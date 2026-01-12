# Registry Format

The scenario registry (`scenarios/registry.yaml`) provides centralized metadata for all scenarios, eliminating per-play file scanning.

## Location

`${CLAUDE_PLUGIN_ROOT}/scenarios/registry.yaml`

## Schema

```yaml
version: 1                          # Registry format version
last_synced: 2026-01-12T14:30:00Z   # ISO timestamp of last sync

scenarios:
  scenario_id:                       # Derived from filename (without .yaml)
    name: "Display Name"             # Required - shown in play menu
    description: "Brief summary"     # Required - shown in play menu
    path: filename.yaml              # Required - relative to scenarios/
    enabled: true                    # Optional - default true
    tags: ["fantasy", "bundled"]     # Optional - categorization
    missing: false                   # System-set - true if file not found
```

## Fields

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `name` | Yes | string | Display name for menus |
| `description` | Yes | string | 1-2 sentence summary |
| `path` | Yes | string | Relative path to scenario file |
| `enabled` | No | boolean | Toggle visibility (default: true) |
| `tags` | No | string[] | Categorization labels |
| `missing` | No | boolean | Set by sync when file not found |

## Tag Conventions

| Tag | Meaning |
|-----|---------|
| `bundled` | Ships with the plugin |
| `generated` | Created via `/kleene generate` |
| `discovered` | Found during sync (manually added) |
| `user-created` | User's custom scenario |

## Metadata Extraction (During Sync)

When syncing, extract metadata from scenario files in priority order:

**Name field:**
1. `name` at top level
2. `title` at top level
3. `metadata.title` nested
4. Fallback: filename without extension, title-cased

**Description field:**
1. `description` at top level
2. `metadata.description` nested
3. Fallback: "No description available"

## Operations

### Auto-Create
If `registry.yaml` doesn't exist when `/kleene play` runs, perform automatic sync to create it.

### Sync (`/kleene sync`)
1. Load existing registry (or empty structure)
2. Glob `scenarios/*.yaml` (exclude registry.yaml)
3. For each scenario file:
   - Extract metadata using priority rules above
   - Add/update entry in registry
4. For existing entries where file not found:
   - Set `missing: true`
5. Update `last_synced` timestamp
6. Write registry file

### Auto-Register on Play
When user selects an unregistered scenario:
1. Read scenario file
2. Extract metadata
3. Add to registry with `tags: ["discovered"]`
4. Proceed to play

### Enable/Disable
Toggle `enabled` field without deleting the scenario file or registry entry.

## Menu Display

When building the play menu:

```
Which scenario would you like to play?

- The Dragon's Choice        (enabled, file exists)
- The Velvet Chamber         (enabled, file exists)
- New Scenario [unregistered] (file exists, not in registry)
- Old Scenario [missing]      (in registry, file not found)
```

Disabled scenarios are hidden from the menu unless explicitly requested.
