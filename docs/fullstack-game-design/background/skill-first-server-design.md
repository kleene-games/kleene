# Plan: Replace kleene-server LLM Layer with Claude Agent SDK

## Context

kleene-server currently wraps the raw Anthropic API with a ~150-line system prompt that reimplements a fraction of the kleene game engine. The actual game engine lives in the kleene plugin's skill (SKILL.md + ~15 framework docs), which runs in Claude Code with full features: time system, scheduled events, parser mode, improvisation, gallery mode, checkpoints, replay, and more.

This refactor replaces the thin LLM reimplementation with the real thing: the server loads the kleene plugin via the Claude Agent SDK, sends `/kleene play [scenario]`, and the skill runs the full game loop. The server becomes a scenario gatekeeper (DRM, progressive disclosure), state observer (multiplayer, monetization), and I/O bridge (web UI ↔ skill).

## Architecture

```
Web UI ←→ FastAPI Server ←→ Claude Agent SDK Session
               ↕                    ↕ (curl to localhost)
        SessionStore          Server's own scenario API
        ScenarioLoader        State/narrative/cell endpoints
```

The skill runs in **remote loading mode**, fetching nodes one-at-a-time from the server's scenario API. The server never sends the full scenario to the LLM — preserving DRM and preventing the engine from seeing future nodes.

## Choice Input: Configurable Per-Session

Two mechanisms for getting player choices into the skill, configurable per-session and changeable mid-session via API:

1. **Claude Code UI mode** (`interaction_mode: "terminal"`) — AskUserQuestion presents choices in the Claude Code terminal. Used when playing directly via Claude Code.
2. **API-driven mode** (`interaction_mode: "api"`) — Server intercepts AskUserQuestion via `can_use_tool`, extracts choices, pushes to web UI. Web UI submits via `POST /choice`. Server returns the answer to the SDK callback.

Default is `api` when started via the server. The `PATCH /game/{session_id}/settings` endpoint gets a new `interaction_mode` field that can switch mid-session.

---

## Phase 0: SDK Validation (Go/No-Go Gate)

**Goal**: Confirm the Agent SDK can load the kleene plugin and run the skill on Linux.

Create a standalone test script `tests/test_sdk_validation.py`:
1. Install `claude-agent-sdk`
2. Start `ClaudeSDKClient` with `plugins=[{"type": "local", "path": "/path/to/kleene"}]`
3. Send `/kleene play dragon_quest` (with local kleene-server running)
4. Verify:
   - Skill loads and executes
   - `can_use_tool` callback fires for `AskUserQuestion`
   - Narrative text appears in response messages
   - Skill's curl calls to localhost:8420 succeed
