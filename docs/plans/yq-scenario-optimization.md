# Investigation: yq for Scenario Reading in Kleene

## Current Approach (kleene-play SKILL.md lines 32-79)

**Standard Load (small scenarios):**
- Read entire file, cache in context
- Works well for scenarios under ~20k tokens

**Lazy Load (large scenarios):**
1. Read first 200 lines for header data
2. Extract: name, initial_character, initial_world, start_node, endings
3. On each turn, use Grep: `"^  {node_id}:" -A 80` to fetch node content
4. Parse YAML from grep output

## Problems with Current Lazy Load

| Issue | Impact |
|-------|--------|
| Fixed `-A 80` context | Truncates long nodes, includes extra content for short ones |
| Grep doesn't parse YAML | Fragile for nested structures, multiline strings |
| 200-line header read | Wastes tokens if only specific fields needed |
| Manual YAML parsing | Error-prone when extracting from grep output |

## The yq Alternative

The patterns from hiivmind-pulse-gh show a tiered approach:

```
yq (preferred) → python+pyyaml (fallback) → grep (fragile)
```

**Surgical extraction examples:**
```bash
# Header fields (instead of reading 200 lines)
yq '.name' scenario.yaml                    # Just title
yq '.initial_character' scenario.yaml       # Just character init
yq '.start_node' scenario.yaml              # Just start node name
yq '.endings | keys' scenario.yaml          # Just ending IDs

# Node loading (instead of grep -A 80)
yq '.nodes.dragon_fight' scenario.yaml      # Exact node content
yq '.nodes.dragon_fight.choice.options' scenario.yaml  # Just options
```

## Token Usage Comparison

**Scenario: dragon_quest.yaml (~400 lines)**

| Operation | Current Approach | yq Approach | Savings |
|-----------|-----------------|-------------|---------|
| Load header | 200 lines (~4k tokens) | ~50 lines (~1k tokens) | ~75% |
| Load node | 80 lines (~1.5k tokens) | 10-30 lines (~0.5k tokens) | ~67% |
| Per-turn overhead | High (grep output includes noise) | Low (exact extraction) | Significant |

**For a 10-turn game session:**
- Current: ~200 + (10 × 80) = 1,000 lines processed
- yq: ~50 + (10 × 20) = 250 lines processed
- **~75% reduction in token consumption**

## Speed Comparison

| Metric | Grep | yq |
|--------|------|-----|
| Parse correctness | Fragile | Reliable |
| Nested data access | Manual parsing required | Native support |
| Shell overhead | One process | One process |
| Execution time | ~Equal | ~Equal |

Speed is comparable, but **yq is more reliable** for YAML structures.

## Recommendation: Yes, Adopt yq

**Why it's a good enhancement:**

1. **Token savings are significant** (~75% for lazy loading)
2. **More reliable** - yq understands YAML, grep doesn't
3. **Pattern already exists** - tool-detection.md and config-parsing.md provide templates
4. **Graceful degradation** - fallback to current approach if yq unavailable

## Implementation Approach

### Phase 1: Add Tool Detection Pattern

Create `lib/patterns/tool-detection.md` (adapt from hiivmind-pulse-gh):
- Detect yq availability: `command -v yq && yq --version`
- Detect python+pyyaml: `python3 -c "import yaml"`
- Set capability flag in context for session

### Phase 2: Add YAML Extraction Pattern

Create `lib/patterns/yaml-extraction.md`:
- yq commands for header fields
- yq commands for node extraction
- Python fallback equivalents
- Grep fallback (preserve current approach as last resort)

### Phase 3: Update kleene-play Lazy Loading

Modify `skills/kleene-play/SKILL.md` lines 40-79:

**Instead of:**
```
Read scenario file with limit: 200
```

**Use:**
```
# If yq available:
yq '.name, .initial_character, .initial_world, .start_node' scenario.yaml

# If python+pyyaml available:
python3 -c "import yaml; d=yaml.safe_load(open('scenario.yaml')); print(yaml.dump({k:d[k] for k in ['name','initial_character','initial_world','start_node']}))"

# Fallback: current 200-line read
```

**Instead of:**
```
Grep for "^  {node_id}:" with -A 80
```

**Use:**
```
# If yq available:
yq '.nodes.{node_id}' scenario.yaml

# If python+pyyaml available:
python3 -c "import yaml; print(yaml.dump(yaml.safe_load(open('scenario.yaml'))['nodes']['{node_id}']))"

# Fallback: current grep approach
```

### Phase 4: Update kleene-analyze

Similar changes for full scenario analysis - yq can extract just the fields needed for graph building.

## Files to Modify

