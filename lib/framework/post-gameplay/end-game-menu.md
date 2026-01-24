# End-Game Statistics and Analysis Framework

Rules for presenting end-game options after an ending is reached.

> **Philosophy:** End-game is not just "game over" — it's a moment for
> reflection on the journey taken. Statistics reveal character growth,
> analysis illuminates decisions made, and replay options invite
> exploration of paths not taken. Analytics serve narrative closure,
> not arbitrary achievement tracking.

## Menu System

After displaying the ending narrative and type box, present an
interactive menu instead of dumping stats as text.

### Menu Presentation

```json
{
  "questions": [{
    "question": "What would you like to do?",
    "header": "Game Over",
    "multiSelect": false,
    "options": [
      {
        "label": "View stats",
        "description": "See final traits, relationships, and inventory"
      },
      {
        "label": "Game analysis",
        "description": "Timeline, key decisions, paths not taken"
      },
      {
        "label": "Play again",
        "description": "Start fresh from the beginning"
      },
      {
        "label": "Replay moment",
        "description": "Return to a key decision point"
      }
    ]
  }]
}
```

### Menu Conventions

Follow `AskUserQuestion` constraints from presentation.md:
- **Header**: Max 12 characters ("Game Over" = 9)
- **Labels**: 1-5 words, ≤20 characters
- **Descriptions**: ≤50 characters

---

## View Stats Option

Display formatted stats block showing final state compared to start.

### Stats Display Format

> **Width:** Exactly 70 characters per line.
> See `presentation.md` for formatting conventions.

```
══════════════════════════════════════════════════════════════════════
FINAL STATS
══════════════════════════════════════════════════════════════════════

TRAITS
  Courage:  7  (+2 from start)
  Wisdom:   8  (+3 from start)
  Luck:     3  (-2 from start)

RELATIONSHIPS
  Elder:    6  (Trusted)
  Dragon:   4  (Respected)

INVENTORY
  • Ancient sword
  • Dragon scale pendant
  • Map of forgotten paths

TIME
  Elapsed: 3 days, 4 hours
══════════════════════════════════════════════════════════════════════
```

### Format Rules

- Show trait values with net change from `initial_character` values
- Only show RELATIONSHIPS section if any relationships exist
- Show inventory as bulleted list, or "Empty" if none
- Show TIME section only if scenario tracks it (`world.time > 0`)

### After Stats Display

Re-present the end-game menu to allow further options.

---

## Game Analysis Option

Display deeper playthrough analysis using data from `beat_log`.

### Analysis Display Format

```
══════════════════════════════════════════════════════════════════════
GAME ANALYSIS
══════════════════════════════════════════════════════════════════════

JOURNEY TIMELINE
  T1.1.1  Started at Village Entrance
  T2.1.1  Met the Elder, learned of the dragon
  T3.2.1  Explored the Shrine, took Dragon Tongue scroll
  T4.3.1  [Improv] Asked about the sword's history
  T5.4.1  Climbed the mountain path
  T6.5.1  Confronted the dragon

KEY DECISIONS
  • T2.1.2 Asked about the key → led to shrine access
  • T3.2.1 Took the scroll → enabled dragon negotiation
  • T6.5.1 Chose to negotiate → Victory ending

PATHS NOT TAKEN
  • Could have attacked the dragon (Rebuff → Death likely)
  • Could have fled the mountain (Escape → Unchanged ending)
  • Never explored the cave system

DECISION GRID COVERAGE
  ┌─────────────┬─────────────┬─────────────┐
  │  Triumph ✓  │ Commitment  │   Rebuff    │
  ├─────────────┼─────────────┼─────────────┤
  │ Discovery ✓ │   Limbo ✓   │ Constraint  │
  ├─────────────┼─────────────┼─────────────┤
  │   Escape    │  Deferral   │    Fate     │
  └─────────────┴─────────────┴─────────────┘
  Coverage: 3/9 cells (Bronze tier)
══════════════════════════════════════════════════════════════════════
```

### Analysis Generation Rules

**Journey Timeline:**
- Build from `beat_log` entries
- Use compact notation: `T6.2.3` = Turn 6, Scene 2, Beat 3
- Mark improvised actions with `[Improv]` prefix
- One line per significant beat

**Key Decisions:**
- Beats where `next_node` was selected (scripted choices)
- Include arrow showing consequence: `→ led to X`
- Focus on decisions that changed trajectory

**Paths Not Taken:**
- Examine options in visited nodes that weren't selected
- Include likely outcome in parentheses
- Mention unexplored locations or NPCs

**Decision Grid Coverage:**
- Track which grid cells were touched during play
- Mark visited cells with `✓`
- Calculate tier: Bronze (4 corners), Silver (+2), Gold (all 9)

