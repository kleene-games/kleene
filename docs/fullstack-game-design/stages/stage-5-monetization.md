# Stage 5: Monetization

## 1. Overview

Stage 5 adds paid scenario purchases via Stripe, an entitlement system for access control, and a store API for browsing and buying content. The system must support multiple acquisition methods (purchase, bundled, gift, creator grant) and enforce access before disclosing scenario content.

**What this stage achieves:**
- Stripe Checkout integration for scenario purchases
- Entitlement model tracking how users acquired access to scenarios
- Store API endpoints for browsing, purchasing, and managing owned content
- Access control middleware intercepting node disclosure for paid scenarios
- Free tier definition (scenarios always accessible without purchase)
- Webhook handling for payment confirmation and refunds
- Scenario pricing metadata

**Why it matters:** Monetization funds ongoing development and content creation. The entitlement system is also the foundation for creator revenue sharing and the NFT achievement economy (Stage 7).

## 2. Prerequisites

- **Stage 2** — Authentication (must know who is buying)
- **Stage 3** — Persistence (entitlements must survive restarts, stored in PostgreSQL)

## 3. Current State

- `pyproject.toml` declares `stripe>=11.0.0` as an optional dependency (not installed in base)
- `config.py` has `stripe_key: str | None` field — unused
- `ScenarioLoader` has no access control — all scenarios returned to all callers
- No pricing metadata in the scenario YAML format or database schema
- No concept of "owned" vs "unowned" scenarios
- The `scenarios` table (Stage 3) includes `price_cents`, `tier`, and `game_modes` columns but nothing reads them yet

## 4. Target Architecture

```
Web Client
    │
    ├── GET /api/v1/store/scenarios ──── Browse catalog (public metadata)
    │
    ├── POST /api/v1/store/purchase ─── Create Stripe Checkout session
    │       │
    │       └── Redirect to Stripe ──── Stripe hosted checkout page
    │                                       │
    │                                   Payment completed
    │                                       │
    │       ┌── Redirect back ──────────────┘
    │       │
    │       └── GET /api/v1/store/purchase/{id}/status
    │
    └── GET /api/v1/scenario/{id}/node/{node_id} ── Entitlement check
                │
                v
        ┌───────────────┐
        │ Access Control │ ── Does user own this scenario?
        │   Middleware    │    Is it free tier?
        └───────────────┘    Is user admin?
                │
           [allowed] → Node data
           [denied]  → 403 SCENARIO_NOT_OWNED

Stripe Webhooks
    │
    POST /api/v1/webhooks/stripe
    │
    ├── checkout.session.completed → Create entitlement
    ├── charge.refunded → Revoke entitlement
    └── (other events logged but not acted on)
```

### Entitlement Model

```
Entitlement
├── user_id: UUID
├── scenario_id: str
├── acquisition_type: "purchase" | "free" | "bundled" | "gift" | "creator" | "admin"
├── stripe_payment_id: str | None
├── granted_at: timestamp
├── revoked_at: timestamp | None
├── revoke_reason: str | None
└── metadata: dict  (gift_from, bundle_id, etc.)
```

**Acquisition types:**
- `purchase` — Paid via Stripe Checkout
- `free` — Scenario is in free tier (implicit entitlement, no record needed)
- `bundled` — Came with a bundle purchase
- `gift` — Gifted by another user
- `creator` — Scenario author always has access
- `admin` — Manually granted by admin

### Access Control Logic

```
can_access(user, scenario):
  IF scenario.tier == "free":
    RETURN true
  IF user.tier == "admin":
    RETURN true
  IF entitlement exists for (user.id, scenario.id) AND not revoked:
    RETURN true
  RETURN false
```

Applied at the route level — intercepts `GET /scenario/{id}/node/{node_id}`, `GET /scenario/{id}/ending/{ending_id}`, and `POST /game/start`.

**Exception:** `GET /scenario/{id}/header` returns metadata (name, description, price) without entitlement — this is the store listing.

## 5. Interface Contracts

