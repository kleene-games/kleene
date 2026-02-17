---
name: kleene-play
description: This skill should be used when the user asks to "play a game", "start kleene", "play dragon quest", "continue my game", "load my save", or wants to play an interactive narrative using the Kleene three-valued logic engine. Handles game state, choices, and narrative presentation.
version: 0.4.0
allowed-tools: Read, Glob, Grep, Write, Edit, AskUserQuestion, Bash
hooks:
  PreToolUse:
    - matcher: "Write|Edit"
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/auto-approve-saves.sh"
    - matcher: "Bash"
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/auto-approve-saves.sh"
---

# Kleene Play Skill

Execute interactive narrative gameplay directly in the main conversation context. State persists naturally - no serialization needed between turns.

## Architecture

This skill runs game logic **inline** (no sub-agent). Benefits:
- State persists in conversation context across turns
- Scenario loaded once, stays cached
- Zero serialization overhead
- Faster turn response (~60-70% improvement)

## Scenario Loading

> **Scenario Loading:** See `${CLAUDE_PLUGIN_ROOT}/lib/framework/scenario-file-loading/overview.md`
> **Extraction Templates:** See `${CLAUDE_PLUGIN_ROOT}/lib/framework/scenario-file-loading/extraction-templates.md`

Scenarios may be loaded in three modes.

### Standard Load (small scenarios)

For scenarios under ~20k tokens, read the entire file once and cache in context.
> **Reference:** See `${CLAUDE_PLUGIN_ROOT}/lib/framework/scenario-file-loading/standard-loading.md`

### Lazy Load (large scenarios)

> **Reference:** See `${CLAUDE_PLUGIN_ROOT}/lib/framework/scenario-file-loading/lazy-loading.md`
> for complete lazy loading protocol including cache strategy and error handling.

When the Read tool returns a token limit error, switch to lazy loading mode. This loads only the header at start, then fetches nodes on demand each turn.

### Remote Load (server-hosted scenarios)

> **Reference:** See `${CLAUDE_PLUGIN_ROOT}/lib/framework/scenario-file-loading/remote-loading.md`
> for complete HTTP API loading protocol.

When a kleene-server URL is configured and a scenario is identified by ID (not local file path), use remote loading. This fetches nodes via HTTP API — same data as lazy loading, different transport.

**Remote mode adds these calls each turn:**
- After each turn: `PUT /api/game/{session_id}/state` — sync state for web UI + persistence
- After narrative output: `PUT /api/game/{session_id}/narrative` — relay to web UI
- When a cell is hit: `POST /api/game/{session_id}/cell` — report Decision Grid coverage
- Before each turn: `GET /api/game/{session_id}/settings` — check for web UI setting changes
- Before presenting choices: `GET /api/game/{session_id}/choice` — check for web UI choice input

## Time System

> **Reference:** See `${CLAUDE_PLUGIN_ROOT}/lib/framework/gameplay/evaluation-reference.md`
> for Time Unit Constants, Travel Time Calculation, and Improvisation Time Calculation.

When a scenario includes `travel_config`, time passes automatically during:
- **Travel**: `move_to` consequences add travel time based on connection data
- **Improvisation**: Free-text actions consume time based on intent classification

Meta intents (save, help, inventory) never consume time.

## Game State Model

> **Reference:** See `${CLAUDE_PLUGIN_ROOT}/lib/framework/formats/game-state.md`
> for complete game state schema including character, world, settings, and checkpoint structures.

Track the game state in working memory across turns. The state includes:
- Scenario info and current/previous node IDs
- Turn/scene/beat counters with beat log for export
- Character state (exists, traits, inventory, flags)
- World state (location, time, flags, location_state, NPC positions, scheduled events)
- Settings (improvisation_temperature, gallery_mode, foresight, parser_mode)
- Checkpoints for replay functionality

## Narrative Presentation

