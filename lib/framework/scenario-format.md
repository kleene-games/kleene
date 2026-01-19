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

## Location State System

Per-location mutable state stored in `world.location_state{}`. Tracks flags, properties, and environment conditions that can change during gameplay.

### Structure

```yaml
world:
  location_state:
    shrine:
      flags: {discovered: true, sealed: false}
      properties: {blessing_power: 100}
      environment: {lighting: dim, temperature: cold}
    village:
      flags: {quest_completed: true}
      properties: {population: 150}
```

### Lazy Initialization

Location state is created on first modification. You don't need to pre-define state for every location—it initializes automatically when a consequence modifies it.

### Components

| Component | Purpose | Example Values |
|-----------|---------|----------------|
| `flags` | Binary states | `discovered`, `sealed`, `quest_completed` |
| `properties` | Numeric values | `population`, `blessing_power`, `damage` |
| `environment` | Atmospheric conditions | `lighting`, `temperature`, `weather` |

See [Location Flag Preconditions](#location_flag_set) and [Location Consequences](#set_location_flag) for usage.

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

### Scene Control

Nodes can force scene breaks for major narrative transitions:

```yaml
forest_entrance:
  scene_break: true    # Forces scene increment on arrival
  narrative: |
    You emerge from the dark tunnel into dappled sunlight...
```

**When to use `scene_break: true`:**
- Major location transitions
- Significant time jumps
- Tonal shifts in narrative
- After climactic moments

**Automatic scene breaks** occur when:
- Location changes (via `move_to` consequence)
- Time advances (via `advance_time` consequence)
- 5+ beats accumulate without explicit break

Scene tracking affects:
- Gameplay headers display "Turn N · Scene S · Beat B"
- Export granularity options (`--granularity=scene`)
- Multi-level rewind targeting (T6.2.3 notation)

### Node-Level Preconditions

Nodes can have preconditions that must be satisfied to enter. When a player's choice leads to a node whose precondition fails, the game displays a "blocked" message and returns to the previous node's choices without advancing the turn counter.

```yaml
dragon_lair:
  precondition:
    type: all_of
    conditions:
      - type: has_item
        item: dragon_scale
      - type: trait_minimum
        trait: courage
        minimum: 10

  blocked_narrative: |
    The lair's entrance pulses with ancient wards. You sense
    powerful forces judging your worthiness.

    Without proof of dragon-kind and sufficient bravery,
    you cannot pass.

  narrative: |
    You enter the dragon's lair...

  choice:
    prompt: "What do you do?"
    options:
      - id: explore
        text: "Explore the cavern"
        next_node: cavern_depths
```

**Behavior when precondition fails:**
- Player does NOT advance to blocked node
- Turn counter does NOT increment
- `blocked_narrative` shown (or generated fallback if not provided)
- Previous node's choices re-presented

**Fallback messages:** If no `blocked_narrative` is provided, the system generates a contextual message based on the precondition type:
- `has_item`: "You need the **[item]** to proceed here."
- `trait_minimum`: "Your **[trait]** ([current]) is insufficient. Requires at least [minimum]."
- `all_of`: Message for first failing sub-condition
- And so on for other precondition types.

### Temporal Metadata (Phase 2: Parsing Only)

Nodes can include temporal metadata for future time-tracking features:

```yaml
temple_interior:
  elapsed_since_previous:
    amount: 2
    unit: hours

  duration:
    amount: 1
    unit: hours

  narrative: |
    After a long journey, you arrive at the temple interior...
```

| Field | Purpose |
|-------|---------|
| `elapsed_since_previous` | Time passed since leaving the previous node |
| `duration` | How long the events of this node take |

**Valid time units:** `seconds`, `minutes`, `hours`, `days`, `weeks`, `months`, `years`

**Note:** In Phase 2, temporal metadata is parsed and validated but not yet used for gameplay mechanics. Full time tracking will be implemented in Phase 5.

### Location-Level Preconditions

Locations can have preconditions that control access. When a `move_to` consequence targets a location whose precondition fails, the game handles it based on `access_mode`:

```yaml
initial_world:
  locations:
    - id: shrine
      name: "Ancient Shrine"
      connections: [forest, mountain_path]

      precondition:
        type: all_of
        conditions:
          - type: has_item
            item: shrine_key
          - type: flag_set
            flag: elder_blessing

      access_denied_narrative: |
        The shrine's ancient wards shimmer before you.
        Without the proper key and the elder's blessing,
        the way remains sealed.

      access_mode: show_locked  # filter | show_locked | show_normal

      initial_state:
        flags: { discovered: false }
        environment: { lighting: dim, ambiance: sacred }
```

#### Access Modes

| Mode | Behavior |
|------|----------|
| `filter` | Hide inaccessible location from options (default, backwards compatible) |
| `show_locked` | Show with "[Locked]" indicator, explain requirements on hover/select |
| `show_normal` | Show normally, display access_denied_narrative if selected |

#### Environment State

Environment properties track conditions like lighting, weather, and temperature:

```yaml
# Set environment
- type: set_environment
  location: shrine  # Omit for current location
  property: lighting
  value: dark

# Modify numeric environment
- type: modify_environment
  location: dragon_lair
  property: temperature
  delta: 100

# Check environment (precondition)
precondition:
  type: environment_is
  property: lighting
  value: lit
```

#### Environment Precondition Types

| Type | Check |
|------|-------|
| `environment_is` | `location.environment[property] == value` |
| `environment_minimum` | `location.environment[property] >= minimum` |
| `environment_maximum` | `location.environment[property] <= maximum` |

**Note:** If `location` is omitted in environment preconditions/consequences, the current location is used. Missing environment properties default to `null`; preconditions fail on null.

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

## Option Properties

### Standard Options

Options normally specify `next_node` to advance the story:

```yaml
options:
  - id: take_sword
    text: "Take the sword"
    precondition: { type: at_location, location: armory }
    consequence:
      - type: gain_item
        item: sword
    narrative: "Steel in hand, you feel ready."
    next_node: armed_and_ready
```

### Grid Cell Classification

Options can specify which Decision Grid cell they represent. This helps the analyze skill track coverage:

```yaml
options:
  - id: fight_dragon
    text: "Draw your sword and attack"
    cell: chooses        # Player actively engages
    next_node: dragon_fight

  - id: flee_dragon
    text: "Turn and run"
    cell: avoids         # Player retreats/refuses
    next_node: attempt_flee
```

Valid `cell` values: `chooses`, `unknown`, `avoids`

### Improvise Options (Unknown Row)

For the "Player Unknown" row of the Decision Grid (Discovery, Limbo, Revelation), options can trigger improvisation instead of advancing to a fixed node:

```yaml
options:
  - id: observe_dragon
    text: "Wait and observe the dragon"
    cell: unknown
    next: improvise
    improvise_context:
      theme: "patient observation of an ancient being"
      permits: ["scales", "inscriptions", "breathing", "eyes", "watch"]
      blocks: ["attack", "charge", "sneak", "steal"]
      limbo_fallback: "Time stretches in the dragon's presence..."
    outcome_nodes:
      discovery: dragon_notices_patience
      revelation: dragon_dismisses_hesitation
      # limbo: omitted = stay at current node
```

#### `next: improvise`

Replaces `next_node`. When selected, triggers a sub-prompt asking "What specifically do you do?" The response is processed through improvisation handling.

#### `improvise_context`

Guides AI interpretation of the player's free-text response:

| Field | Purpose |
|-------|---------|
| `theme` | Thematic context for generating narrative responses |
| `permits` | Regex patterns that indicate Discovery (world permits action) |
| `blocks` | Regex patterns that indicate Revelation (world blocks action) |
| `limbo_fallback` | Narrative shown when response is ambiguous (Limbo cell) |

#### `outcome_nodes`

Maps grid cells to destination nodes. Cell-dependent advancement:

| Cell | Behavior |
|------|----------|
| `discovery` | If matched and node specified, advance to that node |
| `revelation` | If matched and node specified, advance to that node |
| `limbo` | If matched and node specified, advance; otherwise stay at current node |

If an outcome has no node specified, player stays at the current decision point.

### Improvise Option Example

```yaml
intro:
  narrative: |
    The elder grips your arm. "The dragon has returned..."
  choice:
    prompt: "What do you do?"
    options:
      - id: take_sword
        text: "Take the sword from the blacksmith"
        cell: chooses
        next_node: sword_taken

      - id: ask_elder
        text: "Ask the elder what she knows"
        cell: unknown
        next: improvise
        improvise_context:
          theme: "seeking wisdom before action"
          permits: ["history", "weakness", "legend", "why", "story"]
          blocks: ["demand", "threaten", "force", "lie"]
          limbo_fallback: "The elder watches you, waiting for a real question..."
        outcome_nodes:
          discovery: elder_lore
          revelation: elder_silence

      - id: flee_village
        text: "Leave the village to its fate"
        cell: avoids
        next_node: abandoned_village
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

### location_flag_set
```yaml
precondition:
  type: location_flag_set
  location: village
  flag: quest_completed
```

### location_flag_not_set
```yaml
precondition:
  type: location_flag_not_set
  location: shrine
  flag: sealed
```

### location_property_minimum
```yaml
precondition:
  type: location_property_minimum
  location: shrine
  property: blessing_power
  minimum: 50
```

### location_property_maximum
```yaml
precondition:
  type: location_property_maximum
  location: dragon_lair
  property: heat_level
  maximum: 500
```

**Note:** Location preconditions gracefully handle missing state. If `world.location_state[location]` doesn't exist or the flag/property is missing, it defaults to `false` (for flags) or `0` (for properties).

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
  unit: hours  # Optional: seconds, minutes, hours (default), days, weeks, months, years
```

**NEW in v5:** The `unit` field allows specifying time units. Default is `hours` for backwards compatibility. Time is stored internally as seconds.

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

### set_location_flag
```yaml
- type: set_location_flag
  location: village
  flag: quest_completed
  value: true
```

### clear_location_flag
```yaml
- type: clear_location_flag
  location: shrine
  flag: sealed
```

### modify_location_property
```yaml
- type: modify_location_property
  location: village
  property: population
  delta: -10    # Can be negative
```

### set_location_property
```yaml
- type: set_location_property
  location: shrine
  property: blessing_power
  value: 100
```

**Note:** Location consequences use lazy initialization. If `world.location_state[location]` doesn't exist when applying a consequence, it is created with empty `flags: {}` and `properties: {}` before applying the change.

## NPC Location Tracking (NEW in v5)

Track where NPCs are in the world. NPCs can move dynamically and their presence can gate options.

### Initial NPC Locations

Set starting positions in `initial_world`:

```yaml
initial_world:
  npc_locations:
    guardian: temple_gates
    merchant: temple_interior
    oracle: temple_interior
```

### move_npc
```yaml
- type: move_npc
  npc: guardian
  location: temple_interior  # or "current" for player's location
```

**Special value `current`:** Resolves to `world.current_location` at execution time.

### npc_at_location
```yaml
precondition:
  type: npc_at_location
  npc: guardian
  location: current  # NPC is where player is
```

### npc_not_at_location
```yaml
precondition:
  type: npc_not_at_location
  npc: guardian
  location: temple_gates  # NPC has left this location
```

**Note:** If an NPC is at a non-existent location or not in `npc_locations`, preconditions treat them as "offscreen" (not at any named location).

## Scheduled Events (NEW in v5)

Schedule consequences to trigger after time passes. Events fire automatically when `world.time` reaches their `trigger_at` value.

### schedule_event
```yaml
- type: schedule_event
  event_id: dragon_attack
  delay:
    amount: 24
    unit: hours
  consequences:
    - type: set_flag
      flag: village_destroyed
      value: true
    - type: move_npc
      npc: dragon
      location: village
```

The event is added to `world.scheduled_events` with `trigger_at = world.time + delay_in_seconds`.

### trigger_event
```yaml
- type: trigger_event
  event_id: dragon_attack
```

Triggers a scheduled event immediately, applying its consequences and moving it to `triggered_events`.

### cancel_event
```yaml
- type: cancel_event
  event_id: dragon_attack
```

Removes an event from `scheduled_events` (silent no-op if not found).

### event_triggered
```yaml
precondition:
  type: event_triggered
  event_id: dragon_attack
```

Checks if an event has been triggered (exists in `world.triggered_events`).

### event_not_triggered
```yaml
precondition:
  type: event_not_triggered
  event_id: dragon_attack
```

Checks if an event has NOT been triggered.

## Time-Based Preconditions (NEW in v5)

Gate content by elapsed time since game start.

### time_elapsed_minimum
```yaml
precondition:
  type: time_elapsed_minimum
  amount: 8
  unit: hours
```

Requires at least 8 hours (28800 seconds) to have passed since game start.

### time_elapsed_maximum
```yaml
precondition:
  type: time_elapsed_maximum
  amount: 24
  unit: hours
```

Requires no more than 24 hours to have passed. Useful for time-limited opportunities.

### Time Units

Valid units: `seconds`, `minutes`, `hours`, `days`, `weeks`, `months`, `years`

Conversion to seconds:
- seconds: 1
- minutes: 60
- hours: 3600
- days: 86400
- weeks: 604800
- months: 2592000 (30 days)
- years: 31536000 (365 days)

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
  location_state:              # Per-location mutable state
    village:
      flags:
        quest_completed: true
      properties:
        population: 150
    shrine:
      flags: {}
      properties:
        blessing_power: 75
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
