# Stage 1: Server Consolidation & API Contracts

## 1. Overview

Stage 1 formalizes the existing Kleene MVP into a stable, versioned API surface. The current server works but lacks versioning, streaming, session lifecycle management, and error standardization. This stage hardens what exists before adding new capabilities.

**What this stage achieves:**
- Versioned API (`/api/v1/`) so future changes don't break existing clients
- SSE streaming for real-time narrative delivery (replacing synchronous polling)
- Session state machine with explicit lifecycle transitions
- Standardized error responses across all endpoints
- Web frontend completion (filling stubbed modules)
- OpenAPI spec auto-generation for documentation and client codegen

**Why it matters:** Every subsequent stage builds on these API contracts. Getting them right now prevents cascading rewrites later.

## 2. Prerequisites

- None. This is the foundation stage.

## 3. Current State

### Server Routes
**File:** `kleene-server/kleene_server/api/routes.py`
- 17 endpoints under unversioned `/api/` prefix
- `create_router()` takes `ScenarioLoader`, `SessionStore`, and optional `GameEngine`
- No middleware pipeline — routes directly access injected dependencies
- Error responses are bare `HTTPException` with inconsistent detail formats

### Schemas
**File:** `kleene-server/kleene_server/api/schemas.py`
- Pydantic v2 models: `ScenarioSummary`, `ScenarioHeader`, `ScenarioNode`, `ScenarioEnding`, `TurnRequest`, `TurnResponse`, `GridCoverage`, etc.
- `TurnResponse` returns `narrative`, `choices`, `state`, `cell_type`, `ending`, `grid`
- No envelope pattern — responses are bare model instances

### Session Management
**File:** `kleene-server/kleene_server/state/sessions.py`
- `GameSession` dataclass with: `session_id`, `scenario_id`, `game_mode`, `world_id`, `state`, `narrative`, `narrative_history`, `settings`, `cells_discovered`, `saves`, `pending_choice`, `current_choices`, `current_node_id`
- `SessionStore` is a `dict[str, GameSession]` — no lifecycle management, no expiry, no state transitions
- Sessions exist from creation until server restart

### Web Frontend
**File:** `kleene-web/js/` (5 modules)
- `app.js` — Application bootstrap and module coordination
- `game.js` — Game state display and narrative rendering
- `controls.js` — Settings panel (temperature, gallery mode, foresight, parser mode)
- `narrative.js` — Narrative text formatting and history
- `grid.js` — Decision Grid visualization
- Current model: synchronous fetch per turn, no streaming

### Configuration
**File:** `kleene-server/kleene_server/config.py`
- `ServerConfig` dataclass with `mode`, `host`, `port`, `scenarios_dir`, `cors_origins: ["*"]`, LLM fields, and unused `database_url`/`stripe_key`/`admin_key`

## 4. Target Architecture

```
Client (Web/CLI)
    │
    ├── HTTP ──────────── /api/v1/* ──── Versioned JSON API
    │                         │
    │                    Middleware Pipeline
    │                    ├── Error Handler (standardized responses)
    │                    ├── Request ID (correlation tracking)
    │                    └── [Auth placeholder — Stage 2]
    │                         │
    │                    Route Handlers
    │                    ├── Scenario routes (read-only)
    │                    ├── Session routes (lifecycle + turns)
    │                    └── Admin routes (reload, diagnostics)
    │
    └── SSE ──────────── /api/v1/game/{session_id}/stream
                              │
                         SSE Event Stream
                         ├── narrative_chunk (streamed text)
                         ├── choices_ready (turn complete)
                         ├── state_update (game state changed)
                         ├── cell_discovered (grid event)
                         ├── session_ended (game over)
                         └── error (something went wrong)
```

### Data Flow: Turn Processing

```
1. Client POST /api/v1/game/{session_id}/turn {choice: "option_id"}
2. Server validates session state == "active"
3. Server dispatches to GameEngine.process_turn()
4. Engine streams narrative chunks → SSE narrative_chunk events
5. Engine returns final result (choices, state, cell)
6. Server emits choices_ready event via SSE
7. Server updates SessionStore
8. Client receives choices via SSE (or poll fallback)
```

