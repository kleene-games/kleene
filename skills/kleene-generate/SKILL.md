---
name: kleene-generate
description: This skill should be used when the user asks to "generate a scenario", "create a new quest", "make me a game about...", "expand the story", "generate a new path", or when the player ventures beyond known scenario boundaries during gameplay. Generates narratively complete scenarios using Option type semantics and the Nine Cells framework.
version: 0.2.0
---

# Kleene Generate Skill

Generate new scenarios or expand existing ones using LLM capabilities while maintaining Option type semantics and narrative completeness according to the Nine Cells framework.

## Generation Modes

### Mode 1: Full Scenario Generation

Create a complete new scenario from a theme or prompt.

**Input**: Theme description (e.g., "a haunted mansion mystery")
**Output**: Complete `scenario.yaml` file

### Mode 2: Node Generation (Emergent Play)

Generate new nodes when player ventures beyond known paths.

**Input**: Current game state, player's attempted action
**Output**: New node(s) that integrate with existing scenario

### Mode 3: Branch Expansion

Add new branches to an existing scenario to improve grid coverage and raise tier level.

**Input**: Existing scenario, analysis showing missing cells
**Output**: New nodes that fill narrative gaps and advance tier

## Full Scenario Generation

### Step 1: Understand the Theme

Use `AskUserQuestion` to gather key decisions. Group related choices in a single call:

```json
{
  "questions": [
    {
      "question": "What tone should the scenario have?",
      "header": "Tone",
      "multiSelect": false,
      "options": [
        {"label": "Heroic", "description": "Epic triumphs and noble sacrifices"},
        {"label": "Tragic", "description": "Loss, consequence, and bittersweet endings"},
        {"label": "Comedic", "description": "Humor, absurdity, and lighthearted outcomes"},
        {"label": "Mysterious", "description": "Secrets to uncover, nothing is as it seems"}
      ]
    },
    {
      "question": "What completeness tier should we target?",
      "header": "Tier",
      "multiSelect": false,
      "options": [
        {"label": "Bronze (Recommended)", "description": "4 corner cells - focused, clear narrative"},
        {"label": "Silver", "description": "6+ cells - adds uncertainty and exploration"},
        {"label": "Gold", "description": "All 9 cells - full chaos, improv-friendly"}
      ]
    }
  ]
}
```

For protagonist archetype, use a separate call (progressive disclosure):

```json
{
  "questions": [
    {
      "question": "What kind of protagonist?",
      "header": "Protagonist",
      "multiSelect": false,
      "options": [
        {"label": "Reluctant hero", "description": "Drawn into adventure despite themselves"},
        {"label": "Chosen one", "description": "Destined for greatness from the start"},
        {"label": "Antihero", "description": "Morally ambiguous, flawed but compelling"},
        {"label": "Everyman", "description": "Ordinary person in extraordinary circumstances"}
      ]
    }
  ]
}
```

**Menu Guidelines:**
- **Headers**: Max 12 characters
- **Labels**: 1-5 words, concise
- **Descriptions**: Action-oriented, explain consequences
- **Recommended**: Place first with "(Recommended)" suffix

### Step 2: Design the Narrative Skeleton

Create the core structure based on target tier:

**Bronze (4 corners):**
```
START
  ├── Path A (decisive action)
  │   ├── A1: Triumph (Chooses + Permits) → Victory
  │   └── A2: Barrier (Chooses + Blocks) → Blocked/Death
  └── Path B (avoidance)
      ├── B1: Escape (Avoids + Permits) → Unchanged
      └── B2: Fate (Avoids + Blocks) → Forced consequence
```

**Silver (Bronze + middle cells):**
```
START
  ├── Path A (decisive action)
  │   ├── A1: Triumph → Victory
  │   ├── A2: Commitment (Chooses + Indeterminate) → Pending outcome
  │   └── A3: Barrier → Blocked
  ├── Path B (exploration/hesitation)
  │   └── B1: Discovery (Unknown + Permits) → Insight gained
  └── Path C (avoidance)
      ├── C1: Escape → Unchanged
      └── C2: Deferral (Avoids + Indeterminate) → Tension building
```

