# Stage 3: Persistence & Cloud Storage

## 1. Overview

Stage 3 moves Kleene from ephemeral in-memory storage to durable PostgreSQL persistence. Game sessions survive server restarts. Saves persist across devices. Scenarios can be ingested from YAML files into the database for managed deployment.

**What this stage achieves:**
- `StorageProvider` abstraction (in-memory vs database, same interface)
- PostgreSQL schema for users, scenarios, sessions, saves, and cell tracking
- Alembic migration framework for schema evolution
- JSONB storage for game state (nested dict, schema-flexible)
- Scenario ingestion pipeline (YAML → database)
- Cloud saves enabling cross-device play
- Async database access via SQLAlchemy + asyncpg

**Why it matters:** Without persistence, every server restart loses all game state. Monetization (Stage 5) requires durable entitlement records. Social features (Stage 8) require persistent player profiles and leaderboard data.

## 2. Prerequisites

- **Stage 1** — Versioned API, session state machine
- **Stage 2** — User identity (sessions are owned by users, saves are per-user)

## 3. Current State

### SessionStore
**File:** `kleene-server/kleene_server/state/sessions.py`
- Pure in-memory: `dict[str, GameSession]`
- `GameSession` is a dataclass with 13 fields
- Saves stored in `session.saves` dict — lost on restart
- No user ownership (sessions are anonymous)
- `uuid4()[:8]` for session IDs (collision-prone at scale)

### ScenarioLoader
**File:** `kleene-server/kleene_server/scenarios/loader.py`
- Reads YAML files from `scenarios_dir` on disk
- Caches parsed scenarios in memory
- No access control — all scenarios available to all users
- `reload()` re-reads from disk

### Game State Shape
Game state is a nested dict pushed by the LLM engine each turn:
```json
{
  "turn": 5,
  "scene": 2,
  "current_node": "blacksmith_shop",
  "character": {
    "name": "Kael",
    "exists": true,
    "traits": {"courage": 7, "wisdom": 5},
    "inventory": ["rusty_sword", "healing_herbs"],
    "flags": {"spoke_to_elder": true},
    "relationships": {"elena": 3},
    "history": ["Entered village", "Spoke to elder"]
  },
  "world": {
    "current_location": "village",
    "flags": {"gate_open": true},
    "time": {"elapsed_seconds": 3600},
    "scheduled_events": [...],
    "triggered_events": [...]
  }
}
```

This is arbitrarily nested and scenario-dependent — JSONB is the natural fit.

### Dependencies Already Declared
**File:** `kleene-server/pyproject.toml`
```
[project.optional-dependencies]
remote = [
    "sqlalchemy[asyncio]>=2.0.0",
    "alembic>=1.14.0",
    "asyncpg>=0.30.0",
    ...
]
```

### Configuration
**File:** `kleene-server/kleene_server/config.py`
- `database_url: str | None` field exists but is unused
- CLI arg `--db` maps to it

## 4. Target Architecture

```
Route Handler
    │
    v
StorageProvider (abstract interface)
    │
    ├── MemoryStorageProvider          (local mode — current behavior)
    │   └── dict[str, GameSession]
    │
    └── DatabaseStorageProvider         (remote mode)
        │
        ├── SQLAlchemy AsyncSession
        │   ├── UserModel
        │   ├── ScenarioModel
        │   ├── GameSessionModel
        │   ├── SaveModel
        │   └── CellTrackingModel
        │
        └── asyncpg connection pool
            └── PostgreSQL
                ├── users
                ├── scenarios
                ├── game_sessions
                ├── saves
                └── cell_tracking
```

### StorageProvider Interface

