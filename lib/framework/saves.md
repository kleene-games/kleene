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

## Save File Format

```yaml
# Save metadata
save_version: 2
scenario: [scenario_name]
session_started: "[ISO timestamp from game start]"
last_saved: "[current ISO timestamp]"

# Game state
current_node: [node_id]
turn: [turn_number]
character:
  exists: [boolean]
  traits: {...}
  inventory: [...]
  flags: {...}
world:
  current_location: [location]
  time: [time]
  flags: {...}
```

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
   - `turn` number
   - `current_node` ID
3. Sort by `last_saved` (most recent first)
4. Present as numbered list with summary:

```
Found 3 saved games for "The Dragon's Choice":

1. Jan 12, 2:30 PM - Turn 12 at mountain_approach
2. Jan 10, 9:15 AM - Turn 5 at forest_entrance
3. Jan 8, 7:00 PM - Turn 3 at sword_taken

Which save would you like to load?
```

### Loading a Save

When user selects a save to load:

1. Read the specified YAML file from `./saves/[scenario_name]/[filename].yaml`
2. Extract `scenario` field to identify which scenario definition to load
3. Load scenario definition from `${CLAUDE_PLUGIN_ROOT}/scenarios/[scenario].yaml`
4. Store the save filename in memory (continue writing to same file)
5. Resume gameplay from the saved `current_node`

## Hook Integration

The PreToolUse hook auto-approves Write and Bash operations targeting the `saves/` directory, ensuring seamless gameplay without permission prompts.
