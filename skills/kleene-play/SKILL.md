---
name: kleene-play
description: This skill should be used when the user asks to "play a game", "start kleene", "play dragon quest", "continue my game", "load my save", or wants to play an interactive narrative using the Kleene three-valued logic engine. Handles game state, choices, and narrative presentation.
version: 0.4.0
allowed-tools: Read, Glob, Grep, Write, Edit, AskUserQuestion, Bash
hooks:
  PreToolUse:
    - matcher: "Write|Edit"
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/auto-approve-saves.sh"
    - matcher: "Bash"
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/auto-approve-saves.sh"
---

# Kleene Play Skill

Execute interactive narrative gameplay directly in the main conversation context. State persists naturally - no serialization needed between turns.

## Architecture

This skill runs game logic **inline** (no sub-agent). Benefits:
- State persists in conversation context across turns
- Scenario loaded once, stays cached
- Zero serialization overhead
- Faster turn response (~60-70% improvement)

## Scenario Loading

> **Tool Detection:** See `lib/patterns/tool-detection.md` for yq availability check.
> **Templates:** See `lib/patterns/yaml-extraction.md` for all extraction patterns.

Scenarios may be loaded in two modes depending on file size.

### Standard Load (small scenarios)

For scenarios under ~20k tokens, read the entire file once and cache in context.

### Lazy Load (large scenarios)

When the Read tool returns a token limit error, switch to lazy loading.

> **Token Efficiency:** Using `yq` for YAML extraction is **dramatically more efficient** than Read/Grep:
> - Header extraction: **~75% fewer tokens** (extracts only needed fields)
> - Node loading: **~67% fewer tokens** (single node vs grep context)
> - Entire large scenario playthrough: **~50% total token savings**
>
> Always prefer yq when available. The savings compound across every turn.

**Step 1: Detect yaml_tool capability**

At session start, check for yq:
```bash
command -v yq >/dev/null 2>&1 && yq --version 2>&1 | head -1
```

If output contains "mikefarah/yq" and version >= 4: `yaml_tool: yq`
Otherwise: `yaml_tool: grep`

**Step 2: Load header**

**If yaml_tool=yq (~75% token savings):**
```bash
yq '{"name": .name, "start_node": .start_node, "initial_character": .initial_character, "initial_world": .initial_world, "ending_ids": [.endings | keys | .[]]}' scenario.yaml
```

**If yaml_tool=grep (fallback):**
```
Read scenario file with limit: 200
```

Extract and cache:
- `name` - scenario identifier
- `initial_character` - starting character state
- `initial_world` - starting world state
- `start_node` - first node ID
- `ending_ids` - list of ending identifiers

**Step 3: Load nodes on demand**

**If yaml_tool=yq (~67% token savings):**
```bash
yq '.nodes.NODE_ID' scenario.yaml
```

For structured turn context:
```bash
yq '.nodes.NODE_ID as $n | {"narrative": $n.narrative, "prompt": $n.choice.prompt, "options": [$n.choice.options[] | {"id": .id, "text": .text, "cell": .cell, "precondition": .precondition, "next_node": .next_node, "has_improvise": (.next == "improvise"), "outcome_nodes": .outcome_nodes}]}' scenario.yaml
```

**If yaml_tool=grep (fallback):**
```
Pattern: "^  {node_id}:"
Context: -A 80
Path: scenario file
```

Parse YAML from grep output to extract narrative, choice prompt, and options.

**Step 4: Improvise Prefetch (yq only)**

When an option has `next: improvise`, prefetch outcome nodes in a single query:
```bash
yq '.nodes as $all | .nodes.NODE_ID.choice.options[] | select(.next == "improvise") | .outcome_nodes | to_entries | .[] | {"cell": .key, "node": $all[.value]}' scenario.yaml
```

This fetches both discovery and revelation nodes in one query, avoiding multiple round-trips.


**Step 5: Adaptive Node Discovery (for improvised choices)**

When narrative choices lead to unexpected paths or you need to find
appropriate continuation nodes:

**If yaml_tool=yq (preferred):**
```bash
# Find nodes by keyword/theme
yq '.nodes | keys | .[]' scenario.yaml | grep -i 'keyword1\|keyword2\|theme'

# Example: Finding morning-after scenes
yq '.nodes | keys | .[]' scenario.yaml | grep -i 'morning\|wake\|dawn'
```

**If yaml_tool=grep (fallback):**
```bash
grep -i 'keyword' scenario.yaml | grep -E '^\s{2}\w+:'
```

**When to use:**
- Player makes improvised choice that doesn't map to scripted next_node
- Multiple potential continuation paths exist
- Need to find thematically appropriate transition nodes
- Lazy loading mode requires discovering relevant story branches

**Result:** Seamless narrative flow that feels responsive rather than
searching/loading. Do the keyword search, load the best-matching node,
present or adapt it naturally as if you knew it was there all along.


**Step 6: Cache strategy**
- Header data: persistent (kept in context)
- Current node: replaced each turn (don't accumulate old nodes)
- Endings: persistent (needed for ending detection)
- yaml_tool: persistent (detected once at session start)



### Detecting Load Mode

The gateway command attempts full read first. If it fails:
1. Sets `lazy_loading: true` in game context
2. Detects `yaml_tool: yq|grep` for extraction method
3. Loads header via yq or partial read
4. Passes scenario path for per-turn node loading

When `lazy_loading: true`, Phase 2 uses the appropriate tool to load each node.

### Error Handling

If yq fails during extraction, silently fall back to grep. Never interrupt gameplay to report tool failures.

## Time Unit Constants

> **Reference:** See `lib/framework/scenario-format.md` → "Time Units" for conversion table.

All temporal values in `world.time` are stored in seconds.

## Game State Model

Track these values in your working memory across turns:

```
GAME_STATE:
  scenario_name: string       # e.g., "dragon_quest"
  current_node: string        # Current node ID
  previous_node: string       # Previous node ID (for blocked restoration)

  # 3-Level Counter (see lib/framework/presentation.md)
  turn: number                # Major node transitions
  scene: number               # Groupings within turn (resets on turn++)
  beat: number                # Individual moments (resets on scene++)
  scene_title: string         # Auto-generated or from scenario
  scene_location: string      # Location when scene started

  # Beat log for export reconstruction
  beat_log: [                 # Cleared on session end or export
    {turn, scene, beat, type, action, consequences}
  ]

  character:
    exists: boolean           # false = None (character ceased)
    traits: {name: value}     # courage, wisdom, luck, etc.
    inventory: [items]        # Items held
    flags: {flag: boolean}    # Character-specific flags

  world:
    current_location: string  # Location ID
    time: number              # Time in seconds since game start
    flags: {flag: boolean}    # World state flags
    location_state:           # Per-location mutable state
      [location_id]:
        flags: {flag: boolean}
        properties: {name: number}
        environment: {lighting: "dim", temperature: 20}  # Environmental conditions

    # NEW in Phase 4 (v5)
    npc_locations:            # NPC position tracking
      [npc_id]: location_id   # Maps NPC to their current location

    scheduled_events:         # Pending events
      - event_id: string
        trigger_at: number    # Time (seconds) when event fires
        consequences: [...]   # Consequences to apply

    triggered_events: [string]  # IDs of events that have fired

  settings:
    improvisation_temperature: number  # 0-10, controls narrative adaptation
                                       # 0 = verbatim, 5 = balanced, 10 = fully adaptive
    gallery_mode: boolean              # Enable meta-commentary
    foresight: number                  # 0-10, controls hint specificity
    classic_mode: boolean              # Hide scripted options (parser mode)

  recent_history: [string]    # Last 3-5 turns for context
```

### Counter Increment Rules

| Counter | Increments When | Resets |
|---------|-----------------|--------|
| Turn | Advancing to new node via `next_node` | scene→1, beat→1 |
| Scene | Location change, time skip, 5+ beats, explicit marker | beat→1 |
| Beat | Improvised action resolves, scripted choice selected | — |

### Scene Detection Triggers

Scene++ occurs automatically when:
1. `world.current_location` differs from `scene_location`
2. Narrative contains time-skip patterns: `[Time passes]`, `[Hours later]`, `[The next morning]`
3. Beat count reaches 5+ without scene change (auto-subdivision)
4. Node has `scene_break: true` marker

## Core Workflow

### Phase 1: Initialization

**If starting new game:**

1. The gateway command provides the scenario path from `registry.yaml`:
   ```
   ${CLAUDE_PLUGIN_ROOT}/scenarios/[registry.scenarios.ID.path]
   ```

   Load the scenario using the appropriate mode (see **Scenario Loading** section):
   - **Standard**: Read entire file, cache in context
   - **Lazy**: If Read returns token limit error, read first 200 lines for header, then grep for `start_node`

   If the file doesn't exist:
   - Error: "Scenario file not found at [path]. Run /kleene sync to update registry."
   - Exit skill

   Track load mode in context: `lazy_loading: true/false`

2. Initialize state in memory from scenario:
   ```yaml
   current_node: [scenario.start_node]
   previous_node: null            # No previous node at start
   turn: 1
   scene: 1
   beat: 1
   scene_title: "Opening"
   scene_location: [scenario.initial_world.current_location]
   beat_log: []
   character: [scenario.initial_character]
   world: [scenario.initial_world]
   settings:
     improvisation_temperature: 5  # Default (Balanced). See lib/framework/improvisation.md
     gallery_mode: false
     foresight: 5                  # Default (Suggestive)
     classic_mode: false           # Default: show choices
   recent_history: []
   ```

3. **Do NOT create a save file yet.** Only save when:
   - User explicitly asks to save (`/kleene save`)
   - Reaching an ending (auto-save before exit)
   - After 5+ turns of play (checkpoint save)

4. The scenario data is now in your context - do not re-read it.

**If resuming from save:**

1. Read the specified save file from `./saves/[scenario_name]/[filename].yaml`
2. Load the referenced scenario file from `${CLAUDE_PLUGIN_ROOT}/scenarios/`
   - Use appropriate load mode (standard or lazy) based on file size
3. Store the save filename in memory (continue writing to same file)
4. Continue from saved state

### Phase 2: Game Turn

Execute this for each turn:

```
TURN:
  1. Get current node:
     - Standard mode: Access scenario.nodes[current_node] from cached scenario
     - Lazy mode: Grep for "^  {current_node}:" with -A 80, parse YAML

  1a. Process elapsed_since_previous (NEW in v5):
      - If node has elapsed_since_previous:
        - Convert to seconds: amount * TIME_UNITS[unit]
        - Add to world.time
        - Check scheduled events (step 1b)

  1b. Check and process scheduled events (NEW in v5):
      - For each event in scheduled_events where trigger_at <= world.time:
        - Apply event consequences
        - Add event_id to triggered_events
        - Remove from scheduled_events
      - Process events in order (lowest trigger_at first)
      - Max cascade depth: 10 (prevent infinite loops from event chains)

  2. Check for ending:
     - If current_node is in scenario.endings → display ending, save state, EXIT
     - If character.exists == false → display death ending, save state, EXIT

  2a. Check node precondition (if present):
     - If current node has `precondition`:
       - Evaluate precondition against current state
       - If FAILS:
         - Display blocked message (see "Blocked Display Format" below)
         - Restore: current_node = previous node (the node we came from)
         - Do NOT increment turn counter
         - GOTO step 4 (re-present previous choices)
       - If PASSES: continue normally

  3. Display narrative (with temperature adaptation):
     - Read settings.improvisation_temperature (default: 5)
     - Collect relevant improv_* flags from character.flags
     - IF temperature > 0 AND improv_* flags exist:
       - Generate contextual framing based on temperature level
       - Weave into or prepend to narrative text
       - See lib/framework/improvisation.md → "Improvisation Temperature"
     - Output the (possibly adapted) narrative with formatting
     - Show character stats line

  4. Evaluate available choices (with temperature adaptation):
     - For each option in node.choice.options:
       - Evaluate precondition against current state
       - If passes: add to available choices
       - If fails: EXCLUDE from choices (do not show)
     - IF temperature >= 4 AND improv_* flags exist:
       - Enrich option descriptions with improv context
       - E.g., "Attack with your sword (you recall its scarred side)"
     - IF temperature >= 7 AND improv_* flags suggest bonus action:
       - Generate at most 1 bonus option based on improv flags
       - Bonus options use soft consequences only (like free-text improv)
       - See lib/framework/improvisation.md → "Bonus Options"

  5. Present choices via AskUserQuestion:

     **IF settings.classic_mode == true:**
     ```json
     {
       "questions": [{
         "question": "[node.choice.prompt]",
         "header": "Action",
         "multiSelect": false,
         "options": [
           {"label": "Look around", "description": "Survey your surroundings"},
           {"label": "Inventory", "description": "Check what you're carrying"}
         ]
       }]
     }
     ```

     **ELSE (classic_mode == false):**
     ```json
     {
       "questions": [{
         "question": "[node.choice.prompt]",
         "header": "Choice",
         "multiSelect": false,
         "options": [available choices + bonus option if generated]
       }]
     }
     ```

  6. Wait for user selection

  6a. IF selection doesn't match any predefined option (free-text via "Other"):
      - Classify intent (Explore/Interact/Act/Meta)
      - Check feasibility against current state
      - Generate narrative response matching scenario tone
      - Apply soft consequences only (trait ±1, add_history, improv_* flags)
      - Beat++ (log to beat_log with type: "improv", action: summary)
      - Check scene triggers: location change, time skip, beat >= 5
        - If triggered: Scene++, beat→1, update scene_title
      - Display response with consequence indicators
      - Present same choices again (step 5)
      - Do NOT advance node or turn
      - GOTO step 6

  6b. IF selected option has `next: improvise` (scripted Unknown path):
      - Execute Scripted Improvisation Flow (see below)
      - GOTO step 1 if outcome node specified, else GOTO step 5

  6c. IF selection is a generated bonus option:
      - Treat like emergent improvisation (same as 6a)
      - Generate narrative response matching scenario tone
      - Apply soft consequences only (trait ±1, add_history, improv_* flags)
      - Beat++ (log to beat_log with type: "bonus", action: option label)
      - Check scene triggers (same as 6a)
      - Display response with consequence indicators
      - Present same choices again (step 5) — bonus option remains available
      - Do NOT advance node or turn
      - GOTO step 6

  6d. IF selection is "Look around" (classic mode):
      - Re-display current node narrative (abbreviated if long)
      - Extract and list exits mentioned in narrative
      - Extract and list notable items/NPCs if mentioned
      - Format as atmospheric description, not menu
      - Beat++ (log to beat_log with type: "look")
      - Present choices again
      - Do NOT advance node or turn
      - GOTO step 6

  6e. IF selection is "Inventory" (classic mode):
      - Display character.inventory as formatted list
      - If empty: "You are empty-handed."
      - If items: List each with brief description if available
      - Beat++ (log to beat_log with type: "inventory")
      - Present choices again
      - Do NOT advance node or turn
      - GOTO step 6

  7. Display option narrative (if present):
     - Check if selected option has a `narrative` field
     - If present: display it (plain text, no box format)
     - This is the immediate feedback to the player's choice

  8. Apply consequences of chosen option:
     - Execute each consequence type (see Consequence Application table)
     - Update character/world state in memory
     - After all consequences: re-check scheduled events (step 1b)
       - This handles advance_time or schedule_event consequences

  9. Advance state:
     - Log current beat: beat_log.append({turn, scene, beat, type: "scripted_choice", action: option.text})
     - Set previous_node = current_node   # Save for blocked restoration
     - Set current_node = option.next_node
     - Turn++ (resets scene→1, beat→1)
     - Update scene_location = world.current_location
     - Generate scene_title from new node context
     - Add choice to recent_history (keep last 5)

  10. GOTO step 1 (next turn)
```

### Phase 3: Persistence

> **Reference:** See `lib/framework/saves.md` for save format, file creation, and operations.

Save to disk when:
- Game ends (victory, death, transcendence)
- User explicitly requests save
- Session is ending

#### Save Metadata Caching

When saving game state, cache node metadata for rich save listings:

**If yaml_tool=yq:**
```bash
yq '.nodes.CURRENT_NODE | {"title": (.title // ("Node: " + "CURRENT_NODE")), "preview": (.narrative | split("\n") | map(select(. != "")) | .[0])}' scenario.yaml
```

Add to save file:
```yaml
current_node_title: "Village Crossroads"      # From .title or generated
current_node_preview: "The village elder..."   # First line of narrative
```

**If yaml_tool=grep:** Skip metadata caching (graceful degradation).

Old saves without cached metadata load normally - the metadata is optional and only used for richer save listings.

The PreToolUse hook auto-approves saves/ writes for seamless gameplay.

## Precondition & Consequence Evaluation

> **Reference:** See `lib/framework/evaluation-reference.md` for precondition evaluation and consequence application tables.
> **Schema Reference:** See `lib/framework/scenario-format.md` for all types and YAML syntax.

### Location Access Validation

When evaluating a `move_to` consequence or presenting location-based options:

1. Find target location in `scenario.initial_world.locations[]`
2. If location has `precondition`:
   - Evaluate precondition against current state
   - If FAILS, apply `access_mode`:
     - `filter` (default): Hide the option entirely
     - `show_locked`: Show option with "[Locked]" indicator, disabled
     - `show_normal`: Show normally, fail with message if selected

**Access Denied Display (for show_normal mode):**
```
╭──────────────────────────────────────────────────────────────────────╮
│ ACCESS DENIED                                                        │
╰──────────────────────────────────────────────────────────────────────╯

[access_denied_narrative or generated fallback]

You cannot enter [location name].
```

**Location Access Fallback Messages:**
| Precondition Type | Fallback Template |
|-------------------|-------------------|
| `has_item` | "You need the **[item]** to enter this place." |
| `trait_minimum` | "Your **[trait]** is insufficient to access this location." |
| `flag_set` | "Something must happen before this place opens to you." |
| `environment_is` | "The **[property]** here must be **[value]**." |
| `environment_minimum` | "The **[property]** here is too low." |
| `environment_maximum` | "The **[property]** here is too high." |
| `all_of` | Generate message for first failing sub-condition |

### Blocked Display Format

When a node precondition fails, display:

```
╭──────────────────────────────────────────────────────────────────────╮
│ BLOCKED                                                              │
╰──────────────────────────────────────────────────────────────────────╯

[blocked_narrative or generated fallback]

You remain where you are.
```

The header uses the standard 70-character width with rounded corners.

### Fallback Message Generation

If a node has a `precondition` but no `blocked_narrative`, generate a fallback:

| Precondition Type | Fallback Template |
|-------------------|-------------------|
| `has_item` | "You need the **[item]** to proceed here." |
| `missing_item` | "The **[item]** you carry prevents this path." |
| `trait_minimum` | "Your **[trait]** ([current]) is insufficient. Requires at least [minimum]." |
| `trait_maximum` | "Your **[trait]** ([current]) is too high. Requires [maximum] or less." |
| `flag_set` | "Something must happen before you can proceed." |
| `flag_not_set` | "Your past actions have closed this path." |
| `relationship_minimum` | "Your relationship with **[npc]** ([current]) is insufficient. Requires at least [minimum]." |
| `location_flag_set` | "The **[location]** is not yet prepared for this." |
| `location_flag_not_set` | "Conditions at **[location]** prevent this path." |
| `location_property_minimum` | "The **[property]** at **[location]** is insufficient." |
| `location_property_maximum` | "The **[property]** at **[location]** is too high." |
| `all_of` | Generate message for first failing sub-condition |
| `any_of` | "You need at least one of several requirements." |
| `none_of` | "Your current situation prevents this path." |

**Edge Case - Start Node with Precondition:**
If `start_node` has a `precondition`, this is a scenario design error. Display:
```
ERROR: Start node cannot have a precondition.
The scenario "[name]" has an invalid configuration.
```
Refuse to start the game.

## Improvised Action Handling

> **Reference:** See `lib/framework/improvisation.md` for complete handling rules.

When a player selects "Other" and provides free-text input:

1. Classify intent (Explore/Interact/Act/Meta)
2. Check feasibility against current state (Possible/Blocked/Impossible)
3. Generate narrative response matching scenario tone
4. Apply soft consequences only (trait +/-1, add_history, improv_* flags)
5. Display response with bold box format (generate creative title)
6. Present same choices again - do NOT advance node or turn

Soft consequences preserve scenario balance while rewarding exploration.

### Hint Generation (Foresight-Gated)

When player asks for help/hints during improvisation (e.g., "where is the
treasure?", "what should I do?", "how do I get past the troll?"):

1. Classify as Meta intent with hint_request subtype
2. Read `settings.foresight` value (default: 5)
3. Generate hint at appropriate specificity level:

| Foresight | Name | Response Pattern |
|-----------|------|------------------|
| 0 | Blind | "You'll have to discover that yourself." (refuse hint) |
| 1-3 | Cryptic | Atmospheric/poetic. Reference mood, themes, not specifics. |
| 4-6 | Suggestive | Directional. Name regions/directions without exact steps. |
| 7-9 | Helpful | Clear guidance. Name specific locations and items needed. |
| 10 | Oracle | Full walkthrough. Step-by-step instructions to goal. |

**Example responses for "Where can I find treasure?"**

- **0 (Blind)**: "The adventurer must discover their own fortune."
- **3 (Cryptic)**: "Treasures favor those who venture into the deep places..."
- **5 (Suggestive)**: "The eastern passages and underground depths hold rewards."
- **8 (Helpful)**: "There's a painting in the Gallery to the east, and a bar in the Loud Room."
- **10 (Oracle)**: "Go east twice to the Gallery, take the painting. Then go down to the cellar, navigate past the troll, and find the platinum bar in the Loud Room."

**Hint generation requires scenario knowledge:**
- Standard mode: Use cached scenario data to identify goals, items, paths
- Lazy mode: Query scenario with yq/grep to find relevant objectives

Hints should reference the scenario's actual content, not generic advice.
After delivering the hint, present the same choices again (no node advance).

## Scripted Improvisation Flow

When a player selects an option with `next: improvise`, execute this special flow for the Unknown row of the Nine Cells.

> **CRITICAL:** See `lib/framework/presentation.md` → "Improvise Option Flow" for seamless presentation rules. Never output internal processing notes.

### Step 1: Display option narrative

If the option has a `narrative` field, display it first as context. Then immediately present the sub-prompt - no meta-commentary.

### Step 2: Present sub-prompt

Ask the player for specific intent:

```json
{
  "questions": [{
    "question": "What specifically do you do?",
    "header": "Action",
    "multiSelect": false,
    "options": [
      {"label": "Watch carefully", "description": "Observe and study"},
      {"label": "Wait patiently", "description": "See what happens"},
      {"label": "Look for details", "description": "Search for information"}
    ]
  }]
}
```

Generate options based on `improvise_context.theme`. Always allow free-text via "Other".

### Step 3: Classify response to grid cell

Match the player's response against the patterns in `improvise_context`:

```
IF response matches any pattern in `permits`:
  cell = Discovery (Unknown + World Permits)

ELSE IF response matches any pattern in `blocks`:
  cell = Revelation (Unknown + World Blocks)

ELSE:
  cell = Limbo (Unknown + World Indeterminate)
```

Pattern matching uses case-insensitive regex. Example:
- `permits: ["scales", "eyes", "breathing"]` matches "I study the dragon's scales"
- `blocks: ["attack", "steal"]` matches "I try to sneak past and steal something"

### Step 4: Generate narrative response

Based on the determined cell, generate an appropriate response:

**Discovery (permits matched):**
- Exploration yields insight
- Positive tone, rewarding curiosity
- May add soft trait bonus (+1 wisdom typical)

**Revelation (blocks matched):**
- World prevents or warns against action
- Explanatory tone, teaches constraint
- May add soft trait adjustment (-1 luck typical)

**Limbo (no match):**
- Use `improvise_context.limbo_fallback` as the base
- Elaborate with atmospheric detail
- Neutral tone, maintains suspense
- No trait changes

### Step 5: Apply soft consequences

Same rules as emergent improvisation:
- `modify_trait` with delta -1 to +1 only
- `add_history` to record the exploration
- `set_flag` with `improv_*` prefix only

### Step 6: Determine next state

Check `outcome_nodes` for the determined cell:

```yaml
outcome_nodes:
  discovery: dragon_notices_patience
  revelation: dragon_dismisses_hesitation
  # limbo: omitted
```

**If outcome_nodes[cell] is specified:**
- Advance to that node
- Increment turn
- Continue to next turn (step 1)

**If outcome_nodes[cell] is omitted (typical for Limbo):**
- Stay at current node
- Do NOT increment turn
- Re-present original choices (step 5)

### Example Flow

```
Option selected: "Wait and observe the dragon"
  └── has next: improvise

Sub-prompt: "What specifically do you do?"
  └── Player response: "I study the inscriptions on its scales"

Pattern match:
  └── permits: ["scales", "inscriptions"] ← MATCH
  └── cell = Discovery

Generate narrative:
  └── "You peer closer at the ancient markings etched into the iron-hard
       scales. They seem to form words in a language older than human
       memory. One pattern repeats - a symbol of greeting, perhaps?"
  └── +1 wisdom - Attention to detail

Outcome nodes:
  └── discovery: dragon_notices_patience
  └── Advance to dragon_notices_patience, turn++
```

## Narrative Presentation

> **⚠️ MANDATORY: Follow `lib/framework/presentation.md` EXACTLY**
>
> **ALL OUTPUT MUST BE 70 CHARACTERS WIDE — NO EXCEPTIONS.**
>
> This includes:
> - Header block ═ borders: exactly 70 ═ characters
> - Narrative text: wrap at 70 characters
> - Status lines: wrap at 70 characters
>
> Users play on small screens. Text wider than 70 chars is cut off.

### Which Header Block to display

- **Cinematic header**: Game start, location changes, major story beats
- **Normal Header**: Same location, no major narrative changes 

> **MANDATORY:**  See `lib/framework/presentation.md` → "Header Block" for templates and examples of each header



## Choice Presentation

Use AskUserQuestion per conventions in `lib/framework/presentation.md`.

**Silent Precondition Filtering**: Options failing preconditions are
removed BEFORE presenting choices. Never show "locked" or "requires X"
indicators. The character simply doesn't think of impossible actions.
This maintains immersion — if you can't do it, you don't see it.

```json
{
  "questions": [{
    "question": "The dragon awaits. What do you do?",
    "header": "Choice",
    "multiSelect": false,
    "options": [
      {"label": "Fight", "description": "Attack with your sword"},
      {"label": "Negotiate", "description": "Attempt to speak with the dragon"},
      {"label": "Flee", "description": "Retreat to safety"}
    ]
  }]
}
```

## Ending Detection

Check for endings:
1. current_node is in scenario.endings
2. character.exists == false
3. No available choices (dead end - shouldn't happen in well-designed scenarios)

Display ending with appropriate tone:

**Victory:**
```
╔═══════════════════════════════════════════════════════════╗
| VICTORY                                                   |
╚═══════════════════════════════════════════════════════════╝

[Ending narrative - celebratory tone]
```

**Death:**
```
╔═══════════════════════════════════════════════════════════╗
| DEATH                                                     |
╚═══════════════════════════════════════════════════════════╝

[Ending narrative - somber, respectful]
```

**Transcendence:**
```
╔═══════════════════════════════════════════════════════════╗
| TRANSCENDENCE                                             |
╚═══════════════════════════════════════════════════════════╝

[Ending narrative - mystical, transformative]
```

**Unchanged (Irony):**
```
╔═══════════════════════════════════════════════════════════╗
| UNCHANGED                                                 |
╚═══════════════════════════════════════════════════════════╝

[Ending narrative - ironic, reflective]
```

## Additional Resources

- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/core.md`** - Option type semantics, quadrant theory
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/scenario-format.md`** - YAML specification, preconditions, consequences
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/presentation.md`** - Header, trait, and choice formatting
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/improvisation.md`** - Free-text action handling
- **`${CLAUDE_PLUGIN_ROOT}/lib/framework/saves.md`** - Game folder, save format, persistence rules
- **`${CLAUDE_PLUGIN_ROOT}/scenarios/`** - Bundled scenarios