```
StorageProvider (abstract)
│
├── Sessions
│   ├── create_session(user_id, scenario_id, game_mode, world_id?) → GameSession
│   ├── get_session(session_id) → GameSession | None
│   ├── update_session_status(session_id, status) → bool
│   ├── list_sessions(user_id?) → list[SessionSummary]
│   └── delete_expired_sessions(ttl) → int
│
├── State
│   ├── update_state(session_id, state: dict) → bool
│   ├── get_state(session_id) → dict | None
│   ├── update_narrative(session_id, narrative) → bool
│   ├── get_narrative(session_id) → NarrativeData | None
│   ├── update_settings(session_id, settings: dict) → bool
│   └── get_settings(session_id) → dict | None
│
├── Grid
│   ├── report_cell(session_id, cell_type, node_id) → bool
│   └── get_grid_coverage(session_id) → GridCoverage
│
├── Saves
│   ├── save_game(session_id, name?) → str (save_id)
│   ├── load_game(session_id, save_id) → SaveData | None
│   ├── list_saves(user_id?) → list[SaveSummary]
│   └── delete_save(save_id) → bool
│
├── Choices
│   ├── set_pending_choice(session_id, choice) → bool
│   └── get_pending_choice(session_id) → str | None
│
└── Scenarios (database provider only)
    ├── ingest_scenario(yaml_path) → str (scenario_id)
    ├── get_scenario_header(scenario_id) → dict | None
    ├── get_scenario_node(scenario_id, node_id) → dict | None
    ├── get_scenario_ending(scenario_id, ending_id) → dict | None
    ├── get_scenario_locations(scenario_id) → list[dict]
    └── list_scenarios(user_id?) → list[ScenarioSummary]
```

## 5. Interface Contracts

### New/Modified Endpoints

| Method | Path | Change |
|--------|------|--------|
| `GET` | `/api/v1/game/saves` | Now returns saves for authenticated user (was all saves) |
| `DELETE` | `/api/v1/game/saves/{save_id}` | **New** — delete a save |
| `POST` | `/api/v1/admin/scenarios/ingest` | **New** — ingest YAML scenario into database |
| `GET` | `/api/v1/game/{session_id}` | Now includes `user_id` and persistent `session_id` (full UUID) |

### Save Response (updated)

```json
{
  "save_id": "sav_a1b2c3d4",
  "session_id": "ses_e5f6g7h8",
  "scenario_id": "dragon_quest",
  "name": "Before dragon fight",
  "state": { "...": "..." },
  "created_at": "2026-02-15T10:30:00Z",
  "turn": 12,
  "current_node": "dragon_cave_entrance"
}
```

### Scenario Ingestion

```
POST /api/v1/admin/scenarios/ingest
Content-Type: application/json
Authorization: Bearer <admin_jwt>

{
  "yaml_path": "/path/to/dragon_quest.yaml",
  "price_cents": 0,
  "game_modes": ["solo", "shared"],
  "tier": "free"
}

→ 201 Created
{
  "scenario_id": "dragon_quest",
  "name": "The Dragon's Choice",
  "node_count": 25,
  "ending_count": 7,
  "ingested_at": "2026-02-15T10:00:00Z"
}
```

## 6. Data Model

### Entity Relationship Diagram

```
users ──────────< game_sessions >────────── scenarios
  │                    │                        │
  │                    ├──< saves                │
  │                    │                        │
  │                    └──< cell_tracking        │
  │                                             │
  └──< api_keys (Stage 2)                      │
  └──< refresh_tokens (Stage 2)                │
  └──< player_scenarios (Stage 5) >────────────┘
```

### Table: `users`

```sql
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           VARCHAR(255) UNIQUE NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,
    display_name    VARCHAR(100) NOT NULL,
    tier            VARCHAR(20) DEFAULT 'authenticated',
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_users_email ON users(email);
```

### Table: `scenarios`

```sql
CREATE TABLE scenarios (
    id              VARCHAR(100) PRIMARY KEY,  -- slug: "dragon_quest"
    name            VARCHAR(255) NOT NULL,
    description     TEXT DEFAULT '',
    version         VARCHAR(20) DEFAULT '1.0.0',
    header          JSONB NOT NULL,            -- initial_character, initial_world, travel_config
    nodes           JSONB NOT NULL,            -- {node_id: node_data, ...}
    endings         JSONB NOT NULL,            -- {ending_id: ending_data, ...}
    locations       JSONB DEFAULT '[]',
    node_count      INTEGER DEFAULT 0,
    ending_count    INTEGER DEFAULT 0,
    price_cents     INTEGER DEFAULT 0,
    game_modes      VARCHAR(20)[] DEFAULT '{solo}',
    tier            VARCHAR(20) DEFAULT 'free',
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now()
);
```

