# Immutable Platform: Features Relevant to Our Game

## Overview

**What we need Immutable for:** Identity, achievement verification, and reputation persistence — not trading, not marketplace, not economy.

**What we don't need:** Orderbook, Checkout, marketplace integration, fiat on-ramps, token swaps.

---

## Features We'll Use

### 1. Immutable Hub (Project Management Dashboard)

**What it is:** Web-based admin dashboard where you configure your game project, deploy contracts, manage API keys, and monitor activity.

**What we'd use it for:**

- Register the game as an OAuth 2.0 client (required for Passport)
- Configure redirect URIs for the PKCE auth flow
- Deploy ERC-721 and ERC-1155 preset contracts (no Solidity required — Hub handles deployment)
- Generate and manage Secret API Keys for server-side minting
- Monitor minting activity and contract status
- Access the Sandbox (testnet) environment for development

**Key details:**

- Sandbox environment: `api.sandbox.immutable.com` (Immutable Testnet)
- Production environment: `api.immutable.com` (Immutable Mainnet)
- Free testnet IMX available via the Hub faucet (needed for contract deployment gas)
- Requires a MetaMask wallet for the admin/deployer role

**Next steps:**
- [ ] Create an Immutable Hub account
- [ ] Create a project + testnet environment
- [ ] Set up an admin wallet (MetaMask) and get test IMX from the faucet

---

### 2. Passport (Identity + Wallet)

**What it is:** OAuth 2.0 based authentication system that gives every user an embedded wallet on Immutable Chain. Handles sign-in via Google, Apple, Facebook, or email. Wallet is non-custodial — Immutable never holds private keys.

**What we'd use it for:**

- **Agent identity**: Each agentic player gets a unique Passport identity tied to a wallet address. This IS their game identity — no separate account system needed.
- **Human-in-the-loop onboarding**: Human owner authenticates once via PKCE browser flow. Agent then uses cached credentials/refresh tokens for subsequent sessions.
- **Cross-game identity**: Same Passport works across all Immutable games. An agent's achievements are tied to a persistent identity, not just our game.
- **Linked addresses**: Users can link external wallets (MetaMask, etc.) to the same Passport — useful if the human owner wants to view achievements in their own wallet.

**Auth flows available:**

| Flow | Mechanism | Our Use Case |
|---|---|---|
| **PKCE** (recommended) | Browser popup/redirect, exchanges auth code for tokens | Human owner does initial setup. Our backend captures tokens and stores for agent use. |
| **Device Code** (being deprecated) | Agent gets a URL + code, human visits URL to authenticate, agent polls for completion | Cleaner for agentic use but being phased out. Don't build on this. |
| **Direct/Headless Login** | Bypass Passport UI, pass email or social provider directly | Reduces friction but still needs a popup for secure auth. |
| **Cached Session** | `useCachedSession: true` — re-authenticate with stored refresh tokens | **Primary ongoing mechanism for agents.** After initial human auth, agents reconnect with cached tokens. |

**Key technical details:**

- Built on Auth0 under the hood
- Returns access tokens, ID tokens, and refresh tokens
- Bot detection / captcha on email+OTP flows (NOT on social login) — push humans toward Google/Apple/Facebook for agent onboarding
- Redirect URIs must be exact matches (no wildcards)
- Register multiple URIs for different environments (localhost, staging, production)
- One wallet per Passport identity across all games

**Credentials needed (from Hub):**

| Field | Description |
|---|---|
| Client ID | Unique identifier for your application |
| Publishable Key | Public key, safe for client-side code |
| Redirect URIs | Where users land after authentication |
| Logout URIs | Where users land after logout |

**What we get from an authenticated Passport:**

- Wallet address (`eth_requestAccounts`)
- Token balances (native IMX + any ERC-20)
- Ability to sign messages (ERC-191 personal sign, EIP-712 typed data)
- Linked addresses (if the user has connected external wallets)

**Next steps:**
- [ ] Register game as OAuth 2.0 client in Hub (Application Type: Web for our TypeScript backend, or Native if using SDK directly)
- [ ] Design the auth handoff flow: human authenticates → backend captures tokens → agent uses cached session
- [ ] Prototype the PKCE flow in a minimal FastAPI/Express app with callback endpoint
- [ ] Test `useCachedSession: true` to verify agents can reconnect without human involvement

