# Stage 8: Social & Multiplayer Foundation

## 1. Overview

Stage 8 transforms Kleene from a solo experience into a social platform. Shared worlds let multiple players inhabit the same scenario simultaneously. Leaderboards rank players by Decision Grid coverage and turn efficiency. Player profiles showcase achievements and play history. Improvisation sharing lets players contribute creative content that can be curated into scenarios.

**What this stage achieves:**
- Shared world state synchronization (per-player character state + shared world state)
- Turn locking and conflict resolution for simultaneous players
- SSE broadcast to multiple participants in a shared world
- Leaderboard system with multiple scoring dimensions
- Player presence (who's online, what they're playing)
- Improvisation curation pipeline (submit → review → approve → integrate)
- Player profiles with play statistics and achievement showcase
- Collaborative worldbuilding approval workflow

**Why it matters:** Social features create network effects — players attract players. Shared worlds are the foundation for the agentic player ecosystem (Stage 9), where human and AI players coexist in the same narrative worlds.

## 2. Prerequisites

- **Stage 1** — SSE streaming (broadcast to multiple clients)
- **Stage 2** — Authentication (user identity for profiles, leaderboards)
- **Stage 3** — Persistence (shared state, leaderboard data, improvisation records)
- **Stage 5** — Monetization (entitlements for shared world scenarios)
- **Stage 6** — Security (rate limiting for social endpoints, content moderation)

## 3. Current State

### Game Modes
**File:** `kleene-server/kleene_server/state/sessions.py`
- `GameSession` has `game_mode: str = "solo"` field
- `StartSessionRequest` accepts `game_mode` parameter
- Only `"solo"` is implemented — `"shared"` and `"collaborative"` exist as values but have no logic

### World State
**File:** `kleene-server/kleene_server/state/sessions.py`
- `GameSession` has `world_id: str | None` field — unused
- `StartSessionRequest` accepts `world_id` parameter — passed through but not used
- No concept of shared state between sessions

### Cell Tracking
**File:** `kleene-server/kleene_server/state/sessions.py`
- `cells_discovered` tracks per-session cell discoveries
- Grid coverage calculation exists with tier logic (bronze/silver/gold)
- No cross-session aggregation (leaderboards)

### Design Documents
- `plan-iteration-1.md` defines three game modes (solo, shared, collaborative)
- MCP tool API includes social tools: `list_active_players`, `view_leaderboard`, `share_improvisation`

## 4. Target Architecture

```
Player A (Web)     Player B (Web)     Player C (CLI)
    │                   │                   │
    └───────────────────┼───────────────────┘
                        │
              SSE Broadcast Hub
              (per world_id)
                        │
    ┌───────────────────┼───────────────────┐
    │                   │                   │
Session A           Session B           Session C
(character_a)       (character_b)       (character_c)
    │                   │                   │
    └───────────────────┼───────────────────┘
                        │
                  Shared World State
                  ├── world.flags
                  ├── world.time
                  ├── world.locations (NPC positions, item states)
                  ├── world.scheduled_events
                  └── world.triggered_events

Turn Lock Manager
    ├── Acquire lock (per world, per location)
    ├── Process turn (one player at a time per location)
    ├── Broadcast state changes via SSE
    └── Release lock
```

### State Split

In shared worlds, game state is divided into two ownership domains:

| Owner | State | Stored In |
|-------|-------|-----------|
| **Per-player** (private) | character traits, inventory, flags, relationships, history, current_node | `game_sessions.state` |
| **Shared** (world-level) | world flags, time, locations, NPC positions, scheduled/triggered events | `shared_worlds.world_state` |

A player's turn can modify both their private state and the shared world state. Changes to shared state are broadcast to all participants.

### Turn Sequencing

