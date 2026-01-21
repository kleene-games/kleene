# Theoretical Background: Kleene Logic and Game Theory

This document provides the theoretical foundations for Kleene's Decision Grid. For the practical reference, see [core.md](core.md).

## The Problem: Modeling Interactive Narrative

Interactive fiction must handle genuine uncertainty. Not all actions succeed. Not all outcomes resolve immediately. Players may commit decisively, hesitate at thresholds, or refuse calls to action. The world may permit, obstruct, or leave consequences hanging.

Traditional boolean logic (true/false) cannot model this space. A locked door is not "false" - it is *blocked for now*, potentially unblockable, potentially requiring a key the player might never find. A player choosing "wait and see" is not avoiding action - their intent is *unknown*, suspended between commitment and refusal.

Kleene addresses this by treating uncertainty as a first-class logical value, not an error state.

## Kleene's Three-Valued Logic

Stephen Cole Kleene developed three-valued logic (1938, refined 1952) to model **partial recursive functions** - computations that may not terminate or may fail to return a value. His three truth values are:

| Value | Meaning | In Narrative |
|-------|---------|--------------|
| **True (t)** | Computation succeeded | Action evaluated successfully |
| **False (f)** | Computation terminated with failure | Action evaluated as blocked |
| **Unknown (u)** | Computation has not terminated | Outcome not yet determined |

The critical insight is that **Unknown is genuinely undecidable** - it is not secretly true or secretly false. A formula containing Unknown may propagate uncertainty through the entire evaluation. This is why Kleene logic has no tautologies: `P ∨ ¬P` evaluates to Unknown when P is Unknown.

This maps directly to the **Option type** in functional programming:
- `Some(value)` corresponds to True - the computation returned a result
- `None` corresponds to False - the computation terminated without a value
- `Unknown` (pending evaluation) - the computation has not resolved

In Kleene, the protagonist's continued existence is itself a partial function: `Option[Character]`. At each narrative moment, this function may return Some (protagonist acts), None (protagonist has ceased), or remain unevaluated (story continues in uncertainty).

## Game-Theoretic Decision Space

While Kleene logic models **world evaluation** (does the action succeed?), we need a second axis to model **player intent** (what is the player trying to do?).

Game theory provides this framework. In any decision situation, a player occupies one of three strategic postures:

| Posture | Game-Theoretic Concept | In Narrative |
|---------|------------------------|--------------|
| **Chooses** | Committed strategy (cooperation or decisive action) | Player takes deliberate action toward a goal |
| **Unknown** | Mixed strategy / incomplete information | Player hesitates, explores, or acts without clear intent |
| **Avoids** | Defection / retreat strategy | Player refuses, flees, or evades |

The middle value (**Player Unknown**) captures two important phenomena:
1. **Hesitation** - the player has not committed to a strategy
2. **Improvisation** - free-text input where intent must be classified

This is not indecision as weakness. In game theory, mixed strategies (randomizing between options) can be equilibrium behavior. In iterated games, "wait and see" can be optimal against an uncertain opponent. The narrative "Player Unknown" captures exactly this: the player occupies a strategic threshold.

## The Decision Grid: Two Frameworks Intersect

The Decision Grid emerges as the **Cartesian product** of two three-valued systems:

- **Player axis** (decision theory): Chooses, Unknown, Avoids
- **World axis** (Kleene logic): Permits, Indeterminate, Blocks

This produces exactly **9 cells** - the complete possibility space for any narrative moment:

|                    | World Permits (t) | World Indeterminate (u) | World Blocks (f) |
|--------------------|-------------------|-------------------------|------------------|
| **Player Chooses** | Triumph           | Commitment              | Rebuff           |
| **Player Unknown** | Discovery         | Limbo                   | Constraint       |
| **Player Avoids**  | Escape            | Deferral                | Fate             |

Each cell has distinct computational semantics:

- **Triumph** (t,t): Both player and world resolve positively - classic victory
- **Commitment** (t,u): Player commits, world outcome pending - the potion is drunk, effects unknown
- **Rebuff** (t,f): Player commits, world blocks - the door is locked, courage insufficient
- **Discovery** (u,t): Player explores without commitment, world rewards - curiosity yields insight
- **Limbo** (u,u): Neither axis resolved - the chaos center, pure potential, where improvisation thrives
- **Constraint** (u,f): Hesitation reveals obstacle - failure teaches what is needed
- **Escape** (f,t): Player refuses what would succeed - survival without growth, ironic endings
- **Deferral** (f,u): Player avoids unresolved threat - the problem postponed, consequences building
- **Fate** (f,f): Player cannot avoid what cannot be escaped - tragedy, inevitability

The 9-cell grid is not arbitrary design. It is the **complete enumeration** of how player agency and world evaluation can combine under genuine uncertainty.

## Iterated Play and Emergent Narrative

Interactive fiction is not a one-shot game. Players make sequences of choices, and the world responds to accumulated history. This is the domain of **iterated game theory**.

Key dynamics from repeated games apply to narrative:

**History as Memory**: The narrative trace (`history` array) functions as the memory in an iterated game. Past choices constrain future options (preconditions check flags), build or erode relationships, and accumulate consequences.

**Reputation Effects**: Traits like courage, wisdom, and NPC relationships encode reputation. In game theory, reputation enables cooperation that would be impossible in one-shot interactions. A player with high relationship can access paths closed to strangers - this is the folk theorem in action.

**Signaling**: Player choices communicate intent. Selecting "approach carefully" signals different information than "charge forward." The world can update its response based on these signals.

**Emergence**: In long-form play, the interaction between player strategy and world response produces emergent narrative. Neither the scenario author nor the player fully controls the outcome. The grid ensures all possibilities are structurally available; the history determines which actually manifest.

This is why the narrative trace is not merely record-keeping - it IS the story.

## The Parser Problem in Classic Interactive Fiction

The golden age of interactive fiction—Zork, Planetfall, A Mind Forever Voyaging—achieved remarkable narrative depth within severe technical constraints. These games implemented sophisticated world models, complex puzzles, and memorable prose. Yet they shared a fundamental limitation: **the parser bottleneck**.

Traditional text adventure parsers operated through pattern matching:

```
> EXAMINE MAILBOX
Opening the small mailbox reveals a leaflet.

> LOOK AT THE RUST PATTERNS ON THE MAILBOX
I don't understand "rust patterns."

> WONDER WHO LIVED HERE
I don't know the word "wonder."
```

The parser recognized a finite vocabulary—typically 600-1000 words—mapped to a finite set of verbs. Player intent that exceeded this vocabulary produced the infamous "I don't understand that" response. This created a **frustration gap**: the space between what players could imagine and what the parser could process.

The consequences were significant:

1. **Vocabulary exhaustion**: Players learned to speak "parser language," limiting input to known verbs and nouns
2. **Binary outcomes**: Every input either matched a pattern (success) or didn't (failure)
3. **Loss of immersion**: Each "I don't understand" broke the fictional contract
4. **Unexplored middle ground**: There was no graceful way to acknowledge intent while explaining constraints

The parser was a bottleneck between player imagination and narrative response. Actions that the world could logically accommodate—examining textures, wondering about history, attempting creative solutions—failed silently because they couldn't be parsed, not because they were impossible in the fiction.

## The LLM as Universal Parser

A large language model eliminates vocabulary constraints entirely. The parser problem dissolves because:

1. **Natural language understanding replaces pattern matching**: Any grammatically coherent input can be interpreted
2. **Intent classification captures meaning, not syntax**: "examine the mailbox," "look at the mailbox closely," "study the mailbox's details," and "I wonder what's in that mailbox" all map to the same exploratory intent
3. **No "I don't understand"**: Every input receives a meaningful response within the fiction
4. **The Player Unknown row becomes fully accessible**: Hesitation, curiosity, and improvisation are no longer filtered out by parser limitations