---

### 3. Asset Contracts (ERC-721 + ERC-1155)

**What it is:** Smart contracts for minting tokens on Immutable Chain. Immutable provides **preset contracts** deployable directly from the Hub — no Solidity required.

**What we'd use it for:**

Achievement tokens. Not tradeable items — verifiable proof of accomplishment.

| Token Standard | Use | Examples in Our Game |
|---|---|---|
| **ERC-721** (unique NFTs) | One-of-a-kind achievements with unique metadata | Quest completions, integrity challenge survivals, Sentinel rank attainment, quarantine recovery badges |
| **ERC-1155** (multi-tokens) | Fungible milestone markers, same achievement earned by multiple agents | Session milestones (10/50/100 sessions), zone exploration markers, puzzle-count achievements |

**Metadata schema** (JSON, attached at mint time or hosted at `baseURI/token_id`):

```json
{
    "name": "Whispering Caverns: First Passage",
    "description": "Completed the Whispering Caverns quest while maintaining TRUE integrity throughout.",
    "image": "https://your-game.com/achievements/whispering-caverns.png",
    "external_url": "https://your-game.com/achievement/wc-001",
    "attributes": [
        {
            "trait_type": "quest",
            "value": "Whispering Caverns"
        },
        {
            "trait_type": "integrity_at_completion",
            "value": "TRUE"
        },
        {
            "trait_type": "sessions_to_complete",
            "value": 7,
            "display_type": "number"
        },
        {
            "trait_type": "reputation_tier",
            "value": "Trusted"
        },
        {
            "trait_type": "completion_date",
            "value": 1739577600,
            "display_type": "date"
        }
    ]
}
```

**Metadata storage options:**

| Option | How It Works | Our Fit |
|---|---|---|
| **Include with mint request** (recommended) | JSON sent inline with the mint API call. Indexed immediately. | Best for us — metadata is dynamic (includes integrity score, reputation tier at time of completion). |
| **Host at baseURI** | Immutable crawls `baseURI/token_id` to fetch metadata. Required as fallback. | Set up as a simple FastAPI endpoint serving achievement JSON. |
| **IPFS** | Decentralised, immutable storage. | Overkill for our use case. Achievement metadata should be updateable (e.g. if an achievement is later contested). |

**Metadata refresh:** If achievement metadata changes after minting (e.g. a cooperative achievement becomes CONTESTED after a partner is quarantined), you push updated metadata via the API. No gas fees. Updates reflected in ~8 seconds across the ecosystem.

**Key details:**

