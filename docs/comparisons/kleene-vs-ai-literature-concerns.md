# Comparative Analysis: Kleene vs. AI-Generated Literature Concerns

A comparison of Kleene's authoring/generation capabilities with the issues raised in "The Language of the Digital Air: AI-Generated Literature and the Performance of Authorship" (University of Macerata, 2025).

---

## Overview

The paper examines AI-generated literature through the lens of **paratextual framing**—the apparatus of prefaces, afterwords, and editorial notes that human authors use to inject meaning into algorithmically-produced text. The central argument is that while AI writing represents something novel, "the novelty tends to be cloaked in a familiar garb"—the persistent figure of the author resurfaces as "clever prompter" or "curator."

Kleene takes a radically different approach to the human-AI creative relationship that sidesteps many of these concerns while introducing its own distinctive model.

---

## Key Comparisons

### 1. The Problem of Meaning Without Intentionality

**Paper's Concern:**

> "The standard expectation of unknown texts rests on the minimal assumption that the text was written by a human who wants to say something." (Bajohr, quoted in paper)

AI-generated texts lack intentionality. The paratextual apparatus (prefaces, afterwords) exists to inject meaning that the text "may not intrinsically possess."

**Kleene's Approach:**

Kleene doesn't generate free-form prose that pretends to intentionality. Instead, it uses a **formal semantic framework** (the Decision Grid, Option types, Completeness Tiers) that makes the *structure* of narrative meaningful independent of any claim to consciousness.

From `lib/framework/core/core.md`:
```
Option[Character]
├── Some(character) → character exists, story continues
└── None(reason)    → character absent, story may end
```

The 9-cell Decision Grid provides **structural meaning**—Triumph, Rebuff, Discovery, Fate—that emerges from the intersection of player intent and world response, not from any claim that the AI "wants to say something."

**Assessment:** Kleene avoids the paper's central concern by grounding meaning in formal structures rather than simulated intentionality.

---

### 2. Quaternary Authorship and "Promptology"

**Paper's Framework:**

Bajohr's model identifies four levels of authorship distance:
- Primary: Human writes text directly
- Secondary: Human creates rules, rules generate text
- Tertiary: Human configures ML training
- Quaternary: Prompt is the main input (ChatGPT-era)

The paper notes that with proprietary LLMs, "the prompt is the main human input: 'Promptology'—the efficient, even virtuosic formulation of such input prompts—is the main mode of operation of quaternary authorship."

**Kleene's Position:**

Kleene operates at a hybrid of **secondary and quaternary authorship**:

1. **Secondary (rule-based):** The scenario YAML files are explicit rule systems—preconditions, consequences, node transitions. This is combinatorial authorship.

From `skills/kleene-generate/SKILL.md`:
```yaml
precondition: { type: has_item, item: sword }
consequence:
  - type: gain_item
    item: key
next_node: next_node_id
```

2. **Quaternary (prompt-based):** The `kleene-generate` skill uses LLM generation guided by structured prompts and constraints.

From the generate skill:
> "Generate new scenarios or expand existing ones using LLM capabilities while maintaining Option type semantics and narrative completeness according to the Kleene Decision Grid."

**Critical difference:** The prompt isn't open-ended ("write me a story"). It's constrained by:
- Formal completeness requirements (Bronze/Silver/Gold tiers)
- Required narrative structures (4 corners minimum)
- Specific YAML schema compliance
- Validation via `kleene-analyze`

**Assessment:** Kleene hybridizes secondary and quaternary authorship, using prompts to generate content that must conform to explicit rules—not to simulate human writing but to populate a formal game structure.

---

### 3. The "Carving" Metaphor and Human Curation

**Paper's Observation:**

The paper highlights Johnston's ReRites project where the human author spent "6-8 am for one year" carving AI output:

> "Does the farmer write the fruit found on a branch?" The human "carving" transforms "inchoate marble into strange verbal sculptures."

This positions the human as curator/editor who extracts value from abundance.

**Kleene's Approach:**

Kleene inverts this relationship. Rather than the LLM producing abundant raw material that humans carve, the human (or LLM) creates **scenario structure** that the runtime system then instantiates.

