---
name: kleene-play
description: This skill should be used when the user asks to "play a game", "start kleene", "play dragon quest", "continue my game", "load my save", or wants to play an interactive narrative using the Kleene three-valued logic engine. Handles game state, choices, and narrative presentation.
version: 0.2.0
allowed-tools: Read, Glob, Write, AskUserQuestion
---

# Kleene Play Skill

Execute interactive narrative gameplay directly in the main conversation context. State persists naturally - no serialization needed between turns.

## Architecture

This skill runs game logic **inline** (no sub-agent). Benefits:
- State persists in conversation context across turns
- Scenario loaded once, stays cached
- Zero serialization overhead
- Faster turn response (~60-70% improvement)

## Game State Model

Track these values in your working memory across turns:

```
GAME_STATE:
  scenario_name: string       # e.g., "dragon_quest"
  current_node: string        # Current node ID
  turn: number                # Turn counter

  character:
    exists: boolean           # false = None (character ceased)
    traits: {name: value}     # courage, wisdom, luck, etc.
    inventory: [items]        # Items held
    flags: {flag: boolean}    # Character-specific flags

  world:
    current_location: string  # Location ID
    time: number              # Time counter
    flags: {flag: boolean}    # World state flags

  recent_history: [string]    # Last 3-5 turns for context
```

## Core Workflow

### Phase 1: Initialization

**If starting new game:**

1. The gateway command provides the scenario path from `registry.yaml`:
   ```
   ${CLAUDE_PLUGIN_ROOT}/scenarios/[registry.scenarios.ID.path]
   ```
   Read the scenario YAML file once. If the file doesn't exist at the registry path:
   - Error: "Scenario file not found at [path]. Run /kleene sync to update registry."
   - Exit skill

2. Create save directory if needed:
   ```
   ./saves/[scenario_name]/
   ```

3. Generate session save filename with current timestamp:
   ```
   YYYY-MM-DD_HH-MM-SS.yaml
   ```
   Store this filename in memory - all saves this session use the same file.

4. Initialize state from scenario:
   ```yaml
   current_node: [scenario.start_node]
   turn: 0
   character: [scenario.initial_character]
   world: [scenario.initial_world]
   recent_history: []
   ```

5. Write initial save file immediately (so session has a file from start).

6. The scenario data is now in your context - do not re-read it.

**If resuming from save:**

1. Read the specified save file from `./saves/[scenario_name]/[filename].yaml`
2. Load the referenced scenario file from `${CLAUDE_PLUGIN_ROOT}/scenarios/`
3. Store the save filename in memory (continue writing to same file)
4. Continue from saved state

### Phase 2: Game Turn

Execute this for each turn:

```
TURN:
  1. Get current node from scenario.nodes[current_node]

  2. Check for ending:
     - If current_node is in scenario.endings → display ending, save state, EXIT
     - If character.exists == false → display death ending, save state, EXIT

  3. Display narrative:
     - Output the node's narrative text with formatting
     - Show character stats line

  4. Evaluate available choices:
     - For each option in node.choice.options:
       - Evaluate precondition against current state
       - If passes: add to available choices
       - If fails: EXCLUDE from choices (do not show)

  5. Present choices via AskUserQuestion:
     {
       "questions": [{
         "question": "[node.choice.prompt]",
         "header": "Choice",
         "multiSelect": false,
         "options": [available choices with labels/descriptions]
       }]
     }

  6. Wait for user selection

  6a. IF selection doesn't match any predefined option (free-text via "Other"):
      - Classify intent (Explore/Interact/Act/Meta)
      - Check feasibility against current state
      - Generate narrative response matching scenario tone
      - Apply soft consequences only (trait ±1, add_history, improv_* flags)
      - Display response with consequence indicators
      - Present same choices again (step 5)
      - Do NOT advance node or turn
      - GOTO step 6

  7. Apply consequences of chosen option:
     - Execute each consequence type
     - Update character/world state in memory

  8. Advance state:
     - Set current_node = option.next_node
     - Increment turn
     - Add choice to recent_history (keep last 5)

  9. GOTO step 1 (next turn)
```

### Phase 3: Persistence

**Save state to disk ONLY when:**
- Game ends (victory, death, transcendence, etc.)
- User explicitly requests save
- Session is ending

Write to `./saves/[scenario_name]/[session_timestamp].yaml`:
```yaml
# Save metadata
save_version: 2
scenario: [scenario_name]
session_started: "[ISO timestamp from game start]"
last_saved: "[current ISO timestamp]"

# Game state
current_node: [node_id]
turn: [turn_number]
character:
  exists: [boolean]
  traits: {...}
  inventory: [...]
  flags: {...}
world:
  current_location: [location]
  time: [time]
  flags: {...}
```

