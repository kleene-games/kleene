# Analysis: Kleene Framework vs. AI Narrative Quality Evaluation Research

## Overview

This document compares the **Kleene narrative engine's** validation approach against the evaluation methodology proposed in **"Evaluating Quality of Gaming Narratives Co-created with AI"** (Valdivia & Burelli, IT University of Copenhagen, IEEE Conference on Games 2025).

The paper proposes a structured framework for evaluating AI-generated game narratives using Story Quality Dimensions (SQDs), expert Delphi studies, and Kano model classification. Kleene's `kleene-analyze` skill provides automated structural validation—a complementary but different approach.

**Paper:** [arXiv:2509.04239](https://arxiv.org/abs/2509.04239) | [IEEE Xplore](https://ieeexplore.ieee.org/document/11114354/)

---

## The Two Approaches at a Glance

| Aspect | **Valdivia & Burelli** | **Kleene** |
|--------|------------------------|------------|
| **Purpose** | Evaluate narrative quality post-generation | Validate narrative structure pre-play |
| **Method** | Expert panel + player surveys | Automated analysis + schema validation |
| **Dimensions** | 23 Story Quality Dimensions | 15 analysis types + Decision Grid |
| **Classification** | Kano model (Must-have/Attractive/etc.) | Completeness tiers (Bronze/Silver/Gold) |
| **Scope** | Any AI-generated narrative | Kleene scenario format specifically |
| **Automation** | Manual expert evaluation | Fully automated |
| **Output** | Priority rankings for developers | Pass/fail + specific issues |

---

## The Paper's Framework

### Story Quality Dimensions (SQDs)

The paper identifies **23 dimensions** from literature review that affect narrative quality. While the specific list is in a figure, the paper reports:

- **78%** rated "Very important" or higher by experts
- **26%** rated above 4.5 (highest importance)
- No dimension scored below 3.0 median

**Kano Classification Results:**

| Category | Percentage | Meaning |
|----------|------------|---------|
| One-dimensional | 57% | Satisfaction proportional to performance |
| Must-have | 26% | Basic expectations; absence causes dissatisfaction |
| Attractive | 13% | Delighters; presence increases satisfaction |
| Indifferent | 4% | Little impact on satisfaction |

**Two Emergent Dimensions:**
1. **Voice** - Distinctive narrative tone beyond plot/character
2. **Genre Alignment** - Meeting or meaningfully challenging genre conventions

### Evaluation Methodology

The paper proposes a three-stage process:

1. **Compile dimensions** from literature
2. **Validate via Delphi study** with 10 expert narrative designers
3. **Classify using Kano model** to prioritize development focus

This is a **human-in-the-loop evaluation framework** requiring expert judgment.

---

## Kleene's Validation Approach

### Automated Structural Analysis

Kleene's `kleene-analyze` skill performs **15 automated analysis types**:

| # | Analysis | What It Validates |
|---|----------|-------------------|
| 1 | Grid Coverage | All 9 narrative possibility cells represented |
| 2 | Null Cases | Death, departure, blocked paths exist |
| 3 | Structural | No unreachable nodes, dead ends, railroads |
| 4 | Path Enumeration | All paths from start to endings |
| 5 | Cycle Detection | No infinite loops |
| 6 | Item Obtainability | Required items can be acquired |
| 7 | Trait Balance | Trait requirements are achievable |
| 8 | Flag Dependencies | Flags checked are also set somewhere |
| 9 | Relationship Network | NPC relationships are coherent |
| 10 | Consequence Magnitude | Trait changes appropriately sized |
| 11 | Scene Pacing | Scene breaks used appropriately |
| 12 | Path Diversity | No false choices (different options → same result) |
| 13 | Ending Reachability | All endings can be reached |
| 14 | Travel Consistency | Time configuration is valid |
| 15 | Schema Validation | YAML matches JSON Schema |

### Completeness Tiers

Instead of Kano categories, Kleene uses **Decision Grid coverage**:

| Tier | Coverage | Requirements |
|------|----------|--------------|
| Bronze | 4/9 cells | Triumph, Rebuff, Escape, Fate + death + victory paths |
| Silver | 6+/9 cells | Bronze + middle cells (Commitment, Discovery, etc.) |
| Gold | 9/9 cells | All cells represented |

### JSON Schema Validation

The 1100-line schema validates:
- 23+ precondition types
- 22+ consequence types
- Reference integrity
- Type correctness

---

## Mapping Quality Dimensions to Kleene Analysis

While the paper's specific 23 dimensions aren't fully available, we can map the **emergent dimensions** and **Kano categories** to Kleene's capabilities:

### Voice (Emergent Dimension)

**Paper's definition:** Distinctive narrative tone beyond plot/character elements

**Kleene's approach:**
- **Temperature system (0-10)** controls narrative adaptation
- **Tone matching** in improvisation ("Match the scenario's established voice")
- **Gallery mode** for meta-commentary separate from narrative voice
- **Narrative purity rules**: "Characters speak as characters, not as literary critics"

Kleene doesn't **evaluate** voice but provides **authorial controls** to maintain it.

### Genre Alignment (Emergent Dimension)

**Paper's definition:** Meeting or meaningfully challenging genre conventions

**Kleene's approach:**
- **Tone selection** during generation (Heroic/Tragic/Comedic/Mysterious)
- **Ending flavor system** with method and tone dimensions
- **Consequence magnitude scaling** appropriate to genre (catastrophic betrayal = -50 relationship)

Kleene enables genre alignment through authored structure but doesn't validate it automatically.

### Must-Have Dimensions (26%)

These are basic expectations where absence causes dissatisfaction. Likely includes:

| Likely Must-Have | Kleene Equivalent |
|------------------|-------------------|
| Narrative coherence | Structural analysis (no unreachable nodes) |
| Character consistency | State tracked in YAML, not LLM memory |
| Plot progression | Path enumeration, ending reachability |
| Player agency | Decision Grid coverage, path diversity |

Kleene's structural analysis catches many "must-have" failures automatically.

### One-Dimensional Dimensions (57%)

Satisfaction proportional to performance. Likely includes:

| Likely One-Dimensional | Kleene Equivalent |
|------------------------|-------------------|
| Narrative depth | Grid coverage tier (Bronze→Silver→Gold) |
| Choice meaningfulness | Path diversity analysis (false choice detection) |
| Consequence clarity | Consequence magnitude analysis |
| Pacing | Scene pacing analysis |

Kleene's tiered completeness maps to "more is better" one-dimensional qualities.

### Attractive Dimensions (13%)

Delighters that increase satisfaction when present. Likely includes:

| Likely Attractive | Kleene Equivalent |
|-------------------|-------------------|
| Surprising twists | Not validated (authorial responsibility) |
| Emotional resonance | Ending flavor system (tone: triumphant/bittersweet/tragic) |
| Memorable moments | Temperature-based narrative adaptation |

These are harder to validate automatically—Kleene provides tools but not evaluation.

---

## Complementary Approaches

The paper and Kleene address **different validation needs**:

### Paper: Post-Generation Quality Assessment

```
AI generates narrative
        ↓
Expert panel evaluates against 23 SQDs
        ↓
Kano classification identifies priorities
        ↓
Developer iterates based on findings
```

**Strengths:**
- Captures subjective quality (voice, emotional impact)
- Industry expert consensus
- Applicable to any AI narrative system

**Limitations:**
- Requires human experts (slow, expensive)
- Post-hoc evaluation (after generation)
- No automated enforcement

### Kleene: Pre-Play Structural Validation

```
Scenario generated/authored
        ↓
kleene-analyze performs 15 automated checks
        ↓
Issues flagged with specific locations
        ↓
Author fixes issues before play
```

**Strengths:**
- Fully automated (immediate feedback)
- Catches structural issues before players encounter them
- Specific, actionable error messages

**Limitations:**
- Can't evaluate subjective qualities (voice, emotional impact)
- Specific to Kleene format
- Structural completeness ≠ narrative quality

---

## Integration Possibility: SQD-Informed Analysis

Kleene could extend its analysis with SQD-based checks:

### Currently Automated in Kleene

| SQD Category | Kleene Analysis |
|--------------|-----------------|
| Structural coherence | ✓ 7 analysis types (paths, nodes, cycles, etc.) |
| Player agency | ✓ Grid coverage, path diversity |
| Mechanical consistency | ✓ Item/trait/flag obtainability |
| Pacing | ✓ Scene break analysis |

### Could Be Added to Kleene

| SQD Category | Potential Analysis |
|--------------|-------------------|
| **Voice consistency** | Check narrative text for vocabulary/tone drift |
| **Genre alignment** | Validate ending types match declared tone |
| **Emotional arc** | Analyze trait/relationship trajectories across paths |
| **Surprise/twist density** | Count unexpected precondition reveals |

### Requires Human Evaluation

| SQD Category | Why Automation Fails |
|--------------|---------------------|
| Emotional resonance | Subjective experience |
| Memorability | Requires player feedback |
| Thematic depth | Requires interpretation |
| Cultural appropriateness | Context-dependent |

---

## Kano Model vs. Completeness Tiers

Both frameworks classify quality dimensions, but differently:

### Kano Model (Paper)

Classifies by **player satisfaction impact**:

| Category | Player Reaction |
|----------|-----------------|
| Must-have | Absence → Dissatisfaction |
| One-dimensional | More → More satisfaction |
| Attractive | Presence → Delight |
| Indifferent | No impact |

### Completeness Tiers (Kleene)

Classifies by **narrative possibility coverage**:

| Tier | What's Covered |
|------|----------------|
| Bronze | Binary outcomes (success/failure × action/avoidance) |
| Silver | + Uncertainty and exploration |
| Gold | Full possibility space including Limbo |

### Mapping Between Frameworks

| Kano Category | Closest Tier Concept |
|---------------|---------------------|
| Must-have | Bronze requirements (corners + death + victory) |
| One-dimensional | Silver→Gold progression |
| Attractive | Gold-exclusive cells (Limbo, Commitment) |
| Indifferent | Not mapped (Kleene assumes all cells matter) |

Kleene's tiers assume all grid cells have value; the Kano model allows for "indifferent" dimensions that don't affect satisfaction.

---

## Evaluation Methodology Comparison

### Paper: Delphi Study

- **Panel:** 10 narrative design experts
- **Process:** Multiple rounds of anonymous questionnaires
- **Consensus:** Statistical agreement on importance
- **Output:** Ranked, classified dimension list

**Suitable for:** Establishing industry-wide quality standards

### Kleene: Automated Analysis

- **Tool:** yq + JSON Schema + custom checks
- **Process:** Single automated pass
- **Consensus:** Not applicable (deterministic)
- **Output:** Pass/fail per check with specific issues

**Suitable for:** Rapid iteration during development

### Complementary Use

```
1. Generate scenario with kleene-generate
2. Validate structure with kleene-analyze (automated)
3. Playtest with expert panel (SQD evaluation)
4. Iterate based on combined findings
5. Final validation before release
```

Automated validation catches structural issues quickly; expert evaluation catches subjective quality issues that automation misses.

---

## What Kleene Could Learn

### From the Kano Classification

Kleene could weight analysis findings by impact:

```
CRITICAL (Must-have violations):
  ✗ No death path exists
  ✗ Unreachable ending: victory_wisdom

WARNING (One-dimensional below threshold):
  ⚠ Grid coverage: Bronze (4/9) - consider expanding to Silver

INFO (Attractive opportunities):
  ○ No Limbo cell - could add uncertainty moments
  ○ All endings same tone - variety could delight
```

### From the Emergent Dimensions

**Voice validation:**
```yaml
analysis:
  voice_consistency:
    check: narrative_vocabulary_drift
    threshold: 0.3  # max deviation from baseline
    baseline_node: intro
```

**Genre alignment validation:**
```yaml
analysis:
  genre_alignment:
    declared_tone: tragic
    check: ending_tone_distribution
    expected: { tragic: ">50%", triumphant: "<20%" }
```

---

## Conclusion

The paper and Kleene represent **complementary validation approaches**:

| Aspect | Paper | Kleene |
|--------|-------|--------|
| **Focus** | Subjective quality | Structural completeness |
| **Method** | Expert consensus | Automated analysis |
| **Speed** | Slow (human panels) | Fast (immediate) |
| **Coverage** | 23 quality dimensions | 15 structural checks |
| **Iteration** | Post-generation | Pre-play |

**The paper provides:**
- Industry-validated quality dimensions
- Prioritization framework (Kano model)
- Subjective quality criteria

**Kleene provides:**
- Automated structural validation
- Immediate feedback loop
- Specific, actionable issues

An ideal workflow combines both: Kleene's automated analysis for rapid structural iteration, followed by SQD-based expert evaluation for subjective quality assurance before release.

---

## References

**Paper:**
- Valdivia, A. & Burelli, P. (2025). Evaluating Quality of Gaming Narratives Co-created with AI. IEEE Conference on Games 2025.
- arXiv: https://arxiv.org/abs/2509.04239
- IEEE Xplore: https://ieeexplore.ieee.org/document/11114354/

**Kleene Framework:**
- `skills/kleene-analyze/SKILL.md` - 15 analysis types
- `lib/schema/scenario-schema.json` - JSON Schema validation
- `lib/framework/core/core.md` - Decision Grid, completeness tiers
- `lib/framework/core/endings.md` - Ending flavor system (type, method, tone)
- `lib/framework/gameplay/improvisation.md` - Temperature system, tone matching