**Gold (all 9 cells):**
Include explicit nodes for all cells. The "Unknown" row (Discovery, Limbo, Revelation) can be reached through exploration options or improvised play.

### Step 3: Define Key Elements

**Character Traits**: Choose 3-5 relevant traits
```yaml
traits:
  courage: 5    # For combat/confrontation
  wisdom: 5     # For puzzles/dialogue
  luck: 5       # For chance events
  stealth: 5    # For infiltration
  charisma: 5   # For social situations
```

**Key Items**: 3-7 items that enable different paths
```yaml
items:
  - weapon (enables combat)
  - key_item (enables locked path)
  - knowledge_item (enables dialogue/wisdom path)
```

**Flags**: Boolean states that track progress
```yaml
flags:
  - secret_discovered
  - ally_gained
  - enemy_hostile
```

### Step 4: Generate Nodes

For each node, ensure:

1. **Narrative**: Evocative, atmospheric description
2. **Choice**: 2-4 meaningful options
3. **Preconditions**: At least one option with preconditions
4. **Consequences**: State changes that matter
5. **Connections**: Clear paths to other nodes

### Step 5: Ensure Grid Coverage

Verify scenario coverage based on target tier:

**Bronze (Required):**
- [ ] Triumph (Chooses + Permits) - victory/transformation
- [ ] Barrier (Chooses + Blocks) - blocked path
- [ ] Escape (Avoids + Permits) - unchanged/survival
- [ ] Fate (Avoids + Blocks) - forced consequence
- [ ] At least one NONE_DEATH path (mortality)
- [ ] At least one SOME_TRANSFORMED path (growth)

**Silver (Bronze + 2 of these):**
- [ ] Commitment (Chooses + Indeterminate) - action with pending outcome
- [ ] Discovery (Unknown + Permits) - exploration rewarded
- [ ] Revelation (Unknown + Blocks) - hesitation reveals constraint
- [ ] Deferral (Avoids + Indeterminate) - avoidance postpones consequence
- [ ] Limbo (Unknown + Indeterminate) - typically via improvisation

**Gold:** All nine cells represented

### Step 6: Write YAML

Output complete scenario in proper format.

### Step 7: Register Generated Scenario

After writing the scenario file to `${CLAUDE_PLUGIN_ROOT}/scenarios/[filename].yaml`:

1. **Read the saved file** to extract canonical metadata:
   - `name` field (or `title`, or `metadata.title`)
   - `description` field (or `metadata.description`)

2. **Derive scenario ID** from filename (e.g., `haunted_mansion` from `haunted_mansion.yaml`)

3. **Load existing registry**:
   - Read `${CLAUDE_PLUGIN_ROOT}/scenarios/registry.yaml`
   - If registry doesn't exist, create empty structure:
     ```yaml
     version: 1
     last_synced: null
     scenarios: {}
     ```

4. **Add new entry** to registry:
   ```yaml
   haunted_mansion:
     name: "The Haunted Mansion"
     description: "Explore a decrepit estate filled with mystery and horror"
     path: haunted_mansion.yaml
     enabled: true
     tags: ["generated", "user-created"]
   ```

5. **Write updated registry** back to disk

6. **Confirm** to user: "Scenario saved and registered as 'The Haunted Mansion'"

This ensures generated scenarios immediately appear in `/kleene play` menus without requiring manual `/kleene sync`.

## Emergent Node Generation

> **Note**: Mode 2 is now handled **inline by kleene-play** via its "Improvised Action Handling" section. This documentation provides reference guidance for that implementation.

When a player provides free-text input via "Other", kleene-play generates a narrative response inline rather than calling this skill separately. The approach is **flavor text + soft consequences** - the game acknowledges the player's action creatively without creating permanent new nodes.

### How It Works (in kleene-play)

1. Player selects "Other" and types custom action
2. kleene-play classifies intent (Explore/Interact/Act/Meta)
3. Checks feasibility against current state
4. Generates narrative response matching scenario tone
5. Applies soft consequences only (trait ±1, history, improv_* flags)
6. Returns to current node's predefined options