The `session_timestamp` in the filename is set once at game start (Phase 1) and reused for all saves in that session.

## Save Management

### Save Directory Structure

```
./saves/
├── dragon_quest/
│   ├── 2026-01-12_14-30-22.yaml
│   └── 2026-01-10_09-15-00.yaml
├── altered_state_nightclub/
│   └── 2026-01-11_22-45-33.yaml
└── corporate_banking/
    └── 2026-01-09_18-00-00.yaml
```

### Listing Saves

When user requests to see saves for a scenario:

1. Glob `./saves/[scenario_name]/*.yaml`
2. Read each file's metadata:
   - `last_saved` timestamp
   - `turn` number
   - `current_node` ID
3. Sort by `last_saved` (most recent first)
4. Present as numbered list with summary:

```
Found 3 saved games for "The Dragon's Choice":

1. Jan 12, 2:30 PM - Turn 12 at mountain_approach
2. Jan 10, 9:15 AM - Turn 5 at forest_entrance
3. Jan 8, 7:00 PM - Turn 3 at sword_taken

Which save would you like to load?
```

### Loading a Save

When user selects a save to load:

1. Read the specified YAML file from `./saves/[scenario_name]/[filename].yaml`
2. Extract `scenario` field to identify which scenario definition to load
3. Load scenario definition from `${CLAUDE_PLUGIN_ROOT}/scenarios/[scenario].yaml`
4. Store the save filename in memory (continue writing to same file)
5. Resume gameplay from the saved `current_node`

## Precondition Evaluation

Evaluate preconditions against current state:

### has_item
```yaml
precondition:
  type: has_item
  item: sword
```
Check: `"sword" in character.inventory`

### missing_item
```yaml
precondition:
  type: missing_item
  item: curse
```
Check: `"curse" not in character.inventory`

### trait_minimum
```yaml
precondition:
  type: trait_minimum
  trait: courage
  minimum: 7
```
Check: `character.traits.courage >= 7`

### trait_maximum
```yaml
precondition:
  type: trait_maximum
  trait: suspicion
  maximum: 5
```
Check: `character.traits.suspicion <= 5`

### flag_set
```yaml
precondition:
  type: flag_set
  flag: knows_secret
```
Check: `character.flags.knows_secret == true`

### flag_not_set
```yaml
precondition:
  type: flag_not_set
  flag: betrayed_ally
```
Check: `character.flags.betrayed_ally != true`

### at_location
```yaml
precondition:
  type: at_location
  location: forest
```
Check: `world.current_location == "forest"`

### all_of (AND)
```yaml
precondition:
  type: all_of
  conditions:
    - type: has_item
      item: key
    - type: flag_set
      flag: door_revealed
```
Check: ALL conditions must pass

### any_of (OR)
```yaml
precondition:
  type: any_of
  conditions:
    - type: has_item
      item: key
    - type: trait_minimum
      trait: strength
      minimum: 8
```
Check: AT LEAST ONE condition must pass

### none_of (NOT)
```yaml
precondition:
  type: none_of
  conditions:
    - type: flag_set
      flag: alarm_triggered
```
Check: NO conditions can pass

## Consequence Application

Apply consequences to modify state in memory:

### gain_item
```yaml
- type: gain_item
  item: ancient_key
```
Action: Add "ancient_key" to character.inventory

### lose_item
```yaml
- type: lose_item
  item: torch
```
Action: Remove "torch" from character.inventory

### modify_trait
```yaml
- type: modify_trait
  trait: courage
  delta: 2
```
Action: character.traits.courage += 2

### set_trait
```yaml
- type: set_trait
  trait: suspicion
  value: 10
```
Action: character.traits.suspicion = 10

### set_flag
```yaml
- type: set_flag
  flag: shrine_visited
  value: true
```
Action: character.flags.shrine_visited = true (or world.flags if world flag)

### clear_flag
```yaml
- type: clear_flag
  flag: cursed
```
Action: character.flags.cursed = false

### move_to
```yaml
- type: move_to
  location: mountain_path
```
Action: world.current_location = "mountain_path"

### advance_time
```yaml
- type: advance_time
  delta: 1
```
Action: world.time += 1

### character_dies
```yaml
- type: character_dies
  reason: "consumed by dragonfire"
```
Action: character.exists = false, add to history

### character_departs
```yaml
- type: character_departs
  reason: "ascended to the stars"
```
Action: character.exists = false (transcendence ending)

### add_history
```yaml
- type: add_history
  entry: "Discovered the hidden passage"
```
Action: Add to recent_history