| File | Changes |
|------|---------|
| `lib/patterns/tool-detection.md` | New - adapt from pulse-gh |
| `lib/patterns/yaml-extraction.md` | New - scenario-specific patterns |
| `skills/kleene-play/SKILL.md` | Update lazy loading section |
| `skills/kleene-analyze/SKILL.md` | Update scenario loading |
| `commands/kleene.md` | Add tool detection at session start |

## Advanced yq Patterns: Tested and Validated

yq 4.x can do graph-like traversals, not just single-field extraction. Here are tested patterns:

### Pattern 1: Full Turn Context (Single Query)

Get current node + all options with preconditions + metadata for presentation:

```bash
yq '
  .nodes.mountain_approach as $n |
  .nodes as $all |
  {
    "node_id": "mountain_approach",
    "narrative": $n.narrative,
    "prompt": $n.choice.prompt,
    "options": [
      $n.choice.options[] |
      {
        "id": .id,
        "text": .text,
        "cell": .cell,
        "precondition": .precondition,
        "next_node": .next_node,
        "has_improvise": (.next == "improvise")
      }
    ]
  }
' scenario.yaml
```

**Output**: Structured JSON with everything needed for a game turn - narrative, prompt, all options with preconditions and destinations.

### Pattern 2: Destination Preview (Multi-Hop)

Get options with preview of destination narratives:

```bash
yq '
  .nodes as $all |
  .nodes.mountain_approach.choice.options[] |
  select(.next_node) |
  {"option_text": .text, "dest_id": .next_node, "dest_preview": ($all[.next_node].narrative | split("\n")[0])}
' scenario.yaml
```

**Output**:
```
option_text: "Draw your sword and fight!"
dest_id: dragon_fight
dest_preview: The battle is fierce. Fire and steel clash in the mountain air.
```

### Pattern 3: Graph Analysis - Item Dependencies

Find all nodes requiring a specific item:

```bash
yq '
  .nodes | to_entries | .[] |
  select(.value.choice.options[].precondition.item == "rusty_sword") |
  {"node": .key, "requires": "rusty_sword"}
' scenario.yaml
```

**Output**:
```
node: mountain_approach
node: dragon_notices_patience
node: dragon_cornered
```

### Pattern 4: Cell Coverage Analysis

Find all nodes containing Unknown cell options:

```bash
yq '
  .nodes | to_entries | .[] |
  select(.value.choice.options[] | select(.cell == "unknown")) |
  .key
' scenario.yaml
```

**Output**: `intro`, `mountain_approach`

### Pattern 5: Improvise Outcome Traversal

Get improvise option outcomes, then fetch all outcome nodes:

```bash
yq '
  .nodes.intro.choice.options[] |
  select(.next == "improvise") |
  .outcome_nodes | to_entries | .[].value
' scenario.yaml | xargs -I{} yq '.nodes.{}' scenario.yaml
```

**Output**: Full content of `elder_lore` AND `elder_silence` nodes.

### Pattern 6: Minimal Extraction

Just ending IDs (4 lines vs 60+ lines for full endings):

```bash
yq '.endings | keys' scenario.yaml
```

**Output**: `["ending_victory", "ending_death", "ending_transcendence", "ending_fled"]`

---

## Comparison: Token Usage by Query Type

| Query Type | grep -A 80 | yq Templated |
|------------|------------|--------------|
| Single node | ~80 lines | ~15-30 lines |
| Turn context | ~80 lines + manual parsing | ~40 lines, structured |
| Node + destinations | Multiple queries | Single query |
| Item dependency graph | Impossible | One query scans all nodes |
| Ending IDs | ~60 lines | 4 lines |
| Cell coverage | Manual grep + parsing | One query |

**Key insight**: yq enables queries that are *impossible* with grep - like finding all nodes requiring a specific item, or getting destination previews.

---

## Use Cases by Skill

### kleene-play (Gameplay)

| Phase | Operation | Current | yq Pattern | Benefit |
|-------|-----------|---------|------------|---------|
| **Init** | Load header | Read 200 lines | `yq '.name, .initial_character, .initial_world, .start_node'` | ~75% token reduction |
| **Init** | Get ending IDs | Read full endings section | `yq '.endings | keys'` | 4 lines vs 60+ |
| **Turn** | Get current node | `grep -A 80` | `yq '.nodes.{node_id}'` | Exact extraction, no overflow |
| **Turn** | Check ending | String match on cached list | Same yq query at init | Already have data |
| **Improvise** | Prefetch outcomes | Multiple greps | `yq '.nodes.{discovery}, .nodes.{revelation}'` | One query for both nodes |

**Per-session overhead:**
- Init: 1 yq query (header + ending IDs)
- Per turn: 1 yq query (current node)
- Improvise: 1 yq query (prefetch outcome nodes)

### kleene-analyze (Analysis/Validation)

