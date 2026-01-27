# Kleene v5 Best Practices

Design patterns and guidelines for creating rich, maintainable scenarios using Kleene v5 features.

---

## Location State Patterns

### When to Use Flags vs Properties

**Use flags for:**
- Binary states (visited/not visited, locked/unlocked, discovered/hidden)
- Event completion markers (quest_completed, ritual_performed)
- One-time changes (door_opened, seal_broken)

```yaml
location_state:
  shrine:
    flags:
      visited: true
      sealed: false
      ritual_completed: true
```

**Use properties for:**
- Numeric values that change over time (population, power_level, damage)
- Resources that can increase or decrease (gold_stored, magic_reserves)
- Gradual changes (corruption_level, blessing_strength)

```yaml
location_state:
  village:
    properties:
      population: 150
      prosperity: 75
  shrine:
    properties:
      blessing_power: 100
      corruption: 0
```

### Environment for Atmosphere

Use environment properties to track sensory state that affects narrative:

```yaml
initial_state:
  environment:
    lighting: dim        # bright, dim, dark, mystical
    ambiance: sacred     # peaceful, tense, eerie, chaotic
    temperature: cool    # cold, cool, warm, hot
    weather: clear       # clear, foggy, rainy, stormy
```

**Pattern: Dynamic Environment**

```yaml
# Consequence that changes environment
- type: set_environment
  property: lighting
  value: dark

# Precondition that checks environment
precondition:
  type: environment_is
  property: lighting
  value: dark
```

### Location State vs Global Flags

**Prefer location state when:**
- The state is logically tied to a place
- Multiple locations need independent tracking of similar states
- You want to query "what's the state at location X?"

**Prefer global flags when:**
- The state applies game-wide (dragon_alive, war_started)
- The state follows the player, not the location
- Simple binary choices that don't need location context

---

## Node Gating Patterns

### Progressive Unlocks

Build requirements gradually through gameplay:

```yaml
nodes:
  inner_sanctum:
    precondition:
      type: all_of
      conditions:
        - type: flag_set
          flag: completed_trial
        - type: relationship_minimum
          npc: guardian
          minimum: 10
        - type: trait_minimum
          trait: courage
          minimum: 8

    blocked_narrative: |
      Three requirements bar your path:
      - Complete the guardian's trial
      - Earn the guardian's deep trust
      - Develop sufficient courage
```

### Multi-Path Access

Allow different approaches to unlock the same destination:

```yaml
nodes:
  dragon_lair:
    precondition:
      type: any_of
      conditions:
        # Combat path
        - type: all_of
          conditions:
            - type: has_item
              item: dragon_slayer_sword
            - type: trait_minimum
              trait: combat
              minimum: 10

        # Stealth path
        - type: all_of
          conditions:
            - type: has_item
              item: invisibility_cloak
            - type: trait_minimum
              trait: cunning
              minimum: 8

        # Diplomatic path
        - type: all_of
          conditions:
            - type: flag_set
              flag: speaks_dragon_tongue
            - type: relationship_minimum
              npc: dragon
              minimum: 5
```

### Always Provide Blocked Narrative

Make blocked_narrative informative and actionable:

```yaml
# Good - tells player what they need
blocked_narrative: |
  The ancient doors recognize no claim to entry.
  You sense they require proof of the guardian's blessing
  and mastery of the old tongue.

# Bad - vague and unhelpful
blocked_narrative: |
  You cannot enter.
```

---

## NPC Movement Patterns

### Following the Player

Have NPCs join and follow the player:

```yaml
# NPC follows player after joining party
consequence:
  - type: move_npc
    npc: companion
    location: current  # Moves to player's location

# Check if companion is present
precondition:
  type: npc_at_location
  npc: companion
  location: current
```

### Schedule-Based Movement

NPCs that move on their own schedule:

```yaml
# Initial placement
initial_world:
  npc_locations:
    merchant: market
    guard: gate_house

  scheduled_events:
    # Guard changes shift at noon
    - event_id: guard_shift_change
      trigger_at: 43200
      consequences:
        - type: move_npc
          npc: guard
          location: barracks
        - type: move_npc
          npc: night_guard
          location: gate_house

    # Merchant goes home at 5 PM
    - event_id: merchant_closes
      trigger_at: 61200
      consequences:
        - type: move_npc
          npc: merchant
          location: merchant_home
```

### Event-Triggered Relocation

