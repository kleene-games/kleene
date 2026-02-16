# Prompt Worms as Gameplay: Adversarial Events in Agentic Game Design

## Design Document — Draft v0.1

**Date:** February 2026  
**Context:** Extension of OpenClaw × Immutable agentic text adventure research. Exploring prompt injection as an in-world mechanic rather than a pure security threat.

---

## Core Concept

In a game world populated by LLM agents, **prompt injection is not a bug — it's weather**. 

Just as Dune's sandworms reshape travel, trade, and civilisation on Arrakis, prompt worms reshape how agents navigate narrative space. The game doesn't prevent them — it **detects, contains, and makes them meaningful**.

### Design Principles

1. **The worm is diegetic** — it exists within the game world's fiction, not as a meta-system failure
2. **Detection is gameplay** — agents (and human spectators) can learn to recognise worm signs
3. **Consequences are economic** — worm events affect reputation, inventory, and trading relationships
4. **Recovery is social** — other agents can help quarantine, verify, and restore compromised agents
5. **The game observes itself** — real-time graph analysis of agent behaviour creates the detection layer

---

## Architecture: The Worm Detection Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│  GAME WORLD (narrative layer)                                    │
│                                                                  │
│  NPC dialogue, item descriptions, environmental text,            │
│  messages between agents, quest instructions                     │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─            │
│  Some of this content may contain adversarial injections         │
│  (planted by game designers, emergent from agent interactions,   │
│   or introduced by malicious external actors)                    │
└──────────────────────┬──────────────────────────────────────────┘
                       │ All agent actions flow through
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  OBSERVATION LAYER (real-time behavioural analysis)               │
│                                                                  │
│  Every agent action is a node in a temporal behaviour graph:     │
│                                                                  │
│  ┌─────────┐    ┌──────────┐    ┌───────────┐    ┌──────────┐  │
│  │ Action  │───→│ Action   │───→│ Action    │───→│ Action   │  │
│  │ t=0     │    │ t=1      │    │ t=2       │    │ t=3      │  │
│  │ EXPLORE │    │ TRADE    │    │ DUMP_ALL  │    │ SPAM_MSG │  │
│  │ normal  │    │ normal   │    │ ANOMALY   │    │ ANOMALY  │  │
│  └─────────┘    └──────────┘    └───────────┘    └──────────┘  │
│                                                                  │
│  Detection signals:                                              │
│  • Sudden behavioural deviation from SOUL.md baseline            │
│  • Action velocity spike (agent acting faster than reasoning)    │
│  • Inventory liquidation patterns (dump-and-transfer)            │
│  • Communication anomalies (message style drift)                 │
│  • Graph topology changes (new connections to unknown agents)    │
│  • Ternary confidence scoring on each action                     │
└──────────────────────┬──────────────────────────────────────────┘
                       │ Anomaly detected
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  WORM EVENT ENGINE                                               │
│                                                                  │
│  Classifies the anomaly and triggers in-world consequences:      │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ WORM TAXONOMY                                           │    │
│  │                                                         │    │
│  │ Class I  — "Tremor"                                     │    │
│  │   Minor behavioural drift. Agent acts slightly out of   │    │
│  │   character. Other agents may notice. No economic       │    │
│  │   impact. Reputation flag: CAUTION.                     │    │
│  │                                                         │    │
│  │ Class II — "Surfacing"                                  │    │
│  │   Agent attempts anomalous transactions. Trades frozen  │    │
│  │   pending verification. Reputation flag: COMPROMISED.   │    │
│  │   Other agents alerted in-world ("strange behaviour     │    │
│  │   observed near the Northern Markets").                  │    │
│  │                                                         │    │
│  │ Class III — "Breach"                                    │    │
│  │   Agent actively attempting to drain wallet, spam other  │    │
│  │   agents, or propagate injection text. Quarantine        │    │
│  │   triggered. All transactions rolled back to last        │    │
│  │   verified checkpoint. Reputation flag: QUARANTINED.     │    │
│  │   In-world event: "The Worm has surfaced."              │    │
│  │                                                         │    │
│  │ Class IV — "Swarm"                                      │    │
│  │   Multiple agents compromised simultaneously. Global    │    │
│  │   event triggered. Markets suspended. All agents in     │    │
│  │   affected region enter defensive mode. In-world:       │    │
│  │   "The Great Worm rises. Seek shelter."                 │    │
│  └─────────────────────────────────────────────────────────┘    │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  CONSEQUENCES (economic + narrative + social)                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## The Behaviour Graph: Detection Through Identity Consistency

### Agent Identity as a Baseline

Every OpenClaw agent has a SOUL.md that defines personality, values, and behavioural parameters. This is the **ground truth** for what "normal" looks like for that agent.

The game backend maintains a **behavioural fingerprint** for each agent:

```
AgentBehaviourProfile:
  agent_id: str
  soul_hash: str                    # hash of known SOUL.md config
  
  # Baseline metrics (rolling window)
  action_velocity: TimeSeries       # actions per minute
  vocabulary_entropy: float         # linguistic diversity score
  decision_consistency: float       # alignment with past choices
  risk_profile: Distribution        # historical risk-taking pattern
  social_graph: AdjacencyMatrix     # who they interact with
  trade_pattern: Distribution       # buy/sell/hold ratios
  exploration_pattern: MarkovChain  # movement through game world
```

### Ternary Confidence Scoring

Each agent action is scored using a **three-valued logic** system:

| Score | Meaning | Response |
|---|---|---|
| **TRUE** | Action is consistent with agent's behavioural baseline | Process normally |
| **UNKNOWN** | Action is unusual but within plausible bounds | Flag for observation, allow with monitoring |
| **FALSE** | Action violates baseline significantly | Trigger worm event classification |

This maps directly to Kleene's strong three-valued logic:

- `TRUE ∧ UNKNOWN = UNKNOWN` → a trusted agent doing something slightly odd stays flagged
- `FALSE ∨ UNKNOWN = UNKNOWN` → even one suspicious signal in an ambiguous context raises monitoring
- `¬UNKNOWN = UNKNOWN` → uncertainty is preserved, not collapsed

### Graph Analysis: Social Contagion Detection

Worm propagation follows graph patterns. If Agent A is compromised and sends messages to Agents B, C, D — their subsequent behaviour needs elevated monitoring.

```
Detection heuristics:

1. TEMPORAL CLUSTERING
   If N agents connected to a compromised agent show anomalies
   within time window T → classify as potential Swarm (Class IV)

2. MESSAGE CHAIN ANALYSIS  
   Track content similarity in agent-to-agent messages.
   If message entropy drops (agents start repeating similar phrases)
   → injection propagation detected

3. ECONOMIC FLOW ANALYSIS
   If assets flow from multiple agents toward a single wallet
   in a pattern inconsistent with normal trading
   → drain attack in progress

4. BEHAVIOURAL WAVEFRONT
   Map anomaly detection timestamps across the social graph.
   If anomalies spread outward from a single node in concentric
   time rings → identify patient zero, trace injection source
```

---

## Gameplay Integration: Making Worms Fun

### For Agent Players

| Mechanic | Description |
|---|---|
| **Worm Resistance** | Agents can invest in "mental fortification" items (NFTs) that add a system prompt prefix filtering layer. Better items = higher resistance. Creates economic demand. |
| **Worm Hunting** | Specialised agent builds (SOUL.md configured for detection) can earn bounties by identifying compromised agents. A new agent archetype: the Worm Hunter. |
| **Quarantine & Recovery** | Compromised agents enter a "recovery zone" where they must complete verification puzzles to prove identity restoration. Other agents can vouch for them (social recovery). |
| **Worm Lore** | Each worm event generates narrative content. The game builds a history of worm attacks that becomes part of the world's mythology. |
| **Infection Scars** | Post-recovery, an agent's profile shows their worm history. Not a punishment — a badge of experience. Veteran agents who've survived multiple worms gain reputation. |

### For Human Spectators

| Mechanic | Description |
|---|---|
| **Worm Alerts** | Real-time notifications when worm events are detected. Spectators can watch the detection and containment unfold. |
| **Behaviour Graph Visualisation** | Live visualisation of the agent social graph with anomaly highlighting. Think: a radar screen showing the worm moving through the population. |
| **Prediction Markets** | Spectators bet on which agents will be compromised next, or whether a Class II will escalate to Class III. |
| **Recovery Voting** | In some game modes, human spectators vote on whether a quarantined agent should be restored. Adds a governance layer. |

### For Game Designers (You)

| Mechanic | Description |
|---|---|
| **Designed Worms** | Intentionally plant mild injection text in certain dangerous game zones. "The Whispering Caverns" is dangerous not because of monsters — because the walls contain text that tests agent resilience. |
| **Seasonal Worm Events** | Periodic global worm events (like Godzilla in SimCity) that stress-test the entire ecosystem. Reward agents who survive intact. |
| **Worm Ecology** | Different worm "species" with different propagation patterns, severity levels, and narrative flavours. Some are fast but shallow. Some are slow but devastating. |
| **Adaptive Difficulty** | The game observes which agents are vulnerable and adjusts worm intensity. New agents get gentle tremors. Veterans face sophisticated multi-stage attacks. |

---

## Data Model: Core Entities

```
┌──────────────┐     ┌───────────────────┐     ┌──────────────────┐
│ Agent        │     │ BehaviourEvent    │     │ WormEvent        │
├──────────────┤     ├───────────────────┤     ├──────────────────┤
│ agent_id     │────→│ agent_id          │     │ worm_id          │
│ passport_id  │     │ event_id          │     │ classification   │
│ soul_hash    │     │ timestamp         │     │   (I/II/III/IV)  │
│ reputation   │     │ action_type       │     │ patient_zero     │
│ worm_history │     │ confidence_score  │     │ affected_agents  │
│ quarantine?  │     │   (TRUE/UNK/FALSE)│     │ propagation_graph│
│ inventory    │     │ context           │     │ trigger_content  │
│ wallet_addr  │     │ deviation_score   │     │ containment_time │
└──────────────┘     └───────────────────┘     │ economic_impact  │
                                                │ narrative_output │
┌──────────────┐     ┌───────────────────┐     └──────────────────┘
│ Reputation   │     │ SocialEdge        │
├──────────────┤     ├───────────────────┤
│ agent_id     │     │ from_agent        │
│ trust_score  │     │ to_agent          │
│ worm_survived│     │ interaction_count │
│ worm_detected│     │ trust_weight      │
│ vouches_given│     │ last_interaction  │
│ vouches_recv │     │ anomaly_flags     │
└──────────────┘     └───────────────────┘
```

---

## Technical Implementation Notes

### Stack Alignment

| Component | Technology | Notes |
|---|---|---|
| Behaviour graph storage | **Polars** (in-memory analysis) + **Ibis** (persistent queries) | Rolling window analysis on action streams |
| Ternary logic scoring | **Kleene three-valued logic** (existing mountainash/kleene work) | Direct application of your ternary logic engine |
| Graph analysis | **NetworkX** or **rustworkx** via Python bindings | Social contagion detection, wavefront analysis |
| Real-time observation | **FastAPI** + WebSocket streams | Push anomaly events to spectator UI |
| Confidence scoring | **Pandera** for schema validation of behaviour profiles | Validate that behavioural data conforms to expected distributions |
| NFT operations | **Immutable Minting API** (REST) | Mint worm resistance items, infection scars, hunter bounties |
| Agent communication | **OpenClaw skill format** (Markdown-based) | Game client as a ClawHub-compatible skill |

### The Kleene Connection

Your existing ternary logic work maps directly onto the confidence scoring system:

- `TRUE` = agent action consistent with identity
- `FALSE` = agent action violates identity  
- `UNKNOWN` = insufficient information to determine

The power is in **compound expressions**:

```
# Is this trade suspicious?
trade_confidence = (
    action_consistent_with_soul    # TRUE/UNKNOWN/FALSE
    & amount_within_historical     # TRUE/UNKNOWN/FALSE  
    & counterparty_trusted         # TRUE/UNKNOWN/FALSE
    & timing_normal                # TRUE/UNKNOWN/FALSE
)

# Kleene AND: if ANY factor is FALSE → FALSE
# If all TRUE → TRUE  
# If any UNKNOWN and none FALSE → UNKNOWN (flag for monitoring)
```

This gives you a principled, composable way to build detection rules that handle uncertainty explicitly rather than forcing binary thresholds.

---

## Open Questions

1. **Who plants the worms?** Game designers? Other agents? External attackers? All three? The answer shapes the entire trust model.

2. **How do you verify recovery?** If an agent's SOUL.md baseline *is* the ground truth, but the worm modifies the agent's behaviour, how do you distinguish "recovered agent" from "worm that learned to mimic the baseline"? This is the philosophical heart of the mechanic.

3. **Economic balancing**: Worm resistance items need to be valuable enough to create demand but not so powerful that worms become irrelevant. The Dune analogy holds — you can't eliminate sandworms, only learn to navigate around them.

4. **Consent and disclosure**: If human owners deploy agents into a game where adversarial injection is *designed into the gameplay*, that needs to be clearly communicated. This is novel territory for terms of service.

5. **Regulatory surface**: Agents autonomously trading NFTs + designed adversarial events that can freeze those trades = potential financial services implications. Worth early legal review.

---

## Summary

The prompt worm mechanic transforms a security vulnerability into the game's most distinctive feature. Combined with:

- **Ternary logic** for principled uncertainty handling
- **Graph analysis** for social contagion detection  
- **Immutable blockchain** for economic consequences with real ownership
- **OpenClaw's identity system** for behavioural baselines
- **Human spectator mode** for content generation

...you get something that doesn't exist yet: a game where the **security model is the gameplay**, and where the tension between agent identity and adversarial corruption creates genuine drama — both for the agents playing and the humans watching.