## Improvised Action Handling

When a player selects "Other" and provides free-text input, react creatively rather than blocking. Generate a narrative response that acknowledges their action, then return to the current node's options.

### Detection

After receiving user selection (step 6 in Core Workflow), check if the response matches any predefined option label. If NOT:
- The user provided free-text via "Other"
- Execute the Improvisation Handler below
- Do NOT advance to a new node

### Intent Classification

Classify the player's free-text action:

| Intent | Keywords/Patterns | Example |
|--------|-------------------|---------|
| **Explore** | examine, look at, inspect, study, check | "I examine the dragon's scales" |
| **Interact** | talk to, ask, speak with, approach | "I try talking to the shadow in the corner" |
| **Act** | try to, attempt, I want to, I [verb] | "I try to climb the wall" |
| **Meta** | save, help, what are my stats, rules | "save my game" |

### Feasibility Check

Given current state, evaluate if the action is:

**Possible**: World permits this action
- No preconditions block it
- Makes sense in current location
- Character has capability (traits, items)

**Blocked**: World resists
- Missing required item or trait
- Wrong location
- Contradicts established world rules

**Impossible**: Breaks scenario logic
- Tries to interact with non-existent entities
- Attempts to skip major story beats
- Would trivialize core challenges

### Response Generation

Generate a narrative response based on intent and feasibility:

#### Explore (Possible)
Provide atmospheric detail about what they examine. Add richness to the scene.
```
You study the dragon's scales more closely. In the flickering light,
you notice patterns etched into each plate - not natural markings,
but deliberate inscriptions. Writing, perhaps, in a language older
than human speech.

[+1 wisdom - Attention to detail]
```

#### Interact (Possible)
Brief exchange or observation about the interaction attempt.
```
You call out to the shadow. It shifts, acknowledging you, but offers
no words. A cold presence brushes past your mind - not hostile,
but distinctly *other*. It seems to be waiting for something.

[+1 intuition]
```

#### Act (Possible)
Describe the attempt and its outcome. May succeed partially or reveal new information.
```
You attempt to scale the cavern wall. The rock is slick with moisture,
but you find handholds. Halfway up, you spot something glinting in
a crevice - a coin, ancient and tarnished. You pocket it before
descending.

[Gained: tarnished_coin (flavor item)]
```

#### Blocked Action
Explain why the action fails. The world resists, but provide narrative context.
```
You try to push past the stone door, but it won't budge. The runes
carved into its surface pulse faintly - whatever seal holds it closed
requires more than brute force. Perhaps there's another way...
```

#### Impossible Action
Gently redirect without breaking immersion.
```
The dragon fills the entire passage ahead. There's no path around it,
no clever route to slip by unnoticed. Whatever happens next, it
happens here, face to face with the wyrm.
```

#### Meta Request
Handle directly, breaking the fourth wall briefly.
```
Game saved to game_state.yaml.
---
[Continuing...]
```

### Soft Consequences

Improvised actions may apply ONLY these consequence types:

| Allowed | Not Allowed |
|---------|-------------|
| `modify_trait` (delta: -1 to +1) | `gain_item` (scenario items) |
| `add_history` | `lose_item` |
| `set_flag` (only `improv_*` prefix) | `move_to` |
| | `character_dies` |
| | `character_departs` |

**Why these limits?** Improvisation enriches the current moment without derailing scenario balance. Major state changes (items, locations, death) are reserved for scripted paths.

### Soft Flags Convention

Improvised actions can set flags prefixed with `improv_`:
```
improv_examined_dragon_scales
improv_spoke_to_shadow
improv_attempted_wall_climb
```

These flags:
- Track what the player has explored/attempted
- Enable richer responses to repeated improvisation
- Should NOT gate major scenario paths

### Tone Matching

Match the scenario's established voice:
- **Perspective**: Use second person present ("You examine...")
- **Vocabulary**: Match the scenario (archaic/modern/technical)
- **Imagery**: Match the scenario's descriptive density
- **Rhythm**: Match sentence length and pacing

Read the current node's narrative for guidance.

### Improvised Action Presentation

Display improvised action responses with the same bold box format as regular nodes. Generate a creative title based on the player's action:

```
═══════════════════════════════════════════════════════════
**[CREATIVE TITLE]**
Turn [N] | Location: [location]
═══════════════════════════════════════════════════════════

[Narrative response to player's improvised action]

───────────────────────────────────────────────────────────
[trait changes, e.g., +1 wisdom - Attention to detail]
───────────────────────────────────────────────────────────
```

**Title Generation Guidelines:**

