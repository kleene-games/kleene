# Save Management

Rules for game state persistence in Kleene.

## Game Folder Convention

The current working directory is the "game folder". Saves are organized by scenario.

### Directory Structure

```
./saves/
├── dragon_quest/
│   ├── 2026-01-12_14-30-22.yaml
│   └── 2026-01-10_09-15-00.yaml
├── altered_state_nightclub/
│   └── 2026-01-11_22-45-33.yaml
└── corporate_banking/
    └── 2026-01-09_18-00-00.yaml
```

### Path Reference

| Path | Purpose |
|------|---------|
| `./saves/` | Root save directory |
| `./saves/[scenario]/` | Saves for specific scenario |
| `./saves/[scenario]/YYYY-MM-DD_HH-MM-SS.yaml` | Individual save file |

Bundled scenarios loaded from: `${CLAUDE_PLUGIN_ROOT}/scenarios/`

## State Architecture

### In-Memory State (During Gameplay)

State lives in conversation context. No file I/O between turns.

### Save Points

Save file written when:
1. Game starts (initial save created)
2. Game ends (victory/death/transcendence)
3. User requests save (`/kleene save`)
4. Session ends (offer to save)

### Session Behavior

Each gameplay session creates a new timestamped save file. The `session_timestamp` in the filename is set once at game start and reused for all saves in that session.

## Save File Format (v7)

```yaml
# Save metadata
save_version: 7
scenario: [scenario_name]
session_started: "[ISO timestamp from game start]"
last_saved: "[current ISO timestamp]"

# Game state - 3-Level Counter
current_node: [node_id]
turn: [turn_number]
scene: [scene_number]          # Current scene within turn (starts at 1)
beat: [beat_number]            # Current beat within scene (starts at 1)

# Scene metadata
scene_title: "[auto-generated or from scenario]"
scene_location: "[location when scene started]"

# Beat history for export reconstruction
beat_log:
  - turn: 6
    scene: 1
    beat: 1
    type: arrival
    action: "Kitchen arrival"
  - turn: 6
    scene: 1
    beat: 2
    type: improv
    action: "Cool room scene"
    consequences: {dignity: -1, janette: +3}
  # ... continues for all beats in session

# Character and world state
character:
  exists: [boolean]
  traits: {...}
  inventory: [...]
  flags: {...}
world:
  current_location: [location]
  time: [time]                 # Time in seconds since game start
  flags: {...}
  location_state:              # Per-location mutable state (v4)
    [location_id]:
      flags: {flag: boolean}
      properties: {name: number}

  # NEW in v5 - NPC and event tracking
  npc_locations:               # NPC position tracking
    [npc_id]: [location_id]
  scheduled_events:            # Pending events
    - event_id: [string]
      trigger_at: [number]     # Time (seconds) when event fires
      consequences: [...]
  triggered_events: [string]   # IDs of events that have fired

settings:
  improvisation_temperature: [0-10]
  gallery_mode: [boolean]
  foresight: [0-10]              # Hint specificity level
  classic_mode: [boolean]        # Hide scripted options (parser mode)
```

### Backward Compatibility

**v6 → v7:** Saves without `classic_mode` field default to:
- `classic_mode: false`

**v5 → v6:** Saves without `foresight` field default to:
- `foresight: 5`

**v4 → v5:** Saves without NPC/event fields default to:
- `npc_locations: {}`
- `scheduled_events: []`
- `triggered_events: []`

**v3 → v4:** Saves without `location_state` field default to:
- `location_state: {}`

**v2 → v3:** Saves without `scene` or `beat` fields default to:
- `scene: 1`
- `beat: 1`
- `beat_log: []`

This allows older saves to load seamlessly.

## Operations

### Creating New Saves

Use Bash with heredoc - the hook auto-approves saves/ writes:
```bash
mkdir -p ./saves/[scenario_name]
cat > ./saves/[scenario_name]/[timestamp].yaml << 'EOF'
[yaml content]
EOF
```

### Updating Existing Saves

Use Edit tool after reading the file first.

### Listing Saves

When user requests to see saves for a scenario:

1. Glob `./saves/[scenario_name]/*.yaml`
2. Read each file's metadata:
   - `last_saved` timestamp
   - `turn`, `scene`, `beat` counters
   - `current_node` ID
   - `scene_title` if available
3. Sort by `last_saved` (most recent first)
4. Present as numbered list with summary using compact notation:

```
Found 3 saved games for "The Dragon's Choice":

1. Jan 12, 2:30 PM - T12.2.3 at mountain_approach
2. Jan 10, 9:15 AM - T5.1.1 at forest_entrance
3. Jan 8, 7:00 PM - T3.1.2 at sword_taken

Which save would you like to load?
```

The `T12.2.3` notation means Turn 12, Scene 2, Beat 3.

### Loading a Save

When user selects a save to load:

1. Read the specified YAML file from `./saves/[scenario_name]/[filename].yaml`
2. Extract `scenario` field to identify which scenario definition to load
3. Load scenario definition from `${CLAUDE_PLUGIN_ROOT}/scenarios/[scenario].yaml`
4. Store the save filename in memory (continue writing to same file)
5. Resume gameplay from the saved `current_node`

## Hook Integration

The PreToolUse hook auto-approves Write and Bash operations targeting the `saves/` directory, ensuring seamless gameplay without permission prompts.
