# Improvised Action Handling

Rules for responding to player free-text input beyond predefined choices.

> **Philosophy:** Improvisation enriches the current moment without derailing scenario balance. Major state changes (items, locations, death) are reserved for scripted paths.

## Grid Integration

Improvised actions map to the **Player Unknown** row of the Nine Cells:

| Feasibility | Grid Cell   | Response Pattern |
|-------------|-------------|------------------|
| Possible    | **Discovery**   | Reward curiosity, add insight |
| Blocked     | **Revelation**  | Explain constraint, teach player |
| Ambiguous   | **Limbo**       | Acknowledge without resolving |

### Discovery Responses
When improvisation succeeds (feasibility: possible), the world has *permitted* the unknown action. Generate enriching detail that rewards exploration. The character gains insight, flavor, or soft advantages.

### Revelation Responses
When improvisation is blocked, use the moment to *reveal* what's needed. Turn failure into information. The player learns why the path is blocked, which helps them find the correct approach.

### Limbo Responses
When player intent is unclear or action is ambiguous (neither clearly possible nor blocked), acknowledge the hesitation without forcing resolution. The narrative pauses at the threshold of possibility. This is the chaos center - perfect for side quests, ambient exploration, and building atmosphere.

## Detection

After receiving user selection, check if the response matches any predefined option label. If NOT:
- The user provided free-text via "Other"
- Execute the Improvisation Handler below
- Do NOT advance to a new node

## Intent Classification

Classify the player's free-text action:

| Intent | Keywords/Patterns | Example |
|--------|-------------------|---------|
| **Explore** | examine, look at, inspect, study, check | "I examine the dragon's scales" |
| **Interact** | talk to, ask, speak with, approach | "I try talking to the shadow in the corner" |
| **Act** | try to, attempt, I want to, I [verb] | "I try to climb the wall" |
| **Meta** | save, help, what are my stats, rules | "save my game" |

## Feasibility Check

Given current state, evaluate if the action is:

**Possible**: World permits this action
- No preconditions block it
- Makes sense in current location
- Character has capability (traits, items)

**Blocked**: World resists
- Missing required item or trait
- Wrong location
- Contradicts established world rules

**Impossible**: Breaks scenario logic
- Tries to interact with non-existent entities
- Attempts to skip major story beats
- Would trivialize core challenges

**Ambiguous**: Intent unclear or action open-ended (→ Limbo)
- Player hesitates or explores without clear goal
- Action could go multiple ways
- "Wait and see" behaviors

## Response Generation

Generate a narrative response based on intent and feasibility:

### Explore (Possible)
Provide atmospheric detail about what they examine. Add richness to the scene.
```
You study the dragon's scales more closely. In the flickering light,
you notice patterns etched into each plate - not natural markings,
but deliberate inscriptions. Writing, perhaps, in a language older
than human speech.

[+1 wisdom - Attention to detail]
```

### Interact (Possible)
Brief exchange or observation about the interaction attempt.
```
You call out to the shadow. It shifts, acknowledging you, but offers
no words. A cold presence brushes past your mind - not hostile,
but distinctly *other*. It seems to be waiting for something.

[+1 intuition]
```

### Act (Possible)
Describe the attempt and its outcome. May succeed partially or reveal new information.
```
You attempt to scale the cavern wall. The rock is slick with moisture,
but you find handholds. Halfway up, you spot something glinting in
a crevice - a coin, ancient and tarnished. You pocket it before
descending.

[Gained: tarnished_coin (flavor item)]
```

### Blocked Action
Explain why the action fails. The world resists, but provide narrative context.
```
You try to push past the stone door, but it won't budge. The runes
carved into its surface pulse faintly - whatever seal holds it closed
requires more than brute force. Perhaps there's another way...
```

### Impossible Action
Gently redirect without breaking immersion.
```
The dragon fills the entire passage ahead. There's no path around it,
no clever route to slip by unnoticed. Whatever happens next, it
happens here, face to face with the wyrm.
```

### Ambiguous Action (Limbo)
When intent is unclear, acknowledge without forcing resolution. The narrative holds its breath.
```
You stand at the threshold, neither advancing nor retreating. The air
itself seems to wait. The dragon's eyes follow you, patient as stone,
as if time has less meaning here than you'd imagined. What will you do?
```
No state changes. The player remains at the same decision point, but the atmosphere has shifted.

