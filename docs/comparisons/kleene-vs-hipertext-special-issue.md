# Comparative Analysis: Kleene vs. Hipertext.net Special Issue on AI in Narrative Media

A comparison of Kleene's architecture with the theoretical frameworks and empirical findings from "Artificial Intelligence in Narrative Media: Generative AI in Contemporary Storytelling" (Hipertext.net, Issue 31, 2025).

---

## Source Material

**Special Issue:** [Hipertext.net Issue 31 (2025)](https://www.raco.cat/index.php/Hipertext)

**Guest Editors:** Szilvia Ruszev (UCL), Temenuga Trifonova (UCL), Frederic Guerrero-Solé (UPF Barcelona)

**Key Papers Analyzed:**
1. Ruszev, Trifonova & Guerrero-Solé — "Authorship and creativity in the era of AI" (Editorial, pp. 1-10)
2. Letonsaari, Tri-Dung & Tri-Cuong — ["Dimensions of Narrative Agency in the Age of Automatic Content Creation"](https://raco.cat/index.php/Hipertext/article/view/9800206) (pp. 25-39)
3. Ferreira — ["Genre, Bias, and Narrative Logic in AI Dungeon"](https://www.raco.cat/index.php/Hipertext/article/view/433301) (pp. 77-89)
4. Araneda-Acuña — "Generative AI as a Meta-Mediator in Creative Processes: A Vygotskian Perspective" (pp. 67-76)
5. Valverde-Valencia — "Introducing the concept of relational processes in Human-AI creativity" (pp. 55-66)

---

## Overview

The Hipertext.net special issue examines how generative AI is transforming authorship, narrative agency, and creative labor in audiovisual media and gaming. The editorial frames this as "a paradigm shift from singular authorship to distributed co-creation, where the human acts as an orchestrator, curator, or strategist steering a probabilistic system through prompt engineering."

Kleene offers a specific implementation that addresses many of these theoretical concerns while providing concrete architectural solutions to problems identified empirically in the research.

---

## Key Comparisons

### 1. The Two-Dimensional Agency Framework

**Letonsaari et al.'s Framework:**

The paper proposes a two-dimensional model for analyzing narrative agency:
- **Axis 1: User Agency** — Degree of control afforded to users
- **Axis 2: Narrative Origin** — Spectrum from fully authored to fully algorithmic

This creates a design space where different narrative experiences can be positioned and compared.

**Kleene's Implementation:**

Kleene instantiates a specific position in this design space with explicit architectural boundaries:

| Dimension | Kleene's Position |
|-----------|-------------------|
| **User Agency** | High (player determines grid traversal) + Constrained (within authored structure) |
| **Narrative Origin** | Hybrid: Authored structure + Algorithmic texture |

The Decision Grid provides the structural framework:

```
|                    | World Permits | World Indeterminate | World Blocks |
|--------------------|---------------|---------------------|--------------|
| **Player Chooses** | Triumph       | Commitment          | Rebuff       |
| **Player Unknown** | Discovery     | Limbo               | Constraint   |
| **Player Avoids**  | Escape        | Deferral            | Fate         |
```

**Key insight:** Letonsaari et al. note that "procedural and AI-assisted storytelling challenge traditional assumptions about authorship and narrative structure." Kleene responds by making the structure explicit and formal—the Decision Grid doesn't emerge from AI generation; it's the scaffolding within which generation occurs.

**Assessment:** Kleene demonstrates that the authored↔algorithmic spectrum isn't binary. Authored structure can coexist with algorithmic content generation, each handling different layers of the narrative experience.

---

### 2. Genre as Scaffold and Filter

**Ferreira's Findings on AI Dungeon:**

The study of AI Dungeon reveals that "genre conventions in digital games serve as both scaffolds and filters for AI-generated storytelling":

- **Scaffolds:** Genre prompts guide AI toward coherent narratives
- **Filters:** Genre expectations can amplify algorithmic biases
- **Narrative Drift:** AI-generated stories lose coherence, "deviating from recognized genre standards"
- **Player Intervention:** Required to maintain narrative coherence and correct biased outputs

**Kleene's Architecture:**

Kleene addresses these problems through architectural constraints rather than relying on genre prompts alone:

**1. Structural Scaffolding (Beyond Genre)**

Instead of genre conventions, Kleene uses formal completeness requirements:

From `lib/framework/core/core.md`:
```
Completeness Tiers:
- Bronze (4/9 cells): Triumph, Rebuff, Escape, Fate
- Silver (6+/9 cells): Bronze + middle cells (Commitment, Discovery, etc.)
- Gold (9/9 cells): Full Decision Grid coverage
```

This provides structural coherence independent of genre—a horror scenario and a comedy scenario both need paths to Triumph, Rebuff, Escape, and Fate.

**2. Preventing Narrative Drift**

Kleene's improvisation rules explicitly prevent drift:

From `lib/framework/gameplay/improvisation.md`:
```
| Allowed               | Not Allowed           |
|-----------------------|-----------------------|
| modify_trait (±1)     | gain_item (scenario)  |
| add_history           | lose_item             |
| set_flag (improv_*)   | move_to               |
| advance_time          | character_dies        |
|                       | character_departs     |
```

Improvisation can enrich but cannot derail. Major state changes require scripted paths.

**3. Bias Mitigation Through Structure**

Where AI Dungeon shows bias amplification through unconstrained generation, Kleene's authored scenario structure determines:
- Which NPCs exist
- What items are available
- What endings are possible
- What preconditions gate access

The AI generates flavor text within these constraints, not the underlying narrative logic.

**Assessment:** Ferreira identifies narrative drift and bias amplification as key problems in AI-driven interactive fiction. Kleene's architecture directly addresses both through explicit constraints on what AI generation can modify.

---

### 3. Player Intervention and Coherence

**Ferreira's Observation:**

> "Human intervention remains essential for managing narrative drift and correcting biased outputs, highlighting the collaborative nature of human-AI storytelling."

In AI Dungeon, players must actively intervene to maintain coherence—a burden that can break immersion and require constant vigilance.

**Kleene's Approach:**

Kleene shifts the intervention burden from runtime to design time:

**Design-Time Intervention (Scenario Author):**
- Authors create the node graph, preconditions, consequences
- Validation via `kleene-analyze` catches structural problems
- Completeness tiers ensure narrative coverage

**Runtime Generation (Constrained):**
- AI handles improvisation responses within soft consequence limits
- Temperature setting (0-10) controls adaptation intensity
- Player free-text maps to the "Unknown" row, not arbitrary generation

From the improvisation rules:
> "After generating the response: Apply any soft consequences, Display the response, Present the current node's original options AGAIN, Do NOT advance current_node"

The game stays at the same decision point after improvisation—enriched but not derailed.

**Assessment:** Kleene doesn't eliminate human intervention; it moves it from an exhausting runtime activity to a design-time authoring process. Players can explore freely knowing the structure will hold.

---

### 4. AI as Meta-Mediator (Vygotskian Perspective)

**Araneda-Acuña's Framework:**

Drawing on Vygotskian psychology, this paper positions generative AI as a "meta-mediator"—a tool that mediates creative processes while operating at a level above traditional tools. The concern is preserving human agency within AI-mediated creativity.

**Kleene's Mediation Architecture:**

Kleene implements multiple levels of mediation with explicit boundaries:

| Level | Mediator | Function |
|-------|----------|----------|
| **Framework** | Decision Grid, Option types | Defines possibility space |
| **Scenario** | YAML structure | Instantiates specific narrative |
| **Runtime** | LLM | Generates texture within constraints |
| **Player** | Choices + free-text | Traverses and enriches |

The Vygotskian concern about agency is addressed through the constraint architecture—the AI operates as a "Zone of Proximal Development" tool, scaffolding player creativity without replacing it.

From `lib/framework/gameplay/improvisation.md`:
> "**Philosophy:** Improvisation enriches the current moment without derailing scenario balance."

**Temperature as Agency Dial:**

The temperature setting (0-10) gives explicit control over AI influence:
- Temperature 0: Verbatim scenario text, no AI adaptation
- Temperature 5: Balanced integration of player exploration
- Temperature 10: Fully adaptive narrative perspective

This operationalizes the Vygotskian balance—players can dial up or down how much the AI mediates their experience.

**Assessment:** Where Araneda-Acuña theorizes about preserving human agency in AI-mediated creativity, Kleene provides concrete mechanisms (temperature, constraint boundaries, soft consequences) that implement this preservation architecturally.

---

### 5. Relational Processes in Human-AI Creativity

**Valverde-Valencia's Concept:**

This paper moves beyond interaction toward interdependence, proposing "relational processes" as a model for human-AI creativity. The relationship isn't tool-use but mutual constitution.

**Kleene's Relational Architecture:**

Kleene implements several relational mechanisms:

**1. Improv Flags as Relational Memory**

From `lib/framework/gameplay/improvisation.md`:
```
improv_examined_dragon_scales
improv_spoke_to_shadow
improv_attempted_wall_climb
```

These flags track the player's exploratory actions, and at higher temperatures, the AI weaves them into subsequent narrative—the system "remembers" what the player found interesting.

**2. Bonus Options at Temperature 7+**

When temperature is high, the system generates bonus options based on improv flags:
```yaml
label: "Trace the inscriptions"
description: "Follow the symbols you noticed on its scales"
source_flag: improv_examined_dragon_scales
```

The AI offers options that emerge from the player's prior exploration—a genuinely relational dynamic where player curiosity shapes available choices.

**3. Gallery Mode as Meta-Relational**

Gallery Mode provides analytical commentary alongside narrative:
> "Like Frodo at Mount Doom—when the choice finally comes, will matters more than strength."

This creates a relationship not just between player and narrative, but between player and the system's literary intelligence—the AI becomes a companion interpreter, not just a story generator.

**Assessment:** Valverde-Valencia's relational model finds concrete expression in Kleene's temperature system, improv flags, and gallery mode—mechanisms that create genuine interdependence rather than simple input-output relations.

---

### 6. Distributed Authorship

**Editorial's Central Claim:**

> "Authorship has shifted from a singular human creator to a distributed co-creation model, where the human acts as an orchestrator, curator, or strategist steering a probabilistic system through prompt engineering, while AI functions as a 'meta-mediator' with apparent agency."

**Kleene's Distribution Model:**

Kleene makes the distribution explicit with defined roles:

| Role | Contribution | Agency Level |
|------|--------------|--------------|
| **Framework Author** | Decision Grid, Option types, validation criteria | Structural |
| **Scenario Author** | Node graph, preconditions, consequences, narrative text | Content |
| **Runtime LLM** | Improvisation responses, temperature adaptation | Textural |
| **Player** | Choice selection, free-text input, exploration patterns | Traversal |

Unlike prompt engineering where the human "steers a probabilistic system," Kleene separates:
- **Authored structure** (deterministic, validated)
- **Generated texture** (probabilistic, constrained)

The probabilistic element operates within explicit boundaries, not as the primary creative mechanism.

**Assessment:** The special issue identifies distributed authorship as the emerging paradigm. Kleene implements this with clear role definitions and explicit boundaries between what's authored, what's generated, and what's player-determined.

---

## Tensions and Open Questions

### Where Kleene Aligns with Special Issue Concerns

**1. Narrative Coherence**

Ferreira's findings about narrative drift in AI Dungeon validate Kleene's constraint architecture. The soft consequence limits and node-retention after improvisation directly address observed problems in unconstrained AI narrative systems.

**2. Player Agency**

Letonsaari et al.'s framework positions user agency as a key dimension. Kleene's architecture gives players high agency in traversal (which paths to take, what to explore) while maintaining structural coherence—the authored scaffolding doesn't limit meaningful choice, it enables it.

**3. Bias Prevention**

The AI Dungeon study shows genre conventions amplifying bias. Kleene's approach—authored NPCs, items, and endings—means bias can only enter at the scenario authoring level (addressable through review) or in texture generation (limited by soft consequence constraints).

### Where Tensions Remain

**1. Full Generation Mode**

Kleene's `kleene-generate` skill creates complete scenarios from themes. While constrained by completeness requirements, the generated narrative content faces the same challenges Ferreira identifies in AI Dungeon—potential for bias, drift, and coherence loss within the generated portions.

**2. Temperature 10 Adaptation**

At maximum temperature, narrative adaptation becomes substantial:
> "Everything you've learned comes together in this moment—the inscriptions on the scales, the elder's words about the dragon's grief..."

This approaches the unconstrained generation that Ferreira shows produces drift. Kleene's constraint is that adaptation prepends to rather than replaces authored text, but the prepended content could still exhibit problems.

**3. Aesthetic Quality**

The special issue focuses on structural issues (agency, coherence, bias), but aesthetic quality—whether AI-generated prose is actually good—remains largely unaddressed. Kleene's Narrative Purity rules forbid certain patterns but don't guarantee compelling writing.

---

## Summary: Theoretical Frameworks vs. Implemented Architecture

| Concept (Special Issue) | Kleene Implementation |
|------------------------|----------------------|
| Two-dimensional agency space | Explicit position: high agency + hybrid origin |
| Genre as scaffold/filter | Formal completeness tiers replace genre prompts |
| Narrative drift | Soft consequence limits, node retention |
| Bias amplification | Authored structure contains bias surface area |
| Player intervention for coherence | Design-time authoring vs. runtime intervention |
| AI as meta-mediator | Layered mediation with explicit boundaries |
| Relational processes | Improv flags, temperature dial, gallery mode |
| Distributed authorship | Four explicit roles with defined responsibilities |

---

## Conclusion

The Hipertext.net special issue provides theoretical frameworks and empirical findings that illuminate the challenges of AI-driven narrative media. Kleene's architecture can be understood as an implementation response to these challenges:

- Where **Letonsaari et al.** map the design space, Kleene occupies a specific position with explicit rationale
- Where **Ferreira** identifies drift and bias in AI Dungeon, Kleene's constraints directly prevent them
- Where **Araneda-Acuña** theorizes agency preservation, Kleene implements temperature as an agency dial
- Where **Valverde-Valencia** proposes relational processes, Kleene's improv flags and bonus options instantiate them
- Where the **editorial** describes distributed authorship, Kleene defines explicit roles and boundaries

The special issue asks: how do we navigate AI's transformation of narrative media? Kleene proposes: through formal semantic frameworks that make structure explicit, constrain generation to texture, and give players and authors clear roles within a defined possibility space.

This doesn't solve all problems—aesthetic quality, full generation mode, and high-temperature adaptation remain open challenges—but it demonstrates that theoretical concerns about AI narrative can be addressed through architectural design, not just post-hoc framing.

---

## References

- Ruszev, S., Trifonova, T., & Guerrero-Solé, F. (2025). Authorship and creativity in the era of AI. *Hipertext.net*, 31, 1-10.
- Letonsaari, M., Tri-Dung, D., & Tri-Cuong, D. (2025). Dimensions of Narrative Agency in the Age of Automatic Content Creation. *Hipertext.net*, 31, 25-39.
- Ferreira, C. (2025). Genre, Bias, and Narrative Logic in AI Dungeon. *Hipertext.net*, 31, 77-89.
- Araneda-Acuña, C. (2025). Generative AI as a Meta-Mediator in Creative Processes: A Vygotskian Perspective. *Hipertext.net*, 31, 67-76.
- Valverde-Valencia, À. (2025). Introducing the concept of relational processes in Human-AI creativity. *Hipertext.net*, 31, 55-66.

## See Also

- [kleene-vs-ai-literature-concerns.md](./kleene-vs-ai-literature-concerns.md) — Comparison with "The Language of the Digital Air"
- [the_language_of_digital_air.md](./the_language_of_digital_air.md) — Full paper on paratextual framing
