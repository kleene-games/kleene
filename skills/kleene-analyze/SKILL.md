---
name: kleene-analyze
description: This skill should be used when the user asks to "analyze a scenario", "check narrative completeness", "find missing paths", "validate my scenario", "show grid coverage", "check item obtainability", "analyze traits", "find cycles", or wants to understand the structure of a Kleene scenario. Performs graph analysis, Decision Grid coverage checking, and deep structural analysis (yq-enabled) including item/trait/flag dependencies, relationship networks, consequence magnitude, scene pacing, and path diversity.
version: 0.4.0
allowed-tools: Read, Glob, Grep, AskUserQuestion, Bash
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

### 5. Cycle Detection (yq-enabled)
Find loops, self-referential choices, and escape impossibility.

### 6. Item Obtainability Analysis (yq-enabled)
Verify all required items can actually be obtained somewhere in the scenario.

### 7. Trait Balance Analysis (yq-enabled)
Detect traits that can only increase/decrease, and impossible trait requirements.

### 8. Flag Dependency Graph (yq-enabled)
Find flags that are set but never checked, or required but never set.

### 9. Relationship Network Analysis (yq-enabled)
Map NPC relationship changes and identify one-way relationships.

### 10. Consequence Magnitude Analysis (yq-enabled)
Flag over/undersized consequences based on improvisation guidelines.

### 11. Scene Pacing Analysis (yq-enabled)
Analyze scene_break usage and estimate beat accumulation between breaks.

### 12. Path Diversity Analysis (yq-enabled)
Identify false choices, railroads, branching factor, and chokepoints.

### 13. Ending Reachability Analysis (yq-enabled)
Verify all defined endings are actually reachable from start.

## Workflow

> **Tool Detection:** See `lib/patterns/tool-detection.md` for yq availability check.
> **Templates:** See `lib/patterns/yaml-extraction.md` for all extraction patterns.

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

**yq Optimization (if yaml_tool=yq):**

Extract only structural data, skipping narratives (~60% token savings):

```bash
yq '.nodes | to_entries | .[] | {"node": .key, "options": [.value.choice.options[] | {"id": .id, "cell": .cell, "next": (.next_node // .next), "precondition": .precondition}]}' scenario.yaml
```

This returns the graph structure without narrative text, significantly reducing tokens for large scenarios.

### Step 3: Analyze Reachability

From start_node, find all reachable nodes using BFS/DFS.

**IMPORTANT:** Distinguish between static and dynamic edges:

- **Static edges** (`next_node`) - Always in graph, unconditionally reachable
- **Dynamic edges** (`next: improvise` with `outcome_nodes`) - Conditionally reachable via pattern matching

Nodes referenced ONLY in `outcome_nodes` should be reported as "conditionally reachable via improvisation" NOT as "unreachable".

```
REACHABILITY ANALYSIS
─────────────────────
Static reachable: [intro, sword_taken, forest_entrance, ...]
Conditionally reachable (via improvisation): [guardian_respect, guardian_dismissal, elder_lore, elder_silence]
Unreachable: [orphan_node_1]
```

