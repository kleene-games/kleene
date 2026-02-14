# Analysis Report Format

Specification for the output format of the kleene-analyze skill.

## Report Header

Use a double-line box for the main header:

```
═══════════════════════════════════════════════════════════
KLEENE SCENARIO ANALYSIS
Scenario: [Scenario Name]
═══════════════════════════════════════════════════════════
```

## Section Format

Each section uses a single-line underline:

```
SECTION NAME
────────────
[Content]
```

## Status Indicators

| Symbol | Meaning |
|--------|---------|
| `✓` | Valid / Present / Passing |
| `⚠` | Warning / Suboptimal |
| `✗` | Missing / Error / Failing |
| `○` | Available via fallback/improvisation |
| `!` | Structural issue detected |

## Standard Sections

### Schema Validation

```
SCHEMA VALIDATION
─────────────────
Structure:
  ✓ Required fields present (name, start_node, nodes, endings)
  ✓ start_node 'intro' exists in nodes
  ✓ 47/47 next_node references valid
  ✓ 4/4 blocked_next_node references valid

Types:
  ✓ All precondition types valid (12 unique types used)
  ✓ All consequence types valid (15 unique types used)
  ✓ All options have id and text

on_enter Consequences:
  ✓ 2 nodes use on_enter
  ✓ All on_enter consequence types valid

blocked_next_node Redirects:
  ✓ 4 nodes use blocked_next_node
  ✓ All have associated preconditions
```

### Decision Grid

Display the 3x3 grid with cell coverage and counts:

```
DECISION GRID (9 Cells)
───────────────────────
             │ Permits     │ Indeterminate │ Blocks      │
─────────────┼─────────────┼───────────────┼─────────────┤
Chooses      │ ✓ Triumph   │ ✗ Commitment  │ ✓ Rebuff    │
             │   3 paths   │   0 paths     │   2 paths   │
─────────────┼─────────────┼───────────────┼─────────────┤
Unknown      │ ✓ Discovery │ ○ Limbo       │ ✓ Constraint│
             │   1 scripted│   (fallback)  │   1 scripted│
─────────────┼─────────────┼───────────────┼─────────────┤
Avoids       │ ✓ Escape    │ ✗ Deferral    │ ✓ Fate      │
             │   1 path    │   0 paths     │   1 path    │
─────────────┴─────────────┴───────────────┴─────────────┘

Legend: ✓ = scripted paths, ○ = via improvisation/fallback, ✗ = missing

Grid coverage: 7/9 cells (78%)
  Scripted: 6 cells | Via improvisation: 1 cell | Missing: 2 cells
```

### Unknown Row Details

Show improvisation-based Unknown row coverage:

```
UNKNOWN ROW DETAILS
───────────────────
Scripted Unknown options found: 2
  - intro/ask_elder → Discovery: elder_lore, Constraint: elder_silence
  - mountain_approach/observe_dragon → Discovery: dragon_notices_patience, Constraint: dragon_dismisses_coward
Limbo: Always available as fallback when no pattern matches
```

### Completeness Tier

```
COMPLETENESS TIER
─────────────────
Bronze (4 corners):   4/4 ✓  Triumph, Rebuff, Escape, Fate
Silver (+5 middle):   2/5    Commitment ✗, Discovery ✓, Limbo ○, Constraint ✓, Deferral ✗
Gold (all 9 cells):   6/9    Missing: Commitment, Deferral

Tier achieved: SILVER
```

### Path Details

List paths grouped by cell:

```
PATH DETAILS
────────────
✓ Triumph (3 paths):
  - intro → sword_taken → mountain_approach → dragon_fight → ending_victory
  - intro → forest_entrance → shrine → dragon_dialogue → ending_transcendence
  - ...

✓ Rebuff (2 paths):
  - mountain_approach → dragon_fight (blocked: missing sword)
  - mountain_approach → dragon_dialogue (blocked: missing dragon_tongue)

✓ Escape (1 path):
  - intro → mountain_approach → attempt_flee → ending_fled

✗ Fate (0 paths):
  MISSING: No forced consequence when player tries to avoid
```

### Null Cases

```
NULL CASES
──────────
✓ NONE_DEATH: 2 paths (dragon_fight_unarmed, dragon_refused)
✓ NONE_REMOVED: 1 path (ending_transcendence)
✗ NONE_BLOCKED: 0 paths (no completely blocked endings)
```

### Outcome Distribution

```
OUTCOME DISTRIBUTION
────────────────────
SOME_TRANSFORMED (victory): 1 ending
SOME_UNCHANGED (irony): 1 ending
NONE_DEATH: 1 ending
NONE_REMOVED (transcendence): 1 ending
```

### Structural Issues

```
STRUCTURAL ISSUES
─────────────────
✓ No unreachable nodes
✓ No dead ends
! Railroad detected: intro → sword_taken → mountain_approach (3 nodes, 1 path)
! Single-option choices: 2 nodes
  - scroll_taken: 1 option → mountain_approach
    Recommendation: Add "Return to forest" or "Meditate on knowledge" option
  - forced_march: 1 option → battlefield
    Recommendation: Add "Rest briefly" or "Scout ahead" option
✓ No illusory choices
```

### Dynamic Edges (Improvisation)

```
DYNAMIC EDGES (Improvisation)
─────────────────────────────
2 scripted Unknown options found:
  - temple_gates/observe → Discovery: guardian_respect, Constraint: guardian_dismissal
  - intro/ask_elder → Discovery: elder_lore, Constraint: elder_silence

Pattern coverage:
  permits: ritual, pattern, ceremony, weakness, history, legend
  blocks: attack, force, break, demand, threaten
```

### Deep Structural Analysis

Group yq-enabled analyses:

```
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
```

### v5 Feature Sections

For scenarios using v5 features:

```
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

TRAVEL CONSISTENCY (v5)
───────────────────────
Travel config: enabled (default: 30 min)
✓ 12/12 connections have travel_time (or use default)
✓ Bidirectional times consistent
⚠ dragon_descends (12h): Minimum path to dragon_lair is 7.5h
  (village→forest→shrine→village→mountain = 450 min)
✓ Improvisation time configured for all intents
```

### Recommendations

End with actionable suggestions:

```
RECOMMENDATIONS
───────────────
1. Add "Fate" path (required for Bronze):
   - Suggestion: When fleeing, dragon pursues and forces confrontation

2. For Silver tier, add 2+ middle cells:
   - Commitment: Action with pending outcome (drink potion, send messenger)
   - Deferral: Avoidance that builds tension (hide, postpone)
```

## Complete Example Report

See the complete example in `skills/kleene-analyze/SKILL.md` → "Report Format" section.

## Severity Guidelines

| Severity | When to Use |
|----------|-------------|
| Error (`✗`) | Required field missing, broken reference, impossible requirement |
| Warning (`⚠`) | Suboptimal design, potential bug, inconsistency |
| Info (`!`) | Structural observation, design pattern detected |
| OK (`✓`) | Validation passed, feature working correctly |
