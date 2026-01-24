# Parser Mode Behaviors

Parser-style interface for text adventure gameplay.

> **Setting:** `settings.parser_mode: true` (default: `false`)

## Overview

Parser mode recreates the text adventure experience of Zork, Colossal Cave,
and other parser-based interactive fiction. Instead of presenting scripted
choice menus, the player types natural language commands.

### Why Parser Mode?

- **Immersion**: No visible choices breaks the "which option do I pick?" pattern
- **Exploration**: Players discover what's possible through experimentation
- **Authenticity**: Text adventure feel for those who prefer it
- **Challenge**: Requires active engagement to find valid actions

### Mode Comparison

| Aspect | Choice Mode (default) | Parser Mode |
|--------|----------------------|-------------|
| Options visible | Yes (2-4 scripted) | No (hidden) |
| Input method | Select from menu | Type commands |
| Help system | Self-evident options | Adaptive verb hints |
| Free-text | Via "Other" option | Primary input |
| Setting | `parser_mode: false` | `parser_mode: true` |

### Standard Actions

When parser mode is enabled, only three standard actions are presented:
1. **Look around** - Re-survey the current location
2. **Inventory** - Check what you're carrying
3. **Show help** - Get contextual hints about available commands

All other input comes through free-text entry. See [Free-Text Input](#free-text-input) below.

---

## Look Around

Re-display the current node's environment with structured information.

**When selected:**

1. Re-display current node narrative (abbreviated if long)
2. Extract and list exits mentioned in narrative
3. Extract and list notable items/NPCs if mentioned
4. Format as atmospheric description, not menu
5. Beat++ (log to beat_log with type: "look")
6. Present choices again
7. Do NOT advance node or turn

**Example output:**
```
You're in a dimly lit cavern. Moisture drips from the ceiling,
and the air smells of old stone and something else... sulfur.

Exits: North (narrow passage), East (collapsed tunnel)
You see: A rusted lantern, ancient bones scattered on the floor
```

## Inventory

Display the character's current inventory.

**When selected:**

1. Display `character.inventory` as formatted list
2. If empty: "You are empty-handed."
3. If items: List each with brief description if available
4. Beat++ (log to beat_log with type: "inventory")
5. Present choices again
6. Do NOT advance node or turn

**Example output:**
```
You are carrying:
  - A tarnished sword (your father's blade)
  - A leather pouch containing 12 gold coins
  - A crumpled note
```

## Adaptive Help Generation

Generate contextual hints about available actions without spoiling solutions.

**When selected:**

1. Beat++ (log to beat_log with type: "help")
2. Present choices again
3. Do NOT advance node or turn

### Verb Extraction Process

1. Read all `options[].text` from current node
2. Parse the leading verb (e.g., "Open the mailbox" → "open")
3. Lowercase and deduplicate verbs

### Action Categorization

```
MOVEMENT:     go, enter, climb, descend, exit, flee, leave, walk
EXAMINE:      examine, look, read, search, inspect, study
INTERACT:     open, close, take, drop, give, use, push, pull, turn
COMBAT:       attack, fight, defend, strike, parry
COMMUNICATE:  say, ask, talk, tell, shout, whisper
```

### Output Format

```
═══════════════════════════════════════════════════════════════════════
COMMANDS THAT MIGHT WORK HERE
═══════════════════════════════════════════════════════════════════════

Movement:    go [direction], enter
Examine:     examine [thing], read
Interact:    open, take

UNIVERSAL COMMANDS
inventory    - check what you're carrying
look         - survey surroundings
save         - save your game
═══════════════════════════════════════════════════════════════════════
```

### Inclusion Rules

| Include | Exclude |
|---------|---------|
| Verbs extracted from available options | Specific objects (say "open" not "open mailbox") |
| Universal commands (inventory, look, save) | Which directions are valid |
| | Options blocked by preconditions |

### Edge Cases

**No contextual verbs found (node has no options):**
- Show only universal commands section

**Many verbs in same category:**
- List all unique verbs for that category
- E.g., "Interact: open, take, push, use"

---

## Free-Text Input

In parser mode, all meaningful player input comes through free-text entry.
The system uses the same improvisation infrastructure as choice mode's "Other"
option.

### How It Works

1. Player types a command (e.g., "open mailbox", "go north", "examine sword")
2. System classifies intent and evaluates feasibility
3. If command matches a hidden scripted option → execute that option's path
4. If no match → handle as improvisation with soft consequences
5. Present the same node again (unless the matched option advanced the node)

> **Full specification:** See [improvisation.md](improvisation.md) for intent
> classification, feasibility checking, and response generation rules.

### Intent Classification

Parser mode uses the same intent categories:

| Intent | Keywords/Patterns | Example |
|--------|-------------------|---------|
| **Explore** | examine, look at, inspect | "examine the painting" |
| **Interact** | talk to, ask, speak with | "talk to the merchant" |
| **Act** | try, attempt, I [verb] | "climb the wall" |
| **Meta** | save, help, inventory | "save game" |

### Matching Hidden Options

Before treating input as improvisation, attempt to match against hidden options:

1. Parse the player's command for verb + object
2. Compare against `options[].text` for the current node
3. Use fuzzy matching: "go n" matches "Go north around the house"
4. If match found AND preconditions pass → execute that option's consequences

### Example Session

```
> look around
You're in front of a small white house. A boarded window faces west.
Exits: North (around house), South (around house), East (forest)
You see: A mailbox

> open mailbox
You open the mailbox, revealing a leaflet inside.
[Gained: leaflet]

> read leaflet
"WELCOME TO ZORK..."

> go north
You walk around the north side of the house...
```

### When Commands Don't Match

Commands that don't match any hidden option are handled as improvisation:
- Soft consequences only (±1 traits, `improv_*` flags)
- No node advancement
- Player remains at current choice point