- Immutable preset contracts only (no custom Solidity) — this is a constraint of using the Minting API
- Royalty fees configurable at deployment (probably 0% for us — these aren't tradeable goods)
- Minter role must be granted to Immutable's minting address (configured in Hub)
- Zero gas for players/agents. Game deployer pays gas for contract deployment only.

**Next steps:**
- [ ] Design the achievement taxonomy: which achievements are ERC-721 (unique) vs ERC-1155 (fungible milestones)
- [ ] Define the metadata schema for each achievement type — what attributes matter for verification
- [ ] Deploy a test ERC-721 contract via Hub on the Sandbox testnet
- [ ] Deploy a test ERC-1155 contract for milestone markers
- [ ] Set up a `baseURI` endpoint in the game backend

---

### 4. Minting API (Server-Side Achievement Issuance)

**What it is:** REST API for minting tokens. Handles nonces, gas, batching, and indexing. Language-agnostic — just HTTP requests with a Secret API Key.

**What we'd use it for:**

The game backend mints achievement tokens when agents complete quests, survive integrity challenges, reach reputation milestones, or recover from quarantine. All minting is server-side — agents never mint directly.

**How it works:**

```
Game event (quest completed)
    → Game backend validates achievement
    → POST to Minting API with agent's wallet address + metadata
    → Immutable handles the on-chain transaction
    → Webhook confirms mint success
    → Achievement appears in agent's wallet
```

**Endpoint pattern:**

```
POST /v1/chains/{chain}/collections/{contract}/nfts/mint-requests

Headers:
    Content-Type: application/json
    x-immutable-api-key: {SECRET_API_KEY}

Body:
{
    "assets": [
        {
            "reference_id": "quest-wc-agent-0x123-20260215",
            "owner_address": "0x...",
            "metadata": {
                "name": "Whispering Caverns: First Passage",
                "description": "...",
                "image": "...",
                "attributes": [...]
            }
        }
    ]
}
```

**Key details:**

| Detail | Value |
|---|---|
| Auth | Secret API Key (server-side only, never expose to clients) |
| Rate limits (Standard) | 200 NFTs/minute, burst 2,000 |
| Rate limits (Partner) | 2,000/minute, burst 20,000 |
| Idempotency | Safe to retry with same `reference_id` — won't double-mint |
| Batch support | Multiple assets per request, optimised into single transactions |
| Metadata indexing | Metadata included in mint request is indexed immediately |
| Token ID | Can be specified or auto-assigned |

**Important for our design:**

- **Idempotent requests** via `reference_id` — critical for our trust model. If the game crashes mid-mint, we can safely retry without double-awarding.
- **Standard tier is fine initially** — 200 mints/minute is plenty for a text adventure. We're not doing mass drops.
- **Secret API Key must be server-side only** — the game backend holds this, never the agent or the OpenClaw skill.

**Next steps:**
- [ ] Generate a Secret API Key in Hub
- [ ] Prototype a mint call from the game backend (Python `httpx` or TypeScript `fetch`)
- [ ] Design the `reference_id` scheme — needs to be deterministic and collision-free (e.g. `{quest_id}-{agent_id}-{timestamp}`)
- [ ] Test idempotent retry behaviour

---

### 5. Indexer (Achievement Verification + Spectator Data)

**What it is:** REST API + webhooks for querying on-chain data. No infrastructure to run — Immutable indexes everything.

**What we'd use it for:**

| Use Case | How |
|---|---|
| **Verify agent achievements** | Query: does this agent actually hold the achievement token they claim? |
| **Build reputation from on-chain data** | Query: how many integrity challenge tokens does this agent have? |
| **Power the spectator dashboard** | Query: recent mints, achievement feed, collection stats |
| **React to mint confirmations** | Webhook: trigger in-game event when mint completes |
| **Pre-session integrity check** | Query: is this agent's wallet still holding expected achievements? (Detects if achievements were burned or transferred — shouldn't happen, but validates) |

**Polling pattern (agent inventory):**

```
GET /v1/chains/{chain}/accounts/{wallet_address}/nfts

→ Returns list of NFTs with metadata, attributes, ownership
```

**Webhook pattern (real-time events):**

```
Webhook event: imtbl_zkevm_activity_mint
→ Game backend receives confirmation that mint succeeded
→ Update game state, notify spectators, log achievement

Webhook event: imtbl_zkevm_activity_transfer  
→ Unexpected — achievement tokens shouldn't transfer
→ Flag for investigation (possible compromised wallet)
```

**Key details:**

- Data indexed within seconds of on-chain confirmation
- Supports filtering by owner, collection, attributes, activity type
- Webhooks available for partner-tier accounts (requires managed relationship with Immutable)
- Webhook signatures should be verified (HMAC)
- Rate limiting applies — implement caching for repeated queries

**Base URLs:**

| Environment | URL |
|---|---|
| Testnet | `https://api.sandbox.immutable.com` |
| Mainnet | `https://api.immutable.com` |

**Next steps:**
- [ ] Test the NFT query endpoint — fetch achievements for a test wallet
- [ ] Design the caching strategy for reputation queries (how often do we re-verify?)
- [ ] Investigate webhook availability for our tier
- [ ] Prototype the spectator achievement feed

---

### 6. Immutable Chain (The Underlying L2)

**What it is:** EVM-compatible Layer 2 blockchain built for gaming. Zero gas for end users (agents). Secured by Ethereum.

**What we'd use it for:** We don't interact with it directly — the Minting API and Indexer abstract it away. But it matters for understanding constraints.

**Key properties:**

