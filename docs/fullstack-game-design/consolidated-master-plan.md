# Plan: Convert Kleene Scenarios to Self-Describing Blueprint Workflows

## Context

Kleene's current architecture separates **data** (scenario YAML) from **interpreter** (prose SKILL.md). The blueprint framework offers an alternative: scenarios as **typed workflows** that implement game-domain node types defined by a gameplay engine wrapper. This conversion creates an alternative gameplay skill while the existing prose-based system remains untouched.

The key insight: instead of decomposing story nodes into primitive blueprint nodes (conditional + action + user_prompt), we define a **`game_node` extension type** — a higher-level node type that natively supports the full landscape of a story point (preconditions, blocked paths, narrative, choices with per-option preconditions/consequences, improvisation, routing). The scenario format barely changes.

## Architecture

```
gameplay.workflow.yaml (engine + type definitions)
  ├── defines: game_node type (execution semantics)
  ├── defines: kleene consequence types (move_to, schedule_event, etc.)
  ├── defines: kleene precondition types (has_item, trait_minimum, etc.)
  ├── contains: game loop, presentation, improvisation, save/load, end-game
  └── reference (inline) ──> scenario.workflow.yaml (story content)
                                ├── nodes of type: game_node
                                ├── story structure ≈ identical to current format
                                └── endings
```

The gameplay wrapper is the **interpreter** (defines types + engine). The scenario is the **program** (implements types). Both are valid blueprint workflows.

### Separation of Concerns

| Lives in gameplay wrapper | Lives in scenario workflow |
|---|---|
| `game_node` type definition + execution semantics | Story nodes (narrative + choices + consequences) |
| Consequence type definitions (move_to, schedule_event, etc.) | Endings |
| Precondition type definitions (has_item, trait_minimum, etc.) | Initial state (character, world, locations) |
| Game loop (turn → process node → present → apply → next) | Scenario-specific config (travel_config) |
| Presentation rules (70-char, headers, stats) | |
| Improvisation rules (intent classification, soft consequences) | |
| Save/load, end-game menu, counter tracking | |

### Why the scenario owns the full graph

The game is a finite state machine. The scenario contains the complete graph:
- **Time-based events**: `schedule_event` at node A may trigger `blocked_next_node` redirect at node F
- **Conditional fast-forwarding**: When `dragon_descends` fires, multiple nodes gate on `event_not_triggered`
- **No storyline leakage**: Full graph loaded once, not progressively disclosed

## What Changes / What Stays

| Component | Action |
|---|---|
| `skills/kleene-play/` | **Unchanged** |
| `skills/kleene-generate/` | **Unchanged** |
| `skills/kleene-analyze/` | **Unchanged** |
| `commands/kleene.md` | **Minor update** — routing for `/kleene blueprint-play` |
| `skills/kleene-blueprint-play/` | **New** — gameplay engine + type definitions |
| `lib/blueprint-extensions/types.yaml` | **New** — type definitions (referenced by wrapper) |
| `scenarios/dragon_quest.workflow.yaml` | **New** — dragon_quest in workflow format |

## Deliverables

### 1. The `game_node` Type Definition
**File:** `kleene/lib/blueprint-extensions/game_node.yaml`

A custom blueprint node type whose execution semantics describe how to process a self-contained kleene story node. This is the core innovation — it keeps scenario files compact by handling all the internal branching within a single node type.

**`game_node` fields** (identical to current scenario node format):

```yaml
game_node:
  description: A self-contained story point in a Kleene narrative
  fields:
    # Entry conditions
    precondition:       # Optional. Evaluated on entry.
    blocked_narrative:  # Shown when precondition fails
    blocked_next_node:  # Redirect on failure (else return to previous)
    on_enter:           # Consequences applied on entry (before narrative)
    scene_break:        # Force scene increment
    elapsed_since_previous:  # Time skip on entry

    # Content
    narrative:          # The story text (2nd person present tense)

    # Choices
    choice:
      prompt:           # Question text
      options:          # Array of options, each with:
        - id, text, cell, precondition, consequence, narrative, next_node
        - next: improvise  # OR scripted improvisation
          improvise_context: { theme, permits, blocks, limbo_fallback }
          outcome_nodes: { discovery, constraint, limbo }
```

**`game_node` execution semantics** (pseudocode in the type definition):

