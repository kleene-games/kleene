# YAML Extraction Templates (Gameplay)

Templates for extracting scenario data during gameplay using yq 4.x, with grep fallbacks.

> **Analysis queries:** See `lib/patterns/analysis-queries.md` for kleene-analyze patterns.

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

## Registry Patterns

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
| Ending IDs | ~60 lines | 4 lines |

---

## Usage Notes

1. **Replace placeholders:** `NODE_ID`, `SCENARIO` with actual values
2. **Error handling:** If yq fails, silently fall back to grep equivalent
3. **Small files:** Don't use lazy loading for files that fit in context
4. **yq version:** These templates require yq 4.x (Mike Farah's Go version)