See: `kleene-play` skill → "Improvised Action Handling" section

### Context for Response Generation

When generating improvised responses, consider:
- Current location and its description
- Character traits, inventory, flags
- World flags and time
- Recent history (last 3-5 entries)
- What the player is attempting

### Generation Constraints

Improvised responses must:

1. **Respect State**: Only reference items/flags that exist
2. **Stay Local**: Don't advance the story, enrich the current moment
3. **Soft Consequences Only**: trait ±1, add_history, improv_* flags
4. **Maintain Tone**: Match the scenario's established voice
5. **Return to Options**: After response, show current node's choices again

### What's NOT Allowed in Improvisation

- Creating permanent new scenario nodes
- Gaining/losing scenario items
- Changing location
- Killing or transcending the character
- Bypassing major story gates

## Branch Expansion

Given an analysis showing missing cells or tier gaps:

### For Missing "Player Avoids" Paths

Add options that allow retreat or refusal:
```yaml
- id: refuse_quest
  text: "This is not my fight"
  consequence:
    - type: modify_trait
      trait: courage
      delta: -1
  narrative: "You turn away from destiny."
  next_node: ending_unchanged
```

### For Missing Death Paths

Add risky options with fatal consequences:
```yaml
- id: reckless_action
  text: "Charge in without preparation"
  precondition:
    type: none_of
    conditions:
      - type: has_item
        item: armor
  consequence:
    - type: character_dies
      reason: "fell to overwhelming force"
  next_node: ending_death
```

### For Missing Transcendence Paths

Add paths that transform rather than defeat:
```yaml
- id: understand_enemy
  text: "Seek to understand rather than destroy"
  precondition:
    type: trait_minimum
    trait: wisdom
    minimum: 8
  consequence:
    - type: character_departs
      reason: "ascended to a higher understanding"
  next_node: ending_transcendence
```

### For Silver Tier: Middle Cells

**Commitment (Chooses + Indeterminate)** - Action with pending outcome:
```yaml
- id: drink_potion
  text: "Drink the mysterious liquid"
  consequence:
    - type: set_flag
      flag: potion_consumed
      value: true
    - type: add_history
      entry: "Drank the potion. Effects unknown..."
  # Note: no immediate ending - outcome resolves later
  next_node: await_potion_effects
```

**Discovery (Unknown + Permits)** - Exploration rewarded:
```yaml
- id: examine_surroundings
  text: "Examine the chamber more closely"
  # No preconditions - exploration always permitted
  consequence:
    - type: modify_trait
      trait: wisdom
      delta: 1
    - type: set_flag
      flag: noticed_secret_passage
      value: true
  next_node: same_node  # Stay here with new knowledge
```

**Deferral (Avoids + Indeterminate)** - Building tension:
```yaml
- id: hide_and_wait
  text: "Find a hiding spot and wait it out"
  consequence:
    - type: set_flag
      flag: tension_building
      value: true
    - type: advance_time
      hours: 2
    - type: add_history
      entry: "Hid while danger passed... or did it?"
  next_node: aftermath_unknown  # Could go either way
```

## Quality Guidelines

### Narrative Voice

- Use second person present tense ("You stand at the crossroads")
- Be evocative but concise (3-6 sentences per narrative block)
- Show, don't tell emotional states
- Leave room for player interpretation

### Choice Design

- Each choice should feel meaningfully different
- Avoid obvious "correct" answers
- Blocked options should feel like real possibilities
- Include at least one "non-obvious" option

### Consequence Balance

- Not every choice needs combat
- Trait changes should be modest (+/-1 to 3)
- Item acquisition should be meaningful
- Flags should track narratively important events

### Precondition Fairness

- Players should be able to earn required items/traits
- High requirements should have alternative paths
- Blocked options should explain why clearly

## Additional Resources

### Reference Files
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/core.md`** - Option type semantics and Nine Cells
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/scenario-format.md`** - YAML specification

### Example Scenarios
- **`${CLAUDE_PLUGIN_ROOT}/scenarios/dragon_quest.yaml`** - Complete example
