# Kleene Server: LLM Game Engine Integration

## Context

The kleene-server and kleene-web are built and working. The server loads YAML scenarios, extracts nodes on demand, and manages game sessions. The web frontend has narrative display, choice buttons, settings controls (temperature/gallery/foresight/parser mode), stats, inventory, Decision Grid, and free-text input. **The web frontend IS the game interface.**

The missing piece: **the server needs to proxy game turns through a persistent Claude session**, following the [claude-search-proxy](https://github.com/LePetitPince/claude-search-proxy) pattern. Instead of servicing search queries, the persistent Claude session services Kleene game turns — evaluating preconditions, applying consequences, generating narrative, and presenting choices.

## Architecture

```
Browser (kleene-web) ←→ JSON API ←→ kleene-server ←→ Anthropic Claude API
                                          ↕
                                    Scenario YAML
```

**Per-turn flow:**
1. Player clicks a choice (or types free text) in the browser
2. Web frontend → `POST /api/game/{session_id}/turn` → server
3. Server fetches the current node + all its paths from YAML
4. Server sends to Claude: player's choice + current node data + settings
5. Claude (in persistent session with full game context) processes the turn
6. Claude returns: narrative, available choices, state updates, cell type, ending info
7. Server extracts structured response, updates session state
8. Server → returns turn result → web frontend
9. Web frontend displays narrative, renders choices, updates stats/grid

**The persistent Claude session maintains** (in its conversation context, just as kleene-play does now):
- Game rules (system prompt, adapted from SKILL.md)
- Scenario header + initial state
- Full turn history (node data received, decisions made, consequences applied)
- Running game state (traits, inventory, flags, location, turn counters)

## Changes Required

### 1. New: `kleene_server/llm/__init__.py`

Empty init.

### 2. New: `kleene_server/llm/engine.py` — Game Engine (core change)

Wraps the Anthropic Python SDK. Manages one persistent Claude conversation per game session.

```python
class GameEngine:
    def __init__(self, api_key: str, model: str = "claude-sonnet-4-5-20250929"):
        self.client = anthropic.Anthropic(api_key=api_key)
        self.model = model
        self.sessions: dict[str, list[dict]] = {}  # session_id → message history

    def start_game(self, session_id, system_prompt, scenario_header, start_node) -> dict:
        """Initialize a persistent session. Send first message with scenario + start node."""
        # Build initial user message with scenario header + start node data
        # Call Claude API → get initial narrative + choices
        # Store message history
        # Return structured turn result

    def process_turn(self, session_id, player_choice, current_node_data, settings) -> dict:
        """Process one game turn in the persistent session."""
        # Build user message: choice + current node + settings
        # Call Claude API with full message history
        # Parse response (tool_use or structured JSON)
        # Append to message history
        # Return structured turn result

    def _build_user_message(self, choice, node_data, settings) -> str:
        """Format the user message for a turn."""

    def _parse_response(self, response) -> dict:
        """Extract narrative, choices, state, cell_type, ending from Claude's response."""
```

**Response format**: Claude uses a `present_turn` tool (forced via `tool_choice`) to return structured data:
```json
{
  "narrative": "The village elder grips your arm...",
  "choices": {
    "prompt": "What do you do?",
    "options": [
      {"id": "seek_knowledge", "text": "Enter the dark forest", "description": "..."}
    ]
  },
  "state": {
    "turn": 2, "scene": 1, "beat": 1,
    "current_node": "forest_entrance",
    "character": {"traits": {...}, "inventory": [...], "flags": {...}},
    "world": {"current_location": "forest", "flags": {...}, "time": 3600}
  },
  "cell_type": "triumph",
  "ending": null
}
```

Using `tool_choice: {"type": "tool", "name": "present_turn"}` forces structured output. The server extracts args from the `tool_use` block — one API call per turn.

**Message history grows per turn:**
```
system: [game rules]
user: "New game. Scenario: {header}. Start node: {start_node_data}"
assistant: [tool_use: present_turn({initial narrative, choices, state})]
tool_result: "Displayed to player."
user: "Player chose: seek_knowledge. Current node: {forest_entrance data with all paths}. Settings: {temperature: 7, ...}"
assistant: [tool_use: present_turn({narrative, choices, state})]
tool_result: "Displayed to player."
...
```

### 3. New: `kleene_server/llm/prompts.py` — System Prompt

Adapts SKILL.md game rules into a system prompt for the Claude API. Includes:
- Game mechanics (precondition evaluation, consequence application)
- Decision Grid cell classification
- Narrative generation guidelines (temperature adaptation, gallery mode)
- Improvisation handling (free-text classification, soft consequences)
- Response format instructions (use `present_turn` tool)
- State tracking requirements

**Key source files to adapt from:**
- `kleene/skills/kleene-play/SKILL.md` — core game loop rules
- `kleene/lib/framework/gameplay/evaluation-reference.md` — precondition/consequence tables
- `kleene/lib/framework/gameplay/improvisation.md` — free-text handling
- `kleene/lib/framework/gameplay/presentation.md` — narrative formatting (adapt for web, not 70-char terminal)
- `kleene/lib/framework/core/core.md` — Decision Grid theory

### 4. Modified: `kleene_server/api/routes.py` — Add turn endpoint

**New endpoint:**
```python
@router.post("/game/{session_id}/turn")
async def process_turn(session_id: str, req: TurnRequest) -> TurnResponse:
    """Process a game turn through the persistent Claude session."""
    session = store.get_session(session_id)
    # Look up chosen option's next_node from session.current_choices
    # Fetch the target node from YAML via loader
    # Call engine.process_turn(session_id, choice, node_data, settings)
    # Update session: state, narrative, cells, current_choices
    # Return full turn result to web frontend
```

**Modified endpoint: `POST /api/game/start`** — now also initializes the LLM session:
```python
@router.post("/game/start")
async def start_session(req: StartSessionRequest) -> dict:
    session = store.create_session(...)
    header = loader.get_header(req.scenario_id)
    start_node = loader.get_node(req.scenario_id, header["start_node"])
    result = engine.start_game(session.session_id, system_prompt, header, start_node)
    # Store initial state, choices, narrative
    # Return initial turn result (narrative + choices + state)
```

**Existing endpoints kept** (web UI still reads from these for display refresh):
- `GET /state`, `GET /narrative`, `GET /grid`, `GET /settings`, `PATCH /settings`
- These are updated by the turn endpoint, read by the web UI for display

**Endpoints removed/deprecated:**
- `PUT /state`, `PUT /narrative` — server now writes these (not external LLM)
- `POST /choice`, `GET /choice` — replaced by `POST /turn`

### 5. Modified: `kleene_server/state/sessions.py` — Add LLM tracking

Add to `GameSession`:
```python
current_choices: list[dict] = field(default_factory=list)  # Options from last turn (for next_node lookup)
current_node_id: str = ""  # Current node ID
```

The `GameEngine` manages message history separately (in `engine.sessions`).

### 6. Modified: `kleene_server/api/schemas.py` — Turn schemas

```python
class TurnRequest(BaseModel):
    choice: str  # Option ID or free-text input

class TurnResponse(BaseModel):
    narrative: str
    choices: dict | None  # {prompt, options} or None if ending
    state: dict  # Full game state for web UI display
    cell_type: str | None  # Decision Grid cell, if any
    ending: dict | None  # {type, narrative} if game over
    grid: dict  # Updated grid coverage
```

### 7. Modified: `kleene_server/config.py` — API key

Add `anthropic_api_key` field. Read from `ANTHROPIC_API_KEY` env var or `--api-key` CLI arg.

### 8. Modified: `kleene_server/main.py` — Wire engine

Create `GameEngine` instance at startup, pass to router alongside loader and store.

### 9. Modified: `pyproject.toml` — Add anthropic dependency

Add `"anthropic>=0.40.0"` to dependencies.

### 10. Modified: `kleene-web/js/app.js` — Synchronous turns

Replace the polling + fire-and-forget choice submission with synchronous turn processing:

```javascript
async startGame(scenarioId) {
    const result = await this.api('POST', '/api/game/start', {
        scenario_id: scenarioId, game_mode: 'solo'
    });
    // result now includes initial narrative + choices + state
    this.sessionId = result.session_id;
    this.showScreen('game');
    this.handleTurnResult(result);  // Display initial state
}

async submitChoice(choice) {
    // Show loading state
    const result = await this.api('POST', `/api/game/${this.sessionId}/turn`, { choice });
    this.handleTurnResult(result);
}

handleTurnResult(result) {
    // Update all UI components from turn result
    KleeneNarrative.appendNarrative(result.narrative);
    KleeneNarrative.renderChoices(result.choices);
    KleeneGame.updateFromState(result.state);
    KleeneGrid.updateFromGrid(result.grid);
    if (result.ending) { /* show ending screen */ }
}
```

**Remove**: `startPolling()`, `pollState()` — no more 2-second polling loop for narrative/state.

**Keep**: Settings PATCH still works (web UI pushes settings to server, server includes them in next turn message to Claude). Could optionally keep a lighter poll just for settings sync, but not strictly needed since settings are sent with each turn.

### 11. Modified: `kleene-web/js/narrative.js` — Append mode

Change from "replace all from history" to "append new narrative":
```javascript
appendNarrative(text) {
    const display = document.getElementById('narrative-display');
    const turn = document.createElement('div');
    turn.className = 'narrative-turn';
    turn.textContent = text;
    display.appendChild(turn);
    display.scrollTop = display.scrollHeight;
}
```

Keep `renderChoices()` as-is — it already handles structured choice data correctly.

## Files Summary

| File | Action | Purpose |
|------|--------|---------|
| `kleene_server/llm/__init__.py` | Create | Package init |
| `kleene_server/llm/engine.py` | Create | Core LLM proxy — persistent Claude sessions |
| `kleene_server/llm/prompts.py` | Create | System prompt from SKILL.md game rules |
| `kleene_server/api/routes.py` | Modify | Add `POST /turn`, modify `POST /start` |
| `kleene_server/api/schemas.py` | Modify | Add TurnRequest/TurnResponse |
| `kleene_server/state/sessions.py` | Modify | Add current_choices, current_node_id |
| `kleene_server/config.py` | Modify | Add anthropic_api_key |
| `kleene_server/main.py` | Modify | Wire GameEngine |
| `pyproject.toml` | Modify | Add anthropic dependency |
| `kleene-web/js/app.js` | Modify | Synchronous turns, remove polling |
| `kleene-web/js/narrative.js` | Modify | Append mode |
| `tests/test_api.py` | Modify | Add turn endpoint tests (mocked LLM) |

## Verification

1. **Unit test**: Mock the Anthropic client, verify turn processing flow (choice → node fetch → LLM call → structured response → session state update)
2. **Integration test**: Start server with `ANTHROPIC_API_KEY` set, start game via API, submit choices, verify narrative + choices come back correctly
3. **End-to-end**: Open web frontend in browser, connect to server, select dragon_quest, play through several turns, verify narrative displays, choices work, stats update, Decision Grid tracks cells
4. **Settings**: Adjust temperature slider mid-game, verify next turn's narrative reflects the change
5. **Free-text**: Type a custom action, verify improvisation handling works
6. **Ending**: Play to an ending, verify ending screen displays

## Open Questions

1. **Model choice**: Default to `claude-sonnet-4-5-20250929` (fast, cheap, capable enough for game logic). User can override via config. Could also use Haiku for even lower cost.
2. **Context window management**: Long games will accumulate history. For v1, keep full history. Later, add summarization of older turns to stay within context limits.
3. **Streaming**: For v1, wait for full response. Later, add SSE streaming so narrative appears word-by-word in the browser.
4. **Error handling**: If Claude API call fails, return error to web frontend with retry option. Don't lose session state.