```
Player A submits choice at location "village"
    │
    v
Turn Lock Manager: acquire lock for (world_id, "village")
    │
    ├── [lock acquired]
    │   │
    │   v
    │   Process turn:
    │   1. Read shared world state
    │   2. Evaluate preconditions (player state + world state)
    │   3. Apply player consequences (private)
    │   4. Apply world consequences (shared, broadcast)
    │   5. Release lock
    │
    └── [lock busy — Player B is mid-turn at "village"]
        │
        v
        Queue Player A's turn (FIFO per location)
        Notify via SSE: "Waiting for another player..."
```

**Location-scoped locking:** Players at different locations process turns concurrently. Only players at the same location must serialize.

## 5. Interface Contracts

### Game Mode: Shared World

```
POST /api/v1/game/start
{
  "scenario_id": "dragon_quest",
  "game_mode": "shared",
  "world_id": null          // null = create new world, UUID = join existing
}

→ 200 OK
{
  "session_id": "ses_a1b2c3",
  "world_id": "wld_x1y2z3",   // assigned or joined
  "scenario_id": "dragon_quest",
  "game_mode": "shared",
  "players": [
    {"user_id": "usr_a1", "display_name": "Kael", "location": "village"}
  ]
}
```

### Shared World Endpoints

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| `GET` | `/api/v1/worlds` | List active shared worlds | Authenticated |
| `GET` | `/api/v1/worlds/{world_id}` | World details + player list | Authenticated |
| `POST` | `/api/v1/worlds/{world_id}/join` | Join existing world | Authenticated |
| `POST` | `/api/v1/worlds/{world_id}/leave` | Leave world (keep session) | Authenticated |
| `GET` | `/api/v1/worlds/{world_id}/events` | SSE stream for world events | Authenticated |

### World SSE Events

```
event: player_joined
data: {"user_id": "usr_b2", "display_name": "Elena", "location": "village"}

event: player_left
data: {"user_id": "usr_b2", "display_name": "Elena"}

event: world_state_changed
data: {
  "changes": [
    {"path": "world.flags.gate_open", "value": true, "caused_by": "usr_a1"},
    {"path": "world.locations.village.items", "action": "removed", "item": "rusty_sword"}
  ],
  "turn": 12,
  "timestamp": "2026-02-15T10:30:00Z"
}

event: player_moved
data: {"user_id": "usr_a1", "from": "village", "to": "forest_path"}

event: turn_waiting
data: {"location": "village", "reason": "Another player is acting here"}

event: chat_message
data: {"user_id": "usr_b2", "display_name": "Elena", "text": "I found the key!", "timestamp": "..."}
```

### Leaderboard Endpoints

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| `GET` | `/api/v1/leaderboards` | Available leaderboard categories | Anonymous |
| `GET` | `/api/v1/leaderboards/{category}` | Ranked entries | Anonymous |
| `GET` | `/api/v1/leaderboards/{category}/me` | Current user's rank | Authenticated |

### Leaderboard Categories

| Category | Metric | Scoring |
|----------|--------|---------|
| `grid_coverage` | Decision Grid cells discovered | Unique cells across all scenarios |
| `turn_efficiency` | Fewest turns to complete a scenario | Lower is better, per scenario |
| `scenario_completion` | Scenarios completed | Count of distinct scenario endings reached |
| `improvisation_accepted` | Improvisations curated into scenarios | Count of approved submissions |
| `gold_achiever` | Gold tier completions | Count of Gold tier grid completions |

### Leaderboard Response

```
GET /api/v1/leaderboards/grid_coverage?scenario_id=dragon_quest&limit=10

→ 200 OK
{
  "category": "grid_coverage",
  "scenario_id": "dragon_quest",
  "entries": [
    {
      "rank": 1,
      "user_id": "usr_a1",
      "display_name": "DragonSlayer",
      "score": 9,
      "details": {"cells": ["triumph", "rebuff", "escape", "fate", "commitment", "discovery", "deferral", "constraint", "limbo"], "tier": "gold"},
      "achieved_at": "2026-02-10T15:00:00Z"
    },
    {
      "rank": 2,
      "user_id": "usr_b2",
      "display_name": "QuestSeeker",
      "score": 7,
      "details": {"cells": ["triumph", "rebuff", "escape", "fate", "commitment", "discovery", "deferral"], "tier": "silver"},
      "achieved_at": "2026-02-12T09:00:00Z"
    }
  ],
  "total_entries": 156,
  "my_rank": 23
}
```

