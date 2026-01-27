# Standard Loading Mode

Use standard loading for scenarios that fit within context limits (~20k tokens).

## When to Use

- Read tool succeeds without token limit error
- File is under approximately 500-600 lines of YAML
- Most bundled scenarios use this mode

## Protocol

```
1. Read entire scenario file
   Read: scenarios/[scenario_name].yaml

2. Cache in conversation context
   - Scenario name, start_node
   - Initial character and world state
   - All nodes (full content)
   - All endings

3. Set context flag
   lazy_loading: false
```

## Benefits

- **Simplicity:** No extraction queries needed
- **Speed:** All data available immediately
- **Accuracy:** No parsing edge cases

## Cache Strategy

Once loaded, the scenario data remains in context for the entire session. Do not re-read the file unless explicitly requested.

## Fallback

If the Read tool returns a token limit error, switch to lazy loading mode. See `lazy-loading.md`.
