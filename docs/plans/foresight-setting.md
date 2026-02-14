# Foresight Setting Implementation Plan

## Overview

Add a "foresight" setting to the Kleene gameplay framework that controls how much the game reveals when players ask for hints. This complements the existing `improvisation_temperature` and `gallery_mode` settings.

## Foresight Scale

| Level | Name | Behavior |
|-------|------|----------|
| 0 | Blind | No hints. "You'll have to discover that yourself." |
| 1-3 | Cryptic | Atmospheric, poetic. "Treasures favor those who venture deep..." |
| 4-6 | Suggestive | Directional nudges. "The eastern passages may reward exploration." |
| 7-9 | Helpful | Clear guidance. "The gallery to the east contains a painting." |
| 10 | Oracle | Full walkthrough. "Go east, take painting, return to living room." |

**Default**: 5 (Suggestive) - matches the balanced default of temperature

## Files to Modify

### 1. `lib/framework/savegame-format.md`
- Add `foresight` to save format settings block
- Add backward compatibility note for v5 → v6

### 2. `commands/kleene.md`
- Add "Foresight Actions" section (parallel to Temperature Actions)
- Add `/kleene foresight [0-10]` command handling
- Update Help Actions section with foresight commands

### 3. `skills/kleene-play/SKILL.md`
- Add `foresight` to game state model
- Add hint generation rules in improvisation handling
- Document how foresight gates hint specificity

## Implementation Details

### saves.md Changes

Add to settings block (line ~109):
```yaml
settings:
  improvisation_temperature: [0-10]
  gallery_mode: [boolean]
  foresight: [0-10]              # NEW - hint specificity level
```

Add backward compatibility note:
```
**v5 → v6:** Saves without `foresight` field default to:
- `foresight: 5`
```

### kleene.md Changes

Add new section after Gallery Actions (~line 388):

```markdown
### Foresight Actions
Keywords: "foresight", "hints", "help level", "guidance"

**Set Foresight** (`/kleene foresight [0-10]`):
1. Parse foresight value (0-10)
2. Update `settings.foresight` in current game state
3. Confirm: "Foresight set to [N] ([Name])"

If no value provided, show current setting and explain scale:
```
Current foresight: 5 (Suggestive)

Scale:
  0     Blind       - No hints given
  1-3   Cryptic     - Atmospheric, poetic hints
  4-6   Suggestive  - Directional nudges (default)
  7-9   Helpful     - Clear guidance
  10    Oracle      - Full walkthrough instructions

Use: /kleene foresight [0-10]
```

**Note:** Foresight only applies during active gameplay when
players ask questions like "where is the treasure?" or "what
should I do?". The setting is saved with game state.
```

Update Help section (~line 517-522):
```
  /kleene foresight             Show current foresight level
  /kleene foresight [0-10]      Set hint specificity:
                                  0 = Blind (no hints)
                                  5 = Suggestive (default)
                                 10 = Oracle (full walkthrough)
```

### kleene-play/SKILL.md Changes

Add to game state model (line ~219):
```yaml
settings:
  improvisation_temperature: number  # 0-10, controls narrative adaptation
  gallery_mode: boolean              # Enable meta-commentary
  foresight: number                  # 0-10, controls hint specificity (NEW)
```

Add hint generation rules in improvised action handling section.
When player asks meta-questions (intent: Meta, subtype: hint_request):

```markdown
### Hint Generation (Foresight-Gated)

When player asks for help/hints during improvisation (e.g., "where is
the treasure?", "what should I do?", "how do I get past the troll?"):

1. Classify as Meta intent with hint_request subtype
2. Read `settings.foresight` value
3. Generate hint at appropriate specificity level:

| Foresight | Response Pattern |
|-----------|------------------|
| 0 | "You'll have to discover that yourself." (refuse hint) |
| 1-3 | Atmospheric/poetic. Reference mood, themes, not specifics. |
| 4-6 | Directional. Name regions/directions without exact steps. |
| 7-9 | Clear guidance. Name specific locations and items needed. |
| 10 | Full walkthrough. Step-by-step instructions to goal. |

**Example responses for "Where can I find treasure?"**

- **0**: "The adventurer must discover their own fortune."
- **3**: "Treasures favor those who venture into the deep places..."
- **5**: "The eastern passages and underground depths hold rewards."
- **8**: "There's a painting in the Gallery to the east, and a bar in the Loud Room."
- **10**: "Go east twice to the Gallery, take the painting. Then go down to the cellar, navigate past the troll, and find the platinum bar in the Loud Room."
```

## Verification

1. **Manual test**: Start a new game, verify default foresight is 5
2. **Command test**: Run `/kleene foresight` - should show current level
3. **Command test**: Run `/kleene foresight 3` - should update and confirm
4. **Gameplay test**: Ask "where is treasure?" at different foresight levels
5. **Save/load test**: Change foresight, save, reload - should persist
6. **Help test**: Run `/kleene help` - should show foresight commands