## 5. Interface Contracts

### API Versioning

All existing endpoints move under `/api/v1/`. The unversioned `/api/` prefix is removed.

```
/api/scenarios          →  /api/v1/scenarios
/api/scenario/{id}/...  →  /api/v1/scenario/{id}/...
/api/game/...           →  /api/v1/game/...
```

A redirect middleware serves `301` from `/api/*` to `/api/v1/*` during a transition period.

### Standardized Error Response

All error responses follow a consistent envelope:

```json
{
  "error": {
    "code": "SESSION_NOT_FOUND",
    "message": "Session abc123 does not exist or has expired",
    "request_id": "req_7f3a2b"
  }
}
```

Error codes are string constants (not HTTP status codes). HTTP status codes convey transport-level meaning; error codes convey domain-level meaning.

| HTTP Status | Error Code | When |
|-------------|-----------|------|
| 400 | `INVALID_REQUEST` | Malformed request body |
| 404 | `SCENARIO_NOT_FOUND` | Scenario ID doesn't exist |
| 404 | `SESSION_NOT_FOUND` | Session ID doesn't exist or expired |
| 404 | `NODE_NOT_FOUND` | Node ID doesn't exist in scenario |
| 404 | `SAVE_NOT_FOUND` | Save ID doesn't exist |
| 409 | `SESSION_NOT_ACTIVE` | Turn submitted to paused/ended session |
| 409 | `NO_ENGINE_SESSION` | LLM session not initialized |
| 429 | `RATE_LIMITED` | Too many requests (placeholder for Stage 6) |
| 500 | `ENGINE_ERROR` | LLM engine failed during processing |
| 503 | `ENGINE_UNAVAILABLE` | No API key configured |

### SSE Event Schema

**Endpoint:** `GET /api/v1/game/{session_id}/stream`

Connection lifecycle:
1. Client opens SSE connection after session creation
2. Server sends `connected` event with session metadata
3. Server streams events as game progresses
4. Connection closes when session ends or client disconnects
5. Client reconnects with `Last-Event-ID` header for resume

**Event types:**

```
event: connected
data: {"session_id": "abc123", "scenario_id": "dragon_quest"}

event: narrative_chunk
data: {"text": "The forge glows warm. ", "final": false}

event: narrative_chunk
data: {"text": "Weapons line the walls.", "final": true}

event: choices_ready
data: {"prompt": "What do you take?", "options": [...], "state": {...}, "cell_type": "commitment", "grid": {...}}

event: state_update
data: {"turn": 3, "current_node": "blacksmith_shop", "character": {...}}

event: cell_discovered
data: {"cell_type": "triumph", "node_id": "dragon_fight", "coverage": 4, "tier": "bronze"}

event: session_ended
data: {"reason": "ending_reached", "ending": {"id": "ending_victory", "type": "victory"}}

event: error
data: {"code": "ENGINE_ERROR", "message": "Failed to process turn"}
```

Each event includes an `id` field (monotonic counter) for reconnection support.

### Session State Machine

```
        create
          │
          v
      ┌────────┐    pause     ┌────────┐
      │ active  │ ──────────> │ paused │
      │        │ <────────── │        │
      └────────┘    resume    └────────┘
          │                       │
          │ end                   │ end
          v                       v
      ┌────────┐             ┌────────┐
      │ ended  │             │ ended  │
      └────────┘             └────────┘
          │                       │
          │ expire (TTL)          │ expire (TTL)
          v                       v
      [removed from store]   [removed from store]
```

**State transitions:**
- `create` → `active`: Session created, ready to play
- `active` → `paused`: Explicit pause or SSE disconnect timeout
- `paused` → `active`: Resume (SSE reconnect or explicit resume)
- `active` → `ended`: Game ending reached or explicit end
- `paused` → `ended`: Explicit end while paused
- `ended` → removed: TTL expiry (configurable, default 24h for ended, 7d for active/paused)

