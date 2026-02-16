# Stage 4: Remote Execution & Agent SDK

## 1. Overview

Stage 4 replaces the server's thin LLM prompt wrapper with the full kleene-play skill running via Claude Agent SDK. The current `GameEngine` sends a 150-line simplified system prompt to the Anthropic API and handles turns directly. The real skill (`SKILL.md`, 21.8K) contains far richer game logic: improvisation rules, scripted improvisation flows, gallery mode, parser mode, temperature-based option enrichment, and the full Decision Grid evaluation framework. The Agent SDK bridges this gap by running the actual plugin skill as a managed agent session.

**What this stage achieves:**
- `GameEngine` abstraction with two implementations (`LLMGameEngine` and `AgentGameEngine`)
- Agent SDK session lifecycle management (create, run, intercept, recover)
- I/O bridging: web UI choices routed through server to agent's `AskUserQuestion`
- Tool auto-approval policies for safe operations (file reads, saves, HTTP fetches)
- SDK availability detection with graceful fallback to LLM engine
- Session recovery from saved state when SDK sessions are lost

**Why it matters:** The LLM engine is a simplified approximation of the real game engine. Running the actual skill means full feature parity — improvisation, gallery mode, parser mode, scripted improvisation, temperature-based enrichment — without maintaining two divergent implementations.

## 2. Prerequisites

- **Stage 1** — SSE streaming (agent narrative streams to client via SSE)
- **Stage 2** — Auth middleware (agent sessions are user-scoped)
- **Stage 3** — Persistence (session recovery requires saved state to survive SDK restart)

## 3. Current State

### LLM Engine
**File:** `kleene-server/kleene_server/llm/engine.py`
- `GameEngine` class using Anthropic SDK directly
- 150-line system prompt (simplified version of SKILL.md)
- Maintains per-session `message_history` in memory
- Uses `present_turn` tool with `tool_choice: "required"`
- Returns structured turn data: `{narrative, choices, state, cell_type, ending}`
- Methods: `start_game()`, `process_turn()`, `has_session()`

### System Prompt
**File:** `kleene-server/kleene_server/llm/prompts.py`
- Condensed game rules without improvisation, gallery mode, or parser mode
- No reference to framework documentation
- No temperature-based option enrichment
- No scripted improvisation flows

### Full Skill
**File:** `kleene/skills/kleene-play/SKILL.md` (21.8K)
- Complete game engine with all features
- References framework docs via `${CLAUDE_PLUGIN_ROOT}/lib/...`
- Uses `AskUserQuestion` for player choices
- Uses `Bash` (curl) for remote node fetching
- Uses `Write` for save files
- Uses `Read/Glob/Grep` for framework documentation and scenario loading

### Skill-First Server Design
**File:** `kleene/docs/fullstack-game-design/background/skill-first-server-design.md`
- Detailed `AgentEngine` class design with async I/O bridging
- Interaction modes: "terminal" (CLI) and "api" (web)
- Tool handler patterns for auto-approval
- Session recovery via `/kleene continue {scenario}`

## 4. Target Architecture

```
Web Client
    │
    ├── POST /api/v1/game/{id}/turn ──────┐
    │                                      │
    └── GET  /api/v1/game/{id}/stream ─────┤
                                           │
                                      Route Handler
                                           │
                                    GameEngine (abstract)
                                           │
                    ┌──────────────────────┤
                    │                      │
             LLMGameEngine          AgentGameEngine
             (current, fallback)    (SDK-powered)
                    │                      │
             Anthropic API          Claude Agent SDK
             (direct calls)                │
                                    AgentSession
                                    ├── SDK client (background task)
                                    ├── choice_queue (UI → agent)
                                    ├── event_queue (agent → SSE)
                                    ├── tool handler (approval + intercept)
                                    └── interaction_mode ("api" | "terminal")
```

### GameEngine Abstraction

```
GameEngine (abstract)
├── start_game(session_id, scenario_id, settings?) → TurnData
├── process_turn(session_id, choice, node_data?, settings?) → TurnData
├── has_session(session_id) → bool
├── end_session(session_id) → None
└── get_engine_type() → str  ("llm" | "agent")
```

**TurnData structure** (same as current `TurnResponse`):
```
TurnData
├── narrative: str
├── choices: {prompt: str, options: [...]} | None
├── state: dict
├── cell_type: str | None
├── ending: dict | None
└── grid: GridCoverage
```

Both `LLMGameEngine` and `AgentGameEngine` return identical `TurnData`. The route handler doesn't know which engine is running.

### AgentSession

```
AgentSession
├── session_id: str
├── scenario_id: str
├── interaction_mode: "api" | "terminal"
├── sdk_client: ClaudeSDKClient          (Agent SDK client instance)
├── sdk_task: asyncio.Task               (background task running the agent)
├── choice_queue: asyncio.Queue          (web UI → agent, capacity 1)
├── choices_ready: asyncio.Event         (signals turn complete)
├── current_turn_data: TurnData | None   (buffered for retrieval)
├── narrative_buffer: list[str]          (accumulates streaming chunks)
├── status: "initializing" | "waiting" | "processing" | "ended" | "error"
└── error: str | None
```

