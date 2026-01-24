# Lazy Loading for Large Scenarios

When the Read tool returns a token limit error, switch to lazy loading mode for memory-efficient scenario playback.

> **Tool Detection:** See `overview.md` for yq detection protocol.
> **Templates:** See `extraction-templates.md` for all yq/grep patterns.

> **Token Efficiency:** Using `yq` for YAML extraction is **dramatically more efficient** than Read/Grep:
> - Header extraction: **~75% fewer tokens** (extracts only needed fields)
> - Node loading: **~67% fewer tokens** (single node vs grep context)
> - Entire large scenario playthrough: **~50% total token savings**
>
> Always prefer yq when available. The savings compound across every turn.

## Load Header

**If yaml_tool=yq (~75% token savings):**
```bash
yq '{"name": .name, "start_node": .start_node, "initial_character": .initial_character, "initial_world": .initial_world, "ending_ids": [.endings | keys | .[]]}' scenario.yaml
```

**If yaml_tool=grep (fallback):**
```
Read scenario file with limit: 200
```

Extract and cache:
- `name` - scenario identifier
- `initial_character` - starting character state
- `initial_world` - starting world state
- `start_node` - first node ID
- `ending_ids` - list of ending identifiers

## Load Nodes on Demand

**If yaml_tool=yq (~67% token savings):**
```bash
yq '.nodes.NODE_ID' scenario.yaml
```

For structured turn context:
```bash
yq '.nodes.NODE_ID as $n | {"narrative": $n.narrative, "prompt": $n.choice.prompt, "options": [$n.choice.options[] | {"id": .id, "text": .text, "cell": .cell, "precondition": .precondition, "next_node": .next_node, "has_improvise": (.next == "improvise"), "outcome_nodes": .outcome_nodes}]}' scenario.yaml
```

**If yaml_tool=grep (fallback):**
```
Pattern: "^  {node_id}:"
Context: -A 80
Path: scenario file
```

Parse YAML from grep output to extract narrative, choice prompt, and options.

## Improvise Prefetch (yq only)

When an option has `next: improvise`, prefetch outcome nodes in a single query:
```bash
yq '.nodes as $all | .nodes.NODE_ID.choice.options[] | select(.next == "improvise") | .outcome_nodes | to_entries | .[] | {"cell": .key, "node": $all[.value]}' scenario.yaml
```

This fetches both discovery and constraint nodes in one query, avoiding multiple round-trips.

## Adaptive Node Discovery

For improvised choices when narrative choices lead to unexpected paths:

**If yaml_tool=yq (preferred):**
```bash
yq '.nodes | keys | .[]' scenario.yaml | grep -i 'keyword1\|keyword2\|theme'
```

**If yaml_tool=grep (fallback):**
```bash
grep -i 'keyword' scenario.yaml | grep -E '^\s{2}\w+:'
```

## Cache Strategy

- Header data: persistent (kept in context)
- Current node: replaced each turn (don't accumulate old nodes)
- Endings: persistent (needed for ending detection)
- yaml_tool: persistent (detected once at session start)

## Detecting Load Mode

The gateway command attempts full read first. If it fails:
1. Sets `lazy_loading: true` in game context
2. Detects `yaml_tool: yq|grep` for extraction method
3. Loads header via yq or partial read
4. Passes scenario path for per-turn node loading

When `lazy_loading: true`, Phase 2 uses the appropriate tool to load each node.

## Error Handling

If yq fails during extraction, silently fall back to grep. Never interrupt gameplay to report tool failures.
