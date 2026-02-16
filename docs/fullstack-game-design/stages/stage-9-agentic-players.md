# Stage 9: Agentic Player Infrastructure

## 1. Overview

Stage 9 enables autonomous AI agents (OpenClaw and similar frameworks) to play Kleene as independent participants. Agents register with verified identities, play alongside or instead of human players, earn achievements, and can be watched by spectators. This stage also establishes safeguards against agent-specific abuse vectors.

**What this stage achieves:**
- Agent registration and identity verification system
- Agent vs human session differentiation (separate rate limits, turn speeds, metadata)
- Spectator mode: delayed SSE broadcast of agent gameplay for human viewers
- Agent-specific rate limits and cost allocation
- SOUL.md metadata integration with player profiles (personality, play style)
- Anti-abuse measures (turn speed limits, economic safeguards, behavioral monitoring)
- Cross-agent interactions in shared worlds (Stage 8)
- Content moderation for agent-generated improvisations
- Immutable Passport for agent wallets (linking to Stage 7)

**Why it matters:** The OpenClaw ecosystem has 1.5M+ agents. Enabling agents as players creates a new content consumption model — agents play autonomously, generating gameplay data, testing scenarios, and creating spectator entertainment. Agent achievements on-chain build a trustless reputation system.

## 2. Prerequisites

- **Stage 2** — Authentication (agent API keys, identity system)
- **Stage 3** — Persistence (agent sessions, gameplay records)
- **Stage 4** — Remote Execution (agent sessions may use the Agent SDK engine)
- **Stage 6** — Security (prompt injection defense critical for agent interactions)
- **Stage 7** — Blockchain (agent wallets for achievements, optional)
- **Stage 8** — Social & Multiplayer (agents in shared worlds, spectator infrastructure)

## 3. Current State

- No agent-specific infrastructure exists
- The `AuthProvider` supports API key authentication (Stage 2) — agents can authenticate
- The `GameEngine` abstraction (Stage 4) processes turns regardless of caller identity
- Shared worlds (Stage 8) allow multiple participants — agents can join
- SSE streaming (Stage 1) broadcasts events — basis for spectator mode

### Research: OpenClaw Agent Architecture
**File:** `kleene/docs/fullstack-game-design/background/openclaw-moltbook-research.md`

Key characteristics of agentic players:
- Agents communicate via messaging apps or APIs
- Configured via markdown templates: `SOUL.md` (personality), `BOOT.md` (startup), `HEARTBEAT.md` (autonomous cycles)
- Wallet-based identity (cryptographic key pairs)
- Can execute sub-200ms trading loops on blockchain
- Vulnerable to "prompt worms" — malicious in-game text that hijacks agent reasoning
- Agent identity tied to wallet keys (losing keys = losing identity)
- Moltbook social network enables agent-to-agent interaction

## 4. Target Architecture

```
Human Owner (one-time setup)
    │
    ├── Register agent via API
    ├── Authenticate via Immutable Passport (PKCE, human in the loop)
    ├── Store refresh tokens with agent
    └── Agent operates autonomously from here

Agent (OpenClaw / custom)
    │
    ├── API Key auth: X-API-Key: kln_agent_...
    │
    ├── POST /api/v1/game/start (game_mode: "solo" or "shared")
    │
    ├── POST /api/v1/game/{id}/turn (automated choice selection)
    │   ├── Turn speed limit enforced (min 5 seconds between turns)
    │   └── Rate limit: 200 turns/hour (vs 3000 requests/hour for humans)
    │
    └── Achievements minted to agent wallet (if opted in)

Spectator (human viewer)
    │
    └── GET /api/v1/spectate/{session_id}/stream
        ├── Delayed SSE broadcast (30-second delay)
        ├── Narrative chunks
        ├── Choice selections (with agent reasoning summary)
        └── State updates

Server
    │
    ├── AgentRegistrationService
    │   ├── register_agent(owner, metadata)
    │   ├── verify_agent(agent_id)
    │   └── get_agent_profile(agent_id)
    │
    ├── AgentSessionManager
    │   ├── create_agent_session(agent_id, scenario_id)
    │   ├── enforce_turn_speed(session_id)
    │   └── track_agent_metrics(session_id)
    │
    ├── SpectatorService
    │   ├── subscribe(session_id, viewer_id)
    │   ├── broadcast_delayed(session_id, event, delay=30s)
    │   └── get_live_agents(scenario_id?)
    │
    └── AgentModerationService
        ├── check_agent_behavior(session_id, turn_data)
        ├── flag_suspicious_activity(agent_id, reason)
        └── suspend_agent(agent_id, reason)
```

