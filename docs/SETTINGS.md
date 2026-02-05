# Kleene Settings Reference

Complete guide to customizing your Kleene gameplay experience.

---

## Quick Reference

| Command | Range | Default | Effect |
|---------|-------|---------|--------|
| `/kleene temperature [0-10]` | 0-10 | 5 | Narrative adaptation level |
| `/kleene foresight [0-10]` | 0-10 | 5 | Hint specificity |
| `/kleene parser [on\|off]` | on/off | off | Parser-style play |
| `/kleene gallery [on\|off]` | on/off | off | Meta-commentary |

**Settings persist in your save file** and are restored when you continue a game.

---

## Temperature (Narrative Adaptation)

Controls how much the AI adapts narrative based on your exploration and improvisation.

| Level | Name | What Happens |
|-------|------|--------------|
| **0** | Verbatim | Scenario text exactly as written - traditional branching |
| **1-3** | Subtle | Faint echoes of your discoveries woven in |
| **4-6** | Balanced | Direct references to your exploration |
| **7-9** | Immersive | Rich integration + bonus options may appear |
| **10** | Adaptive | Narrative fully shaped by your actions |

### When to Use Each Level

- **Temperature 0**: First playthrough to learn a scenario's structure
- **Temperature 5**: Good balance of structure and adaptation (default)
- **Temperature 10**: Replay for emergent storytelling - every playthrough is unique

### Example

Same scenario, different temperatures:

**At temperature 0:**
> You enter the cave. Darkness surrounds you.

**At temperature 7** (after exploring the forest):
> You enter the cave. The familiar scent of pine from the forest clings to your cloak as darkness surrounds you.

### Command
```bash
/kleene temperature 7
```

---

## Foresight (Hint Specificity)

Controls how specific hints are when you ask for guidance (e.g., "where should I go?").

| Level | Style | Example Response |
|-------|-------|------------------|
| **0** | Blind | "You must discover that yourself." |
| **1-3** | Cryptic | "The path winds where shadows fear to tread..." |
| **4-6** | Suggestive | "Perhaps the eastern passage holds promise." |
| **7-9** | Helpful | "The key is in the library, on the third shelf." |
| **10** | Oracle | "Go east, take the key from shelf 3, return to the locked door, use key." |

### When to Use Each Level

- **Foresight 0**: You want to discover everything yourself
- **Foresight 5**: Occasional nudges without spoilers (default)
- **Foresight 10**: You're stuck and want explicit guidance

### Command
```bash
/kleene foresight 3
```

---

## Interaction Modes

Kleene offers two complementary interaction modes. Both use the same
underlying systems—the only difference is how options are presented.

| Mode | Setting | What You See |
|------|---------|--------------|
| **Choice** (default) | `parser_mode: false` | 2-4 scripted options with descriptions |
| **Parser** | `parser_mode: true` | No choices shown - type commands |

---

### Choice Mode (Default)

Menu-driven interface for accessible narrative gameplay.

#### Why Choose Choice Mode?

- **Accessibility**: Clear options reduce cognitive load
- **Guidance**: Always know valid actions exist
- **Discovery**: Options reveal narrative possibilities
- **Onboarding**: Perfect for new players

#### Example

```
What do you do?
1. Enter the cave
2. Search the bushes
3. Return to town
```

You can still type custom actions via "Other" at any time.

#### Command
```bash
/kleene choice on     # Enable choice mode
/kleene parser off    # Same effect
```

---

### Parser Mode

Type commands like classic text adventures (Zork, Colossal Cave).

#### Why Choose Parser Mode?

- **Immersion**: No visible choices breaks the "pick an option" pattern
- **Exploration**: Discover what's possible through experimentation
- **Authenticity**: Text adventure feel for those who prefer it
- **Challenge**: Requires active engagement to find valid actions

#### How It Works

When enabled:
- **No choice options appear** - you type what you want to do
- **Type "look"** to see your surroundings
- **Type "inventory"** to check what you're carrying
- **Type "help"** for context-sensitive suggestions
- Commands like "go north", "take lamp", "examine mailbox" all work

#### Example

