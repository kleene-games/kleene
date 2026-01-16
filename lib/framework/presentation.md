# Kleene Presentation Conventions

Standardized rules for rendering gameplay UI elements.

> **⚠️ CRITICAL: 70-CHARACTER WIDTH LIMIT**
>
> ALL output — headers, narrative text, status lines — MUST be wrapped
> at **exactly 70 characters**. This is non-negotiable. Users play on
> small screens and terminal windows. Text wider than 70 characters
> will be cut off or cause horizontal scrolling.
>
> When outputting narrative, manually wrap text at 70 characters.



## 3-Level Counter System

Gameplay progress is tracked with three hierarchical counters:

| Level | Increments When | Resets |
|-------|-----------------|--------|
| **Turn** | Advancing to new node via `next_node` | — |
| **Scene** | Location change, time skip, 5+ beats, or explicit marker | Beat → 1 |
| **Beat** | Improvised action resolves, scripted choice selected | — |

**Display format in headers:** `Turn N · Scene S · Beat B`

**Compact notation (for rewind, saves):** `T6.2.3` = Turn 6, Scene 2, Beat 3

### Scene Detection Triggers

Scenes increment automatically on:
1. **Location change**: `world.current_location` differs from scene start
2. **Time skip**: Narrative contains `[Time passes]`, `[Hours later]`, etc.
3. **Beat threshold**: After 5+ beats without scene change
4. **Explicit marker**: `scene_break: true` in scenario YAML

---

## Header Block

There are two types of header that can be displayed for each turn:
- **Cinematic Header**
- **Normal Header**

### Cinematic Header

#### When to Display the Cinematic Header
- **The First Turn** Provide the cinematic header to welcome the player to the game!
- **Location changes** (when `world.current_location` changes)
- **Major story beats** (entering a new act or significant scene)

#### Cinematic Title Formatting
- Convert scenario `name` to spaced uppercase: "The Yabba" → "T H E   Y A B B A"
- Double-space between words, single-space between letters
- Center within 70-char width


#### Cinematic Header Template and Example
**Cinematic Header Template**

```
══════════════════════════════════════════════════════════════════════
               [T I T L E  I N  S P A C E D  C A P S]
══════════════════════════════════════════════════════════════════════
                       [Location Name]
                  Turn N · Scene S · Beat B
══════════════════════════════════════════════════════════════════════
```

**Cinematic Header Example**


```
══════════════════════════════════════════════════════════════════════
                        T H E   Y A B B A
══════════════════════════════════════════════════════════════════════
                         The Royal Hotel
                    Turn 1 · Scene 1 · Beat 1
══════════════════════════════════════════════════════════════════════
```

### Normal Header

#### When to Display the Normal Header
On **normal turns** (same location, no major transition): skip the header block and show the Normal Header
Width: exactly 70 characters.


#### Normal Header Template and Example

**Normal Header Template**

```
══════════════════════════════════════════════════════════════════════
[Location Name] | Turn N · Scene S · Beat B
══════════════════════════════════════════════════════════════════════
```

**Normal Header Example**

```
══════════════════════════════════════════════════════════════════════
The Pub | Turn 4 · Scene 2 · Beat 3
══════════════════════════════════════════════════════════════════════
```



## Footer Block

**Footer Example**

Display after narrative, framed by border lines.

### Format

```
══════════════════════════════════════════════════════════════════════
**[Character Name]** | [Trait1]: [val] ([delta]) | [Trait2]: [val] | ...
[Relationships if non-zero]
══════════════════════════════════════════════════════════════════════
```

### Example

```
══════════════════════════════════════════════════════════════════════
**John Grant** | Dignity: 10 | Sobriety: 7 (-3) | Money: 6
Jock: -3 | Tim: 5
══════════════════════════════════════════════════════════════════════
```


## Header and Footer Values

### Location

- Look up `world.current_location` in scenario's `locations` array
- Display location `name` field, centered

### Counter Display

All three counters are initialized at 1 (no 0th turn/scene/beat).

**Header format:** `Turn N · Scene S · Beat B`

**Examples:**
- `Turn 1 · Scene 1 · Beat 1` — Game start
- `Turn 6 · Scene 2 · Beat 3` — Extended play within turn 6
- `Turn 7 · Scene 1 · Beat 1` — New node transition (resets scene/beat)


### Which Traits to Show

**Dynamic Trait Activation:** Show traits with value ≠ 0 only. Hide
zero-initialized traits until they become relevant. When "Desperation"
first appears in the status line, it signals the stat has activated
and become part of the story. This reduces clutter and makes trait
appearances narratively significant.

### Traits and Relationships

- Only show if non-zero
- Format: `[NPC]: [value]` (e.g., `Jock: -3`)
- Omit relationships at 0
- Show deltas from current turn in parentheses if non-zero
- Remove delta indicator after next turn
- Follow scenario definition order (as they appear in `initial_character.traits`)

### Status Line Compression

When many traits/relationships exist:
- Show only non-zero values
- Wrap at 70 chars onto new lines
- Abbreviate if desperate: "Self-knowledge" → "Self-know:"





## Narrative Block

- Render node `narrative` field directly (it contains markdown)
- Footer Block follows narrative

### Line Length

- **WRAP ALL TEXT AT 70 CHARACTERS** — do not let lines exceed this width
- Target: ≤70 characters per line
- If exceeds, wrap to next line

### Normal Turn Format

On normal turns (no location change), frame the narrative with Normal Header
at top and footer at bottom.

**Normal Turn Example with Header, Narrative and Footer**