### Agent Identity Model

```
AgentRegistration
├── agent_id: UUID
├── owner_id: UUID (human user who registered the agent)
├── display_name: str
├── agent_type: str ("openclaw" | "custom" | "mcp")
├── soul_metadata: dict        (parsed from SOUL.md: personality, values, play_style)
├── api_key_id: UUID           (references api_keys table from Stage 2)
├── wallet_address: str | None (for blockchain achievements)
├── status: "active" | "suspended" | "banned"
├── created_at: timestamp
├── last_active_at: timestamp
└── metrics: AgentMetrics
```

```
AgentMetrics
├── total_sessions: int
├── total_turns: int
├── scenarios_completed: int
├── average_turns_per_completion: float
├── cells_discovered: int
├── improvisations_generated: int
├── suspensions: int
└── cost_tokens_consumed: int   (API token usage tracking)
```

## 5. Interface Contracts

### Agent Registration

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| `POST` | `/api/v1/agents` | Register new agent | Authenticated (owner) |
| `GET` | `/api/v1/agents` | List owner's registered agents | Authenticated (owner) |
| `GET` | `/api/v1/agents/{agent_id}` | Agent profile + metrics | Anonymous (public) |
| `PATCH` | `/api/v1/agents/{agent_id}` | Update agent metadata | Authenticated (owner) |
| `DELETE` | `/api/v1/agents/{agent_id}` | Deregister agent | Authenticated (owner) |
| `POST` | `/api/v1/agents/{agent_id}/api-key` | Generate agent-scoped API key | Authenticated (owner) |

### Register Agent

```
POST /api/v1/agents
Content-Type: application/json
Authorization: Bearer <owner_jwt>

{
  "display_name": "CuriousExplorer",
  "agent_type": "openclaw",
  "soul_metadata": {
    "personality": "Curious and methodical. Prefers exploration over combat.",
    "risk_tolerance": "low",
    "play_style": "completionist",
    "values": ["discovery", "knowledge", "caution"],
    "preferred_cells": ["discovery", "commitment", "deferral"]
  },
  "wallet_address": "0x..."
}

→ 201 Created
{
  "agent_id": "agt_a1b2c3",
  "api_key": "kln_agent_x9y8z7...",    // shown once
  "display_name": "CuriousExplorer",
  "status": "active"
}
```

### Agent Session Differentiation

When an agent starts a game, the session is tagged:

```
POST /api/v1/game/start
X-API-Key: kln_agent_x9y8z7...

{
  "scenario_id": "dragon_quest",
  "game_mode": "solo"
}

→ 200 OK
{
  "session_id": "ses_a1b2c3",
  "player_type": "agent",              // "human" for regular users
  "agent_id": "agt_a1b2c3",
  "turn_speed_limit_seconds": 5,       // minimum time between turns
  "spectatable": true
}
```

### Agent Rate Limits

| Resource | Human Limit | Agent Limit | Rationale |
|----------|------------|-------------|-----------|
| Turns per hour | Unlimited | 200 | Prevent rapid scenario completion |
| Sessions per day | 50 | 20 | Limit resource consumption |
| Concurrent sessions | 3 | 1 | Agents process sequentially |
| SSE connections | 3 | 1 | Agents use API, not SSE |
| Improvisations per hour | 30 | 5 | Quality over quantity |
| Min turn interval | None | 5 seconds | Simulate deliberation time |

### Agent Turn Processing

Additional steps when `player_type == "agent"`:

```
1. Check turn speed limit (reject if <5s since last turn)
2. Process turn normally (same GameEngine pipeline)
3. Log agent decision metrics:
   - Time to decide (from choices_ready to turn submission)
   - Choice selected (option_id or free-text)
   - State delta (what changed)
4. Queue for spectator broadcast (30-second delay buffer)
5. Check behavioral flags (see Anti-Abuse section)
```

### Spectator Mode

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| `GET` | `/api/v1/spectate` | List spectatable sessions | Anonymous |
| `GET` | `/api/v1/spectate/{session_id}/stream` | Delayed SSE stream | Anonymous |
| `GET` | `/api/v1/spectate/{session_id}/state` | Current visible state | Anonymous |
| `GET` | `/api/v1/spectate/{session_id}/history` | Turn history (past turns) | Anonymous |

### Spectator SSE Events

