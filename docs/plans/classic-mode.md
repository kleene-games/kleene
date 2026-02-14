# Classic Mode Implementation Plan (ARCHIVED)

> **Note:** This feature has been implemented and renamed to "Parser Mode".
> See `lib/framework/gameplay/parser-mode.md` for the current specification.
> The setting has been renamed from `classic_mode` to `parser_mode`.
> Commands `/kleene classic` still work as aliases for `/kleene parser`.

---

# Original Plan (for historical reference)

## Overview

Add a "classic_mode" boolean setting that hides pre-canned choice options, forcing players to type commands like original Zork. When enabled, only "Look around" and "Inventory" are shown - everything else requires free-text input via "Other".

This leverages the existing improvisation system which already handles free-text parsing. No command interpreter needed.

## How It Works

| Mode | Choice Presentation |
|------|---------------------|
| **OFF** (default) | Show 2-4 scripted options + implicit "Other" |
| **ON** | Show only "Look around" + "Check inventory", force typing for actions |

**Why keep two options:** Provides a safety net so players aren't completely lost.
- **Look around**: Re-displays location narrative and available exits/items
- **Check inventory**: Shows current items held (classic parser staple)

## Files to Modify

### 1. `lib/framework/savegame-format.md`
- Add `classic_mode` to settings block
- Add backward compatibility note

### 2. `commands/kleene.md`
- Add "Classic Mode Actions" section
- Add `/kleene classic [on|off]` command handling
- Update Help section

### 3. `skills/kleene-play/SKILL.md`
- Add `classic_mode` to game state model
- Modify choice presentation logic (Phase 2, step 5)
- Add "Look around" and "Inventory" handlers

## Implementation Details

### saves.md Changes

Add to settings block:
```yaml
settings:
  improvisation_temperature: [0-10]
  gallery_mode: [boolean]
  foresight: [0-10]
  classic_mode: [boolean]        # NEW - hide scripted options
```

Add backward compatibility:
```
**v6 → v7:** Saves without `classic_mode` field default to:
- `classic_mode: false`
```

### kleene.md Changes

Add new section after Foresight Actions:

```markdown
### Classic Mode Actions
Keywords: "classic", "parser", "text adventure", "zork mode", "manual"

**Toggle Classic Mode** (`/kleene classic [on|off]`):
1. Parse on/off value (or toggle if not provided)
2. Update `settings.classic_mode` in current game state
3. Confirm with explanation

If no value provided, show current setting and explain:
```
Classic mode: OFF

When ON, hides pre-scripted choice options. You must type commands
like original text adventures (Zork, Colossal Cave, etc.).

Only "Look around" and "Inventory" remain as safety options -
everything else requires typing via "Other". Try commands like:
  - go north / enter cave / climb ladder
  - examine painting / look at sword
  - take key / pick up torch
  - talk to merchant / attack troll

When OFF (default), shows 2-4 scripted choices with descriptions.

Use: /kleene classic on
     /kleene classic off
```

**Note:** Classic mode only affects choice presentation. The
improvisation system handles all typed commands. Setting is
saved with game state.
```

Update Help section:
```
  /kleene classic               Show classic mode status
  /kleene classic [on|off]      Toggle text adventure mode:
                                  on = Type commands (Zork-style)
                                  off = Show choice menu (default)
```

### kleene-play/SKILL.md Changes

Add to game state model:
```yaml
settings:
  improvisation_temperature: number
  gallery_mode: boolean
  foresight: number
  classic_mode: boolean           # Hide scripted options (NEW)
```

Add default in initialization:
```yaml
settings:
  improvisation_temperature: 5
  gallery_mode: false
  foresight: 5
  classic_mode: false            # Default: show choices
```

Modify Phase 2 step 5 (choice presentation):

```markdown
5. Present choices via AskUserQuestion:

   **IF settings.classic_mode == true:**
   ```json
   {
     "questions": [{
       "question": "[node.choice.prompt]",
       "header": "Action",
       "multiSelect": false,
       "options": [
         {"label": "Look around", "description": "Survey your surroundings"},
         {"label": "Inventory", "description": "Check what you're carrying"}
       ]
     }]
   }
   ```

   **ELSE (classic_mode == false):**
   [existing choice presentation code]
```

Add classic mode handlers in Phase 2 step 6:

```markdown
6d. IF selection is "Look around" (classic mode):
    - Re-display current node narrative (abbreviated if long)
    - Extract and list exits mentioned in narrative
    - Extract and list notable items/NPCs if mentioned
    - Format as atmospheric description, not menu
    - Beat++ (log to beat_log with type: "look")
    - Present choices again
    - Do NOT advance node or turn
    - GOTO step 6

6e. IF selection is "Inventory" (classic mode):
    - Display character.inventory as formatted list
    - If empty: "You are empty-handed."
    - If items: List each with brief description if available
    - Beat++ (log to beat_log with type: "inventory")
    - Present choices again
    - Do NOT advance node or turn
    - GOTO step 6
```

## Interaction with Other Settings

| Setting | Interaction with Classic Mode |
|---------|-------------------------------|
| `temperature` | Still affects narrative adaptation for typed commands |
| `gallery_mode` | Still adds meta-commentary if enabled |
| `foresight` | Still controls hint specificity for "help" requests |

Classic mode is orthogonal - it only changes the UI, not the underlying systems.

## Verification

1. **Toggle test**: Run `/kleene classic` - should show OFF by default
2. **Enable test**: Run `/kleene classic on` - should confirm enabled
3. **Gameplay test**: Start game with classic mode, verify only "Look around" + "Inventory" shown
4. **Look test**: Select "Look around" - should redisplay narrative with exits/items
5. **Inventory test**: Select "Inventory" - should show items or "empty-handed"
6. **Type test**: Select "Other", type "go north" - should use improvisation
7. **Mid-game toggle**: Enable classic mode during play, then disable - should work seamlessly
8. **Save/load test**: Enable classic mode, save, reload - should persist
9. **Help test**: Run `/kleene help` - should show classic mode commands
