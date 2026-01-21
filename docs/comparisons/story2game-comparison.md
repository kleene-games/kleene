# Analysis: Kleene Framework vs. Story2Game Paper

## Overview

This document compares the **Kleene narrative engine** against the **Story2Game** paper (Zhou et al., Georgia Tech, arXiv:2505.03547v1) which presents an LLM-based approach to generating complete text-based interactive fiction games.

Both systems use LLMs to generate and run interactive fiction, but with fundamentally different architectures and philosophies.

---

## The Two Systems at a Glance

| Aspect | **Story2Game** | **Kleene** |
|--------|----------------|------------|
| **Goal** | Generate playable IF games from prompts | Generate, validate, and play IF with narrative completeness |
| **Architecture** | Three-stage pipeline (story→world→code) | Three skills (generate→analyze→play) + JSON Schema |
| **Generation Target** | Executable Python code | YAML scenarios validated against schema |
| **Player Actions** | Dynamic code generation for novel verbs | Soft consequence system + intent classification |
| **State Model** | Object graph with attributes | Character/World/Location state with 23+ precondition types |
| **Uncertainty** | Binary (action succeeds/fails compilation) | Three-valued (permits/indeterminate/blocks) |
| **Completeness** | Compilation success rate (~80%) | Decision Grid coverage tiers (Bronze/Silver/Gold) |
| **Validation** | Code compilation | 15 analysis types + JSON Schema validation |

---

## Generation Capabilities

### Story2Game: Code Generation Pipeline

Story2Game generates complete games through three stages:

1. **Story Generation**: LLM creates narrative with preconditions/effects for each action
2. **World Population**: Rooms, characters, objects instantiated based on story
3. **Game Engine Code**: Python code generated to manipulate game state

**Output**: Executable game code
**Completeness metric**: Does it compile? (~80-97% success)

### Kleene: Scenario Generation with Grid Coverage

Kleene's `kleene-generate` skill creates scenarios through:

1. **Theme Understanding**: Interactive menus for tone, tier, protagonist archetype
2. **Narrative Skeleton Design**: Structure based on target tier (Bronze/Silver/Gold)
3. **Element Definition**: Traits, items, flags designed for mechanical depth
4. **Node Generation**: Narrative + choices + preconditions + consequences
5. **Grid Coverage Verification**: Ensure all required cells are covered
6. **Schema Validation**: Output validated against JSON Schema
7. **Registry Integration**: Generated scenarios immediately playable

**Output**: YAML scenario validated against 1100-line JSON Schema
**Completeness metric**: Decision Grid coverage (9 cells)

### Generation Comparison

| Feature | Story2Game | Kleene |
|---------|------------|--------|
| Input | Title + events + setting | Theme + tone + tier + archetype |
| Output format | Python code | YAML with JSON Schema validation |
| Validation | Compilation | 15 analysis types + schema |
| Iteration | Re-generate | Branch expansion to improve coverage |
| Designer involvement | Minimal | Interactive menus throughout |

---

## State Model Sophistication

### Story2Game: Object-Attribute Model

Story2Game tracks:
- Objects with binary (true/false) or numeric (0-10) attributes
- Room graph with object positions
- Player inventory

Attributes are generated on-demand when players try novel actions.

### Kleene: Multi-Layer State System

Kleene tracks via JSON Schema-validated structures:

**Character State:**
- `exists` (boolean) - Option type: Some/None
- `traits` (object) - Named numeric values (courage, wisdom, etc.)
- `inventory` (array) - Items held
- `relationships` (object) - NPC relationship values
- `flags` (object) - Character-specific boolean states

**World State:**
- `current_location` - Position in location graph
- `time` (number) - Elapsed time in seconds
- `flags` (object) - World-level boolean states
- `location_state` (object) - Per-location mutable state
- `npc_locations` (object) - NPC position tracking
- `scheduled_events` (array) - Time-triggered consequences
- `triggered_events` (array) - Event history

**Location State (per location):**
- `flags` - Location-specific booleans
- `properties` - Location-specific numerics
- `environment` - Atmospheric conditions (lighting, temperature, etc.)

### Precondition Richness

| Story2Game | Kleene (23+ types) |
|------------|-------------------|
| Location check | `at_location` |
| Inventory check | `has_item`, `missing_item` |
| Attribute check | `trait_minimum`, `trait_maximum` |
| - | `flag_set`, `flag_not_set` |
| - | `relationship_minimum` |
| - | `location_flag_set`, `location_flag_not_set` |
| - | `location_property_minimum`, `location_property_maximum` |
| - | `environment_is`, `environment_minimum`, `environment_maximum` |
| - | `npc_at_location`, `npc_not_at_location` |
| - | `time_elapsed_minimum`, `time_elapsed_maximum` |
| - | `event_triggered`, `event_not_triggered` |
| - | `all_of`, `any_of`, `none_of` (composable) |