```
EXECUTE game_node(node, state):
  1. IF node.elapsed_since_previous:
       state.world.time += convert_to_seconds(elapsed_since_previous)
       process_scheduled_events(state)

  2. IF node.precondition:
       result = evaluate_precondition(node.precondition, state)
       IF fails AND node.blocked_next_node:
         display_blocked(node.blocked_narrative)
         RETURN next_node = node.blocked_next_node  (turn advances)
       IF fails AND no blocked_next_node:
         display_blocked(node.blocked_narrative)
         RETURN next_node = state.previous_node  (turn does NOT advance)

  3. IF node.on_enter:
       FOR consequence in node.on_enter:
         apply_consequence(consequence, state)
       process_scheduled_events(state)

  4. Display narrative:
     - Determine header type (cinematic vs normal)
     - Apply temperature adaptation (improv_* flags)
     - Format at 70-char width
     - Show character stats line
     - IF gallery_mode: append meta-commentary

  5. Evaluate choices:
     - Filter options by preconditions (silent removal)
     - IF temperature >= 4: enrich descriptions
     - IF temperature >= 7: maybe generate bonus option

  6. Present choices via AskUserQuestion
     (or parser mode: Look/Inventory/Help)

  7. Handle response:
     IF free-text (Other): → improvisation flow
     IF bonus option: → bonus flow (soft consequences, no advance)
     IF next: improvise: → scripted improvisation flow
     IF parser command: → look/inventory/help (no advance)
     IF scripted option: → apply consequences, advance

  8. IF scripted option:
     - Display option narrative (if present)
     - Apply option consequences
     - process_scheduled_events(state)
     - Advance: turn++, beat_log, checkpoint, previous_node = current
     RETURN next_node = option.next_node
```

This is essentially the game turn loop from the current SKILL.md, formalized as a node type definition. The gameplay wrapper reads this definition and uses it to process each `game_node` in the scenario.

### 2. Consequence & Precondition Type Definitions
**File:** `kleene/lib/blueprint-extensions/types.yaml`

**Consequence extensions (8)** — only operations needing semantic typing:
- `move_to` — location + travel time calc + instant flag
- `advance_time` — amount + unit → seconds
- `character_dies` — exists=false + reason in history
- `character_departs` — exists=false (transcendence)
- `move_npc` — NPC tracking with "current" resolution
- `schedule_event` — timed event with delay + nested consequences
- `trigger_event` — immediate execution + move to triggered list
- `cancel_event` — remove by ID

**Precondition extensions (6):**
- `location_state_check` — location flags/properties with lazy defaults
- `environment_check` — atmospheric conditions with "current" resolution
- `npc_location_check` — NPC at/not-at with "current" resolution
- `time_check` — elapsed time with unit conversion
- `event_check` — event triggered/not-triggered

**Mapped to existing blueprint-lib types (no extension):**
- `set_flag`/`clear_flag` → `set_flag`
- `gain_item` → `mutate_state(append)`
- `lose_item` → `mutate_state(remove)`
- `modify_trait`/`set_trait` → `mutate_state(add/set)`
- `modify_relationship` → `mutate_state(add)`
- `add_history` → `mutate_state(append)`
- Location state ops → `mutate_state` on nested paths
- `has_item`/`missing_item` → `evaluate_expression` with `contains()`
- `trait_minimum/maximum` → `evaluate_expression`
- `flag_set/not_set` → `state_check`
- `at_location` → `state_check`
- `all_of/any_of/none_of` → direct blueprint-lib equivalents

### 3. Scenario Workflow — dragon_quest.workflow.yaml
**File:** `kleene/scenarios/dragon_quest.workflow.yaml`

The scenario format **barely changes**. The only differences from current `dragon_quest.yaml`:
1. Workflow header (name, version, definitions source)
2. Each node gets `type: game_node`
3. Endings section gains workflow ending structure

**Example — blacksmith_shop stays self-contained:**

```yaml
# dragon_quest.workflow.yaml (excerpt)
name: "The Dragon's Choice"
version: "2.1.0"

definitions:
  source: "${GAMEPLAY_WRAPPER}/lib/blueprint-extensions"

travel_config: { ... }          # IDENTICAL to current
initial_character: { ... }      # IDENTICAL to current
initial_world: { ... }          # IDENTICAL to current

start_node: intro

nodes:
  blacksmith_shop:
    type: game_node             # ← only addition
    precondition:               # IDENTICAL to current
      type: event_not_triggered
      event_id: dragon_descends
    blocked_narrative: |
      The forge's glow is drowned by a fiercer light outside.
      Through the window, you see the dragon descending!
    blocked_next_node: dragon_attacks_village
    narrative: |
      The forge glows warm. Weapons line the walls...
    choice:
      prompt: "What do you take?"
      options:
        - id: take_rusty
          text: "Grab the rusty sword by the door"
          cell: chooses
          consequence:
            - type: gain_item
              item: rusty_sword
            - type: modify_trait
              trait: courage
              delta: 1
            - type: advance_time
              amount: 10
              unit: minutes
          narrative: "Quick and simple..."
          next_node: armed_and_ready
        - id: forge_blade
          text: "Work the forge yourself"
          cell: unknown
          precondition:
            type: trait_minimum
            trait: wisdom
            minimum: 7
          consequence:
            - type: gain_item
              item: forged_blade
          narrative: "Hours pass at the forge..."
          next_node: armed_and_ready

endings:
  ending_victory:
    type: victory
    narrative: |
      VICTORY...
```

**Node count:** Same as current — ~25 story nodes + 7 endings. NO node expansion.

**File size estimate:** ~85-95 KB (current is ~80 KB — overhead is just workflow header + `type: game_node` per node).

### 4. Gameplay Wrapper — kleene-blueprint-play
**File:** `kleene/skills/kleene-blueprint-play/workflow.yaml`

