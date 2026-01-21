# YAML Extraction Patterns

Templates for extracting scenario data using yq 4.x, with grep fallbacks.

## Header Extraction

### yq Template: Game Initialization

Extract only the fields needed to start a game (~75% token reduction vs 200-line read):

```bash
yq '{"name": .name, "start_node": .start_node, "initial_character": .initial_character, "initial_world": .initial_world, "ending_ids": [.endings | keys | .[]]}' scenario.yaml
```

**Output:** Structured YAML with just the initialization data.

### grep Fallback: Header

```bash
# Read first 200 lines for header
Read scenario.yaml with limit: 200
```

Parse the output to extract `name`, `initial_character`, `initial_world`, `start_node`, and `endings` keys.

---

## Node Extraction

### yq Template: Single Node

Extract a specific node by ID:

```bash
yq '.nodes.NODE_ID' scenario.yaml
```

Replace `NODE_ID` with the actual node identifier (e.g., `dragon_fight`).

### yq Template: Turn Context (Structured)

Get current node with all fields formatted for game turn:

```bash
yq '.nodes.NODE_ID as $n | {"narrative": $n.narrative, "prompt": $n.choice.prompt, "options": [$n.choice.options[] | {"id": .id, "text": .text, "cell": .cell, "precondition": .precondition, "next_node": .next_node, "has_improvise": (.next == "improvise"), "outcome_nodes": .outcome_nodes}]}' scenario.yaml
```

### grep Fallback: Node

```bash
Grep pattern: "^  NODE_ID:"
Context: -A 80
Path: scenario.yaml
```

Parse YAML from grep output. Note: May include extra content or truncate long nodes.

---

## Improvise Prefetch

### yq Template: Prefetch Outcome Nodes

When an option has `next: improvise`, prefetch both potential outcome nodes in one query:

```bash
yq '.nodes as $all | .nodes.NODE_ID.choice.options[] | select(.next == "improvise") | .outcome_nodes | to_entries | .[] | {"cell": .key, "node": $all[.value]}' scenario.yaml
```

**Output:** Both discovery and constraint nodes (if specified) in a single query.

### grep Fallback: Multiple Greps

```bash
# Grep for discovery node
Grep pattern: "^  DISCOVERY_NODE_ID:"
Context: -A 80

# Grep for constraint node
Grep pattern: "^  CONSTRAINT_NODE_ID:"
Context: -A 80
```

Two separate queries required.

---

## Analysis Patterns (kleene-analyze)

### yq Template: Graph Structure (No Narratives)

Extract only structural data for graph building:

```bash
yq '.nodes | to_entries | .[] | {"node": .key, "options": [.value.choice.options[] | {"id": .id, "cell": .cell, "next": (.next_node // .next), "precondition": .precondition}]}' scenario.yaml
```

