# Export Framework

Rules for exporting gameplay sessions to readable documents.

## Overview

The export system transforms raw gameplay (including tool calls, YAML
queries, and technical artifacts) into clean, readable documents. Multiple
modes support different use cases from simple transcripts to deep analysis.

## Export Modes

### Transcript (Default)

**Command:** `/kleene export` or `/kleene export --mode=transcript`

Pure gameplay log — the raw experience cleaned of technical artifacts.

**Includes:**
- Exact narrative text as presented
- Player choices verbatim
- Consequence notifications (trait/relationship changes)
- Headers and footers

**Excludes:**
- Bash/yq tool calls and output
- Read/Grep/Glob operations
- YAML data blocks
- System messages
- Tool permission prompts

**Format:**
```markdown
# The Yabba - A Journey

## Turn 1: Bundanyabba Railway Station

The train shudders to a halt at Bundanyabba. You step onto the
platform into a wall of heat — forty bloody degrees, easy...

> **Choice:** Find a pub

---
**John Grant** | Dignity: 10 | Sobriety: 10 | Money: 8

## Turn 2: The Royal Hotel

The pub is cool and dark after the blinding street...
```

**Use case:** Archive the actual play experience, share the story.

---

### Summary

**Command:** `/kleene export --mode=summary`

Condensed analysis — what happened and why.

**Includes:**
- Turn-by-turn narrative with key beats
- Choices and consequences documented
- Gallery Notes (if gallery_mode was on)
- Comparative analysis across branches (if rewinds occurred)
- Technical observations
- Thematic synthesis

**Format:**
```markdown
# The Yabba - Session Analysis

## Overview
- Playtime: ~2 hours
- Turns: 45
- Ending: Catastrophic (dignity collapse)
- Branches explored: 3

## Timeline

### Branch 1: The Descent (Turns 1-28)

**Turn 1: Arrival**
Chose to go to pub immediately.
- Consequence: Sobriety -2, first encounter with Jock

> Gallery Note: The choice to drink immediately sets the tone —
> John is already seeking escape before understanding what he's
> escaping from.

**Turn 5: The Two-Up Game**
Chose to bet everything.
- Consequence: Money 8 → 0, Desperation activated

...
```

**Use case:** Understand what happened, learn from the session, share
insights about narrative design.

---

### Stats

**Command:** `/kleene export --mode=stats`

Just the numbers — quick reference for the journey.

**Includes:**
- Starting vs. final stats comparison
- Relationship evolution (start → peak → end)
- Trait trajectory graph (text-based)
- Major consequence events with turn numbers
- Ending achieved and type

**Format:**
```markdown
# The Yabba - Stats Summary

## Character: John Grant

### Trait Evolution
| Trait | Start | End | Delta | Peak/Low |
|-------|-------|-----|-------|----------|
| Dignity | 10 | 1 | -9 | Low: 1 (T28) |
| Sobriety | 10 | 5 | -5 | Low: 2 (T15) |
| Money | 8 | -5 | -13 | Low: -5 (T22) |
| Desperation | 0 | 10 | +10 | High: 10 (T25) |
| Self-knowledge | 2 | 20 | +18 | High: 20 (T28) |

### Relationships
| NPC | Start | End | Key Moment |
|-----|-------|-----|------------|
| Jock | 0 | +2 | T5: Gambling together |
| Janette | 0 | +45 | T18: Kitchen intimacy |
| Doc | 0 | +25 | T22: Psychological games |
| Tim | 0 | +15 | T12: Drinking buddies |

### Major Events
- T5.1.2: First gambling loss (Money: 8 → 3)
- T15.2.4: Blackout drunk (Sobriety: 2)
- T18.1.1: Relationship with Janette begins
- T22.3.2: Borrowed money from Doc
- T28.2.5: Missed the bus, Janette betrayal

### Session Overview
| Metric | Value |
|--------|-------|
| Total turns | 28 |
| Total scenes | 47 |
| Total beats | 156 |
| Estimated playtime | ~3 hours |

### Ending
**Type:** Catastrophic
**Final State:** Dignity 1, trapped in The Yabba
```

**Use case:** Quick reference, comparing playthroughs, tracking progress.

---

### Branches

**Command:** `/kleene export --mode=branches` or `--split-branches`

For sessions with rewinds — separate documentation per timeline.

**Output Structure:**
```
exports/
├── the_yabba_2026-01-16_index.md    # Branch overview
├── the_yabba_2026-01-16_branch1.md  # First timeline
├── the_yabba_2026-01-16_branch2.md  # After rewind to T15
└── the_yabba_2026-01-16_branch3.md  # After rewind to T5
```

**Index File Format:**
```markdown
# The Yabba - Branch Analysis

## Timeline Tree

```
T1 ─── T5 ─── T15 ─── T28 [Branch 1: Catastrophic]
        │      │
        │      └──── T18 ─── T25 [Branch 2: Escape attempt]
        │
        └──── T8 ─── T12 [Branch 3: Early resistance]
```

## Branch Comparison

| Branch | Divergence | Turns | Ending | Key Difference |
|--------|------------|-------|--------|----------------|
| 1 | — | 28 | Catastrophic | Full descent |
| 2 | T15 | 10 | Escape | Refused Doc's money |
| 3 | T5 | 7 | Victory | Never gambled |

## Divergence Analysis

### T5: The Gambling Choice
- Branch 1: Bet everything → spiral begins
- Branch 3: Walked away → maintained dignity
```

