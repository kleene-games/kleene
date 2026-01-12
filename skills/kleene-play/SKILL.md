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

1. Read the scenario YAML file once:
   ```
   ${CLAUDE_PLUGIN_ROOT}/scenarios/[scenario_name].yaml
   ```

2. Initialize state from scenario:
   ```yaml
   current_node: [scenario.start_node]
   turn: 0
   character: [scenario.initial_character]
   world: [scenario.initial_world]
   recent_history: []
   ```

3. The scenario data is now in your context - do not re-read it.

**If resuming from save:**

1. Read `game_state.yaml` from current directory
2. Load the referenced scenario file
3. Continue from saved state

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
       - If fails: optionally show as blocked with reason

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

Write to `game_state.yaml`:
```yaml
scenario: [scenario_name]
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

## Choice Presentation

Use AskUserQuestion with these guidelines:

- **header**: Max 12 chars (e.g., "Choice", "Action")
- **labels**: 1-5 words, action-oriented
- **descriptions**: Hint at consequences or requirements
- **blocked options**: Show with "(Blocked)" and reason, or omit

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