### I/O Bridge: Choice Routing

```
Web UI submits choice
    │
    v
POST /api/v1/game/{id}/turn {choice: "seek_knowledge"}
    │
    v
AgentEngine.process_turn(session_id, "seek_knowledge")
    │
    v
choice_queue.put("seek_knowledge")      # unblocks agent
    │
    v
Agent resumes processing...
Agent calls AskUserQuestion → tool handler intercepts
    │
    v
Tool handler extracts choices → current_turn_data = TurnData(...)
choices_ready.set()                      # signals turn complete
    │
    v
AgentEngine returns TurnData to route handler
    │
    v
SSE emits choices_ready event to web client
```

## 5. Interface Contracts

### Engine Selection

Configured via `ServerConfig`:

```
engine_mode: "legacy" | "agent" | "auto"
plugin_path: Path | None                    (path to kleene plugin root)
default_interaction_mode: "api" | "terminal"
```

**`auto` mode** (recommended):
1. Check if Claude Agent SDK is importable
2. Check if `plugin_path` points to valid plugin
3. If both: use `AgentGameEngine`
4. If either fails: fall back to `LLMGameEngine`, log warning

### Tool Handler Policy

The Agent SDK's `can_use_tool` callback controls tool approval:

| Tool | Action | Condition |
|------|--------|-----------|
| `AskUserQuestion` | **Intercept** (API mode) / Allow (terminal mode) | Extract choices, buffer as TurnData |
| `Read` | Auto-approve | Path under plugin root or framework docs |
| `Glob` | Auto-approve | Path under plugin root or scenarios dir |
| `Grep` | Auto-approve | Path under plugin root |
| `Bash` | Auto-approve | `curl` to `localhost:8420` (node fetching) |
| `Bash` | Auto-approve | `yq` commands (YAML parsing) |
| `Write` | Auto-approve | Path under `./saves/` (save files) |
| `Edit` | Auto-approve | Path under `./saves/` |
| All others | **Deny** | Safety boundary |

### AskUserQuestion Interception (API Mode)

When the agent calls `AskUserQuestion` in API mode, the tool handler:

1. Extracts `questions[0]` from the tool input
2. Maps to TurnData:
   - `question` → `choices.prompt`
   - `options` → `choices.options` (mapped: `label` → `text`, `description` → `description`)
   - `header` → `choices.header`
3. Buffers as `current_turn_data`
4. Sets `choices_ready` event
5. Waits on `choice_queue.get()` for player response
6. Returns the choice as the tool result (as if the user had selected it)

### Session Start Flow

```
POST /api/v1/game/start {scenario_id: "dragon_quest"}
    │
    v
AgentEngine.start_game("dragon_quest")
    │
    v
1. Create AgentSession
2. Launch SDK client as asyncio.Task:
   - Load kleene plugin from plugin_path
   - Send initial prompt: "/kleene play dragon_quest"
   - Plugin loads scenario, initializes state, presents first turn
3. Agent calls AskUserQuestion → intercepted
4. First TurnData buffered
5. Return TurnData to route handler
```

### Session Recovery

When server restarts, SDK sessions are lost but game state is in the database (Stage 3):

```
1. Client attempts POST /game/{id}/turn
2. AgentEngine.has_session(id) returns False
3. Route handler loads saved state from StorageProvider
4. AgentEngine creates new SDK session
5. Sends: "/kleene continue dragon_quest" with saved state
6. Agent resumes from saved position
7. Turn proceeds normally
```

### New Configuration Fields

Added to `ServerConfig`:

```
plugin_path: Path | None        # e.g., /home/user/git/kleene-games/kleene
engine_mode: str = "auto"       # "legacy" | "agent" | "auto"
default_interaction_mode: str = "api"   # "api" | "terminal"
```

### New Dependencies

Added to `pyproject.toml`:
```
[project.optional-dependencies]
agent = [
    "claude-agent-sdk>=0.1.35",
]
```

## 6. Data Model

No database schema changes. The `game_sessions.state` JSONB column already stores the full game state that the agent pushes each turn.

New in-memory structure per session:

```
AgentSession (in-memory only, not persisted)
├── SDK client reference
├── Asyncio task reference
├── Choice queue
├── Event queue
└── Status tracking
```

Agent sessions are ephemeral — they exist only while the server is running. The persistent game state in the database enables session recovery.

## 7. Migration Path

### Step 1: Extract GameEngine abstraction
- Create abstract `GameEngine` base class
- Rename current `GameEngine` to `LLMGameEngine` implementing the interface
- Update `create_router()` to accept `GameEngine` (already does, just formalize the interface)
- Verify all tests pass (pure refactor)

### Step 2: Implement AgentGameEngine shell
- Create `AgentGameEngine` class with the same interface
- Implement `start_game()` and `process_turn()` with SDK integration
- Initially: hardcode tool approval (approve all reads, deny all writes except saves)