**Benefit:** Skips narrative text (~60% of each node's content).

### yq Template: Cell Coverage Report

Count options by cell type:

```bash
yq '[.nodes | to_entries | .[] | .value.choice.options[] | select(.cell)] | group_by(.cell) | .[] | {"cell": .[0].cell, "count": length}' scenario.yaml
```

**Output:**
```yaml
cell: chooses
count: 12
---
cell: avoids
count: 5
---
cell: unknown
count: 3
```

### yq Template: Precondition Dependency Map

Find all options requiring specific preconditions:

```bash
yq '.nodes | to_entries | .[] | .value.choice.options[] | select(.precondition) | {"node": (parent | parent | parent | .key), "option": .id, "requires": .precondition}' scenario.yaml
```

**Note:** This query is impossible with grep - new capability enabled by yq.

### yq Template: Item Dependencies

Find all nodes requiring a specific item:

```bash
yq '.nodes | to_entries | .[] | select(.value.choice.options[].precondition.item == "ITEM_NAME") | {"node": .key, "requires": "ITEM_NAME"}' scenario.yaml
```

---

## Registry Patterns (commands/kleene.md)

### yq Template: Scenario Menu Data

Extract enabled scenarios for menu display:

```bash
yq '.scenarios | to_entries | .[] | select(.value.enabled) | {"id": .key, "name": .value.name, "description": .value.description, "path": .value.path}' registry.yaml
```

### yq Template: Scenario Stats Extraction

Extract stats for registry caching:

```bash
yq '{"node_count": (.nodes | length), "ending_count": (.endings | length), "cells": [.nodes[].choice.options[] | select(.cell) | .cell] | unique}' scenario.yaml
```

---

## Save Patterns

### yq Template: Save Metadata Batch

Extract metadata from multiple save files:

```bash
for f in ./saves/SCENARIO/*.yaml; do
  yq --arg file "$f" '{"file": $file, "turn": .turn, "node": .current_node, "saved": .last_saved}' "$f"
done
```

### yq Template: Node Preview for Save Caching

Extract node title and preview at save time:

```bash
yq '.nodes.NODE_ID | {"title": (.title // ("Node: " + "NODE_ID")), "preview": (.narrative | split("\n") | map(select(. != "")) | .[0])}' scenario.yaml
```

---

## Destination Preview (Multi-Hop)

### yq Template: Options with Destination Previews

Get options with first line of destination narratives:

```bash
yq '.nodes as $all | .nodes.NODE_ID.choice.options[] | select(.next_node) | {"option_text": .text, "dest_id": .next_node, "dest_preview": ($all[.next_node].narrative | split("\n")[0])}' scenario.yaml
```

**Output:**
```yaml
option_text: "Draw your sword and fight!"
dest_id: dragon_fight
dest_preview: The battle is fierce. Fire and steel clash in the mountain air.
```

---

## Token Usage Comparison

| Query Type | grep -A 80 | yq Templated |
|------------|------------|--------------|
| Single node | ~80 lines | ~15-30 lines |
| Turn context | ~80 lines + manual parsing | ~40 lines, structured |
| Node + destinations | Multiple queries | Single query |
| Item dependency graph | Impossible | One query |
| Ending IDs | ~60 lines | 4 lines |
| Cell coverage | Manual grep + parsing | One query |

---

## Usage Notes

1. **Replace placeholders:** `NODE_ID`, `ITEM_NAME`, `SCENARIO` with actual values
2. **Error handling:** If yq fails, silently fall back to grep equivalent
3. **Small files:** Don't use lazy loading for files that fit in context
4. **yq version:** These templates require yq 4.x (Mike Farah's Go version)

---

## Deep Analysis Queries

These queries provide structural analysis capabilities impossible with grep. Used by kleene-analyze for comprehensive scenario validation.

### Cycle Detection

Find self-loops and multi-node cycles:

```bash
# Self-loops (node points to itself)
yq '.nodes | to_entries | .[] | {"node": .key, "dests": [.value.choice.options[] | (.next_node // .next)]} | select(.dests[] == .node)' scenario.yaml

# Build adjacency for multi-node cycle detection
yq '.nodes | to_entries | .[] | {"node": .key, "destinations": [.value.choice.options[] | (.next_node // .next)] | unique}' scenario.yaml
```

**Output Format:**
```
CYCLE DETECTION
───────────────
! Self-loop: tavern → tavern (via "have another drink")
! Loop: village → forest → clearing → village (3 nodes)
✓ No inescapable cycles detected
```

### Item Obtainability

Verify required items can be obtained:

```bash
# Items that can be gained
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | .consequence[]? | select(.type == "gain_item") | .item] | unique | .[]' scenario.yaml

# Items required by preconditions
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | .precondition? | select(.type == "has_item") | .item] | unique | .[]' scenario.yaml

# Where each item is obtained
yq '.nodes | to_entries | .[] as $entry | $entry.value.choice.options[]? | select(.consequence[]?.type == "gain_item") | {"node": $entry.key, "option": .id, "gains": [.consequence[] | select(.type == "gain_item") | .item]}' scenario.yaml
```

**Output Format:**
```
ITEM OBTAINABILITY
──────────────────
Obtainable: sword, key, torch, scroll
Required:   sword, key, dragon_scale

✓ sword: Obtained at intro/take_sword
✓ key: Obtained at cellar/find_key
✗ dragon_scale: NEVER OBTAINABLE
  Required at: mountain_peak/use_scale
```

### Trait Balance

Analyze trait modifications and requirements:

```bash
# All trait modifications grouped by trait
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | .consequence[]? | select(.type == "modify_trait")] | group_by(.trait) | .[] | {trait: .[0].trait, deltas: [.[].delta], total_positive: ([.[].delta | select(. > 0)] | add // 0), total_negative: ([.[].delta | select(. < 0)] | add // 0)}' scenario.yaml

# Trait requirements
yq '.nodes | to_entries | .[] as $entry | $entry.value.choice.options[]? | select(.precondition?.type == "trait_minimum") | {"node": $entry.key, "option": .id, "trait": .precondition.trait, "minimum": .precondition.minimum}' scenario.yaml

# Starting traits
yq '.initial_character.traits' scenario.yaml
```

**Output Format:**
```
TRAIT BALANCE
─────────────
courage (starting: 5):
  Gains possible: +6 (max achievable: 11)
  Losses possible: -3 (min achievable: 2)
  ✓ All requirements satisfiable

corruption (starting: 0):
  Gains possible: +10
  Losses possible: 0
  ⚠ Can only increase (no redemption path)
```

### Flag Dependencies

Find unused or unobtainable flags:

```bash
# Flags that get set
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | .consequence[]? | select(.type == "set_flag") | .flag] | unique | .[]' scenario.yaml

# Flags checked in preconditions
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | .precondition? | select(.type == "flag_set" or .type == "flag_not_set") | .flag] | unique | .[]' scenario.yaml

# Where flags are set
yq '.nodes | to_entries | .[] as $entry | $entry.value.choice.options[]? | select(.consequence[]?.type == "set_flag") | {"node": $entry.key, "option": .id, "sets": [.consequence[] | select(.type == "set_flag") | .flag]}' scenario.yaml
```

**Output Format:**
```
FLAG DEPENDENCIES
─────────────────
Set flags:     met_elder, found_secret, betrayed_ally
Checked flags: met_elder, found_secret, knows_truth

✓ met_elder: Set at village/talk_elder
⚠ betrayed_ally: Set but never checked
✗ knows_truth: Required but never set
```

### Relationship Network

Map NPC relationship dynamics:

```bash
# All relationship changes grouped by NPC
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | .consequence[]? | select(.type == "modify_relationship")] | group_by(.npc) | .[] | {npc: .[0].npc, changes: [.[].delta], can_improve: ([.[].delta] | any(. > 0)), can_worsen: ([.[].delta] | any(. < 0))}' scenario.yaml

# Starting relationships
yq '.initial_character.relationships // {}' scenario.yaml
```

**Output Format:**
```
RELATIONSHIP NETWORK
────────────────────
elder (starting: 0):
  Changes: +5, +3, -2
  ✓ Can improve and worsen

villain (starting: -10):
  Changes: -5, -10, -15
  ⚠ Can only worsen (no redemption)
```

### Consequence Magnitude

Check consequence scaling follows guidelines:

```bash
# All trait/relationship modifications with context
yq '.nodes | to_entries | .[] as $node | $node.value.choice.options[]? | select(.consequence) | {"node": $node.key, "option": .id, "changes": [.consequence[] | select(.type == "modify_trait" or .type == "modify_relationship") | {"type": .type, "target": (.trait // .npc), "delta": .delta}]}' scenario.yaml
```

**Guidelines:**
- ±1-3: Minor/improvised actions
- ±5-10: Major scripted decisions
- ±15-50: Catastrophic events

**Output Format:**
```
CONSEQUENCE MAGNITUDE
─────────────────────
⚠ Oversized: village/help_stranger → courage +15
⚠ Undersized: climax/betray_mentor → trust -2

Distribution: ±1-3: 72%, ±5-10: 19%, ±15+: 8%
```

### Scene Pacing

Analyze scene break distribution:

```bash
# Explicit scene breaks
yq '[.nodes | to_entries | .[] | select(.value.scene_break == true) | .key] | .[]' scenario.yaml

# Auto-break triggers (location changes)
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | .consequence[]? | select(.type == "move_to")] | length' scenario.yaml

# Auto-break triggers (time advances)
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | .consequence[]? | select(.type == "advance_time")] | length' scenario.yaml
```

**Output Format:**
```
SCENE PACING
────────────
Explicit scene_break: 3 nodes
Auto-breaks: 8 move_to, 4 advance_time

⚠ Longest sequence without break: 5 nodes
  intro → sword → training → practice → test
```

### Path Diversity

Analyze branching quality:

```bash
# Options per node and unique destinations
yq '.nodes | to_entries | .[] | {"node": .key, "options": (.value.choice.options | length), "unique_dests": ([.value.choice.options[] | (.next_node // .next)] | unique | length)}' scenario.yaml

# False choices (multiple options → same destination)
yq '.nodes | to_entries | .[] | {"node": .key, "options": [.value.choice.options[] | {"id": .id, "dest": (.next_node // .next)}]} | select((.options | map(.dest) | unique | length) < (.options | length))' scenario.yaml
```

**Output Format:**
```
PATH DIVERSITY
──────────────
Average branching: 2.3 options/node

False choices:
  ⚠ village_square: 3 options → tavern

Railroads (single path):
  ! intro → sword → training (3 nodes)
```

### Ending Reachability

Verify all endings have paths:

```bash
# All defined endings
yq '.endings | keys | .[]' scenario.yaml

# Endings referenced by nodes
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | .next_node? | select(. and (. | test("^ending")))] | unique | .[]' scenario.yaml
```

**Output Format:**
```
ENDING REACHABILITY
───────────────────
Defined: 6 endings
Reachable: 5 endings

✗ ending_secret: No path found
```

### Reachability Analysis

Distinguish static and dynamic edges:

```bash
# All nodes reachable via improvisation
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | select(.next == "improvise") | .outcome_nodes | to_entries | .[] | .value] | flatten | unique | .[]' scenario.yaml
```

**Output Format:**
```
REACHABILITY ANALYSIS
─────────────────────
Static reachable: [intro, sword_taken, forest_entrance, ...]
Conditionally reachable (via improvisation): [guardian_respect, guardian_dismissal, elder_lore, elder_silence]
Unreachable: [orphan_node_1]
```

### Single-Option Node Detection

Find potentially problematic single-option choices:

```bash
# Nodes with only one option
yq '.nodes | to_entries | .[] | select(.value.choice.options | length == 1) | {"node": .key, "option": .value.choice.options[0].text, "next": (.value.choice.options[0].next_node // .value.choice.options[0].next)}' scenario.yaml
```

**Severity Classification:**
- **Error**: 1 option + not an ending + no `next: improvise`
- **Warning**: 1 option + has `next: improvise` (improvable via "Other")
- **OK**: Ending node or special context

---

## v5 Feature Queries

Queries for v5 features: location state, NPC tracking, temporal events, travel system.

### Location State Validation

```bash
# Location flags that get set
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | .consequence[]? | select(.type == "set_location_flag") | {location: .location, flag: .flag}] | unique | .[]' scenario.yaml

# Location flags checked in preconditions
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | .precondition? | select(.type | test("location_flag")) | {location: .location, flag: .flag}] | unique | .[]' scenario.yaml

# Location properties modified
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | .consequence[]? | select(.type | test("location_property")) | {location: .location, property: .property}] | unique | .[]' scenario.yaml

# Location properties checked
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | .precondition? | select(.type | test("location_property")) | {location: .location, property: .property}] | unique | .[]' scenario.yaml

# Environment changes
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | .consequence[]? | select(.type | test("environment"))] | unique | .[]' scenario.yaml
```

### Node Precondition Validation

```bash
# Nodes with preconditions
yq '[.nodes | to_entries | .[] | select(.value.precondition) | .key] | .[]' scenario.yaml

# Nodes with preconditions but missing blocked_narrative
yq '.nodes | to_entries | .[] | select(.value.precondition and (.value.blocked_narrative | not)) | .key' scenario.yaml

# Check precondition types used in node gating
yq '[.nodes | to_entries | .[] | select(.value.precondition) | {node: .key, precondition_type: .value.precondition.type}] | .[]' scenario.yaml
```

### NPC Location Validation

```bash
# NPCs defined in initial_world
yq '.initial_world.npc_locations | keys | .[]' scenario.yaml

# NPCs moved via consequences
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | .consequence[]? | select(.type == "move_npc") | .npc] | unique | .[]' scenario.yaml

# NPCs checked in preconditions
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | .precondition? | select(.type | test("npc_")) | .npc] | unique | .[]' scenario.yaml

# NPCs moved via scheduled events
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | .consequence[]? | select(.type == "schedule_event") | .consequences[]? | select(.type == "move_npc") | .npc] | unique | .[]' scenario.yaml
```

### Temporal/Event Validation

```bash
# Events scheduled
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | .consequence[]? | select(.type == "schedule_event") | .event_id] | unique | .[]' scenario.yaml

# Events triggered manually
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | .consequence[]? | select(.type == "trigger_event") | .event_id] | unique | .[]' scenario.yaml

# Events cancelled
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | .consequence[]? | select(.type == "cancel_event") | .event_id] | unique | .[]' scenario.yaml

# Events checked in preconditions
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | .precondition? | select(.type | test("event_")) | .event_id] | unique | .[]' scenario.yaml

# Time-based preconditions
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | .precondition? | select(.type | test("time_elapsed"))] | length' scenario.yaml

# Time advancements
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | .consequence[]? | select(.type == "advance_time")] | length' scenario.yaml
```

### Travel Consistency Validation

```bash
# Check if travel_config exists
yq '.travel_config // "none"' scenario.yaml

# Get all connections with travel times
yq '[.initial_world.locations[] | {location: .id, connections: .connections}]' scenario.yaml

# Find connections missing travel_minutes (object syntax only)
yq '.initial_world.locations[] | {"location": .id, "missing": [.connections[]? | select(type == "object" and .travel_minutes == null) | .target]}' scenario.yaml

# Get improvisation time config
yq '.travel_config.improvisation_time // "not configured"' scenario.yaml

# Check bidirectional consistency
yq '.initial_world.locations as $locs | $locs[] | . as $from | .connections[]? | select(type == "object") | {"from": $from.id, "to": .target, "minutes": .travel_minutes}' scenario.yaml

# Build bidirectional comparison
yq '
  .initial_world.locations as $locs |
  [
    $locs[] | . as $from |
    .connections[]? |
    (if type == "object" then {"target": .target, "minutes": .travel_minutes} else {"target": ., "minutes": null} end) |
    {from: $from.id, to: .target, minutes}
  ] |
  group_by([.from, .to] | sort) |
  .[] | select(length == 2) |
  {
    pair: "\(.[0].from)↔\(.[0].to)",
    forward: .[0].minutes,
    backward: .[1].minutes,
    symmetric: (.[0].minutes == .[1].minutes)
  }
' scenario.yaml
```

### Improvisation Coverage Analysis

```bash
# Find all improvise options
yq '.nodes | to_entries | .[] | {node: .key, options: [.value.choice.options[] | select(.next == "improvise") | {id: .id, theme: .improvise_context.theme, permits: .improvise_context.permits, blocks: .improvise_context.blocks, outcomes: .outcome_nodes}]}' scenario.yaml

# Aggregate all permits patterns
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | select(.next == "improvise") | .improvise_context.permits[]?] | flatten | unique | .[]' scenario.yaml

# Aggregate all blocks patterns
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | select(.next == "improvise") | .improvise_context.blocks[]?] | flatten | unique | .[]' scenario.yaml
```

---

## Schema Validation Queries

Validate scenario structure against schema specification.

### Level 1 - Required Structure

```bash
# Required top-level fields present
yq 'has("name") and has("start_node") and has("nodes") and has("endings")' scenario.yaml

# start_node exists in nodes
yq '.start_node as $start | .nodes | has($start)' scenario.yaml

# All next_node references exist in nodes or endings
yq '
  (.nodes | keys) as $nodes |
  (.endings | keys | map("ending_" + .)) as $endings |
  ($nodes + $endings) as $valid |
  [.nodes | to_entries | .[] | .value.choice.options[]? | (.next_node // .next) | select(. != null and . != "improvise")] |
  map(select(. as $ref | $valid | index($ref) | not)) |
  if length == 0 then "all valid" else . end
' scenario.yaml

# All blocked_next_node references exist
yq '
  (.nodes | keys) as $nodes |
  (.endings | keys | map("ending_" + .)) as $endings |
  ($nodes + $endings) as $valid |
  [.nodes | to_entries | .[] | select(.value.blocked_next_node) | .value.blocked_next_node] |
  map(select(. as $ref | $valid | index($ref) | not)) |
  if length == 0 then "all valid" else . end
' scenario.yaml
```

### Level 2 - Type Validation

```bash
# Find all precondition types used
yq '[.. | select(has("precondition")) | .precondition | .. | .type? | select(.)] | unique | .[]' scenario.yaml

# Find all consequence types used
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | .consequence[]? | .type] | unique | .[]' scenario.yaml

# Options missing required fields (id, text)
yq '.nodes | to_entries | .[] | {"node": .key, "missing": [.value.choice.options[] | select(.id == null or .text == null) | {"id": .id, "text": .text}]} | select(.missing | length > 0)' scenario.yaml
```

### Level 3 - on_enter Validation

```bash
# Find all on_enter consequences
yq '.nodes | to_entries | .[] | select(.value.on_enter) | {"node": .key, "on_enter_count": (.value.on_enter | length), "types": [.value.on_enter[]?.type]}' scenario.yaml

# Validate on_enter consequence types
yq '[.nodes | to_entries | .[] | .value.on_enter[]? | .type] | unique | .[]' scenario.yaml

# Check on_enter item references are valid
yq '[.nodes | to_entries | .[] | .value.on_enter[]? | select(.type == "gain_item" or .type == "lose_item") | .item] | unique | .[]' scenario.yaml
```

### Level 4 - blocked_next_node Validation

```bash
# Find all blocked_next_node usage
yq '[.nodes | to_entries | .[] | select(.value.blocked_next_node) | {"node": .key, "blocked_next": .value.blocked_next_node, "has_precondition": (.value.precondition != null)}]' scenario.yaml

# Verify blocked_next_node always has precondition
yq '.nodes | to_entries | .[] | select(.value.blocked_next_node and (.value.precondition | not)) | .key' scenario.yaml
```
