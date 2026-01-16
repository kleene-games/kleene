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

**Output:** Both discovery and revelation nodes (if specified) in a single query.

### grep Fallback: Multiple Greps

```bash
# Grep for discovery node
Grep pattern: "^  DISCOVERY_NODE_ID:"
Context: -A 80

# Grep for revelation node
Grep pattern: "^  REVELATION_NODE_ID:"
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
