# Getting Started with Kleene

**Kleene is an adaptive AI text adventure engine for Claude Code.** Your choices matter, your improvisation shapes the story.

---

## Installation

First, install the plugin in Claude Code:

```bash
# Add the marketplace
/plugin marketplace add kleene-games/kleene

# Install the plugin
/plugin install kleene@kleene-games
```

**Verify installation:** Run `/kleene` - you should see the command menu.

---

## Play Your First Game (5 minutes)

1. **Run `/kleene play`**
2. **Choose "Dragon Quest"** (beginner-friendly)
3. **Start at temperature 0** (traditional branching)
4. **Make choices** using the presented options
5. **Once comfortable, try free-text actions** - type anything!

**Example free-text actions:**
- "I examine the dragon's scales closely"
- "I try to sneak past while it's distracted"
- "I offer it gold from my pouch"

The AI adapts the story to your creativity. ✨


---

## Four Scenarios Included

### Dragon Quest (Beginner) ⚔️
Classic fantasy adventure. Perfect for learning Kleene basics.
- **Playtime:** 15-20 minutes
- **Difficulty:** Beginner
- **Best for:** First-time players

### The Yabba (Advanced) 🌵
Psychological thriller inspired by *Wake in Fright* (1971). Dark themes, moral ambiguity.
- **Playtime:** 30-60 minutes
- **Difficulty:** Advanced
- **Content Warnings:** Psychological themes, substance use, moral ambiguity

### Altered State Nightclub (Experimental) 🎭
Surreal mystery in a nightclub that defies reality.
- **Playtime:** 20-40 minutes
- **Difficulty:** Intermediate
- **Best for:** Players who like weird, experimental narratives

### Corporate Banking (Intermediate) 💼
Navigate career challenges and ethical dilemmas in the corporate world.
- **Playtime:** 25-35 minutes
- **Difficulty:** Intermediate
- **Best for:** Decision-making practice, ethical dilemmas

---

## Create Your Own Adventure

### Option 1: Generate with AI

```bash
/kleene generate a haunted mansion mystery
```

The AI creates a complete scenario with:
- Branching paths
- Multiple endings
- Proper structure
- Character stats

### Option 2: Use Templates

1. Check out `scenarios/TEMPLATES/minimal.yaml`
2. Copy and modify
3. Test with `/kleene analyze your_scenario`

### Option 3: Write from Scratch

1. Study `scenarios/dragon_quest.yaml` for inspiration
2. Follow the [Scenario Authoring Guide](docs/SCENARIO_AUTHORING.md)
3. Use the [format specification](lib/framework/scenario-format.md) as reference

**Minimal working scenario:**

```yaml
name: "My Adventure"

initial_character:
  name: "Hero"
  traits: { courage: 5 }
  inventory: []

start_node: intro

nodes:
  intro:
    narrative: "Your adventure begins..."
    choice:
      prompt: "What do you do?"
      options:
        - id: go
          text: "Enter the cave"
          next_node: victory

endings:
  victory:
    narrative: "You did it!"
    type: victory
```

Save as `scenarios/my_adventure.yaml` and run `/kleene play my_adventure`

---

## Essential Commands

| Command | What It Does |
|---------|--------------|
| `/kleene play` | Start new game (shows scenario menu) |
| `/kleene play dragon_quest` | Play specific scenario |
| `/kleene continue [scenario]` | Resume from save |
| `/kleene temperature [0-10]` | Set adaptation level |
| `/kleene foresight [0-10]` | Set hint specificity (0=none, 10=full walkthrough) |
| `/kleene classic [on\|off]` | Toggle Zork-style text adventure mode |
| `/kleene save` | Save current game |
| `/kleene rewind [target]` | Go back to earlier point |
| `/kleene export [mode]` | Export gameplay to markdown |
| `/kleene gallery [on\|off]` | Toggle meta-commentary |
| `/kleene generate [theme]` | Create new scenario |
| `/kleene analyze [scenario]` | Check for issues |

---

## Tips for Great Gameplay

### For Your First Game
1. Choose Dragon Quest
2. Start at temp 0
3. Focus on learning the story
4. Don't worry about "optimal" choices - there's no wrong way to play

### To Experience Emergent Storytelling
1. Play any scenario at temp 0 first (learn the "canon")
2. Replay at temp 10
3. Use free-text actions liberally
4. See how the AI adapts the narrative