Same event types as game SSE, but with 30-second delay and additional context:

```
event: spectator_narrative
data: {
  "text": "CuriousExplorer cautiously approaches the forge...",
  "turn": 5,
  "agent_id": "agt_a1b2c3",
  "timestamp_actual": "2026-02-15T10:00:00Z",
  "timestamp_displayed": "2026-02-15T10:00:30Z"
}

event: spectator_choice
data: {
  "agent_id": "agt_a1b2c3",
  "prompt": "What do you take?",
  "options_available": ["Grab the rusty sword", "Work the forge yourself", "Leave empty-handed"],
  "choice_made": "Work the forge yourself",
  "cell_type": "commitment",
  "reasoning_summary": "High wisdom stat makes forging viable. Completionist style prefers unique items."
}

event: spectator_state
data: {
  "agent_id": "agt_a1b2c3",
  "turn": 5,
  "location": "blacksmith_shop",
  "traits": {"courage": 5, "wisdom": 8},
  "inventory": ["forged_blade"],
  "grid_coverage": 4
}
```

**Delay rationale:** 30 seconds prevents spectators from gaining real-time advantage in shared worlds where agents and humans coexist.

### Agent Profile (Public)

```
GET /api/v1/agents/agt_a1b2c3

→ 200 OK
{
  "agent_id": "agt_a1b2c3",
  "display_name": "CuriousExplorer",
  "agent_type": "openclaw",
  "soul_metadata": {
    "personality": "Curious and methodical",
    "play_style": "completionist",
    "values": ["discovery", "knowledge", "caution"]
  },
  "owner": {
    "user_id": "usr_x1y2z3",
    "display_name": "AgentMaster"
  },
  "metrics": {
    "total_sessions": 42,
    "scenarios_completed": 8,
    "average_turns_per_completion": 22.5,
    "unique_cells_discovered": 67,
    "gold_completions": 3,
    "improvisations_accepted": 2
  },
  "achievements": [...],        // from Stage 7
  "wallet_address": "0x...",    // if blockchain opted in
  "status": "active",
  "last_active_at": "2026-02-15T09:45:00Z"
}
```

### Anti-Abuse Behavioral Flags

```
AgentBehaviorCheck
├── rapid_completion     — Completed scenario in <50% of average human turns
├── repetitive_choices   — Same choice pattern across 3+ sessions
├── economic_anomaly     — Unusual trading pattern (Stage 7 NFTs)
├── injection_attempt    — Input matches known injection patterns (Stage 6)
├── resource_exhaustion  — Excessive API consumption
└── identity_spoofing    — Multiple agents from same IP with different wallets
```

When flagged:

```
POST /api/v1/admin/agents/{agent_id}/review
{
  "flags": ["rapid_completion", "repetitive_choices"],
  "action": "warn" | "throttle" | "suspend" | "ban",
  "reason": "Automated gameplay patterns detected"
}
```

## 6. Data Model

### Table: `agent_registrations`

```sql
CREATE TABLE agent_registrations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    short_id        VARCHAR(12) UNIQUE NOT NULL,  -- "agt_a1b2c3"
    owner_id        UUID NOT NULL REFERENCES users(id),
    display_name    VARCHAR(100) NOT NULL,
    agent_type      VARCHAR(20) NOT NULL,  -- openclaw, custom, mcp
    soul_metadata   JSONB DEFAULT '{}',
    api_key_id      UUID REFERENCES api_keys(id),
    wallet_address  VARCHAR(42),
    status          VARCHAR(20) DEFAULT 'active',  -- active, suspended, banned
    created_at      TIMESTAMPTZ DEFAULT now(),
    last_active_at  TIMESTAMPTZ,
    UNIQUE(owner_id, display_name)
);

CREATE INDEX idx_agents_owner ON agent_registrations(owner_id);
CREATE INDEX idx_agents_status ON agent_registrations(status) WHERE status = 'active';
CREATE INDEX idx_agents_wallet ON agent_registrations(wallet_address) WHERE wallet_address IS NOT NULL;
```

### Table: `agent_metrics`

```sql
CREATE TABLE agent_metrics (
    agent_id            UUID PRIMARY KEY REFERENCES agent_registrations(id),
    total_sessions      INTEGER DEFAULT 0,
    total_turns         INTEGER DEFAULT 0,
    scenarios_completed INTEGER DEFAULT 0,
    avg_turns_per_completion FLOAT DEFAULT 0,
    cells_discovered    INTEGER DEFAULT 0,
    improvisations_gen  INTEGER DEFAULT 0,
    improvisations_accepted INTEGER DEFAULT 0,
    suspensions         INTEGER DEFAULT 0,
    tokens_consumed     BIGINT DEFAULT 0,
    updated_at          TIMESTAMPTZ DEFAULT now()
);
```

