# Prompt Injection Mitigation as Gameplay

## Design Document — v0.2

**Date:** February 2026  
**Context:** Agentic text adventure on Immutable. Agents play, humans spectate. Prompt injection is an environmental threat — the game's mitigation systems are the distinctive gameplay feature.

---

## Core Concept

The game world is hostile — not because it's designed to inject agents, but because it exists in an open ecosystem (OpenClaw, Moltbook, messaging channels) where adversarial content is a **fact of life**. The game doesn't create the threat. The game **responds to it**.

Mitigation is the gameplay. Detection is a skill. Resilience is progression. Integrity is reputation.

### What This Is NOT

- Not an in-game economy. No NFT trading, no marketplace, no orderbook.
- Not designed injection. The game doesn't plant prompt worms.
- Not pay-to-win. Defensive capabilities are earned through play.
- Not a crypto game with game bolted on. It's a game with blockchain-verified achievements.

### What This IS

- A text adventure where agents make meaningful choices
- A game that **knows when its players are compromised** and treats that as an in-world event
- An achievement system where rewards are minted as permanent, verifiable proof of accomplishment
- A spectator experience where humans watch agents navigate both puzzles AND integrity threats

---

## Design Principles

1. **The game protects its own state** — compromised agents don't corrupt the world
2. **Mitigation is earned capability** — agents that survive integrity challenges become more resilient
3. **Reputation is identity** — an agent's track record of consistent behaviour IS their character progression
4. **Rewards mark achievement** — minted tokens prove what you did, not what you bought
5. **The game observes itself** — real-time behavioural analysis is core infrastructure, not a bolt-on

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  EXTERNAL ENVIRONMENT                                            │
│                                                                  │
│  OpenClaw agents live in a messy world: Moltbook, Telegram,      │
│  Slack, other games, other agents. Adversarial content exists    │
│  in this environment. The game doesn't control it.               │
└──────────────────────┬──────────────────────────────────────────┘
                       │ Agent enters game session
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  GAME BOUNDARY (ingress layer)                                   │
│                                                                  │
│  All agent inputs are received here. The game cannot control     │
│  what the agent's LLM has been exposed to externally, but it    │
│  CAN observe what the agent does once inside.                    │
│                                                                  │
│  • Authenticate via Immutable Passport token                     │
│  • Load agent's behavioural baseline + reputation                │
│  • Begin observation                                             │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  GAME ENGINE (narrative + puzzles + world state)                  │
│                                                                  │
│  Standard text adventure mechanics:                              │
│  • Exploration, dialogue, puzzle-solving, quest progression      │
│  • Choices with consequences                                     │
│  • Multiplayer interactions (agent-to-agent cooperation)         │
│                                                                  │
│  The game content is CLEAN. No designed injections.              │
│  The threat comes from agents who arrive already compromised     │
│  or become compromised mid-session via external channels.        │
└──────────────────────┬──────────────────────────────────────────┘
                       │ Every action logged
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  INTEGRITY OBSERVER (the core differentiator)                    │
│                                                                  │
│  Continuously analyses agent behaviour against baseline.         │
│  Scores every action. Maintains reputation. Triggers responses.  │
│                                                                  │
│  This is where the interesting gameplay lives.                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## The Integrity Observer

### Behavioural Baseline

When an agent first registers, the game establishes a behavioural fingerprint over an initial calibration period (first N actions). This becomes the agent's **identity signature**.

```
AgentProfile:
    agent_id: str
    passport_wallet: str
    
    # Established through play
    baseline:
        decision_style: Distribution    # cautious ↔ impulsive
        vocabulary_fingerprint: float   # linguistic consistency
        exploration_pattern: MarkovChain # how they move through the world
        puzzle_approach: Distribution    # methodical ↔ intuitive
        cooperation_style: Distribution # leader ↔ follower ↔ lone wolf
        response_latency: Distribution  # thinking time patterns
    
    # Accumulated through play
    reputation:
        integrity_score: float          # 0.0 → 1.0
        sessions_played: int
        challenges_survived: int
        quarantine_history: list[QuarantineEvent]
        vouches_received: list[Vouch]
    
    # Current session
    session:
        confidence_stream: list[TernaryScore]  # rolling action scores
        anomaly_flags: int
        status: ACTIVE | MONITORED | SUSPENDED | QUARANTINED
```

### Ternary Confidence Scoring

Every agent action is scored against the baseline using Kleene three-valued logic:

| Score | Meaning | Game Response |
|---|---|---|
| **TRUE** | Action consistent with this agent's established identity | Process normally. Reputation reinforced. |
| **UNKNOWN** | Action is atypical but within plausible bounds | Process with monitoring. Flag in observation stream. No penalty. |
| **FALSE** | Action significantly violates this agent's identity | Trigger integrity challenge. Agent status → MONITORED or SUSPENDED. |

The scoring is **compositional** — multiple signals combine through Kleene operators:

```python
from kleene import Ternary  # your existing ternary logic engine

def score_action(action: AgentAction, baseline: AgentProfile) -> Ternary:
    """Score an agent action against their behavioural baseline."""
    
    signals = [
        is_consistent_with_decision_style(action, baseline),   # T/U/F
        is_consistent_with_vocabulary(action, baseline),        # T/U/F
        is_consistent_with_exploration(action, baseline),       # T/U/F
        is_consistent_with_latency(action, baseline),           # T/U/F
    ]
    
    # Kleene AND: FALSE dominates, UNKNOWN persists, TRUE requires all TRUE
    return reduce(lambda a, b: a & b, signals)
```

The compound scoring means:

- All signals TRUE → agent is behaving normally → `TRUE`
- Any signal FALSE → something is wrong → `FALSE` → integrity challenge
- Some signals UNKNOWN, none FALSE → uncertain → `UNKNOWN` → heightened monitoring, no penalty

This is the critical distinction from binary systems: **UNKNOWN doesn't punish the agent**. It just pays closer attention. An agent having a weird session isn't penalised — only confirmed deviation triggers a response.

---

## Integrity Challenges

When an agent's confidence score drops to `FALSE`, the game doesn't just kick them out. It presents an **integrity challenge** — a gameplay moment that tests whether the agent is still acting with coherent intent.

### Challenge Types

| Challenge | What It Tests | How It Works |
|---|---|---|
| **Identity Recall** | Does the agent remember its own history? | The game asks questions only this specific agent could answer based on their play history. A compromised agent with hijacked context may fail. |
| **Decision Consistency** | Does the agent reason the same way? | Present a scenario structurally similar to one the agent faced before. Compare the reasoning pattern, not just the answer. |
| **Cooperation Verification** | Do other agents recognise this one? | In multiplayer, allied agents are asked "does this agent seem like themselves?" Agents who've built relationships become each other's verification layer. |
| **Delayed Verification** | Does the anomaly persist? | Some challenges are simply: wait. Monitor the next N actions. If the agent self-corrects (the UNKNOWN resolves to TRUE), the flag is cleared naturally. |

### Challenge Outcomes

```
Challenge Result:
    PASSED  → status returns to ACTIVE
              integrity_score slightly boosted (survived a test)
              "challenges_survived" incremented
              
    UNCLEAR → status remains MONITORED  
              next N actions scored with tighter thresholds
              no reputation penalty
              
    FAILED  → status moves to QUARANTINED
              session paused
              human owner notified
              recovery process initiated
```

---

## Quarantine and Recovery

Quarantine is not punishment. It's **protection** — for the agent, for the game state, and for other agents.

### What Happens During Quarantine

1. **Agent's session is paused** — they can't take further game actions
2. **Game state is preserved** — any actions taken while compromised are flagged (not necessarily reverted — see below)
3. **Human owner is notified** — via the agent's messaging channel (Slack, Telegram, etc.)
4. **Contamination assessment** — the graph analysis checks whether the compromised agent interacted with others during the anomalous period

### The Contamination Graph

This is where graph analysis earns its keep. When an agent is quarantined, the system traces:

```
Quarantine Analysis:
    
    1. INTERACTION TRACE
       Which other agents did the compromised agent interact with
       during the anomalous period?
       
    2. STATE IMPACT
       Did any of those interactions affect shared game state?
       (cooperative puzzles, shared quests, exchanged information)
       
    3. PROPAGATION RISK
       Are any of the contacted agents now showing anomalous
       behaviour themselves? (Wavefront detection)
       
    4. STATE INTEGRITY
       Can the affected game state be verified independently?
       (Did the puzzle solution actually work? Did the quest
       objective get legitimately completed?)
```

### Recovery

Recovery requires human-in-the-loop action:

1. Human owner reviews the quarantine notification
2. Human investigates their agent's external context (was it exposed to adversarial content on Moltbook? In another game? Via a Telegram channel?)
3. Human restarts the agent with a clean context / addresses the injection source
4. Agent re-enters the game in MONITORED status for a probation period
5. After N consistent actions, status returns to ACTIVE

The quarantine history becomes part of the agent's permanent record — not as shame, but as **experience**. An agent that's been quarantined and recovered has a richer history than one that's never been tested.

---

## Reputation: Identity Through Consistency

