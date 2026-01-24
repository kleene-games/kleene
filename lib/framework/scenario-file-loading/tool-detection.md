# Tool Detection Pattern

Detect available YAML processing tools at session start. Use the best available tool for scenario extraction.

## Detection Order

```
yq 4.x (preferred) → grep (fallback) → full read (small files)
```

## Step 1: Check for yq

Run at session start (silent, no user output):

```bash
command -v yq >/dev/null 2>&1 && yq --version 2>&1 | head -1
```

**Expected output for yq 4.x:**
```
yq (https://github.com/mikefarah/yq/) version v4.x.x
```

**Version validation:**
- Must be Mike Farah's Go version (contains "github.com/mikefarah/yq")
- Must be version 4.x or higher
- Python yq (different project) is NOT supported

**Set capability flag:**
```
IF output matches "mikefarah/yq" AND version >= 4:
  yaml_tool: yq
ELSE:
  yaml_tool: grep
```

## Step 2: Determine Load Strategy

Based on file size and yaml_tool capability:

| File Size | yaml_tool=yq | yaml_tool=grep |
|-----------|--------------|----------------|
| Small (<20k tokens) | Full read | Full read |
| Large (>20k tokens) | yq extraction | grep -A 80 |

**Small file detection:**
- Attempt full Read
- If succeeds without token limit error: use standard mode
- If token limit error: switch to lazy mode with appropriate tool

## Usage in Skills

Reference this pattern in skill files:

```markdown
> **Tool Detection:** See `lib/framework/scenario-file-loading/tool-detection.md`
```

At session start, detect tools and store in context:

```
SESSION_CONTEXT:
  yaml_tool: yq|grep
  lazy_loading: true|false
```

## Fallback Chain

If the primary tool fails during operation:

```
1. yq command fails → silently fall back to grep
2. grep fails → read entire file (may hit token limit)
3. Token limit → report to user, cannot load scenario
```

**Silent fallback:** Never interrupt gameplay to report tool failures. Just use the next tool in the chain.

## Example Detection Code

```bash
# Detect yq availability and version
detect_yaml_tool() {
  if command -v yq >/dev/null 2>&1; then
    version_output=$(yq --version 2>&1 | head -1)
    if echo "$version_output" | grep -q "mikefarah/yq"; then
      echo "yq"
      return 0
    fi
  fi
  echo "grep"
  return 0
}
```

## Notes

- **No Python fallback:** Python+pyyaml was considered but excluded for simplicity
- **yq syntax:** All templates use yq 4.x syntax (different from yq 3.x and Python yq)
- **Performance:** yq and grep have similar execution time; yq wins on correctness