**yq query to identify improvisation outcome nodes:**
```bash
# Extract all nodes reachable via improvisation
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | select(.next == "improvise") | .outcome_nodes | to_entries | .[] | .value] | flatten | unique | .[]' scenario.yaml
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

**yq Optimization (if yaml_tool=yq):**

Get cell coverage report in a single query:

```bash
yq '[.nodes | to_entries | .[] | .value.choice.options[] | select(.cell)] | group_by(.cell) | .[] | {"cell": .[0].cell, "count": length}' scenario.yaml
```

For each path, determine cell in the 3x3 grid based on two axes:

**Player Axis (Chooses / Unknown / Avoids)**:
- **Chooses**: Takes decisive action toward goal (fight, speak, help, take)
- **Unknown**: Hesitates, explores, or improvises ("Other" selection, `improv_*` flags)
- **Avoids**: Retreats, refuses, flees, ignores

**World Axis (Permits / Indeterminate / Blocks)**:
- **Permits**: Path available, action succeeds, preconditions met
- **Indeterminate**: Outcome pending, no ending reached, multiple continuations
- **Blocks**: Precondition prevents progress, action fails

**The Decision Grid** (see `lib/framework/core.md` for detailed definitions):
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

DYNAMIC EDGES (Improvisation)
─────────────────────────────
2 scripted Unknown options found:
  - temple_gates/observe → Discovery: guardian_respect, Revelation: guardian_dismissal
  - intro/ask_elder → Discovery: elder_lore, Revelation: elder_silence

Pattern coverage:
  permits: ritual, pattern, ceremony, weakness, history, legend
  blocks: attack, force, break, demand, threaten

DEEP STRUCTURAL ANALYSIS (yq-enabled)
─────────────────────────────────────
CYCLES
  ✓ No self-loops
  ✓ No multi-node cycles

ITEM OBTAINABILITY
  ✓ 4/4 required items obtainable

TRAIT BALANCE
  ✓ courage: all requirements achievable (max: 11)
  ⚠ corruption: can only increase (no redemption)

FLAG DEPENDENCIES
  ✓ 3/4 checked flags are settable
  ⚠ betrayed_ally: set but never checked
  ✗ knows_truth: required but never set

RELATIONSHIPS
  ✓ elder: bidirectional
  ⚠ villain: can only worsen

CONSEQUENCE MAGNITUDE
  ⚠ 1 oversized (village/help_stranger)
  Distribution: ±1-3: 72%, ±5-10: 19%, ±15+: 8%

SCENE PACING
  Explicit breaks: 3, Auto-breaks: 12
  ⚠ Longest sequence: 5 nodes without break

PATH DIVERSITY
  Branching factor: 2.3
  ! 1 false choice (village_square)
  ! 1 railroad (intro → sword → training)

ENDING REACHABILITY
  ✓ 5/6 endings reachable
  ✗ ending_secret: no path found

LOCATION STATE VALIDATION (v5)
──────────────────────────────
Location flags set: village.quest_completed, shrine.blessed
Location flags checked: village.quest_completed ✓, shrine.visited ✗ (never set)
Location properties: shrine.blessing_power (modified: +50, -10)

NODE PRECONDITION VALIDATION (v5)
─────────────────────────────────
Gated nodes: 3 (inner_sanctum, dragon_lair, secret_chamber)
✓ inner_sanctum: blocked_narrative defined
⚠ dragon_lair: missing blocked_narrative (will use fallback)
✓ secret_chamber: blocked_narrative defined

NPC LOCATION VALIDATION (v5)
────────────────────────────
NPCs defined: guardian, merchant, oracle
NPCs moved: guardian (temple_gates → temple_interior)
NPCs checked: guardian ✓, merchant ✓, oracle (never checked)
⚠ herald: referenced but never defined in npc_locations

TEMPORAL/EVENT VALIDATION (v5)
──────────────────────────────
Events scheduled: quest_deadline, guardian_moves
Events checked: quest_deadline ✓, dragon_attack ✗ (never scheduled)
Time preconditions: 2 (time_elapsed_minimum at inner_sanctum)
⚠ midnight_ritual: scheduled but never checked

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

**yq Optimization (if yaml_tool=yq):**

Extract all preconditions in a single query (impossible with grep):

```bash
yq '.nodes | to_entries | .[] | .value.choice.options[] | select(.precondition) | {"node": (parent | parent | parent | .key), "option": .id, "requires": .precondition}' scenario.yaml
```

Find all nodes requiring a specific item:

```bash
yq '.nodes | to_entries | .[] | select(.value.choice.options[].precondition.item == "rusty_sword") | {"node": .key, "requires": "rusty_sword"}' scenario.yaml
```

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

**Note:** The precondition dependency queries are only possible with yq. When using grep fallback, this analysis is limited.

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

## Deep Structural Analysis (yq-enabled)

These analyses require yq 4.x and provide capabilities impossible with grep.

### Cycle Detection

Find self-loops and multi-node cycles:

```bash
# Self-loops (node points to itself)
yq '.nodes | to_entries | .[] | {node: .key, dests: [.value.choice.options[] | (.next_node // .next)]} | select(.dests[] == .node)' scenario.yaml