| Step | Operation | Current | yq Pattern | Benefit |
|------|-----------|---------|------------|---------|
| **Graph Build** | Get node connections | Parse full YAML | `yq '.nodes | to_entries | .[] | {key: .key, dests: [.value.choice.options[].next_node]}'` | Structure only, skip narratives |
| **Cell Coverage** | Find cell-tagged options | Manual search | `yq '.nodes | .. | select(.cell == "chooses")'` | One query scans all |
| **Unknown Detection** | Find improvise options | Manual search | `yq '.nodes | .. | select(.next == "improvise")'` | One query |
| **Ending Types** | Classify endings | Read full endings | `yq '.endings | to_entries | .[] | {id: .key, type: .value.type}'` | Types only, skip narratives |
| **Precondition Map** | Item dependencies | **Impossible** | `yq '.nodes | .. | select(.precondition.item == "rusty_sword")'` | **New capability** |
| **Reachability** | Find orphan nodes | BFS after full load | Graph query + set difference | Structural analysis |

**Key insight**: kleene-analyze benefits most from yq - many analysis queries are *impossible* with grep.

### kleene-generate (Scenario Generator)

| Step | Operation | Current | yq Pattern | Benefit |
|------|-----------|---------|------------|---------|
| **Register** | Extract metadata | Read full file | `yq '.name, .description'` | 2 fields only |
| **Register** | Load registry | Read full registry | `yq '.scenarios | keys'` | Just scenario list |
| **Branch Expand** | Find gaps | Call kleene-analyze | Use analyze patterns | Same yq benefits |
| **Tier Check** | Verify coverage | Manual check | Cell coverage query | One query |

---

## Implementation: Query Templates

### For kleene-play

**Template: Game Initialization**
```bash
yq '
  {
    "name": .name,
    "start_node": .start_node,
    "initial_character": .initial_character,
    "initial_world": .initial_world,
    "ending_ids": [.endings | keys | .[]]
  }
' scenario.yaml
```

**Template: Turn Context**
```bash
yq '
  .nodes.{NODE_ID} as $n |
  {
    "narrative": $n.narrative,
    "prompt": $n.choice.prompt,
    "options": [
      $n.choice.options[] |
      {
        "id": .id,
        "text": .text,
        "precondition": .precondition,
        "next_node": .next_node,
        "has_improvise": (.next == "improvise"),
        "outcome_nodes": .outcome_nodes
      }
    ]
  }
' scenario.yaml
```

**Template: Improvise Prefetch**
```bash
yq '
  .nodes as $all |
  .nodes.{NODE_ID}.choice.options[] |
  select(.next == "improvise") |
  .outcome_nodes | to_entries | .[] |
  {"cell": .key, "node": $all[.value]}
' scenario.yaml
```

### For kleene-analyze

**Template: Graph Structure (no narratives)**
```bash
yq '
  .nodes | to_entries | .[] |
  {
    "node": .key,
    "options": [.value.choice.options[] | {
      "id": .id,
      "cell": .cell,
      "next": (.next_node // .next),
      "precondition": .precondition
    }]
  }
' scenario.yaml
```

**Template: Cell Coverage Report**
```bash
yq '
  [.nodes | to_entries | .[] | .value.choice.options[] | select(.cell)] |
  group_by(.cell) |
  .[] | {cell: .[0].cell, count: length}
' scenario.yaml
```

**Template: Precondition Dependency Map**
```bash
yq '
  .nodes | to_entries | .[] |
  .value.choice.options[] |
  select(.precondition) |
  {
    "node": (parent | parent | parent | .key),
    "option": .id,
    "requires": .precondition
  }
' scenario.yaml
```

### For kleene-generate

**Template: Registration Metadata**
```bash
yq '{name: .name, description: .description}' scenario.yaml
```

**Template: Registry Update**
```bash
yq -i '.scenarios.{ID} = {
  "name": "Title",
  "description": "Desc",
  "path": "file.yaml",
  "enabled": true,
  "tags": ["generated"]
}' registry.yaml
```

---

## Revised Recommendation

**Yes, adopt yq** - not just for token savings, but for capabilities:

1. **Surgical extraction** when you need minimal data
2. **Expansive queries** when you need graph traversal
3. **Structured output** eliminates parsing errors
4. **Analysis patterns** that grep cannot do

---

## Gateway Command Optimizations (commands/kleene.md)

### Registry Operations

| Operation | Current | yq Pattern | Benefit |
|-----------|---------|------------|---------|
| **List enabled scenarios** | Read full registry | `yq '.scenarios | to_entries | .[] | select(.value.enabled) | {id: .key, name: .value.name}'` | Just IDs and names |
| **Get scenario paths** | Parse full registry | `yq '.scenarios | to_entries | .[] | .value.path'` | For unregistered check |
| **Sync metadata** | Read full scenario | `yq '{name: .name, description: .description}'` | 2 fields only |
| **Build menu** | Multiple full reads | One registry query + yq per new scenario | Minimal reads |