### Store Endpoints

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| `GET` | `/api/v1/store/scenarios` | Browse scenario catalog | Anonymous |
| `GET` | `/api/v1/store/scenarios/{id}` | Scenario detail (price, description, ratings) | Anonymous |
| `POST` | `/api/v1/store/purchase` | Create Stripe Checkout session | Authenticated |
| `GET` | `/api/v1/store/purchase/{id}/status` | Check purchase completion | Authenticated |
| `GET` | `/api/v1/store/library` | User's owned scenarios | Authenticated |
| `POST` | `/api/v1/store/gift` | Gift scenario to another user | Authenticated |
| `POST` | `/api/v1/webhooks/stripe` | Stripe webhook receiver | Stripe signature |

### Browse Catalog

```
GET /api/v1/store/scenarios?tier=premium&sort=popular

→ 200 OK
{
  "scenarios": [
    {
      "id": "dragon_quest",
      "name": "The Dragon's Choice",
      "description": "A branching narrative of courage and sacrifice...",
      "version": "2.1.0",
      "price_cents": 499,
      "currency": "usd",
      "tier": "premium",
      "game_modes": ["solo", "shared"],
      "node_count": 25,
      "ending_count": 7,
      "owned": false,
      "rating": 4.2,
      "play_count": 1523
    }
  ],
  "total": 12,
  "page": 1,
  "per_page": 20
}
```

**`owned` field:** Resolved per-request using the authenticated user's entitlements. Anonymous users always see `false`.

### Purchase Flow

```
POST /api/v1/store/purchase
Content-Type: application/json
Authorization: Bearer <jwt>

{
  "scenario_id": "dragon_quest",
  "success_url": "https://kleene.game/store/success?session_id={CHECKOUT_SESSION_ID}",
  "cancel_url": "https://kleene.game/store/cancel"
}

→ 200 OK
{
  "checkout_url": "https://checkout.stripe.com/c/pay/cs_test_...",
  "purchase_id": "pur_a1b2c3d4",
  "expires_at": "2026-02-15T11:00:00Z"
}
```

Client redirects to `checkout_url`. After payment, Stripe redirects to `success_url`.

### Purchase Status

```
GET /api/v1/store/purchase/pur_a1b2c3d4/status

→ 200 OK
{
  "purchase_id": "pur_a1b2c3d4",
  "scenario_id": "dragon_quest",
  "status": "completed",       // "pending" | "completed" | "failed" | "refunded"
  "stripe_session_id": "cs_test_...",
  "completed_at": "2026-02-15T10:35:00Z"
}
```

### Webhook Handling

```
POST /api/v1/webhooks/stripe
Stripe-Signature: t=...,v1=...

Handled events:
├── checkout.session.completed
│   → Create entitlement (purchase)
│   → Update purchase status to "completed"
│
├── charge.refunded
│   → Revoke entitlement
│   → Update purchase status to "refunded"
│
└── (all others)
    → Log and acknowledge (200 OK)
```

**Idempotency:** Webhook handlers check if entitlement already exists before creating. Stripe may deliver the same event multiple times.

### Access Control Error

```
GET /api/v1/scenario/premium_quest/node/intro
Authorization: Bearer <jwt_without_entitlement>

→ 403 Forbidden
{
  "error": {
    "code": "SCENARIO_NOT_OWNED",
    "message": "Purchase required to access this scenario",
    "scenario_id": "premium_quest",
    "price_cents": 499,
    "store_url": "/api/v1/store/scenarios/premium_quest"
  }
}
```

### Gift Flow

```
POST /api/v1/store/gift
Content-Type: application/json
Authorization: Bearer <jwt>

{
  "scenario_id": "dragon_quest",
  "recipient_email": "friend@example.com",
  "message": "Enjoy this quest!"
}

→ 200 OK
{
  "gift_id": "gift_x1y2z3",
  "status": "pending",        // "pending" (recipient not registered) or "delivered"
  "recipient_email": "friend@example.com"
}
```

Gifts to unregistered emails are held as pending and delivered on registration.

## 6. Data Model

### Table: `entitlements`

