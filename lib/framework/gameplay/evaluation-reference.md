# Precondition & Consequence Evaluation Reference

Operational tables for evaluating preconditions and applying consequences during gameplay.

> **Schema Reference:** See `scenario-format.md` for all type definitions and YAML syntax.

## Precondition Evaluation

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
| `location_flag_set` | `world.location_state[location].flags[flag] == true` |
| `location_flag_not_set` | `world.location_state[location].flags[flag] != true` |
| `location_property_minimum` | `world.location_state[location].properties[property] >= minimum` |
| `location_property_maximum` | `world.location_state[location].properties[property] <= maximum` |
| `environment_is` | `world.location_state[location].environment[property] == value` |
| `environment_minimum` | `world.location_state[location].environment[property] >= minimum` |
| `environment_maximum` | `world.location_state[location].environment[property] <= maximum` |
| `all_of` | All nested conditions pass |
| `any_of` | At least one nested condition passes |
| `none_of` | No nested conditions pass |
| `npc_at_location` | `world.npc_locations[npc] == resolve_location(location)` |
| `npc_not_at_location` | `world.npc_locations[npc] != resolve_location(location)` |
| `time_elapsed_minimum` | `world.time >= (amount * TIME_UNITS[unit])` |
| `time_elapsed_maximum` | `world.time <= (amount * TIME_UNITS[unit])` |
| `event_triggered` | `event_id in world.triggered_events` |
| `event_not_triggered` | `event_id not in world.triggered_events` |

**Location resolution:** When `location` is `"current"`, resolve to `world.current_location`.

**Lazy defaults:** Missing location state defaults to empty. Missing flags default to `false`, missing properties to `0`.

## Consequence Application

Apply consequences to modify state in memory:

| Type | Action |
|------|--------|
| `gain_item` | Add to `character.inventory` |
| `lose_item` | Remove from `character.inventory` |
| `modify_trait` | `character.traits[trait] += delta` |
| `set_trait` | `character.traits[trait] = value` |
| `set_flag` | `character.flags[flag] = value` |
| `clear_flag` | `character.flags[flag] = false` |
| `move_to` | `world.current_location = location` (+ travel time, see below) |
| `advance_time` | `world.time += amount * TIME_UNITS[unit]` (default unit: hours) |
| `modify_relationship` | `character.relationships[npc] += delta` |
| `character_dies` | `character.exists = false`, add reason to history |
| `character_departs` | `character.exists = false` (transcendence) |
| `add_history` | Append entry to `recent_history` |
| `set_location_flag` | `world.location_state[location].flags[flag] = value` |
| `clear_location_flag` | `world.location_state[location].flags[flag] = false` |
| `modify_location_property` | `world.location_state[location].properties[property] += delta` |
| `set_location_property` | `world.location_state[location].properties[property] = value` |
| `set_environment` | `world.location_state[location].environment[property] = value` |
| `modify_environment` | `world.location_state[location].environment[property] += delta` |
| `move_npc` | `world.npc_locations[npc] = (location == 'current' ? world.current_location : location)` |
| `schedule_event` | Add `{event_id, trigger_at: world.time + delay_seconds, consequences}` to `scheduled_events` |
| `trigger_event` | Find event in `scheduled_events`, apply consequences, move `event_id` to `triggered_events` |
| `cancel_event` | Remove event from `scheduled_events` by `event_id` (silent no-op if not found) |

**Lazy initialization:** Location consequences create `location_state[location]` with empty `flags: {}` and `properties: {}` if missing.

**Location omission:** When `location` is omitted in environment consequences, use `world.current_location`.

## Travel Time Calculation

When `move_to` is applied and `scenario.travel_config` exists:

```
IF scenario.travel_config exists AND consequence.instant != true:
  from_location = world.current_location
  to_location = consequence.location

  # Find connection from current location
  connection = find_connection(from_location, to_location)

  IF connection is object with travel_minutes:
    travel_minutes = connection.travel_minutes
  ELSE:
    travel_minutes = scenario.travel_config.default_travel_minutes

  # Apply travel time
  world.time += travel_minutes * 60

  # Then set new location
  world.current_location = to_location
```

**Finding Connections:**

```
find_connection(from_id, to_id):
  from_location = scenario.initial_world.locations.find(l => l.id == from_id)

  FOR connection IN from_location.connections:
    IF connection is string AND connection == to_id:
      RETURN {target: to_id, travel_minutes: null}  # Use default
    IF connection is object AND connection.target == to_id:
      RETURN connection

  RETURN null  # No direct connection (may be teleport)
```