```
══════════════════════════════════════════════════════════════════════
The Royal Hotel | Turn 3 · Scene 1 · Beat 2
══════════════════════════════════════════════════════════════════════

The old miner slaps you on the back. "Have another, mate! The Yabba
looks after its own." The beer is cold and the air is thick with
smoke and laughter. You feel yourself relaxing into the rhythm of
the place.

══════════════════════════════════════════════════════════════════════
**John Grant** | Dignity: 8 | Sobriety: 7 (-3) | Money: 6
Jock: 2 | Tim: 5
══════════════════════════════════════════════════════════════════════
```





## Choice Prompts

Use `AskUserQuestion` with these constraints:
- `header`: max 12 characters
- Option `label`: 1-5 words, ≤20 characters
- Option `description`: brief context, ≤50 characters
- Max 4 options (tool limit)

If node has >4 options, select most relevant based on preconditions and current state.




## Improvise Option Flow

When a player selects an option with `next: improvise`, maintain seamless narrative presentation.

### Silent Processing

**NEVER** output internal state or processing notes. The player should experience seamless narrative flow without seeing game mechanics.

Forbidden outputs:
- "This option has `next: improvise`"
- "Presenting sub-prompt"
- "Processing improvisation flow"
- "Executing scripted improvisation"
- Any meta-commentary about option types or game internals

### Transition Flow

```
[Player selects improvise option]
         ↓
[Display option.narrative if present]
         ↓
[Present sub-prompt via AskUserQuestion]
```

### Example

```
> Question the elder

The elder pauses, studying your face.

What specifically do you ask?
  1. Ask about its history
  2. Ask why it attacks now
  ...
```

### Option Narrative

If the improvise option has a `narrative` field, display it as the immediate response to the player's choice BEFORE showing the sub-prompt:

```yaml
- id: ask_elder
  text: "Ask the elder what she knows"
  narrative: "The elder pauses, studying your face."  # ← Display this
  next: improvise
```

The transition from choice → narrative → sub-prompt should feel like natural storytelling, not a game engine exposing its internals.

## Temperature-Adapted Improvised Narrative

When `settings.improvisation_temperature > 0` and relevant `improv_*` flags exist, generate contextual framing woven into the scripted narrative.

### Gallery Mode (Meta-Commentary)

If `settings.gallery_mode: true`, include analytical commentary alongside
the narrative — like the "analysis cards" at art galleries that explain
what's happening beneath the surface.

**Gallery mode ON:** Include meta-headers like `[Temperature 10: Theme]`,
explain psychological dynamics, comment on narrative structure, show why
certain consequences are triggered. Educational and fascinating.

**Gallery mode OFF (default):** Pure in-world narrative only. No
meta-commentary, no mechanics explanations, no breaking the fourth wall.
The player experiences the story without seeing behind the curtain.

**Example (gallery mode ON):**
```
[Temperature 10: Meta-Interrogation]

Doc is asking the player's question through the character. With
self-knowledge at 20 (maximum awareness), John Grant understands his
own self-destruction was irrational. This is the psychological core
of the story — why do people destroy themselves even when they see
the trap clearly?
```

### Formatting Rules

**No special markers** — Improvised text blends seamlessly with narrative. No italics, brackets, labels, or ASCII boxes distinguishing adapted text from scripted text.

### Example - Original Text
```
The dragon's eyes fix upon you. Ancient and knowing, they hold
the weight of centuries. What will you do?
```

### Example - Original Text with Improvised Text woven throughout
```
The dragon's eyes fix upon you with your glowing green spiky hair. Ancient and knowing, they hold
the weight of centuries of punk history. What will you do?
```




**Length by Temperature**

| Temperature | Max Improvisation Length |
|-------------|----------------------|
| 1-3 | 1 sentence |
| 4-6 | 1-2 sentences |
| 7-9 | 2-3 sentences |
| 10 | 3-4 sentences |

### Example: Temperature 5

```
The inscriptions you noticed earlier seem relevant here — the same
curving symbols are etched into the cavern walls.

The dragon's eyes fix upon you. Ancient and knowing, they hold
the weight of centuries. What will you do?
```

### Example: Temperature 10

```
Everything you've learned comes together in this moment — the
inscriptions on the scales, the elder's words about grief, the
way the shadows seem to bow rather than flee. You see now what
others never paused to notice.

The dragon's eyes fix upon you. Ancient and knowing, they hold
the weight of centuries. What will you do?
```

### What NOT to Include (when gallery_mode is OFF)

- Meta-commentary ("Based on your exploration...")
- Game mechanics ("Your improv_examined_scales flag triggers...")
- Future hints ("This will be important later...")
- Forced relevance (referencing unrelated discoveries)
- Scene labels or ASCII title boxes
- Consequence explanations or stat breakdowns

When `gallery_mode: true`, these are encouraged as educational content.

### Tone Matching

Improvised text must match the scenario's established voice:
- **Perspective**: Same as node narrative (usually 2nd person present)
- **Vocabulary**: Match scenario register (archaic, modern, technical)
- **Imagery density**: Match descriptive style of surrounding text

## Bonus Option Presentation

At temperature 7+, bonus options may be generated and added to choices.

### Placement

Bonus options appear AFTER scripted options but BEFORE the implicit "Other" option.

```
What will you do?

1. Attack with your sword
   └── Challenge the dragon in combat

2. Speak to the dragon
   └── Attempt to communicate

3. Trace the inscriptions ★
   └── Follow the symbols you noticed on its scales

[Other: custom action]
```

### Indicator

Use a subtle star (★) after the label to indicate this is a bonus option. Do NOT use labels like "[BONUS]" or "[Generated]".

### Description Style

Bonus option descriptions should:
- Reference the discovery that triggered them
- Use present tense
- Be concise (under 50 characters)