# Build adjacency for multi-node cycle detection
yq '.nodes | to_entries | .[] | {node: .key, destinations: [.value.choice.options[] | (.next_node // .next)] | unique}' scenario.yaml
```

**Report:**
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
yq '.nodes | to_entries | .[] | .value.choice.options[]? | select(.consequence[]?.type == "gain_item") | {node: (parent | parent | parent | .key), option: .id, gains: [.consequence[] | select(.type == "gain_item") | .item]}' scenario.yaml
```

**Report:**
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
yq '.nodes | to_entries | .[] | .value.choice.options[]? | select(.precondition?.type == "trait_minimum") | {node: (parent | parent | parent | .key), option: .id, trait: .precondition.trait, minimum: .precondition.minimum}' scenario.yaml

# Starting traits
yq '.initial_character.traits' scenario.yaml
```

**Report:**
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
yq '.nodes | to_entries | .[] | .value.choice.options[]? | select(.consequence[]?.type == "set_flag") | {node: (parent | parent | parent | .key), option: .id, sets: [.consequence[] | select(.type == "set_flag") | .flag]}' scenario.yaml
```

**Report:**
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

**Report:**
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
yq '.nodes | to_entries | .[] as $node | $node.value.choice.options[]? | select(.consequence) | {node: $node.key, option: .id, changes: [.consequence[] | select(.type == "modify_trait" or .type == "modify_relationship") | {type, target: (.trait // .npc), delta}]}' scenario.yaml
```

**Guidelines reference:**
- ±1-3: Minor/improvised actions
- ±5-10: Major scripted decisions
- ±15-50: Catastrophic events

**Report:**
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

**Report:**
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
yq '.nodes | to_entries | .[] | {node: .key, options: (.value.choice.options | length), unique_dests: ([.value.choice.options[] | (.next_node // .next)] | unique | length)}' scenario.yaml

# False choices (multiple options → same destination)
yq '.nodes | to_entries | .[] | {node: .key, options: [.value.choice.options[] | {id: .id, dest: (.next_node // .next)}]} | select((.options | map(.dest) | unique | length) < (.options | length))' scenario.yaml
```

**Report:**
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

**Report:**
```
ENDING REACHABILITY
───────────────────
Defined: 6 endings
Reachable: 5 endings

✗ ending_secret: No path found
```

### Location State Validation (v5)

Verify location flags and properties are used correctly:

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

**Report:**
```
LOCATION STATE VALIDATION
─────────────────────────
Flags set:     village.quest_completed, shrine.blessed
Flags checked: village.quest_completed ✓, shrine.visited ✗ (never set)
Properties:    shrine.blessing_power (modified: +50, -10)
Environment:   shrine.lighting → dark, temple.ambiance → sacred

⚠ shrine.visited: checked but never set
```

### Node Precondition Validation (v5)

Verify all gated nodes have proper blocked narratives:

```bash
# Nodes with preconditions
yq '[.nodes | to_entries | .[] | select(.value.precondition) | .key] | .[]' scenario.yaml

# Nodes with preconditions but missing blocked_narrative
yq '.nodes | to_entries | .[] | select(.value.precondition and (.value.blocked_narrative | not)) | .key' scenario.yaml

# Check precondition types used in node gating
yq '[.nodes | to_entries | .[] | select(.value.precondition) | {node: .key, precondition_type: .value.precondition.type}] | .[]' scenario.yaml
```

**Report:**
```
NODE PRECONDITION VALIDATION
────────────────────────────
Gated nodes: 3
  ✓ inner_sanctum: all_of - blocked_narrative defined
  ⚠ dragon_lair: has_item - missing blocked_narrative (will use fallback)
  ✓ secret_chamber: flag_set - blocked_narrative defined

Recommendation: Add blocked_narrative to dragon_lair for better player experience.
```

### NPC Location Validation (v5)

Verify NPC tracking is consistent:

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