**Use case:** Exploring alternate paths, understanding decision impact.

---

### Gallery

**Command:** `/kleene export --mode=gallery`

Meta-commentary only — the analytical layer.

**Includes:**
- All Gallery Notes generated during play
- Psychological analysis
- Thematic observations
- Narrative structure commentary
- Framework/design observations

**Excludes:**
- Narrative text
- Player choices
- Stats/consequences

**Format:**
```markdown
# The Yabba - Gallery Notes

## Turn 5: The Two-Up Game

> The gambling scene is the trap's jaws closing. John doesn't need
> money — he has enough for the flight. He gambles because The Yabba
> has already begun its work: the heat, the mateship, the sense that
> rules from "outside" don't apply here.

## Turn 15: The Blackout

> Sobriety at 2 represents not just drunkenness but dissolution of
> self. John can no longer distinguish his choices from the town's
> expectations. The Yabba drinks through him.

## Turn 18: Janette

> The kitchen scene inverts power dynamics. Janette initiates,
> controls, consumes. John experiences intimacy as another form of
> being absorbed — not by alcohol or gambling, but by the town's
> appetite for him specifically.

## Thematic Analysis

### The Yabba as Organism
The town functions as a collective entity that digests outsiders...
```

**Use case:** Learning about narrative design, psychology, studying the
scenario's themes.

---

## Command Options

```bash
# Mode selection
/kleene export                       # transcript (default)
/kleene export --mode=transcript     # explicit transcript
/kleene export --mode=summary        # analysis with gallery notes
/kleene export --mode=stats          # numbers only
/kleene export --mode=branches       # split by timeline
/kleene export --mode=gallery        # commentary only

# Granularity (3-level counter)
/kleene export --granularity=turn    # One section per turn (default)
/kleene export --granularity=scene   # One section per scene
/kleene export --granularity=beat    # One section per beat (most detailed)

# Branch handling
/kleene export --split-branches      # separate file per branch
/kleene export --merged              # all branches in one file

# Format options
/kleene export --format=md           # markdown (default)
/kleene export --format=json         # structured data
/kleene export --format=html         # styled for web

# Output location
/kleene export                       # ./exports/[scenario]_[date].md
/kleene export --output=myfile.md    # specific filename
/kleene export --dir=./archives/     # specific directory
```

## Granularity Levels

The `--granularity` option controls how detailed the export structure is:

### Turn Granularity (default)
One section per major turn. Beats and scenes within a turn are combined.

```markdown
## Turn 6: Morning with Janette

[All scenes and beats combined in one section]
**Consequences:** Dignity +2, Self-knowledge +3, Janette +15
```

### Scene Granularity
One section per scene. Beats within a scene are combined.

```markdown
## Turn 6: Morning with Janette

### Scene 1: Morning Intimacy (Beats 1-3)
[Kitchen, cool room, intimacy combined]
**Consequences:** Janette +8

### Scene 2: Honest Conversations (Beats 4-6)
[Dish washing, Robyn discussion combined]
**Consequences:** Dignity +2, Self-knowledge +3
```

### Beat Granularity
One section per beat. Maximum detail.

```markdown
## Turn 6: Morning with Janette

### Scene 1: Morning Intimacy

**T6.1.1**: Kitchen Arrival
[Narrative]

**T6.1.2**: Cool Room Scene
[Narrative]
*Dignity -1, Janette +3*

**T6.1.3**: Intimacy
[Narrative]
*Janette +5*

### Scene 2: Honest Conversations

**T6.2.1**: Dish Washing
[Narrative]
*Self-knowledge +1*
```

The `T6.1.2` notation means Turn 6, Scene 1, Beat 2.

## Processing Rules

### What to Filter Out

When generating any export mode, remove:
- `Bash(...)` tool calls and their output
- `Read(...)`, `Grep(...)`, `Glob(...)` calls
- yq queries and YAML data blocks
- System reminder tags
- Tool permission prompts ("Allow Bash?")
- Internal state dumps
- Error messages and retries

### What to Preserve

Always keep:
- Cinematic headers (══════ blocks)
- Narrative text (the story)
- Player choices (mark with `>`)
- Status/footer lines
- Consequence notifications
- Gallery Notes (in modes that include them)

### Branch Detection

Identify branches by looking for:
- "rewind" or "go back" requests
- State restoration events
- Turn number decreases
- Explicit branch markers

### Gallery Note Identification

Gallery Notes are identified by:
- `[Temperature 10: ...]` headers
- `Gallery Note:` prefixes
- Analytical paragraphs about psychology/theme
- Meta-commentary about narrative structure

## Output Locations

**Default:** `./exports/[scenario]_[YYYY-MM-DD].md`

**With branches:** `./exports/[scenario]_[date]_branch[N].md`

**Directory structure:**
```
./exports/
├── the_yabba_2026-01-16.md
├── dragon_quest_2026-01-15.md
└── altered_state_2026-01-14/
    ├── index.md
    ├── branch1.md
    └── branch2.md
```