### Player Presence

```
GET /api/v1/presence?scenario_id=dragon_quest

→ 200 OK
{
  "online": [
    {
      "user_id": "usr_a1",
      "display_name": "DragonSlayer",
      "scenario_id": "dragon_quest",
      "game_mode": "shared",
      "world_id": "wld_x1y2z3",
      "location": "dragon_cave",
      "turn": 18,
      "last_active": "2026-02-15T10:29:50Z"
    }
  ],
  "total_online": 12,
  "total_playing_scenario": 3
}
```

### Player Profiles

```
GET /api/v1/players/{user_id}/profile

→ 200 OK
{
  "user_id": "usr_a1",
  "display_name": "DragonSlayer",
  "joined_at": "2026-01-15T00:00:00Z",
  "stats": {
    "scenarios_completed": 5,
    "total_turns": 342,
    "gold_completions": 2,
    "unique_cells": 38,
    "improvisations_shared": 7,
    "improvisations_accepted": 3
  },
  "achievements": [...],  // from Stage 7
  "recent_activity": [
    {"type": "completed", "scenario_id": "dragon_quest", "tier": "gold", "at": "2026-02-10T15:00:00Z"},
    {"type": "shared_improv", "scenario_id": "dragon_quest", "node_id": "village_square", "at": "2026-02-08T11:00:00Z"}
  ]
}
```

### Improvisation Sharing

```
POST /api/v1/improvisations
Content-Type: application/json
Authorization: Bearer <jwt>

{
  "session_id": "ses_a1b2c3",
  "scenario_id": "dragon_quest",
  "node_id": "village_square",
  "player_input": "I try to climb the church tower to get a better view",
  "narrative_response": "You scale the ancient stone tower...",
  "classification": "discovery",
  "outcome": "You spot the dragon's lair in the distant mountains"
}

→ 201 Created
{
  "improvisation_id": "imp_x1y2z3",
  "status": "submitted"
}
```

### Improvisation Curation Pipeline

```
submitted → under_review → approved → integrated
                        → rejected

GET /api/v1/admin/improvisations?status=submitted
POST /api/v1/admin/improvisations/{id}/review
  {action: "approve" | "reject", reviewer_notes: "..."}
POST /api/v1/admin/improvisations/{id}/integrate
  {target_node_id: "village_square", as_option: true}
```

## 6. Data Model

### Table: `shared_worlds`

```sql
CREATE TABLE shared_worlds (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    short_id        VARCHAR(12) UNIQUE NOT NULL,  -- "wld_x1y2z3"
    scenario_id     VARCHAR(100) NOT NULL REFERENCES scenarios(id),
    world_state     JSONB NOT NULL DEFAULT '{}',
    player_count    INTEGER DEFAULT 0,
    max_players     INTEGER DEFAULT 8,
    status          VARCHAR(20) DEFAULT 'active',  -- active, full, archived
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_worlds_scenario ON shared_worlds(scenario_id) WHERE status = 'active';
```

### Table: `world_participants`

```sql
CREATE TABLE world_participants (
    world_id        UUID REFERENCES shared_worlds(id) ON DELETE CASCADE,
    user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
    session_id      UUID REFERENCES game_sessions(id) ON DELETE CASCADE,
    joined_at       TIMESTAMPTZ DEFAULT now(),
    left_at         TIMESTAMPTZ,
    PRIMARY KEY (world_id, user_id)
);
```

### Table: `leaderboard_entries`

