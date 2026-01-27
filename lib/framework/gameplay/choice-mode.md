# Choice Mode Behaviors

Menu-driven interface for accessible narrative gameplay.

> **Setting:** `settings.parser_mode: false` (this is the default)

## Overview

Choice mode presents structured narrative options via menus. Players
select from curated choices representing meaningful narrative branches.

### Why Choice Mode?

- **Accessibility**: Clear options reduce cognitive load
- **Guidance**: Players always know valid actions exist
- **Discovery**: Options reveal narrative possibilities
- **Onboarding**: Perfect for new players learning the scenario

### Mode Comparison

| Aspect | Choice Mode (default) | Parser Mode |
|--------|----------------------|-------------|
| Options visible | Yes (2-4 scripted) | No (hidden) |
| Input method | Select from menu | Type commands |
| Help system | Self-evident options | Adaptive verb hints |
| Free-text | Via "Other" option | Primary input |
| Setting | `parser_mode: false` | `parser_mode: true` |

---

## Choice Presentation

When choice mode is active, present scripted options from the current
node's `choice.options` array.

### Presentation Rules

1. **Filter by precondition**: Only show options whose preconditions pass
2. **Order preservation**: Maintain scenario-defined option order
3. **Maximum 4 options**: Tool constraint - select most relevant if >4
4. **Implicit "Other"**: Always available for free-text improvisation

### AskUserQuestion Format

```json
{
  "questions": [{
    "question": "[node.choice.prompt]",
    "header": "Choice",
    "multiSelect": false,
    "options": [
      {"label": "Attack", "description": "Draw your sword and strike"},
      {"label": "Negotiate", "description": "Attempt to reason with them"},
      {"label": "Flee", "description": "Run back the way you came"}
    ]
  }]
}
```

### Formatting Constraints

| Element | Constraint |
|---------|-----------|
| `header` | Max 12 characters |
| `label` | 1-5 words, ≤20 characters |
| `description` | ≤50 characters |

---

## Silent Precondition Filtering

Options failing preconditions are removed BEFORE presenting choices.
Never show "locked" or "requires X" indicators.

**Why?** The character simply doesn't think of impossible actions.
This maintains immersion — if you can't do it, you don't see it.

### Example

If the player lacks a key, the "Unlock the door" option simply doesn't
appear. No visual indication that the option exists or is locked.

---

## Free-Text via "Other"

The "Other" option is always implicitly available, allowing players
to type custom actions.

### When Player Selects "Other"

1. Prompt for free-text input
2. Classify intent (Explore/Interact/Act/Meta)
3. Check feasibility against current state
4. Generate narrative response
5. Apply soft consequences only
6. Return to same choice point

> **Full specification:** See [improvisation.md](improvisation.md)

---

## Temperature Integration

At higher temperatures (4+), choice mode adapts:

### Temperature 4-6 (Balanced)

- Option descriptions may reference `improv_*` discoveries
- E.g., "Attack (you recall its scarred side)"

### Temperature 7+ (Immersive)

- Bonus options may appear based on player discoveries
- Marked with subtle ★ indicator
- Appear after scripted options, before "Other"

### Example at Temperature 7

```
What do you do?

1. Attack with your sword
   └── Challenge the dragon in combat

2. Speak to the dragon
   └── Attempt to communicate

3. Trace the inscriptions ★
   └── Follow the symbols you noticed on its scales

[Other: custom action]
```

---

## Comparison with Parser Mode

Both modes share the same underlying systems:

| Component | Behavior |
|-----------|----------|
| Improvisation engine | Identical - same intent classification |
| Consequence application | Identical - same state changes |
| Temperature adaptation | Identical - same narrative weaving |
| Save/load | Identical - mode is a setting in save file |

The only difference is **presentation**:
- Choice mode shows the options
- Parser mode hides them

Players can switch modes at any time with `/kleene parser on` or
`/kleene choice on` (which sets `parser_mode: false`).

---

## When to Recommend Choice Mode

Suggest choice mode (the default) when:

- Player is new to interactive fiction
- Player prefers guided experiences
- Scenario has complex option dependencies
- Player wants to see the possibility space

---

## Related Documentation

- **[Parser Mode](parser-mode.md)** - The complementary parser-style interface
- **[Improvisation](improvisation.md)** - Free-text action handling
- **[Presentation](presentation.md)** - Visual formatting conventions
