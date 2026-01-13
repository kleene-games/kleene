---
name: kleene-analyze
description: This skill should be used when the user asks to "analyze a scenario", "check narrative completeness", "find missing paths", "validate my scenario", "show grid coverage", or wants to understand the structure of a Kleene scenario. Performs graph analysis and nine-cell grid coverage checking.
version: 0.2.0
---

# Kleene Analyze Skill

Analyze scenario structure for narrative completeness, detecting missing cells in the 3x3 grid, unreachable nodes, dead ends, and structural issues.

## Analysis Types

### 1. Grid Coverage Analysis
Check coverage of the nine narrative cells and determine completeness tier (Bronze/Silver/Gold).

### 2. Null Case Analysis
Verify death, departure, and blocked paths exist.

### 3. Structural Analysis
Find unreachable nodes, dead ends, railroads, and illusory choices.

### 4. Path Enumeration
List all possible paths from start to endings.

## Workflow

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

### Step 3: Analyze Reachability

From start_node, find all reachable nodes using BFS/DFS.

```
Reachable: [intro, sword_taken, forest_entrance, ...]
Unreachable: [orphan_node_1, orphan_node_2]
```

### Step 4: Find All Paths

Enumerate paths from start_node to each ending:

```
Path 1: intro → sword_taken → mountain_approach → dragon_fight → ending_victory
Path 2: intro → forest_entrance → shrine_discovery → scroll_taken → ...
...
```

Track path length and required preconditions.

### Step 5: Classify Paths into Cells

For each path, determine cell in the 3x3 grid based on two axes:

**Player Axis (Chooses / Unknown / Avoids)**:
- **Chooses**: Takes decisive action toward goal (fight, speak, help, take)
- **Unknown**: Hesitates, explores, or improvises ("Other" selection, `improv_*` flags)
- **Avoids**: Retreats, refuses, flees, ignores

**World Axis (Permits / Indeterminate / Blocks)**:
- **Permits**: Path available, action succeeds, preconditions met
- **Indeterminate**: Outcome pending, no ending reached, multiple continuations
- **Blocks**: Precondition prevents progress, action fails

**The Nine Cells**:
|                    | World Permits | World Indeterminate | World Blocks |
|--------------------|---------------|---------------------|--------------|
| **Player Chooses** | Triumph       | Commitment          | Barrier      |
| **Player Unknown** | Discovery     | Limbo               | Revelation   |
| **Player Avoids**  | Escape        | Deferral            | Fate         |

**Classification Signals**:
- Triumph: Active option + success ending
- Commitment: Active option + pending state/no ending
- Barrier: Active option + precondition failure
- Discovery: (scripted) option with `cell: unknown` + `outcome_nodes.discovery`
- Discovery: (emergent) improv_* flag + positive outcome
- Limbo: (scripted) option with `cell: unknown` + no outcome_nodes.limbo
- Limbo: (emergent) improv_* flag + no state change
- Revelation: (scripted) option with `cell: unknown` + `outcome_nodes.revelation`
- Revelation: (emergent) improv_* flag + blocked by precondition
- Escape: Retreat option + survival ending
- Deferral: Retreat option + pending state
- Fate: Retreat option + forced negative outcome

**Detecting Scripted Unknown Options**:

Scan all options for `next: improvise` attribute:

```yaml
options:
  - id: observe_dragon
    text: "Wait and observe"
    cell: unknown           # ← Indicates Unknown row
    next: improvise         # ← Triggers scripted improvisation
    outcome_nodes:
      discovery: node_id    # ← Scripted Discovery path
      revelation: node_id   # ← Scripted Revelation path
      # limbo: omitted      # ← Stays at node (default Limbo)
```

For each such option:
- If `outcome_nodes.discovery` exists → count as scripted Discovery
- If `outcome_nodes.revelation` exists → count as scripted Revelation
- `outcome_nodes.limbo` is optional; Limbo is always possible as fallback

### Step 6: Classify Endings

Map each ending to outcome type:
- `type: victory` → SOME_TRANSFORMED
- `type: death` → NONE_DEATH
- `type: transcendence` → NONE_REMOVED
- `type: unchanged` → SOME_UNCHANGED

### Step 7: Detect Structural Issues

**Unreachable Nodes**: Nodes with no incoming edges (except start)

**Dead Ends**: Non-ending nodes with no outgoing edges

**Railroads**: Sequences of 3+ nodes with only one path through

**Illusory Choices**: Multiple options at a node leading to same destination

## Report Format

