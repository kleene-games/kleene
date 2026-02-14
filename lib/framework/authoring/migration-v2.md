# Kleene v5 Migration Guide

This guide helps you upgrade existing scenarios to use the new features introduced in Kleene v5 (Phases 1-4).

## Quick Reference

| Feature | Phase | Required? | Backwards Compatible? |
|---------|-------|-----------|----------------------|
| Location State | 1 | No | Yes |
| NPC Location Tracking | 2 | No | Yes |
| Node Preconditions | 2 | No | Yes |
| Location Preconditions | 3 | No | Yes |
| Scheduled Events | 4 | No | Yes |
| Time-Based Gating | 4 | No | Yes |
| Improvisation Routing | 4 | No | Yes |

All features are **additive** - existing v4 scenarios work without modification.

---

## Phase 1: Location State

Track mutable state per-location (flags, properties, environment).

### Before (v4)

```yaml
initial_world:
  current_location: village
  flags:
    village_quest_completed: true  # Global flag
```

### After (v5)

```yaml
initial_world:
  current_location: village
  flags: {}  # Keep global flags for cross-cutting concerns

  # NEW: Per-location mutable state
  location_state:
    village:
      flags:
        quest_completed: true  # Location-specific
      properties:
        population: 150
    shrine:
      flags: {}
      properties:
        blessing_power: 75
```

### Using Location State in Preconditions

```yaml
# Before: Global flag check
precondition:
  type: flag_set
  flag: village_quest_completed

# After: Location-specific flag check
precondition:
  type: location_flag_set
  location: village
  flag: quest_completed
```

### Using Location State in Consequences

```yaml
consequence:
  # Set location flag
  - type: set_location_flag
    location: village
    flag: quest_completed
    value: true

  # Modify location property
  - type: modify_location_property
    location: village
    property: population
    delta: -10
```

---

## Phase 2: NPC Location Tracking

Track where NPCs are and gate options based on their presence.

### Before (v4)

```yaml
# No NPC tracking - relied on flags
initial_character:
  flags:
    met_guardian: false

# Option checked flag
options:
  - id: speak_guardian
    precondition:
      type: flag_set
      flag: guardian_present  # Had to manually manage
```

### After (v5)

```yaml
initial_world:
  current_location: village

  # NEW: Track NPC positions
  npc_locations:
    guardian: temple_gates
    merchant: market
    oracle: temple_interior
```

### Using NPC Location in Preconditions

```yaml
options:
  - id: speak_guardian
    text: "Speak with the guardian"
    # NEW: Checks NPC location directly
    precondition:
      type: npc_at_location
      npc: guardian
      location: current  # "current" = player's location
```

### Moving NPCs

```yaml
consequence:
  - type: move_npc
    npc: guardian
    location: temple_interior  # Or "current" for player's location
```

---

## Phase 2: Node Preconditions

Gate entire nodes, not just options within them.

### Before (v4)

```yaml
nodes:
  dragon_lair:
    narrative: "You enter the dragon's lair..."
    choice:
      options:
        # Every option had to check the precondition
        - id: explore
          precondition:
            type: has_item
            item: dragon_scale
          text: "Explore"
          next_node: explore_lair
```

### After (v5)

```yaml
nodes:
  dragon_lair:
    # NEW: Node-level precondition
    precondition:
      type: all_of
      conditions:
        - type: has_item
          item: dragon_scale
        - type: trait_minimum
          trait: courage
          minimum: 10

    # NEW: What to show when blocked
    blocked_narrative: |
      The lair's entrance pulses with ancient wards.
      Without proof of dragon-kind and sufficient bravery,
      you cannot pass.

    narrative: "You enter the dragon's lair..."
    choice:
      options:
        # Options no longer need the precondition
        - id: explore
          text: "Explore"
          next_node: explore_lair
```

### Behavior Change

When the player's choice leads to a blocked node:
- Turn counter does NOT increment
- `blocked_narrative` is shown
- Previous node's choices are re-presented

---

## Phase 3: Location Preconditions

Gate locations themselves, not just nodes at those locations.

### Before (v4)

```yaml
# Had to check at every node referencing the location
nodes:
  approach_shrine:
    choice:
      options:
        - id: enter
          precondition:
            type: has_item
            item: shrine_key
          consequence:
            - type: move_to
              location: shrine
          next_node: shrine_interior
```

### After (v5)

```yaml
initial_world:
  locations:
    - id: shrine
      name: "Ancient Shrine"

      # NEW: Location-level precondition
      precondition:
        type: all_of
        conditions:
          - type: has_item
            item: shrine_key
          - type: flag_set
            flag: elder_blessing

      # NEW: What to show when access denied
      access_denied_narrative: |
        The shrine's ancient wards shimmer before you.
        Without the proper key and blessing, the way is sealed.

      # NEW: How to display locked location
      access_mode: show_locked  # filter | show_locked | show_normal
```

### Access Modes

| Mode | Behavior |
|------|----------|
| `filter` | Hide from options (default, backwards compatible) |
| `show_locked` | Show with "[Locked]" indicator |
| `show_normal` | Show normally, explain on failed attempt |

---

## Phase 4: Scheduled Events

Schedule future consequences based on time passage.

### Before (v4)

```yaml
# No built-in time/event system
# Had to track manually with flags
```

### After (v5)

```yaml
initial_world:
  time: 0
  scheduled_events: []  # Or pre-schedule events
  triggered_events: []
```

### Scheduling Events in Consequences

```yaml
consequence:
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

### Checking Event Status

```yaml
# Has the event triggered?
precondition:
  type: event_triggered
  event_id: dragon_attack

# Has the event NOT triggered?
precondition:
  type: event_not_triggered
  event_id: dragon_attack
