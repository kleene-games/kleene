# Kleene - Adaptive AI Text Adventure Engine

**Text adventures that actually adapt to your choices.** Built specifically for Claude Code.

Unlike traditional choice-based games, Kleene responds to free-form actions and improvisation. The temperature system lets you control how much the AI adapts - from traditional branching (temp 0) to fully emergent storytelling (temp 10).

🎮 [**Get Started in 5 Minutes**](GETTING_STARTED.md) | 📖 [Documentation](docs/) | 🤝 [Contributing](CONTRIBUTING.md)


## Quick Start

```bash
# Play a game
/kleene play

# Try the beginner-friendly Dragon Quest
/kleene play dragon_quest

# Start at temperature 0 (traditional), increase once comfortable
/kleene temperature 0

# Generate your own scenario
/kleene generate a cyberpunk heist

# Check your scenario for issues
/kleene analyze
```

👉 **New to Kleene?** Check out the [Getting Started Guide](GETTING_STARTED.md)

---

## Installation

1. **Install the plugin** in Claude Code
2. **Verify installation:** Run `/kleene` to see the menu
3. **Play your first game:** `/kleene play` → choose Dragon Quest
4. **Have fun!** Start at temp 0, then experiment with higher temps

---

## Playing Games

### Basic Commands

| Command | What It Does |
|---------|--------------|
| `/kleene play` | Start a new game (shows scenario menu) |
| `/kleene continue [scenario]` | Resume from save |
| `/kleene temperature [0-10]` | Set adaptation level |
| `/kleene save` | Save current game |

### Temperature Guide

- **0 (Verbatim):** Scenario text exactly as written - traditional branching
- **1-3 (Subtle):** Faint echoes of your discoveries woven in
- **4-6 (Balanced):** Direct references to your exploration
- **7-9 (Immersive):** Rich integration + bonus options appear
- **10 (Adaptive):** Narrative fully shaped by your actions

**Pro tip:** Start every scenario at temp 0 to learn it, then replay at temp 10 for emergent magic.

### Free-Form Actions

When playing at temp > 0, you can type anything instead of picking from options:
- **Explore:** "I search the room for hidden doors"
- **Interact:** "I try to befriend the guard"
- **Act:** "I light the papers on fire"
- **Meta:** "I want to leave this location"

The AI evaluates feasibility and generates responses that fit the scenario tone.

---

## Features

### For Players
- **Improvisation Support**: Type any action—Claude interprets and responds dynamically
- **State Persistence**: Save/load game states, pick up where you left off
- **Auto-approval Hooks**: Seamless gameplay without permission prompts
- **Pure Claude Code Integration**: No separate app, plays in your terminal

### For Creators
- **AI-Powered Generation**: Create complete scenarios from a single theme prompt
- **YAML-based Format**: Human-readable, version-controllable scenario files
- **Structural Validation**: Analyze completeness across Bronze/Silver/Gold tiers
- **Nine Cells Framework**: Built-in guidance for rich, non-binary storytelling
- **Preconditions & Consequences**: Full game logic with inventory, traits, flags, relationships

## Create Your Own Scenarios

Kleene isn't just a game engine—it's a complete authoring toolkit:

1. **Generate**: Start with a theme (`/kleene generate "space station mystery"`)
2. **Edit**: Scenarios are YAML files you can hand-edit or ask Claude to refine
3. **Validate**: Check structural completeness (`/kleene analyze my_scenario`)
4. **Play**: Test your creation immediately (`/kleene play my_scenario`)
5. **Share**: Push to the community scenarios repo


---

## Creating Scenarios

### Option 1: Use the Generator

```bash
/kleene generate a space station mystery

# Or be more specific
/kleene generate a noir detective story set in 1940s Los Angeles
```

The AI creates a complete scenario with branching paths, endings, and proper structure.

### Option 2: Write Your Own

1. Check out `scenarios/dragon_quest.yaml` for inspiration
2. Use templates in `scenarios/TEMPLATES/`
3. Follow the [Scenario Authoring Guide](docs/SCENARIO_AUTHORING.md)
4. Validate with `/kleene analyze your_scenario`

**Minimal scenario example:**

```yaml
name: "My Adventure"
description: "A brief description"

initial_character:
  name: "Hero"
  traits: { courage: 5, wisdom: 5 }
  inventory: []

start_node: intro

nodes:
  intro:
    narrative: |
      You stand at the beginning of your adventure...
    choice:
      prompt: "What do you do?"
      options:
        - id: brave
          text: "Be brave and enter"
          next_node: victory
        - id: flee
          text: "Run away"
          next_node: escape

endings:
  victory:
    narrative: "You conquered your fear!"
    type: victory

  escape:
    narrative: "You lived to fight another day."
    type: unchanged
```

