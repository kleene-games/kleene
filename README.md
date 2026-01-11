# Kleene Plugin for Claude Code

A three-valued narrative engine for interactive fiction, using Option types and LLM-driven scenario generation.

Named for Stephen Cole Kleene, who formalized three-valued logic in 1938.

## Overview

Every narrative moment exists in one of three states:
- **Some(value)** - The protagonist exists and can act
- **None** - The protagonist has ceased (death, departure, transcendence)
- **Unknown** - The narrative hasn't resolved yet

## Quick Start

```bash
# Start a new game
/kleene play

# Play the bundled Dragon Quest scenario
/kleene play dragon_quest

# Generate a new scenario
/kleene generate a haunted mansion mystery

# Analyze scenario structure
/kleene analyze
```

## The Four Quadrants

Every choice exists at the intersection of two axes:

|                    | World Permits          | World Blocks           |
|--------------------|------------------------|------------------------|
| **Player Chooses** | Victory/Transformation | Blocked Path           |
| **Player Avoids**  | Escape/Unchanged       | Forced Consequence     |

A narratively complete scenario ensures all quadrants are reachable.

## Game Folder

Your current directory is the "game folder":

| File | Purpose |
|------|---------|
| `game_state.yaml` | Saved game state (auto-created) |
| `scenario.yaml` | Custom scenario (optional) |

## Skills

| Skill | Purpose |
|-------|---------|
| `kleene-play` | Play interactive narratives using AskUserQuestion |
| `kleene-generate` | Create new scenarios or expand existing ones |
| `kleene-analyze` | Check narrative completeness and structure |

## Scenario Format

Scenarios are defined in YAML. See `lib/framework/scenario-format.md` for the complete specification.

```yaml
name: "My Scenario"
description: "A brief description"

initial_character:
  name: "Hero"
  traits: { courage: 5, wisdom: 5 }
  inventory: []

nodes:
  start:
    narrative: |
      You stand at the beginning...
    choice:
      prompt: "What do you do?"
      options:
        - id: action
          text: "Take action"
          next_node: next_scene
```

## License

MIT