### For Creating Scenarios
1. Start with endings, work backward
2. Keep first version simple (5-10 nodes)
3. Run `/kleene analyze` frequently
4. Playtest at temps 0, 5, and 10

---

## Understanding Temperature (The Magic Sauce)

This is what makes Kleene unique - the same scenario plays completely differently based on temperature:

- **Temperature 0:** Traditional branching narrative (choose from presented options)
- **Temperature 5:** Story adapts to your exploration
- **Temperature 10:** Fully emergent storytelling - every playthrough is unique

**Try this experiment:** Play Dragon Quest at temp 0 (traditional). Then replay at temp 10 (emergent). Same scenario, completely different experience.

**Change temperature anytime:**
```bash
/kleene temperature 5
```

### When to Use Each Setting

| Temperature | Best For | What Happens |
|-------------|----------|--------------|
| **0** | First playthrough | Scenario plays as written - no adaptation |
| **3** | Subtle callbacks | Your discoveries get referenced occasionally |
| **5** | Balanced mix | Good blend of structure + adaptation |
| **7** | Rich immersion | Story deeply integrates your actions, bonus options appear |
| **10** | Wild experimentation | Fully emergent - anything can happen |

**Pro tip:** Start at 0 to learn a scenario, then crank it up to 10 for emergent magic.

---

## Understanding Free-Text Actions

When temperature > 0, you can type anything instead of picking from options. The AI will:

1. **Classify your intent** (Explore, Interact, Act, Meta)
2. **Check feasibility** against current state
3. **Generate narrative response** matching scenario tone
4. **Apply soft consequences** (small trait changes, history notes)
5. **Present original choices again** (you don't lose your turn)

**Examples:**

| You Type | AI Response |
|----------|-------------|
| "I search the room for traps" | Describes what you find, maybe +1 perception |
| "I try to bribe the guard" | Evaluates if you have money, generates outcome |
| "I want to befriend this character" | Generates interaction, adjusts relationship |
| "I examine the mysterious rune" | Provides lore, maybe +1 knowledge |

**The magic:** These actions get woven into the narrative at higher temperatures!

---

## Understanding Progress Tracking

Kleene tracks your position with three counters: **Turn · Scene · Beat**

| Counter | When It Increments |
|---------|-------------------|
| **Turn** | When you make a scripted choice (node transition) |
| **Scene** | Location change, time skip, or 5+ beats accumulate |
| **Beat** | Every improvised action or scripted choice |

**Example header:**
```
═══════════════════════════════════════════════════════════════════════
Turn 6 · Scene 2 · Beat 3                              The Dusty Saloon
═══════════════════════════════════════════════════════════════════════
```

**Compact notation:** T6.2.3 means Turn 6, Scene 2, Beat 3 - used in saves and rewind.

---

## Using Rewind

Made a choice you regret? Jump back in time:

```bash
/kleene rewind -1      # Go back 1 beat
/kleene rewind --1     # Go back 1 scene
/kleene rewind T6.2.3  # Jump to Turn 6, Scene 2, Beat 3
```

Rewind creates a branch - your original timeline is preserved in exports.

---

## Exporting Your Journey

Save your adventure as a clean markdown file:

```bash
/kleene export              # Clean narrative transcript
/kleene export summary      # Includes analysis and themes
```

Exports are saved to `./exports/` - perfect for sharing or reviewing.

---

## Troubleshooting

**"Free-text actions aren't working"**
- Temperature must be > 0
- Run `/kleene temperature 5` and try again

**"Scenario won't load"**
- Check YAML syntax
- Run `/kleene analyze` to find errors

**"Game feels repetitive"**
- Increase temperature: `/kleene temperature 7`
- Try more free-text actions

**"Too much improvisation, want traditional story"**
- Decrease temperature: `/kleene temperature 0`

More help: [Troubleshooting Guide](docs/TROUBLESHOOTING.md) | [FAQ](docs/FAQ.md)

---

## Next Steps

**Ready to explore?**
- 📖 [Full Documentation](README.md)
- ✍️ [Scenario Authoring Guide](docs/SCENARIO_AUTHORING.md)
- 🎮 [Play the bundled scenarios](scenarios/)
- 🤝 [Contribute](CONTRIBUTING.md)

**Have fun!** Remember: there's no wrong way to play. Experiment, improvise, and see where the story takes you. 🚀