```sql
CREATE TABLE leaderboard_entries (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id),
    category        VARCHAR(50) NOT NULL,
    scenario_id     VARCHAR(100) REFERENCES scenarios(id),  -- NULL for global boards
    score           INTEGER NOT NULL,
    details         JSONB DEFAULT '{}',
    achieved_at     TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, category, scenario_id)
);

CREATE INDEX idx_leaderboard_rank ON leaderboard_entries(category, scenario_id, score DESC);
CREATE INDEX idx_leaderboard_user ON leaderboard_entries(user_id);
```

### Table: `improvisations`

```sql
CREATE TABLE improvisations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    short_id        VARCHAR(12) UNIQUE NOT NULL,
    user_id         UUID NOT NULL REFERENCES users(id),
    session_id      UUID REFERENCES game_sessions(id),
    scenario_id     VARCHAR(100) NOT NULL REFERENCES scenarios(id),
    node_id         VARCHAR(100) NOT NULL,
    player_input    TEXT NOT NULL,
    narrative_response TEXT NOT NULL,
    classification  VARCHAR(20),  -- Decision Grid cell type
    outcome         TEXT,
    status          VARCHAR(20) DEFAULT 'submitted',  -- submitted, under_review, approved, rejected, integrated
    reviewer_id     UUID REFERENCES users(id),
    reviewer_notes  TEXT,
    reviewed_at     TIMESTAMPTZ,
    integrated_at   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_improvisations_status ON improvisations(status);
CREATE INDEX idx_improvisations_scenario ON improvisations(scenario_id, node_id);
CREATE INDEX idx_improvisations_user ON improvisations(user_id);
```

### Table: `player_presence`

```sql
CREATE TABLE player_presence (
    user_id         UUID PRIMARY KEY REFERENCES users(id),
    scenario_id     VARCHAR(100),
    session_id      UUID,
    world_id        UUID,
    location        VARCHAR(100),
    turn            INTEGER DEFAULT 0,
    last_heartbeat  TIMESTAMPTZ DEFAULT now(),
    status          VARCHAR(20) DEFAULT 'online'  -- online, idle, offline
);

CREATE INDEX idx_presence_scenario ON player_presence(scenario_id) WHERE status = 'online';
```

### Updates to `game_sessions`

```sql
ALTER TABLE game_sessions ADD COLUMN world_id UUID REFERENCES shared_worlds(id);
```

## 7. Migration Path

### Step 1: Shared world infrastructure
- Create `shared_worlds` and `world_participants` tables
- Implement `SharedWorldManager` with create/join/leave operations
- Implement state split: player state in `game_sessions`, world state in `shared_worlds`

### Step 2: Turn locking
- Implement location-scoped turn lock (in-memory with advisory locks for database)
- Test: two players at same location → turns serialize correctly
- Test: two players at different locations → turns process concurrently

### Step 3: SSE broadcast
- Extend SSE infrastructure from Stage 1 to support per-world broadcast channels
- World state changes → broadcast to all participants
- Player join/leave → broadcast to world

### Step 4: Leaderboards
- Create `leaderboard_entries` table
- Hook into game completion events to update scores
- Implement leaderboard API with pagination and user-specific rank

### Step 5: Player presence
- Create `player_presence` table with heartbeat mechanism
- SSE connection → online, disconnect → idle (30s), timeout → offline (5min)
- Presence API for who's playing what

### Step 6: Improvisation pipeline
- Create `improvisations` table
- Add sharing endpoint (player submits during gameplay)
- Add admin review workflow
- Integration step: approved improvisation → new option on target node

### Step 7: Player profiles
- Aggregate stats from sessions, cell tracking, achievements, improvisations
- Profile API endpoint
- Privacy controls: public vs private profile elements

**Backward compatibility:** Solo mode is unchanged. Shared world features only activate when `game_mode: "shared"`. All new tables and endpoints are additive.

## 8. Security Considerations

