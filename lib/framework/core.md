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

## The Four Quadrants

Every choice exists at the intersection of two axes:

|                    | World Permits          | World Blocks           |
|--------------------|------------------------|------------------------|
| **Player Chooses** | Victory/Transformation | Blocked Path           |
| **Player Avoids**  | Escape/Unchanged       | Forced Consequence     |

### Quadrant 1: Player Chooses, World Permits
The hero acts and succeeds. Classic victory. Transformation through agency.

### Quadrant 2: Player Chooses, World Blocks
The hero tries but cannot proceed. Missing key, insufficient courage, locked door.
The precondition returns `Some(false)` with a reason.

### Quadrant 3: Player Avoids, World Permits
The hero could act but chooses not to. Fleeing the dragon, refusing the call.
Irony ending - survival without growth.

### Quadrant 4: Player Avoids, World Blocks
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

## A Complete Narrative

A narratively complete scenario must include:
1. At least one path to each quadrant
2. At least one NONE_DEATH path (mortality)
3. At least one SOME_TRANSFORMED path (growth possible)
4. Ideally: NONE_REMOVED (transcendence) and SOME_UNCHANGED (irony)

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

The meta-game ensures the generated content maintains narrative completeness across all quadrants.
