# Kleene Presentation Conventions

Standardized rules for rendering gameplay UI elements.

## Header Block

Display at game start and optionally at major transitions. Width: 70 characters.

```
═══════════════════════════════════════════════════════════════════════
                    [TITLE IN SPACED CAPS]
═══════════════════════════════════════════════════════════════════════
                       [Location Name]
                    Turn N | [Time if tracked]
              [Trait Bars - see rules below]
═══════════════════════════════════════════════════════════════════════
```

### Title Formatting

- Convert scenario `name` to spaced uppercase: "The Yabba" → "T H E   Y A B B A"
- Double-space between words, single-space between letters
- Center within 70-char width

### Location

- Look up `world.current_location` in scenario's `locations` array
- Display location `name` field, centered

### Time

- Only show if scenario tracks time (has `time` consequences)
- Format: `Turn N` or `Turn N | Time: HH:00`

## Trait Display Rules

### Which Traits to Show

- If scenario has ≤5 total traits: show all
- Otherwise: show traits with value ≠ 0 (hide zero-initialized until modified)

### Display Order

Follow scenario definition order (as they appear in `initial_character.traits`)

### Format

```
Name: [bar] value
```

Bar is 10 segments:
- Full segment: █
- Empty segment: ░
- Scale: `value / max_value` (default max: 10)

Example: Sobriety at 7/10 → `Sobriety: ███████░░░ 7`

### Deltas

Show changes from current turn:
```
Sobriety: ███████░░░ 7 (-3)
```

Remove delta indicator after next turn.

### Capping

- Traits cap at their max (default 10, unless scenario specifies)
- Display shows actual value, not capped: if trait reaches 12, show 12

## Status Line

Display after each narrative block, separated by horizontal rule.

### Format

```
---
**[Character Name]** | [Trait1]: [val] | [Trait2]: [val] | ...
📍 [Location] | [Key Relationships]
```

### Line Length

- Target: ≤80 characters per line
- If exceeds, break at `|` separator

### Relationships

- Only show if non-zero
- Format: `[NPC]: [value]` (e.g., `Jock: -3`)
- Omit relationships at 0

### Example

```
---
**John Grant** | Dignity: 13 | Sobriety: 9 | Money: 8
📍 The Royal Hotel | Jock: -3
```

## Narrative Block

- Render node `narrative` field directly (it contains markdown)
- No additional decoration around narrative text
- Status line follows narrative after `---` separator

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

### Example: WRONG

```
> Question the elder

This option has next: improvise. Presenting sub-prompt.

What specifically do you ask?
  1. Ask about its history
  ...
```

### Example: CORRECT

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
