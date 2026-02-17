# Scenario File Loading

This folder consolidates all scenario loading protocols for the Kleene engine.

## Load Modes

| Mode | When Used | Behavior |
|------|-----------|----------|
| **Standard** | Files under ~20k tokens | Read entire file, cache in context |
| **Lazy** | Files exceeding token limit | Load header once, fetch nodes on demand |
| **Remote** | Server-hosted scenarios | Fetch nodes via HTTP API from kleene-server |

## Decision Flow

```
1. Check for server configuration
   │
   ├─ SERVER URL configured + scenario ID provided → Remote mode
   │   └─ See remote-loading.md
   │
   └─ LOCAL FILE available
       │
       ├─ Detect yaml_tool at session start
       │   └─ See tool-detection.md
       │
       ├─ Attempt full Read of scenario file
       │   │
       │   ├─ SUCCESS → Standard mode
       │   │   └─ See standard-loading.md
       │   │
       │   └─ TOKEN LIMIT ERROR → Lazy mode
       │       └─ See lazy-loading.md
```

## Tool Detection

At session start, check for yq availability:

```bash
command -v yq >/dev/null 2>&1 && yq --version 2>&1 | head -1
```

Set capability flag:
- `yaml_tool: yq` if output contains "mikefarah/yq" and version >= 4
- `yaml_tool: grep` otherwise

> **Details:** See `tool-detection.md` for complete detection protocol.

## Files in This Folder

| File | Purpose |
|------|---------|
| `overview.md` | This file - mode selection and decision flow |
| `tool-detection.md` | yq availability detection |
| `standard-loading.md` | Full file read protocol |
| `lazy-loading.md` | On-demand node loading protocol |
| `remote-loading.md` | HTTP API loading protocol (kleene-server) |
| `extraction-templates.md` | yq/grep templates for gameplay |

## Related Files

- **Analysis queries:** `lib/patterns/analysis-queries.md` - yq patterns for kleene-analyze
- **Scenario format:** `lib/framework/formats/scenario-format.md` - YAML specification
