# Story Endings

How narratives conclude in Kleene.

## Ending Types

| Type | Option State | What It Means | Example |
|------|--------------|---------------|---------|
| **victory** | Some | Character survives, transformed by journey | Slaying the dragon |
| **unchanged** | Some | Character survives but unchanged (irony) | Fleeing without growth |
| **death** | None | Character destroyed | Consumed by dragonfire |
| **transcendence** | None | Character departed (ascended, stayed behind, etc.) | Choosing the fairy realm |

## Relationship to Option Semantics

- **Some** endings: Character exists at story end (victory, unchanged)
- **None** endings: Character absent at story end (death, transcendence)

The SOME_*/NONE_* prefixes in analysis output reflect this:
- `SOME_TRANSFORMED` → victory
- `SOME_UNCHANGED` → unchanged
- `NONE_DEATH` → death
- `NONE_REMOVED` → transcendence

## Relationship to the Decision Grid

Ending types are **orthogonal** to Decision Grid cells. The Grid describes *how you arrive*; the ending type describes *what kind of outcome*.

| Grid Cell | Can Lead To |
|-----------|-------------|
| **Triumph** | Usually victory, but could be pyrrhic (death) |
| **Rebuff** | Often unchanged (blocked), but could force death |
| **Escape** | Typically unchanged (fled), occasionally victory (strategic retreat) |
| **Fate** | Often death/transcendence (inescapable), but could be unchanged |
| **Discovery** | Often victory (rewarded curiosity), could be transcendence |
| **Limbo** | Any—the chaos zone |
| **Commitment** | Outcome pending—depends on what resolves |
| **Constraint** | Often unchanged (limitation revealed), could trigger death |
| **Deferral** | Problem postponed—any ending possible when it resurfaces |

## Author Guidance

### Choosing an Ending Type

**Victory** — Use when the protagonist:
- Achieves their primary goal
- Undergoes meaningful growth or change
- Resolves the central conflict favorably

**Unchanged** — Use when the protagonist:
- Survives but learns nothing
- Returns to where they started (circular journey)
- Avoids the challenge entirely (ironic escape)

**Death** — Use when the protagonist:
- Is physically destroyed
- Ceases to exist through violence or catastrophe
- Makes a fatal mistake

**Transcendence** — Use when the protagonist:
- Chooses to leave the mortal world
- Ascends to a higher state
- Remains in another realm (fairy realm, dream world)
- Transforms into something non-human

### Completeness Requirements

For Bronze tier (minimum), scenarios need:
- At least one **death** ending (mortality has stakes)
- At least one **victory** ending (growth is possible)

For richer narratives (Silver/Gold):
- Include **unchanged** endings (irony, cost of avoidance)
- Include **transcendence** endings (alternatives to binary win/lose)

### Common Patterns

**The Pyrrhic Victory**
```yaml
endings:
  pyrrhic:
    narrative: "The dragon dies, but so do you..."
    type: death  # Not victory—character doesn't survive
```

**Strategic Retreat**
```yaml
endings:
  wise_retreat:
    narrative: "You flee, but carry the lesson..."
    type: victory  # Growth through wisdom, not combat
```

**Ironic Escape**
```yaml
endings:
  coward:
    narrative: "Safe. Unchanged. The dragon still hunts."
    type: unchanged  # Survival without growth
```

**Transcendent Choice**
```yaml
endings:
  fairy_realm:
    narrative: "You choose the eternal twilight..."
    type: transcendence  # Departure, not death
```

## YAML Syntax

```yaml
endings:
  ending_id:
    narrative: |
      Multi-line ending narrative...
    type: victory | death | transcendence | unchanged
```

The `type` field is required and must be one of the four values.

## Ending Flavor System

The four ending types capture *what* happened to the character (existence state), but not *how* or *why*. Two victory endings can feel completely different:

- Victory via forged blade (combat triumph)
- Victory via dragon dialogue (wisdom path)
- Victory via desperate unarmed strike (lucky survival)

The Ending Flavor System adds two optional dimensions to classify endings with narrative nuance.

### Three Dimensions of Endings

| Dimension | Question | Examples |
|-----------|----------|----------|
| **Type** (required) | What is the character's final state? | victory, death, transcendence, unchanged |
| **Method** (optional) | How did they achieve this outcome? | force, wisdom, sacrifice, avoidance |
| **Tone** (optional) | What emotional resonance does it carry? | triumphant, tragic, bittersweet, hollow |