NPCs that respond to world events:

```yaml
consequence:
  - type: schedule_event
    event_id: dragon_attack
    delay:
      amount: 6
      unit: hours
    consequences:
      # Dragon arrives
      - type: move_npc
        npc: dragon
        location: village_square

      # Villagers flee
      - type: move_npc
        npc: elder
        location: hidden_cave
      - type: move_npc
        npc: merchant
        location: hidden_cave
```

### NPC Presence Gates

Create opportunities that only exist when NPCs are present:

```yaml
options:
  - id: learn_secret
    text: "Ask the elder about the ancient prophecy"
    precondition:
      type: all_of
      conditions:
        - type: npc_at_location
          npc: elder
          location: current
        - type: relationship_minimum
          npc: elder
          minimum: 10
```

---

## Temporal Design Patterns

### Day/Night Cycles

Create time-based atmosphere shifts:

```yaml
initial_world:
  time: 21600  # 6 AM

  scheduled_events:
    - event_id: morning
      trigger_at: 21600
      consequences:
        - type: set_flag
          flag: time_of_day_morning
          value: true
        - type: set_environment
          location: village
          property: lighting
          value: dawn

    - event_id: noon
      trigger_at: 43200
      consequences:
        - type: clear_flag
          flag: time_of_day_morning
        - type: set_flag
          flag: time_of_day_afternoon
          value: true

    - event_id: evening
      trigger_at: 64800
      consequences:
        - type: clear_flag
          flag: time_of_day_afternoon
        - type: set_flag
          flag: time_of_day_evening
          value: true
        - type: set_environment
          location: village
          property: lighting
          value: dusk

    - event_id: night
      trigger_at: 75600
      consequences:
        - type: clear_flag
          flag: time_of_day_evening
        - type: set_flag
          flag: time_of_day_night
          value: true
```

### Deadline Mechanics

Create urgency with time limits:

```yaml
# Schedule a deadline
consequence:
  - type: schedule_event
    event_id: village_destroyed
    delay:
      amount: 24
      unit: hours
    consequences:
      - type: set_flag
        flag: too_late
        value: true

# Check if deadline passed
options:
  - id: save_village
    text: "Rush to defend the village"
    precondition:
      type: event_not_triggered
      event_id: village_destroyed

# Cancel deadline by completing objective
consequence:
  - type: cancel_event
    event_id: village_destroyed
  - type: set_flag
    flag: village_saved
    value: true
```

### Delayed Consequences

Actions that have effects later:

```yaml
# Planting seeds
consequence:
  - type: schedule_event
    event_id: crops_ready
    delay:
      amount: 3
      unit: days
    consequences:
      - type: set_location_flag
        location: farm
        flag: crops_harvestable
        value: true

# Sending a messenger
consequence:
  - type: schedule_event
    event_id: reinforcements_arrive
    delay:
      amount: 2
      unit: days
    consequences:
      - type: move_npc
        npc: cavalry
        location: village
      - type: modify_location_property
        location: village
        property: defense_strength
        delta: 50
```

---

## Event Scheduling Strategies

### Cascading Events

Events that trigger other events:

```yaml
# Main event triggers chain reaction
scheduled_events:
  - event_id: volcano_erupts
    trigger_at: 86400
    consequences:
      - type: set_flag
        flag: volcano_active
        value: true
      # Schedule follow-up events
      - type: schedule_event
        event_id: lava_reaches_village
        delay:
          amount: 2
          unit: hours
        consequences:
          - type: set_location_flag
            location: village
            flag: threatened
            value: true
      - type: schedule_event
        event_id: ash_blocks_sun
        delay:
          amount: 6
          unit: hours
        consequences:
          - type: set_environment
            location: all
            property: lighting
            value: dark
```

### Cancelable Timers

Events that can be stopped:

```yaml
# Start a dangerous countdown
consequence:
  - type: schedule_event
    event_id: bomb_explodes
    delay:
      amount: 30
      unit: minutes
    consequences:
      - type: set_flag
        flag: building_destroyed
        value: true
      - type: character_dies
        reason: "consumed in the explosion"

# Option to defuse
options:
  - id: defuse
    text: "Attempt to defuse the bomb"
    precondition:
      type: all_of
      conditions:
        - type: has_item
          item: wire_cutters
        - type: trait_minimum
          trait: dexterity
          minimum: 8
    consequence:
      - type: cancel_event
        event_id: bomb_explodes
      - type: set_flag
        flag: bomb_defused
        value: true
```

