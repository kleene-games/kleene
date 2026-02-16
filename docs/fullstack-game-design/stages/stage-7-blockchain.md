# Stage 7: Blockchain Identity & Achievements (Immutable)

## 1. Overview

Stage 7 integrates Immutable Platform for blockchain-based identity (Passport) and verifiable achievement NFTs (Minting API). This is an optional layer — players who opt in get a wallet and can earn on-chain achievement tokens. Players who don't opt in continue using standard authentication and soft achievements.

**What this stage achieves:**
- `PassportAuthProvider` implementing the Stage 2 `AuthProvider` interface
- PKCE OAuth flow integration with the web frontend
- Achievement contract deployment (ERC-721 for unique achievements, ERC-1155 for milestone markers)
- Metadata schema for achievement NFTs with game-specific attributes
- Minting pipeline: game event → achievement check → mint request → on-chain confirmation
- `ImmutableAchievementService` wrapping achievement tracking with optional minting
- Sandbox and production environment management
- Feature flag for blockchain features (opt-in per user)

**Why it matters:** On-chain achievements create portable, verifiable proof of gameplay accomplishments. When combined with Stage 9 (agentic players), achievements form a trustless reputation system where agent credibility is backed by on-chain history.

## 2. Prerequisites

- **Stage 2** — `AuthProvider` interface (Passport implements it)
- **Stage 3** — Persistence (wallet addresses stored with user accounts, achievement records in database)
- **Stage 5** — Monetization (entitlement model extends to NFT-gated content)
- **Stage 6** — Security (wallet operations require hardened auth, rate limiting)

## 3. Current State

- No blockchain integration exists anywhere in the codebase
- The `AuthProvider` interface (Stage 2) supports pluggable providers — `PassportAuthProvider` plugs in
- The Immutable features overview document (`background/immutable-features-overview.md`) contains detailed integration specifications
- Achievement tracking doesn't exist yet — the closest is `cell_tracking` in the database which records Decision Grid cell discoveries

### Immutable Platform Services (from research)

| Service | Purpose | Access Method |
|---------|---------|---------------|
| **Passport** | OAuth identity + embedded wallet | PKCE flow, client-side SDK |
| **Minting API** | Server-side NFT creation | REST API with Secret API Key |
| **Indexer** | On-chain data queries + webhooks | REST API + webhook subscriptions |
| **Immutable Hub** | Admin dashboard | Web UI for contract deployment, key management |
| **Immutable Chain** | L2 (zkEVM on Ethereum) | Zero gas for players |

## 4. Target Architecture

```
Web Client
    │
    ├── Passport PKCE Flow
    │   ├── Login button → Passport popup
    │   ├── OAuth callback → access_token + id_token
    │   └── Server validates → JWT issued (with wallet_address claim)
    │
    └── Achievement Display
        ├── In-game: soft achievement notification
        └── On-chain: NFT minted, viewable in any wallet/marketplace

Server
    │
    ├── PassportAuthProvider
    │   ├── validate_passport_token(id_token) → AuthContext
    │   ├── get_wallet_address(user_id) → str
    │   └── link_passport(user_id, passport_data) → bool
    │
    ├── AchievementService (abstract)
    │   ├── check_achievement(session_id, event) → list[Achievement]
    │   ├── grant_achievement(user_id, achievement) → bool
    │   └── get_achievements(user_id) → list[Achievement]
    │
    ├── ImmutableAchievementService (extends AchievementService)
    │   ├── mint_achievement(user_id, achievement) → MintResult
    │   ├── verify_achievement(wallet, token_id) → bool
    │   └── get_on_chain_achievements(wallet) → list[OnChainAchievement]
    │
    └── Webhook Handler
        ├── imtbl_zkevm_activity_mint → confirm mint
        └── imtbl_zkevm_activity_transfer → flag unexpected transfer

Immutable Chain
    │
    ├── ERC-721 Contract: Unique Achievements
    │   └── Gold tier completion, first-ever completions, legendary plays
    │
    └── ERC-1155 Contract: Milestone Markers
        └── Bronze/Silver tier completions, scenario completions, cell discoveries
```

### PassportAuthProvider

Implements the `AuthProvider` interface from Stage 2:

```
PassportAuthProvider
├── authenticate_token(token) → AuthContext
│   Validates Immutable Passport id_token
│   Extracts wallet_address, email, sub (passport user ID)
│   Returns AuthContext with metadata: {wallet_address, passport_id}
│
├── authenticate_api_key(key) → AuthContext
│   Delegates to DatabaseAuthProvider (API keys aren't Passport-specific)
│
├── create_user(passport_data) → User
│   Creates user from Passport OAuth callback
│   Links wallet_address to user record
│
├── issue_tokens(user) → TokenPair
│   Issues Kleene JWTs (same as DatabaseAuthProvider)
│   Adds wallet_address to JWT claims
│
└── refresh_tokens(refresh_token) → TokenPair
    Standard refresh (same as DatabaseAuthProvider)
```