```sql
CREATE TABLE entitlements (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id),
    scenario_id     VARCHAR(100) NOT NULL REFERENCES scenarios(id),
    acquisition_type VARCHAR(20) NOT NULL,  -- purchase, free, bundled, gift, creator, admin
    stripe_payment_id VARCHAR(255),
    stripe_session_id VARCHAR(255),
    granted_at      TIMESTAMPTZ DEFAULT now(),
    revoked_at      TIMESTAMPTZ,
    revoke_reason   VARCHAR(255),
    metadata        JSONB DEFAULT '{}',
    UNIQUE(user_id, scenario_id, acquisition_type)
);

CREATE INDEX idx_entitlements_user ON entitlements(user_id) WHERE revoked_at IS NULL;
CREATE INDEX idx_entitlements_scenario ON entitlements(scenario_id);
CREATE INDEX idx_entitlements_stripe ON entitlements(stripe_session_id);
```

### Table: `purchases`

```sql
CREATE TABLE purchases (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    short_id        VARCHAR(12) UNIQUE NOT NULL,  -- "pur_a1b2c3d4"
    user_id         UUID NOT NULL REFERENCES users(id),
    scenario_id     VARCHAR(100) NOT NULL REFERENCES scenarios(id),
    stripe_session_id VARCHAR(255),
    stripe_payment_intent VARCHAR(255),
    amount_cents    INTEGER NOT NULL,
    currency        VARCHAR(3) DEFAULT 'usd',
    status          VARCHAR(20) DEFAULT 'pending',  -- pending, completed, failed, refunded
    created_at      TIMESTAMPTZ DEFAULT now(),
    completed_at    TIMESTAMPTZ,
    refunded_at     TIMESTAMPTZ
);

CREATE INDEX idx_purchases_user ON purchases(user_id);
CREATE INDEX idx_purchases_stripe ON purchases(stripe_session_id);
```

### Table: `gifts`

```sql
CREATE TABLE gifts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    short_id        VARCHAR(12) UNIQUE NOT NULL,
    sender_id       UUID NOT NULL REFERENCES users(id),
    recipient_email VARCHAR(255) NOT NULL,
    recipient_id    UUID REFERENCES users(id),  -- NULL if not yet registered
    scenario_id     VARCHAR(100) NOT NULL REFERENCES scenarios(id),
    message         TEXT,
    status          VARCHAR(20) DEFAULT 'pending',  -- pending, delivered, expired
    created_at      TIMESTAMPTZ DEFAULT now(),
    delivered_at    TIMESTAMPTZ,
    expires_at      TIMESTAMPTZ
);
```

### Updates to `scenarios` table

The `price_cents`, `tier`, and `game_modes` columns from Stage 3 are now actively used:

```sql
-- Additional columns for store display
ALTER TABLE scenarios ADD COLUMN currency VARCHAR(3) DEFAULT 'usd';
ALTER TABLE scenarios ADD COLUMN rating_sum INTEGER DEFAULT 0;
ALTER TABLE scenarios ADD COLUMN rating_count INTEGER DEFAULT 0;
ALTER TABLE scenarios ADD COLUMN play_count INTEGER DEFAULT 0;
```

## 7. Migration Path

### Step 1: Add Stripe dependency
- Install `stripe>=11.0.0` in remote extras
- Add `stripe_key`, `stripe_webhook_secret` to `ServerConfig`
- Validate Stripe key on startup (test mode vs live mode detection)

### Step 2: Create entitlements table
- Alembic migration for `entitlements`, `purchases`, `gifts` tables
- Add store-related columns to `scenarios` table

### Step 3: Implement access control middleware
- Create `EntitlementService` with `can_access(user_id, scenario_id)` method
- Wrap scenario node/ending endpoints with entitlement check
- Free tier scenarios bypass the check
- Admin users bypass the check
- Test: unauthenticated user can't access premium node → purchase → can access