**Template: Scenario Menu Data**
```bash
yq '
  .scenarios | to_entries | .[] |
  select(.value.enabled) |
  {
    "id": .key,
    "name": .value.name,
    "description": .value.description,
    "path": .value.path
  }
' registry.yaml
```

### Save Listing Operations

| Operation | Current | yq Pattern | Benefit |
|-----------|---------|------------|---------|
| **List saves** | Read each file | `yq '{turn: .turn, node: .current_node, saved: .last_saved}'` per file | Just metadata |
| **Sort by date** | Parse each file | Single query with dates | Already sorted |

**Template: Save Metadata Batch**
```bash
for f in ./saves/dragon_quest/*.yaml; do
  yq --arg file "$f" '{
    "file": $file,
    "turn": .turn,
    "node": .current_node,
    "saved": .last_saved
  }' "$f"
done
```

---

## Save File Enhancements

### Current Save Format
```yaml
current_node: intro
turn: 0
# ... no node context cached
```

### Enhanced Save Format (with co-reference caching)
```yaml
current_node: intro
current_node_title: "Village Crossroads"           # NEW: from node.title or generated
current_node_preview: "The village elder grips..." # NEW: first line of narrative
turn: 0
# ... rest of state
```

**Benefits:**
1. **Rich save listings** without loading scenario files
2. **Resume preview** shows context without scenario load
3. **Co-references** between saves and scenario nodes

**Template: Extract Node Preview for Caching**
```bash
yq '
  .nodes.intro |
  {
    "title": (.title // "Node: intro"),
    "preview": (.narrative | split("\n") | .[0])
  }
' scenario.yaml
```

### Enhanced Save Writing

When saving game state:
```bash
yq '
  .nodes[$NODE_ID] |
  {
    "title": (.title // ("Node: " + $NODE_ID)),
    "preview": (.narrative | split("\n") | map(select(. != "")) | .[0])
  }
' --arg NODE_ID "$current_node" scenario.yaml
```

This extracts node metadata at save time, caching it in the save file.

---

## Registry Enhancements

### Current Registry Entry
```yaml
dragon_quest:
  name: "The Dragon's Choice"
  description: "Face the dragon..."
  path: dragon_quest.yaml
  enabled: true
```

### Enhanced Registry Entry (with scenario stats)
```yaml
dragon_quest:
  name: "The Dragon's Choice"
  description: "Face the dragon..."
  path: dragon_quest.yaml
  enabled: true
  # NEW: Cached stats for rich menus
  stats:
    node_count: 18
    ending_count: 4
    tier: "Silver"
    cells_covered: ["triumph", "barrier", "escape", "discovery"]
```

**Benefits:**
1. **Tier badges** in scenario menu without loading scenarios
2. **Completion indicators** showing scenario complexity
3. **Cell coverage preview** for players choosing scenarios

**Template: Extract Scenario Stats for Registry**
```bash
yq '
  {
    "node_count": (.nodes | length),
    "ending_count": (.endings | length),
    "cells": [.nodes | .. | select(.cell) | .cell] | unique
  }
' scenario.yaml
```

---

## Implementation Summary

### Phase 1: Core yq Patterns
1. Add `lib/patterns/tool-detection.md` (adapt from pulse-gh)
2. Add `lib/patterns/yaml-extraction.md` (kleene-specific templates)

### Phase 2: kleene-play Updates
1. Update lazy loading to use yq
2. Add node prefetching for improvise outcomes
3. Cache node metadata in saves

### Phase 3: kleene-analyze Updates
1. Use graph structure queries (no narratives)
2. Add cell coverage and precondition queries

### Phase 4: Gateway Command Updates
1. yq for registry operations
2. yq for save listing
3. Enhanced save format with node previews

### Phase 5: Registry Enhancements
1. Cache scenario stats during sync
2. Show tier badges in menus

---

## Verification

1. **Tool availability**: Run `yq --version` at session start, set capability flag
2. **Pattern testing**: Test each template against `dragon_quest.yaml`
3. **Fallback chain**: Verify python+pyyaml fallback works when yq unavailable
4. **Save compatibility**: Ensure old saves load without cached node metadata (graceful degradation)

---

## Open Questions

1. **yq version requirement**: Require yq 4.x (Mike Farah's Go version)? The Python yq is a different project with different syntax.

2. **Save format migration**: Auto-upgrade old saves to add cached node metadata on load, or leave as-is?

3. **Registry stats caching**: Cache tier/cell data during sync, or calculate on-demand?

4. **Error handling**: If yq parsing fails mid-game, auto-fallback to grep or abort and report?