### Achievement Definitions

Achievements are defined as configuration, not code:

```yaml
achievements:
  # ERC-721 (unique)
  first_gold_completion:
    type: erc721
    name: "Gold Pioneer"
    description: "First player to achieve Gold tier on this scenario"
    trigger:
      event: grid_tier_reached
      conditions:
        tier: gold
        is_first: true  # checked against database
    image: "achievements/gold_pioneer.png"
    attributes:
      - trait_type: quest
        value: "{scenario_name}"
      - trait_type: completion_turns
        value: "{turn_count}"
        display_type: number

  # ERC-1155 (fungible milestones)
  bronze_completion:
    type: erc1155
    name: "Bronze Explorer"
    description: "Achieved Bronze tier Decision Grid coverage"
    trigger:
      event: grid_tier_reached
      conditions:
        tier: bronze
    image: "achievements/bronze_explorer.png"
    attributes:
      - trait_type: quest
        value: "{scenario_name}"
```

## 5. Interface Contracts

### Passport Auth Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/auth/passport/login` | Initiate PKCE flow (returns auth URL) |
| `GET` | `/api/v1/auth/passport/callback` | OAuth callback (exchanges code for tokens) |
| `POST` | `/api/v1/auth/passport/link` | Link Passport to existing account |
| `DELETE` | `/api/v1/auth/passport/unlink` | Unlink Passport from account |

### Passport Login Flow

```
1. Client: GET /api/v1/auth/passport/login
   Server generates PKCE challenge (code_verifier, code_challenge)
   Returns: {auth_url: "https://passport.immutable.com/authorize?..."}

2. Client redirects to auth_url (Passport popup/redirect)

3. User authenticates with Immutable Passport

4. Passport redirects to: /api/v1/auth/passport/callback?code=...&state=...

5. Server exchanges code for tokens:
   POST https://auth.immutable.com/oauth/token
   {
     grant_type: "authorization_code",
     code: "...",
     code_verifier: "...",
     client_id: "{IMMUTABLE_CLIENT_ID}",
     redirect_uri: "{CALLBACK_URL}"
   }

6. Server validates id_token, extracts:
   - sub (Passport user ID)
   - email
   - wallet_address (via eth_requestAccounts after auth)

7. Server creates/updates user, issues Kleene JWT
   Returns: {tokens: {access_token, refresh_token}, user: {...}}
```

### Achievement Endpoints

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| `GET` | `/api/v1/achievements` | User's achievements (soft + on-chain) | Authenticated |
| `GET` | `/api/v1/achievements/{id}` | Achievement detail | Authenticated |
| `GET` | `/api/v1/achievements/verify/{wallet}` | Verify on-chain achievements | Anonymous |
| `POST` | `/api/v1/achievements/opt-in` | Enable blockchain achievements | Authenticated + Passport |

### Achievement Response

```json
{
  "achievements": [
    {
      "id": "ach_a1b2c3",
      "definition_id": "bronze_completion",
      "name": "Bronze Explorer",
      "description": "Achieved Bronze tier Decision Grid coverage",
      "scenario_id": "dragon_quest",
      "earned_at": "2026-02-15T10:00:00Z",
      "on_chain": true,
      "token": {
        "contract_address": "0x...",
        "token_id": "42",
        "chain": "imtbl-zkevm-mainnet",
        "mint_status": "confirmed",
        "transaction_hash": "0x..."
      }
    },
    {
      "id": "ach_d4e5f6",
      "definition_id": "gold_completion",
      "name": "Gold Champion",
      "earned_at": "2026-02-15T11:30:00Z",
      "on_chain": false,
      "reason": "Blockchain features not enabled"
    }
  ]
}
```

### Minting Pipeline

```
Game Event (grid_tier_reached, scenario_completed, etc.)
    │
    v
AchievementService.check_achievement(session_id, event)
    │ Returns list of triggered achievements
    v
For each achievement:
    │
    ├── Store soft achievement in database (always)
    │
    └── IF user has opted in to blockchain AND has linked wallet:
        │
        ImmutableAchievementService.mint_achievement(user_id, achievement)
        │
        ├── Build metadata JSON (name, description, image, attributes)
        │
        ├── POST /v1/chains/{chain}/collections/{contract}/nfts/mint-requests
        │   Headers: x-immutable-api-key: {SECRET_API_KEY}
        │   Body: {
        │     assets: [{
        │       reference_id: "ach-{achievement_id}-{user_id}",
        │       owner_address: "{wallet_address}",
        │       metadata: { ... }
        │     }]
        │   }
        │
        ├── Store mint request ID in database (status: "pending")
        │
        └── Webhook confirms mint → update status to "confirmed"
```

