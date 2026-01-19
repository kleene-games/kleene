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
| `move_to` | `world.current_location = location` |
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
