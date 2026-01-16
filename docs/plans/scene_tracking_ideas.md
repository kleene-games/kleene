Current Problem

What I tracked:
- Turn++ only when next_node advanced
- Turn 6 contained: cool room, intimacy, dish washing, Robyn talk, public walk, Tim confrontation, packing scene

What actually happened:
- ~8-10 distinct narrative beats
- Multiple improvised scenes
- Several emotional/thematic shifts
- Many consequence applications

Result in export:
- "Turn 6 Extended: Scene 1, Scene 2, Scene 3..." (awkward)
- Turn count (11) doesn't reflect actual gameplay density (~25-30 beats)
- Consequence attribution unclear: "At Turn 6: +1, -1, +2" (which scene?)

---
Proposed Solution: Beat Tracking

Option 1: Sub-Turn Notation

Turn 6.0 - Kitchen arrival (node entry)
Turn 6.1 - Cool room scene (improvisation)
Turn 6.2 - Intimacy (improvisation)
Turn 6.3 - Dish washing (improvisation)
Turn 6.4 - Robyn conversation (improvisation)
Turn 6.5 - Public walk (player choice)
Turn 6.6 - Tim confrontation (improvisation)
Turn 7.0 - Next scripted node

Pros:
- Precise consequence attribution
- Clear progression within complex turns
- Export can show "Turn 6 had 6 beats"
- Maintains turn structure

Cons:
- More notation complexity
- Player sees "Turn 6.4" (may feel technical)

---
Option 2: Beat Counter (Internal)

turn: 6
beat: 4
display: "Turn 6 (Beat 4)" or just "Turn 6"

Track beats internally but show simplified to player:
- Status line: "Turn 6" (hide beat)
- Save file: stores both turn and beat
- Export: "Turn 6, Beat 4: Dish washing scene"

Pros:
- Clean player-facing display
- Detailed internal tracking
- Export gets full granularity

Cons:
- Player may not realize how much happened in one "turn"

---
Option 3: Scene Tracking

Turn 6, Scene A: Kitchen conversation
Turn 6, Scene B: Cool room
Turn 6, Scene C: Intimacy
Turn 6, Scene D: Dish washing
Turn 6, Scene E: Robyn discussion
Turn 7, Scene A: Main street

Pros:
- Cinematic language (scenes, not beats)
- Natural for narrative medium
- Export reads like screenplay

Cons:
- "Scene" implies more structure than improv has
- Harder to define scene boundaries algorithmically

---
When to Increment Beat/Sub-turn

Trigger A: After Improvised Action Resolution

1. Player provides free-text input
2. I classify intent, generate response
3. Apply soft consequences
4. Beat++
5. Re-present same choices (or move to next beat)

Trigger B: On Choice Presentation

1. Display narrative
2. Present AskUserQuestion
3. Beat++ (so each choice gets numbered)
4. Wait for response

Trigger C: Scene Boundary Detection (Manual)

1. I sense scene has concluded
2. Before transitioning to new narrative context
3. Beat++

Recommendation: Combination of A + C
- Improv resolution always increments
- Major scene shifts increment
- Re-presenting same choice doesn't increment

---
Implementation in Game State

Enhanced State Model

turn: 6
beat: 4
major_node: "morning_with_janette"
current_beat_type: "improvisation"  # or "scripted_choice", "transition"

# Beat history for this turn
turn_6_beats:
  - beat: 1, type: "arrival", node: "morning_with_janette"
  - beat: 2, type: "improv", action: "cool room scene", consequences: {dignity: -1}
  - beat: 3, type: "improv", action: "intimacy", consequences: {janette: +5}
  - beat: 4, type: "improv", action: "dish washing", consequences: {dignity: +1}

Status Line Options

Verbose:
══════════════════════════════════════════════════════════════════════
Tim's Kitchen | Turn 6.4
══════════════════════════════════════════════════════════════════════

Clean (my preference):
══════════════════════════════════════════════════════════════════════
Tim's Kitchen | Turn 6
══════════════════════════════════════════════════════════════════════
(Beat tracked internally, shown only in export)