**Constraints:**
- Turns can only be submitted when state is `active`
- Save/load available in `active` or `paused`
- Settings updates available in `active` or `paused`
- State and narrative reads available in any state except removed

### Updated Endpoint List

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/scenarios` | List available scenarios |
| `GET` | `/api/v1/scenario/{id}/header` | Scenario metadata + initial state |
| `GET` | `/api/v1/scenario/{id}/node/{node_id}` | Single node (progressive disclosure) |
| `GET` | `/api/v1/scenario/{id}/ending/{ending_id}` | Ending details |
| `GET` | `/api/v1/scenario/{id}/locations` | Location definitions |
| `POST` | `/api/v1/scenario/{id}/reload` | Force scenario cache refresh |
| `POST` | `/api/v1/game/start` | Create session + initialize engine |
| `GET` | `/api/v1/game/sessions` | List active sessions |
| `GET` | `/api/v1/game/{session_id}` | Session details + current state |
| `POST` | `/api/v1/game/{session_id}/turn` | Submit choice, process turn |
| `GET` | `/api/v1/game/{session_id}/stream` | SSE event stream |
| `POST` | `/api/v1/game/{session_id}/pause` | Pause session |
| `POST` | `/api/v1/game/{session_id}/resume` | Resume session |
| `POST` | `/api/v1/game/{session_id}/end` | End session |
| `PUT` | `/api/v1/game/{session_id}/state` | Sync state (engine → store) |
| `GET` | `/api/v1/game/{session_id}/state` | Read state (store → UI) |
| `PUT` | `/api/v1/game/{session_id}/narrative` | Push narrative text |
| `GET` | `/api/v1/game/{session_id}/narrative` | Read narrative + history |
| `PATCH` | `/api/v1/game/{session_id}/settings` | Update per-turn settings |
| `GET` | `/api/v1/game/{session_id}/settings` | Read settings |
| `GET` | `/api/v1/game/{session_id}/grid` | Decision Grid coverage |
| `POST` | `/api/v1/game/{session_id}/cell` | Report cell discovery |
| `POST` | `/api/v1/game/{session_id}/save` | Save game state |
| `GET` | `/api/v1/game/saves` | List all saves |
| `POST` | `/api/v1/game/load/{save_id}` | Load saved state |
| `POST` | `/api/v1/game/{session_id}/choice` | Submit choice from web UI |
| `GET` | `/api/v1/game/{session_id}/choice` | Poll pending choice |

### OpenAPI Generation

FastAPI auto-generates OpenAPI 3.1 spec from Pydantic models. Additions:
- Tags for endpoint grouping: `scenarios`, `sessions`, `gameplay`, `saves`
- Example values on all schema fields
- Description on every endpoint
- Available at `/api/v1/docs` (Swagger UI) and `/api/v1/openapi.json`

## 6. Data Model

No database changes in this stage (still in-memory). Schema updates to `GameSession`:

```
GameSession (updated)
├── session_id: str
├── scenario_id: str
├── game_mode: str ("solo" | "shared" | "collaborative")
├── world_id: str | None
├── status: str ("active" | "paused" | "ended")      # NEW
├── created_at: str (ISO 8601)
├── updated_at: str (ISO 8601)                        # NEW
├── ended_at: str | None (ISO 8601)                   # NEW
├── state: dict[str, Any]
├── narrative: str
├── narrative_history: list[str]
├── settings: dict[str, Any]
├── cells_discovered: list[dict[str, Any]]
├── saves: dict[str, dict[str, Any]]
├── pending_choice: str | None
├── current_choices: list[dict[str, Any]]
├── current_node_id: str
└── sse_event_counter: int                            # NEW (for Last-Event-ID)
```

## 7. Migration Path

### Step 1: Add API version prefix
- Update `create_router()` to use `prefix="/api/v1"`
- Add redirect middleware from `/api/*` → `/api/v1/*`
- Update web frontend fetch URLs

### Step 2: Add error standardization
- Create error handler middleware
- Replace bare `HTTPException` calls with domain error codes
- Add `request_id` generation middleware

### Step 3: Add session lifecycle
- Add `status`, `updated_at`, `ended_at` fields to `GameSession`
- Add state validation to turn processing (reject if not `active`)
- Add pause/resume/end endpoints
- Add TTL-based session cleanup (background task)

### Step 4: Add SSE streaming
- Create `SSEManager` that maintains per-session event queues
- Add `/stream` endpoint using `StreamingResponse`
- Modify `GameEngine` interface to yield narrative chunks
- Update web frontend to consume SSE instead of polling

### Step 5: Complete web frontend
- Audit each JS module for stubbed functionality
- Implement SSE client with reconnection logic
- Add session lifecycle controls (pause/resume/end)
- Add proper error display using standardized error responses

### Step 6: Generate OpenAPI spec
- Add tags, descriptions, and examples to all endpoints
- Verify spec at `/api/v1/openapi.json`
- Test with Swagger UI at `/api/v1/docs`

**Backward compatibility:** The redirect middleware ensures old `/api/*` URLs continue working. Remove redirects after all clients migrate to `/api/v1/`.

## 8. Security Considerations

- **CORS remains `["*"]`** in this stage — tightened in Stage 6
- **No auth** — all endpoints remain unauthenticated (Stage 2)
- **SSE connection hijacking** — without auth, anyone who knows a session_id can connect to its stream. Acceptable for local-only mode; must be gated by auth in remote mode (Stage 2)
- **Session enumeration** — `GET /sessions` lists all sessions. Acceptable for local; requires auth scoping in Stage 2
- **Request ID exposure** — include in responses for debugging but ensure it doesn't leak internal state
- **SSE reconnection** — `Last-Event-ID` must be validated (monotonic, within bounds) to prevent replay attacks

## 9. Verification Criteria

- [ ] All endpoints respond under `/api/v1/` prefix
- [ ] Old `/api/*` URLs return 301 redirects to `/api/v1/*`
- [ ] `/api/v1/openapi.json` returns valid OpenAPI 3.1 spec
- [ ] `/api/v1/docs` renders Swagger UI with all endpoints documented
- [ ] All error responses match the standardized envelope format
- [ ] SSE stream delivers `narrative_chunk` and `choices_ready` events during gameplay
- [ ] SSE reconnection with `Last-Event-ID` resumes from correct event
- [ ] Session state machine enforces valid transitions (turn rejected when paused/ended)
- [ ] Sessions expire after configured TTL
- [ ] Web frontend operates entirely via SSE (no turn polling)
- [ ] Web frontend handles SSE disconnection and reconnection gracefully
- [ ] `process_turn` rejects requests when session status is not `active`

## 10. Open Questions

- **SSE vs WebSocket:** SSE is simpler and sufficient for server→client streaming. If bidirectional streaming is needed later (e.g., collaborative typing), WebSocket may be warranted. Decision: start with SSE, revisit if Stage 8 (multiplayer) needs it.
- **Event buffer size:** How many SSE events to buffer per session for reconnection? Too few and clients miss events; too many wastes memory. Suggest 100 events or 5 minutes, whichever is smaller.
- **Narrative chunk granularity:** Should chunks be sentence-level, paragraph-level, or token-level? Paragraph-level aligns with the game's presentation rules (70-char formatted blocks) but token-level gives the smoothest streaming UX.
- **Session TTL values:** Default 24h for ended sessions, 7d for active/paused. Should these be configurable via `ServerConfig`?
- **Legacy endpoint removal timeline:** How long to maintain `/api/*` redirects before removing them? Suggest one minor version cycle.
- **OpenAPI spec versioning:** Should the spec version track the API version (1.0.0) or the server version (0.1.0)?

---

*Cross-references:*
- *[Consolidated Master Plan](../consolidated-master-plan.md)*
- *[Plan Iteration 1](../background/plan-iteration-1.md) — Phase 1-3*
- *[Remote Loading Mode](../../lib/framework/scenario-file-loading/remote-loading.md)*