From `lib/framework/gameplay/improvisation.md`:
> "**Philosophy:** Improvisation enriches the current moment without derailing scenario balance. Major state changes (items, locations, death) are reserved for scripted paths."

The constraint is architectural:
- **Scripted paths** (human-authored YAML): Major narrative beats, item acquisition, death/transcendence
- **Improvisation** (runtime LLM): Flavor text, soft consequences only (±1 traits, history entries)

From the improvisation rules:
```
| Allowed | Not Allowed |
|---------|-------------|
| modify_trait (delta: -1 to +1) | gain_item (scenario items) |
| add_history | lose_item |
| set_flag (only improv_* prefix) | move_to |
| advance_time | character_dies |
```

**Assessment:** Rather than carving abundance into meaning, Kleene constrains generation to fill slots within a pre-designed structure. The human authors the architecture; the LLM fills in texture.

---

### 4. The Persistence of the Author-Function

**Paper's Conclusion:**

Despite poststructuralist predictions of the author's death:
> "Authors seem to continue to attach their names to works produced in collaboration with AI systems... Reclaiming authorship can be brought into play precisely as a defense against both the phantasm of the technically optimized AI genius and the absolute atomization of authorship."

The paratextual apparatus in AI literature resurrects the author as guarantor of meaning.

**Kleene's Model:**

Kleene explicitly distributes authorship across multiple functions:

| Role | Responsibility |
|------|----------------|
| **Framework Author** | Decision Grid, Option types, completeness semantics |
| **Scenario Author** | YAML structure, node graph, preconditions/consequences |
| **Runtime LLM** | Improvisation responses, temperature-based adaptation |
| **Player** | Intent (Chooses/Unknown/Avoids), free-text input |

From `lib/framework/core/core.md`:
> "Every narrative moment presents a choice. The player acts (or hesitates, or refuses), and the world responds (permits, blocks, or leaves the outcome hanging)."

The **player** becomes a co-author through their choices—not in the postmodern "reader completes the text" sense, but mechanically, as their input directly determines which cells of the Decision Grid are traversed.

**Assessment:** Kleene doesn't resurrect a singular author through paratextual framing. It defines explicit roles for multiple contributors, with the framework itself serving as the "author-function" that guarantees structural meaning.

---

### 5. The Fantasy of Artificial Subjectivity

**Paper's Critique:**

Several AI literature experiments (I Am Code, The Inner Life of an AI) capitalize on the "fantasy of artificial subjectivity"—prompting the AI to speak in first person about its "inner life":

> "The memoir is coherent in the sense that it is aligned with the tech industry's fantasy of machine sentience and artificial general intelligence."

**Kleene's Position:**

Kleene explicitly rejects this fantasy. The framework uses **second person present tense** ("You stand at the crossroads") consistently, positioning the player as protagonist.

From `lib/framework/gameplay/improvisation.md`:
> "Match the scenario's established voice: **Perspective**: Use second person present ('You examine...')"

More importantly, the **Narrative Purity** rules explicitly forbid the kind of meta-commentary that would suggest AI self-awareness:

> "**Characters speak as characters, not as literary critics.**
> When generating improvised dialogue, NEVER include:
> - Story structure terms ("redemption arc", "character arc", "narrative")
> - Psychological jargon ("projection", "defense mechanism", "trauma response")
> - Meta-awareness of being in a story"

The Gallery Mode system provides analytical commentary *separately* from narrative:
> "Gallery commentary is **qualitative and literary**, not technical... Commentary should illuminate the experience without dissecting it clinically."

**Assessment:** Kleene architecturally prevents the "AI speaking about its inner life" pattern that the paper critiques. The LLM generates in-world fiction, not pseudo-autobiography.

---

### 6. Validation vs. Paratextual Persuasion

**Paper's Observation:**

AI literature experiments rely on paratextual validation—bringing in experts (poets, scientists) to assess the work, with their judgments serving to authorize meaning:

> "This validation consists of taking the texts seriously, reading them as she would read submissions by her students... The point is not that she likes what she reads, but that her disposition towards these artificial texts is indistinguishable from her disposition towards human-authored poems."

**Kleene's Approach:**

Kleene replaces subjective validation with **formal analysis**. The `kleene-analyze` skill performs:

