# Kleene: Three-Valued Narrative Framework

Named for Stephen Cole Kleene, who formalized three-valued logic in 1938.

## Core Philosophy

Every narrative moment presents a choice. The player acts (or hesitates, or refuses), and the world responds (permits, blocks, or leaves the outcome hanging). This intersection produces nine distinct narrative outcomes.

**The Player's Intent**
- **Chooses** - Takes decisive action toward a goal
- **Unknown** - Hesitates, explores, or improvises (free-text input)
- **Avoids** - Retreats, refuses, or evades

**The World's Response**
- **Permits** - The action succeeds
- **Blocks** - The action fails (precondition not met, consequence prevents it)
- **Indeterminate** - The outcome hasn't resolved yet

**The Decision Grid**
These axes intersect to produce 9 cells - the complete space of narrative outcomes:

|                    | World Permits (t) | World Indeterminate (u) | World Blocks (f) |
|--------------------|-------------------|-------------------------|------------------|
| **Player Chooses** | Triumph           | Commitment              | Rebuff           |
| **Player Unknown** | Discovery         | Limbo                   | Constraint       |
| **Player Avoids**  | Escape            | Deferral                | Fate             |


> For the theoretical foundations in Kleene logic and game theory, see [theoretical_background.md](theoretical_background.md).

## The Option Type

The Option type wraps narrative possibility:

```
Option[Character]
├── Some(character) → character exists, story continues
└── None(reason)    → character absent, story may end
```

Every Option tracks its history—the sequence of transformations that led here:

```
Some(hero enters) → Some(found sword) → Some(faced dragon) → None(consumed by fire)
```

This trace IS the story.

### Transformations

**map() - Safe Change**
Your character changes but survives. Gain a sword, learn a secret, move locations.
```
hero.map(gain_sword) → Some(hero with sword)
```

**and_then() - Risky Action**
Your character enters danger that might end them. Fight the dragon, cross the chasm.
```
hero.and_then(fight_dragon) → Some(victorious) OR None(defeated)
```

**filter() - Conditional Gate**
Continue only if a condition is met:
```
hero.filter(courage >= 5) → Some(hero) OR None(courage failed)
```

## The Decision Grid

Every choice exists at the intersection of player intent and world response. The 3×3 grid captures all possible narrative outcomes.

### Row 1: Player Chooses (Decisive Action)

| Cell | What Happens |
|------|--------------|
| **Triumph** | You acted and succeeded. Classic victory. |
| **Commitment** | Action started, consequences pending. The potion's effects haven't manifested yet. |
| **Rebuff** | You tried but something blocks you. Missing key, locked door, insufficient courage. |

### Row 2: Player Unknown (Hesitant/Improvised)

This row captures hesitation and improvisation—both scripted options and free-text input.

| Cell | What Happens |
|------|--------------|
| **Discovery** | Exploration succeeds. The world rewards your curiosity. |
| **Limbo** | Pure potential. Multiple futures remain possible. The chaos zone where side quests thrive. |
| **Constraint** | Hesitation reveals limitation. You learn what you're missing. |

### Row 3: Player Avoids (Retreat/Refusal)

| Cell | What Happens |
|------|--------------|
| **Escape** | You could act but chose not to. Survival without growth. |
| **Deferral** | Problem postponed, not solved. Consequences build in the background. |
| **Fate** | You tried to avoid but couldn't. The consequence finds you anyway. |

## Story Endings

When the narrative reaches an ending, it's classified by the character's final state:

| Ending Type | Option State | Meaning |
|-------------|--------------|---------|
| **victory** | Some | Survives, transformed |
| **unchanged** | Some | Survives, unchanged |
| **death** | None | Destroyed |
| **transcendence** | None | Departed |

Ending types are **orthogonal** to the Decision Grid—any cell can lead to any ending.

> **Full reference:** See [endings.md](endings.md) for author guidance and design patterns.

## Completeness Tiers

Narrative completeness is measured by coverage of the **9 Decision Grid cells**:

### Bronze (4/9 cells)
Cover the four corners—the binary foundation:
- **Triumph** (Player Chooses + World Permits)
- **Rebuff** (Player Chooses + World Blocks)
- **Escape** (Player Avoids + World Permits)
- **Fate** (Player Avoids + World Blocks)

Plus: At least one NONE_DEATH path and one SOME_TRANSFORMED path.

### Silver (6+/9 cells)
Bronze requirements plus 2+ middle cells from:
- **Commitment** - consequences pending
- **Discovery** - exploration rewarded
- **Constraint** - failure teaches
- **Deferral** - problem postponed
- **Limbo** - pure potential (typically via improvisation)

### Gold (9/9 cells)
All 9 grid intersections represented. The scenario natively supports hesitation, improvisation, and indeterminate outcomes.

### A Complete Narrative

At minimum (Bronze), a narratively complete scenario must include:
1. At least one path to each corner cell (Triumph, Rebuff, Escape, Fate)
2. At least one NONE_DEATH path (mortality)
3. At least one SOME_TRANSFORMED path (growth possible)
4. Ideally: NONE_REMOVED (transcendence) and SOME_UNCHANGED (irony)

## Implementation Reference

State management, preconditions, and consequences are fully specified in operational documents:

| Topic | Document |
|-------|----------|
| State structure (character, world, history) | [scenario-format.md](scenario-format.md), [saves.md](saves.md) |
| Precondition types (21 types) | [scenario-format.md](scenario-format.md#precondition-types) |
| Consequence types (23+ types) | [scenario-format.md](scenario-format.md#consequence-types) |
| Evaluation logic | [evaluation-reference.md](evaluation-reference.md) |

**Conceptual overview:** Preconditions gate which options appear. Consequences transform state when options are chosen. Both operate on the Option type semantics defined above.

## Emergent Narrative

When players venture beyond scripted paths, the system generates new narrative that:
- Maintains Option type semantics (Some continues, None ends)
- Respects current character and world state
- Creates meaningful choices with real consequences
- Maps improvised actions to the "Player Unknown" row (Discovery, Limbo, or Constraint)

The meta-game ensures generated content maintains narrative completeness across the Decision Grid.

## Improvisation

When players type custom actions instead of selecting options, the system classifies their intent and determines if the world permits, blocks, or leaves the outcome open. This maps to the **Unknown row** of the Decision Grid.

> **Full specification:** See [improvisation.md](improvisation.md) for pattern matching, outcome routing, soft consequences, and static analysis implications.