> **⚠️ MANDATORY: Follow `${CLAUDE_PLUGIN_ROOT}/lib/framework/gameplay/presentation.md` EXACTLY**
>
> **ALL OUTPUT MUST BE 70 CHARACTERS WIDE — NO EXCEPTIONS.**
>
> This includes:
> - Header block ═ borders: exactly 70 ═ characters
> - Narrative text: wrap at 70 characters
> - Status lines: wrap at 70 characters
>
> Users play on small screens. Text wider than 70 chars is cut off.

### Which Header Block to display

> **MANDATORY:**  See `${CLAUDE_PLUGIN_ROOT}/lib/framework/gameplay/presentation.md` → "Header Block" for templates and examples of each header

- **Cinematic header**: Game start, location changes, major story beats
- **Normal Header**: Same location, no major narrative changes 



## Core Workflow

### Phase 1: Initialization

**If starting new game:**

1. The gateway command provides the scenario path from `registry.yaml`:
   ```
   ${CLAUDE_PLUGIN_ROOT}/scenarios/[registry.scenarios.ID.path]
   ```

   Load the scenario using the appropriate mode (see **Scenario Loading** section):
   - **Standard**: Read entire file, cache in context
   - **Lazy**: If Read returns token limit error, read first 200 lines for header, then grep for `start_node`

   If the file doesn't exist:
   - Error: "Scenario file not found at [path]. Run /kleene sync to update registry."
   - Exit skill

   Track load mode in context: `lazy_loading: true/false`

2. Initialize state in memory from scenario:
   ```yaml
   current_node: [scenario.start_node]
   previous_node: null            # No previous node at start
   turn: 1
   scene: 1
   beat: 1
   scene_title: "Opening"
   scene_location: [scenario.initial_world.current_location]
   beat_log: []
   character: [scenario.initial_character]
   world: [scenario.initial_world]
   settings:
     improvisation_temperature: 5  # Default (Balanced). See lib/framework/gameplay/improvisation.md
     gallery_mode: false
     foresight: 5                  # Default (Suggestive)
     parser_mode: false           # Default: show choices
   recent_history: []
   checkpoints: []                 # For end-game replay feature
   ```

3. **Do NOT create a save file yet.** Only save when:
   - User explicitly asks to save (`/kleene save`)
   - Reaching an ending (auto-save before exit)
   - After 5+ turns of play (checkpoint save)

4. The scenario data is now in your context - do not re-read it.

**If resuming from save:**

1. Read the specified save file from `./saves/[scenario_name]/[filename].yaml`
2. Load the referenced scenario file from `${CLAUDE_PLUGIN_ROOT}/scenarios/`
   - Use appropriate load mode (standard or lazy) based on file size
3. Store the save filename in memory (continue writing to same file)
4. Continue from saved state

### Phase 2: Game Turn

Execute this for each turn:

```
TURN:
  1. Get current node:
     - Standard mode: Access scenario.nodes[current_node] from cached scenario
     - Lazy mode: Grep for "^  {current_node}:" with -A 80, parse YAML
     - Remote mode: GET /api/scenario/{scenario_id}/node/{current_node} from server

  1a. Process elapsed_since_previous (NEW in v5):
      - If node has elapsed_since_previous:
        - Convert to seconds: amount * TIME_UNITS[unit]
        - Add to world.time
        - Check scheduled events (step 1b)

  1b. Check and process scheduled events (NEW in v5):
      - For each event in scheduled_events where trigger_at <= world.time:
        - Apply event consequences
        - Add event_id to triggered_events
        - Remove from scheduled_events
      - Process events in order (lowest trigger_at first)
      - Max cascade depth: 10 (prevent infinite loops from event chains)

  2. Check for ending:
     - If current_node is in scenario.endings → display ending, save state, GOTO End-Game Menu
     - If character.exists == false → display death ending, save state, GOTO End-Game Menu

  2a. Check node precondition (if present):
     - If current node has `precondition`:
       - Evaluate precondition against current state
       - If FAILS:
         - Display blocked message (see "Blocked Display Format" below)
         - Restore: current_node = previous node (the node we came from)
         - Do NOT increment turn counter
         - GOTO step 4 (re-present previous choices)
       - If PASSES: continue normally

  3. Display narrative (with temperature adaptation):
     - Read settings.improvisation_temperature (default: 5)
     - Collect relevant improv_* flags from character.flags
     - IF temperature > 0 AND improv_* flags exist:
       - Generate contextual framing based on temperature level
       - Weave into or prepend to narrative text
       - See lib/framework/gameplay/improvisation.md → "Improvisation Temperature"
     - Output the (possibly adapted) narrative with formatting
     - Show character stats line

  4. Evaluate available choices (with temperature adaptation):
     - For each option in node.choice.options:
       - Evaluate precondition against current state
       - If passes: add to available choices
       - If fails: EXCLUDE from choices (do not show)
     - IF temperature >= 4 AND improv_* flags exist:
       - Enrich option descriptions with improv context
       - E.g., "Attack with your sword (you recall its scarred side)"
     - IF temperature >= 7 AND improv_* flags suggest bonus action:
       - Generate at most 1 bonus option based on improv flags
       - Bonus options use soft consequences only (like free-text improv)
       - See lib/framework/gameplay/improvisation.md → "Bonus Options"

  5. Present choices via AskUserQuestion:

     **IF settings.parser_mode == true:**
     ```json
     {
       "questions": [{
         "question": "[node.choice.prompt]",
         "header": "Action",
         "multiSelect": false,
         "options": [
           {"label": "Look around", "description": "Survey your surroundings"},
           {"label": "Inventory", "description": "Check what you're carrying"},
           {"label": "Show help", "description": "See commands that might work here"}
         ]
       }]
     }
     ```

     **ELSE (parser_mode == false):**
     ```json
     {
       "questions": [{
         "question": "[node.choice.prompt]",
         "header": "Choice",
         "multiSelect": false,
         "options": [available choices + bonus option if generated]
       }]
     }
     ```

  6. Wait for user selection

  6a. IF selection doesn't match any predefined option (free-text via "Other"):
      - Classify intent (Explore/Interact/Act/Meta)
      - Check feasibility against current state
      - Generate narrative response matching scenario tone
      - Apply soft consequences only (trait ±1, add_history, improv_* flags)
      - Apply improvisation time cost (see evaluation-reference.md → "Improvisation Time Calculation")
        - After time advance: re-check scheduled events (step 1b)
      - Beat++ (log to beat_log with type: "improv", action: summary)
      - Check scene triggers: location change, time skip, beat >= 5
        - If triggered: Scene++, beat→1, update scene_title
      - Display response with consequence indicators
      - Present same choices again (step 5)
      - Do NOT advance node or turn
      - GOTO step 6

  6b. IF selected option has `next: improvise` (scripted Unknown path):
      - Execute Scripted Improvisation Flow (see below)
      - GOTO step 1 if outcome node specified, else GOTO step 5

  6c. IF selection is a generated bonus option:
      - Treat like emergent improvisation (same as 6a)
      - Generate narrative response matching scenario tone
      - Apply soft consequences only (trait ±1, add_history, improv_* flags)
      - Apply improvisation time cost (classify as 'act' intent, see evaluation-reference.md → "Improvisation Time Calculation")
        - After time advance: re-check scheduled events (step 1b)
      - Beat++ (log to beat_log with type: "bonus", action: option label)
      - Check scene triggers (same as 6a)
      - Display response with consequence indicators
      - Present same choices again (step 5) — bonus option remains available
      - Do NOT advance node or turn
      - GOTO step 6

  6d. IF selection is "Look around" (parser mode):
      > See `${CLAUDE_PLUGIN_ROOT}/lib/framework/gameplay/parser-mode.md` → "Look Around"
      - Beat++ (log to beat_log with type: "look")
      - Present choices again, do NOT advance node or turn
      - GOTO step 6

  6e. IF selection is "Inventory" (parser mode):
      > See `${CLAUDE_PLUGIN_ROOT}/lib/framework/gameplay/parser-mode.md` → "Inventory"
      - Beat++ (log to beat_log with type: "inventory")
      - Present choices again, do NOT advance node or turn
      - GOTO step 6

  6f. IF selection is "Show help" (parser mode):
      > See `${CLAUDE_PLUGIN_ROOT}/lib/framework/gameplay/parser-mode.md` → "Adaptive Help"
      - Beat++ (log to beat_log with type: "help")
      - Present choices again, do NOT advance node or turn
      - GOTO step 6

  7. Display option narrative (if present):
     - Check if selected option has a `narrative` field
     - If present: display it (plain text, no box format)
     - This is the immediate feedback to the player's choice

  8. Apply consequences of chosen option:
     - Execute each consequence type (see Consequence Application table)
     - For `move_to` consequences: apply travel time (see evaluation-reference.md → "Travel Time Calculation")
     - Update character/world state in memory
     - After all consequences: re-check scheduled events (step 1b)
       - This handles advance_time, move_to travel time, or schedule_event consequences

  9. Advance state:
     - Log current beat: beat_log.append({turn, scene, beat, type: "scripted_choice", action: option.text})
     - Set previous_node = current_node   # Save for blocked restoration
     - Set current_node = option.next_node
     - Turn++ (resets scene→1, beat→1)
     - Update scene_location = world.current_location
     - Generate scene_title from new node context
     - Add choice to recent_history (keep last 5)
     - Save checkpoint for replay:
       checkpoints.append({
         turn: [new turn number],
         scene: 1,
         beat: 1,
         node_id: current_node,
         description: [summarize the choice just made],
         character: [deep copy of character state],
         world: [deep copy of world state]
       })

  9a. Remote mode sync (if remote loading):
      - PUT /api/game/{session_id}/state with full game state
      - PUT /api/game/{session_id}/narrative with rendered narrative text
      - If a cell was hit: POST /api/game/{session_id}/cell
      - GET /api/game/{session_id}/settings to check for web UI changes
      - GET /api/game/{session_id}/choice to check for web UI choice input

  10. GOTO step 1 (next turn)
```

