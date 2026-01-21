# Analysis Validation Guide

Comprehensive validation checklists for Kleene scenarios, organized by validation type and severity.

## Validation Types Overview

| Type | Purpose | When to Run |
|------|---------|-------------|
| Schema | Required fields, types, references | Always (fast) |
| Structural | Graph integrity, reachability | Full analysis |
| Semantic | Game logic, obtainability | Deep analysis |
| v5 Features | Location, NPC, temporal systems | If v5 features used |
| Narrative | Completeness, player experience | Final review |

## Schema Validation Checklist

Validates YAML structure against the scenario schema specification.

### Required Structure

| Check | Severity | Condition |
|-------|----------|-----------|
| Required fields present | Error | `name`, `start_node`, `nodes`, `endings` all exist |
| `start_node` exists | Error | `start_node` value found in `nodes` |
| `next_node` references valid | Error | All `next_node` values exist in `nodes` or `endings` |
| `blocked_next_node` valid | Error | All `blocked_next_node` values exist in `nodes` or `endings` |

### Type Validation

| Check | Severity | Condition |
|-------|----------|-----------|
| Precondition types valid | Warning | All `.precondition.type` values are known types |
| Consequence types valid | Warning | All `.consequence[].type` values are known types |
| Options have required fields | Error | All options have `id` and `text` fields |
| `blocked_next_node` has precondition | Warning | Node with `blocked_next_node` has `.precondition` |

### Valid Precondition Types

```
has_item, missing_item, trait_minimum, trait_maximum, flag_set, flag_not_set,
at_location, relationship_minimum, all_of, any_of, none_of,
location_flag_set, location_flag_not_set, location_property_minimum,
location_property_maximum, npc_at_location, npc_not_at_location,
event_triggered, event_not_triggered, time_elapsed_minimum, time_elapsed_maximum,
environment_is, environment_minimum, environment_maximum
```

### Valid Consequence Types

```
gain_item, lose_item, modify_trait, set_trait, set_flag, clear_flag,
modify_relationship, move_to, advance_time, character_dies, character_departs,
add_history, set_location_flag, clear_location_flag, modify_location_property,
set_location_property, move_npc, schedule_event, trigger_event, cancel_event,
set_environment, modify_environment
```

### on_enter Validation

| Check | Severity | Condition |
|-------|----------|-----------|
| `on_enter` consequence types valid | Warning | All `.on_enter[].type` values are known types |
| `on_enter` items valid | Info | Items in `on_enter` are obtainable elsewhere |

## Structural Validation Checklist

Validates graph integrity and navigability.

| Check | Severity | Condition |
|-------|----------|-----------|
| All nodes reachable | Warning | Every node reachable from `start_node` (or via improvisation) |
| No dead ends | Warning | Non-ending nodes have at least one valid exit |
| All endings reachable | Warning | At least one path exists to each ending |
| No orphan nodes | Warning | Every node has at least one incoming edge (except `start_node`) |

### Reachability Notes

Distinguish between:
- **Static reachability**: Via `next_node` edges
- **Dynamic reachability**: Via improvisation `outcome_nodes`

Nodes only reachable via improvisation should be flagged as "conditionally reachable" not "unreachable".

## Semantic Validation Checklist

Validates game logic and playability.

| Check | Severity | Condition |
|-------|----------|-----------|
| Required items obtainable | Error | Every `has_item` precondition item can be gained somewhere |
| Required flags settable | Error | Every `flag_set` precondition flag can be set somewhere |
| Trait requirements achievable | Warning | Max achievable trait value >= highest requirement |
| At least one ending always reachable | Error | A path exists with no preconditions to at least one ending |

### Item Obtainability

For each item required by `has_item` preconditions:
1. Search for `gain_item` consequences with that item
2. If found, verify the gaining node is reachable before the requiring node
3. If not found, flag as **Error**

### Flag Dependencies

For each flag checked:
- `flag_set` preconditions: Verify a `set_flag` consequence exists
- `flag_not_set` preconditions: Verify the flag isn't always set before this point

### Trait Balance

For each trait:
1. Calculate maximum achievable value: `starting + sum(positive_deltas)`
2. Calculate minimum achievable value: `starting + sum(negative_deltas)`
3. Compare against `trait_minimum` and `trait_maximum` requirements

