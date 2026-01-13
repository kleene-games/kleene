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