### Phase 3: Persistence

> **Reference:** See `${CLAUDE_PLUGIN_ROOT}/lib/framework/formats/savegame-format.md` for save format, file creation, and operations.

Save to disk when:
- Game ends (victory, death, transcendence)
- User explicitly requests save
- Session is ending

#### Save Metadata Caching

When saving game state, cache node metadata for rich save listings:

**If yaml_tool=yq:**
```bash
yq '.nodes.CURRENT_NODE | {"title": (.title // ("Node: " + "CURRENT_NODE")), "preview": (.narrative | split("\n") | map(select(. != "")) | .[0])}' scenario.yaml
```

Add to save file:
```yaml
current_node_title: "Village Crossroads"      # From .title or generated
current_node_preview: "The village elder..."   # First line of narrative
```

**If yaml_tool=grep:** Skip metadata caching (graceful degradation).

Old saves without cached metadata load normally - the metadata is optional and only used for richer save listings.

The PreToolUse hook auto-approves saves/ writes for seamless gameplay.

## Precondition & Consequence Evaluation

> **Reference:** See `${CLAUDE_PLUGIN_ROOT}/lib/framework/gameplay/evaluation-reference.md` for precondition evaluation and consequence application tables.
> **Schema Reference:** See `${CLAUDE_PLUGIN_ROOT}/lib/framework/formats/scenario-format.md` for all types and YAML syntax.

### Location Access Validation

> **Reference:** See `${CLAUDE_PLUGIN_ROOT}/lib/framework/gameplay/evaluation-reference.md`
> for location access validation, blocked display formatting, and fallback message generation.

When a location has a `precondition`, evaluate it and apply the configured `access_mode`.

## Improvised Action Handling

> **Reference:** See `${CLAUDE_PLUGIN_ROOT}/lib/framework/gameplay/improvisation.md` for complete handling rules.

When a player selects "Other" and provides free-text input:

1. Classify intent (Explore/Interact/Act/Meta)
2. Check feasibility against current state (Possible/Blocked/Impossible)
3. Generate narrative response matching scenario tone
4. Apply soft consequences only (trait +/-1, add_history, improv_* flags)
5. Display response with bold box format (generate creative title)
6. Present same choices again - do NOT advance node or turn

Soft consequences preserve scenario balance while rewarding exploration.

