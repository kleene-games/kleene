# Kleene: Three-Valued Narrative Framework

Named for Stephen Cole Kleene, who formalized three-valued logic in 1938.

## Core Philosophy

Every narrative moment exists in one of three states:
- **Some(value)** - The protagonist exists and can act
- **None** - The protagonist has ceased to be (death, departure, transcendence)
- **Unknown** - The narrative hasn't yet resolved this possibility

This maps to Kleene's logic: True, False, Unknown.

## The Option Type

The Option type is the container of narrative possibility:

```
Option[Character]
├── Some(character) → character exists, story continues
└── None(reason) → character absent, story may end or transform
```

### Narrative Trace

Every Option tracks its history - the sequence of transformations that led to the current state:

```
Some(hero enters) → Some(found sword) → Some(faced dragon) → None(consumed by fire)
```

This trace IS the story. The narrative emerges from the transformation history.

## Transformations

### map() - Safe Transformation

The character changes but continues to exist. The hero gains an item, learns wisdom, changes location.

```
hero.map(gain_sword) → Some(hero with sword)
```

Maps preserve existence. A Some always becomes Some (with the new value).

### and_then() - Risky Transformation

The character enters a situation that might end their existence. Fighting the dragon, crossing the chasm, confronting truth.

```
hero.and_then(fight_dragon) → Some(victorious hero) OR None(defeated)
```

This is where None enters the narrative. The transformation itself decides the outcome.

### filter() - Conditional Continuation

The character continues only if a condition is met:

```
hero.filter(has_courage >= 5) → Some(hero) OR None(courage failed)
```

## The Nine Cells

Every choice exists at the intersection of three player states and three world responses:

|                    | World Permits | World Indeterminate | World Blocks |
|--------------------|---------------|---------------------|--------------|
| **Player Chooses** | Triumph       | Commitment          | Barrier      |
| **Player Unknown** | Discovery     | Limbo               | Revelation   |
| **Player Avoids**  | Escape        | Deferral            | Fate         |

### The Axes

**Player Axis:**
- **Chooses** - Decisive action toward a goal
- **Unknown** - Hesitation, exploration, or improvised action
- **Avoids** - Retreat, refusal, or evasion

**World Axis:**
- **Permits** - World allows action to succeed
- **Indeterminate** - Outcome not yet resolved, depends on future actions
- **Blocks** - World prevents or punishes action

### Row 1: Player Chooses (Decisive Action)

**Triumph (Chooses + Permits)**
The hero acts and succeeds. Classic victory. Transformation through agency.
```
hero.and_then(fight_dragon) → Some(victorious hero)
```

**Commitment (Chooses + Indeterminate)**
Action initiated, consequences pending. The hero drinks the potion, sends the messenger, plants the trap.
```
hero.and_then(drink_potion) → Unknown(effects pending)
```

**Barrier (Chooses + Blocks)**
The hero tries but cannot proceed. Missing key, insufficient courage, locked door.
The precondition returns `Some(false)` with a reason.

### Row 2: Player Unknown (Hesitant/Improvised)

The Unknown row captures player hesitation and improvisation. These cells can be achieved two ways:

**Scripted Unknown**: Options with `cell: unknown` and `next: improvise` that explicitly invite open-ended player input. The scenario author defines patterns for Discovery/Revelation outcomes and a fallback for Limbo.

**Emergent Unknown**: Free-text "Other" input at any choice point. The play skill classifies intent and feasibility to determine which cell applies.

Both approaches are valid. Scripted Unknown guarantees coverage for the analyze skill; Emergent Unknown provides organic exploration.

**Discovery (Unknown + Permits)**
Exploration yields unexpected success. The world rewards curiosity.
```
hero.map(examine_dragon_scales) → Some(hero, +wisdom, "noticed weakness")
```
Triggered by: `permits` patterns match in improvise options, or feasibility = Possible for emergent improvisation.

**Limbo (Unknown + Indeterminate)**
The narrative center - pure potential. Player hesitates at crossroads, improvises without clear outcome.
Multiple futures remain possible. This is the chaos zone where side quests and improvisation thrive.
```
hero.filter(???) → Unknown(anything possible)
```
Triggered by: No pattern match (uses `limbo_fallback`), or feasibility = Ambiguous for emergent improvisation.

**Revelation (Unknown + Blocks)**
Hesitation reveals constraint. Failure teaches what's needed.
```
hero.map(approach_carefully) → Some(false, "You realize you cannot proceed without...")
```
Triggered by: `blocks` patterns match in improvise options, or feasibility = Blocked for emergent improvisation.

### Row 3: Player Avoids (Retreat/Refusal)

**Escape (Avoids + Permits)**
The hero could act but chooses not to. Fleeing the dragon, refusing the call.
Irony ending - survival without growth.

**Deferral (Avoids + Indeterminate)**
Problem postponed, not solved. The hero hides, ignores warnings, avoids confrontation.
A ticking clock - consequences build in the background.
```
hero.map(hide_from_dragon) → Unknown(it still hunts)
```

**Fate (Avoids + Blocks)**
The hero tries to avoid but cannot. The consequence finds them anyway.
Tragedy, fate, inevitability.

## Null Cases (None Outcomes)

### NONE_DEATH
Character ceases to exist through destruction.
```
None(consumed by dragonfire)
```

### NONE_REMOVED
Character ceases to exist through transcendence or departure.
```
None(ascended to the stars)
None(chose to remain in the fairy realm)
```

### NONE_BLOCKED
Path was impossible due to preconditions.
```
None(cannot enter without key)
```

### NONE_PROPAGATED
None propagated from an earlier state (character was already gone).

## Completeness Tiers

Narrative completeness is measured by coverage of the nine cells:

