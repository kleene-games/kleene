---
name: kleene-play
description: This skill should be used when the user asks to "play a game", "start kleene", "play dragon quest", "continue my game", "load my save", or wants to play an interactive narrative using the Kleene three-valued logic engine. Handles game state, choices, and narrative presentation.
version: 0.1.0
---

# Kleene Play Skill

Execute interactive narrative gameplay using the Kleene three-valued logic framework. Present narrative text, offer choices via AskUserQuestion, apply consequences, and persist game state.

## Game Folder Convention

The "game folder" is the current working directory. Look for:
- `game_state.yaml` - Current game state (create if starting new game)
- `scenario.yaml` - Custom scenario (optional, use bundled scenarios otherwise)

## Core Workflow

### Starting a New Game

1. Check if `game_state.yaml` exists
2. If not, ask user which scenario to play
3. Load scenario from `${CLAUDE_PLUGIN_ROOT}/scenarios/` or local `scenario.yaml`
4. Initialize game state from scenario's `initial_character` and `initial_world`
5. Write initial `game_state.yaml`
6. Present the start node narrative

### Continuing a Game

1. Read `game_state.yaml`
2. Load the referenced scenario
3. Get current node from state
4. Present narrative and choices

### Game Turn Loop

Each turn:

1. **Read State**: Load `game_state.yaml`
2. **Get Current Node**: Find node by `current_node` in scenario
3. **Present Narrative**: Display the node's narrative text
4. **Check Game Over**: If at an ending node, display ending and stop
5. **Evaluate Choices**: For each option in the choice:
   - Evaluate precondition against current state
   - Mark as available or blocked (with reason)
6. **Present Choices**: Use AskUserQuestion with available options
7. **Apply Consequence**: Execute the chosen option's consequences
8. **Update State**: Modify character/world state, add to history
9. **Advance Node**: Set `current_node` to `next_node`
10. **Persist State**: Write updated `game_state.yaml`
11. **Continue**: If not at ending, present next node narrative

## State File Format

```yaml
scenario: dragon_quest  # Scenario name
current_node: forest_entrance
turn: 3

character:
  name: "The Wanderer"
  exists: true
  traits:
    courage: 6
    wisdom: 7
    luck: 5
  inventory:
    - rusty_sword
  relationships: {}
  flags:
    knows_dragon_tongue: false

world:
  current_location: forest
  time: 3
  flags:
    dragon_alive: true

history:
  - "Some(hero enters the story)"
  - "Some(took the sword)"
  - "Some(entered the forest)"

game_over: false
ending_type: null
```

## Precondition Evaluation

Evaluate preconditions to determine option availability:

### has_item
```yaml
precondition:
  type: has_item
  item: sword
```
Check: `item in character.inventory`

### trait_minimum
```yaml
precondition:
  type: trait_minimum
  trait: courage
  minimum: 7
```
Check: `character.traits[trait] >= minimum`

### flag_set
```yaml
precondition:
  type: flag_set
  flag: knows_dragon_tongue
```
Check: `character.flags.get(flag, False) == True`

### all_of / any_of / none_of
Combine multiple conditions with AND / OR / NOT logic.

## Consequence Application

Apply consequences to modify state:

- **gain_item**: Add to `character.inventory`
- **lose_item**: Remove from `character.inventory`
- **modify_trait**: Add delta to `character.traits[trait]`
- **set_flag**: Set `character.flags[flag] = value`
- **move_to**: Set `world.current_location = location`
- **character_dies**: Set `character.exists = false`, add reason to history
- **character_departs**: Set `character.exists = false` with transcendence reason

## Presenting Choices with AskUserQuestion

Use the `AskUserQuestion` tool to present choices as an interactive menu.

**Menu Guidelines:**
- **Headers**: Max 12 characters (e.g., "Choice", "Action")
- **Labels**: 1-5 words, concise action phrases
- **Descriptions**: Action-oriented, explain consequences or requirements
- **Blocked options**: Include "(BLOCKED)" in label with reason in description

```json
{
  "questions": [
    {
      "question": "The dragon awaits. What do you do?",
      "header": "Choice",
      "multiSelect": false,
      "options": [
        {
          "label": "Fight with sword",
          "description": "Attack head-on (requires rusty_sword)"
        },
        {
          "label": "Speak dragon tongue",
          "description": "Attempt peaceful negotiation"
        },
        {
          "label": "Flee",
          "description": "Retreat and seek another path"
        }
      ]
    }
  ]
}
```

### Building the Options Array

For each choice option in the scenario node:

1. **Evaluate precondition** against current state
2. **If available**: Add to options with descriptive label
3. **If blocked**: Either omit OR add with description explaining why blocked

### Option Formatting

- **label**: The choice text from scenario (keep under 50 chars)
- **description**: Context about consequences or requirements
  - For available: hint at what happens
  - For blocked: explain what's missing (e.g., "Requires: rusty_sword")

### Showing Blocked Options

Two approaches:

**Approach 1: Omit blocked options**
Only show what's available. Mention blocked options in narrative text above.

**Approach 2: Include with explanation**
Add blocked options with descriptions like:
```json
{
  "label": "Fight unarmed (BLOCKED)",
  "description": "Requires courage 10+ (you have 5)"
}
```

If user selects a blocked option, explain why it fails and re-present choices.

## Narrative Presentation

Present narrative with rich formatting:

```
═══════════════════════════════════════════════════════════
THE DRAGON'S CHOICE
Turn 3 | Location: Dark Forest
═══════════════════════════════════════════════════════════

[Narrative text from node...]

───────────────────────────────────────────────────────────
Character: The Wanderer
Traits: courage:6 wisdom:7 luck:5
Inventory: rusty_sword
───────────────────────────────────────────────────────────
```

## Emergent Narrative

When player attempts an action not in the scenario:

1. Acknowledge the creative choice
2. Use the generate skill to create a new node
3. Ensure the generated node:
   - Respects current character/world state
   - Has meaningful consequences
   - Connects back to existing nodes or creates valid ending
4. Add generated node to scenario
5. Continue play

## History Tracking

Each choice adds to history with Option-type semantics:

```yaml
history:
  - "Some(hero enters the story)"
  - "Some(took the sword) - armed themselves"
  - "Some(entered the forest) - seeking another way"
  - "None(consumed by dragonfire) - THE END"
```

## Ending Detection

Check for endings:
- Current node is in `endings` section
- `character.exists == false`
- No available choices (dead end)

Display ending with type-specific formatting:
- **victory**: Celebratory tone
- **death**: Somber, respect for the attempt
- **transcendence**: Mystical, transformative
- **unchanged**: Ironic, reflective

## Additional Resources

### Reference Files
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/core.md`** - Core Option type mechanics
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/scenario-format.md`** - YAML format specification

### Bundled Scenarios
- **`${CLAUDE_PLUGIN_ROOT}/scenarios/dragon_quest.yaml`** - Complete example scenario