### Player-Triggered vs Automatic

**Automatic events (scheduled at game start):**
- Day/night transitions
- NPC schedules (merchant opens shop at 9 AM)
- Natural phenomena (tides, weather patterns)

**Player-triggered events (scheduled via actions):**
- Consequences of player choices (sending a message)
- Deadlines started by story events
- Time limits on quests

---

## Improvisation Patterns

### Good Pattern Keywords

**Discovery (permits) - exploratory, patient, respectful:**
```yaml
permits:
  - watch          # Observation
  - listen         # Attention
  - study          # Learning
  - patience       # Waiting
  - respect        # Deference
  - ask            # Inquiry
  - examine        # Investigation
  - bow            # Reverence
```

**Constraint (blocks) - aggressive, disrespectful, hasty:**
```yaml
blocks:
  - attack         # Violence
  - demand         # Aggression
  - steal          # Theft
  - threaten       # Intimidation
  - force          # Coercion
  - mock           # Disrespect
  - rush           # Impatience
  - lie            # Deception
```

### Context-Appropriate Themes

Match patterns to the situation:

```yaml
# Temple guardian - values respect and patience
improvise_context:
  theme: "approaching a sacred guardian"
  permits: ["bow", "prayer", "offering", "ceremony", "patience"]
  blocks: ["demand", "threaten", "mock", "rush", "steal"]

# Wild animal - values calm and non-threat
improvise_context:
  theme: "encountering a wild creature"
  permits: ["still", "quiet", "slow", "gentle", "offer food"]
  blocks: ["loud", "sudden", "chase", "corner", "threaten"]

# Suspicious merchant - values business
improvise_context:
  theme: "negotiating with a wary merchant"
  permits: ["trade", "offer", "coin", "fair", "value"]
  blocks: ["threaten", "steal", "demand", "cheat", "intimidate"]
```

### Limbo Fallback Quality

Make limbo_fallback feel like a valid narrative beat, not a failure:

```yaml
# Good - creates atmosphere and suggests next action
limbo_fallback: |
  Time stretches in the dragon's presence. Your improvised
  approach yields nothing definitive - neither progress nor
  setback. The moment holds, pregnant with possibility.

# Bad - feels like punishment
limbo_fallback: "Nothing happens. Try again."
```

---

## General Best Practices

### 1. Test with /kleene analyze

Always run analysis to catch:
- Orphaned nodes from improvisation outcomes
- Flags checked but never set
- NPCs referenced but not defined
- Events scheduled but never checked

### 2. Provide Clear Feedback

When blocking player progress, always explain:
- What's needed (items, traits, flags)
- Where to get it (if not a spoiler)
- Why it matters narratively

### 3. Balance Time Advancement

- Small actions: 5-15 minutes
- Conversations: 15-30 minutes
- Travel between areas: 30 minutes - 2 hours
- Rest/sleep: 6-8 hours
- Significant undertakings: varies

### 4. Use Lazy Initialization

Don't pre-define every location's state. Let it initialize on first use:

```yaml
# Don't do this
location_state:
  location_1: { flags: {}, properties: {} }
  location_2: { flags: {}, properties: {} }
  location_3: { flags: {}, properties: {} }
  # ... 50 more empty entries

# Do this - define only what has initial values
location_state:
  village:
    flags: { visited: true }
    properties: { population: 150 }
  # Other locations initialize when first modified
```

### 5. Group Related Consequences

Keep related changes together for clarity:

```yaml
# Good - grouped by effect
consequence:
  # Quest completion effects
  - type: set_flag
    flag: quest_completed
    value: true
  - type: modify_relationship
    npc: quest_giver
    delta: 15

  # Rewards
  - type: gain_item
    item: enchanted_sword
  - type: modify_trait
    trait: reputation
    delta: 5

  # Scheduled follow-up
  - type: schedule_event
    event_id: celebration
    delay:
      amount: 1
      unit: days
    consequences: [...]
```

---

## See Also

- [Migration Guide](./migration-v2.md) - Upgrading from v4
- [Scenario Format](../framework/scenario-format.md) - Complete YAML reference
- [Advanced Template](../../lib/framework/authoring/TEMPLATES/advanced.yaml) - Feature showcase
- [Temporal Template](../../lib/framework/authoring/TEMPLATES/temporal_example.yaml) - Time system focus
