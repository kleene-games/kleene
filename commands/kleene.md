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

If action is provided, parse to determine intent:

### Play Actions
Keywords: "play", "start", "continue", "load", "resume", "my game"

**Step 1: List available scenarios**

Use Glob to find all `.yaml` files in `${CLAUDE_PLUGIN_ROOT}/scenarios/`
Read each scenario's `name` and `description` fields to build the menu.

**Step 2: Present scenario menu**

Use AskUserQuestion with the scenarios found. Example:
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

**Step 3: Game Loop (YOU orchestrate this)**

Run this loop. YOU handle user interaction; agent handles game logic.

**State tracking** (maintain across turns in YOUR context):
- `agent_id`: Saved from Task response, used for resume
- `scenario_path`: Full path to scenario YAML (for fresh launches)
- `scenario_name`: Scenario name extracted from YAML (for resume turns)
- `game_state`: Parsed from agent's `---STATE---` output block
- `resume_failed`: Set to true when API error detected, cleared on successful fresh launch

**IMPORTANT: No file writes during gameplay.** State flows through agent output, not disk.

```
GAME_LOOP:
  1. Launch or resume agent with error recovery:

     IF first turn OR resume_failed:
       Launch FRESH agent with FULL scenario path:
       Task(subagent_type: kleene:kleene-game-runner,
            prompt: "SCENARIO: [path]\nUSER_CHOICE: [option_id]")

       Save agent_id from response for future resume
       Set resume_failed = false

     ELSE (subsequent turn, resume available):
       ATTEMPT resume with SCENARIO_NAME and current STATE:
       Task(subagent_type: kleene:kleene-game-runner,
            prompt: "SCENARIO_NAME: [name]\nUSER_CHOICE: [option_id]",
            resume: agent_id)

       The agent uses cached scenario from context - no file re-read needed.
       State is also in agent context from previous turn.

       Check response for API errors:
       - If contains "API Error" OR "unexpected tool_use_id" OR "orphaned":
         → Set resume_failed = true
         → Immediately launch FRESH agent with SCENARIO: [path]
         → Save new agent_id
         → Set resume_failed = false
         → Continue with fresh agent's response

  2. Parse agent response:
     - Everything BEFORE "---STATE---" = narrative
     - Parse the ---STATE--- block and store as game_state
     - Parse the ---CHOICES--- block for options
     - If "---GAME_OVER---" found: display ending, save state, EXIT loop

  3. **DISPLAY THE NARRATIVE** (CRITICAL - do not skip this!)
     Write the narrative text directly to the user as your response text.
     Do NOT use any tool for this - just output the text in your message.
     Example: If agent returned "You enter the dark forest...",
     you write "You enter the dark forest..." in your response.
     Include ALL formatting (═══, ───, **bold**, stats line, etc.)
     This is the story itself - the user MUST see it before making a choice.

  4. Present choices to user:
     Call AskUserQuestion with parsed options:
     {
       "questions": [
         {
           "question": "[prompt from ---CHOICES--- block]",
           "header": "Choice",
           "multiSelect": false,
           "options": [
             {
               "label": "[1-5 word action phrase]",
               "description": "[consequence or requirement]"
             }
           ]
         }
       ]
     }

     Menu Guidelines:
     - Headers: max 12 chars
     - Labels: 1-5 words, concise
     - Descriptions: action-oriented, explain what happens

  5. Map user selection back to option id

  6. Save agent_id and game_state for next turn (in YOUR context, not disk)

  7. GOTO step 1 with USER_CHOICE
```

**In-Context State Architecture**
- **First turn**: Agent receives `SCENARIO: [path]`, reads scenario, initializes state
- **Resume turns**: Agent has scenario and state in context from previous turns
- **Agent output**: Always includes `---STATE---` block with current game state
- **Main thread (YOU)**: Tracks state in context, displays narrative, calls AskUserQuestion
- **No file I/O during gameplay** - eliminates permission prompts

**State is saved to disk ONLY on:**
- Game over (`---GAME_OVER---` detected)
- User explicitly says "save" or runs `/kleene save`
- Session ends (offer to save)

This optimization avoids per-turn file writes and permission prompts.

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

**Expand Current**:
- Load existing scenario from `${CLAUDE_PLUGIN_ROOT}/scenarios/`
- Use `kleene-generate` to add branches
- Save back to same location

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

Game state is kept in memory during play. Save on game over
or with /kleene save.

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

## Workflow Examples

### Example 1: Start New Game
```
User: /kleene play

1. Check for scenario.yaml → not found
2. List available scenarios from plugin
3. Ask user which to play
4. Launch agent with SCENARIO path
5. Parse response, track state in context
6. Display narrative, present choices
7. Loop until game over
```

### Example 2: Continue Game
```
User: /kleene continue

1. Load game_state.yaml from game folder
2. Load referenced scenario
3. Launch agent with state
4. Continue game loop
```

### Example 3: Generate Scenario
```
User: /kleene generate a cyberpunk heist

1. Extract theme: "cyberpunk heist"
2. Use kleene-generate skill
3. Ask clarifying questions
4. Generate complete scenario
5. Save as scenario.yaml
6. Offer to play immediately
```

### Example 4: Analyze Scenario
```
User: /kleene analyze

1. Load scenario.yaml (or bundled scenario)
2. Use kleene-analyze skill
3. Build graph and analyze
4. Display quadrant coverage
5. Show structural issues
6. Provide recommendations
```

## Error Handling

**No game state found**:
"No saved game found. Would you like to start a new game?"

**Invalid scenario**:
"Could not load scenario. Validation errors: [list errors]"

**Unknown action**:
"I didn't understand that action. Try '/kleene help' for available commands."

## State Persistence

**During gameplay**: State flows through agent context - no file writes.

**Save points** (when game_state.yaml is written):
1. Game ends (victory/death/etc)
2. User requests save (`/kleene save`)
3. Session ends (offer to save)

This eliminates permission prompts during normal gameplay while preserving the ability to resume across sessions.
