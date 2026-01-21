---
name: kleene
description: "Unified entry point for Kleene narrative engine - play games, generate scenarios, analyze structure"
arguments:
  - name: action
    description: "Optional: 'play', 'generate', 'analyze'. If omitted, show menu."
    required: false
---

# Kleene Gateway Command

> **Tool Detection:** See `lib/patterns/tool-detection.md` for yq availability check.
> **Templates:** See `lib/patterns/yaml-extraction.md` for all extraction patterns.

**SILENT MODE**: Do NOT narrate your actions. No "Let me...", "Now I'll...", "Perfect!". Just use tools and present results. Be terse.

## Tool Detection (at session start)

Detect yq availability once per session:

```bash
command -v yq >/dev/null 2>&1 && yq --version 2>&1 | head -1
```

Set `yaml_tool: yq` if output contains "mikefarah/yq" and version >= 4, otherwise `yaml_tool: grep`.

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

   **If yaml_tool=yq (efficient extraction):**
   ```bash
   yq '.scenarios | to_entries | .[] | select(.value.enabled) | {"id": .key, "name": .value.name, "description": .value.description, "path": .value.path}' registry.yaml
   ```

   **If yaml_tool=grep:**
   - Read `${CLAUDE_PLUGIN_ROOT}/scenarios/registry.yaml`

   If registry doesn't exist, perform auto-sync first (see Registry Actions below)

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

   **Include tier badges if stats are cached:**
   - `[Bronze]`, `[Silver]`, `[Gold]` based on stats.tier
   - Show node count for complexity: "18 nodes"