```

### Triggering and Cancelling Events

```yaml
consequence:
  # Trigger immediately (bypasses time delay)
  - type: trigger_event
    event_id: dragon_attack

  # Cancel a scheduled event
  - type: cancel_event
    event_id: dragon_attack
```

---

## Phase 4: Time-Based Gating

Gate content based on elapsed game time.

### Before (v4)

```yaml
# No time tracking
```

### After (v5)

```yaml
initial_world:
  time: 0  # Time in seconds (0 = game start)
```

### Advancing Time

```yaml
consequence:
  - type: advance_time
    amount: 2
    unit: hours  # seconds, minutes, hours, days, weeks, months, years
```

### Time Preconditions

```yaml
# Require minimum time passed
precondition:
  type: time_elapsed_minimum
  amount: 8
  unit: hours

# Require maximum time (deadline)
precondition:
  type: time_elapsed_maximum
  amount: 24
  unit: hours
```

### Pre-Scheduling Events in initial_world

```yaml
initial_world:
  time: 28800  # Start at 8 AM (8 * 3600 seconds)

  scheduled_events:
    - event_id: noon_bells
      trigger_at: 43200  # 12 PM in seconds
      consequences:
        - type: set_flag
          flag: past_noon
          value: true

    - event_id: market_closes
      trigger_at: 61200  # 5 PM
      consequences:
        - type: set_flag
          flag: market_closed
          value: true
```

---

## Phase 4: Improvisation Routing

Create scripted paths for the "Unknown" row with pattern-matched outcomes.

### Before (v4)

```yaml
options:
  - id: observe
    text: "Wait and observe"
    next_node: observation_result  # Fixed outcome
```

### After (v5)

```yaml
options:
  - id: observe
    text: "Wait and observe"
    cell: unknown  # Indicates Unknown row
    next: improvise  # Triggers freeform input

    improvise_context:
      theme: "observing the dragon"
      permits: ["patience", "learn", "watch", "study"]  # → Discovery
      blocks: ["attack", "steal", "trick", "provoke"]   # → Constraint
      limbo_fallback: "Time stretches in the dragon's presence..."

    outcome_nodes:
      discovery: dragon_notices_patience
      constraint: dragon_dismisses
      # limbo: omitted = stay at current node
```

### How Pattern Matching Works

1. Player selects improvise option
2. Freeform text input requested
3. System checks input against `permits` patterns
4. System checks input against `blocks` patterns
5. Route to appropriate outcome:
   - Matches `permits` → `outcome_nodes.discovery`
   - Matches `blocks` → `outcome_nodes.constraint`
   - No match → stay at current node (Limbo)

---

## Save Format Migration

### v4 Save Format

```yaml
scenario: dragon_quest
current_node: forest_entrance
turn: 3

character:
  name: "Wanderer"
  exists: true
  traits: { courage: 6, wisdom: 7 }
  inventory: [rusty_sword]
  flags: { shrine_visited: true }

world:
  current_location: forest
  time: 3
  flags: { dragon_alive: true }

history:
  - "Some(hero enters)"
  - "Some(took sword)"

game_over: false
ending_type: null
```

### v5 Save Format

```yaml
scenario: dragon_quest
current_node: forest_entrance
turn: 3

character:
  name: "Wanderer"
  exists: true
  traits: { courage: 6, wisdom: 7 }
  inventory: [rusty_sword]
  relationships: { elder: 5 }  # May be present in v4
  flags: { shrine_visited: true }

world:
  current_location: forest
  time: 10800  # Now in seconds

  # NEW in v5
  npc_locations:
    guardian: temple_gates
    elder: village

  # NEW in v5
  scheduled_events:
    - event_id: dragon_attack
      trigger_at: 86400
      consequences: [...]

  # NEW in v5
  triggered_events:
    - guardian_moves

  flags: { dragon_alive: true }

  # NEW in v5
  location_state:
    village:
      flags: { quest_completed: true }
      properties: { population: 150 }

  locations: [...]

history:
  - "Some(hero enters)"
  - "Some(took sword)"

game_over: false
ending_type: null
```

### Automatic Migration

The play skill automatically upgrades v4 saves when loaded:
- Adds missing `npc_locations: {}`
- Adds missing `scheduled_events: []`
- Adds missing `triggered_events: []`
- Adds missing `location_state: {}`
- Converts time if needed

---

## Backwards Compatibility Notes

1. **All v4 scenarios work unchanged** - new features are additive
2. **New saves load in old code** - missing fields gracefully ignored
3. **Time conversion** - if `world.time` is a small integer (< 1000), treat as legacy turns
4. **NPC references to undefined NPCs** - preconditions fail gracefully (NPC considered "offscreen")
5. **Location flags for undefined locations** - lazy initialization creates the state

---

## Checklist for Upgrading a Scenario

- [ ] Add `npc_locations` to `initial_world` if NPCs are important
- [ ] Convert global flags to `location_state` flags where appropriate
- [ ] Add node `precondition` and `blocked_narrative` for gated areas
- [ ] Add location `precondition` and `access_denied_narrative` for locked areas
- [ ] Replace manual flag tracking with `schedule_event` for timed effects
- [ ] Add `advance_time` consequences for realistic time passage
- [ ] Convert "observe" type options to use `next: improvise` with outcomes
- [ ] Run `/kleene analyze` to validate the upgraded scenario

---

## See Also

- [Scenario Format](../framework/scenario-format.md) - Complete YAML reference
- [Best Practices](./best-practices.md) - Design patterns for v5 features
- [Templates](../../lib/framework/authoring/TEMPLATES/) - Example scenarios demonstrating features