**Report:**
```
NPC LOCATION VALIDATION
───────────────────────
Defined:  guardian (temple_gates), merchant (market), oracle (temple_interior)
Moved:    guardian (via trial_choice → temple_interior)
Checked:  guardian ✓, merchant ✓
Unused:   oracle (never checked)

⚠ herald: referenced in precondition at temple_announcement but not defined in npc_locations
```

### Temporal/Event Validation (v5)

Verify scheduled events and time preconditions are consistent:

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

**Report:**
```
TEMPORAL/EVENT VALIDATION
─────────────────────────
Events:
  Scheduled: guardian_moves, quest_deadline, midnight_ritual
  Checked:   guardian_moves ✓, quest_deadline ✓
  Cancelled: quest_deadline (via complete_quest)

Time mechanics:
  advance_time: 8 consequences
  time_elapsed_minimum: 2 preconditions
  time_elapsed_maximum: 1 precondition

⚠ midnight_ritual: scheduled but never checked (dead event?)
⚠ dragon_arrival: checked but never scheduled
```

### Improvisation Coverage Analysis (v5)

Detailed analysis of scripted Unknown options:

```bash
# Find all improvise options
yq '.nodes | to_entries | .[] | {node: .key, options: [.value.choice.options[] | select(.next == "improvise") | {id: .id, theme: .improvise_context.theme, permits: .improvise_context.permits, blocks: .improvise_context.blocks, outcomes: .outcome_nodes}]}' scenario.yaml

# Aggregate all permits patterns
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | select(.next == "improvise") | .improvise_context.permits[]?] | flatten | unique | .[]' scenario.yaml

# Aggregate all blocks patterns
yq '[.nodes | to_entries | .[] | .value.choice.options[]? | select(.next == "improvise") | .improvise_context.blocks[]?] | flatten | unique | .[]' scenario.yaml
```

**Report:**
```
IMPROVISATION COVERAGE
──────────────────────
2 scripted Unknown options:

  temple_gates / observe:
    Theme: "observing the temple guardian"
    → Discovery: guardian_respect (permits: ritual, pattern, ceremony)
    → Revelation: guardian_dismissal (blocks: attack, force, break)
    → Limbo: stays at node (fallback)

  intro / ask_elder:
    Theme: "seeking wisdom before action"
    → Discovery: elder_lore (permits: history, weakness, legend)
    → Revelation: elder_silence (blocks: demand, threaten, force)
    → Limbo: stays at node (fallback)

Pattern keywords:
  Permits (Discovery): ritual, pattern, ceremony, history, weakness, legend, why, story
  Blocks (Revelation): attack, force, break, demand, threaten, lie
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

### v5 Feature Validation

- [ ] Location flags checked are also set somewhere
- [ ] Location properties checked are also modified somewhere
- [ ] Gated nodes have blocked_narrative defined
- [ ] NPCs referenced in preconditions are defined in npc_locations
- [ ] Scheduled events are checked somewhere (not dead events)
- [ ] Event preconditions reference scheduled events
- [ ] Improvisation outcome_nodes reference valid nodes

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
          "description": "Complete grid coverage, structure, deep analysis, and paths"
        },
        {
          "label": "Grid coverage",
          "description": "Check all nine narrative cells and determine tier"
        },
        {
          "label": "Deep structural (yq)",
          "description": "Items, traits, flags, relationships, cycles, pacing"
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

**Menu Guidelines:** See `lib/framework/presentation.md` → "Menu Conventions".

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

**Deep structural analysis** (yq required):
"Run deep analysis on this scenario"

**Item obtainability**:
"Check if all required items can be obtained"

**Trait balance**:
"Analyze trait modifications and requirements"

**Flag dependencies**:
"Find unused or unobtainable flags"

**Relationship network**:
"Map NPC relationship dynamics"

**Consequence magnitude**:
"Check consequence scaling"

**Scene pacing**:
"Analyze scene break distribution"

**Path diversity**:
"Find false choices and railroads"

**Ending reachability**:
"Verify all endings are reachable"

**Cycle detection**:
"Find loops and self-referential choices"

## Additional Resources

### Reference Files
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/core.md`** - Decision Grid and tier definitions
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/scenario-format.md`** - YAML format
