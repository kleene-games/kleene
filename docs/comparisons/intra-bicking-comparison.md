# Analysis: Kleene Framework vs. Intra (Ian Bicking's LLM Text Adventure)

## Overview

This document compares the **Kleene narrative engine** against **Intra**, an LLM-driven text adventure created by Ian Bicking and documented in his blog post ["Intra: LLM-Driven Text Adventure"](https://ianbicking.org/blog/2025/07/intra-llm-text-adventure).

Both projects grapple with the same fundamental challenge: how to create coherent, playable interactive fiction with LLMs while maintaining "ground truth" about game state. They arrive at remarkably similar architectural decisions from different starting points.

---

## The Two Systems at a Glance

| Aspect | **Intra** | **Kleene** |
|--------|-----------|------------|
| **Architecture** | Client-side TypeScript + OpenRouter | Claude Code plugin (YAML + LLM) |
| **State Management** | Code-tracked formal state | YAML scenarios + JSON Schema |
| **Action Resolution** | Intent parsing → guided thinking → state tags | Intent classification → feasibility → soft consequences |
| **NPC Handling** | Filtered perspective + selection step | Authored nodes + relationship tracking |
| **Hallucination Control** | Inventory visibility + minimal objects | Soft consequence limits |
| **Prompt Strategy** | Markup tags, no tools, role inversion | Skill prompts with bounded improvisation |
| **Authoring Model** | Author creates world, LLM narrates | Author creates scenarios, LLM adapts texture |

---

## Shared Core Insight: Ground Truth

Both systems independently arrive at the same architectural principle:

### Bicking's Formulation

> "I wanted to create a game with real state, with a sense of 'ground truth': facts determined outside of narrative demands."

> "If the events stay ungrounded...there's a sense that we're navigating a collaborative dreamscape."

### Kleene's Formulation

> "State is not stored in LLM memory. State is stored in validated YAML structures."

> "Improvisation enriches the current moment without derailing scenario balance. Major state changes are reserved for scripted paths."

**The shared insight**: LLMs are unreliable state managers. Coherent games require **external authoritative state** that the LLM reads but doesn't control.

---

## Problem-by-Problem Comparison

### Problem 1: State Consistency

**Bicking's experience:**
> "If the events stay ungrounded and nothing is resolved by code, there's a sense that we're navigating a collaborative dreamscape."

**Bicking's solution:** Formal code tracking game state (player position, inventory, door locks) with tagged state modifications:
```xml
<removeRestriction>Hollow_Atrium</removeRestriction>
```

**Kleene's solution:** YAML state validated against JSON Schema:
```yaml
world:
  current_location: temple_entrance
  location_state:
    shrine:
      flags: { sealed: false }
```

State changes through typed consequences:
```yaml
consequence:
  - type: clear_location_flag
    location: shrine
    flag: sealed
```

| Approach | Intra | Kleene |
|----------|-------|--------|
| State format | JavaScript objects | YAML with JSON Schema |
| Modification | XML tags in LLM output | Typed consequence objects |
| Validation | Code-level | Schema validation + 15 analysis types |

**Verdict**: Both externalize state from LLM. Kleene adds formal validation layer.

---

### Problem 2: Hallucination / Object Inflation

**Bicking's experience:**
> "If objects can be hallucinated into existence then this can get out of hand."

**Bicking's solutions:**
- Display player inventory prominently to anchor reality
- Minimize object count in world design
- Use narrative integration ("chainsaw-carrying" dominates perception)

**Kleene's solution:** Soft consequence limits prohibit item creation during improvisation:

| Allowed (Soft) | Prohibited (Hard) |
|----------------|-------------------|
| `modify_trait` (±1) | `gain_item` |
| `add_history` | `lose_item` |
| `set_flag` (improv_* only) | `move_to` |
| `advance_time` | `character_dies` |

The LLM can describe examining a sword but cannot create one. Items exist only if authored in the scenario.

| Approach | Intra | Kleene |
|----------|-------|--------|
| Prevention method | Design constraint + visibility | Hard-coded consequence limits |
| Enforcement | Developer discipline | Schema + runtime checks |
| Flexibility | Author can allow | Strict boundary |

**Verdict**: Kleene enforces at the system level; Intra relies on careful prompting.

---

### Problem 3: Player Action Suggestibility

**Bicking's experience:**
> "Direct player input is too suggestible. 'Marta and Ama get into a disagreement' could be interpreted as the player causing this."

**Bicking's solution:** Intent parsing/rewriting:
```
Player input: "open the door"
Rewritten: <action>Player attempts to open the door</action>
```

**Kleene's solution:** Intent classification system:

```
Player types: "I try to pick the lock"
        ↓
Intent classification: Act
        ↓
Feasibility check: Blocked (no lockpicks)
        ↓
Grid mapping: Constraint
        ↓
Response: "You examine the lock mechanism, but without proper tools,
          you'd only damage it. The lock requires specialized picks."
        ↓
Return to authored choices
```

Player can only affect state through soft consequences—they cannot declare narrative facts.

| Approach | Intra | Kleene |
|----------|-------|--------|
| Input handling | Rewrite to action tags | Classify intent + check feasibility |
| Authority | LLM resolves rewritten action | Scenario preconditions gate outcomes |
| Player power | Can attempt anything | Can attempt; outcome bounded |

**Verdict**: Both filter player input. Kleene adds feasibility checking against state.

---

### Problem 4: NPC Over-Responsiveness

**Bicking's experience:**
> "Lunchtime conversations in Intra get out of hand when every NPC in the complex gets a turn."

> "An 'unengaged character who is unengaged in the event' remains difficult—the model defaults to generating something."

**Bicking's solutions:**
- Selection step: Ask LLM which 2-3 NPCs should respond
- Perspective filtering: NPCs see only events in their room

**Kleene's solution:** NPCs are authored, not simulated:

- NPC dialogue generated only during "Interact" improvisation
- `npc_locations` tracks where NPCs are (authored or via `move_npc`)
- `npc_at_location` / `npc_not_at_location` preconditions control presence
- Relationship values gate dialogue depth

NPCs don't autonomously respond—they're invoked when players explicitly interact.

| Approach | Intra | Kleene |
|----------|-------|--------|
| NPC agency | Autonomous with selection filter | Reactive only (player-invoked) |
| Presence | Dynamic (LLM tracks) | Authored + `move_npc` consequences |
| Dialogue | Generated per NPC turn | Generated on player interaction |

**Verdict**: Intra attempts autonomous NPCs (hard problem). Kleene sidesteps by making NPCs reactive.

---

### Problem 5: Memory / Context Limits

**Bicking's experience:**
> "Event history provides the only memory; critical information vanishes into context depth."

**Bicking's proposed solution:** Explicit memory uplift mechanisms (not yet implemented).

**Kleene's solution:** State persists in YAML, not context:

- Character flags: `{ met_guardian: true, learned_secret: true }`
- World flags: `{ door_unlocked: true }`
- `improv_*` flags: Track improvised discoveries
- Relationships: Numeric values persist across sessions
- History array: `add_history` consequences record events

The LLM reads current state each turn—no accumulated context drift.

| Approach | Intra | Kleene |
|----------|-------|--------|
| Memory location | Context window | YAML state + flags |
| Persistence | Session only | Save files across sessions |
| Retrieval | Context depth | Explicit state read each turn |

**Verdict**: Kleene's external state eliminates context-based memory loss entirely.

---

### Problem 6: Prompt Engineering Complexity

**Bicking's strategies:**

1. **No tools**: Markup tags instead of structured tool use
2. **Role inversion**: User = game engine, not player
3. **Guided thinking**: Explicit question sequences forcing reasoning
4. **Minimize indirection**: IDs match titles, consistent markup

**Kleene's strategies:**

1. **Skill prompts**: Detailed instructions in SKILL.md files
2. **AskUserQuestion**: Structured menus for player choices
3. **Intent classification**: Explicit categories (Explore/Interact/Act/Meta)
4. **Temperature control**: 0-10 scale for narrative adaptation
5. **Soft/hard boundary**: Clear rules on what LLM can affect

| Strategy | Intra | Kleene |
|----------|-------|--------|
| Structured output | XML markup tags | Consequence types + AskUserQuestion |
| Reasoning control | Guided thinking questions | Intent → Feasibility → Grid mapping |
| Flexibility tuning | N/A | Temperature 0-10 |
| Output constraints | Role/markup conventions | Soft consequence whitelist |

**Verdict**: Both use explicit structuring. Kleene adds temperature control for author preference.

---

### Problem 7: "What Is the Game?"

**Bicking's concern:**
> "What really is the 'game' here? What makes it fun?"

> Traditional IF puzzles function as "pass-fail riddles with no middle ground—unlike 'dartboard' games offering gradual feedback."

**Kleene's answer:** The Decision Grid provides a formal model of what the "game" is:

|                    | World Permits | World Indeterminate | World Blocks |
|--------------------|---------------|---------------------|--------------|
| **Player Chooses** | Triumph       | Commitment          | Rebuff       |
| **Player Unknown** | Discovery     | Limbo               | Constraint   |
| **Player Avoids**  | Escape        | Deferral            | Fate         |

The "game" is exploring the possibility space of player agency × world response.

**Completeness tiers** define what makes a scenario "complete":
- Bronze: Can succeed, fail, escape, or be trapped
- Silver: + uncertainty, exploration
- Gold: Full possibility space

**Bicking's insight maps to Kleene:**

> "It's hard to learn these games: you don't improve in small steps."

Kleene's Constraint cell addresses this—failed exploration teaches what's needed:
```
You try to open the sealed door. The runes pulse faintly—whatever
holds it closed requires more than brute force. Perhaps there's
something in the temple that could help.
```

The player learns without binary pass/fail.

---

## Architectural Comparison

### Intra Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Client-Side (Browser)                     │
├─────────────────────────────────────────────────────────────┤
│  React/Next.js UI     │  OpenRouter LLM Calls               │
│  ───────────────────  │  ─────────────────────              │
│  • Room display       │  • Intent parsing                   │
│  • Inventory view     │  • Action resolution                │
│  • NPC interactions   │  • NPC responses                    │
│                       │  • State modification tags          │
├─────────────────────────────────────────────────────────────┤
│  Formal Game State (JavaScript)                             │
│  • Player position    • Inventory    • Room restrictions    │
└─────────────────────────────────────────────────────────────┘
```

### Kleene Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Claude Code Plugin                        │
├─────────────────────────────────────────────────────────────┤
│  Scenario YAML           │  LLM (Claude)                    │
│  ────────────────────    │  ──────────────                  │
│  • Nodes + choices       │  • Intent classification         │
│  • Preconditions (23+)   │  • Feasibility narrative         │
│  • Consequences (22+)    │  • Temperature adaptation        │
│  • State (validated)     │  • Improvisation (soft only)     │
├─────────────────────────────────────────────────────────────┤
│  JSON Schema Validation (1100 lines)                        │
│  15 Analysis Types (kleene-analyze)                         │
└─────────────────────────────────────────────────────────────┘
```

### Key Differences

| Aspect | Intra | Kleene |
|--------|-------|--------|
| Runtime | Browser + OpenRouter | Claude Code |
| State format | JavaScript objects | YAML + JSON Schema |
| LLM role | Resolves actions, generates NPCs | Interprets input, adapts texture |
| Validation | Code-level checks | Schema + 15 analysis types |
| Offline | No (requires OpenRouter) | Yes (local YAML files) |
| Authoring | World design + prompt engineering | Scenario YAML + generation tools |

---

## Bicking's 50 Improvements vs. Kleene Features

Mapping selected improvements to Kleene's current state:

| Bicking's Improvement | Kleene Status |
|-----------------------|---------------|
| NPC consistency | ✓ Relationship values + authored behavior |
| Self-scheduling NPCs | ✓ `scheduled_events` + `npc_locations` |
| Inventory systems | ✓ `inventory` array + `gain_item`/`lose_item` |
| Skill implementation | ✓ Trait system (courage, wisdom, etc.) |
| Dynamic puzzles | ~ Preconditions enable complexity |
| Streaming responses | ✗ Not implemented |
| Parallelization | ✗ Sequential processing |
| Multi-user | ✗ Single-player only |
| Time-based design | ✓ `time`, `advance_time`, `time_elapsed_*` preconditions |
| Object editors | ~ YAML editing + schema validation |
| Data typing/verification | ✓ JSON Schema + kleene-analyze |
| Gameplay-based evaluation | ✓ 15 analysis types + grid coverage |

---

## What Each System Could Learn

### What Kleene Could Adopt from Intra

1. **Guided thinking pattern**: Explicit question sequences for complex action resolution
2. **NPC perspective filtering**: NPCs aware only of events in their location
3. **Streaming responses**: Better perceived latency
4. **Client-side option**: Browser-based play without Claude Code

### What Intra Could Adopt from Kleene

1. **JSON Schema validation**: Formal state structure verification
2. **Completeness analysis**: Ensure scenarios cover possibility space
3. **Soft/hard consequence boundary**: Systematic hallucination prevention
4. **Decision Grid**: Formal model of what the "game" is
5. **Temperature system**: Author control over LLM influence
6. **15 analysis types**: Automated structural validation

---

## The Authoring Question

Both authors grapple with what "authoring" means with AI:

### Bicking

> "Material created by AI can feel authored. But you do have to put in the work of authoring! You have to develop an intention and ensure the work embodies that intention."

> "I want to use AI for better work, not easier work."

### Kleene

The framework explicitly separates authorial responsibilities:

| Author Provides | LLM Provides |
|-----------------|--------------|
| Structure (nodes, choices, endings) | Texture (narrative adaptation) |
| Mechanics (preconditions, consequences) | Improvisation (bounded responses) |
| Completeness (grid coverage) | Personality (temperature-scaled) |

Temperature 0 = pure authorial voice. Temperature 10 = rich co-creation.

**The shared philosophy**: AI doesn't replace authoring—it requires a *different kind* of authoring focused on structure, boundaries, and intention rather than prose generation.

---

## Conclusion

Intra and Kleene independently converge on the same core architecture:

1. **External authoritative state** (not LLM memory)
2. **Bounded LLM influence** (interpretation, not control)
3. **Structured action resolution** (not freeform generation)
4. **Explicit author intention** (not delegation to AI)

Bicking's blog post provides invaluable practitioner insight into the problems that arise when building LLM games. Kleene's architecture systematically addresses most of these problems through:

- JSON Schema validation (state consistency)
- Soft consequence limits (hallucination control)
- Intent classification (suggestibility filtering)
- Decision Grid (defining what "the game" is)
- 15 analysis types (automated quality checks)

The key difference: Intra discovers these problems through development; Kleene encodes solutions into its architecture.

---

## References

**Intra:**
- Bicking, I. (2025). Intra: LLM-Driven Text Adventure. https://ianbicking.org/blog/2025/07/intra-llm-text-adventure
- Playable demo and source referenced in blog post

**Kleene Framework:**
- `lib/framework/core/core.md` - Decision Grid, completeness tiers
- `lib/framework/gameplay/improvisation.md` - Soft consequences, intent classification
- `lib/schema/scenario-schema.json` - 1100-line JSON Schema
- `skills/kleene-analyze/SKILL.md` - 15 analysis types
- `docs/design/theoretical_background.md` - Bounded creativity, parser problem