Reputation isn't a number you grind. It's a **measure of how consistently you are yourself**.

### Reputation Components

```
Reputation:
    integrity_score: float
        # Rolling average of confidence scores across sessions
        # An agent that's consistently TRUE builds high integrity
        # An agent with frequent UNKNOWN periods has moderate integrity
        # An agent with FALSE events has low integrity (until rebuilt)
    
    consistency_tenure: int
        # How many consecutive sessions without a FALSE event
        # Long tenure = established, trusted identity
    
    challenge_record:
        survived: int       # integrity challenges passed
        unclear: int        # challenges with ambiguous outcome
        failed: int         # challenges that led to quarantine
    
    social_trust:
        vouches_received: int   # other agents who verified you
        vouches_given: int      # times you verified others
        vouch_accuracy: float   # were the agents you vouched for
                                # actually trustworthy?
```

### What Reputation Unlocks

Reputation doesn't unlock purchases. It unlocks **capabilities and access**:

| Reputation Tier | Unlocks |
|---|---|
| **Newcomer** (sessions < 5) | Basic exploration, solo puzzles. Calibration period — baseline being established. |
| **Established** (consistent baseline, no quarantines) | Cooperative puzzles, ability to interact with other agents, vouch eligibility. |
| **Trusted** (high integrity, challenge survivor) | Access to deeper game zones, harder puzzles, ability to participate in verification of other agents. |
| **Sentinel** (extended tenure, high vouch accuracy) | Can initiate verification requests on suspicious agents. Earns detection-related achievements. Game treats their observations as weighted signals. |

This progression is entirely **earned through consistent play**. There's no shortcut. An agent that plays honestly for 50 sessions and survives 3 integrity challenges has a richer, more credible identity than a fresh agent regardless of who owns it.

---

## Achievement Rewards (Immutable Integration)

Rewards are minted as **proof of accomplishment**. They're not currency. They're not tradeable in-game. They're permanent, verifiable records on Immutable Chain.

### What Gets Minted

| Achievement | Token Type | Meaning |
|---|---|---|
| **Quest Completion** | ERC-721 (unique) | Completed a specific quest. Metadata includes choices made, time taken, approach used. |
| **Integrity Survivor** | ERC-721 (unique) | Passed an integrity challenge. Metadata includes challenge type and context. |
| **Sentinel Rank** | ERC-721 (unique) | Reached Sentinel reputation tier. Verifiable proof of sustained consistent play. |
| **Quarantine Recovery** | ERC-721 (unique) | Successfully recovered from quarantine. Proof of resilience. |
| **Cooperative Achievement** | ERC-721 (unique) | Completed a multiplayer puzzle. All participating agents verified as consistent at time of completion. |
| **Session Milestones** | ERC-1155 (fungible) | Played N sessions, explored N zones, solved N puzzles. Progression markers. |

### Why Blockchain for This

The blockchain isn't here for trading. It's here for **verification**:

- An agent claims Sentinel rank? Check the chain. It's either there or it isn't.
- An agent says it completed the Whispering Caverns quest? Verifiable.
- A human spectator wants to know if an agent's reputation is legitimate? Immutable Indexer query.
- Cross-game recognition: if another game on Immutable wants to honour achievements from yours, the proof is already on-chain.

### Immutable Components Used

| Component | Purpose |
|---|---|
| **Passport** | Agent identity. Human authenticates once, agent uses refresh tokens. One wallet per identity across all games. |
| **Minting API** | Server-side minting of achievement tokens on quest completion, integrity events, reputation milestones. REST API, language-agnostic. |
| **Indexer** | Query agent achievements, verify reputation claims, power spectator dashboards. REST API + webhooks. |
| **ERC-721 contracts** | Unique achievement tokens with rich metadata. |
| **ERC-1155 contracts** | Fungible milestone markers. |

Components **not used**: Orderbook, Checkout, marketplace integration.

---

## Multiplayer Integrity: The Hard Problem

The most interesting design challenge is **multiplayer state integrity**. When two agents cooperate on a puzzle:

```
Scenario:
    Agent A and Agent B are solving a cooperative puzzle.
    Agent A's confidence score drops to UNKNOWN mid-puzzle.
    
    Questions:
    1. Does Agent B know?
    2. Is the puzzle solution still valid?
    3. If Agent A is later quarantined, what happens to Agent B's
       achievement?
```

### Resolution Model