## v5 Feature Validation Checklist

For scenarios using v5 features (location state, NPCs, temporal events, travel).

### Location State

| Check | Severity | Condition |
|-------|----------|-----------|
| Location flags checked are set | Warning | Every `location_flag_set` check has matching `set_location_flag` |
| Location properties checked exist | Warning | Every `location_property_*` check has matching modification |

### Node Preconditions

| Check | Severity | Condition |
|-------|----------|-----------|
| Gated nodes have blocked_narrative | Warning | Nodes with `.precondition` should have `.blocked_narrative` |

### NPC Tracking

| Check | Severity | Condition |
|-------|----------|-----------|
| NPCs referenced are defined | Warning | NPCs in preconditions exist in `initial_world.npc_locations` |
| NPCs moved are checked | Info | NPCs with `move_npc` consequences are used in preconditions |
| NPCs checked are defined | Error | NPCs in `npc_at_location` exist in `npc_locations` |

### Temporal/Event System

| Check | Severity | Condition |
|-------|----------|-----------|
| Scheduled events are checked | Warning | Events in `schedule_event` have matching `event_triggered` checks |
| Event preconditions reference real events | Error | `event_triggered` checks reference scheduled events |
| Time preconditions achievable | Warning | `time_elapsed_minimum` can be reached via `advance_time` |

### Travel Consistency

| Check | Severity | Condition |
|-------|----------|-----------|
| Travel config complete | Info | `travel_config` exists if scenario uses time |
| Connections have travel time | Warning | Object-syntax connections have `travel_minutes` or use default |
| Bidirectional times consistent | Warning | A→B and B→A times differ by <50% (unless intentionally asymmetric) |
| Event reachability under time | Error | Time-gated events are reachable within their trigger time |
| Improvisation time configured | Info | All 5 intent types have time configured |

### Improvisation Coverage

| Check | Severity | Condition |
|-------|----------|-----------|
| `outcome_nodes` reference valid nodes | Error | All nodes in `outcome_nodes.*` exist |
| Permits/blocks patterns defined | Info | `improvise_context.permits` and `.blocks` are non-empty arrays |

## Narrative Validation Checklist

Validates completeness and player experience.

| Check | Severity | Condition |
|-------|----------|-----------|
| Death path exists | Warning | At least one path leads to `NONE_DEATH` |
| Victory path exists | Warning | At least one path leads to `SOME_TRANSFORMED` |
| Multiple meaningful choices | Info | Most nodes have 2+ options with different outcomes |
| No single-option "choices" | Warning | Nodes with 1 option either have `next: improvise` or are explicitly designed |

## Interpreting Results

### Severity Levels

| Level | Action Required |
|-------|-----------------|
| **Error** | Must fix before scenario is playable |
| **Warning** | Should fix for good player experience |
| **Info** | May be intentional design choice |

### Common Issues and Fixes

**Error: Item never obtainable**
- Add a `gain_item` consequence somewhere reachable before the requirement
- Or remove the `has_item` precondition

**Warning: Flag set but never checked**
- Remove unused flag or add a precondition that uses it
- May be intentional for history/flavor

**Warning: Trait can only increase/decrease**
- Add balancing consequences
- Or document as intentional (corruption/purity systems)

**Warning: Single-option node**
- Add alternative options (retreat, explore, wait)
- Or add `next: improvise` to allow player creativity
- Or mark as intentional chokepoint

**Warning: Railroad detected**
- Add branching options to middle nodes
- Or accept as narrative beat (tension building)

**Warning: Missing blocked_narrative**
- Add narrative text explaining why node is inaccessible
- Improves player experience when preconditions fail

## Quick Reference

### Minimum Viable Scenario

For a valid Bronze-tier scenario:
- [ ] 4 required fields present
- [ ] All references valid
- [ ] All items/flags obtainable
- [ ] 4 corner cells covered (Triumph, Rebuff, Escape, Fate)
- [ ] At least one death path
- [ ] At least one victory path
- [ ] No single-option dead ends

### Full Validation Order

1. **Schema** - Fast, catches structural errors
2. **Structural** - Graph integrity
3. **Semantic** - Game logic
4. **v5 Features** - If applicable
5. **Narrative** - Final review
