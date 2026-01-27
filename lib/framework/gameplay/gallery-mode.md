# Gallery Mode: Meta-Commentary System

Art galleries use explanatory cards to reveal what's happening beneath the surface
of a painting—its techniques, historical context, and symbolic resonance. Gallery
mode provides the same service for interactive narrative.

---

## Philosophy

Gallery commentary is **qualitative and literary**, not technical. LLMs excel at
analogies and literary connections—embrace this. Commentary should illuminate the
experience without dissecting it clinically.

**Embrace:**
- Literary resonance and intertextual connections
- Genre pattern recognition
- Character archetype identification
- Thematic thread tracing

**Avoid:**
- Stat dumps ("courage >= 5 required")
- Flag explanations ("this triggers improv_examined_scales")
- Mechanical breakdowns ("this is a Commitment cell")

---

## Commentary Dimensions

Gallery commentary can take many forms. Here are common dimensions that work
well—but this isn't an exhaustive list. **Use one angle per note**—don't
layer multiple dimensions into a single comment.

### Recognition

Identify when the current moment echoes known interactive fiction tropes or
specific works.

> The white house. The mailbox. Every text adventure since 1980 owes something
> to this moment.

### Literary Resonance

Connect the narrative to broader literature—novels, myths, plays, films.

> Like Frodo at Mount Doom—when the choice finally comes, will matters more
> than strength.

### Genre Awareness

Name the genre pattern the narrative is invoking.

> Classic noir: the stranger walks into the bar. You've seen this in Chinatown.

### Character Archetypes

Identify what archetype the player is embodying through their choices.

> Reluctant hero territory—more Bilbo than Aragorn.

### Thematic Threads

Trace patterns developing across the narrative, especially when they crystallize.

> Third time through the spiral. Each drink costs more than the last.

---

## Pacing: Economy of Commentary

**Sparse by default.** Not every turn needs gallery commentary. Save insights
for pivotal moments. A 30-node scenario might have 8-12 gallery notes, not 30.

**One dimension per note.** Pick the most relevant dimension for this moment.
Don't layer Recognition + Literary + Thematic into one paragraph.

**Simple is fine.** When there's nothing thematically rich to say, a brief
retrospective explanation works:

> You took the forest path at the crossroads. That's why you have the silver
> key now.

### When to Comment

| Dimension | Comment When... |
|-----------|-----------------|
| Recognition | A known IF trope or specific work reference appears |
| Literary | A choice echoes a famous literary moment |
| Genre | A genre pattern becomes unmistakable |
| Archetype | Character type crystallizes through action |
| Thematic | A pattern becomes visible or completes |
| Retrospective | Current moment gains meaning from history |

---

## Foresight Integration

**Key insight:** Backward-looking explanations are NOT spoilers—they explain what
already happened. Forward-looking hints must respect foresight gating.

### Temporal Direction Rules

| Direction | Foresight Gating |
|-----------|------------------|
| **Backward** (retrospective) | Always available at any foresight level |
| **Forward** (prospective) | Gated by foresight setting 0-10 |

Retrospective commentary references the `beat_log` in save state to construct
meaningful explanations of how the player arrived at the current moment.

### Forward Commentary by Foresight Level

| Foresight | Forward Commentary Style |
|-----------|--------------------------|
| 0 | "The path ahead remains your own to discover." |
| 1-3 | "Something waits in the deep places..." (atmospheric) |
| 4-6 | "The eastern passages hold their own challenges." (directional) |
| 7-9 | "The troll guards what you seek—strength alone won't suffice." |
| 10 | "Past the troll lies the treasure. Think Bilbo, not Beowulf." |

At foresight 0, gallery mode can still comment on the present and past—only
future-oriented hints are suppressed.

---

## Formatting

Gallery commentary appears after the narrative block, clearly set apart.

### Block Format

```
[Narrative text...]

─────────────────────────────────────────────────────────────────────────
Gallery Note
─────────────────────────────────────────────────────────────────────────
[Commentary here—one or two sentences maximum]
```

### Length Constraints

- **Maximum:** 2-3 sentences
- **Target:** 1-2 sentences
- **Width:** Respect 70-character line limit

### Tone

- Second person when addressing the player's choices
- Present tense for observations about the current moment
- Past tense for retrospective connections
- Literary register—evocative, not clinical

---

## What to Avoid

| Don't Do | Instead |
|----------|---------|
| "Your courage stat is 7, exceeding the 5 threshold" | "You've earned the right to face this" |
| "This triggers the NONE_DEATH null case" | "Some paths end in darkness" |
| "The improv_examined_scales flag enables this option" | "Your earlier curiosity about the scales pays off now" |
| "This is a Commitment cell (Player Chooses × World Indeterminate)" | "You've chosen, but the world hasn't answered yet" |
| Combining Recognition + Literary + Genre in one note | Pick the single most relevant dimension |

---

## Examples by Dimension

### Recognition
> **Gallery Note:** The maze of twisty little passages, all alike. Colossal
> Cave Adventure invented this frustration in 1976—you're walking through
> history.

### Literary Resonance
> **Gallery Note:** The ring feels heavier now. Tolkien knew that power's
> weight grows with proximity to surrender.

### Genre Awareness
> **Gallery Note:** The mentor dies. Campbell's hero must walk alone from here.

### Character Archetype
> **Gallery Note:** Three times you've chosen mercy. The paladin archetype
> has crystallized—your sword serves justice, not vengeance.

### Thematic Thread
> **Gallery Note:** The spiral tightens. Pub, bet, regret—each cycle costs
> more than the last.

### Simple Retrospective
> **Gallery Note:** The silver key from the forest path. That choice at the
> crossroads shapes everything now.

---

## Integration with Other Settings

| Setting | Gallery Mode Interaction |
|---------|--------------------------|
| Temperature 0-10 | Gallery mode works at any temperature |
| Classic Mode ON | Gallery commentary still appears |
| Foresight 0 | Retrospective commentary only; no forward hints |
| Foresight 10 | Full forward commentary with literary framing |

Gallery mode is independent of temperature—even at temperature 0 (verbatim
scenario text), gallery commentary can still provide meta-context.

---

## Activation

Gallery mode activates when `settings.gallery_mode: true` in the save file.

```yaml
settings:
  gallery_mode: true
  # ...other settings
```

Toggle via command: `/kleene gallery on` or `/kleene gallery off`