Story2Game generates attributes on-demand. Kleene requires authored preconditions but provides much richer expressiveness.

---

## Handling Unanticipated Player Actions

### Story2Game: Dynamic Code Generation

When players try unexpected actions:

1. **Essential Object Preconditions**: Create missing objects, place in world
2. **Fundamental/Additional Preconditions**: Add attributes to existing objects
3. **Preceding Event Preconditions**: Generate prerequisite actions (1-level depth)
4. **Attribute Effects**: Cascade new attributes to existing actions

**Result**: ~80% compilation success, ~60% semantic success

**Key limitation**: Can't model room properties (e.g., "illuminate the forest" fails)

### Kleene: Bounded Improvisation System

When players type free-text:

1. **Intent Classification**: Explore / Interact / Act / Meta
2. **Feasibility Check**: Possible / Blocked / Impossible / Ambiguous
3. **Grid Mapping**: Discovery (permits) / Constraint (blocks) / Limbo (ambiguous)
4. **Soft Consequences Only**:
   - `modify_trait` (±1 max)
   - `add_history`
   - `set_flag` (only `improv_*` prefix)
   - `advance_time`
5. **Temperature-Based Adaptation**: 0-10 scale controls narrative integration
6. **Return to Authored Choices**: Player stays at same decision point

**Key principle**: Improvisation enriches without derailing authored structure.

### Comparison

| Scenario | Story2Game | Kleene |
|----------|------------|--------|
| "Cut rope with scissors" | Generate scissors, place in world, generate code | Constraint: "You don't have scissors" (teaches player) |
| "Examine dragon scales" | Generate `scale_pattern` attribute | Discovery: +1 wisdom, `improv_examined_dragon_scales` flag |
| "Illuminate the forest" | Fails (rooms lack properties) | Discovery/Constraint based on items + location environment state |
| "Kill the dragon" | Generate fight code, may create weapon | Constraint if no weapon; boss fights reserved for authored paths |

---

## Validation and Analysis

### Story2Game: Compilation-Based

Validation is binary: does the generated code compile?

- Individual actions: ~97% success
- Complete stories: ~87.5% success
- Semantic correctness: ~60% success

No structural analysis of narrative coverage.

### Kleene: 15 Analysis Types

The `kleene-analyze` skill performs:

| # | Analysis | Description |
|---|----------|-------------|
| 1 | Grid Coverage | Check 9-cell coverage, determine tier |
| 2 | Null Cases | Verify death, departure, blocked paths exist |
| 3 | Structural | Find unreachable nodes, dead ends, railroads |
| 4 | Path Enumeration | List all paths from start to endings |
| 5 | Cycle Detection | Find loops, self-referential choices |
| 6 | Item Obtainability | Verify required items are obtainable |
| 7 | Trait Balance | Detect impossible trait requirements |
| 8 | Flag Dependencies | Find unused/unobtainable flags |
| 9 | Relationship Network | Map NPC relationship dynamics |
| 10 | Consequence Magnitude | Flag over/undersized consequences |
| 11 | Scene Pacing | Analyze scene_break usage |
| 12 | Path Diversity | Identify false choices, railroads |
| 13 | Ending Reachability | Verify all endings are reachable |
| 14 | Travel Consistency | Validate travel time config |
| 15 | Schema Validation | Validate structure, types, references |

Plus JSON Schema validation against 1100-line schema with:
- All precondition types validated
- All consequence types validated
- Reference integrity (next_node targets exist)
- Type correctness throughout

---

## The Uncertainty Question

### Story2Game: Binary Outcomes

Actions either:
- Compile successfully → Execute
- Fail compilation → Error

No "pending" or "indeterminate" state. The system generates deterministic code.

### Kleene: Three-Valued Logic

Based on Kleene's 1938 three-valued logic:

| Value | Meaning | Example |
|-------|---------|---------|
| **Permits** | Action succeeds | Door opens |
| **Blocks** | Action fails | Door locked, key required |
| **Indeterminate** | Outcome pending | Potion drunk, effects unknown |

This enables the **Commitment** cell: "You drink the potion. Its effects haven't manifested yet."

Story2Game would need to immediately generate the potion's effects. Kleene can hold suspense via scheduled events that trigger later.

---

## Completeness Models