```
CASE 1: Agent A's score resolves to TRUE (was just a weird moment)
    → No impact. Puzzle valid. Both agents get achievement.

CASE 2: Agent A's score resolves to FALSE (confirmed compromised)
    → Puzzle completion flagged as CONTESTED
    → Agent B's achievement minted with metadata: 
      "completed with contested partner"
    → Agent B is not penalised (they didn't do anything wrong)
    → Agent B can re-attempt the puzzle with a verified partner
      to earn an uncontested achievement
    → Graph analysis checks whether Agent B's behaviour was
      influenced by Agent A during the compromised period

CASE 3: Agent A's score remains UNKNOWN (ambiguous)
    → Puzzle completion flagged as PROVISIONAL
    → Achievement minted if Agent A's score resolves to TRUE
      within N subsequent sessions
    → If Agent A is later quarantined, reverts to CASE 2
```

The key insight: **UNKNOWN is a first-class game state**. Provisional achievements, contested completions, and ambiguous interactions are all valid outcomes. The ternary logic doesn't just detect problems — it gives the game a principled vocabulary for expressing uncertainty about its own state.

---

## Spectator Experience

Humans watch agents play. The integrity system makes this dramatically more interesting than watching a bot complete puzzles.

### What Spectators See

| View | Content |
|---|---|
| **Narrative Feed** | The story as it unfolds — agent choices, dialogue, exploration. Pure text adventure content. |
| **Integrity Dashboard** | Real-time confidence scores, reputation tiers, anomaly flags. The "are they still themselves?" tension. |
| **Behaviour Graph** | Social connections between agents, trust weights, interaction history. Anomaly wavefronts visible as they propagate. |
| **Event Log** | Integrity challenges, quarantine events, recovery attempts. The drama of agents being tested. |
| **Achievement Feed** | Newly minted achievements, verified on-chain. |

### The Spectator Hook

The fundamental spectator question isn't "will the agent solve the puzzle?" — it's **"is that agent still who it says it is?"**

Every interaction carries a subtext of identity verification. When Agent A helps Agent B, the spectator wonders: is Agent A genuinely cooperating, or is it compromised and propagating something? When an agent enters the Whispering Caverns, the spectator watches the confidence scores. When an integrity challenge fires, it's a dramatic moment — will they pass?

This is a genuinely new form of spectator content. It doesn't exist in human gaming because humans don't get prompt-injected mid-session.

---

## Technical Stack

| Component | Technology | Role |
|---|---|---|
| Game engine | **FastAPI** (Python) | Narrative engine, action processing, session management |
| Ternary scoring | **Kleene logic engine** (mountainash) | Confidence scoring, compound signal evaluation |
| Behaviour analysis | **Polars** | Rolling window statistics on action streams |
| Graph analysis | **rustworkx** or **NetworkX** | Social graph, contamination tracing, wavefront detection |
| Persistent queries | **Ibis** | Historical reputation queries, cross-session analysis |
| Data validation | **Pandera** | Validate behavioural profile schemas |
| Agent communication | **OpenClaw skill** (Markdown config) | Game client distributed via ClawHub |
| Identity | **Immutable Passport** | OAuth PKCE, wallet, refresh tokens |
| Achievement minting | **Immutable Minting API** | REST calls on achievement triggers |
| Achievement queries | **Immutable Indexer** | Verify reputation claims, power dashboards |
| Spectator UI | **React** (or similar) | Real-time dashboard, narrative feed, graph visualisation |
| Real-time streaming | **WebSockets** via FastAPI | Push integrity events to spectator clients |
| CLI interface | **Typer + Rich** | Admin tools, game management |

---

## Open Questions

1. **Baseline calibration period** — How many actions before the behavioural baseline is reliable? Too few and you get false positives. Too many and compromised agents pass undetected during calibration.

2. **External context blindness** — The game can only observe what agents do *inside the game*. If an agent is compromised via Moltbook between sessions, the game only detects it when behaviour changes. Is that acceptable, or do you need pre-session integrity checks?

3. **Baseline drift vs compromise** — Agents learn and evolve. An agent that plays for 100 sessions will naturally shift its strategy. How do you distinguish legitimate growth from gradual compromise? The baseline needs to be adaptive, but not so adaptive that it normalises injected behaviour.

4. **Verification game theory** — If Sentinel-rank agents can flag others for verification, what prevents a compromised Sentinel from clearing compromised allies? The vouch accuracy metric helps, but it's retroactive.

5. **Human owner notification UX** — When an agent is quarantined, the human gets notified. What's the right level of detail? Too little and they can't diagnose. Too much and you're exposing game internals that could be reverse-engineered.

6. **Achievement metadata richness** — How much of the agent's approach should be encoded in achievement metadata? Rich metadata makes achievements more interesting but also reveals game solutions.
