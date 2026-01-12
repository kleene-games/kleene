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
Keywords: "play", "start", "continue", "load", "resume", "my game"

**Step 1: Check for saved game**

Check if `game_state.yaml` exists in current directory. If yes, ask if user wants to continue or start fresh.

**Step 2: List available scenarios**

Use Glob to find all `.yaml` files in `${CLAUDE_PLUGIN_ROOT}/scenarios/`
Read each scenario's `name` and `description` fields to build the menu.

**Step 3: Present scenario menu**

Use AskUserQuestion with the scenarios found:
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
          "label": "The Velvet Chamber",
          "description": "Unravel a nightclub mystery"
        }
      ]
    }
  ]
}
```

**Step 4: Start game loop**

Once scenario is selected, the `kleene-play` skill takes over. The skill:
- Loads the scenario YAML once
- Initializes state from scenario
- Runs the game loop directly in this conversation
- State persists naturally (no serialization between turns)
- Saves to disk only on game over or explicit save

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

### Help Actions
Keywords: "help", "how", "what", "?"

Display quick reference:

```
═══════════════════════════════════════════════════════════
KLEENE - Three-Valued Narrative Engine
═══════════════════════════════════════════════════════════

PLAY
  /kleene play                    Start or continue a game
  /kleene play dragon_quest       Play specific scenario
  /kleene continue                Resume saved game

GENERATE
  /kleene generate [theme]        Create new scenario
  /kleene generate haunted house  Example with theme
  /kleene expand                  Add to current scenario

ANALYZE
  /kleene analyze                 Check current scenario
  /kleene analyze dragon_quest    Analyze specific scenario

SAVE
  /kleene save                    Save current game to disk

Game state persists in conversation during play.
Saved automatically on game over.

═══════════════════════════════════════════════════════════
```

## Game Folder Convention

The current working directory is the "game folder". Files used:

| File | Purpose |
|------|---------|
| `game_state.yaml` | Saved game state (written on game over or explicit save) |
| `scenario.yaml` | Custom scenario (optional) |

If no local `scenario.yaml` exists, use bundled scenarios from:
`${CLAUDE_PLUGIN_ROOT}/scenarios/`

## State Architecture

**During gameplay**: State lives in conversation context. No file I/O between turns.

**Save points** (when `game_state.yaml` is written):
1. Game ends (victory/death/transcendence)
2. User requests save (`/kleene save`)
3. Session ends (offer to save)

This eliminates permission prompts during normal gameplay while preserving the ability to resume across sessions.

## Error Handling

**No game state found**:
"No saved game found. Would you like to start a new game?"

**Invalid scenario**:
"Could not load scenario. Validation errors: [list errors]"

**Unknown action**:
"I didn't understand that action. Try '/kleene help' for available commands."