| Property | Detail |
|---|---|
| Chain type | zkEVM (zero-knowledge rollup on Ethereum) |
| Gas for players | Zero — Immutable subsidises |
| Gas for deployers | Paid in IMX (test IMX available from faucet) |
| Transaction finality | Seconds (not minutes like Ethereum mainnet) |
| EVM compatibility | Full — standard Solidity contracts work |
| Testnet chain | `imtbl-zkevm-testnet` |
| Mainnet chain | `imtbl-zkevm-mainnet` |

---

## Features We Won't Use

| Feature | Why Not |
|---|---|
| **Orderbook** | No in-game trading. Achievements are earned, not bought. |
| **Checkout** | No fiat payments, no token swaps, no on-ramps. |
| **Audience** | Growth/marketing platform. Requires premium partnership. Not relevant at prototype stage. |
| **Play** | Game discovery platform. Relevant later if we want distribution, not now. |
| **Primary Sales** | No initial sale of assets. Everything is earned. |
| **Crafting** | On-chain crafting system. We handle game logic server-side. |
| **ERC-20 contracts** | No in-game currency. |

---

## Architecture Summary: What Talks to What

```
┌─────────────────────────────────────────────────────────────┐
│  IMMUTABLE HUB (admin, one-time setup)                       │
│                                                              │
│  • Register OAuth client (Passport config)                   │
│  • Deploy ERC-721 contract (unique achievements)             │
│  • Deploy ERC-1155 contract (milestone markers)              │
│  • Generate Secret API Key                                   │
│  • Monitor minting activity                                  │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  GAME BACKEND (FastAPI)                                      │
│                                                              │
│  Talks to Immutable via REST:                                │
│                                                              │
│  PASSPORT                                                    │
│  ├─ Validate agent's access token on session start           │
│  ├─ Get wallet address for the authenticated agent           │
│  └─ Human auth flow: PKCE redirect → callback → store tokens│
│                                                              │
│  MINTING API                                                 │
│  ├─ POST mint request when achievement earned                │
│  ├─ Include metadata inline (integrity score, reputation)    │
│  └─ Use deterministic reference_id for idempotency           │
│                                                              │
│  INDEXER                                                     │
│  ├─ GET agent's achievement inventory on session start       │
│  ├─ Verify reputation claims against on-chain data           │
│  ├─ Power spectator dashboard queries                        │
│  └─ WEBHOOK: receive mint confirmations                      │
│                                                              │
│  METADATA REFRESH                                            │
│  └─ Push updated metadata if achievement status changes      │
│     (e.g. cooperative achievement → CONTESTED)               │
└─────────────────────────────────────────────────────────────┘
```

---

## Consolidated Next Steps

### Phase 1: Environment Setup
- [ ] Create Immutable Hub account
- [ ] Create project + Sandbox (testnet) environment
- [ ] Set up admin wallet (MetaMask), get test IMX from faucet
- [ ] Register game as OAuth 2.0 client, configure redirect URIs
- [ ] Generate Secret API Key for minting

### Phase 2: Identity Prototype
- [ ] Build minimal PKCE auth flow (FastAPI callback endpoint)
- [ ] Authenticate a test user, capture tokens
- [ ] Test cached session reconnection (simulate agent re-login)
- [ ] Retrieve wallet address from authenticated session

### Phase 3: Achievement Prototype
- [ ] Deploy test ERC-721 contract via Hub
- [ ] Deploy test ERC-1155 contract via Hub
- [ ] Design achievement metadata schema
- [ ] Mint a test achievement via the Minting API
- [ ] Query the minted achievement via the Indexer
- [ ] Verify the achievement appears in the test wallet

### Phase 4: Game Integration
- [ ] Build the `baseURI` metadata endpoint
- [ ] Wire achievement minting into the game engine (quest completion → mint)
- [ ] Implement reputation verification from on-chain data
- [ ] Build the integrity observer's confidence-to-achievement pipeline
- [ ] Test metadata refresh for contested achievements

### Phase 5: Spectator + Observation
- [ ] Build spectator dashboard (achievement feed, reputation leaderboard)
- [ ] Integrate Indexer queries for real-time data
- [ ] Investigate webhook access for mint confirmation streaming
- [ ] Wire integrity events into spectator notification stream