### Meta Request
Handle directly, breaking the fourth wall briefly.
```
Game saved to game_state.yaml.
---
[Continuing...]
```

## Soft Consequences

Improvised actions may apply ONLY these consequence types:

| Allowed | Not Allowed |
|---------|-------------|
| `modify_trait` (delta: -1 to +1) | `gain_item` (scenario items) |
| `add_history` | `lose_item` |
| `set_flag` (only `improv_*` prefix) | `move_to` |
| | `character_dies` |
| | `character_departs` |

**Why these limits?** Improvisation enriches the current moment without derailing scenario balance. Major state changes (items, locations, death) are reserved for scripted paths.

### Soft Flags Convention

Improvised actions can set flags prefixed with `improv_`:
```
improv_examined_dragon_scales
improv_spoke_to_shadow
improv_attempted_wall_climb
```

These flags:
- Track what the player has explored/attempted
- Enable richer responses to repeated improvisation
- Should NOT gate major scenario paths

## Consequence Magnitude Scaling

While improvised actions use soft consequences (±1), scripted choices
scale based on narrative weight:

| Action Type | Trait Delta | Relationship Delta |
|-------------|-------------|-------------------|
| Improvised exploration | ±1 | +1 to +3 |
| Minor scripted choice | ±2 | ±5 |
| Major scripted choice | ±3 to ±5 | ±15 to ±25 |
| Catastrophic betrayal | ±5 | -50 |

**Examples:**
- Examining something interesting: +1 wisdom
- Choosing to help someone: +2 trust, +5 relationship
- Major confrontation: -3 dignity, -25 relationship
- Betraying a lover: -5 dignity, -50 relationship

## Relationship Damage Tiers

| Offense Level | Delta | Example |
|---------------|-------|---------|
| Minor | ±5 | Mild disagreement, awkward moment |
| Moderate | ±15 | Challenging someone publicly |
| Major | ±25 | Full confrontation, harsh words |
| Catastrophic | ±50 | Betrayal, abandonment, broken promise |

**Positive relationships follow similar tiers:**
- Casual kindness: +5
- Genuine help: +15
- Major sacrifice: +25
- Life-changing bond: +50

## Dynamic NPC Introduction

Introduce NPCs at 0 relationship when they first become relevant.
Don't front-load all potential NPCs in initial state.

**Example:** Doc doesn't appear in relationships until he enters the
story, then starts at 0 and tracks from there. This keeps the status
line uncluttered and makes NPC appearances feel significant.

## Turn Increment Discipline

Turn++ ONLY when:
- Moving to a new node via `next_node`

Turn does NOT increment:
- During improvised loops or sub-conversations
- When re-presenting the same choice after free-text response
- When player selects "Other" and provides custom input

This prevents turn inflation and keeps pacing correct.

## Scene Length Calibration

**Extend improvised scenes when:**
- Temperature is high (7-10)
- Relationship is strong (40+)
- Player choice indicates depth ("just talk" vs "leave")
- No urgent plot pressure

**Short improv:** 1-2 paragraphs, return to scripted options

**Extended improv:** 3-5 paragraphs, multiple exchanges, then return
to scripted nodes at natural transition points

## Rewind (State Restoration)

When player requests "rewind to [point]":
1. Restore exact numeric values (all traits and relationships)
2. Restore narrative context (location, recent events)
3. Continue seamlessly without "loading..." meta-commentary
4. Present the choice menu from that point

Do NOT show restoration mechanics. The narrative simply returns to
that moment as if it always was.

## Tone Matching

Match the scenario's established voice:
- **Perspective**: Use second person present ("You examine...")
- **Vocabulary**: Match the scenario (archaic/modern/technical)
- **Imagery**: Match the scenario's descriptive density
- **Rhythm**: Match sentence length and pacing

Read the current node's narrative for guidance.

## Presentation

> **Reference:** See `lib/framework/presentation.md` for complete formatting rules.

Display improvised action responses with the same bold box format as regular nodes. Generate a creative title based on the player's action:

```
═══════════════════════════════════════════════════════════
**[CREATIVE TITLE]**
Turn [N] | Location: [location]
═══════════════════════════════════════════════════════════

[Narrative response to player's improvised action]

───────────────────────────────────────────────────────────
[trait changes, e.g., +1 wisdom - Attention to detail]
───────────────────────────────────────────────────────────
```

### Title Generation

| Player Action | Bad Title | Good Title |
|--------------|-----------|------------|
| "Pick up baggie and snort it" | Improvised Action | The Quick Fix |
| "I examine the bartender's tattoos" | Improvised Action | Ink and Suspicion |
| "Try talking to the woman with cold skin" | Improvised Action | Cold Conversation |
| "I climb the wall to look for an exit" | Improvised Action | The Desperate Ascent |

The title should:
- Be evocative/atmospheric (2-5 words)
- Reflect what the player is actually doing
- Match the scenario's tone
- NOT be generic ("Improvised Action", "Custom Choice", etc.)

## After Improvisation

After generating the response:
1. Apply any soft consequences
2. Display the response using the bold box format
3. Present the current node's original options AGAIN
4. Do NOT advance `current_node` or increment `turn`

The game stays at the same decision point, enriched by the player's exploration.

## Edge Cases

**Player tries to defeat boss via free-text:**
```
The dragon is vast - scales like ancient iron. A wild attack without
preparation would be suicide. The wyrm's eyes track you, waiting to
see what you'll actually do.
```
Then: Show original options.

**Player tries to leave scenario bounds:**
```
You consider turning back, but the path behind has collapsed.
Rocks and debris block any retreat. The only way is forward.
```

**Player repeats same improvisation:**
Check `improv_*` flags. If already set:
```
You've already examined the scales closely. The inscriptions remain
as mysterious as before. Perhaps action, not study, is needed now.
```

**Player action matches a blocked option:**
If free-text describes an action that has a precondition they don't meet, explain WHY it's blocked:
```
You reach for where your sword should hang, but your hand finds only
air. Without a weapon, challenging the dragon directly would be folly.
```

## Improvisation Temperature

The temperature setting (0-10) controls how much improvised context influences the presentation of scripted narratives. Higher temperatures create a more responsive, personalized experience.

### Scale Definition

| Temp | Style | Description |
|------|-------|-------------|
| 0 | Verbatim | Scenario text displayed exactly as written |
| 1-3 | Subtle | Faint echoes of improvised discoveries |
| 4-6 | Balanced | Direct references woven into narrative |
| 7-9 | Immersive | Rich integration of all improv context |
| 10 | Fully Adaptive | Narrative perspective shaped by exploration |

**Default:** 5 (Balanced)

> **Gallery Mode:** For educational/analytical play, enable `gallery_mode`
> in settings. This adds meta-commentary explaining psychological dynamics,
> narrative structure, and why consequences trigger — like art gallery
> analysis cards. See `lib/framework/presentation.md` → "Gallery Mode".

### Core Principle

Temperature affects *presentation*, not *structure*. The scenario YAML is authoritative for:
- Node transitions
- Consequences
- Preconditions
- Ending narratives

Temperature-based adaptation only enriches mood, context, and perspective.

### Eligible Flags for Callback

Only `improv_*` flags are eligible for temperature-based adaptation:

| Flag Pattern | Callback Context |
|--------------|------------------|
| `improv_examined_*` | "You recall examining..." |
| `improv_spoke_to_*` | "Having spoken with [entity]..." |
| `improv_attempted_*` | "Your earlier attempt at..." |
| `improv_discovered_*` | "The knowledge you gained..." |

Regular `character.flags` set by scripted consequences are NOT used for temperature adaptation — they gate preconditions only.

## Narrative Adaptation

Before displaying a node's narrative, check temperature and relevant `improv_*` flags.

### Temperature 0 (Verbatim)

Display narrative exactly as written. No adaptation.

```
# Node narrative (unchanged)
The dragon's eyes fix upon you. Ancient and knowing, they hold
the weight of centuries. What will you do?
```

### Temperature 1-3 (Subtle)

Add faint atmospheric hints without explicit reference.

```
Something about the dragon's scales feels familiar, though you
can't quite place why.

The dragon's eyes fix upon you. Ancient and knowing, they hold
the weight of centuries. What will you do?
```

### Temperature 4-6 (Balanced)

Direct reference to improvised discoveries, woven naturally.