### Bronze (Original Model)
Cover the four corners - the binary foundation:
- **Triumph** (Player Chooses + World Permits)
- **Barrier** (Player Chooses + World Blocks)
- **Escape** (Player Avoids + World Permits)
- **Fate** (Player Avoids + World Blocks)

Plus: At least one NONE_DEATH path and one SOME_TRANSFORMED path.

### Silver (Extended Model)
Bronze requirements plus 2+ middle cells from:
- **Commitment** - consequences pending
- **Discovery** - exploration rewarded
- **Revelation** - failure teaches
- **Deferral** - problem postponed
- **Limbo** - pure potential (typically via improvisation)

### Gold (Full Model)
All nine cells represented. The scenario natively supports hesitation, improvisation, and indeterminate outcomes.

## A Complete Narrative

At minimum (Bronze), a narratively complete scenario must include:
1. At least one path to each corner cell (Triumph, Barrier, Escape, Fate)
2. At least one NONE_DEATH path (mortality)
3. At least one SOME_TRANSFORMED path (growth possible)
4. Ideally: NONE_REMOVED (transcendence) and SOME_UNCHANGED (irony)

For richer narratives (Silver/Gold), also include middle cells that embrace uncertainty.

## State Management

Game state consists of:

### Character State
```yaml
character:
  name: "The Wanderer"
  exists: true  # false = None
  traits:
    courage: 5
    wisdom: 5
    luck: 5
  inventory:
    - rusty_sword
    - torch
  relationships:
    elder: 3
    dragon: -2
  flags:
    knows_dragon_tongue: true
```

### World State
```yaml
world:
  current_location: village
  time: 0
  flags:
    dragon_alive: true
    village_threatened: true
```

### Narrative Trace
```yaml
history:
  - "Some(hero enters the story)"
  - "Some(took the sword)"
  - "Some(entered the forest)"
```

## Preconditions

Preconditions determine if a choice is available. They return:
- `Some(true)` - option available
- `Some(false, reason)` - option blocked, with explanation
- `None` - option impossible (character doesn't exist)

### Common Preconditions

```yaml
precondition:
  type: has_item
  item: sword

precondition:
  type: trait_minimum
  trait: courage
  minimum: 7

precondition:
  type: flag_set
  flag: knows_dragon_tongue

precondition:
  type: all_of
  conditions:
    - type: has_item
      item: sword
    - type: trait_minimum
      trait: courage
      minimum: 5
```

## Consequences

Consequences transform the game state when a choice is made:

```yaml
consequence:
  - type: gain_item
    item: ancient_key
  - type: modify_trait
    trait: wisdom
    delta: 2
  - type: set_flag
    flag: shrine_visited
    value: true
  - type: move_to
    location: mountain_path
```

### The Fatal Consequence

```yaml
consequence:
  - type: character_dies
    reason: "consumed by dragonfire"
```

This sets `character.exists: false` and records the reason in the narrative trace.

## Emergent Narrative

When the player ventures beyond known paths, the LLM generates new narrative nodes that:

1. Maintain consistency with the Option type semantics
2. Respect the current character and world state
3. Ensure at least one path forward (unless it's an ending)
4. Track the narrative trace
5. Create meaningful choices with real consequences

### Grid-Aware Generation

Improvised actions naturally map to the "Player Unknown" row:
- **Discovery** - when exploration succeeds
- **Limbo** - when intent is ambiguous
- **Revelation** - when improvisation reveals constraints

The meta-game ensures generated content maintains narrative completeness across the nine cells, with particular attention to the chaos center (Limbo) where side quests and improvised adventures thrive.

## Improvisation Routing

When a player selects an option with `next: improvise`, the system uses pattern matching to determine the outcome.

### Scripted Unknown Options

```yaml
options:
  - id: observe_dragon
    text: "Wait and observe"
    cell: unknown           # Indicates Unknown row (middle of 3x3 grid)
    next: improvise         # Triggers improvisation routing
    improvise_context:
      theme: "observing the dragon"
      permits: ["patience", "learn", "watch", "study"]  # Patterns → Discovery
      blocks: ["attack", "steal", "trick", "provoke"]   # Patterns → Revelation
      limbo_fallback: "Time stretches in the dragon's presence..."
    outcome_nodes:
      discovery: dragon_notices_patience  # Player input matches permits
      revelation: dragon_dismisses        # Player input matches blocks
      # limbo: (omitted) - stays at current node (default Limbo)
```

### Resolution Flow

1. Player selects improvise option → freeform text input requested
2. System evaluates input against `permits[]` and `blocks[]` patterns
3. **Discovery**: Input matches permits → navigate to `outcome_nodes.discovery`
4. **Revelation**: Input matches blocks → navigate to `outcome_nodes.revelation`
5. **Limbo**: No pattern match → stay at current node (use `limbo_fallback` narrative)

### Pattern Matching

Patterns in `permits` and `blocks` are treated as case-insensitive substrings:
- `"patience"` matches "I wait patiently", "patience is key", "with patience"
- `"attack"` matches "I attack the dragon", "launch an attack", "attack!"

More specific patterns should be listed before general ones for clarity.

### Static Analysis Implications

Nodes referenced in `outcome_nodes` are **conditionally reachable**:
- They cannot be reached via normal `next_node` traversal
- They ARE reachable when player input matches the appropriate pattern
- Analysis tools should report these as "reachable via improvisation" not "unreachable"

The analyze skill distinguishes between:
- **Static edges** (`next_node`) - Always in graph, unconditionally reachable
- **Dynamic edges** (`next: improvise` with `outcome_nodes`) - Conditionally reachable

This distinction is critical for accurate reachability analysis.