### Step 4: Implement store API
- Browse catalog (public metadata, owned flag per user)
- Purchase flow (Stripe Checkout session creation, redirect handling)
- Library endpoint (user's owned scenarios)

### Step 5: Implement webhook handler
- Stripe signature verification
- `checkout.session.completed` → create entitlement
- `charge.refunded` → revoke entitlement
- Idempotency checks

### Step 6: Gift system
- Gift creation (sender pays, recipient gets entitlement)
- Pending gift delivery on registration
- Gift expiry for unclaimed gifts

**Backward compatibility:** Free tier scenarios (including all scenarios in local mode) work exactly as before. Access control only activates for scenarios where `tier != "free"`.

## 8. Security Considerations

- **Stripe webhook verification:** Always verify `Stripe-Signature` header using `stripe_webhook_secret`. Never process unverified webhooks.
- **Idempotent webhook handling:** Stripe delivers events at-least-once. Use `stripe_session_id` as idempotency key.
- **Price consistency:** Validate that the price in the Checkout session matches the current scenario price. Prevent race conditions where price changes between browse and purchase.
- **Entitlement bypass:** Access control must be enforced at the route level, not just the UI. API consumers could bypass client-side checks.
- **Refund handling:** Revoking entitlement on refund means active game sessions become inaccessible. Consider: allow completing the current session but block new sessions.
- **Gift abuse:** Rate limit gift creation to prevent spam. Validate recipient email format.
- **PCI compliance:** Stripe Checkout handles all card data — Kleene server never sees card numbers. Maintain this boundary.
- **Store listing privacy:** Ensure scenario metadata in store listings doesn't reveal plot spoilers. The `description` field should be curated.

## 9. Verification Criteria

- [ ] Free tier scenarios accessible without authentication (unchanged behavior)
- [ ] Premium scenario node request without entitlement returns 403 `SCENARIO_NOT_OWNED`
- [ ] Purchase flow: browse → buy → Stripe Checkout → webhook → entitlement created → node accessible
- [ ] Duplicate webhook delivery creates only one entitlement (idempotent)
- [ ] Refund webhook revokes entitlement
- [ ] `GET /store/library` returns only the authenticated user's owned scenarios
- [ ] `GET /store/scenarios` shows `owned: true` for purchased scenarios, `false` otherwise
- [ ] Admin users can access all scenarios regardless of entitlement
- [ ] Gift to registered user: immediate entitlement creation
- [ ] Gift to unregistered email: entitlement created on registration
- [ ] Stripe webhook signature verification rejects forged requests
- [ ] Local mode: all scenarios accessible (no entitlement checks)

## 10. Open Questions

- **Stripe Checkout vs embedded payment:** Checkout redirects to Stripe's hosted page (simpler, PCI compliant). Embedded uses Stripe Elements in the Kleene web UI (more integrated, more work). Suggest Checkout for MVP, upgrade to embedded later if UX demands it.
- **Currency support:** Start with USD only, or support multiple currencies? Stripe supports both. Suggest USD only for launch, add currency support based on user geography later.
- **Creator revenue share:** If scenario authors earn a percentage of sales, the system needs: creator association, revenue tracking, payout scheduling. Defer to a separate "Creator Platform" stage or handle as a manual process initially?
- **Bundle pricing:** How are bundles priced and structured? A bundle could be a discount on N scenarios or a "season pass." Suggest deferring bundles until there are enough scenarios to bundle (5+).
- **Subscription model:** Should there be a subscription tier (e.g., $9.99/month for all scenarios)? This changes the entitlement model significantly. Suggest starting with a la carte purchases, add subscription later based on demand.
- **Refund policy:** Automatic refund via Stripe, or manual review? What about partial refunds (played 50% of scenario)?
- **Tax handling:** Stripe Tax can handle sales tax/VAT calculation. Enable from the start or defer?
- **Free trial:** Allow playing the first N nodes of a paid scenario before requiring purchase? This would require partial entitlements.

---

*Cross-references:*
- *[Stage 2: Identity & Auth](stage-2-identity-auth.md) — User identity for purchases*
- *[Stage 3: Persistence](stage-3-persistence.md) — Database tables, scenarios table*
- *[Stage 7: Blockchain](stage-7-blockchain.md) — NFT achievements as purchasable content*
- *[Plan Iteration 1](../background/plan-iteration-1.md) — Phase 7, Stripe Checkout + webhooks*