**Idempotency:** `reference_id` ensures the same achievement is never minted twice for the same user.

### Immutable Webhook Handler

```
POST /api/v1/webhooks/immutable
X-Immutable-Signature: ...

Events:
├── imtbl_zkevm_activity_mint
│   → Update achievement mint_status to "confirmed"
│   → Store transaction_hash and token_id
│
└── imtbl_zkevm_activity_transfer
    → Log unexpected transfer (possible account compromise)
    → Flag for investigation if recipient != owner
```

### NFT Metadata Schema

```json
{
  "name": "Gold Pioneer - The Dragon's Choice",
  "description": "First player to achieve Gold tier Decision Grid coverage on The Dragon's Choice",
  "image": "https://kleene.game/achievements/gold_pioneer_dragon_quest.png",
  "external_url": "https://kleene.game/achievements/ach_a1b2c3",
  "animation_url": null,
  "attributes": [
    {"trait_type": "quest", "value": "The Dragon's Choice"},
    {"trait_type": "tier", "value": "Gold"},
    {"trait_type": "completion_turns", "value": 18, "display_type": "number"},
    {"trait_type": "cells_discovered", "value": 9, "display_type": "number"},
    {"trait_type": "completion_date", "value": 1739577600, "display_type": "date"},
    {"trait_type": "player_type", "value": "human"}
  ]
}
```

Metadata is included with the mint request (not hosted at a separate URI).

## 6. Data Model

### Updates to `users` table

```sql
ALTER TABLE users ADD COLUMN passport_id VARCHAR(255) UNIQUE;
ALTER TABLE users ADD COLUMN wallet_address VARCHAR(42);
ALTER TABLE users ADD COLUMN blockchain_opted_in BOOLEAN DEFAULT FALSE;

CREATE INDEX idx_users_passport ON users(passport_id) WHERE passport_id IS NOT NULL;
CREATE INDEX idx_users_wallet ON users(wallet_address) WHERE wallet_address IS NOT NULL;
```

### Table: `achievements`

```sql
CREATE TABLE achievements (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id),
    session_id      UUID REFERENCES game_sessions(id),
    scenario_id     VARCHAR(100) REFERENCES scenarios(id),
    definition_id   VARCHAR(100) NOT NULL,  -- "bronze_completion", "gold_pioneer"
    name            VARCHAR(255) NOT NULL,
    earned_at       TIMESTAMPTZ DEFAULT now(),
    on_chain        BOOLEAN DEFAULT FALSE,
    mint_request_id VARCHAR(255),
    mint_status     VARCHAR(20),  -- pending, confirmed, failed
    token_id        VARCHAR(100),
    contract_address VARCHAR(42),
    transaction_hash VARCHAR(66),
    metadata        JSONB DEFAULT '{}',
    UNIQUE(user_id, definition_id, scenario_id)
);

CREATE INDEX idx_achievements_user ON achievements(user_id);
CREATE INDEX idx_achievements_mint ON achievements(mint_request_id) WHERE on_chain = TRUE;
```

### Table: `achievement_definitions`

```sql
CREATE TABLE achievement_definitions (
    id              VARCHAR(100) PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    description     TEXT,
    type            VARCHAR(10) NOT NULL,  -- erc721, erc1155
    trigger_event   VARCHAR(100) NOT NULL,
    trigger_conditions JSONB NOT NULL,
    image_url       VARCHAR(500),
    attributes_template JSONB DEFAULT '[]',
    contract_address VARCHAR(42),  -- which contract to mint on
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT now()
);
```

## 7. Migration Path

### Step 1: Immutable Hub setup
- Register Kleene as OAuth 2.0 client in Immutable Hub
- Configure redirect URIs (sandbox and production)
- Deploy ERC-721 and ERC-1155 preset contracts (no Solidity needed)
- Generate Secret API Key for server-side minting

### Step 2: Configuration
- Add to `ServerConfig`: `immutable_client_id`, `immutable_client_secret`, `immutable_api_key`, `immutable_environment` (`sandbox` | `production`)
- Add feature flag: `blockchain_enabled: bool = False`

