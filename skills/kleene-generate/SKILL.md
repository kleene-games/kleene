---
name: kleene-generate
description: This skill should be used when the user asks to "generate a scenario", "create a new quest", "make me a game about...", "expand the story", "generate a new path", or when the player ventures beyond known scenario boundaries during gameplay. Generates narratively complete scenarios using Option type semantics.
version: 0.1.0
---

# Kleene Generate Skill

Generate new scenarios or expand existing ones using LLM capabilities while maintaining Option type semantics and narrative completeness.

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

Add new branches to an existing scenario to improve quadrant coverage.

**Input**: Existing scenario, analysis showing missing quadrants
**Output**: New nodes that fill narrative gaps

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
      "question": "How complex should the narrative be?",
      "header": "Complexity",
      "multiSelect": false,
      "options": [
        {"label": "Simple (Recommended)", "description": "5-10 nodes, clear path to endings"},
        {"label": "Medium", "description": "15-20 nodes, multiple branching paths"},
        {"label": "Complex", "description": "25+ nodes, interconnected story threads"}
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

Create the core structure ensuring all quadrants:

```
START
  ├── Path A (action path)
  │   ├── A1: Player chooses, world permits → Victory
  │   └── A2: Player chooses, world blocks → Blocked/Death
  ├── Path B (knowledge path)
  │   ├── B1: Alternative victory → Transcendence
  │   └── B2: Partial success → Different outcome
  └── Path C (avoidance path)
      ├── C1: Player avoids, world permits → Escape/Unchanged
      └── C2: Player avoids, world blocks → Forced consequence
```

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

### Step 5: Ensure Quadrant Coverage

Verify the scenario has paths to:
- [ ] Player chooses + world permits (victory)
- [ ] Player chooses + world blocks (blocked path)
- [ ] Player avoids + world permits (escape)
- [ ] Player avoids + world blocks (forced consequence)
- [ ] NONE_DEATH (mortality)
- [ ] SOME_TRANSFORMED (growth)

### Step 6: Write YAML

Output complete scenario in proper format.

## Emergent Node Generation

When player attempts an unscripted action during play:

### Context Gathering

Collect from game state:
- Current location and description
- Character traits, inventory, flags
- World flags and time
- Recent history (last 3-5 entries)
- The attempted action

### Generation Constraints

The generated node must:

1. **Respect State**: Only reference items/flags that exist
2. **Be Reachable**: Player can actually get here from current state
3. **Have Consequences**: Meaningful state changes
4. **Connect Forward**: Lead to existing nodes or valid endings
5. **Maintain Tone**: Match the scenario's established voice

### Generation Template

```yaml
generated_node_id:
  narrative: |
    [Describe the situation based on player's action]
    [React to their choice with the world's response]
    [Set up the next decision point]
  choice:
    prompt: "[Contextual prompt]"
    options:
      - id: continue_path
        text: "[Option that advances the story]"
        consequence:
          - [Meaningful state change]
        narrative: "[Brief result]"
        next_node: [existing_node OR new_generated_node OR ending]

      - id: retreat_option
        text: "[Option to return to known territory]"
        narrative: "[Result of retreating]"
        next_node: [existing_node]
```

### Integration

After generating:
1. Add node to scenario's `nodes` section
2. Update any referring nodes if needed
3. Continue play from new node

## Branch Expansion

Given an analysis showing missing quadrants:

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
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/core.md`** - Option type semantics
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/scenario-format.md`** - YAML specification

### Example Scenarios
- **`${CLAUDE_PLUGIN_ROOT}/scenarios/dragon_quest.yaml`** - Complete example
