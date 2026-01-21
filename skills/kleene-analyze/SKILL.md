---
name: kleene-analyze
description: This skill should be used when the user asks to "analyze a scenario", "check narrative completeness", "find missing paths", "validate my scenario", "show grid coverage", "check item obtainability", "analyze traits", "find cycles", or wants to understand the structure of a Kleene scenario. Performs graph analysis, Decision Grid coverage checking, and deep structural analysis (yq-enabled) including item/trait/flag dependencies, relationship networks, consequence magnitude, scene pacing, and path diversity.
version: 0.5.0
allowed-tools: Read, Glob, Grep, AskUserQuestion, Bash
---

# Kleene Analyze Skill

Analyze scenario structure for narrative completeness, detecting missing cells in the 3x3 grid, unreachable nodes, dead ends, and structural issues.

## Analysis Types

| # | Type | Description |
|---|------|-------------|
| 1 | Grid Coverage | Check 9-cell coverage and determine tier (Bronze/Silver/Gold) |
| 2 | Null Cases | Verify death, departure, and blocked paths exist |
| 3 | Structural | Find unreachable nodes, dead ends, railroads, illusory choices |
| 4 | Path Enumeration | List all paths from start to endings |
| 5 | Cycle Detection | Find loops, self-referential choices (yq) |
| 6 | Item Obtainability | Verify required items are obtainable (yq) |
| 7 | Trait Balance | Detect impossible trait requirements (yq) |
| 8 | Flag Dependencies | Find unused/unobtainable flags (yq) |
| 9 | Relationship Network | Map NPC relationship dynamics (yq) |
| 10 | Consequence Magnitude | Flag over/undersized consequences (yq) |
| 11 | Scene Pacing | Analyze scene_break usage (yq) |
| 12 | Path Diversity | Identify false choices, railroads (yq) |
| 13 | Ending Reachability | Verify all endings are reachable (yq) |
| 14 | Travel Consistency | Validate travel time config (v5, yq) |
| 15 | Schema Validation | Validate structure, types, references (yq) |

## Workflow

> **Tool Detection:** See `lib/patterns/tool-detection.md` for yq availability check.
> **Query Templates:** See `lib/patterns/yaml-extraction.md` for all extraction patterns.
> **Report Format:** See `lib/framework/formats/analysis-report-format.md` for output specification.
> **Validation Checklists:** See `lib/guides/analysis-validation-guide.md` for all checks.

### Step 1: Load Scenario

Read scenario from:
- Local `scenario.yaml` in current directory
- Bundled scenario from `${CLAUDE_PLUGIN_ROOT}/scenarios/`
- Specified file path

Parse YAML and validate basic structure.

### Step 2: Build Graph

Construct directed graph:
- Nodes: Each scenario node
- Edges: Connections from choice options to next_node
- Edge metadata: option_id, preconditions, consequences

Use yq graph structure extraction (see `lib/patterns/yaml-extraction.md` → "Analysis Patterns"):

```bash
yq '.nodes | to_entries | .[] | {"node": .key, "options": [.value.choice.options[] | {"id": .id, "cell": .cell, "next": (.next_node // .next), "precondition": .precondition}]}' scenario.yaml
```

### Step 3: Analyze Reachability

From start_node, find all reachable nodes using BFS/DFS.

**Distinguish static and dynamic edges:**
- **Static** (`next_node`) - Unconditionally reachable
- **Dynamic** (`next: improvise` + `outcome_nodes`) - Conditionally reachable

Nodes only in `outcome_nodes` should be "conditionally reachable via improvisation" NOT "unreachable".

### Step 4: Find All Paths

Enumerate paths from start_node to each ending. Track path length and required preconditions.

### Step 5: Classify Paths into Cells

**The Decision Grid** (see `lib/framework/core/core.md` for detailed definitions):

|                    | World Permits | World Indeterminate | World Blocks |
|--------------------|---------------|---------------------|--------------|
| **Player Chooses** | Triumph       | Commitment          | Rebuff       |
| **Player Unknown** | Discovery     | Limbo               | Constraint   |
| **Player Avoids**  | Escape        | Deferral            | Fate         |

**Classification Signals:**
- Triumph: Active option + success ending
- Commitment: Active option + pending state
- Rebuff: Active option + precondition failure
- Discovery: Scripted Unknown option → `outcome_nodes.discovery`, or improv_* flag + positive outcome
- Limbo: Scripted Unknown → fallback, or improv_* flag + no state change
- Constraint: Scripted Unknown → `outcome_nodes.constraint`, or improv_* flag + blocked
- Escape: Retreat option + survival ending
- Deferral: Retreat option + pending state
- Fate: Retreat option + forced negative outcome

### Step 6: Classify Endings

Map each ending to outcome type:
- `type: victory` → SOME_TRANSFORMED
- `type: death` → NONE_DEATH
- `type: transcendence` → NONE_REMOVED
- `type: unchanged` → SOME_UNCHANGED