### Compound Command Resolution

> **Reference:** See `${CLAUDE_PLUGIN_ROOT}/lib/framework/gameplay/improvisation.md` → "Compound Command Resolution"

Multi-step natural language input (e.g., "go to the tree, climb it, get the egg") can be resolved across multiple nodes in a single interaction with batched validation and cohesive narrative output.

### Hint Generation (Foresight-Gated)

> **Reference:** See `${CLAUDE_PLUGIN_ROOT}/lib/framework/gameplay/improvisation.md` → "Hint Generation (Foresight-Gated)"

When player asks for help/hints, generate responses gated by `settings.foresight` (0-10). Hints should reference actual scenario content, not generic advice. Present same choices again after hint (no node advance).

## Scripted Improvisation Flow

> **Reference:** See `${CLAUDE_PLUGIN_ROOT}/lib/framework/gameplay/scripted-improvisation.md`
> for complete scripted improvisation protocol including grid cell classification, pattern matching, and outcome node handling.

When a player selects an option with `next: improvise`, execute the special flow for the Unknown row of the Decision Grid. This involves presenting a sub-prompt, classifying the response to Discovery/Constraint/Limbo, generating appropriate narrative, and determining whether to advance to an outcome node or stay at the current node.





## Choice Presentation

Use AskUserQuestion per conventions in `${CLAUDE_PLUGIN_ROOT}/lib/framework/gameplay/presentation.md`.

**Silent Precondition Filtering**: Options failing preconditions are
removed BEFORE presenting choices. Never show "locked" or "requires X"
indicators. The character simply doesn't think of impossible actions.
This maintains immersion — if you can't do it, you don't see it.

```json
{
  "questions": [{
    "question": "The dragon awaits. What do you do?",
    "header": "Choice",
    "multiSelect": false,
    "options": [
      {"label": "Fight", "description": "Attack with your sword"},
      {"label": "Negotiate", "description": "Attempt to speak with the dragon"},
      {"label": "Flee", "description": "Retreat to safety"}
    ]
  }]
}
```

## Ending Detection

Check for endings:
1. current_node is in scenario.endings
2. character.exists == false
3. No available choices (dead end - shouldn't happen in well-designed scenarios)

**Display ending with appropriate tone** See `${CLAUDE_PLUGIN_ROOT}/lib/framework/core/endings.md` 

## End-Game Menu

> **Reference:** See `${CLAUDE_PLUGIN_ROOT}/lib/framework/post-gameplay/end-game-menu.md`
> for complete end-game menu system, statistics display, game analysis,
> and replay functionality.

Present the end-game menu following the framework document. The menu
offers four options:
- **View stats** — Final traits, relationships, inventory
- **Game analysis** — Timeline, key decisions, paths not taken
- **Play again** — Reset and restart from Turn 1
- **Replay from moment** — Return to a key decision checkpoint

The menu loops until player selects an action that restarts gameplay.

## Additional Resources

### Core
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/core/core.md`** - Option type semantics, Decision Grid theory
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/core/endings.md`** - Ending classification, flavor system

### Formats
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/formats/scenario-format.md`** - YAML specification, preconditions, consequences
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/formats/savegame-format.md`** - Game folder, save format, persistence rules
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/formats/registry-format.md`** - Scenario registry format
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/formats/game-state.md`** - Game state schema, counters, checkpoints

### Gameplay
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/gameplay/presentation.md`** - Header, trait, and choice formatting
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/gameplay/improvisation.md`** - Free-text action handling, compound commands, hints
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/gameplay/parser-mode.md`** - Parser-style interface behaviors
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/gameplay/choice-mode.md`** - Default choice-based interface mode
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/gameplay/gallery-mode.md`** - Meta-commentary system for replays
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/gameplay/evaluation-reference.md`** - Precondition/consequence tables

### Post-Gameplay
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/post-gameplay/overview.md`** - Post-gameplay system architecture
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/post-gameplay/export.md`** - End-game transcript/summary generation

### Scenarios
- **`${CLAUDE_PLUGIN_ROOT}/scenarios/`** - Bundled scenarios
