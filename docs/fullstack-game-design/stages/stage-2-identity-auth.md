# Stage 2: Identity & Authentication

## 1. Overview

Stage 2 adds user identity and authentication to Kleene. The system must support multiple auth strategies (local development with no auth, API keys for programmatic access, OAuth for web login) through a single abstraction. JWT tokens provide stateless session verification. Rate limiting prevents abuse per auth tier.

**What this stage achieves:**
- `AuthProvider` abstraction supporting pluggable authentication backends
- JWT-based token management (access + refresh)
- API key system with scoped permissions (play, admin, store)
- Rate limiting per authentication tier
- Middleware that wraps existing routes without modifying route logic
- Backward-compatible anonymous mode for local development

**Why it matters:** Every feature from Stage 3 onward (persistence, monetization, social, blockchain) requires knowing who the user is. This stage establishes identity without coupling to any specific provider.

## 2. Prerequisites

- **Stage 1** — Versioned API (`/api/v1/`), standardized error responses, session state machine

## 3. Current State

- **No authentication exists.** All 17+ endpoints are fully open.
- `config.py` defines `admin_key: str | None` but it is never checked by any route or middleware.
- `pyproject.toml` lists no auth libraries (no PyJWT, no python-jose, no passlib).
- `cors_origins` is `["*"]` — no origin restriction.
- Sessions are identified by short UUIDs (`uuid4()[:8]`) with no ownership association.
- The web frontend makes unauthenticated `fetch()` calls to the local server.

## 4. Target Architecture

```
Client Request
    │
    ├── Authorization: Bearer <jwt>      (web sessions)
    ├── X-API-Key: <key>                 (programmatic access)
    └── (none)                           (anonymous/local mode)
    │
    v
┌──────────────────────────────────────────┐
│           Auth Middleware                  │
│                                          │
│  1. Extract credentials from request     │
│  2. Resolve to AuthContext via Provider   │
│  3. Attach AuthContext to request state   │
│  4. Rate limit check per tier            │
│  5. Pass to route handler                │
└──────────────────────────────────────────┘
    │
    v
Route Handler
    │
    └── Reads request.state.auth: AuthContext
        ├── user_id: str | None
        ├── tier: "anonymous" | "authenticated" | "api_key" | "admin"
        ├── scopes: set[str]
        └── rate_limit: RateLimitConfig
```

### AuthProvider Interface

```
AuthProvider (abstract)
├── authenticate_token(token: str) → AuthContext | None
├── authenticate_api_key(key: str) → AuthContext | None
├── create_user(email, password_hash) → User
├── get_user(user_id) → User | None
├── issue_tokens(user) → TokenPair {access_token, refresh_token, expires_in}
└── refresh_tokens(refresh_token) → TokenPair | None
```

**Implementations:**

| Provider | When | Storage |
|----------|------|---------|
| `LocalAuthProvider` | Local development mode | None — returns anonymous context for all requests |
| `DatabaseAuthProvider` | Remote server mode | PostgreSQL users table (Stage 3) |
| `PassportAuthProvider` | Blockchain mode (Stage 7) | Immutable Passport OAuth |

The provider is selected at startup based on `ServerConfig.mode`:
- `mode: "local"` → `LocalAuthProvider` (all requests get anonymous admin access)
- `mode: "remote"` → `DatabaseAuthProvider`

### AuthContext

```
AuthContext
├── user_id: str | None          (None for anonymous)
├── tier: str                    (anonymous | authenticated | api_key | admin)
├── scopes: set[str]             (play, save, store, admin)
├── rate_limit: RateLimitConfig
│   ├── requests_per_minute: int
│   └── requests_per_hour: int
└── metadata: dict[str, Any]     (provider-specific: wallet_address, etc.)
```

## 5. Interface Contracts

### Auth Endpoints

| Method | Path | Description | Auth Required |
|--------|------|-------------|---------------|
| `POST` | `/api/v1/auth/register` | Create account (email + password) | No |
| `POST` | `/api/v1/auth/login` | Login, receive JWT pair | No |
| `POST` | `/api/v1/auth/refresh` | Exchange refresh token for new pair | Refresh token |
| `POST` | `/api/v1/auth/logout` | Invalidate refresh token | Access token |
| `GET` | `/api/v1/auth/me` | Current user profile | Access token |
| `POST` | `/api/v1/auth/api-keys` | Generate new API key | Access token |
| `GET` | `/api/v1/auth/api-keys` | List user's API keys | Access token |
| `DELETE` | `/api/v1/auth/api-keys/{key_id}` | Revoke API key | Access token |

### Registration

```
POST /api/v1/auth/register
Content-Type: application/json

{
  "email": "player@example.com",
  "password": "...",
  "display_name": "DragonSlayer"
}

→ 201 Created
{
  "user_id": "usr_a1b2c3",
  "email": "player@example.com",
  "display_name": "DragonSlayer",
  "tokens": {
    "access_token": "eyJ...",
    "refresh_token": "eyJ...",
    "expires_in": 3600
  }
}
```

### Login