```
═══════════════════════════════════════════════════════════
KLEENE SCENARIO ANALYSIS
Scenario: The Dragon's Choice
═══════════════════════════════════════════════════════════

GRID COVERAGE
─────────────
             │ Permits     │ Indeterminate │ Blocks      │
─────────────┼─────────────┼───────────────┼─────────────┤
Chooses      │ ✓ Triumph   │ ✗ Commitment  │ ✓ Barrier   │
             │   3 paths   │   0 paths     │   2 paths   │
─────────────┼─────────────┼───────────────┼─────────────┤
Unknown      │ ✓ Discovery │ ○ Limbo       │ ✓ Revelation│
             │   1 scripted│   (fallback)  │   1 scripted│
─────────────┼─────────────┼───────────────┼─────────────┤
Avoids       │ ✓ Escape    │ ✗ Deferral    │ ✓ Fate      │
             │   1 path    │   0 paths     │   1 path    │
─────────────┴─────────────┴───────────────┴─────────────┘

Legend: ✓ = scripted paths, ○ = via improvisation/fallback, ✗ = missing

UNKNOWN ROW DETAILS
───────────────────
Scripted Unknown options found: 2
  - intro/ask_elder → Discovery: elder_lore, Revelation: elder_silence
  - mountain_approach/observe_dragon → Discovery: dragon_notices_patience, Revelation: dragon_dismisses_coward
Limbo: Always available as fallback when no pattern matches

COMPLETENESS TIER
─────────────────
Bronze corners: 3/4 (Triumph ✓, Barrier ✓, Escape ✓, Fate ✗)
Silver middle:  0/5 (no middle cells scripted)
Tier achieved:  BRONZE (INCOMPLETE - missing Fate)

PATH DETAILS
────────────
✓ Triumph (3 paths):
  - intro → sword_taken → mountain_approach → dragon_fight → ending_victory
  - intro → forest_entrance → shrine → dragon_dialogue → ending_transcendence
  - ...

✓ Barrier (2 paths):
  - mountain_approach → dragon_fight (blocked: missing sword)
  - mountain_approach → dragon_dialogue (blocked: missing dragon_tongue)

✓ Escape (1 path):
  - intro → mountain_approach → attempt_flee → ending_fled

✗ Fate (0 paths):
  MISSING: No forced consequence when player tries to avoid

NULL CASES
──────────
✓ NONE_DEATH: 2 paths (dragon_fight_unarmed, dragon_refused)
✓ NONE_REMOVED: 1 path (ending_transcendence)
✗ NONE_BLOCKED: 0 paths (no completely blocked endings)

OUTCOME DISTRIBUTION
────────────────────
SOME_TRANSFORMED (victory): 1 ending
SOME_UNCHANGED (irony): 1 ending
NONE_DEATH: 1 ending
NONE_REMOVED (transcendence): 1 ending

STRUCTURAL ISSUES
─────────────────
✓ No unreachable nodes
✓ No dead ends
! Railroad detected: intro → sword_taken → mountain_approach (3 nodes, 1 path)
✓ No illusory choices

RECOMMENDATIONS
───────────────
1. Add "Fate" path (required for Bronze):
   - Suggestion: When fleeing, dragon pursues and forces confrontation

2. For Silver tier, add 2+ middle cells:
   - Commitment: Action with pending outcome (drink potion, send messenger)
   - Deferral: Avoidance that builds tension (hide, postpone)

═══════════════════════════════════════════════════════════
```

## Detailed Analyses

### Precondition Dependency Map

Show which items/traits/flags are required for which paths:

```
rusty_sword:
  Required for: dragon_fight
  Obtained at: intro (take_sword option)

knows_dragon_tongue:
  Required for: dragon_dialogue
  Obtained at: shrine_discovery (take_scroll option)

courage >= 10:
  Required for: dragon_fight_unarmed
  Max obtainable: 8 (starting 5 + sword +1 + victory +3)
  Status: IMPOSSIBLE (intended?)
```

### Critical Path Analysis

Identify the "minimum viable playthrough":

```
Shortest path to victory: 4 nodes
  intro → sword_taken → mountain_approach → dragon_fight → ending_victory

Shortest path to any ending: 3 nodes
  intro → mountain_approach → attempt_flee → ending_fled
```

### Choice Weight Analysis

For each choice node, analyze option distribution:

```
mountain_approach (4 options):
  - fight_with_sword: requires item (conditional)
  - fight_unarmed: requires trait 10 (impossible)
  - speak_dragon_tongue: requires flag (conditional)
  - flee_dragon: always available (fallback)

  Available without preconditions: 1/4 (25%)
  Potentially available: 3/4 (75%)
  Always blocked: 1/4 (25%)
```

## Validation Checks

### Structural Validation

- [ ] start_node exists in nodes
- [ ] All next_node references exist
- [ ] All endings are reachable
- [ ] No orphan nodes

### Semantic Validation

- [ ] Referenced items can be obtained
- [ ] Referenced flags can be set
- [ ] Trait requirements are achievable
- [ ] At least one ending is always reachable

### Narrative Validation

- [ ] At least one death path
- [ ] At least one victory/success path
- [ ] Multiple meaningful choices
- [ ] No single-option "choices"

## Analysis Type Selection

When no specific analysis is requested, use `AskUserQuestion` to let the user choose:

```json
{
  "questions": [
    {
      "question": "What type of analysis would you like?",
      "header": "Analysis",
      "multiSelect": false,
      "options": [
        {
          "label": "Full analysis (Recommended)",
          "description": "Complete grid coverage, structure, and path analysis"
        },
        {
          "label": "Grid coverage",
          "description": "Check all nine narrative cells and determine tier"
        },
        {
          "label": "Structural issues",
          "description": "Find dead ends, railroads, unreachable nodes"
        },
        {
          "label": "Path enumeration",
          "description": "List all possible routes through the scenario"
        }
      ]
    }
  ]
}
```

**Menu Guidelines:**
- **Headers**: Max 12 characters
- **Labels**: 1-5 words
- **Descriptions**: Action-oriented, explain what analysis reveals
- **Recommended**: Place first with "(Recommended)" suffix

## Quick Commands

These keywords trigger specific analysis types without the menu:

**Full analysis**:
"Analyze this scenario for narrative completeness"

**Grid check only**:
"Check grid coverage for this scenario"

**Tier check**:
"What tier is this scenario?"

**Find issues**:
"Find structural problems in this scenario"

**Path enumeration**:
"Show all paths through this scenario"

**Precondition map**:
"Show what items and flags are needed where"

## Additional Resources

### Reference Files
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/core.md`** - Nine Cells and tier definitions
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/scenario-format.md`** - YAML format