### Method Dimension

The *method* describes how the outcome was achieved.

| Method | Description | Example |
|--------|-------------|---------|
| **force** | Combat, physical dominance | Slaying dragon with forged blade |
| **wisdom** | Understanding, knowledge, dialogue | Speaking the dragon's language |
| **cunning** | Trickery, misdirection, exploitation | Trapping dragon, exploiting weakness |
| **luck** | Chance, desperation, improbable success | Unarmed desperate strike |
| **sacrifice** | Self-destruction for others | Shielding elder from flames |
| **relationship** | Help from NPCs, bonds | Elder translating ancient tongue |
| **time** | Patience, waiting, outlasting | Waiting for dragon to leave |
| **avoidance** | Fleeing, hiding, refusing engagement | Escaping through forest |

### Tone Dimension

The *tone* describes the emotional arc and resonance of the ending.

| Tone | Description | Example |
|------|-------------|---------|
| **triumphant** | Pure victory, celebration | Dragon slain, village celebrates |
| **bittersweet** | Victory with cost, mixed feelings | Won but lost something precious |
| **tragic** | Noble failure, honorable death | Died protecting the innocent |
| **ironic** | Unexpected twist, subverted expectations | Survived but world unchanged |
| **enlightened** | Transcendent understanding | Glimpsed deeper patterns |
| **hollow** | Empty achievement, pyrrhic | Won but at what cost? |
| **haunting** | Lingering consequences, regret | Too late, village burned |
| **shameful** | Cowardice, failure to act | Fled while others suffered |

### Example Combinations

Combining Type × Method × Tone creates nuanced ending classifications:

| Type | Method | Tone | Ending Flavor |
|------|--------|------|---------------|
| victory | force | triumphant | Classic Hero |
| victory | wisdom | enlightened | Sage's Path |
| victory | luck | bittersweet | Desperate Triumph |
| victory | relationship | triumphant | Partnership Victory |
| death | sacrifice | tragic | Noble Sacrifice |
| death | force | hollow | Pyrrhic Death |
| death | avoidance | shameful | Coward's End |
| transcendence | wisdom | enlightened | Ascension |
| unchanged | avoidance | shameful | Fled in Shame |
| unchanged | time | haunting | Too Late |

### YAML Syntax with Flavor

```yaml
endings:
  ending_victory_combat:
    narrative: "The dragon yields to your blade..."
    type: victory
    method: force        # Optional: how the outcome was achieved
    tone: triumphant     # Optional: emotional resonance
```

### When to Specify Flavor

**Add method and tone when:**
- Multiple endings share the same type but feel different
- The ending's emotional arc matters to the narrative
- You want analysis tools to distinguish between endings

**Leave implicit when:**
- The ending is straightforward and the type alone suffices
- Method and tone are obvious from narrative context
- The scenario is simple with few endings

### Decision Grid Influence on Tone

The final Decision Grid cell often correlates with tone:

| Final Cell | Typical Tones |
|------------|---------------|
| Triumph | triumphant, enlightened |
| Rebuff | hollow, ironic |
| Escape | bittersweet, shameful |
| Fate | tragic, haunting |
| Discovery | enlightened, bittersweet |
| Constraint | hollow, haunting |

### Future: Trait-Based Inference

Future analysis tools may infer method and tone from character journey when not specified:

- High courage delta + victory → likely method: force
- High wisdom + transcendence → likely method: wisdom
- Courage decreased + unchanged → likely tone: shameful

This inference will supplement, not replace, author-specified values.

## Runtime vs. Ending Types

Note the distinction between:

- **Runtime consequences** (`character_dies`, `character_departs`) — Applied during gameplay when something happens mid-story
- **Ending types** (`victory`, `death`, etc.) — Classification of how the narrative concludes

A `character_dies` consequence during play leads to a `death` ending. A `character_departs` consequence leads to a `transcendence` ending. But you can also reach endings through node routing without explicit death/departure consequences.

## See Also

- [scenario-format.md](scenario-format.md) — Full YAML specification
- [core.md](core.md) — Decision Grid and Option type foundations
- [SCENARIO_AUTHORING.md](../../docs/SCENARIO_AUTHORING.md) — Authoring tutorial