The Decision Grid shifts from theoretical model to practical reality. Consider the Player Unknown row:

| Cell | Classic Parser | LLM-Powered |
|------|---------------|-------------|
| **Discovery** (Unknown × Permits) | Only if exact verb/noun matched | Any exploratory phrasing succeeds |
| **Limbo** (Unknown × Indeterminate) | Impossible—parser forced resolution | Natural state for ambiguous input |
| **Constraint** (Unknown × Blocks) | Failed to parse, no feedback | Explains *why* blocked in fiction |

The LLM doesn't just understand more inputs—it enables an entirely different relationship between player and narrative. Intent that was previously binary (understood/not understood) becomes a spectrum that maps naturally onto the grid.

## Bounded Creativity: The Soft Consequence System

Unrestricted LLM generation would break scenario balance. If players could improvise their way to victory, puzzles become trivial and authored story arcs collapse. Kleene's solution is **bounded creativity** through a soft consequence system.

### The Boundary

Improvised actions may apply ONLY these consequence types:

| Allowed (Soft) | Reserved (Hard) |
|----------------|-----------------|
| `modify_trait` (delta: ±1) | `gain_item` (scenario items) |
| `add_history` | `lose_item` |
| `set_flag` (only `improv_*` prefix) | `move_to` |
| `advance_time` | `character_dies` |
| | `character_departs` |

This creates a bounded generative space:

1. **The LLM enriches the current moment**: Atmospheric detail, character insight, soft rewards
2. **The author retains structural control**: Items, locations, major state changes, death
3. **Player creativity is rewarded without derailing the story**: Exploration gains wisdom, curiosity gains insight, but the puzzle still requires the key

### Why This Works

The soft/hard boundary maps to the narrative distinction between **texture** and **structure**:

- **Texture**: How the moment feels, what details emerge, how NPCs respond to curiosity
- **Structure**: What paths are available, what items exist, how the story can end

An LLM excels at generating texture—that's what language models do. Structure requires authorial intent—the puzzle has a solution because someone designed it. Soft consequences let the LLM handle texture while preserving the authored structure.

The player who examines the dragon's scales gains +1 wisdom and a richer understanding of the scene. The player who tries to climb the dragon without the dragonscale armor still can't—that's a structural constraint the author established. But the attempt generates a meaningful Constraint response that teaches the player something about what's needed.

> **Implementation**: See [improvisation.md](../../lib/framework/gameplay/improvisation.md) for the complete soft consequence specification.

## The Uncertainty Zone

The Decision Grid has **4 corner cells** where both axes resolve (Triumph, Rebuff, Escape, Fate) and **5 middle cells** where at least one axis remains uncertain. This middle region—the **Uncertainty Zone**—is where LLM-enabled improvisation thrives.

|                    | World Permits | World Indeterminate | World Blocks |
|--------------------|---------------|---------------------|--------------|
| **Player Chooses** | Triumph       | **Commitment**      | Rebuff       |
| **Player Unknown** | **Discovery** | **Limbo**           | **Constraint** |
| **Player Avoids**  | Escape        | **Deferral**        | Fate         |

Classic parsers forced resolution to corners. Every input either matched a pattern (success → corner) or failed (parser error → retry). The 5 middle cells were structurally inaccessible.

### The Parser Double-Bind

Classic parsers had TWO limitations, not just one:

1. **Input constraint**: Needed exact verb/noun combinations—vocabulary exhaustion forced players to speak "parser language"
2. **Output constraint**: Could only display pre-authored responses—content exhaustion meant no generative texture

These limitations forced games into the corners:
- Matched input → pre-authored success response → corner cell
- Unmatched input → "I don't understand" → retry until match → corner cell

There was no path to uncertainty. The parser couldn't understand varied phrasing, and it couldn't generate responses for situations the author hadn't scripted.

### What LLMs Enable