- **Schema Validation**: Required fields, types, references
- **Structural Validation**: Graph integrity, reachability
- **Semantic Validation**: Item obtainability, flag dependencies
- **Narrative Validation**: Decision Grid coverage, completeness tiers

From `skills/kleene-analyze/SKILL.md`:
```
| Check | Severity | Condition |
|-------|----------|-----------|
| Death path exists | Warning | At least one path leads to NONE_DEATH |
| Victory path exists | Warning | At least one path leads to SOME_TRANSFORMED |
| Required items obtainable | Error | Every has_item precondition item can be gained somewhere |
```

A scenario isn't validated by expert judgment but by **structural completeness**—whether it covers the Decision Grid cells, whether items are obtainable, whether endings are reachable.

**Assessment:** Kleene substitutes formal validation for rhetorical persuasion. Quality is measurable against explicit criteria, not dependent on paratextual framing.

---

## Tensions and Limitations

### Where Kleene Faces Similar Challenges

**1. Temperature-Based Narrative Adaptation**

The improvisation system's "temperature" setting (0-10) controls how much player exploration influences narrative presentation. At high temperatures:

> "The narrative perspective shifts to reflect the character's complete journey... Everything you've learned comes together in this moment."

This adaptive narrative approaches the kind of "emergent meaningfulness" that the paper suggests requires human curation. Who validates that temperature-10 adaptations are coherent?

**2. Full Scenario Generation**

The `kleene-generate` skill creates complete scenarios from themes. While constrained by completeness requirements, the narrative content itself is LLM-generated:

> "**Narrative Voice**: Use second person present tense... Be evocative but concise (3-6 sentences per narrative block)"

The prose quality of generated scenarios faces the same challenges as any LLM fiction—coherence, originality, depth. The framework provides structural scaffolding but not literary quality control.

**3. The "Alienness" of AI Writing**

The paper notes that even enthusiastic AI collaborators acknowledge:
> "AI is alien, and its art feels alien." (Marche)

Kleene's Narrative Purity rules attempt to mask this by forbidding meta-commentary, but the underlying generation may still exhibit the "uncanny" quality of LLM prose—competent but somehow hollow.

---

## Summary: Two Models of Human-AI Creative Collaboration

| Dimension | AI Literature (Paper) | Kleene |
|-----------|----------------------|--------|
| **Meaning source** | Paratextual framing | Formal semantic structure |
| **Authorship model** | Quaternary (prompt-focused) | Hybrid secondary/quaternary (rules + prompts) |
| **Human role** | Carver/curator of abundance | Architect of constraints |
| **Validation** | Expert judgment, rhetorical | Structural analysis, formal |
| **AI persona** | Simulated subjectivity | Transparent tool |
| **Output format** | Prose for reading | Interactive fiction for playing |
| **Quality metric** | Aesthetic judgment | Completeness tier coverage |

---

## Conclusion

The paper argues that AI-generated literature resurrects the author-function through paratextual apparatus—prefaces, afterwords, expert validations that inject meaning into otherwise "authorless" text.

Kleene offers an alternative model: rather than generating prose that requires post-hoc meaning injection, it defines a **formal semantic framework** (Decision Grid, Option types, Completeness Tiers) where meaning emerges from structure. The human authors architecture; the LLM fills texture; the player co-creates through choices; and validation is formal rather than rhetorical.

This doesn't eliminate all concerns about AI creativity—generated prose may still feel alien, and temperature-based adaptation introduces its own validation challenges—but it demonstrates that the binary of "paratextual framing vs. meaningless output" isn't the only path. A third option exists: **formal semantics as meaning infrastructure**.

---

## References

- "The Language of the Digital Air: AI-Generated Literature and the Performance of Authorship" (2025). Humanities Department, University of Macerata. https://doi.org/10.3390/h14080164
- Kleene Framework Documentation: `lib/framework/core/core.md`, `lib/framework/gameplay/improvisation.md`
- Kleene Skills: `skills/kleene-generate/SKILL.md`, `skills/kleene-analyze/SKILL.md`

## See Also

- [the_language_of_digital_air.md](./the_language_of_digital_air.md) — Full paper text
- [theoretical_background.md](../design/theoretical_background.md) — Kleene's formal foundations
