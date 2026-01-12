---
name: kleene
description: "Unified entry point for Kleene narrative engine - play games, generate scenarios, analyze structure"
arguments:
  - name: action
    description: "Optional: 'play', 'generate', 'analyze'. If omitted, show menu."
    required: false
---

# Kleene Gateway Command

**SILENT MODE**: Do NOT narrate your actions. No "Let me...", "Now I'll...", "Perfect!". Just use tools and present results. Be terse.

## If no action provided, show menu FIRST

Use AskUserQuestion to present options:

```json
{
  "questions": [
    {
      "question": "Welcome to Kleene! What would you like to do?",
      "header": "Kleene",
      "multiSelect": false,
      "options": [
        {
          "label": "Play a game",
          "description": "Start fresh or resume your saved progress"
        },
        {
          "label": "Generate scenario",
          "description": "Create new narrative from a theme you choose"
        },
        {
          "label": "Analyze scenario",
          "description": "Check completeness and find structural issues"
        },
        {
          "label": "Help",
          "description": "View commands and learn how Kleene works"
        }
      ]
    }
  ]
}
```

Then route based on selection.

## Action Routing

Parse the action to determine intent:

### Play Actions
Keywords: "play", "start", "continue", "load", "resume", "my game", "list saves"

**Step 1: Determine game mode**

Parse user intent:
- `play [scenario]` → New game (default)
- `continue [scenario]` or `resume [scenario]` → List saves for that scenario
- `list saves [scenario]` → Show available saves without starting

**Step 2: For new games**

1. **Load the registry:**
   - Read `${CLAUDE_PLUGIN_ROOT}/scenarios/registry.yaml`
   - If registry doesn't exist, perform auto-sync first (see Registry Actions below)

2. **Check for unregistered scenarios:**
   - Glob `${CLAUDE_PLUGIN_ROOT}/scenarios/*.yaml`
   - Exclude `registry.yaml` from results
   - Compare against registry paths
   - Track any files not in registry as "unregistered"

3. **Build scenario menu:**
   - Include all enabled scenarios from registry
   - Add unregistered scenarios with `[new]` indicator
   - Add missing scenarios with `[missing]` warning (file not found)
   - Skip disabled scenarios

4. Present scenario menu via AskUserQuestion:

```json
{
  "questions": [
    {
      "question": "Which scenario would you like to play?",
      "header": "Scenario",
      "multiSelect": false,
      "options": [
        {
          "label": "The Dragon's Choice",
          "description": "Face the dragon and choose your fate"
        },
        {
          "label": "My New Scenario [new]",
          "description": "Unregistered - will be added to registry"
        }
      ]
    }
  ]
}
```

5. **On selection:**
   - If unregistered: auto-register (extract metadata, add to registry), then load
   - If missing: warn user, offer to run `/kleene sync` to clean up registry
   - Otherwise: load scenario using path from registry

6. **Load scenario (handle large files):**

   Attempt to read the scenario file:
   ```
   Read: ${CLAUDE_PLUGIN_ROOT}/scenarios/[path]
   ```

   If Read succeeds: standard mode (full scenario cached)

   If Read returns **token limit error** (file too large):
   - Switch to **lazy loading mode**
   - Read first 200 lines only: `Read with limit: 200`
   - Extract header: `initial_character`, `initial_world`, `endings`
   - Grep for start node: `Grep "^  {start_node}:" -A 80`
   - Set context flag: `lazy_loading: true`

   The `kleene-play` skill will use this flag to load nodes on demand.

7. The `kleene-play` skill:
   - Creates `./saves/[scenario_name]/` directory if needed
   - Generates timestamped save file: `YYYY-MM-DD_HH-MM-SS.yaml`
   - Initializes fresh state and writes initial save
   - Runs the game loop

**Step 3: For continue/resume**

1. Check if `./saves/[scenario_name]/` directory exists
2. If no saves found: "No saved games found for [scenario]. Starting new game."
3. If saves found, list them via AskUserQuestion:

```json
{
  "questions": [
    {
      "question": "Found 3 saved games for 'The Dragon's Choice':",
      "header": "Load Save",
      "multiSelect": false,
      "options": [
        {
          "label": "Jan 12, 2:30 PM",
          "description": "Turn 12 at mountain_approach"
        },
        {
          "label": "Jan 10, 9:15 AM",
          "description": "Turn 5 at forest_entrance"
        },
        {
          "label": "Start new game",
          "description": "Begin fresh playthrough"
        }
      ]
    }
  ]
}
```

4. Load selected save and resume gameplay

### Generate Actions
Keywords: "generate", "create", "make", "new scenario", "new quest", "about"

**Step 1: Get theme**

If no theme provided, use AskUserQuestion:

```json
{
  "questions": [
    {
      "question": "What theme would you like for your scenario?",
      "header": "Theme",
      "multiSelect": false,
      "options": [
        {
          "label": "Haunted mansion",
          "description": "Explore a decrepit estate filled with mystery and horror"
        },
        {
          "label": "Space station",
          "description": "Survive and explore in a sci-fi setting"
        },
        {
          "label": "Medieval kingdom",
          "description": "Navigate politics, war, and courtly intrigue"
        }
      ]
    }
  ]
}
```

