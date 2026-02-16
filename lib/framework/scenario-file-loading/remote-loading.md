# Remote Loading for Server-Hosted Scenarios

When a scenario is hosted on a kleene-server instance (local proxy or remote), use remote loading mode. This replaces yq/grep with HTTP API calls — same data, different transport.

> **Tool Detection:** See `overview.md` for mode selection.
> **Comparison:** See `lazy-loading.md` for the pattern this replaces.

## When to Use Remote Mode

Remote loading activates when:
- A server URL is configured (via `/kleene server` or environment)
- The scenario is identified by ID (not a local file path)
- The local proxy is running at `localhost:8420`

## Load Header

```
GET /api/scenario/{scenario_id}/header
```

Returns:
```json
{
  "name": "The Dragon's Choice",
  "description": "A hero must decide...",
  "start_node": "intro",
  "initial_character": { "traits": { "courage": 5, ... }, ... },
  "initial_world": { "current_location": "village", ... },
  "ending_ids": ["ending_victory", "ending_death", ...],
  "travel_config": { ... }
}
```

**Equivalent lazy-loading command:**
```bash
yq '{"name": .name, "start_node": .start_node, ...}' scenario.yaml
```

## Load Nodes on Demand

```
GET /api/scenario/{scenario_id}/node/{node_id}
```

Returns the full node definition including narrative, choice, options with preconditions, consequences, and improvise contexts.

```json
{
  "id": "intro",
  "narrative": "The village elder grips your arm...",
  "choice": {
    "prompt": "What do you do?",
    "options": [
      {
        "id": "seek_knowledge",
        "text": "Enter the dark forest",
        "cell": "chooses",
        "consequence": [...],
        "next_node": "forest_entrance"
      },
      ...
    ]
  }
}
```

**Equivalent lazy-loading command:**
```bash
yq '.nodes.intro' scenario.yaml
```

## Load Endings

```
GET /api/scenario/{scenario_id}/ending/{ending_id}
```

Returns:
```json
{
  "id": "ending_victory",
  "narrative": "VICTORY\n\nThe village celebrates...",
  "type": "victory"
}
```

## Load Locations

```
GET /api/scenario/{scenario_id}/locations
```

Returns array of location definitions with connections.

## State Synchronization

After each turn, the LLM pushes current game state to the server:

```
PUT /api/game/{session_id}/state
Body: { "state": { ...full game state... } }
```

This enables:
- Web UI to display stats, inventory, choices, position
- Server-side persistence across sessions
- Shared world state in multiplayer mode

## Narrative Relay

After generating narrative output, push it to the server for web UI display:

```
PUT /api/game/{session_id}/narrative
Body: { "narrative": "The rendered narrative text..." }
```

## Cell Reporting

When a Decision Grid cell is hit (from option's `cell` annotation or improvisation classification):

```
POST /api/game/{session_id}/cell
Body: { "cell_type": "triumph", "node_id": "dragon_fight" }
```

## Settings Polling

Before each turn, check if the player adjusted settings via the web UI:

```
GET /api/game/{session_id}/settings
```

Returns:
```json
{
  "improvisation_temperature": 7,
  "gallery_mode": false,
  "foresight": 5,
  "parser_mode": false
}
```

Update in-context settings if they differ from current values.

## Choice Input via Web UI

The player can click choice buttons in the web UI instead of using AskUserQuestion:

```
GET /api/game/{session_id}/choice
```

Returns `{"choice": "seek_knowledge"}` if a choice was submitted, or `{"choice": null}` if not.

When a choice is available from the web UI, use it instead of presenting AskUserQuestion.

## Save/Load via Server

```
POST /api/game/{session_id}/save
Body: { "name": "Before dragon fight" }
→ { "save_id": "abc123" }

POST /api/game/load/{save_id}?session_id={session_id}
→ { "state": {...}, "scenario_id": "dragon_quest" }
```

## Cache Strategy

- Header data: persistent (cached in context after first fetch)
- Current node: replaced each turn (fetch fresh via API)
- Endings: persistent (cached after first access)
- Settings: polled each turn (may change via web UI)

## Error Handling

If the server is unreachable:
1. Log warning but don't interrupt gameplay
2. Fall back to in-context state (LLM still has full state)
3. Retry on next turn
4. If server remains down for 3+ turns, inform player

If a node is not found (404):
1. Report error in narrative: "Path not found in scenario data"
2. Return to previous node
3. Do NOT increment turn counter

## Comparison: Three Loading Modes

| Aspect | Standard | Lazy | Remote |
|--------|----------|------|--------|
| Source | Full file in context | yq/grep on filesystem | HTTP API calls |
| Header | From cached file | yq header extraction | `GET /header` |
| Node | From cached file | yq node extraction | `GET /node/{id}` |
| State | LLM context only | LLM context only | LLM context + server sync |
| Saves | Write to `./saves/` | Write to `./saves/` | `POST /save` via API |
| Settings | In-context | In-context | Polled from server |
| Web UI | None | None | State relay enabled |