The engine workflow. Contains the game loop, type definitions, and cross-cutting concerns.

```
start → load_scenario → init_state → game_loop ←──────────────┐
                                        ↓                      │
                                  get_current_node              │
                                        ↓                      │
                                  execute_game_node             │
                                  (using game_node semantics)   │
                                        ↓                      │
                                  check_ending ─[yes]─> end_game_menu
                                        ↓ [no]                 │
                                  advance_state ────────────────┘
```

**Key nodes:**

| Node | Type | Purpose |
|---|---|---|
| `load_scenario` | action | Read scenario.workflow.yaml |
| `init_state` | action | Initialize game state from scenario |
| `game_loop` | action | Fetch current node from scenario graph |
| `execute_game_node` | action (prose) | Process node using `game_node` execution semantics |
| `check_ending` | conditional | Is current_node an ending? Is character.exists false? |
| `advance_state` | action | Turn++, beat_log, checkpoint, update scene |
| `end_game_menu` | user_prompt | Stats/analysis/replay/replay-from-moment |
| `save_game` | action | Write state to ./saves/ |

**The `execute_game_node` node is the heart** — it's a prose payload node that says:

```
Process the current game_node following the execution semantics
defined in ${CLAUDE_PLUGIN_ROOT}/lib/blueprint-extensions/game_node.yaml.

For presentation: ${CLAUDE_PLUGIN_ROOT}/lib/framework/gameplay/presentation.md
For improvisation: ${CLAUDE_PLUGIN_ROOT}/lib/framework/gameplay/improvisation.md
For scripted improv: ${CLAUDE_PLUGIN_ROOT}/lib/framework/gameplay/scripted-improvisation.md
For consequences: ${CLAUDE_PLUGIN_ROOT}/lib/framework/gameplay/evaluation-reference.md
```

This is the "Inception" quality we discussed — the workflow routes to a prose payload that contains the game engine instructions. The graph guarantees the right instructions are delivered at the right time.

### 5. Thin SKILL.md Wrapper
**File:** `kleene/skills/kleene-blueprint-play/SKILL.md`

Frontmatter + bootstrap instruction pointing to the workflow.

### 6. Gateway Update
**File:** `kleene/commands/kleene.md` (minor edit)

- `.workflow.yaml` scenarios → route to `kleene-blueprint-play`
- `.yaml` scenarios → route to `kleene-play` (existing)
- New subcommand: `/kleene blueprint-play [scenario]`

## Context Budget Comparison

| Layer | Prose (current) | Blueprint (new) |
|---|---|---|
| **Skill body** | 22 KB (SKILL.md) | ~2 KB (thin wrapper) |
| **Gameplay engine** | 0 (embedded in SKILL.md) | ~15-25 KB (wrapper workflow + type definitions) |
| **Scenario** | ~80 KB | ~85-95 KB (≈ same — just `type: game_node` added) |
| **Framework docs** | ~40-70 KB (on-demand) | ~40-70 KB (same refs from prose payloads) |
| **Typical session** | **~60-90 KB** | **~60-100 KB** |

Context budgets are nearly identical. The type definitions + wrapper (~15-25 KB) replace the prose SKILL.md (~22 KB). The scenario file barely grows.

## Implementation Sequence

1. **`game_node` type definition** (`game_node.yaml`) — the core extension
2. **Consequence/precondition types** (`types.yaml`) — game-domain operations
3. **Dragon quest conversion** (`dragon_quest.workflow.yaml`) — add `type: game_node` + workflow header
4. **Gameplay wrapper** (`kleene-blueprint-play/workflow.yaml`) — engine + game loop
5. **Thin wrapper** (`kleene-blueprint-play/SKILL.md`) — frontmatter + bootstrap
6. **Gateway update** (`kleene.md`) — routing for workflow scenarios

## Verification

1. `/kleene blueprint-play dragon_quest` — play full scenario
2. Compare with `/kleene play dragon_quest` — same narrative, choices, consequences
3. Test: new game, save, load, improvisation, parser mode, scripted improv, endings
4. Test: time pressure (let dragon_descends fire), blocked nodes, precondition filtering
5. Verify context consumption (~60-100 KB typical session)

## Critical Files

| File | Purpose |
|---|---|
| `kleene/skills/kleene-play/SKILL.md` | Reference: current game engine logic to formalize as `game_node` semantics |
| `kleene/scenarios/dragon_quest.yaml` | Reference: scenario to convert |
| `kleene/lib/framework/gameplay/evaluation-reference.md` | Reference: precondition/consequence evaluation tables |
| `kleene/lib/framework/gameplay/presentation.md` | Reference: display formatting rules |
| `kleene/lib/framework/gameplay/improvisation.md` | Reference: free-text handling rules |
| `/home/nathanielramm/git/hiivmind/hiivmind-blueprint-lib/nodes/workflow_nodes.yaml` | Reference: how blueprint node types are defined |
| `/home/nathanielramm/git/hiivmind/hiivmind-blueprint-lib/consequences/consequences.yaml` | Reference: consequence type definition format |