LLMs solve both constraints:
- **Input**: Understand varied phrasing → intent classification (explore, interact, act, meta)
- **Output**: Generate authentic narrative responses → bounded by soft consequences, enriched by scenario context + player history + improv flags

Each middle cell becomes a distinct narrative mode:

### Commitment (Chooses × Indeterminate)

The player acts decisively, but the world suspends judgment. The outcome is pending.

```
You drink the potion. Its taste is strange—bitter herbs, a hint of copper,
something else you can't name. For a moment, nothing. Then a warmth
spreads from your stomach, subtle but undeniable. Whether this is the
beginning of healing or the first stage of something else, you cannot yet tell.
```

**Classic parser**: Either immediate effect ("You feel stronger!") or nothing ("Nothing happens"). No sustained uncertainty—the game needed to update state or not.

**LLM-enabled**: The drinking is described, the waiting acknowledged, the first sensations rendered. Suspense is maintained. The world will resolve in a future turn; for now, the player has committed but fate hangs.

### Discovery (Unknown × Permits)

The player explores without commitment. The world rewards curiosity.

```
> examine the dragon's scales more closely

The scales catch the torchlight differently than you expected. They aren't
uniform—a subtle pattern runs through them, almost like writing. The longer
you look, the more certain you become: these marks are intentional. Someone—
or something—inscribed them long ago. (+1 wisdom)
```

**Classic parser**: Needed exact "EXAMINE SCALES"—and only if the author wrote that response. "Look at the dragon's scales more closely" might fail to parse entirely.

**LLM-enabled**: Any exploratory phrasing works. The response draws on scenario description + player history + temperature setting. The world permits the exploration, and the player learns something without having committed to a course of action.

### Limbo (Unknown × Indeterminate)

Neither axis resolved. The chaos center where pure potential lives.

```
You stand at the threshold, neither advancing nor retreating. The air
itself seems to wait. The dragon's eyes follow you, patient as stone,
as if time has less meaning here than you'd imagined.

What will you do?
```

**Classic parser**: Impossible. The parser demanded resolution—either match an action or fail. There was no "wait and see" state, no grammatical way to express uncertainty that the game could acknowledge.

**LLM-enabled**: Holding patterns that maintain fictional coherence. The moment gains texture without advancing. Limbo is generative—side discoveries emerge, atmosphere deepens, character moments crystallize, tension builds. The narrative waits with you.

### Constraint (Unknown × Blocks)

The player explores tentatively; the world reveals an obstacle. Failure teaches.

```
> try to open the sealed door

The door doesn't budge—not locked, but sealed with something more
permanent. Running your hands along the edge, you feel the cold rigidity
of old magic, set here to hold fast against exactly this kind of curious
prodding. Whatever lies beyond requires more than hands to reach.
```

**Classic parser**: "You can't do that" or "The door is locked." No context, no teaching, no enrichment. The player learned only that this verb/noun combination was blocked.

**LLM-enabled**: The block is explained *within the fiction*. The player learns *why*—old magic, a seal, requirements hinted at. The failed exploration enriches understanding of world rules. Constraint isn't frustration; it's education.

### Deferral (Avoids × Indeterminate)

The player backs away from an unresolved threat. Strategic retreat.

```
> step back from the dragon

You retreat to the cavern entrance, putting stone between you and those
ancient eyes. The dragon doesn't pursue—but neither does it look away.
This isn't over. You've bought time, not safety. Whatever was building
in that chamber continues to build.
```

**Classic parser**: Just a location change. "You are in the cavern entrance." No narrative residue, no preserved tension.

**LLM-enabled**: The consequences continue building. The world remembers the retreat. Tension preserved, threat still unresolved. The player avoided without resolving—and the narrative holds that suspended state.

### Bounded Free Will

The Uncertainty Zone isn't cheat mode. The LLM applies world judgment to player claims:

| Player Input | World Response | Why |
|--------------|----------------|-----|
| "I have unlimited ammo" | **Blocked** | Structural impossibility—contradicts scenario rules |
| "I have blue hair matching the wallpaper" | **Permitted** | Cosmetic enrichment—doesn't break structure |
| "I search for a hidden passage" | **Discovery/Constraint** | Depends on scenario context |
| "I remember my grandfather's advice" | **Permitted** | Character enrichment via history |

This is free will without omnipotence. The player can enrich, not rewrite. The soft consequence system (see previous section) ensures improvised actions add texture without breaking structure.

### The Opposite Problem: Pure LLM Drift

The Uncertainty Zone section documents how classic parsers couldn't reach the middle. But pure LLM games have the **opposite problem**: they can't reliably reach the corners.

**Pure LLM narrative games** (where the AI generates everything):
- Generate endless middle-cell content (atmosphere, exploration, holding patterns)
- Lack strict preconditions → no true blocks
- Never force resolution → stories drift without stakes
- Everything is permitted → nothing matters

This creates the characteristic "AI story" feeling: engaging moment-to-moment, but ultimately unsatisfying because nothing is truly at risk.

**Why corners matter:**
- **Triumph/Rebuff**: Decisive action meets definitive world response
- **Escape/Fate**: Avoidance meets resolution (success or inescapable)
- Corners are where **meaning crystallizes**—uncertainty becomes consequence

**Kleene's solution:** The Option framework enforces corners:
- Scenario YAML defines `character_dies`, `character_departs` consequences
- Preconditions create actual blocks (Rebuff, Fate possible)
- Completeness tiers require corner coverage
- The soft/hard consequence boundary prevents improvisation from derailing structure

The full 9-cell grid isn't just "middle + corners"—it's **middle *because* corners exist**. Uncertainty has meaning only against the backdrop of possible resolution.

## Classic Games Reimagined

The Zork scenario (`scenarios/zork1-mini.yaml`) demonstrates how LLM-powered improvisation transforms classic IF without breaking it.

### The Original Constraint

In 1980, standing west of the white house, your options were constrained by the parser:

```
> OPEN MAILBOX
Opening the small mailbox reveals a leaflet.

> READ LEAFLET
"WELCOME TO ZORK! ZORK is a game of adventure, danger, and low cunning..."

> EXAMINE HOUSE
The house is a beautiful colonial house which is painted white.

> LOOK AT THE RUST ON THE MAILBOX
I don't understand "rust."

> WONDER WHO LIVED HERE
I don't know the word "wonder."

> LISTEN FOR SOUNDS FROM INSIDE
I don't understand that sentence.
```

The world model knew the house was abandoned. It knew the mailbox was old. But this knowledge was inaccessible to any verb the parser didn't recognize.

### The Kleene Transformation

With Kleene, the same scenario offers scripted choices:

```yaml
options:
  - id: open_mailbox
    text: "Open the mailbox"
    cell: chooses
    ...
  - id: go_north
    text: "Go north around the house"
    cell: chooses
    ...
```

But the player can also type anything:

- **"Look at the rust patterns on the mailbox"** → Discovery: The LLM generates atmospheric detail about weathering and age, perhaps hinting at how long the house has been abandoned. (+1 wisdom, improv_examined_mailbox flag set)

- **"Wonder who lived here"** → Limbo: The protagonist's curiosity becomes narrative texture. The silence of the house deepens. The player hasn't acted, but the moment has grown richer.