| Player Action | Bad Title | Good Title |
|--------------|-----------|------------|
| "Pick up baggie and snort it" | Improvised Action | The Quick Fix |
| "I examine the bartender's tattoos" | Improvised Action | Ink and Suspicion |
| "Try talking to the woman with cold skin" | Improvised Action | Cold Conversation |
| "I climb the wall to look for an exit" | Improvised Action | The Desperate Ascent |

The title should:
- Be evocative/atmospheric (2-5 words)
- Reflect what the player is actually doing
- Match the scenario's tone
- NOT be generic ("Improvised Action", "Custom Choice", etc.)

### After Improvisation

After generating the response:
1. Apply any soft consequences
2. Display the response using the bold box format (see Improvised Action Presentation above)
3. Present the current node's original options AGAIN
4. Do NOT advance `current_node` or increment `turn`

The game stays at the same decision point, enriched by the player's exploration.

### Edge Cases

**Player tries to defeat boss via free-text:**
```
The dragon is vast - scales like ancient iron. A wild attack without
preparation would be suicide. The wyrm's eyes track you, waiting to
see what you'll actually do.
```
Then: Show original options.

**Player tries to leave scenario bounds:**
```
You consider turning back, but the path behind has collapsed.
Rocks and debris block any retreat. The only way is forward.
```

**Player repeats same improvisation:**
Check `improv_*` flags. If already set:
```
You've already examined the scales closely. The inscriptions remain
as mysterious as before. Perhaps action, not study, is needed now.
```

**Player action matches a blocked option:**
If free-text describes an action that has a precondition they don't meet, explain WHY it's blocked:
```
You reach for where your sword should hang, but your hand finds only
air. Without a weapon, challenging the dragon directly would be folly.
```

## Narrative Presentation

Display narrative with consistent formatting:

```
═══════════════════════════════════════════════════════════
**NODE TITLE** (or scenario name)
Turn [N] | Location: [location]
═══════════════════════════════════════════════════════════

[Narrative text from node - use markdown formatting]

───────────────────────────────────────────────────────────
courage:[X] wisdom:[X] luck:[X] | [inventory items]
───────────────────────────────────────────────────────────
```

### Status Updates

State changes (flags, traits, items) go in the **footer stats line**, never as separate headings.

**DO:** Show changes in footer
```
───────────────────────────────────────────────────────────
Sobriety: 7 (-3) | Suspicion: 8 (+3) | Flags: knows_dj_secret
───────────────────────────────────────────────────────────
```

**DON'T:** Create separate headings for status
```
───────────────────────────────────────────────────────────
*Flag set: knows_dj_secret*
───────────────────────────────────────────────────────────
```

The bold box header (`═══`) is reserved for node/scene titles only.

## Choice Presentation

Use AskUserQuestion with these guidelines:

- **header**: Max 12 chars (e.g., "Choice", "Action")
- **labels**: 1-5 words, action-oriented
- **descriptions**: Hint at consequences or requirements
- **blocked options**: NEVER show. Filter out before presenting choices.

```json
{
  "questions": [{
    "question": "The dragon awaits. What do you do?",
    "header": "Choice",
    "multiSelect": false,
    "options": [
      {"label": "Fight", "description": "Attack with your sword"},
      {"label": "Negotiate", "description": "Attempt to speak with the dragon"},
      {"label": "Flee", "description": "Retreat to safety"}
    ]
  }]
}
```

## Ending Detection

Check for endings:
1. current_node is in scenario.endings
2. character.exists == false
3. No available choices (dead end - shouldn't happen in well-designed scenarios)

Display ending with appropriate tone:

**Victory:**
```
╔═══════════════════════════════════════════════════════════╗
║  VICTORY                                                  ║
╚═══════════════════════════════════════════════════════════╝

[Ending narrative - celebratory tone]
```

**Death:**
```
╔═══════════════════════════════════════════════════════════╗
║  DEATH                                                    ║
╚═══════════════════════════════════════════════════════════╝

[Ending narrative - somber, respectful]
```

**Transcendence:**
```
╔═══════════════════════════════════════════════════════════╗
║  TRANSCENDENCE                                            ║
╚═══════════════════════════════════════════════════════════╝

[Ending narrative - mystical, transformative]
```

**Unchanged (Irony):**
```
╔═══════════════════════════════════════════════════════════╗
║  UNCHANGED                                                ║
╚═══════════════════════════════════════════════════════════╝

[Ending narrative - ironic, reflective]
```

## Additional Resources

- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/core.md`** - Option type semantics
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/scenario-format.md`** - YAML specification
- **`${CLAUDE_PLUGIN_ROOT}/scenarios/`** - Bundled scenarios
