# Analysis: Kleene Framework vs. Microsoft Research GENEVA

## Overview

This document compares the **Kleene narrative engine** against **GENEVA** (Leandro et al., Microsoft Research, IEEE CoG 2024), a graph-based tool for generating and visualizing branching narratives using GPT-4.

Both systems use LLMs for narrative generation, but serve different purposes in the game development pipeline.

**Paper:** [GENEVA: GENErating and Visualizing branching narratives using LLMs](https://arxiv.org/abs/2311.09213)
**Interactive Demo:** https://narrative.msr-emergence.com/

---

## The Two Systems at a Glance

| Aspect | **GENEVA** | **Kleene** |
|--------|------------|------------|
| **Primary Purpose** | Visualize branching narratives for designers | Generate, validate, and play interactive narratives |
| **Pipeline Phase** | Design-time visualization | Design-time generation + validation + runtime play |
| **Output** | Visual DAG of narrative beats | Validated YAML scenarios + interactive gameplay |
| **LLM Role** | Generate story structure | Generate, validate, interpret, and adapt |
| **Target User** | Game designers | Game designers AND players |
| **Validation** | Visual inspection | 15 analysis types + JSON Schema |
| **Runtime Support** | None (design tool only) | Full play engine with improvisation |

---

## Generation Capabilities

### GENEVA: Constrained Graph Generation

GENEVA accepts:
- High-level narrative description
- Structural constraints (# starts, # endings, # plot paths)
- Context for grounding (setting, time period)

GENEVA produces:
- DAG of narrative beats (events that move plot forward)
- Visual graph for designer exploration
- Branching and reconverging storylines

**Key constraint**: Number of paths, not narrative quality metrics.

### Kleene: Grid-Targeted Generation with Validation

Kleene's `kleene-generate` accepts:
- Theme description
- Tone (Heroic/Tragic/Comedic/Mysterious)
- Completeness tier target (Bronze/Silver/Gold)
- Protagonist archetype

Kleene produces:
- YAML scenario with nodes, choices, preconditions, consequences
- Validated against 1100-line JSON Schema
- Analyzed for Decision Grid coverage
- Immediately playable with improvisation support

**Key constraint**: Decision Grid coverage (narrative possibility space).

### Generation Comparison

| Feature | GENEVA | Kleene |
|---------|--------|--------|
| **Input constraints** | # paths, # endings | Grid tier, tone, archetype |
| **Output format** | Visual graph | Validated YAML + registry entry |
| **Validation** | Visual inspection | 15 analysis types + JSON Schema |
| **Mechanical depth** | Narrative beats only | Preconditions, consequences, traits, items, flags |
| **Iterability** | Re-generate | Branch expansion to improve tier |
| **Designer workflow** | View → manually implement | Generate → analyze → expand → play |

---

## Completeness Models

### GENEVA: Structural Completeness

GENEVA measures:
- Number of starting points achieved
- Number of endings achieved
- Number of distinct plot paths
- Graph connectivity

These are **structural** metrics: does the graph satisfy the requested constraints?

A GENEVA graph with 6 endings might have all victories—no measurement of whether failure, avoidance, or uncertainty are represented.

### Kleene: Narrative Completeness via Decision Grid

Kleene measures coverage of the 3×3 Decision Grid:

|                    | World Permits | World Indeterminate | World Blocks |
|--------------------|---------------|---------------------|--------------|
| **Player Chooses** | Triumph       | Commitment          | Rebuff       |
| **Player Unknown** | Discovery     | Limbo               | Constraint   |
| **Player Avoids**  | Escape        | Deferral            | Fate         |

**Completeness Tiers:**

| Tier | Coverage | Meaning |
|------|----------|---------|
| Bronze | 4/9 | Four corners (Triumph, Rebuff, Escape, Fate) + death + victory paths |
| Silver | 6+/9 | Bronze + middle cells (Commitment, Discovery, Deferral, etc.) |
| Gold | 9/9 | All cells represented |

Kleene's `kleene-analyze` skill checks:
- Which cells have paths
- Whether death endings exist (NONE_DEATH)
- Whether transcendence endings exist (NONE_REMOVED)
- Whether both transformed and unchanged endings exist

A scenario with many paths could still be Bronze-incomplete if it lacks avoidance or failure options.

---

## Validation Capabilities

### GENEVA: Visual Inspection

Designers view the generated graph and manually assess:
- Narrative quality
- Path coherence
- Story flow

No automated validation beyond graph structure.

### Kleene: 15 Analysis Types + JSON Schema

The `kleene-analyze` skill performs:

| # | Analysis | What It Catches |
|---|----------|-----------------|
| 1 | Grid Coverage | Missing player intent/world response combinations |
| 2 | Null Cases | No death path, no transcendence path |
| 3 | Structural | Unreachable nodes, dead ends, railroads |
| 4 | Path Enumeration | Full path listing for manual review |
| 5 | Cycle Detection | Infinite loops |
| 6 | Item Obtainability | Required item never granted |
| 7 | Trait Balance | Impossible trait requirements |
| 8 | Flag Dependencies | Flag checked but never set |
| 9 | Relationship Network | NPC relationship issues |
| 10 | Consequence Magnitude | Over/undersized trait changes |
| 11 | Scene Pacing | Rhythm issues |
| 12 | Path Diversity | False choices (multiple options → same destination) |
| 13 | Ending Reachability | Endings with no path to them |
| 14 | Travel Consistency | Time config issues |
| 15 | Schema Validation | Type errors, missing fields, broken references |

Plus JSON Schema validation with:
- 23+ precondition types validated
- 22+ consequence types validated
- Reference integrity (all next_node targets exist)
- Type correctness throughout

---

## Mechanical Depth

### GENEVA: Narrative Beats Only

GENEVA generates:
- Narrative text for each beat
- Connections between beats

No mechanical representation of:
- What the player needs to reach a beat
- What changes when a beat is visited
- Character state or world state

Implementation of mechanics is left to later development.

### Kleene: Full Mechanical Specification

Kleene scenarios include:

**Preconditions (23+ types):**
- Item checks: `has_item`, `missing_item`
- Trait checks: `trait_minimum`, `trait_maximum`
- Flag checks: `flag_set`, `flag_not_set`
- Location checks: `at_location`, `location_flag_set`, `location_property_minimum`
- Environment checks: `environment_is`, `environment_minimum`
- NPC checks: `npc_at_location`, `npc_not_at_location`
- Time checks: `time_elapsed_minimum`, `time_elapsed_maximum`
- Event checks: `event_triggered`, `event_not_triggered`
- Composable: `all_of`, `any_of`, `none_of`

**Consequences (22+ types):**
- Items: `gain_item`, `lose_item`
- Traits: `modify_trait`, `set_trait`
- Flags: `set_flag`, `clear_flag`
- Relationships: `modify_relationship`
- Location: `move_to`, `set_location_flag`, `modify_location_property`, `set_environment`
- NPCs: `move_npc`
- Time: `advance_time`
- Events: `schedule_event`, `trigger_event`, `cancel_event`
- Endings: `character_dies`, `character_departs`
- History: `add_history`

This enables scenarios with:
- Location-specific puzzles (shrine is sealed until blessing_power reaches threshold)
- NPC movement (merchant follows player to new location)
- Scheduled events (poison takes effect 30 minutes after consumption)
- Environmental changes (lighting changes based on player actions)

---

## Runtime Support

### GENEVA: None

GENEVA is a design-time tool. Generated graphs must be manually implemented in a game engine before players can experience them.

### Kleene: Full Play Engine

Kleene's `kleene-play` skill provides:

**Core Gameplay:**
- Load scenario from YAML
- Track character/world state
- Evaluate preconditions
- Apply consequences
- Present choices via interactive menus

**Improvisation System:**
- Free-text input handling
- Intent classification (Explore/Interact/Act/Meta)
- Feasibility checking
- Grid mapping (Discovery/Constraint/Limbo)
- Soft consequences (±1 traits, improv_* flags)
- Temperature-based narrative adaptation (0-10 scale)

**Advanced Features:**
- Save/load system with timestamped saves
- Rewind to previous decision points
- Export to transcript/summary/stats
- Gallery mode for educational meta-commentary
- Parser mode (text adventure-style, hide scripted options)

---

## Workflow Comparison

### GENEVA Workflow

```
Designer provides description + constraints
         ↓
    GENEVA generates DAG
         ↓
    Designer views graph
         ↓
    Manual implementation in game engine
         ↓
    Players experience game
```

Gap: Significant manual work between generation and play.

### Kleene Workflow

```
Designer/LLM provides theme + tier + tone
         ↓
    kleene-generate creates scenario
         ↓
    kleene-analyze validates (15 checks)
         ↓
    Issues found? → kleene-generate expands branches
         ↓
    Scenario registered in registry
         ↓
    kleene-play runs game with improvisation
         ↓
    Players experience game immediately
```

No gap: Generation → Validation → Play is a continuous pipeline.

---

## Branch Expansion: Iterative Improvement

### GENEVA: Re-generate

If a GENEVA graph is unsatisfactory, the designer must re-generate with different constraints. No targeted expansion.

### Kleene: Targeted Branch Expansion

Kleene's `kleene-generate` Mode 3 (Branch Expansion) can:

**For missing "Player Avoids" paths:**
```yaml
- id: refuse_quest
  text: "This is not my fight"
  consequence:
    - type: modify_trait
      trait: courage
      delta: -1
  next_node: ending_unchanged
```

**For missing death paths:**
```yaml
- id: reckless_action
  text: "Charge in without preparation"
  precondition:
    type: none_of
    conditions:
      - type: has_item
        item: armor
  consequence:
    - type: character_dies
      reason: "fell to overwhelming force"
  next_node: ending_death
```

**For Silver tier (middle cells):**

*Commitment (action with pending outcome):*
```yaml
- id: drink_potion
  text: "Drink the mysterious liquid"
  consequence:
    - type: set_flag
      flag: potion_consumed
    - type: schedule_event
      event_id: potion_effect
      delay: { amount: 30, unit: minutes }
      consequences:
        - type: modify_trait
          trait: strength
          delta: 3
  next_node: await_effects
```

Analysis-driven expansion ensures generated scenarios meet completeness requirements.

---

## Integration Possibility: GENEVA → Kleene Pipeline

A hybrid workflow could leverage both:

```
GENEVA generates branching narrative structure
         ↓
Designer reviews graph visualization
         ↓
Converter transforms GENEVA graph to Kleene YAML skeleton
         ↓
kleene-generate adds mechanical depth (preconditions, consequences)
         ↓
kleene-analyze validates (15 checks + schema)
         ↓
Issues? → kleene-generate expands branches for grid coverage
         ↓
kleene-play runs game with improvisation
```

This leverages:
- GENEVA's rapid visual prototyping
- Kleene's mechanical depth and validation
- Kleene's runtime improvisation

---

## Summary Comparison

| Capability | GENEVA | Kleene |
|------------|--------|--------|
| **Generate narrative structure** | ✓ | ✓ |
| **Visual graph output** | ✓ | ✗ |
| **Mechanical specification** | ✗ | ✓ (23+ preconditions, 22+ consequences) |
| **Validation pipeline** | ✗ | ✓ (15 analysis types + JSON Schema) |
| **Completeness metrics** | Structural only | Decision Grid coverage |
| **Iterative expansion** | Re-generate | Targeted branch expansion |
| **Runtime play** | ✗ | ✓ |
| **Player improvisation** | ✗ | ✓ (bounded soft consequences) |
| **Designer involvement** | View graph | Interactive menus throughout |

---

## Conclusion

GENEVA and Kleene address different parts of the narrative game development problem:

- **GENEVA** excels at **rapid visual prototyping** for designers to explore branching structures
- **Kleene** excels at **complete pipeline** from generation through validation to play

GENEVA helps designers see what a narrative could look like.
Kleene helps designers (and players) experience what a narrative actually does.

A combined approach would use GENEVA for initial brainstorming and Kleene for mechanical implementation, validation, and runtime.

---

## References

**GENEVA:**
- Leandro, J., Rao, S., Xu, M., Xu, W., Jojic, N., Brockett, C., & Dolan, B. (2024). GENEVA: GENErating and Visualizing branching narratives using LLMs. IEEE Conference on Games 2024.
- Paper: https://arxiv.org/abs/2311.09213
- Demo: https://narrative.msr-emergence.com/
- Blog: https://www.microsoft.com/en-us/research/blog/geneva-uses-large-language-models-for-interactive-game-narrative-design/

**Kleene Framework:**
- `lib/framework/core/core.md` - Decision Grid, Option types, completeness tiers
- `lib/schema/scenario-schema.json` - 1100-line JSON Schema (23+ preconditions, 22+ consequences)
- `skills/kleene-generate/SKILL.md` - Generation modes, grid targeting, branch expansion
- `skills/kleene-analyze/SKILL.md` - 15 analysis types, validation pipeline
- `skills/kleene-play/SKILL.md` - Play engine, improvisation, temperature system
- `lib/framework/gameplay/improvisation.md` - Soft consequences, intent classification
- `docs/design/theoretical_background.md` - Three-valued logic foundations