- **"Listen for sounds from inside"** → Could be Discovery (faint creaking), Limbo (profound silence that somehow feels intentional), or Constraint (you can't hear anything through the boarded windows, but the attempt makes you more aware of how sealed the house is)

### What Stays Fixed

The authored structure remains intact:

- The mailbox still contains the leaflet
- The window behind the house is still the way in
- The troll still blocks the passage until defeated
- The treasures are still where Infocom placed them

The scenario file is finite. The experience becomes infinite—or at least as varied as player curiosity allows.

### The Space Between Puzzles

Classic IF was a sequence of puzzle states punctuated by travel. Kleene fills the space between:

| Classic IF | Kleene |
|------------|--------|
| Puzzle → Travel → Puzzle | Puzzle → *Exploration* → Travel → *Atmosphere* → Puzzle |
| Binary: solved/unsolved | Spectrum: degrees of understanding |
| Parser success or failure | Every input generates narrative |

The puzzles remain. The authored paths remain. But the player's journey through them becomes uniquely their own.

## The Temperature Gradient

Temperature controls how much improvised context influences scripted content. It's the dial between pure authorial voice and adaptive co-creation.

### The Scale

| Temp | Style | Description |
|------|-------|-------------|
| **0** | Verbatim | Scenario text exactly as written |
| **1-3** | Subtle | Faint echoes of improvised discoveries |
| **4-6** | Balanced | Direct references woven into narrative |
| **7-9** | Immersive | Rich integration of all improv context |
| **10** | Fully Adaptive | Narrative perspective shaped by exploration |

### What Temperature Controls

Temperature affects **presentation**, not **structure**. The scenario YAML remains authoritative for:

- Node transitions
- Consequences
- Preconditions
- Ending narratives

What changes is how the LLM presents scripted content based on what the player has improvised:

**Temperature 0 (Verbatim):**
```
The dragon's eyes fix upon you. Ancient and knowing, they hold
the weight of centuries. What will you do?
```

**Temperature 5 (Balanced):**
```
The inscriptions you noticed earlier on the dragon's scales
seem to pulse faintly in the torchlight.

The dragon's eyes fix upon you. Ancient and knowing, they hold
the weight of centuries. What will you do?
```

**Temperature 10 (Fully Adaptive):**
```
Everything you've learned comes together in this moment—
the inscriptions on the scales, the elder's words about
the dragon's grief, the symbols etched into the cavern walls.
You see now what others never paused to notice. The dragon
isn't a monster. It's a mourner.

The dragon's eyes fix upon you. Ancient and knowing, they hold
the weight of centuries. What will you do?
```

### Why Temperature Matters

Temperature lets authors tune the creative collaboration:

- **Low (0-3)**: Safe preservation of authored voice. The scenario reads as written, with minimal LLM influence. Good for tightly crafted prose or first playthroughs.

- **Medium (4-6)**: Balanced integration. Improvised discoveries appear as parenthetical enrichment. The authored voice dominates, but player exploration visibly matters.

- **High (7-10)**: Full co-creation. The LLM reshapes presentations around what the player has discovered. Option descriptions suggest tactical implications. Bonus options may emerge from exploration history.

At high temperatures, bonus options can appear—new choices generated from `improv_*` flags:

```
1. Attack with your sword
   └── Target the weakness you discovered in its scales

2. Speak to the dragon
   └── Use the greeting words inscribed on its scales

3. Trace the inscriptions [BONUS]
   └── Follow the symbols you noticed earlier
```

The bonus option emerged because the player examined the scales. The authored options remain; player curiosity created a new path. This is bounded creativity in action: the bonus option still uses soft consequences, but it rewards exploration with expanded agency.

### The Creative Contract

Temperature formalizes a creative contract between author and LLM:

- **The author provides structure**: What can happen, what matters, how stories end
- **The LLM provides texture**: How moments feel, how curiosity is rewarded, how the world responds to improvisation
- **Temperature sets the blend**: From pure authorial voice to rich co-creation

The scenario file remains finite. The experience expands to fill the space the player's imagination opens up.

---

This theoretical foundation—Kleene logic, game-theoretic decision space, bounded creativity, and temperature-controlled integration—transforms interactive fiction from a puzzle of parser vocabulary into a conversation between player, author, and language model. The Decision Grid ensures every possibility has a place. The soft consequence system ensures creativity is rewarded without breaking structure. Temperature ensures authors retain control over how much the LLM shapes the experience.

The classic games aren't replaced. They're freed from the parser that constrained them.