Note: The "Other" option is automatically added by AskUserQuestion.

**Step 2: Generate scenario**

Use `kleene-generate` skill to create complete scenario YAML.

**Step 3: Name and save**

Ask for a filename, then save to: `${CLAUDE_PLUGIN_ROOT}/scenarios/[name].yaml`

This makes the scenario available in the Play menu for all future sessions.

### Analyze Actions
Keywords: "analyze", "check", "validate", "coverage", "structure", "paths"

**Analyze Scenario**:
- Load scenario from current directory or bundled scenarios
- Use `kleene-analyze` skill
- Display comprehensive report

### Registry Actions
Keywords: "sync", "registry", "enable", "disable", "list scenarios"

**Sync Registry** (`/kleene sync`):
1. Read existing `${CLAUDE_PLUGIN_ROOT}/scenarios/registry.yaml` (or create empty structure if missing)
2. Glob all `.yaml` files in `scenarios/` (excluding `registry.yaml`)
3. For each scenario file found:
   - If already in registry and file exists: validate metadata is current
   - If in registry but file missing: set `missing: true`
   - If not in registry: extract metadata, add with `tags: ["discovered"]`
4. Extract metadata using priority order:
   - Name: `name` → `title` → `metadata.title` → filename
   - Description: `description` → `metadata.description` → "No description"
5. Update `last_synced` timestamp to current ISO datetime
6. Write updated `registry.yaml`
7. Report changes:
```
Registry synced:
  Added: 2 scenarios
  Removed: 1 missing entry
  Updated: 0 scenarios
```

**Registry Status** (`/kleene registry`):
Display summary of registry state:
```
Kleene Scenario Registry
Last synced: 2026-01-12 14:30

Registered scenarios: 4
  - The Dragon's Choice (dragon_quest) [enabled]
  - The Velvet Chamber (altered_state_nightclub) [enabled]
  - Corporate Banking (corporate_banking) [disabled]
  - Old Scenario (old_scenario) [missing]

Unregistered files: 1
  - new_scenario.yaml
```

**Enable Scenario** (`/kleene enable [scenario]`):
1. Load registry
2. Find scenario by ID or name (fuzzy match)
3. Set `enabled: true`
4. Write registry
5. Confirm: "Enabled 'The Dragon's Choice'"

**Disable Scenario** (`/kleene disable [scenario]`):
1. Load registry
2. Find scenario by ID or name (fuzzy match)
3. Set `enabled: false`
4. Write registry
5. Confirm: "Disabled 'Corporate Banking' - will not appear in play menu"

### Help Actions
Keywords: "help", "how", "what", "?"

Display quick reference:

```
═══════════════════════════════════════════════════════════
KLEENE - Three-Valued Narrative Engine
═══════════════════════════════════════════════════════════

PLAY
  /kleene play                    Start a new game (shows scenario menu)
  /kleene play dragon_quest       New game of specific scenario

SAVES
  /kleene continue [scenario]     List and load saves for scenario
  /kleene list saves [scenario]   Show all saves for a scenario
  /kleene save                    Save current game to disk

GENERATE
  /kleene generate [theme]        Create new scenario
  /kleene generate haunted house  Example with theme
  /kleene expand                  Add to current scenario

ANALYZE
  /kleene analyze                 Check current scenario
  /kleene analyze dragon_quest    Analyze specific scenario

REGISTRY
  /kleene sync                    Sync registry with scenarios folder
  /kleene registry                Show registry status
  /kleene enable [scenario]       Enable a disabled scenario
  /kleene disable [scenario]      Hide scenario from play menu

Saves: ./saves/[scenario]/[timestamp].yaml
Registry: scenarios/registry.yaml

═══════════════════════════════════════════════════════════
```

## Game Folder Convention

The current working directory is the "game folder". Saves are organized by scenario:

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

| Path | Purpose |
|------|---------|
| `./saves/` | Root save directory |
| `./saves/[scenario]/` | Saves for specific scenario |
| `./saves/[scenario]/YYYY-MM-DD_HH-MM-SS.yaml` | Individual save file |

Bundled scenarios loaded from: `${CLAUDE_PLUGIN_ROOT}/scenarios/`

## State Architecture

**During gameplay**: State lives in conversation context. No file I/O between turns.

**Save points** (when save file is written):
1. Game starts (initial save created)
2. Game ends (victory/death/transcendence)
3. User requests save (`/kleene save`)
4. Session ends (offer to save)

Each gameplay session creates a new timestamped save file. Subsequent saves in the same session update that file.

## Error Handling

**No saves found for scenario**:
"No saved games found for [scenario]. Starting new game."

**Invalid scenario**:
"Could not load scenario. Validation errors: [list errors]"

**Large scenario (token limit)**:
Automatically switch to lazy loading mode. No error shown to user - this is transparent.

**Unknown action**:
"I didn't understand that action. Try '/kleene help' for available commands."
