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
├── .claude-plugin/
│   └── plugin.json           # Plugin manifest
├── commands/
│   └── kleene.md             # Gateway command (routes to skills)
├── skills/
│   ├── kleene-play/          # Game loop (inline, no sub-agent)
│   ├── kleene-generate/      # Scenario generation
│   └── kleene-analyze/       # Structural analysis
├── lib/framework/
│   ├── core.md               # Option type semantics & quadrant theory
│   └── scenario-format.md    # YAML specification
├── scenarios/                # Bundled scenarios
│   └── dragon_quest.yaml     # Example scenario
├── hooks/                    # Auto-approve for seamless gameplay
└── _archive/                 # Archived components
    └── game-runner.md        # Legacy sub-agent (replaced by inline skill)
```

## Core Concepts

### The Four Quadrants

Every choice exists at the intersection of player agency and world response:

|                    | World Permits          | World Blocks           |
|--------------------|------------------------|------------------------|
| **Player Chooses** | Victory/Transformation | Blocked Path           |
| **Player Avoids**  | Escape/Unchanged       | Forced Consequence     |

A narratively complete scenario ensures all quadrants are reachable.

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

1. Create `scenarios/your_scenario.yaml` following the format in `lib/framework/scenario-format.md`
2. Validate with `/kleene analyze your_scenario`
3. Test with `/kleene play your_scenario`

### Modifying Skills

Skills in `skills/*/SKILL.md` define behavior through markdown prompts. Key patterns:
- Use `AskUserQuestion` for player choices (max 12 char headers, 1-5 word labels)
- Reference `${CLAUDE_PLUGIN_ROOT}` for plugin-relative paths
- Keep menus to 2-4 options

### Game Runner Agent

The `agents/game-runner.md` defines a haiku-model subagent that:
- Receives scenario path (first turn) or scenario name + state (subsequent turns)
- Evaluates preconditions and applies consequences
- Returns structured output with required markers

## Game Folder Convention

The current working directory is the "game folder". Saves are organized by scenario:

```
./saves/
├── dragon_quest/
│   ├── 2026-01-12_14-30-22.yaml
│   └── 2026-01-10_09-15-00.yaml
├── altered_state_nightclub/
│   └── 2026-01-11_22-45-33.yaml
└── corporate_banking/
    └── 2026-01-09_18-00-00.yaml
```

| Path | Purpose |
|------|---------|
| `./saves/[scenario]/` | Saves for specific scenario |
| `./saves/[scenario]/YYYY-MM-DD_HH-MM-SS.yaml` | Individual save file |

Each gameplay session creates a new timestamped save file at start.