- **Turn lock starvation:** A malicious player could acquire a lock and never release it. Implement lock timeout (60 seconds) with automatic release.
- **World state tampering:** In shared worlds, player-pushed state updates could contain fabricated world state changes. The server must validate that world state changes are consistent with the turn being processed.
- **Presence privacy:** Some players may not want their online status visible. Default to opt-in for presence visibility.
- **Improvisation content moderation:** Shared improvisations are user-generated content visible to others. Implement content filtering (profanity, harmful content) before making submissions visible.
- **Leaderboard manipulation:** Prevent score inflation through repeated gameplay or exploited game states. Validate scores server-side against game session records.
- **Chat moderation:** In-world chat messages need basic content filtering and rate limiting.
- **SSE connection limits:** Shared worlds with many players generate many SSE connections. Set per-world limits (max 8 players) and per-user limits (max 3 SSE connections).
- **World data isolation:** Ensure players in different worlds cannot access each other's world state through API manipulation.

## 9. Verification Criteria

- [ ] Create shared world → second player joins → both see each other in player list
- [ ] Player A's turn changes world flag → Player B receives `world_state_changed` SSE event
- [ ] Two players at same location → turns process sequentially (no state corruption)
- [ ] Two players at different locations → turns process concurrently
- [ ] Player disconnects → presence updates to "idle" → timeout → "offline"
- [ ] Leaderboard shows correct rankings after game completion
- [ ] Player profile aggregates stats from all sessions
- [ ] Improvisation submitted → appears in admin review queue → approve → integrated into scenario
- [ ] Solo mode works exactly as before (no shared world overhead)
- [ ] `game_mode: "shared"` in `StartSessionRequest` creates/joins a shared world
- [ ] Turn lock timeout prevents lock starvation (lock released after 60 seconds)
- [ ] SSE broadcast scales to 8 players per world without degradation

## 10. Open Questions

- **World persistence:** Should shared worlds persist indefinitely, or expire after all players leave? Suggest: persist for 7 days of inactivity, then archive.
- **World discovery:** How do players find worlds to join? Lobby system? Invitation links? Matchmaking? Suggest: list active worlds in the UI, allow joining by world_id or invitation link.
- **Conflict resolution beyond locking:** What if Player A opens a gate and Player B closes it in the same second? Location-scoped locking handles sequential turns, but what about remote consequences (Player A at village triggers event affecting Player B at forest)? Suggest: global event queue processed between turns.
- **Improvisation quality threshold:** What criteria determine if an improvisation is "good enough" to integrate? Manual review for now, automated quality scoring later?
- **Leaderboard anti-cheat:** How to detect and prevent leaderboard manipulation? Server-side score validation is a start, but sophisticated cheating (optimal paths via external tools) is harder to detect.
- **Chat system scope:** Simple in-game text chat, or richer communication (emotes, reactions)? Suggest: text-only for MVP.
- **Collaborative worldbuilding:** The third game mode where approved improvisations become permanent world content. How does this differ from "shared + improvisation integration"? Does it need its own mode, or is it a feature of shared worlds?
- **Spectator mode:** Stage 9 introduces spectator mode for watching agents play. Should human spectators be supported in this stage? Suggest: yes, read-only SSE connections with no turn submission.

---

*Cross-references:*
- *[Stage 1: Server Consolidation](stage-1-server-consolidation.md) — SSE infrastructure*
- *[Stage 2: Identity & Auth](stage-2-identity-auth.md) — User identity for profiles*
- *[Stage 3: Persistence](stage-3-persistence.md) — Database tables*
- *[Stage 7: Blockchain](stage-7-blockchain.md) — Achievement display in profiles*
- *[Stage 9: Agentic Players](stage-9-agentic-players.md) — Agents in shared worlds, spectator mode*
- *[Plan Iteration 1](../background/plan-iteration-1.md) — Game modes, social features, MCP social tools*