### Step 3: Implement AskUserQuestion interception
- Build the choice routing pipeline (queue-based async I/O bridge)
- Test: start game → receive first choices → submit choice → receive next choices

### Step 4: Implement tool handler policies
- Create configurable tool handler with the approval matrix above
- Test each tool category: reads approved, writes to saves approved, other writes denied

### Step 5: SSE integration
- Agent narrative chunks → SSE `narrative_chunk` events
- `choices_ready` → SSE `choices_ready` event
- State updates → SSE `state_update` events

### Step 6: Session recovery
- On `has_session() == False` with existing database session → recover
- Test: start game → play 5 turns → restart server → submit turn → game continues

### Step 7: Engine auto-detection
- Implement `auto` mode: check SDK availability, fall back to LLM
- Test: remove SDK → server starts with LLM engine → install SDK → server starts with agent engine

**Backward compatibility:** `engine_mode: "legacy"` runs the current `LLMGameEngine` unchanged. The `auto` mode falls back to legacy if the SDK is unavailable. No existing functionality is removed.

## 8. Security Considerations

- **Tool approval scope:** The auto-approval policy is the security boundary. A misconfigured policy could let the agent write arbitrary files or execute arbitrary commands. The tool handler must validate paths strictly (no `../` traversal, only whitelisted directories).
- **Plugin path validation:** `plugin_path` must point to a real kleene plugin directory. Validate on startup (check for `plugin.json` and `skills/kleene-play/SKILL.md`).
- **SDK session isolation:** Each SDK session runs in its own async context. Ensure sessions cannot access each other's state through shared mutable state.
- **Resource limits:** SDK sessions consume memory (conversation history) and API tokens. Set per-session limits: max turns (configurable, default 200), max context tokens, idle timeout.
- **Prompt injection via choices:** Player choices are passed as tool results to the agent. The skill's prompt should establish boundaries preventing player input from overriding game rules. This is inherent to the skill design (SKILL.md has explicit injection resistance).
- **Localhost-only curl:** Auto-approved `curl` commands are restricted to `localhost:8420`. Validate the full URL to prevent SSRF (no redirects to external hosts).

## 9. Verification Criteria

- [ ] `engine_mode: "agent"` starts game using full kleene-play skill
- [ ] `engine_mode: "legacy"` starts game using simplified LLM prompt (unchanged behavior)
- [ ] `engine_mode: "auto"` detects SDK availability and selects appropriate engine
- [ ] Agent engine: first turn returns narrative + choices matching the skill's full output quality
- [ ] Agent engine: improvisation works (free-text input → intent classification → outcome)
- [ ] Agent engine: gallery mode activates when settings toggle it
- [ ] Agent engine: parser mode works (look/inventory/help commands)
- [ ] Agent engine: temperature slider affects option enrichment
- [ ] Agent engine: save/load works through SDK session
- [ ] Session recovery: restart server mid-game → next turn succeeds → game state is continuous
- [ ] Tool handler: reads to plugin root are approved, writes outside saves are denied
- [ ] Tool handler: curl to localhost:8420 approved, curl to external URLs denied
- [ ] SSE streams narrative chunks from agent in real-time
- [ ] `GameEngine` interface is identical for both implementations (routes don't know which engine is active)

## 10. Open Questions

- **SDK session memory:** Agent SDK sessions accumulate conversation history. For long games (100+ turns), context may exceed limits. Strategy: periodically compact history? Restart session with summary? Use the skill's built-in context management?
- **Concurrent SDK sessions:** How many simultaneous agent SDK sessions can one server support? Each consumes API tokens and memory. Need benchmarking to determine practical limits.
- **Interaction mode switching:** Can a session switch between "terminal" and "api" mid-game? The design supports it (`update_interaction_mode()`), but is there a use case? Possible: start in CLI, then switch to web UI.
- **Agent SDK availability:** The SDK is a separate package that may not be installed in all environments. How gracefully does the fallback work? Test: `import claude_agent_sdk` fails → `auto` mode selects `LLMGameEngine`.
- **Turn timeout:** How long to wait for the agent to process a turn before timing out? LLM calls can take 10-30 seconds. Suggest 60-second timeout with SSE keepalive.
- **Multiple agents per session:** Stage 8 (multiplayer) may need multiple agents in shared worlds. Does `AgentGameEngine` support one-agent-per-session, or could one agent manage multiple characters? Defer to Stage 8 design.
- **Cost attribution:** Agent SDK sessions cost API tokens. How are these costs tracked and attributed to users? Important for Stage 5 (monetization). Suggest token metering per session.

---

*Cross-references:*
- *[Skill-First Server Design](../background/skill-first-server-design.md) — AgentEngine class, tool handler, interaction modes*
- *[Stage 1: Server Consolidation](stage-1-server-consolidation.md) — SSE streaming*
- *[Stage 3: Persistence](stage-3-persistence.md) — Session recovery from saved state*
- *[Remote Loading Mode](../../lib/framework/scenario-file-loading/remote-loading.md) — How the skill fetches nodes via HTTP*
- *[SKILL.md](../../skills/kleene-play/SKILL.md) — The full game engine skill*