See the [complete format specification](lib/framework/scenario-format.md) for all features.

---

## Skills Reference

| Skill | Purpose |
|-------|---------|
| `kleene-play` | Interactive gameplay with inline state management |
| `kleene-generate` | Create scenarios from themes or expand existing ones |
| `kleene-analyze` | Check narrative completeness and structure |

---

## Game Saves

Saves are stored at: `./saves/[scenario_name]/[timestamp].yaml`

- **Auto-save:** Created when you start a game
- **Manual save:** `/kleene save` during gameplay
- **Resume:** `/kleene continue [scenario]` lists available saves
- **Location:** Current directory is the "game folder"

---

## Bundled Scenarios

### Dragon Quest (Beginner)
Classic fantasy adventure. Perfect for learning Kleene basics.
**Playtime:** 15-20 minutes | **Difficulty:** Beginner

### The Yabba (Advanced)
Psychological thriller inspired by *Wake in Fright* (1971). Dark themes, moral ambiguity.
**Playtime:** 30-60 minutes | **Difficulty:** Advanced | **Content Warnings:** Psychological themes, substance use

### Altered State Nightclub (Experimental)
Surreal mystery in a nightclub that defies reality.
**Playtime:** 20-40 minutes | **Difficulty:** Intermediate

### Corporate Banking (Intermediate)
Navigate career challenges and ethical dilemmas in the corporate world.
**Playtime:** 25-35 minutes | **Difficulty:** Intermediate


---

## Why Kleene?

### True Improvisation
**Type anything.** Don't just pick from options - describe what you want to do and the AI responds:
- "I examine the dragon's scales closely"
- "I try to sneak past while it's distracted"
- "I offer it gold from my pouch"

### The Temperature System (What Makes This Unique)
Same scenario, completely different experience:
- **Temperature 0:** Traditional branching narrative
- **Temperature 5:** Story adapts to your exploration
- **Temperature 10:** Fully emergent storytelling - every playthrough is unique

Try playing Dragon Quest at temp 0, then replay at temp 10. Mind = blown.

### Built for Claude Code
- Native integration with seamless UX
- Auto-saves during gameplay
- Smart lazy loading for massive scenarios
- No external dependencies

### Four Awesome Scenarios Included
- **Dragon Quest** (beginner) - Classic fantasy adventure
- **The Yabba** (advanced) - Psychological thriller with dark themes
- **Altered State Nightclub** (experimental) - Surreal mystery
- **Corporate Banking** (intermediate) - Career drama and tough choices

### Create Your Own Adventures
- Simple YAML format (no coding required)
- Built-in scenario generator: `/kleene generate haunted mansion`
- Validator ensures no dead ends: `/kleene analyze`
- Templates to get you started quickly

---

---

## Community

- **Contribute scenarios:** See [CONTRIBUTING.md](CONTRIBUTING.md)
- **Report bugs:** Open a GitHub issue
- **Share your creations:** Tag them with `#kleene`
- **Get help:** Check [FAQ](docs/FAQ.md) or [Troubleshooting](docs/TROUBLESHOOTING.md)

---

## Documentation

- **[Getting Started](GETTING_STARTED.md)** - 5-minute quick start
- **[Scenario Authoring Guide](docs/SCENARIO_AUTHORING.md)** - Create your own adventures
- **[Scenario Format Reference](lib/framework/scenario-format.md)** - Complete YAML specification
- **[Presentation Conventions](lib/framework/presentation.md)** - Headers, traits, choice formatting
- **[Improvisation Guide](lib/framework/improvisation.md)** - Free-text action handling
- **[FAQ](docs/FAQ.md)** - Common questions answered
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Fix common issues

---

## Advanced: Framework Theory

Kleene is built on solid theoretical foundations for those who want to dive deep.

### The Nine Cells Framework

Every choice exists at the intersection of player intent and world response:

|                    | World Permits | World Indeterminate | World Blocks |
|--------------------|---------------|---------------------|--------------|
| **Player Chooses** | Triumph       | Commitment          | Barrier      |
| **Player Unknown** | Discovery     | Limbo               | Revelation   |
| **Player Avoids**  | Escape        | Deferral            | Fate         |

**Player Unknown** captures both hesitation and improvised free-text actions.
**Limbo** (center cell) is where side quests and improvisation thrive.

A narratively complete scenario ensures coverage across the grid. See [Core Framework](lib/framework/core.md) for deep technical details.

---

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and updates.

---

**Made with ❤️ for Claude Code** | [Report Issues](https://github.com/hiivmind/kleene/issues) | [Contribute](CONTRIBUTING.md)