**Why store nodes/endings as JSONB blobs, not normalized tables?**
- Scenario data is read-heavy, write-once (ingested from YAML, rarely updated)
- Individual node access uses `nodes->>'node_id'` which is fast with GIN index
- Normalized tables (one row per node) would be 25+ rows per scenario with complex joins
- JSONB preserves the exact structure the game engine expects
- Trade-off: no per-node relational queries, but those aren't needed

```sql
CREATE INDEX idx_scenarios_nodes ON scenarios USING GIN (nodes);
```

### Table: `game_sessions`

```sql
CREATE TABLE game_sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    short_id        VARCHAR(8) UNIQUE NOT NULL,   -- for URL-friendly references
    user_id         UUID REFERENCES users(id) ON DELETE SET NULL,
    scenario_id     VARCHAR(100) REFERENCES scenarios(id),
    game_mode       VARCHAR(20) DEFAULT 'solo',
    world_id        UUID,
    status          VARCHAR(20) DEFAULT 'active',  -- active, paused, ended
    state           JSONB DEFAULT '{}',
    narrative       TEXT DEFAULT '',
    narrative_history JSONB DEFAULT '[]',
    settings        JSONB DEFAULT '{"improvisation_temperature": 5, "gallery_mode": false, "foresight": 5, "parser_mode": false}',
    current_choices JSONB DEFAULT '[]',
    current_node_id VARCHAR(100) DEFAULT '',
    pending_choice  VARCHAR(255),
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now(),
    ended_at        TIMESTAMPTZ
);

CREATE INDEX idx_sessions_user ON game_sessions(user_id) WHERE status != 'ended';
CREATE INDEX idx_sessions_world ON game_sessions(world_id) WHERE world_id IS NOT NULL;
CREATE INDEX idx_sessions_status ON game_sessions(status);
```

### Table: `saves`

```sql
CREATE TABLE saves (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    short_id        VARCHAR(8) UNIQUE NOT NULL,
    session_id      UUID REFERENCES game_sessions(id) ON DELETE CASCADE,
    user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
    scenario_id     VARCHAR(100) REFERENCES scenarios(id),
    name            VARCHAR(255),
    state           JSONB NOT NULL,
    turn            INTEGER DEFAULT 0,
    current_node    VARCHAR(100) DEFAULT '',
    created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_saves_user ON saves(user_id);
CREATE INDEX idx_saves_session ON saves(session_id);
```

### Table: `cell_tracking`

```sql
CREATE TABLE cell_tracking (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id      UUID REFERENCES game_sessions(id) ON DELETE CASCADE,
    user_id         UUID REFERENCES users(id) ON DELETE SET NULL,
    scenario_id     VARCHAR(100) REFERENCES scenarios(id),
    cell_type       VARCHAR(20) NOT NULL,
    node_id         VARCHAR(100) NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_cells_session ON cell_tracking(session_id);
CREATE INDEX idx_cells_user_scenario ON cell_tracking(user_id, scenario_id);
```

## 7. Migration Path

### Step 1: Create StorageProvider abstraction
- Define `StorageProvider` abstract base class
- Refactor current `SessionStore` into `MemoryStorageProvider` implementing this interface
- Update `create_router()` to accept `StorageProvider` instead of `SessionStore`
- Verify all existing tests pass (pure refactor, no behavior change)

### Step 2: Set up Alembic
- `alembic init` in `kleene-server/`
- Configure `alembic.ini` with async driver support
- Create initial migration with all tables above
- Test migration against fresh PostgreSQL instance

### Step 3: Implement DatabaseStorageProvider
- SQLAlchemy 2.0 async models mapping to tables above
- Implement all `StorageProvider` methods using async sessions
- Connection pooling via `create_async_engine` with `pool_size=10, max_overflow=20`

### Step 4: Scenario ingestion pipeline
- CLI command: `kleene-server ingest-scenario /path/to/scenario.yaml`
- Reads YAML, validates structure, inserts into `scenarios` table
- Admin API endpoint for programmatic ingestion
- Maintain backward compatibility: `ScenarioLoader` still works for local mode (reads files)