```
POST /api/v1/auth/login
Content-Type: application/json

{
  "email": "player@example.com",
  "password": "..."
}

→ 200 OK
{
  "user_id": "usr_a1b2c3",
  "tokens": {
    "access_token": "eyJ...",
    "refresh_token": "eyJ...",
    "expires_in": 3600
  }
}
```

### JWT Structure

**Access Token Claims:**
```json
{
  "sub": "usr_a1b2c3",
  "tier": "authenticated",
  "scopes": ["play", "save"],
  "iat": 1739577600,
  "exp": 1739581200,
  "iss": "kleene-server"
}
```

- **Lifetime:** 1 hour (access), 30 days (refresh)
- **Algorithm:** HS256 with server-side secret (sufficient for single-server; RS256 for distributed)
- **Refresh token:** Opaque, stored server-side, single-use (rotation on each refresh)

### API Key Structure

```
API Key format: kln_{scope}_{random_32_chars}
Examples:
  kln_play_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
  kln_admin_x9y8z7w6v5u4t3s2r1q0p9o8n7m6l5k4
```

**Scopes:**

| Scope | Permissions |
|-------|------------|
| `play` | Start sessions, submit turns, save/load, read scenarios |
| `store` | All of `play` + purchase scenarios, manage entitlements |
| `admin` | All permissions + scenario upload, user management, diagnostics |

### Rate Limits

| Tier | Requests/min | Requests/hour | Concurrent SSE |
|------|-------------|---------------|----------------|
| `anonymous` | 30 | 300 | 1 |
| `authenticated` | 120 | 3000 | 3 |
| `api_key` | 300 | 10000 | 10 |
| `admin` | unlimited | unlimited | unlimited |

Rate limit headers on every response:
```
X-RateLimit-Limit: 120
X-RateLimit-Remaining: 117
X-RateLimit-Reset: 1739577660
```

When exceeded:
```
429 Too Many Requests
{
  "error": {
    "code": "RATE_LIMITED",
    "message": "Rate limit exceeded. Retry after 23 seconds.",
    "retry_after": 23
  }
}
```

### Auth Error Codes

| HTTP Status | Error Code | When |
|-------------|-----------|------|
| 401 | `AUTH_REQUIRED` | No credentials provided on protected endpoint |
| 401 | `TOKEN_EXPIRED` | JWT access token has expired |
| 401 | `TOKEN_INVALID` | JWT signature verification failed |
| 401 | `API_KEY_INVALID` | API key not found or revoked |
| 403 | `INSUFFICIENT_SCOPE` | Valid auth but missing required scope |
| 409 | `EMAIL_EXISTS` | Registration with existing email |
| 422 | `WEAK_PASSWORD` | Password doesn't meet requirements |

### Route Protection

Endpoints gain an auth requirement annotation:

| Endpoint Category | Required Tier | Required Scope |
|-------------------|--------------|----------------|
| `GET /scenarios`, `GET /scenario/{id}/*` | anonymous | — |
| `POST /game/start`, `POST /game/{id}/turn` | anonymous | `play` (if authenticated) |
| `POST /game/{id}/save`, `POST /game/load/*` | authenticated | `save` |
| `POST /scenario/{id}/reload` | admin | `admin` |
| `GET /game/sessions` | authenticated | — (scoped to own sessions) |

**Key principle:** In local mode (`LocalAuthProvider`), all requests pass through with anonymous-admin context. No route logic changes — only the middleware behavior differs.

### Session Ownership

When auth is active, sessions are bound to users:
- `POST /game/start` associates `session.user_id = auth.user_id`
- `GET /game/sessions` filters to `user_id = auth.user_id` (admin sees all)
- `POST /game/{id}/turn` verifies `session.user_id == auth.user_id`
- Anonymous users can create sessions but cannot persist them across server restarts (Stage 3)

## 6. Data Model

### Users Table (created in Stage 3, schema defined here)

```
users
├── id: UUID (primary key)
├── email: str (unique, indexed)
├── password_hash: str
├── display_name: str
├── tier: str ("authenticated" default)
├── created_at: timestamp
├── updated_at: timestamp
└── is_active: bool (default true)
```

### API Keys Table

```
api_keys
├── id: UUID (primary key)
├── user_id: UUID (foreign key → users)
├── key_hash: str (indexed, bcrypt hash of key)
├── key_prefix: str (first 12 chars for identification: "kln_play_a1b2")
├── scope: str ("play" | "store" | "admin")
├── name: str (user-assigned label)
├── created_at: timestamp
├── last_used_at: timestamp | null
├── revoked_at: timestamp | null
└── expires_at: timestamp | null
```

### Refresh Tokens Table

```
refresh_tokens
├── id: UUID (primary key)
├── user_id: UUID (foreign key → users)
├── token_hash: str (indexed)
├── issued_at: timestamp
├── expires_at: timestamp
├── revoked_at: timestamp | null
└── replaced_by: UUID | null (token rotation chain)
```

