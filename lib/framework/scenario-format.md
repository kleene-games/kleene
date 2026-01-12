# Kleene Scenario Format

Scenarios are defined in YAML with the following structure.

## Top-Level Structure

```yaml
name: "Scenario Title"
description: "Brief description of the scenario"
version: "1.0.0"
```

### Required Metadata Fields

| Field | Purpose | Used By |
|-------|---------|---------|
| `name` | Display name for play menus | Registry, play skill |
| `description` | 1-2 sentence summary | Registry, play skill |

### Legacy Field Compatibility

Some older scenarios use different field names. The registry sync process handles these variations:

| Standard | Legacy Alternatives |
|----------|---------------------|
| `name` | `title`, `metadata.title` |
| `description` | `metadata.description` |

New scenarios should always use `name` and `description` at the top level.

### Full Example

```yaml

# Initial state
initial_character:
  name: "Hero Name"
  traits: { courage: 5, wisdom: 5, luck: 5 }
  inventory: []
  relationships: {}
  flags: {}

initial_world:
  current_location: start_location
  time: 0
  flags: {}
  locations:
    - id: location_id
      name: "Location Name"
      description: "Location description"
      connections: [other_location_id]
      items: []

# The scenario graph
start_node: node_id

nodes:
  node_id:
    narrative: |
      Multi-line narrative text...
    choice:
      prompt: "What do you do?"
      options:
        - id: option_id
          text: "Option text"
          precondition: { ... }
          consequence: [ ... ]
          narrative: "Result narrative"
          next_node: next_node_id

endings:
  ending_id:
    narrative: |
      Ending narrative...
    type: victory | death | transcendence | unchanged
```

## Node Structure

### Narrative Node

```yaml
forest_entrance:
  narrative: |
    The forest swallows you in shadow. Ancient trees whisper secrets.

    Deeper in, you glimpse the ruins of a shrine.
  choice:
    prompt: "Do you approach the shrine?"
    options:
      - id: enter_shrine
        text: "Approach the ancient shrine"
        consequence:
          - type: move_to
            location: shrine
          - type: modify_trait
            trait: wisdom
            delta: 2
        narrative: "The old magic stirs as you approach."
        next_node: shrine_discovery
      - id: leave_forest
        text: "Return to the village"
        narrative: "Some secrets are best left undisturbed."
        next_node: village
```

### Ending Node

```yaml
endings:
  victory:
    narrative: |
      The dragon yields. Victory is yours.
      You have been transformed by the trial.
    type: victory

  death:
    narrative: |
      The dragon's fire consumes you.
      Your story ends here.
    type: death
```

## Precondition Types

### has_item
```yaml
precondition:
  type: has_item
  item: sword
```

### missing_item
```yaml
precondition:
  type: missing_item
  item: key
```

### trait_minimum
```yaml
precondition:
  type: trait_minimum
  trait: courage
  minimum: 7
```

### trait_maximum
```yaml
precondition:
  type: trait_maximum
  trait: fear
  maximum: 3
```

### flag_set
```yaml
precondition:
  type: flag_set
  flag: knows_dragon_tongue
```

### flag_not_set
```yaml
precondition:
  type: flag_not_set
  flag: dragon_hostile
```

### at_location
```yaml
precondition:
  type: at_location
  location: dragon_lair
```

### relationship_minimum
```yaml
precondition:
  type: relationship_minimum
  npc: elder
  minimum: 5
```

### all_of (AND)
```yaml
precondition:
  type: all_of
  conditions:
    - type: has_item
      item: sword
    - type: trait_minimum
      trait: courage
      minimum: 5
```

### any_of (OR)
```yaml
precondition:
  type: any_of
  conditions:
    - type: has_item
      item: sword
    - type: has_item
      item: staff
```

### none_of (NOT)
```yaml
precondition:
  type: none_of
  conditions:
    - type: flag_set
      flag: coward
```

## Consequence Types

### gain_item
```yaml
- type: gain_item
  item: ancient_key
```

### lose_item
```yaml
- type: lose_item
  item: torch
```

### modify_trait
```yaml
- type: modify_trait
  trait: courage
  delta: 2    # Can be negative
```

### set_trait
```yaml
- type: set_trait
  trait: fear
  value: 0
```

### set_flag
```yaml
- type: set_flag
  flag: shrine_visited
  value: true
```

### clear_flag
```yaml
- type: clear_flag
  flag: dragon_hostile
```

### modify_relationship
```yaml
- type: modify_relationship
  npc: dragon
  delta: 5
```

### move_to
```yaml
- type: move_to
  location: mountain_path
```

### advance_time
```yaml
- type: advance_time
  amount: 1
```

### character_dies
```yaml
- type: character_dies
  reason: "consumed by dragonfire"
```

### character_departs
```yaml
- type: character_departs
  reason: "transcended with the dragon spirits"
```

### add_history
```yaml
- type: add_history
  entry: "The hero made a fateful choice"
```

## Game State File

The game state is persisted in `game_state.yaml` in the game folder:

```yaml
scenario: dragon_quest
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
    - torch
  relationships:
    elder: 3
  flags:
    knows_dragon_tongue: false

world:
  current_location: forest
  time: 3
  flags:
    dragon_alive: true
  locations: { ... }

history:
  - "Some(hero enters the story)"
  - "Some(took the sword) - armed themselves"
  - "Some(entered the forest) - seeking another way"

game_over: false
ending_type: null
```

## Validation Rules

A valid scenario must:

1. Have a `start_node` that exists in `nodes`
2. All `next_node` references must exist in `nodes` or `endings`
3. All precondition items/traits/flags must be used consistently
4. Have at least one ending of type `death` (mortality)
5. Have at least one ending of type `victory` or `transcendence` (growth)
6. All choice options should have unique `id` values within their choice
7. Location connections should be bidirectional or intentionally one-way