**Instant Travel:**

When `move_to` has `instant: true`, skip travel time calculation entirely:

```yaml
- type: move_to
  location: dream_realm
  instant: true  # No travel time applied
```

Use `instant: true` for:
- Teleportation
- Dream sequences
- Flashbacks
- Fast travel mechanics

## Improvisation Time Calculation

When processing improvised actions and `scenario.travel_config.improvisation_time` exists:

```
IF scenario.travel_config.improvisation_time exists:
  intent = classify_intent(player_action)  # explore/interact/act/meta/limbo

  IF intent == 'meta':
    time_minutes = 0  # Meta actions never consume time
  ELSE:
    time_minutes = scenario.travel_config.improvisation_time[intent]

  world.time += time_minutes * 60
```

**Intent Classification Defaults:**

| Intent | Default Minutes | When Used |
|--------|-----------------|-----------|
| `explore` | 15 | Examining, studying, inspecting |
| `interact` | 10 | Talking, asking, approaching |
| `act` | 20 | Attempting physical actions |
| `meta` | 0 | Save, help, inventory (always 0) |
| `limbo` | 5 | Ambiguous or hesitant actions |

## Location Access Validation

When evaluating a `move_to` consequence or presenting location-based options:

1. Find target location in `scenario.initial_world.locations[]`
2. If location has `precondition`:
   - Evaluate precondition against current state
   - If FAILS, apply `access_mode`:
     - `filter` (default): Hide the option entirely
     - `show_locked`: Show option with "[Locked]" indicator, disabled
     - `show_normal`: Show normally, fail with message if selected

### Access Denied Display

For `show_normal` mode when access fails:

```
╭──────────────────────────────────────────────────────────────────────╮
│ ACCESS DENIED                                                        │
╰──────────────────────────────────────────────────────────────────────╯

[access_denied_narrative or generated fallback]

You cannot enter [location name].
```

### Location Access Fallback Messages

| Precondition Type | Fallback Template |
|-------------------|-------------------|
| `has_item` | "You need the **[item]** to enter this place." |
| `trait_minimum` | "Your **[trait]** is insufficient to access this location." |
| `flag_set` | "Something must happen before this place opens to you." |
| `environment_is` | "The **[property]** here must be **[value]**." |
| `environment_minimum` | "The **[property]** here is too low." |
| `environment_maximum` | "The **[property]** here is too high." |
| `all_of` | Generate message for first failing sub-condition |

## Blocked Display Format

When a node precondition fails, display:

```
╭──────────────────────────────────────────────────────────────────────╮
│ BLOCKED                                                              │
╰──────────────────────────────────────────────────────────────────────╯

[blocked_narrative or generated fallback]

You remain where you are.
```

The header uses the standard 70-character width with rounded corners.

## Fallback Message Generation

If a node has a `precondition` but no `blocked_narrative`, generate a fallback:

| Precondition Type | Fallback Template |
|-------------------|-------------------|
| `has_item` | "You need the **[item]** to proceed here." |
| `missing_item` | "The **[item]** you carry prevents this path." |
| `trait_minimum` | "Your **[trait]** ([current]) is insufficient. Requires at least [minimum]." |
| `trait_maximum` | "Your **[trait]** ([current]) is too high. Requires [maximum] or less." |
| `flag_set` | "Something must happen before you can proceed." |
| `flag_not_set` | "Your past actions have closed this path." |
| `relationship_minimum` | "Your relationship with **[npc]** ([current]) is insufficient. Requires at least [minimum]." |
| `location_flag_set` | "The **[location]** is not yet prepared for this." |
| `location_flag_not_set` | "Conditions at **[location]** prevent this path." |
| `location_property_minimum` | "The **[property]** at **[location]** is insufficient." |
| `location_property_maximum` | "The **[property]** at **[location]** is too high." |
| `all_of` | Generate message for first failing sub-condition |
| `any_of` | "You need at least one of several requirements." |
| `none_of` | "Your current situation prevents this path." |

### Edge Case: Start Node with Precondition

If `start_node` has a `precondition`, this is a scenario design error. Display:
```
ERROR: Start node cannot have a precondition.
The scenario "[name]" has an invalid configuration.
```
Refuse to start the game.

## Time Unit Constants

Convert time units to seconds for all temporal operations:

| Unit | Seconds |
|------|---------|
| seconds | 1 |
| minutes | 60 |
| hours | 3600 |
| days | 86400 |
| weeks | 604800 |
| months | 2592000 (30 days) |
| years | 31536000 (365 days) |

All temporal values in `world.time` are stored in seconds.
