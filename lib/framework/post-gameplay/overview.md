# Post-Gameplay Systems

After a game ends, two systems handle player reflection and archival.

## Interactive: End-Game Menu

Presented immediately after reaching an ending. Loops until player restarts.

| Option | Purpose |
|--------|---------|
| View stats | Display final traits, relationships, inventory |
| Game analysis | Timeline, key decisions, paths not taken |
| Play again | Reset and restart from Turn 1 |
| Replay moment | Return to a checkpoint |

> **Details:** See `end-game-menu.md`

## File Export: /kleene export

Generates files for archival or sharing. Triggered via command, not menu.

| Mode | Output |
|------|--------|
| transcript | Clean narrative log (default) |
| summary | Analysis with gallery notes |
| stats | Numbers only |
| branches | Split by timeline |
| gallery | Commentary only |

> **Details:** See `export.md`

## Shared Data

Both systems use:
- `beat_log`: Turn/scene/beat entries for timeline reconstruction
- `checkpoints`: State snapshots for replay/branch analysis
- Character/world state: Final values vs initial for delta display