```
What do you do?
> _
```
(You type: "enter the cave" or "go into cave" or "explore cave")

#### Best For

- Text adventure veterans who prefer typing
- Zork I: Mini for authentic retro experience
- Players who find choice menus limiting

#### Command
```bash
/kleene parser on     # Enable parser mode
/kleene choice off    # Same effect
```

---

## Gallery Mode (Meta-Commentary)

Adds literary commentary explaining narrative techniques as you play—like
the explanatory cards at art galleries.

| Mode | What You See |
|------|--------------|
| **OFF** (default) | Pure immersive narrative |
| **ON** | Commentary cards after key moments |

### Commentary Dimensions

Gallery mode can offer many types of commentary. Common examples include:

| Dimension | What It Illuminates |
|-----------|---------------------|
| **Recognition** | IF tropes and specific work references |
| **Literary Resonance** | Connections to novels, myths, films |
| **Genre Awareness** | Pattern identification (noir, heroic quest) |
| **Character Archetypes** | What archetype you're embodying |
| **Thematic Threads** | Patterns developing across the narrative |

### Example Commentary

> **Gallery Note:** Like Frodo at Mount Doom—when the choice finally comes,
> will matters more than strength.

> **Gallery Note:** Third time through the spiral. Each drink costs more
> than the last.

### Foresight Integration

Gallery mode works hand-in-hand with your foresight setting:

| Commentary Type | Foresight Gating |
|-----------------|------------------|
| **Backward-looking** | Always available—retrospective isn't spoilers |
| **Forward-looking** | Gated by foresight level (0 = none, 10 = full) |

At foresight 0, gallery commentary explains how you got here but won't hint
at what's ahead. At foresight 10, it might say: "Past the troll lies the
treasure. Think Bilbo, not Beowulf."

### Best For

- Writers studying narrative structure
- Educators teaching interactive fiction
- Curious players who want to understand the craft
- Understanding how your choices shape the story

### Command
```bash
/kleene gallery on
```

---

## Recommended Settings by Playstyle

### First-Time Player
```bash
/kleene temperature 0
/kleene foresight 5
```
Learn the scenario as written. Hints available if you get stuck.

### Text Adventure Veteran
```bash
/kleene parser on
/kleene temperature 3
/kleene foresight 3
```
Parser commands with subtle narrative adaptation and cryptic hints.

### Emergent Storyteller
```bash
/kleene temperature 10
/kleene foresight 0
```
Maximum improvisation, discover everything yourself.

### Narrative Student
```bash
/kleene temperature 5
/kleene gallery on
```
Balanced play with educational commentary on techniques.

### Zork Purist
```bash
/kleene parser on
/kleene temperature 0
/kleene foresight 0
```
Authentic 1980s text adventure experience. Perfect for `zork1-mini`.

---

## Settings Interactions

| Combination | Effect |
|-------------|--------|
| Temperature 10 + Parser ON | Maximum freedom - type anything, AI adapts fully |
| Temperature 0 + Parser ON | Traditional parser adventure - strict but authentic |
| Gallery ON + Temperature 10 | See how your improvisations affect narrative |
| Foresight 0 + Parser ON | Hardcore mode - no hints, no choices shown |

---

## Troubleshooting

**"Free-text actions aren't working"**
- Temperature must be > 0. Run `/kleene temperature 5` and try again.

**"I can't figure out what to do in parser mode"**
- Type "help" for context-sensitive suggestions
- Type "look" to see your surroundings
- Increase foresight: `/kleene foresight 7`

**"Gallery mode is too intrusive"**
- Gallery commentary only appears at key moments
- If it's too much, toggle off: `/kleene gallery off`

**"Settings didn't save"**
- Settings are saved when you run `/kleene save`
- Auto-saves also preserve settings
- When you `/kleene continue`, settings are restored

---

## See Also

- [Getting Started Guide](GETTING_STARTED.md) - Quick start tutorial
- [Scenario Authoring Guide](SCENARIO_AUTHORING.md) - Create your own adventures
- [Troubleshooting](TROUBLESHOOTING.md) - Fix common issues
