# Scripted Improvisation Flow

When a player selects an option with `next: improvise`, execute this special flow for the Unknown row of the Decision Grid.

> **CRITICAL:** See `${CLAUDE_PLUGIN_ROOT}/lib/framework/gameplay/presentation.md` → "Improvise Option Flow" for seamless presentation rules. Never output internal processing notes.

## Step 1: Display option narrative

If the option has a `narrative` field, display it first as context. Then immediately present the sub-prompt - no meta-commentary.

## Step 2: Present sub-prompt

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

## Step 3: Classify response to grid cell

Match the player's response against the patterns in `improvise_context`:

```
IF response matches any pattern in `permits`:
  cell = Discovery (Unknown + World Permits)

ELSE IF response matches any pattern in `blocks`:
  cell = Constraint (Unknown + World Blocks)

ELSE:
  cell = Limbo (Unknown + World Indeterminate)
```

Pattern matching uses case-insensitive regex. Example:
- `permits: ["scales", "eyes", "breathing"]` matches "I study the dragon's scales"
- `blocks: ["attack", "steal"]` matches "I try to sneak past and steal something"

## Step 4: Generate narrative response

Based on the determined cell, generate an appropriate response:

**Discovery (permits matched):**
- Exploration yields insight
- Positive tone, rewarding curiosity
- May add soft trait bonus (+1 wisdom typical)

**Constraint (blocks matched):**
- World prevents or warns against action
- Explanatory tone, teaches constraint
- May add soft trait adjustment (-1 luck typical)

**Limbo (no match):**
- Use `improvise_context.limbo_fallback` as the base
- Elaborate with atmospheric detail
- Neutral tone, maintains suspense
- No trait changes

## Step 5: Apply soft consequences

Same rules as emergent improvisation:
- `modify_trait` with delta -1 to +1 only
- `add_history` to record the exploration
- `set_flag` with `improv_*` prefix only
- `advance_time` via config lookup (if `travel_config.improvisation_time` exists):
  - Discovery/Constraint: use `explore` intent time
  - Limbo: use `limbo` intent time
  - After time advance: re-check scheduled events

## Step 6: Determine next state

Check `outcome_nodes` for the determined cell:

```yaml
outcome_nodes:
  discovery: dragon_notices_patience
  constraint: dragon_dismisses_hesitation
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

## Example Flow

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