```json
{
  "questions": [
    {
      "question": "Which scenario would you like to play?",
      "header": "Scenario",
      "multiSelect": false,
      "options": [
        {
          "label": "The Dragon's Choice [Silver]",
          "description": "Face the dragon and choose your fate (17 nodes)"
        },
        {
          "label": "The Velvet Chamber [Gold]",
          "description": "Explore a surreal nightclub mystery (24 nodes)"
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

   If scenario has no cached stats, omit the tier badge and node count.

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
3. **Extract save metadata:**

   **If yaml_tool=yq (efficient extraction):**
   ```bash
   for f in ./saves/SCENARIO/*.yaml; do
     yq --arg file "$f" '{"file": $file, "turn": .turn, "node": .current_node, "saved": .last_saved, "title": .current_node_title, "preview": .current_node_preview}' "$f"
   done
   ```

   **If yaml_tool=grep:** Read each save file fully.

   If save has `current_node_title` and `current_node_preview` (cached metadata), use them for rich display. Otherwise, just show turn and node ID.

4. If saves found, list them via AskUserQuestion:

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
4. **Extract metadata:**

   **If yaml_tool=yq (efficient extraction):**
   ```bash
   yq '{"name": .name, "description": .description}' scenario.yaml
   ```

   **If yaml_tool=grep:** Read file and parse name/description manually.

   Priority order:
   - Name: `name` → `title` → `metadata.title` → filename
   - Description: `description` → `metadata.description` → "No description"

5. **Extract stats (if yaml_tool=yq):**
   ```bash
   yq '{"node_count": (.nodes | length), "ending_count": (.endings | length), "cells": [.nodes[].choice.options[] | select(.cell) | .cell] | unique}' scenario.yaml
   ```

   Calculate tier from cells:
   - **Bronze**: Has chooses + avoids cells (4 corners)
   - **Silver**: Bronze + unknown cells
   - **Gold**: Full grid coverage

   Store in registry as `stats` field (see Phase 5 below).

6. Update `last_synced` timestamp to current ISO datetime
7. Write updated `registry.yaml`
8. Report changes:
```
Registry synced:
  Added: 2 scenarios
  Removed: 1 missing entry
  Updated: 0 scenarios
  Stats cached: 3 scenarios
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

### Temperature Actions
Keywords: "temperature", "temp", "improv", "adaptation"

**Set Temperature** (`/kleene temperature [0-10]`):
1. Parse temperature value (0-10)
2. Update `settings.improvisation_temperature` in current game state
3. Confirm: "Improvisation temperature set to [N]"

If no value provided, show current setting and explain scale:
```
Current improvisation temperature: 0 (Verbatim)

Scale:
  0     Verbatim    - Scenario text exactly as written (default)
  1-3   Subtle      - Faint echoes of discoveries
  4-6   Balanced    - Direct references woven in
  7-9   Immersive   - Rich integration + bonus options
  10    Adaptive    - Narrative shaped by exploration

Use: /kleene temperature [0-10]
```

**Note:** Temperature only applies during active gameplay. The setting is saved with game state and persists across sessions.

### Gallery Actions
Keywords: "gallery", "meta", "commentary", "analysis"

**Toggle Gallery Mode** (`/kleene gallery [on|off]`):
1. Parse on/off value (or toggle if not provided)
2. Update `settings.gallery_mode` in current game state
3. Confirm with explanation

If no value provided, show current setting and explain:
```
Gallery mode: OFF

When ON, includes meta-commentary alongside narrative — like the
analysis cards at art galleries. Explains psychological dynamics,
narrative structure, and why consequences trigger.

When OFF (default), pure immersive narrative only.

Use: /kleene gallery on
     /kleene gallery off
```

**Note:** Gallery mode only applies during active gameplay. The setting is saved with game state and persists across sessions.

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

**Note:** Foresight only applies during active gameplay when players ask questions like "where is the treasure?" or "what should I do?". The setting is saved with game state.

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

### Rewind Actions
Keywords: "rewind", "go back", "restore", "undo"

**Rewind to Position** (`/kleene rewind [target]`):

Supports 3-level targeting with Turn.Scene.Beat notation:

| Target | Meaning |
|--------|---------|
| `6` | Turn 6, Scene 1, Beat 1 |
| `6.2` | Turn 6, Scene 2, Beat 1 |
| `6.2.3` | Turn 6, Scene 2, Beat 3 |
| `T6.2.3` | Same (explicit T prefix) |
| `-1` | Back 1 beat |
| `--1` | Back 1 scene |

**Process:**
1. Parse target to identify turn/scene/beat
2. Restore exact numeric values (all traits and relationships)
3. Restore turn, scene, beat counters
4. Restore narrative context (location, recent events)
5. Continue seamlessly without "loading..." meta-commentary
6. Present the choice menu from that point

The narrative simply returns to that moment as if it always was.

If no target specified, show recent history:
```
Recent history:
  T6.2.3  Tim confrontation on street
  T6.2.2  Walk publicly (Dignity +2)
  T6.2.1  Dish washing
  T6.1.3  Intimacy [time passes] (Janette +5)
  T6.1.2  Cool room scene (Dignity -1)
  T6.1.1  Kitchen arrival

Use: /kleene rewind 6.2.1
```

### Export Actions
Keywords: "export", "transcript", "save story", "save journey", "summary", "stats"

> **Reference:** See `lib/framework/gameplay/export.md` for complete format specifications.

**Export Modes:**

| Mode | Command | Description |
|------|---------|-------------|
| **Transcript** | `/kleene export` | Clean narrative log (default) |
| **Summary** | `/kleene export --mode=summary` | Analysis with gallery notes |
| **Stats** | `/kleene export --mode=stats` | Numbers only |
| **Branches** | `/kleene export --mode=branches` | Split by timeline |
| **Gallery** | `/kleene export --mode=gallery` | Commentary only |

**Options:**
```
--format=md|json|html    Output format (default: md)
--split-branches         Separate file per branch
--output=filename.md     Specific output file
--dir=./path/            Output directory
```

**Process (all modes):**
1. Collect session content from conversation context
2. Filter out technical artifacts (Bash, yq, Read, etc.)
3. Extract relevant content based on mode
4. Format and write to `./exports/[scenario]_[date].md`

**Example:**
```
/kleene export                      # transcript to default location
/kleene export --mode=summary       # full analysis
/kleene export --mode=stats         # just numbers
/kleene export --split-branches     # one file per timeline
```

If no active game:
"No active game to export. Start a game with /kleene play first."

### Help Actions
Keywords: "help", "how", "what", "?"

Display quick reference:

```
═══════════════════════════════════════════════════════════
KLEENE - AI Narrative Engine
═══════════════════════════════════════════════════════════

PLAY
  /kleene play                    Start a new game (shows scenario menu)
  /kleene play dragon_quest       New game of specific scenario

SAVES
  /kleene continue [scenario]     List and load saves for scenario
  /kleene list saves [scenario]   Show all saves for a scenario
  /kleene save                    Save current game to disk
  /kleene rewind [target]         Restore to earlier position:
                                    6       Turn 6, Scene 1, Beat 1
                                    6.2     Turn 6, Scene 2, Beat 1
                                    6.2.3   Turn 6, Scene 2, Beat 3
                                    -1      Back 1 beat
                                    --1     Back 1 scene

EXPORT
  /kleene export                  Export as clean transcript (default)
  /kleene export --mode=summary   Export with analysis & gallery notes
  /kleene export --mode=stats     Export numbers only
  /kleene export --mode=branches  Split export by timeline
  /kleene export --granularity=beat  Export with beat-level detail

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

SETTINGS
  /kleene temperature             Show current improvisation temperature
  /kleene temperature [0-10]      Set adaptation level:
                                    0 = Verbatim (script only)
                                    5 = Balanced (default)
                                   10 = Fully adaptive
  /kleene gallery                 Show gallery mode status
  /kleene gallery [on|off]        Toggle meta-commentary
  /kleene foresight               Show current foresight level
  /kleene foresight [0-10]        Set hint specificity:
                                    0 = Blind (no hints)
                                    5 = Suggestive (default)
                                   10 = Oracle (full walkthrough)
  /kleene classic                 Show classic mode status
  /kleene classic [on|off]        Toggle text adventure mode:
                                    on = Type commands (Zork-style)
                                    off = Show choice menu (default)

DURING GAMEPLAY
  Select "Other" or type freely   Improvise beyond scripted choices
  Your actions shape the story    Explore, interact, experiment!

PROGRESS TRACKING
  Headers show: Turn N · Scene S · Beat B
  Compact notation: T6.2.3 = Turn 6, Scene 2, Beat 3
  Use this notation with /kleene rewind

Saves: ./saves/[scenario]/[timestamp].yaml

═══════════════════════════════════════════════════════════
```

## Persistence

> **Reference:** See `lib/framework/formats/saves.md` for game folder conventions, save format, and persistence rules.

Saves are stored at `./saves/[scenario]/[timestamp].yaml` in the game folder.
Bundled scenarios loaded from: `${CLAUDE_PLUGIN_ROOT}/scenarios/`

## Error Handling

**No saves found for scenario**:
"No saved games found for [scenario]. Starting new game."

**Invalid scenario**:
"Could not load scenario. Validation errors: [list errors]"

**Large scenario (token limit)**:
Automatically switch to lazy loading mode. No error shown to user - this is transparent.

**Unknown action**:
"I didn't understand that action. Try '/kleene help' for available commands."