Scene-based:
══════════════════════════════════════════════════════════════════════
Tim's Kitchen | Turn 6, Scene D
══════════════════════════════════════════════════════════════════════

---
Export Benefits

Transcript Mode with Beat Tracking

Current (coarse):
## Turn 6: Morning with Janette

[8000 words of narrative spanning multiple scenes]

**Consequences:** Dignity +1, -1, +2, Janette +5, +3, +8

With beats (granular):
## Turn 6: Morning with Janette

### Beat 6.1: Kitchen Conversation
[Narrative]
**Consequences:** Self-knowledge +1

### Beat 6.2: Cool Room Scene
[Narrative]
**Consequences:** Dignity -1, Janette +3

### Beat 6.3: Intimacy [time passes]
**Consequences:** Janette +5

### Beat 6.4: Dish Washing
[Narrative]
**Consequences:** Dignity +1, Self-knowledge +1

### Beat 6.5: Robyn Discussion
[Narrative]
**Consequences:** Dignity +2, Janette +5

Summary Mode with Beat Aggregation

## Turn 6: Extended Intimacy (5 beats)

**Beat Summary:**
- 6.1: Kitchen conversation (Self-knowledge +1)
- 6.2: Cool room scene (Dignity -1, Janette +3)
- 6.3: Intimacy [time passes] (Janette +5)
- 6.4: Dish washing (Dignity +1, Self-knowledge +1)
- 6.5: Robyn discussion (Dignity +2, Janette +5)

**Turn totals:** Dignity +2, Self-knowledge +2, Janette +13

Stats Mode with Beat Granularity

Turn 6 Trajectory:
  6.0: Dignity: 2, Janette: 66
  6.1: Dignity: 2, Janette: 66 (kitchen talk, +1 self-knowledge)
  6.2: Dignity: 1, Janette: 69 (cool room, -1 dignity, +3 janette)
  6.3: Dignity: 1, Janette: 74 (intimacy, +5 janette)
  6.4: Dignity: 2, Janette: 74 (dish washing, +1 dignity, +1 self-knowledge)
  6.5: Dignity: 4, Janette: 79 (robyn talk, +2 dignity, +5 janette)

---
Save File Enhancement

Current Save Format

turn: 6
current_node: morning_with_janette
character:
  traits: {...}

With Beat Tracking

turn: 6
beat: 4
current_node: morning_with_janette
current_beat_context: "dish washing scene - discussing honesty"

# Optional: beat history for replay
beat_log:
  - turn: 6, beat: 1, action: "kitchen conversation", consequences: {self_knowledge: +1}
  - turn: 6, beat: 2, action: "cool room innuendo", consequences: {dignity: -1, janette: +3}
  - turn: 6, beat: 3, action: "intimacy [time passes]", consequences: {janette: +5}
  - turn: 6, beat: 4, action: "dish washing", consequences: {dignity: +1, self_knowledge: +1}

character:
  traits: {...}

Benefits:
- Resume knows exactly where in extended turn you were
- Export can reconstruct full beat sequence
- Consequence attribution precise

---
Skill Modifications

kleene-play Skill Changes

Add to game state:
GAME_STATE:
  turn: number           # Major turn (node transitions)
  beat: number           # Sub-turn (scene/improv within turn)
  beat_type: string      # "arrival", "scripted_choice", "improv", "transition"

  # For export
  beat_history: [
    {turn: 6, beat: 1, type: "arrival", node: "morning_with_janette"},
    {turn: 6, beat: 2, type: "improv", action: "cool room", consequences: {...}},
    ...
  ]

Beat increment rules:
INCREMENT beat WHEN:
- Improvised action resolves (free-text response complete)
- Major scene transition detected
- Scripted choice with improvise_context triggers

DO NOT increment beat WHEN:
- Re-presenting same choices after improv (still same beat)
- Minor clarifications or meta-questions

INCREMENT turn (and reset beat to 0) WHEN:
- Advancing to new major node via next_node
- Moving to scripted ending

Status line display:
if major_transition or first_turn:
    # Cinematic header with turn only
    display(f"Turn {turn}")