5. Test on Ubuntu 25.10 (known SDK issues #509, #268 on Linux)

**If blocked**: Workaround — symlink skill into `cwd/.claude/skills/`. If still blocked, investigate using the SDK's `system_prompt` parameter to inject SKILL.md content directly (fallback to prompt-based approach with the full skill text instead of the thin 150-line prompt).

**Files**: New `tests/test_sdk_validation.py`

---

## Phase 1: AgentEngine Core

**Goal**: New engine class that manages SDK sessions with async I/O bridging.

### New file: `kleene_server/llm/agent_engine.py`

```
AgentEngine
├── start_game(session_id, scenario_id, interaction_mode) -> None
│   Creates AgentSession, launches SDK as background asyncio.Task
│   Waits for first choices_ready event
│
├── submit_choice(session_id, choice) -> dict
│   Puts choice into session's queue, waits for next turn
│   Returns current turn data (narrative, choices, state, etc.)
│
├── get_current_turn(session_id) -> dict
│   Returns buffered turn data (narrative, choices) without blocking
│
├── update_interaction_mode(session_id, mode) -> None
│   Switches between "terminal" and "api" mid-session
│
└── has_session(session_id) -> bool

AgentSession
├── session_id, scenario_id
├── interaction_mode: "terminal" | "api"
├── choices_ready: asyncio.Event  (set when AskUserQuestion intercepted)
├── choice_queue: asyncio.Queue   (web UI → SDK callback)
├── current_turn_data: dict       (narrative, choices extracted from interception)
├── narrative_buffer: list[str]   (streaming narrative chunks)
├── task: asyncio.Task            (the running SDK session)
└── client: ClaudeSDKClient       (for session lifecycle)
```

### SDK Session Lifecycle (`_run_session`)

1. Create `ClaudeAgentOptions`:
   - `plugins=[{"type": "local", "path": plugin_path}]`
   - `can_use_tool=self._handle_tool`
   - `include_partial_messages=True`
   - `model=configured_model`
   - `cwd=session_working_dir` (temp dir per session for saves)
2. Open `ClaudeSDKClient`, send `/kleene play {scenario_id}`
3. Iterate response messages, buffer narrative text
4. On session end: mark session as completed

### Tool Handler (`_handle_tool`)

```python
async def _handle_tool(self, tool_name, input_data, server_name):
    if tool_name == "AskUserQuestion" and self.interaction_mode == "api":
        # Extract choices from input_data["questions"]
        self._extract_and_buffer_choices(input_data)
        self.choices_ready.set()
        # Block until web UI submits a choice
        choice = await self.choice_queue.get()
        # Return with pre-filled answer
        return PermissionResultAllow(updated_input={
            **input_data,
            "answers": self._format_answer(input_data, choice)
        })

    if tool_name == "AskUserQuestion" and self.interaction_mode == "terminal":
        # Let it through — Claude Code UI handles it
        return PermissionResultAllow()

    if tool_name == "Bash":
        # Auto-approve curl calls to localhost (skill's remote mode)
        # Auto-approve yq calls (tool detection)
        return PermissionResultAllow()

    if tool_name == "Write" or tool_name == "Edit":
        # Auto-approve save file writes
        return PermissionResultAllow()

    if tool_name == "Read" or tool_name == "Glob" or tool_name == "Grep":
        # Auto-approve reads (skill reads framework docs)
        return PermissionResultAllow()

    # Default: allow
    return PermissionResultAllow()
```

**Files**: New `kleene_server/llm/agent_engine.py`

---

## Phase 2: Configuration

**Goal**: Add config for plugin path, engine mode, and defaults.

### Modified: `kleene_server/config.py`

Add fields to `ServerConfig`:
- `plugin_path: Path | None` — path to kleene plugin directory
- `engine_mode: str` — `"legacy"` (raw Anthropic) or `"agent"` (SDK)
- `default_interaction_mode: str` — `"api"` or `"terminal"`

Resolution chain: CLI args → .env → environment → defaults.
Default `plugin_path`: sibling directory `../kleene` relative to kleene-server.

### Modified: `kleene_server/main.py`

Wire up engine based on `engine_mode`:
- `"agent"` + `plugin_path` exists → `AgentEngine`
- `"legacy"` + `anthropic_api_key` → `GameEngine` (unchanged)
- Neither → `None` (graceful degradation)

Update `/health` to report engine type.

**Files**: `kleene_server/config.py`, `kleene_server/main.py`

---

## Phase 3: Route Integration

**Goal**: Adapt start/turn endpoints to work with both engine types.

### Modified: `kleene_server/api/routes.py`

**Type handling**: `create_router` accepts `AgentEngine | GameEngine | None`.

**`POST /game/start`**:
- If AgentEngine: `await engine.start_game(session_id, scenario_id, interaction_mode)`
  - No need to pass header/start_node — the skill fetches these via curl
  - Wait for `choices_ready`, return turn data from `engine.get_current_turn()`
- If GameEngine: unchanged (legacy path)

**`POST /game/{session_id}/turn`**:
- If AgentEngine: `result = await engine.submit_choice(session_id, choice)`
  - No need to look up next_node or fetch node data — skill handles all of that
  - State/narrative/cell updates arrive via the skill's curl calls to existing endpoints
- If GameEngine: unchanged (legacy path)

**`PATCH /game/{session_id}/settings`**:
- Add `interaction_mode` field to `UpdateSettingsRequest`
- If AgentEngine: call `engine.update_interaction_mode(session_id, mode)`
- Store in SessionStore alongside other settings

**`POST /game/{session_id}/choice`** — stays as-is. In API mode, this is how the web UI submits. The `can_use_tool` callback picks it up.

**New endpoint: `GET /game/{session_id}/stream`** (optional, SSE):
- Server-Sent Events for real-time narrative streaming
- Yields narrative chunks from `AgentSession.narrative_buffer`
- Not required for MVP (skill PUTs narrative via curl), but improves web UI responsiveness

### Modified: `kleene_server/api/schemas.py`

- Add `interaction_mode: str | None = None` to `StartSessionRequest`
- Add `interaction_mode: str | None = None` to `UpdateSettingsRequest`
- Add `engine_type: str` to start response

### Modified: `kleene_server/state/sessions.py`

- Add `interaction_mode: str = "api"` to `GameSession`

**Files**: `kleene_server/api/routes.py`, `kleene_server/api/schemas.py`, `kleene_server/state/sessions.py`

---

## Phase 4: Dependencies

### Modified: `pyproject.toml`

```toml
dependencies = [
    "fastapi>=0.115.0",
    "uvicorn[standard]>=0.32.0",
    "ruamel.yaml>=0.18.0",
    "pydantic>=2.10.0",
    "anthropic>=0.40.0",        # Keep for legacy engine
    "claude-agent-sdk>=0.1.35", # New: Agent SDK
]
```

Pin SDK version based on Phase 0 findings.

**Files**: `pyproject.toml`

---

## Phase 5: Tests

### New: `tests/test_agent_engine.py`

- Unit tests with mocked SDK client
- Test AgentSession async lifecycle (start → choices_ready → submit → next turn)
- Test interaction_mode switching mid-session
- Test tool handler auto-approves correct tools
- Test error handling (SDK crash, timeout, etc.)

### Modified: `tests/test_api.py`

- Add fixtures for AgentEngine-backed routes
- Test start_session with agent engine
- Test process_turn with agent engine
- Test interaction_mode in settings
- All existing legacy engine tests unchanged

### New: `tests/test_integration_sdk.py` (marked slow)

- Full integration test: start server, start agent session, play 2-3 turns
- Requires running kleene-server and valid API key
- Validates the full loop: SDK → skill → curl to server → state updates

**Files**: `tests/test_agent_engine.py`, `tests/test_api.py`, `tests/test_integration_sdk.py`

---

## Phase 6: Cleanup (Later, Optional)

- Delete `llm/prompts.py` (system prompt + present_turn tool definition)
- Optionally remove `llm/engine.py` if legacy mode is no longer needed
- Or keep both engines behind the `engine_mode` config flag

---

## Session Recovery

When the server restarts, SDK sessions are lost. Recovery path:
1. Game state is persisted in SessionStore (skill PUTs state every turn)
2. On reconnect: start new SDK session with `/kleene continue {scenario}`
3. Skill loads from saved state and resumes

This uses the skill's existing save/resume capability — no new code needed in the skill.

---

## Files Summary

| File | Action | Phase |
|------|--------|-------|
| `tests/test_sdk_validation.py` | New | 0 |
| `kleene_server/llm/agent_engine.py` | New | 1 |
| `kleene_server/config.py` | Modify | 2 |
| `kleene_server/main.py` | Modify | 2 |
| `kleene_server/api/routes.py` | Modify | 3 |
| `kleene_server/api/schemas.py` | Modify | 3 |
| `kleene_server/state/sessions.py` | Modify | 3 |
| `pyproject.toml` | Modify | 4 |
| `tests/test_agent_engine.py` | New | 5 |
| `tests/test_api.py` | Modify | 5 |
| `tests/test_integration_sdk.py` | New | 5 |
| `kleene_server/llm/prompts.py` | Delete | 6 |

## Verification

1. **Phase 0**: Run `test_sdk_validation.py` — SDK loads plugin, skill executes, AskUserQuestion intercepted
2. **Phase 1-4**: Run existing test suite — all legacy tests pass, new agent engine tests pass
3. **Integration**: Start server with `--engine-mode agent`, hit `POST /game/start` with a scenario, verify narrative + choices returned, submit choice via `POST /turn`, verify next turn
4. **Full loop**: Play 3+ turns through the web UI, verify state persists, settings changes propagate, Decision Grid cells reported
5. **Recovery**: Kill and restart server, verify resume works via `/kleene continue`
