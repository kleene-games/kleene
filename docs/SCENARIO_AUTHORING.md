# Scenario Authoring Guide

Create your own adaptive text adventures for Kleene. This guide takes you from minimal scenarios to advanced features.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Minimal Scenario](#minimal-scenario)
3. [Basic Branching](#basic-branching)
4. [Adding Character Depth](#adding-character-depth)
5. [Common Patterns](#common-patterns)
6. [Temperature-Aware Design](#temperature-aware-design)
7. [Advanced Features](#advanced-features)
8. [Testing & Validation](#testing--validation)
9. [Best Practices](#best-practices)
10. [Reference Tables](#reference-tables)

---

## Quick Start

**Three ways to create scenarios:**

1. **Generate with AI:** `/kleene generate a space station mystery`
2. **Use templates:** Copy `scenarios/TEMPLATES/minimal.yaml`
3. **Write from scratch:** Follow this guide

**Workflow:**
```bash
# 1. Create your scenario file
nano scenarios/my_adventure.yaml

# 2. Validate it
/kleene analyze my_adventure

# 3. Fix any issues, repeat

# 4. Playtest
/kleene play my_adventure

# 5. Test at different temperatures
/kleene temperature 0    # Traditional
/kleene temperature 10   # Emergent
```

---

## Minimal Scenario

The absolute minimum working scenario:

```yaml
name: "First Adventure"
description: "Your first Kleene scenario"

initial_character:
  name: "Hero"
  traits:
    courage: 5
  inventory: []

initial_world:
  current_location: "start"

start_node: intro

nodes:
  intro:
    narrative: |
      You stand at the entrance to a dark cave.
    choice:
      prompt: "What do you do?"
      options:
        - id: enter
          text: "Enter the cave"
          next_node: ending_brave

endings:
  ending_brave:
    narrative: |
      You entered the cave and found treasure!
    type: victory
```

**Save this as `scenarios/first_adventure.yaml` and run:**
```bash
/kleene play first_adventure
```

---

## Basic Branching

Add multiple paths and endings:

```yaml
name: "The Choice"
description: "A simple branching story"

initial_character:
  name: "Traveler"
  traits:
    courage: 5
    wisdom: 5
  inventory: []

start_node: crossroads

nodes:
  crossroads:
    narrative: |
      You reach a crossroads. The left path is dark and foreboding.
      The right path is bright but overgrown.
    choice:
      prompt: "Which path do you take?"
      options:
        - id: left
          text: "Take the dark path"
          consequence:
            - type: modify_trait
              trait: courage
              delta: 2
          next_node: dark_path

        - id: right
          text: "Take the bright path"
          consequence:
            - type: modify_trait
              trait: wisdom
              delta: 2
          next_node: bright_path

  dark_path:
    narrative: |
      The dark path leads to a dragon's lair!
    choice:
      prompt: "The dragon awakens. What do you do?"
      options:
        - id: fight
          text: "Fight the dragon"
          precondition:
            type: trait_minimum
            trait: courage
            minimum: 7
          next_node: ending_victory

        - id: flee
          text: "Run away"
          next_node: ending_escape

  bright_path:
    narrative: |
      The bright path leads to a peaceful village.
    choice:
      prompt: "The villagers welcome you."
      options:
        - id: stay
          text: "Stay and help the village"
          next_node: ending_helper

endings:
  ending_victory:
    narrative: "You defeated the dragon!"
    type: victory

  ending_escape:
    narrative: "You lived to adventure another day."
    type: unchanged

  ending_helper:
    narrative: "You became a beloved member of the community."
    type: transcendence
```

**Key concepts:**
- **Preconditions:** Gate options based on character state
- **Consequences:** Modify traits, inventory, flags
- **Multiple endings:** Different outcome types

---

## Adding Character Depth

### Traits

Track character attributes that change during gameplay:

```yaml
initial_character:
  name: "Detective"
  traits:
    investigation: 5   # Ability to find clues
    empathy: 3         # Understanding people
    corruption: 0      # Moral decay
    reputation: 10     # Public standing
```

**Use traits in preconditions:**
```yaml
options:
  - id: notice_clue
    text: "Notice the hidden bloodstain"
    precondition:
      type: trait_minimum
      trait: investigation
      minimum: 7
    next_node: clue_found
```

### Inventory

Track items the character carries:

```yaml
initial_character:
  inventory:
    - key
    - map
    - torch
```

**Check inventory:**
```yaml
precondition:
  type: has_item
  item: lockpick
```

**Gain/lose items:**
```yaml
consequence:
  - type: gain_item
    item: magic_sword
  - type: lose_item
    item: rusty_dagger
```

### Relationships

Track connections with NPCs:

```yaml
initial_character:
  relationships:
    marcus: 0      # Neutral
    villain: -10   # Enemy
    mentor: 20     # Ally
```

**Modify relationships:**
```yaml
consequence:
  - type: modify_relationship
    npc: marcus
    delta: 5  # Improves relationship
```

### Flags

Track story milestones:

```yaml
initial_character:
  flags:
    found_secret: false
    betrayed_ally: false
    knows_truth: false
```

**Check flags:**
```yaml
precondition:
  type: flag_set
  flag: found_secret
  value: true
```

**Set flags:**
```yaml
consequence:
  - type: set_flag
    flag: found_secret
    value: true
```

---

## Common Patterns

### Locked Door Pattern

```yaml
nodes:
  locked_door:
    narrative: "A locked door blocks your path."
    choice:
      prompt: "What do you do?"
      options:
        - id: use_key
          text: "Use the key"
          precondition:
            type: has_item
            item: key
          consequence:
            - type: lose_item
              item: key
            - type: set_flag
              flag: door_opened
              value: true
          next_node: beyond_door

        - id: pick_lock
          text: "Pick the lock"
          precondition:
            type: trait_minimum
            trait: dexterity
            minimum: 8
          consequence:
            - type: modify_trait
              trait: dexterity
              delta: 1
          next_node: beyond_door

        - id: go_back
          text: "Turn back"
          next_node: previous_room
```

### NPC Conversation Pattern

```yaml
nodes:
  meet_guard:
    narrative: "A guard blocks the gate."
    choice:
      prompt: "How do you approach?"
      options:
        - id: bribe
          text: "Offer a bribe"
          precondition:
            type: has_item
            item: gold
          consequence:
            - type: lose_item
              item: gold
            - type: modify_relationship
              npc: guard
              delta: 10
          next_node: gate_open

        - id: charm
          text: "Try to charm them"
          precondition:
            type: trait_minimum
            trait: charisma
            minimum: 6
          consequence:
            - type: modify_relationship
              npc: guard
              delta: 5
          next_node: guard_friendly

        - id: intimidate
          text: "Intimidate them"
          consequence:
            - type: modify_relationship
              npc: guard
              delta: -10
          next_node: guard_hostile
```

### Moral Choice Pattern

```yaml
nodes:
  moral_dilemma:
    narrative: |
      You find a wounded enemy soldier. They're helpless.
    choice:
      prompt: "What do you do?"
      options:
        - id: help
          text: "Help them"
          consequence:
            - type: modify_trait
              trait: morality
              delta: 3
            - type: modify_trait
              trait: reputation
              delta: -2  # Allies disapprove
          next_node: compassion_path

        - id: ignore
          text: "Walk away"
          consequence:
            - type: modify_trait
              trait: pragmatism
              delta: 2
          next_node: neutral_path

        - id: finish
          text: "End their suffering"
          consequence:
            - type: modify_trait
              trait: morality
              delta: -5
            - type: set_flag
              flag: killed_prisoner
              value: true
          next_node: dark_path
```

---

## Temperature-Aware Design

Design scenarios that work well at ALL temperature levels.

### At Temperature 0 (Traditional)
- Scenario plays exactly as written
- Only presented options available
- No improvisation

**Design for this:**
- Ensure presented options cover obvious actions
- Write complete, self-contained narratives
- Don't leave obvious gaps players might want to fill

### At Temperature 5-7 (Balanced)
- Player exploration gets referenced
- Bonus options may appear
- Narrative adapts subtly

**Design for this:**
- Use flags to track discoveries
- Write flexible narratives that can incorporate references
- Expect players to try unexpected things

### At Temperature 10 (Emergent)
- Fully adaptive storytelling
- Heavy improvisation
- Player actions reshape narrative

**Design for this:**
- Focus on strong thematic foundations
- Create memorable characters and conflicts
- Trust the AI to adapt your core story

### Improvisation Contexts (Advanced)

Add `improvise` options for the "Unknown" row of the Nine Cells:

```yaml
options:
  - id: observe
    text: "Wait and observe the situation"
    next: improvise
    improvise_context:
      theme: "observing the dragon"
      permits: ["scales", "eyes", "breathing", "treasure"]
      blocks: ["attack", "steal", "run"]
      limbo_fallback: "You watch, uncertain what to do."
    outcome_nodes:
      discovery: dragon_notices_patience
      revelation: dragon_dismisses_hesitation
      # limbo loops back to current node
```

**How it works:**
1. Player chooses "observe"
2. Gets sub-prompt: "What specifically do you do?"
3. Player response matched against patterns:
   - Matches `permits` → Discovery outcome
   - Matches `blocks` → Revelation outcome
   - No match → Limbo (loops back)

---

## Advanced Features

### Complex Preconditions

**All of (AND logic):**
```yaml
precondition:
  type: all_of
  conditions:
    - type: has_item
      item: sword
    - type: trait_minimum
      trait: strength
      minimum: 5
    - type: flag_set
      flag: trained_with_master
      value: true
```

**Any of (OR logic):**
```yaml
precondition:
  type: any_of
  conditions:
    - type: has_item
      item: lockpick
    - type: trait_minimum
      trait: magic
      minimum: 8
```

**None of (NOT logic):**
```yaml
precondition:
  type: none_of
  conditions:
    - type: flag_set
      flag: betrayed_ally
      value: true
```

### Multiple Consequences

Chain multiple effects:

```yaml
consequence:
  - type: gain_item
    item: legendary_sword
  - type: modify_trait
    trait: power
    delta: 5
  - type: set_flag
    flag: became_hero
    value: true
  - type: modify_relationship
    npc: mentor
    delta: 10
  - type: add_history
    entry: "Claimed the legendary sword from the stone"
```

### Location Tracking

Define locations and track movement:

```yaml
initial_world:
  current_location: "town_square"
  locations:
    - id: town_square
      name: "Town Square"
      connections: [tavern, market, gate]
    - id: tavern
      name: "The Dragon's Rest Tavern"
      connections: [town_square]
```

**Move between locations:**
```yaml
consequence:
  - type: move_to
    location: tavern
```

**Require specific location:**
```yaml
precondition:
  type: at_location
  location: blacksmith
```

### Scene Pacing

Use `scene_break: true` on nodes that represent major transitions:

```yaml
nodes:
  chapter_two:
    scene_break: true
    narrative: |
      Three days later, you wake in an unfamiliar room...
```

**Scene break triggers:**
- Explicit `scene_break: true` on node
- Location change (different `current_location`)
- Time skip (via `advance_time` consequence)
- 5+ beats accumulated since last scene break

This affects how scenes are tracked in gameplay headers and how exports are organized by granularity level.

### Consequence Magnitude

Scale consequences appropriately based on action significance:

| Action Type | Trait Change | Relationship Change |
|-------------|-------------|---------------------|
| Improvised exploration | ±1 | ±1-2 |
| Minor scripted choice | ±2-3 | ±3-5 |
| Major decision | ±5-10 | ±10-15 |
| Catastrophic event | ±15-50 | ±25-50 |

**Example - catastrophic betrayal:**
```yaml
consequence:
  - type: modify_trait
    trait: trust
    amount: -25    # Major negative impact
  - type: modify_relationship
    target: mayor
    amount: -50    # Relationship destroyed
```

**Guidelines:**
- Small changes accumulate over time
- Reserve large deltas for pivotal moments
- Negative consequences should feel proportional to player action
- Consider trait caps (typically 0-100)

---

## Testing & Validation

### Use the Analyzer

```bash
/kleene analyze my_scenario
```

**Checks for:**
- Missing node references
- Orphaned nodes
- Missing endings
- Invalid precondition/consequence types
- YAML syntax errors

### Playtesting Checklist

- [ ] Play at temperature 0 (traditional)
- [ ] Play at temperature 5 (balanced)
- [ ] Play at temperature 10 (emergent)
- [ ] Try all major paths
- [ ] Reach all endings
- [ ] Test preconditions work correctly
- [ ] Verify consequences apply
- [ ] Try free-text actions at high temp
- [ ] Check for typos and formatting
- [ ] Confirm content warnings are accurate

### Common Issues

**"Can't reach certain endings"**
- Check preconditions aren't too restrictive
- Ensure paths exist to all endings
- Verify flags/items are obtainable

**"Options appear when they shouldn't"**
- Review precondition logic
- Check flag states
- Verify trait thresholds

**"Narrative feels disconnected"**
- Add more consequence types
- Use `add_history` to track journey
- Reference character state in narratives

**"Too linear"**
- Add more branching points
- Create optional side paths
- Offer meaningful choices (not illusions)

---

## Best Practices

### Design Philosophy

1. **Start with endings, work backward**
   - Define 3-5 distinct endings
   - Map paths to reach each
   - Ensure interesting choices along the way

2. **Respect player agency**
   - Avoid false choices (different text, same outcome)
   - Make consequences meaningful
   - Don't railroad players

3. **Balance challenge and accessibility**
   - Not all endings should be equally easy
   - But all should be reachable
   - Use preconditions thoughtfully

### Writing Tips

1. **Show, don't tell**
   - ❌ "You feel scared"
   - ✅ "Your hands shake as you reach for the door"

2. **Use active voice**
   - ❌ "The dragon is approached by you"
   - ✅ "You approach the dragon"

3. **Keep it concise**
   - Short paragraphs (2-4 sentences)
   - Clear choices
   - Punchy endings

4. **Match tone throughout**
   - Serious scenario = serious text
   - Comedic scenario = light tone
   - Horror scenario = atmospheric language

### Structure Guidelines

**Scenario size recommendations:**

| Size | Nodes | Endings | Playtime | Best For |
|------|-------|---------|----------|----------|
| Minimal | 5-10 | 2-3 | 5-10 min | Learning, testing |
| Small | 10-20 | 3-4 | 15-20 min | Focused stories |
| Medium | 20-40 | 4-6 | 30-45 min | Rich narratives |
| Large | 40-80 | 6-10 | 60-90 min | Epic adventures |
| Massive | 80+ | 10+ | 2+ hours | Campaigns |

**Node design:**
- Each node = one scene or moment
- Narrative: 2-5 sentences
- Options: 2-4 choices
- Use `improvise` for Unknown options

### Content Warnings

Add warnings for sensitive content:

```yaml
# In registry.yaml:
my_scenario:
  content_warnings:
    - "violence"
    - "psychological themes"
    - "substance use"
    - "moral ambiguity"
```

**When to warn:**
- Violence or gore
- Psychological horror
- Substance use/abuse
- Sexual content
- Death/suicide
- Trauma themes
- Discrimination/prejudice

---

## Reference Tables

### Precondition Types

| Type | Parameters | Example |
|------|------------|---------|
| `has_item` | `item` | Has specific item in inventory |
| `missing_item` | `item` | Doesn't have item |
| `trait_minimum` | `trait`, `minimum` | Trait >= value |
| `trait_maximum` | `trait`, `maximum` | Trait <= value |
| `flag_set` | `flag`, `value` | Flag equals value |
| `flag_not_set` | `flag` | Flag not true |
| `at_location` | `location` | At specific location |
| `relationship_minimum` | `npc`, `minimum` | Relationship >= value |
| `all_of` | `conditions[]` | All conditions true (AND) |
| `any_of` | `conditions[]` | Any condition true (OR) |
| `none_of` | `conditions[]` | No conditions true (NOT) |

### Consequence Types

| Type | Parameters | Effect |
|------|------------|--------|
| `gain_item` | `item` | Add item to inventory |
| `lose_item` | `item` | Remove item from inventory |
| `modify_trait` | `trait`, `delta` | Change trait by delta (+/-) |
| `set_trait` | `trait`, `value` | Set trait to exact value |
| `set_flag` | `flag`, `value` | Set flag to value |
| `clear_flag` | `flag` | Set flag to false |
| `modify_relationship` | `npc`, `delta` | Change relationship by delta |
| `move_to` | `location` | Move to location |
| `advance_time` | `delta` | Increase time counter |
| `character_dies` | `reason` | End game (death) |
| `character_departs` | - | End game (transcendence) |
| `add_history` | `entry` | Add to narrative history |

### Ending Types

| Type | Meaning | Typical Use |
|------|---------|-------------|
| `victory` | Protagonist wins | Defeating the villain, achieving goal |
| `death` | Protagonist dies | Combat loss, fatal mistake |
| `transcendence` | Protagonist transforms | Leaving mortality, ascension, departure |
| `unchanged` | Protagonist unchanged | Escape, stagnation, ironic endings |

---

## Next Steps

**Ready to create?**
1. Check out `scenarios/TEMPLATES/` for starter templates
2. Study `scenarios/dragon_quest.yaml` for a complete example
3. Read the [full format specification](../lib/framework/scenario-format.md)
4. Share your scenario - see [CONTRIBUTING.md](../CONTRIBUTING.md)

**Need help?**
- [FAQ](FAQ.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [GitHub Issues](https://github.com/hiivmind/kleene/issues)

**Happy creating!** 🎮✨