else:
    # Normal header with turn only
    display(f"Location | Turn {turn}")

# Beat hidden from player, tracked internally
# Save file stores both: turn=6, beat=4

---
Export Command Enhancement

Transcript Mode

/kleene export --mode=transcript

# With granularity options:
/kleene export --mode=transcript --granularity=turn    # default, one section per major turn
/kleene export --mode=transcript --granularity=beat    # one section per beat
/kleene export --mode=transcript --granularity=scene   # group beats into scenes

Output examples:

Turn granularity (current):
## Turn 6: Morning with Janette
[All beats combined in one section]

Beat granularity (new):
## Turn 6: Morning with Janette

### Turn 6.1: Kitchen Conversation
[Beat 1 content]

### Turn 6.2: Cool Room Scene
[Beat 2 content]

Scene granularity (smart grouping):
## Turn 6: Morning with Janette

### Scene A: Private Intimacy (Beats 1-3)
[Kitchen, cool room, intimacy combined]

### Scene B: Honest Conversations (Beats 4-5)
[Dish washing, Robyn talk combined]

---
Practical Example: Kitchen Branch Turn 6

What Actually Happened (25 minutes of gameplay):

1. Kitchen conversation about thinking too much
2. Innuendo → return to bedroom [time passes]
3. Post-intimacy vulnerability
4. "Tell me about Sydney" → Glebe flat description
5. Truth about Robyn with Janette present
6. Decision to walk publicly
7. Main street walk hand-in-hand
8. Tim confrontation on street
9. Return to pack belongings
10. Tim drunk return, kitchen confrontation

Current Tracking:

Turn 6 (all of the above)
Turn 7 (next node)

With Beat Tracking:

Turn 6.0  - Node arrival (kitchen)
Turn 6.1  - Kitchen conversation (improv)
Turn 6.2  - Bedroom return (improv)
Turn 6.3  - Tell me about Sydney (improv)
Turn 6.4  - Robyn truth (improv)
Turn 6.5  - Walk publicly (scripted choice → triggers transition)
Turn 6.6  - Main street (improv/triggered scene)
Turn 6.7  - Tim street confrontation (improv)
Turn 6.8  - Pack belongings (improv)
Turn 6.9  - Tim kitchen confrontation (improv)
Turn 6.10 - Decision point (scripted choice → next_node)
Turn 7.0  - Hotel (new major node)

Export Would Show:

## Turn 6: Extended Intimacy and Confrontation (10 beats)

### Beat 6.1: Kitchen Philosophy
Janette: "You're different when you stop thinking."
**Consequences:** None (setup)

### Beat 6.2: Return to Bedroom
[Tasteful fade] *[Time passes]*
**Consequences:** Self-knowledge +1, Janette +5

### Beat 6.3: "Tell Me About Sydney"
John describes Glebe flat honestly - peeling paint, thin walls, but real.
**Consequences:** Dignity +1, Self-knowledge +1, Janette +5

### Beat 6.4: The Truth About Robyn
Discussed with Janette present. Full transparency.
**Consequences:** Dignity +2, Self-knowledge +2, Janette +5

... [continues for all 10 beats]

**Turn 6 Totals:** Dignity +4, Self-knowledge +6, Janette +25, Tim -25

---
Recommendation

Implement beat tracking with:
1. Internal counter (turn.beat format)
2. Player-facing display: Show only major turn (hide beat)
3. Save file: Store both turn and beat
4. Beat increment triggers:
  - After improvised action resolution
  - On major scene transitions
  - Reset to 0 when advancing major turn
5. Export granularity options:
  - --granularity=turn (default, groups beats)
  - --granularity=beat (shows every beat)
  - --granularity=scene (smart grouping of related beats)

Benefits:
- Precise consequence attribution
- Better session replay
- Clearer exports
- No player-facing complexity (hidden unless exporting)
- Enables future features (resume mid-turn, beat-level save states)

Minimal disruption:
- Player experience unchanged (still sees "Turn 6")
- Only export and save file formats enhanced
- Backwards compatible (old saves just have beat=0)
