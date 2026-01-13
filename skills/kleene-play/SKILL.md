---
name: kleene-play
description: This skill should be used when the user asks to "play a game", "start kleene", "play dragon quest", "continue my game", "load my save", or wants to play an interactive narrative using the Kleene three-valued logic engine. Handles game state, choices, and narrative presentation.
version: 0.3.0
allowed-tools: Read, Glob, Grep, Write, Edit, AskUserQuestion
hooks:
  PreToolUse:
    - matcher: "Write|Edit"
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/auto-approve-saves.sh"
    - matcher: "Bash"
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/auto-approve-saves.sh"
---

# Kleene Play Skill

Execute interactive narrative gameplay directly in the main conversation context. State persists naturally - no serialization needed between turns.

## Architecture

This skill runs game logic **inline** (no sub-agent). Benefits:
- State persists in conversation context across turns
- Scenario loaded once, stays cached
- Zero serialization overhead
- Faster turn response (~60-70% improvement)

## Scenario Loading

Scenarios may be loaded in two modes depending on file size.

### Standard Load (small scenarios)

For scenarios under ~20k tokens, read the entire file once and cache in context.

### Lazy Load (large scenarios)

When the Read tool returns a token limit error, switch to lazy loading:

**Step 1: Load header (first 200 lines)**
```
Read scenario file with limit: 200
```
Extract and cache:
- `scenario` / `title` - scenario identifier
- `initial_character` - starting character state
- `initial_world` - starting world state
- `start_node` - first node ID (usually in header, but may need grep)
- `endings` - all ending definitions

**Step 2: Load nodes on demand**

For each node needed during gameplay, use Grep:
```
Pattern: "^  {node_id}:"
Context: -A 80 (captures most node content)
Path: scenario file
```

Parse the YAML from grep output to extract:
- `title` / `narrative` - display text
- `choice.prompt` - question to ask
- `choice.options` - available choices with preconditions/consequences

