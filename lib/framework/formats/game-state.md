# Game State Model

Complete schema for tracking game state in working memory across turns.

## GAME_STATE Structure

```yaml
GAME_STATE:
  scenario_name: string       # e.g., "dragon_quest"
  current_node: string        # Current node ID
  previous_node: string       # Previous node ID (for blocked restoration)

  # 3-Level Counter (see lib/framework/gameplay/presentation.md)
  turn: number                # Major node transitions
  scene: number               # Groupings within turn (resets on turn++)
  beat: number                # Individual moments (resets on scene++)
  scene_title: string         # Auto-generated or from scenario
  scene_location: string      # Location when scene started

  # Beat log for export reconstruction
  beat_log: [                 # Cleared on session end or export
    {turn, scene, beat, type, action, consequences}
  ]

  character:
    exists: boolean           # false = None (character ceased)
    traits: {name: value}     # courage, wisdom, luck, etc.
    inventory: [items]        # Items held
    flags: {flag: boolean}    # Character-specific flags

  world:
    current_location: string  # Location ID
    time: number              # Time in seconds since game start
    flags: {flag: boolean}    # World state flags
    location_state:           # Per-location mutable state
      [location_id]:
        flags: {flag: boolean}
        properties: {name: number}
        environment: {lighting: "dim", temperature: 20}  # Environmental conditions

    # NEW in Phase 4 (v5)
    npc_locations:            # NPC position tracking
      [npc_id]: location_id   # Maps NPC to their current location

    scheduled_events:         # Pending events
      - event_id: string
        trigger_at: number    # Time (seconds) when event fires
        consequences: [...]   # Consequences to apply

    triggered_events: [string]  # IDs of events that have fired

  settings:
    improvisation_temperature: number  # 0-10, controls narrative adaptation
                                       # 0 = verbatim, 5 = balanced, 10 = fully adaptive
    gallery_mode: boolean              # Enable meta-commentary
    foresight: number                  # 0-10, controls hint specificity
    parser_mode: boolean               # Hide scripted options (parser-style play)

  recent_history: [string]    # Last 3-5 turns for context

  # Checkpoints for replay (not persisted to disk)
  checkpoints: [              # Saved on each Turn++
    {
      turn: number,
      scene: number,
      beat: number,
      node_id: string,
      description: string,    # Human-readable moment description
      character: {...},       # Full character snapshot
      world: {...}            # Full world snapshot
    }
  ]
```

## Counter Increment Rules

| Counter | Increments When | Resets |
|---------|-----------------|--------|
| Turn | Advancing to new node via `next_node` | scene→1, beat→1 |
| Scene | Location change, time skip, 5+ beats, explicit marker | beat→1 |
| Beat | Improvised action resolves, scripted choice selected | — |

## Scene Detection Triggers

Scene++ occurs automatically when:

1. `world.current_location` differs from `scene_location`
2. Narrative contains time-skip patterns: `[Time passes]`, `[Hours later]`, `[The next morning]`
3. Beat count reaches 5+ without scene change (auto-subdivision)
4. Node has `scene_break: true` marker
