# Kleene Example Walkthrough

See Kleene in action! This walkthrough shows the same scenario (Dragon Quest) played at different temperature settings to demonstrate how dramatically the experience changes.

---

## The Scenario: Dragon Quest

A classic fantasy adventure where you must decide how to face a dragon threatening your village.

**Estimated playtime:** 15-20 minutes
**Difficulty:** Beginner
**Perfect for:** First-time players

---

## Part 1: Traditional Branching (Temperature 0)

At temperature 0, Kleene plays like a traditional text adventure. You get the scenario exactly as written, with no AI adaptation.

### Starting the Game

```
$ /kleene play dragon_quest
/kleene temperature 0
```

### Turn 1: The Beginning

```
═══════════════════════════════════════════════════════════
            T H E   D R A G O N ' S   C H O I C E
═══════════════════════════════════════════════════════════
                         Village Square
                           Turn 1 | Time: 0
        Courage: █████░░░░░ 5 | Wisdom: █████░░░░░ 5
═══════════════════════════════════════════════════════════

A massive dragon has descended upon your village. Smoke rises
from the distant mountains where it lairs. The elders have gathered
in the town square, arguing about what to do.

Some say negotiate. Others say fight. A few whisper of an ancient
binding ritual that could end this peacefully.

You are the village's champion. The decision falls to you.

┌─────────────────────────────────────────────────────────┐
│ What do you do?                                         │
└─────────────────────────────────────────────────────────┘

○ Challenge the dragon to combat
○ Seek a diplomatic solution
○ Research ancient dragon lore
```

**[CHOICE: Research dragon lore]**

Temperature 0 response (verbatim):
```
═══════════════════════════════════════════════════════════
                  T H E   D R A G O N ' S   C H O I C E
═══════════════════════════════════════════════════════════
                           Village Library
                              Turn 1
                   Courage: █████░░░░░ 5 | Wisdom: ███████████ 7
═══════════════════════════════════════════════════════════

You spend days in the dusty library, poring over ancient texts.

The librarian, an old scholar named Elara, guides you to the
relevant tomes. Together you uncover the dragon's true name and
nature: it is not evil, merely trapped by an ancient curse.

Your wisdom grows from understanding, not assumption.
```

**Result:** +2 wisdom, learned the dragon's true nature

---

## The Temperature Difference

Now let's see the SAME scenario at **Temperature 10** (Adaptive):

### Playthrough at Temp 10

```
═══════════════════════════════════════════════════════════════
               T H E   D R A G O N ' S   C H O I C E
═══════════════════════════════════════════════════════════
                        Mountain Pass
                       Turn 1 | Time: 0
              Courage: █████░░░░░ 5 | Wisdom: █████░░░░░ 5
═══════════════════════════════════════════════════════════

You stand before the dragon's lair, a massive cave carved into
the mountainside. The villagers' pleas echo in your memory. The
beast has taken livestock, burned crops. Children no longer play
outside.

The dragon's breathing echoes from within - deep, rhythmic, eternal.

> What do you do?
  • Fight the dragon
  • Negotiate with the dragon
  • Sneak past the dragon
```

**Player chooses: "Other" and types:** *"I study the carvings around the entrance to learn about the dragon's history"*

```yaml
═══════════════════════════════════════════════════════════════════════
║  ANCIENT WISDOM                                           ║
╚═══════════════════════════════════════════════════════════╝

You examine the weathered carvings around the cave entrance. They tell
a story - this dragon isn't a mindless beast. It was placed here as a
guardian, bound by an ancient oath.

The carvings show offerings and respect, not combat. Perhaps there's
another way.

**Consequences:**
- Wisdom +2 (careful observation)
- Added insight: improv_knows_dragon_history

═══════════════════════════════════════════════════════════
```

Now you have context other players wouldn't - and at higher temperatures, the AI will remember and integrate this discovery.

**Notice:**
- The player got to be creative
- The game rewarded observation
- New knowledge was gained
- Options remain available (didn't advance the node)
- At temp 0, this wouldn't happen

---

## Comparison: Temperature 0 vs Temperature 10

Let's replay the same choice with different temperatures:

### At Temperature 0 (Verbatim)

```
═══════════════════════════════════════════════════════════
                    THE DRAGON'S CHOICE
═══════════════════════════════════════════════════════════
                      Mountain Cave Entrance
                          Turn 3 | Time: 15
             Courage: ███████░░░ 7 | Wisdom: █████░░░░░ 5
═══════════════════════════════════════════════════════════

A vast cavern opens before you. The dragon sleeps on a bed of gold.
Your village needs the dragon's hoard to survive the winter.

What do you do?

[Choices presented]
```

**Same scenario, Temperature 10:**
```
═══════════════════════════════════════════════════════════
              T H E   D R A G O N ' S   C H O I C E
═══════════════════════════════════════════════════════════

TURN 5 | The Lair

You've spent hours observing the dragon's breathing patterns,
the way its scales catch the torchlight, the ancient runes
carved into its treasure hoard.

All those hours you spent studying dragon lore in the village
library come flooding back. This is your moment.

What do you do?

→ Use your knowledge to negotiate
→ Attack while it's distracted
→ Leave with what you've learned

[Player chose to examine scales closely in previous turn,
 story adapted to weave that discovery into the narrative]
```

---

## Key Differences

### At Temperature 0
- **Predictable:** Same choices every time
- **Structured:** Clear paths and branches
- **Traditional:** Classic IF experience
- **Best for:** First-time players, learning the story

### At Temperature 10
- **Adaptive:** Narrative shapes itself around your actions
- **Emergent:** Bonus options appear based on exploration
- **Contextual:** Previous discoveries affect current choices
- **Unique:** No two playthroughs are the same

---

## Play This Yourself

Want to experience the difference? Try it now:

```bash
# First playthrough (traditional)
/kleene play dragon_quest
/kleene temperature 0

# Then replay (emergent)
/kleene play dragon_quest
/kleene temperature 10
```

**Pro tip:** Save your temp 0 playthrough, then load it and set temp to 10. Watch how the same scenario transforms!

---

## What This Means for Gameplay

### At Temperature 0
- You get the "canon" story
- Fixed branches, predictable outcomes
- Like reading a choose-your-own-adventure book
- Perfect for first playthrough

### At Temperature 10
- The AI weaves in your discoveries
- Free-text actions deeply impact story
- Bonus options appear based on exploration
- No two playthroughs are the same

### The Sweet Spot
Most players find temps 5-7 ideal for balance:
- Enough structure to follow the story
- Enough adaptation to feel personalized
- Rich integration of player actions

---

## Try It Yourself

**Step 1: Play at temp 0**
```bash
/kleene play dragon_quest
/kleene temperature 0
```
Play through once - make note of key moments.

**Step 2: Replay at temp 10**
```bash
/kleene temperature 10
```
Replay the same scenario - use free-text actions liberally.

**Step 3: Compare**
Notice how:
- The story adapts to your discoveries
- Bonus options appear based on your actions
- Narrative references your improvisation
- Outcomes diverge based on exploration

This is Kleene's magic. Same scenario file, infinite experiences.

---

**Want to see more examples?** Try [The Yabba](../scenarios/the_yabba.yaml) - it's designed for high-temperature play with psychological depth.