### Step 5: Provider selection at startup
- `mode == "local"` → `MemoryStorageProvider` (with `ScenarioLoader` for YAML files)
- `mode == "remote"` → `DatabaseStorageProvider` (with scenarios from database)
- Both expose identical `StorageProvider` interface to routes

### Step 6: Data format compatibility
- Verify YAML save format (v8) roundtrips cleanly through JSONB
- Test: save game in local mode → ingest into database → load in remote mode
- Handle edge cases: Python `None` ↔ JSON `null`, datetime serialization

**Backward compatibility:** Local mode is unchanged — same in-memory storage, same YAML scenario files. Remote mode adds database persistence without altering the API contract.

## 8. Security Considerations

- **SQL injection:** SQLAlchemy parameterized queries prevent injection. Never interpolate user input into raw SQL.
- **JSONB injection:** Game state is stored as-is from the LLM engine. Validate that state dicts don't contain excessively large values (set max JSONB size per field, e.g., 1MB for state).
- **Connection string secrets:** `database_url` contains credentials. Load from environment variable or `.env` file, never commit to source.
- **Row-level security:** `user_id` filtering at the application layer (in `DatabaseStorageProvider`). Consider PostgreSQL RLS policies as defense-in-depth.
- **Backup and recovery:** PostgreSQL `pg_dump` for backups. JSONB fields are included. Test restore regularly.
- **Data retention:** Define retention policy for ended sessions and orphaned saves. Suggest: ended sessions retained 90 days, then archived or deleted.
- **Migration safety:** Alembic migrations must be backward-compatible (add columns as nullable, backfill, then add constraints). Never drop columns in the same migration that removes code using them.

## 9. Verification Criteria

- [ ] Server starts in remote mode with PostgreSQL connection
- [ ] `alembic upgrade head` creates all tables successfully
- [ ] `alembic downgrade -1` and `alembic upgrade head` is idempotent
- [ ] Create session → play turns → save game → restart server → load save → continue playing
- [ ] Game state survives server restart (verified by checking session still exists after restart)
- [ ] Scenario ingestion: `dragon_quest.yaml` → database → all nodes accessible via API
- [ ] Cell tracking persists across restarts and aggregates across sessions per user
- [ ] Save game in local mode (YAML), ingest scenario into database, load save in remote mode — state is identical
- [ ] Local mode works exactly as before (no database required)
- [ ] Connection pool handles concurrent requests without exhaustion (10 concurrent sessions)
- [ ] `StorageProvider` interface is the same one used by all subsequent stages

## 10. Open Questions

- **JSONB vs normalized game state:** Current approach stores entire game state as JSONB. Alternative: normalize character traits, inventory, flags into separate columns/tables for queryable leaderboards. Suggest JSONB for game state (flexibility), denormalized summary columns for leaderboard-relevant data (turn count, cell coverage). Revisit for Stage 8.
- **Scenario versioning:** When a scenario YAML is re-ingested, should existing sessions reference the old version or migrate? Suggest: scenarios are versioned by `id + version` composite, existing sessions keep their version.
- **Narrative history size:** `narrative_history` can grow unbounded (one entry per turn, potentially 100+ turns). Cap at 50 entries in database? Paginate access?
- **Multi-region deployment:** Single PostgreSQL instance vs read replicas? Defer until load patterns are understood.
- **Connection pool sizing:** `pool_size=10, max_overflow=20` is a starting point. Should these be configurable via `ServerConfig`?
- **Scenario YAML ↔ JSONB fidelity:** YAML supports anchors, aliases, and complex types that JSONB doesn't. Verify the ingestion pipeline handles all scenario format features.

---

*Cross-references:*
- *[Stage 1: Server Consolidation](stage-1-server-consolidation.md) — Session state machine*
- *[Stage 2: Identity & Auth](stage-2-identity-auth.md) — Users table, session ownership*
- *[Stage 5: Monetization](stage-5-monetization.md) — player_scenarios table*
- *[Plan Iteration 1](../background/plan-iteration-1.md) — Database schema, Phase 5*
- *[Scenario Format Spec](../../lib/framework/formats/scenario-format.md)*