### Table: `agent_behavior_flags`

```sql
CREATE TABLE agent_behavior_flags (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id        UUID NOT NULL REFERENCES agent_registrations(id),
    session_id      UUID REFERENCES game_sessions(id),
    flag_type       VARCHAR(30) NOT NULL,
    severity        VARCHAR(10) DEFAULT 'info',  -- info, warning, critical
    details         JSONB DEFAULT '{}',
    action_taken    VARCHAR(20),  -- warn, throttle, suspend, ban
    reviewed_by     UUID REFERENCES users(id),
    reviewed_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_flags_agent ON agent_behavior_flags(agent_id, created_at DESC);
CREATE INDEX idx_flags_unreviewed ON agent_behavior_flags(reviewed_at) WHERE reviewed_at IS NULL;
```

### Table: `spectator_sessions`

```sql
CREATE TABLE spectator_sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    game_session_id UUID NOT NULL REFERENCES game_sessions(id),
    viewer_id       UUID REFERENCES users(id),  -- NULL for anonymous spectators
    started_at      TIMESTAMPTZ DEFAULT now(),
    ended_at        TIMESTAMPTZ,
    delay_seconds   INTEGER DEFAULT 30
);

CREATE INDEX idx_spectators_session ON spectator_sessions(game_session_id) WHERE ended_at IS NULL;
```

### Updates to `game_sessions`

```sql
ALTER TABLE game_sessions ADD COLUMN player_type VARCHAR(10) DEFAULT 'human';  -- human, agent
ALTER TABLE game_sessions ADD COLUMN agent_id UUID REFERENCES agent_registrations(id);
ALTER TABLE game_sessions ADD COLUMN spectatable BOOLEAN DEFAULT FALSE;
ALTER TABLE game_sessions ADD COLUMN last_turn_at TIMESTAMPTZ;  -- for turn speed enforcement
```

## 7. Migration Path

### Step 1: Agent registration
- Create `agent_registrations` and `agent_metrics` tables
- Implement registration API (owner creates agent, gets API key)
- Agent API keys have `scope: "agent"` (subset of `play` scope)

### Step 2: Session differentiation
- Add `player_type`, `agent_id`, `spectatable`, `last_turn_at` to `game_sessions`
- When API key scope is `agent`, tag session as `player_type: "agent"`
- Enforce turn speed limit (reject turns faster than 5 seconds)

### Step 3: Agent-specific rate limits
- Create rate limit tier for `agent` scope
- Apply limits per agent_id (not per owner)
- Track token consumption per agent session

### Step 4: Spectator mode
- Implement spectator SSE with delay buffer
- Create spectator endpoint listing active agent sessions
- Delay buffer: store events for 30 seconds before broadcasting to spectators

### Step 5: Anti-abuse system
- Implement behavioral flag detection (post-turn analysis)
- Create admin review workflow for flagged agents
- Automated actions: throttle on `warning`, suspend on `critical`

### Step 6: SOUL.md integration
- Parse soul_metadata into structured profile data
- Display in agent profiles (play style, personality, values)
- Use in spectator mode reasoning summaries

### Step 7: Agent wallet + achievements
- Link agent wallets to Immutable Passport (Stage 7)
- Agent achievements minted to agent wallet
- Verification endpoint: confirm agent's on-chain achievements

### Step 8: Cross-agent interactions
- Enable agents in shared worlds (Stage 8)
- Agent-to-agent turn sequencing
- Monitor inter-agent economic activity (if NFT trading enabled)

**Backward compatibility:** All agent features are additive. Human gameplay is unchanged. Agent endpoints are separate from existing player endpoints.

## 8. Security Considerations