```
The inscriptions you noticed earlier on the dragon's scales
seem to pulse faintly in the torchlight.

The dragon's eyes fix upon you. Ancient and knowing, they hold
the weight of centuries. What will you do?
```

### Temperature 7-9 (Immersive)

Rich integration connecting multiple improvised elements.

```
Having studied the dragon's scales and spoken with the elder,
you recognize patterns now — the inscriptions are words of
greeting, not warning. The dragon has been waiting, perhaps
for someone who would look closely enough to see.

The dragon's eyes fix upon you. Ancient and knowing, they hold
the weight of centuries. What will you do?
```

### Temperature 10 (Fully Adaptive)

The narrative perspective shifts to reflect the character's complete journey.

```
Everything you've learned comes together in this moment —
the inscriptions on the scales, the elder's words about
the dragon's grief, the symbols etched into the cavern walls.
You see now what others never paused to notice. The dragon
isn't a monster. It's a mourner.

The dragon's eyes fix upon you. Ancient and knowing, they hold
the weight of centuries. What will you do?
```

### Adaptation Guidelines

1. **Prepend, don't replace** — The original narrative appears after adaptation
2. **Match tone** — Adaptation inherits the scenario's voice and vocabulary
3. **Length scales with temperature** — 1 sentence at temp 3, up to 3-4 at temp 10
4. **Relevance filter** — Only reference flags that relate to the current scene
5. **Never spoil** — Don't reveal scripted outcomes or future consequences

## Option Adaptation

At temperature 4+, option *descriptions* (not labels) can be enriched with improv context.

### Temperature 0-3

Options displayed exactly as written.

```
1. Attack with your sword
   └── Challenge the dragon in combat

2. Speak to the dragon
   └── Attempt to communicate
```

### Temperature 4-6

Descriptions enriched with relevant discoveries.

```
1. Attack with your sword
   └── Challenge the dragon in combat (you recall its scarred left side)

2. Speak to the dragon
   └── Attempt to communicate (remembering the greeting symbols you studied)
```

### Temperature 7+

Descriptions may suggest tactical implications.

```
1. Attack with your sword
   └── Target the weakness you discovered in its scales

2. Speak to the dragon
   └── Use the greeting words inscribed on its scales
```

### Rules

- **Labels stay fixed** — Precondition matching depends on exact option IDs
- **Descriptions only** — The `description` field shown in AskUserQuestion
- **Parenthetical preferred** — At temp 4-6, use "(you recall...)" format
- **Integrated at temp 7+** — Rewrite description to incorporate discovery naturally

## Bonus Options

At temperature 7+, generate up to 1 bonus option per choice based on `improv_*` flags.

### Generation Criteria

A bonus option can be generated when:
1. Temperature >= 7
2. At least one `improv_*` flag suggests a meaningful action
3. The action is feasible in current context
4. Adding it won't exceed 4-option limit (including bonus)

### Bonus Option Structure

```yaml
label: "[Short imperative - 2-4 words]"
description: "[Brief context referencing the discovery]"
source_flag: "[The improv_* flag that triggered this]"
```

### Examples

**Flag:** `improv_discovered_dragon_weakness`
```
label: "Strike the weak point"
description: "Target the vulnerability you discovered earlier"
```

**Flag:** `improv_examined_dragon_scales`
```
label: "Trace the inscriptions"
description: "Follow the symbols you noticed on its scales"
```

**Flag:** `improv_spoke_to_shadow`
```
label: "Call to the shadow"
description: "Summon the presence you communed with"
```

### Behavior When Selected

Bonus options behave like emergent improvisation (free-text "Other"):

1. Generate narrative response matching scenario tone
2. Apply soft consequences only (trait ±1, `add_history`, new `improv_*` flags)
3. Display response with the bold box format
4. Present same choices again — bonus option remains available
5. Do NOT advance node or increment turn

### Edge Cases

**Multiple relevant flags:**
Choose the most relevant to current scene. Only 1 bonus option per choice.

**Flag already used for bonus:**
Track which flags have generated bonus options this turn. Avoid repeating.

**Bonus option selected twice:**
Handle like repeated improvisation — acknowledge without granting duplicate rewards.
```
You've already traced the inscriptions carefully. The pattern
is committed to memory now.
```