**Note:** These tables are physically created in Stage 3 when PostgreSQL is introduced. In Stage 2, `DatabaseAuthProvider` uses SQLAlchemy models that map to these tables. If Stage 2 is deployed before Stage 3, a SQLite fallback or in-memory store can bridge the gap.

## 7. Migration Path

### Step 1: Add auth dependencies
- Add `PyJWT>=2.8.0`, `passlib[bcrypt]>=1.7.0` to `pyproject.toml`
- Add `jwt_secret` to `ServerConfig` (generated on first run if not provided)

### Step 2: Implement AuthProvider abstraction
- Create `auth/provider.py` with abstract `AuthProvider`
- Create `auth/local_provider.py` — returns anonymous admin context for all requests
- Wire into `ServerConfig`: `mode == "local"` → `LocalAuthProvider`

### Step 3: Add auth middleware
- Create FastAPI middleware that extracts credentials, resolves `AuthContext`, attaches to `request.state`
- In local mode, middleware short-circuits to anonymous admin
- Add rate limiting using in-memory token bucket (per user_id or IP for anonymous)

### Step 4: Add auth endpoints
- Create `auth/routes.py` with register, login, refresh, logout, me, api-keys
- These endpoints are only active when `mode != "local"`

### Step 5: Annotate existing routes
- Add `Depends(require_auth(tier="anonymous"))` etc. to route functions
- In local mode, the dependency always succeeds
- Add session ownership checks to session routes

### Step 6: Add `DatabaseAuthProvider`
- Implement against SQLAlchemy models (tables created in Stage 3)
- JWT issuance with configurable secret and expiry
- API key generation and validation

**Backward compatibility:** Local mode is completely unaffected. The `LocalAuthProvider` makes auth invisible — no tokens needed, no rate limits enforced, all scopes granted.

## 8. Security Considerations

- **Password storage:** bcrypt with cost factor 12. Never store plaintext or reversible encryption.
- **JWT secret management:** Must be configured via environment variable or `.env` file, not hardcoded. In production, rotate periodically.
- **Refresh token rotation:** Each refresh invalidates the previous token. If a revoked token is used, invalidate the entire chain (detect token theft).
- **API key storage:** Only the bcrypt hash is stored. The full key is shown once at creation time.
- **Rate limiting bypass:** Rate limits keyed on `user_id` (authenticated) or IP (anonymous). Consider `X-Forwarded-For` behind reverse proxy.
- **Timing attacks:** Use constant-time comparison for token and key validation.
- **Account enumeration:** Registration and login should return identical error timing for existing vs non-existing emails.
- **CORS:** Still `["*"]` in this stage. Stage 6 tightens to specific origins. Auth tokens in `Authorization` header (not cookies) mitigate CSRF.

## 9. Verification Criteria

- [ ] Local mode: all existing functionality works without any auth headers
- [ ] Remote mode: unauthenticated requests to protected endpoints return `AUTH_REQUIRED`
- [ ] Register → login → access protected endpoint → works
- [ ] Expired access token → 401 `TOKEN_EXPIRED` → refresh → new access token → works
- [ ] API key with `play` scope can start games but cannot reload scenarios
- [ ] API key with `admin` scope can do everything
- [ ] Revoked API key returns `API_KEY_INVALID`
- [ ] Rate limit exceeded → 429 with correct `retry_after`
- [ ] Rate limit headers present on every response
- [ ] Sessions created by user A are not visible to user B
- [ ] `GET /game/sessions` returns only the authenticated user's sessions
- [ ] Admin can see all sessions
- [ ] `AuthProvider` interface is the same one referenced by Stage 7 (`PassportAuthProvider`)

## 10. Open Questions

- **OAuth providers (Google, GitHub):** Should Stage 2 include social login, or defer to Stage 7 (which adds Immutable Passport as an OAuth provider)? Suggest deferring — email/password + API keys cover the MVP.
- **Email verification:** Required before play, or optional? Requiring it adds friction; not requiring it enables throwaway accounts. Suggest optional with incentive (verified users get higher rate limits).
- **Password requirements:** Minimum length, complexity rules? Suggest minimum 8 characters, no complexity rules (NIST 800-63B guidance).
- **Multi-device sessions:** Can a user have multiple active JWT sessions? Suggest yes — refresh token rotation per device handles this.
- **Admin bootstrapping:** How is the first admin account created? Suggest a CLI command (`kleene-server create-admin`) or environment variable (`ADMIN_EMAIL`).
- **Rate limiting storage:** In-memory token bucket works for single-server. Redis needed for distributed rate limiting (defer until scaling is needed).
- **API key expiry:** Should API keys expire by default, or be permanent until revoked? Suggest permanent with optional expiry.

---

*Cross-references:*
- *[Stage 1: Server Consolidation](stage-1-server-consolidation.md) — API versioning, error codes*
- *[Stage 3: Persistence](stage-3-persistence.md) — Users table creation*
- *[Stage 7: Blockchain](stage-7-blockchain.md) — PassportAuthProvider*
- *[Plan Iteration 1](../background/plan-iteration-1.md) — Player authentication design*