**Step 3: Cache strategy**
- Header data: persistent (kept in context)
- Current node: replaced each turn (don't accumulate old nodes)
- Endings: persistent (needed for ending detection)

### Detecting Load Mode

The gateway command attempts full read first. If it fails:
1. Sets `lazy_loading: true` in game context
2. Loads header via partial read
3. Passes scenario path for per-turn node loading

When `lazy_loading: true`, Phase 2 must grep for each node instead of accessing cached scenario data.

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

   Load the scenario using the appropriate mode (see **Scenario Loading** section):
   - **Standard**: Read entire file, cache in context
   - **Lazy**: If Read returns token limit error, read first 200 lines for header, then grep for `start_node`

   If the file doesn't exist:
   - Error: "Scenario file not found at [path]. Run /kleene sync to update registry."
   - Exit skill

   Track load mode in context: `lazy_loading: true/false`

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
   - Use appropriate load mode (standard or lazy) based on file size
3. Store the save filename in memory (continue writing to same file)
4. Continue from saved state

### Phase 2: Game Turn

Execute this for each turn:

```
TURN:
  1. Get current node:
     - Standard mode: Access scenario.nodes[current_node] from cached scenario
     - Lazy mode: Grep for "^  {current_node}:" with -A 80, parse YAML

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

  6b. IF selected option has `next: improvise` (scripted Unknown path):
      - Execute Scripted Improvisation Flow (see below)
      - GOTO step 1 if outcome node specified, else GOTO step 5

  7. Display option narrative (if present):
     - Check if selected option has a `narrative` field
     - If present: display it (plain text, no box format)
     - This is the immediate feedback to the player's choice

  8. Apply consequences of chosen option:
     - Execute each consequence type
     - Update character/world state in memory

  9. Advance state:
     - Set current_node = option.next_node
     - Increment turn
     - Add choice to recent_history (keep last 5)

  10. GOTO step 1 (next turn)
```

### Phase 3: Persistence

> **Reference:** See `lib/framework/saves.md` for save format, file creation, and operations.

Save to disk when:
- Game ends (victory, death, transcendence)
- User explicitly requests save
- Session is ending

The PreToolUse hook auto-approves saves/ writes for seamless gameplay.

## Precondition & Consequence Evaluation

> **Schema Reference:** See `lib/framework/scenario-format.md` for all types and YAML syntax.

### Precondition Evaluation

Evaluate preconditions against current state:

| Type | Check |
|------|-------|
| `has_item` | `item in character.inventory` |
| `missing_item` | `item not in character.inventory` |
| `trait_minimum` | `character.traits[trait] >= minimum` |
| `trait_maximum` | `character.traits[trait] <= maximum` |
| `flag_set` | `character.flags[flag] == true` |
| `flag_not_set` | `character.flags[flag] != true` |
| `at_location` | `world.current_location == location` |
| `relationship_minimum` | `character.relationships[npc] >= minimum` |
| `all_of` | All nested conditions pass |
| `any_of` | At least one nested condition passes |
| `none_of` | No nested conditions pass |

### Consequence Application

Apply consequences to modify state in memory:

| Type | Action |
|------|--------|
| `gain_item` | Add to `character.inventory` |
| `lose_item` | Remove from `character.inventory` |
| `modify_trait` | `character.traits[trait] += delta` |
| `set_trait` | `character.traits[trait] = value` |
| `set_flag` | `character.flags[flag] = value` |
| `clear_flag` | `character.flags[flag] = false` |
| `move_to` | `world.current_location = location` |
| `advance_time` | `world.time += delta` |
| `modify_relationship` | `character.relationships[npc] += delta` |
| `character_dies` | `character.exists = false`, add reason to history |
| `character_departs` | `character.exists = false` (transcendence) |
| `add_history` | Append entry to `recent_history` |

## Improvised Action Handling

> **Reference:** See `lib/framework/improvisation.md` for complete handling rules.

When a player selects "Other" and provides free-text input:

1. Classify intent (Explore/Interact/Act/Meta)
2. Check feasibility against current state (Possible/Blocked/Impossible)
3. Generate narrative response matching scenario tone
4. Apply soft consequences only (trait +/-1, add_history, improv_* flags)
5. Display response with bold box format (generate creative title)
6. Present same choices again - do NOT advance node or turn

Soft consequences preserve scenario balance while rewarding exploration.

## Scripted Improvisation Flow

When a player selects an option with `next: improvise`, execute this special flow for the Unknown row of the Nine Cells.

> **CRITICAL:** See `lib/framework/presentation.md` → "Improvise Option Flow" for seamless presentation rules. Never output internal processing notes.

### Step 1: Display option narrative

If the option has a `narrative` field, display it first as context. Then immediately present the sub-prompt - no meta-commentary.

### Step 2: Present sub-prompt

Ask the player for specific intent:

```json
{
  "questions": [{
    "question": "What specifically do you do?",
    "header": "Action",
    "multiSelect": false,
    "options": [
      {"label": "Watch carefully", "description": "Observe and study"},
      {"label": "Wait patiently", "description": "See what happens"},
      {"label": "Look for details", "description": "Search for information"}
    ]
  }]
}
```

Generate options based on `improvise_context.theme`. Always allow free-text via "Other".

### Step 3: Classify response to grid cell

Match the player's response against the patterns in `improvise_context`:

```
IF response matches any pattern in `permits`:
  cell = Discovery (Unknown + World Permits)

ELSE IF response matches any pattern in `blocks`:
  cell = Revelation (Unknown + World Blocks)

ELSE:
  cell = Limbo (Unknown + World Indeterminate)
```

Pattern matching uses case-insensitive regex. Example:
- `permits: ["scales", "eyes", "breathing"]` matches "I study the dragon's scales"
- `blocks: ["attack", "steal"]` matches "I try to sneak past and steal something"

### Step 4: Generate narrative response

Based on the determined cell, generate an appropriate response:

**Discovery (permits matched):**
- Exploration yields insight
- Positive tone, rewarding curiosity
- May add soft trait bonus (+1 wisdom typical)

**Revelation (blocks matched):**
- World prevents or warns against action
- Explanatory tone, teaches constraint
- May add soft trait adjustment (-1 luck typical)

**Limbo (no match):**
- Use `improvise_context.limbo_fallback` as the base
- Elaborate with atmospheric detail
- Neutral tone, maintains suspense
- No trait changes

### Step 5: Apply soft consequences

Same rules as emergent improvisation:
- `modify_trait` with delta -1 to +1 only
- `add_history` to record the exploration
- `set_flag` with `improv_*` prefix only

### Step 6: Determine next state

Check `outcome_nodes` for the determined cell:

```yaml
outcome_nodes:
  discovery: dragon_notices_patience
  revelation: dragon_dismisses_hesitation
  # limbo: omitted
```

**If outcome_nodes[cell] is specified:**
- Advance to that node
- Increment turn
- Continue to next turn (step 1)

**If outcome_nodes[cell] is omitted (typical for Limbo):**
- Stay at current node
- Do NOT increment turn
- Re-present original choices (step 5)

### Example Flow

```
Option selected: "Wait and observe the dragon"
  └── has next: improvise

Sub-prompt: "What specifically do you do?"
  └── Player response: "I study the inscriptions on its scales"

Pattern match:
  └── permits: ["scales", "inscriptions"] ← MATCH
  └── cell = Discovery

Generate narrative:
  └── "You peer closer at the ancient markings etched into the iron-hard
       scales. They seem to form words in a language older than human
       memory. One pattern repeats - a symbol of greeting, perhaps?"
  └── +1 wisdom - Attention to detail

Outcome nodes:
  └── discovery: dragon_notices_patience
  └── Advance to dragon_notices_patience, turn++
```

## Narrative Presentation

> **Conventions:** See `lib/framework/presentation.md` for complete formatting rules.

Display narrative with the **cinematic header format**:

### Header Exemplar

```
═══════════════════════════════════════════════════════════════════════
                    T H E   V E L V E T   C H A M B E R
═══════════════════════════════════════════════════════════════════════
                          Main Entrance
                        Turn 1 | Time: 23:00
                   Sobriety: ██████████ 10 | Suspicion: ████░░░░░░ 5
═══════════════════════════════════════════════════════════════════════
```

## Choice Presentation

Use AskUserQuestion per conventions in `lib/framework/presentation.md`.

**Blocked options**: NEVER show. Filter out options whose preconditions fail before presenting choices.

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

- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/core.md`** - Option type semantics, quadrant theory
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/scenario-format.md`** - YAML specification, preconditions, consequences
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/presentation.md`** - Header, trait, and choice formatting
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/improvisation.md`** - Free-text action handling
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/saves.md`** - Game folder, save format, persistence rules
- **`${CLAUDE_PLUGIN_ROOT}/scenarios/`** - Bundled scenarios