### Step 3: PassportAuthProvider
- Implement PKCE flow (code challenge generation, token exchange)
- Implement token validation (id_token verification with Immutable's JWKS)
- Integrate with user creation/linking

### Step 4: AchievementService
- Create abstract `AchievementService` interface
- Create `DatabaseAchievementService` (soft achievements, always active)
- Create `ImmutableAchievementService` (extends database service with minting)
- Hook into game events (cell discovery, scenario completion, grid tier changes)

### Step 5: Minting pipeline
- Implement mint request creation via Immutable Minting API
- Implement webhook handler for mint confirmations
- Test full pipeline in sandbox environment

### Step 6: Frontend integration
- Add "Connect Passport" button to user profile
- Add achievement display with on-chain/off-chain indicators
- Add opt-in toggle for blockchain features

### Step 7: Achievement definitions
- Create initial set of achievement definitions
- Load from YAML config or database
- Test triggers against game events

**Backward compatibility:** Blockchain features are entirely opt-in. Users without Passport continue using standard auth and earn soft achievements. The `AchievementService` interface is identical for both paths.

## 8. Security Considerations

- **Passport token validation:** Always validate id_tokens against Immutable's JWKS endpoint. Never trust client-provided tokens without server-side verification.
- **Secret API Key protection:** The Minting API key can create NFTs — it must never be exposed to clients. Store as environment variable, rotate periodically.
- **Wallet address verification:** When linking a wallet, verify ownership via a signed message challenge. Don't trust client-provided addresses blindly.
- **Mint rate limiting:** Minting has API rate limits (200/min standard, 2000/min partner). Implement server-side queue to stay within limits.
- **Achievement farming:** Prevent users from replaying scenarios to re-earn achievements. The `UNIQUE(user_id, definition_id, scenario_id)` constraint prevents duplicate grants.
- **Transfer detection:** Monitor for unexpected token transfers (via Indexer webhooks). Transfers to unknown addresses may indicate account compromise.
- **Sandbox vs production:** Use environment-specific configuration. Never point sandbox code at production contracts.
- **Gas costs:** Immutable Chain has zero gas for players, but deployers pay in IMX. Budget for contract deployment and ongoing minting costs.

## 9. Verification Criteria

- [ ] Passport PKCE login flow works end-to-end (browser → Passport → callback → JWT)
- [ ] `PassportAuthProvider` returns `AuthContext` with `wallet_address` in metadata
- [ ] User can link/unlink Passport from existing account
- [ ] Soft achievements granted without blockchain opt-in
- [ ] Blockchain opt-in + achievement trigger → mint request created
- [ ] Mint webhook → achievement status updated to "confirmed" with token_id
- [ ] Duplicate achievement trigger → no duplicate mint (idempotent)
- [ ] `GET /achievements/verify/{wallet}` returns on-chain achievements for any wallet
- [ ] Achievement metadata includes correct game-specific attributes
- [ ] Sandbox environment fully functional before production deployment
- [ ] Feature flag: `blockchain_enabled: false` → all Passport/minting features disabled
- [ ] `AchievementService` interface is the same one referenced by Stage 9 (agent achievements)

## 10. Open Questions

- **ERC-721 vs ERC-1155 criteria:** Which achievements are unique (721) vs milestone (1155)? Suggest: "first-ever" achievements are 721, repeatable milestones are 1155. But what about "Gold tier on a specific scenario" — unique per scenario or repeatable?
- **Achievement image hosting:** Where are achievement images stored? IPFS for immutability? CDN for performance? Immutable recommends CDN with fallback.
- **Cross-scenario achievements:** Can achievements span multiple scenarios (e.g., "Complete 5 different scenarios")? This requires a meta-achievement system that tracks across scenario boundaries.
- **Achievement revocation:** Can on-chain achievements be revoked (e.g., if earned through exploits)? ERC-721/1155 tokens can't be burned by the issuer. This is a one-way operation — mint carefully.
- **Immutable ToS for agents:** Stage 9 enables agentic players. Immutable's ToS may not explicitly cover autonomous agents earning and trading NFTs. Investigate before production.
- **IMX gas budget:** Deploying contracts and minting costs IMX tokens. Estimate monthly costs based on projected player/achievement volume.
- **Multi-wallet support:** Can a user link multiple wallets? Suggest: one primary wallet for minting, but display achievements from any linked wallet.

---

*Cross-references:*
- *[Immutable Features Overview](../background/immutable-features-overview.md) — Complete Immutable Platform integration guide*
- *[Stage 2: Identity & Auth](stage-2-identity-auth.md) — AuthProvider interface*
- *[Stage 5: Monetization](stage-5-monetization.md) — Entitlement model*
- *[Stage 9: Agentic Players](stage-9-agentic-players.md) — Agent wallets and achievement verification*
- *[OpenClaw Research](../background/openclaw-moltbook-research.md) — Agent economy and NFT trading*