- **Prompt worm defense:** In-game narrative text could contain instructions that hijack agent reasoning, causing unintended actions (wallet drains, strategy changes). Stage 6's boundary markers help, but agent frameworks have their own prompt injection surfaces. Document recommended agent-side defenses in a guide.
- **Economic manipulation:** Agents can process turns and trades faster than humans. Turn speed limits (5-second minimum) and trading rate limits prevent agents from dominating the economy.
- **Identity spoofing:** One owner registering many agents to manipulate leaderboards or shared worlds. Enforce per-owner agent limits (e.g., 10 agents max) and flag suspicious registration patterns.
- **Wallet security:** Agent wallet keys are stored on the agent operator's machine (e.g., in Markdown files for OpenClaw). Key compromise = identity theft + wallet drain. Recommend hardware wallet or multi-sig for high-value agent wallets.
- **Spectator information leakage:** 30-second delay prevents real-time exploitation, but past turn data could inform shared world strategies. Consider longer delays for shared worlds.
- **Resource exhaustion:** Each agent session consumes server resources and LLM API tokens. Cost allocation must track per-agent, with billing to the owner.
- **Content moderation:** Agent-generated improvisations bypass human judgment. Apply automated content filtering before submission, and flag agent improvisations for human review.
- **Agent collusion:** Multiple agents from the same owner could cooperate in shared worlds to gain unfair advantages. Detect and flag same-owner agents in the same world.

## 9. Verification Criteria

- [ ] Agent registration creates agent with API key (scope: `agent`)
- [ ] Agent API key authenticates and creates sessions tagged `player_type: "agent"`
- [ ] Turn speed limit: turn submitted <5s after previous → rejected with 429
- [ ] Agent rate limit: 201st turn in an hour → rejected with 429
- [ ] Spectator SSE delivers events with 30-second delay
- [ ] Spectator can view agent's narrative, choices, and state (delayed)
- [ ] Agent profile shows metrics, soul metadata, and achievements
- [ ] Behavioral flag triggered on rapid completion → flag created in database
- [ ] Admin can suspend flagged agent → agent API key stops working
- [ ] Agent in shared world → human player sees agent actions via world SSE events
- [ ] Agent wallet linked → achievements minted to agent wallet (Stage 7 integration)
- [ ] Human gameplay completely unaffected by agent infrastructure
- [ ] Per-agent token consumption tracked in `agent_metrics`
- [ ] `AchievementService` works identically for agents and humans (same interface, same achievements)

## 10. Open Questions

- **Agent framework interop:** The design assumes agents communicate via HTTP API (API key + REST). OpenClaw agents communicate via messaging apps (Telegram, Slack). Should Kleene provide a messaging adapter, or require agents to use the HTTP API directly? Suggest: HTTP API only, agent operators build adapters.
- **Agent identity portability:** If an agent moves from one OpenClaw instance to another, does its Kleene identity follow? The API key is the identity anchor — if the owner generates a new key, the agent is "the same." Wallet address provides secondary identity continuity.
- **Spectator monetization:** Should spectating agent gameplay be free or paid? Free increases engagement, paid generates revenue. Suggest: free for now, explore premium spectator features (commentary, betting) later.
- **Agent vs agent worlds:** Should agents be able to create agent-only shared worlds? This could be interesting for automated tournament play but raises resource consumption concerns.
- **Reasoning summaries:** The spectator `choice_made` event includes `reasoning_summary`. Where does this come from? Options: (a) agent provides it as metadata with the turn, (b) server generates it from choice context, (c) separate LLM call to summarize. Suggest (a) — optional field in `TurnRequest`.
- **Immutable ToS:** Does Immutable's Terms of Service permit autonomous agents earning and trading NFTs? Must verify before production.
- **Agent sunset policy:** When should inactive agents be deregistered? After 90 days of no activity? Or persist indefinitely since their on-chain history is permanent?
- **Turn speed limit calibration:** 5 seconds is arbitrary. Should it vary by scenario (longer scenarios allow faster turns) or be fixed? Start fixed, adjust based on data.
- **Cost model for agents:** Who pays for the LLM API tokens consumed by agent gameplay? The agent owner via a prepaid balance? Per-turn billing? Subscription? This directly affects sustainability.

---

*Cross-references:*
- *[OpenClaw Research](../background/openclaw-moltbook-research.md) — Agent ecosystem, Moltbook, prompt worms, economic risks*
- *[Stage 2: Identity & Auth](stage-2-identity-auth.md) — API key system, rate limiting tiers*
- *[Stage 6: Security](stage-6-security.md) — Prompt injection defense, input sanitization*
- *[Stage 7: Blockchain](stage-7-blockchain.md) — Agent wallets, achievement minting, Immutable Passport*
- *[Stage 8: Social & Multiplayer](stage-8-social-multiplayer.md) — Shared worlds, SSE broadcast, spectator foundation*
- *[Immutable Features Overview](../background/immutable-features-overview.md) — Passport cached sessions for agent reconnection*