### After Analysis Display

Re-present the end-game menu to allow further options.

---

## Play Again Option

Reset all state and restart from Turn 1.

### Reset Procedure

1. Re-initialize from scenario's `initial_character` and `initial_world`
2. Reset counters: `turn: 1, scene: 1, beat: 1`
3. Clear `beat_log` and `recent_history`
4. Set `current_node` to `start_node`
5. Begin Phase 2 (Game Turn) from step 1

### What Clears

- All character traits reset to initial values
- All relationship values reset
- Inventory cleared, initial items restored
- All flags cleared, initial flags restored
- World state reset to initial
- All counters reset to 1
- Beat log cleared
- Checkpoints cleared

### What Persists

- Scenario remains cached in context
- Player's knowledge of the story (meta)
- Session statistics (for multi-run analysis)

---

## Replay from Moment Option

Allow player to return to a key decision point and try a different
path.

### Key Moment Sub-Menu

Present a sub-menu of identified decision points:

```json
{
  "questions": [{
    "question": "Which moment would you like to return to?",
    "header": "Rewind",
    "multiSelect": false,
    "options": [
      {
        "label": "T2.1.2",
        "description": "When you asked about the elder's key"
      },
      {
        "label": "T3.2.1",
        "description": "Taking the Dragon Tongue scroll at the Shrine"
      },
      {
        "label": "T6.5.1",
        "description": "Facing the dragon on the mountain"
      }
    ]
  }]
}
```

### Key Moment Identification

Identify key moments from `beat_log` entries matching these criteria:
- `type: "scripted_choice"` — Node transitions via option selection
- `type: "improv"` — Free-text improvised actions
- Beats where major flags changed
- Beats where location changed

### State Restoration Algorithm

When a moment is selected:

1. Find the `beat_log` entry for that moment
2. Replay consequences from game start up to (but not including) beat
3. Set `current_node` to the node where that choice was made
4. Present the choices from that node (player can make different choice)

### Checkpoint Implementation

- Store snapshots: On each Turn++, save a checkpoint of full state
- Checkpoints stored in memory during play, not persisted to disk
- Rewind = restore checkpoint, clear subsequent `beat_log` entries

### No Key Moments Edge Case

If no key moments exist (very short game), show fallback menu:

```json
{
  "questions": [{
    "question": "No key decision points recorded. What would you do?",
    "header": "Rewind",
    "multiSelect": false,
    "options": [
      {
        "label": "Play again",
        "description": "Start fresh from the beginning"
      },
      {
        "label": "Back to menu",
        "description": "Return to end-game options"
      }
    ]
  }]
}
```

---

## End-Game Menu Loop

The menu loops until player selects an action that exits the loop.

### Control Flow

```
END_GAME_LOOP:
  1. Present end-game menu
  2. Wait for selection
  3. IF "View stats":
       - Display stats block
       - GOTO step 1
  4. IF "Game analysis":
       - Display analysis block
       - GOTO step 1
  5. IF "Play again":
       - Reset state (see Reset Procedure)
       - Begin new game (Phase 1)
       - EXIT loop
  6. IF "Replay from moment":
       - Present key moments sub-menu
       - IF moment selected:
           - Restore checkpoint
           - Resume from that node (Phase 2)
           - EXIT loop
       - IF "Back to menu":
           - GOTO step 1
```

### Loop Characteristics

- **View Stats** and **Game Analysis** return to menu (informational)
- **Play Again** and **Replay from Moment** exit loop (action)
- Player can view stats/analysis multiple times before deciding
- Loop terminates only on explicit game restart

---

## Integration with Other Systems

### Connection to Export Modes

> **Reference:** See `export.md` for export framework.

End-game analysis data feeds into export modes:
- **Stats mode** (`--mode=stats`) uses same trait/relationship data
- **Summary mode** (`--mode=summary`) uses journey timeline
- **Branches mode** (`--mode=branches`) uses checkpoint data

### Connection to Presentation

> **Reference:** See `../gameplay/presentation.md` for display formatting.

- All output uses 70-character width
- ASCII box characters match presentation conventions
- Counter notation (`T6.2.3`) follows compact format spec

### Connection to Save Files

> **Reference:** See `../formats/savegame-format.md` for save format.

- `beat_log` stored in save files enables post-session analysis
- Checkpoints are memory-only (not persisted to saves)
- Final state snapshot written on game over

### Connection to Decision Grid

> **Reference:** See `../core/core.md` for grid theory.

Grid coverage tracking maps each choice to its cell:
- Scripted choices: Use `cell` field from option
- Improvised actions: Map via feasibility (see `../gameplay/improvisation.md`)
- Coverage tiers reflect completeness of exploration