### Step 7: Detect Structural Issues

| Issue | Detection |
|-------|-----------|
| Unreachable Nodes | No incoming edges (except start) |
| Dead Ends | Non-ending nodes with no outgoing edges |
| Railroads | 3+ nodes with only one path through |
| Single-Option Nodes | Choice with only 1 option (warn unless `next: improvise`) |
| Illusory Choices | Multiple options leading to same destination |

## Deep Structural Analysis (yq-enabled)

All deep analysis queries are in `lib/patterns/yaml-extraction.md` → "Deep Analysis Queries".

| Analysis | Query Section |
|----------|---------------|
| Cycle Detection | `### Cycle Detection` |
| Item Obtainability | `### Item Obtainability` |
| Trait Balance | `### Trait Balance` |
| Flag Dependencies | `### Flag Dependencies` |
| Relationship Network | `### Relationship Network` |
| Consequence Magnitude | `### Consequence Magnitude` |
| Scene Pacing | `### Scene Pacing` |
| Path Diversity | `### Path Diversity` |
| Ending Reachability | `### Ending Reachability` |

## v5 Feature Validation

For scenarios using v5 features, queries are in `lib/patterns/yaml-extraction.md` → "v5 Feature Queries".

| Validation | Query Section |
|------------|---------------|
| Location State | `### Location State Validation` |
| Node Preconditions | `### Node Precondition Validation` |
| NPC Tracking | `### NPC Location Validation` |
| Temporal Events | `### Temporal/Event Validation` |
| Travel Consistency | `### Travel Consistency Validation` |
| Improvisation Coverage | `### Improvisation Coverage Analysis` |

## Schema Validation

Queries are in `lib/patterns/yaml-extraction.md` → "Schema Validation Queries".

**Levels:**
1. Required Structure - fields present, references valid
2. Type Validation - precondition/consequence types known
3. on_enter Validation - consequence types valid
4. blocked_next_node Validation - has associated precondition

## Report Format

> **Reference:** See `lib/framework/formats/analysis-report-format.md` for complete specification.

Reports use:
- Double-line box header: `═══`
- Section underlines: `───`
- Status indicators: `✓` (OK), `⚠` (Warning), `✗` (Error), `○` (Fallback), `!` (Issue)

## Validation Checks

> **Reference:** See `lib/guides/analysis-validation-guide.md` for complete checklists.

**Validation types:** Schema, Structural, Semantic, v5 Features, Narrative

## Analysis Type Selection

When no specific analysis is requested:

```json
{
  "questions": [
    {
      "question": "What type of analysis would you like?",
      "header": "Analysis",
      "multiSelect": false,
      "options": [
        {"label": "Full analysis (Recommended)", "description": "Complete grid coverage, structure, deep analysis, and paths"},
        {"label": "Grid coverage", "description": "Check all nine narrative cells and determine tier"},
        {"label": "Deep structural (yq)", "description": "Items, traits, flags, relationships, cycles, pacing"},
        {"label": "Path enumeration", "description": "List all possible routes through the scenario"}
      ]
    }
  ]
}
```

## Quick Commands

| Keyword | Analysis |
|---------|----------|
| "analyze for completeness" | Full analysis |
| "check grid coverage" | Grid check only |
| "what tier is this" | Tier check |
| "find structural problems" | Structural issues |
| "show all paths" | Path enumeration |
| "check items/flags" | Precondition map |
| "run deep analysis" | Deep structural (yq) |
| "check item obtainability" | Item analysis |
| "analyze traits" | Trait balance |
| "find flag problems" | Flag dependencies |
| "map relationships" | Relationship network |
| "check consequence sizes" | Consequence magnitude |
| "analyze pacing" | Scene pacing |
| "find false choices" | Path diversity |
| "check ending reachability" | Ending reachability |
| "find cycles/loops" | Cycle detection |
| "check travel config" | Travel consistency |
| "validate schema" | Schema validation |

## JSON Schema Validation (Optional)

If `check-jsonschema` is installed:

```bash
check-jsonschema --schemafile ${CLAUDE_PLUGIN_ROOT}/lib/schema/scenario-schema.json <scenario.yaml>
```

Or use the wrapper script:

```bash
./scripts/validate-scenario.sh scenarios/dragon_quest.yaml
```

## Additional Resources

### Core
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/core/core.md`** - Decision Grid and tier definitions
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/core/endings.md`** - Ending classification

### Patterns
- **`${CLAUDE_PLUGIN_ROOT}/lib/patterns/yaml-extraction.md`** - All yq query patterns

### Formats
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/formats/scenario-format.md`** - YAML format
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/formats/analysis-report-format.md`** - Report format

### Guides
- **`${CLAUDE_PLUGIN_ROOT}/lib/guides/analysis-validation-guide.md`** - Validation checklists

### Gameplay
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/gameplay/presentation.md`** - Menu conventions
