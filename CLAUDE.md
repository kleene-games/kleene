# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Kleene is a Claude Code plugin implementing a three-valued narrative engine for interactive fiction. Named for Stephen Cole Kleene (who formalized three-valued logic in 1938), it uses Option types to model narrative states:
- **Some(value)** - Protagonist exists and can act
- **None** - Protagonist has ceased (death, departure, transcendence)
- **Unknown** - Narrative hasn't resolved yet

## Quick Start

```bash
/kleene play               # Start a game (shows scenario menu)
/kleene play dragon_quest  # Play specific scenario
/kleene generate [theme]   # Create new scenario from theme
/kleene analyze            # Check scenario completeness
```

## Plugin Architecture

```
kleene/
├── .claude/                          # Project settings
│   └── settings.json
├── .claude-plugin/
│   └── plugin.json                   # Plugin manifest (v0.2.0)
├── commands/
│   └── kleene.md                     # Gateway command (routes to skills)
├── skills/
│   ├── kleene-play/                  # Game loop (inline, no sub-agent)
│   ├── kleene-generate/              # Scenario generation
│   └── kleene-analyze/               # Structural analysis
├── lib/
│   ├── framework/
│   │   ├── core/                     # Core semantics
│   │   │   ├── core.md               # Option types & Decision Grid
│   │   │   └── endings.md            # Null case definitions
│   │   ├── formats/                  # File specifications
│   │   │   ├── scenario-format.md    # YAML scenario spec
│   │   │   ├── saves.md              # Save file format
│   │   │   └── registry-format.md    # Scenario registry spec
│   │   └── gameplay/                 # Runtime behavior
│   │       ├── presentation.md       # Display formatting
│   │       ├── improvisation.md      # Free-text handling
│   │       ├── gallery-mode.md       # Meta-commentary system
│   │       └── export.md             # Export modes
│   ├── guides/                       # Authoring guides
│   ├── patterns/                     # Reusable patterns
│   └── schema/                       # JSON schema for validation
├── scenarios/
│   ├── dragon_quest.yaml             # Example scenario
│   ├── registry.yaml                 # Scenario metadata
│   └── TEMPLATES/                    # Authoring templates
├── docs/                             # User documentation
├── scripts/                          # Validation scripts
├── hooks/                            # Auto-approve for seamless gameplay
└── _archive/                         # Archived components
    └── core_original.md              # Legacy core.md
```

## Core Concepts

### The Decision Grid

Every choice exists at the intersection of player intent (Chooses/Unknown/Avoids) and world response (Permits/Indeterminate/Blocks):

|                    | World Permits | World Indeterminate | World Blocks |
|--------------------|---------------|---------------------|--------------|
| **Player Chooses** | Triumph       | Commitment          | Rebuff       |
| **Player Unknown** | Discovery     | Limbo               | Constraint   |
| **Player Avoids**  | Escape        | Deferral            | Fate         |

**Player Unknown** captures both hesitation and improvised free-text actions.
**World Indeterminate** represents outcomes not yet resolved.
**Limbo** (center cell) is the chaos zone where side quests and improvisation thrive.

### Completeness Tiers

- **Bronze**: 4 corner cells (Triumph, Rebuff, Escape, Fate) - the original quadrants
- **Silver**: Bronze + 2 middle cells (adds uncertainty/exploration)
- **Gold**: All 9 intersections - full narrative possibility space

### Null Cases

- **NONE_DEATH** - Character destruction
- **NONE_REMOVED** - Transcendence/departure
- **NONE_BLOCKED** - Path impossible due to preconditions

### State Flow During Gameplay

During gameplay, state persists in the main conversation context (no sub-agent, no file writes):
1. Scenario loaded once at game start, cached in context
2. Game state tracked in conversation memory
3. Choices presented via AskUserQuestion
4. Consequences applied inline, state updated in memory
5. State saved to disk only on: game over, explicit save, or session end

This architecture eliminates serialization overhead between turns.

## Scenario Format (YAML)

Key elements in scenario files:

```yaml
name: "Title"
initial_character:
  traits: { courage: 5, wisdom: 5 }
  inventory: []
  flags: {}
initial_world:
  current_location: start
  flags: {}
start_node: intro
nodes:
  node_id:
    narrative: "Text shown to player"
    choice:
      prompt: "What do you do?"
      options:
        - id: option_id
          text: "Option text"
          precondition: { type: has_item, item: sword }
          consequence:
            - type: gain_item
              item: key
          next_node: next_node_id
endings:
  ending_id:
    narrative: "Ending text"
    type: victory | death | transcendence | unchanged
```

### Precondition Types
`has_item`, `missing_item`, `trait_minimum`, `trait_maximum`, `flag_set`, `flag_not_set`, `at_location`, `relationship_minimum`, `all_of`, `any_of`, `none_of`

### Consequence Types
`gain_item`, `lose_item`, `modify_trait`, `set_trait`, `set_flag`, `clear_flag`, `modify_relationship`, `move_to`, `advance_time`, `character_dies`, `character_departs`, `add_history`

## Working with This Plugin

### Adding New Scenarios

1. Start from a template in `scenarios/TEMPLATES/` (basic, intermediate, or advanced)
2. Create `scenarios/your_scenario.yaml` following `lib/framework/formats/scenario-format.md`
3. Add metadata entry to `scenarios/registry.yaml`
4. Validate with `/kleene analyze your_scenario`
5. Test with `/kleene play your_scenario`

### Modifying Skills

Skills in `skills/*/SKILL.md` define behavior through markdown prompts. Key patterns:
- Use `AskUserQuestion` for player choices (max 12 char headers, 1-5 word labels)
- Reference `${CLAUDE_PLUGIN_ROOT}` for plugin-relative paths
- Keep menus to 2-4 options

## Game Folder Convention

> **Reference:** See `lib/framework/formats/saves.md` for complete details.

The current working directory is the "game folder". Saves are stored at `./saves/[scenario]/[timestamp].yaml`. Each gameplay session creates a new timestamped save file at start.

## Scenario Validation

```bash
# Full schema validation (requires check-jsonschema)
pip install check-jsonschema
check-jsonschema --schemafile lib/schema/scenario-schema.json scenarios/my_scenario.yaml

# Or use the validation script (falls back to yq if check-jsonschema not installed)
./scripts/validate-scenario.sh scenarios/my_scenario.yaml

# Semantic analysis via skill
/kleene analyze my_scenario
```