### Story2Game: Structural Metrics

- Does the story have the requested number of events?
- Does the generated code compile?
- Can preconditions be satisfied?

No consideration of whether the narrative covers different player strategies (action vs. avoidance, success vs. failure).

### Kleene: Decision Grid Coverage

The 3×3 grid defines 9 possible narrative outcomes:

|                    | World Permits | World Indeterminate | World Blocks |
|--------------------|---------------|---------------------|--------------|
| **Player Chooses** | Triumph       | Commitment          | Rebuff       |
| **Player Unknown** | Discovery     | Limbo               | Constraint   |
| **Player Avoids**  | Escape        | Deferral            | Fate         |

**Completeness Tiers:**

| Tier | Coverage | Required Cells |
|------|----------|----------------|
| Bronze | 4/9 | Triumph, Rebuff, Escape, Fate + death path + victory path |
| Silver | 6+/9 | Bronze + 2 middle cells (Commitment, Discovery, etc.) |
| Gold | 9/9 | All cells scripted or via improvisation |

A scenario with 10 endings could still be Bronze-incomplete if all endings are victories (no Rebuff, Escape, or Fate).

---

## Architectural Strengths

### Story2Game Strengths
1. **Zero authoring**: Title + theme → playable game
2. **Emergent objects**: World expands for player creativity
3. **Executable semantics**: Code guarantees consistent behavior

### Kleene Strengths
1. **Narrative completeness theory**: Formal framework for coverage
2. **Rich state model**: 23+ precondition types, location state, NPCs, events
3. **Validation pipeline**: 15 analysis types catch problems before play
4. **Bounded improvisation**: Player creativity within authored structure
5. **Iterative improvement**: Generate → Analyze → Expand branches → Re-analyze

---

## Architectural Weaknesses

### Story2Game Weaknesses
1. **60% semantic success**: Many actions don't match expectations
2. **No structural room properties**: Can't model environment changes
3. **No uncertainty modeling**: Everything resolves immediately
4. **No validation beyond compilation**: Narrative quality unchecked
5. **Object proliferation**: May create incoherent world state

### Kleene Weaknesses
1. **Requires authoring or generation**: Not instant
2. **Soft consequence limits**: Players can't create objects via improvisation
3. **Complexity**: 1100-line schema, 15 analysis types to understand

---

## What Each System Could Learn

### What Kleene Could Adopt from Story2Game

1. **Object creation in improvisation**: Limited emergent objects (flavor items, not key items)
2. **Automatic world population**: Generate location graphs from narrative

### What Story2Game Could Adopt from Kleene

1. **Decision Grid coverage**: Ensure generated stories cover failure and avoidance paths
2. **Validation pipeline**: Analyze before play, not just compile
3. **Three-valued outcomes**: Support pending/indeterminate states
4. **Soft/hard consequence boundary**: Protect authored structure from generation drift
5. **Completeness tiers**: Define what makes a generated game narratively complete

---

## Synthesis: Kleene as Complete Pipeline

Story2Game demonstrates that LLMs can generate playable games. Kleene demonstrates that LLMs can generate, validate, and iterate on narratively complete games.

| Phase | Story2Game | Kleene |
|-------|------------|--------|
| **Generate** | Story→World→Code | Theme→Skeleton→Nodes with grid targeting |
| **Validate** | Compilation only | 15 analysis types + JSON Schema |
| **Iterate** | Re-generate | Branch expansion to raise tier |
| **Play** | Execute generated code | Play with bounded improvisation |

Kleene's approach is more labor-intensive but produces scenarios that are:
- Validated against formal schema
- Analyzed for narrative completeness
- Expandable to improve coverage
- Playable with improvisation that respects structure

---

## References

**Story2Game Paper:**
- Zhou, E., Basavatia, S., Siam, M., Chen, Z., & Riedl, M. O. (2025). Story2Game: Generating (Almost) Everything in an Interactive Fiction Game. arXiv:2505.03547v1
- https://arxiv.org/html/2505.03547v1

**Kleene Framework:**
- `lib/framework/core/core.md` - Decision Grid, Option types, completeness tiers
- `lib/framework/gameplay/improvisation.md` - Soft consequences, intent classification, temperature
- `lib/schema/scenario-schema.json` - 1100-line JSON Schema (23+ preconditions, 22+ consequences)
- `skills/kleene-generate/SKILL.md` - Generation modes, grid targeting, branch expansion
- `skills/kleene-analyze/SKILL.md` - 15 analysis types, validation pipeline
- `docs/design/theoretical_background.md` - Three-valued logic foundations
