#!/bin/bash
set -euo pipefail

# Kleene Save Auto-Approve Hook
# Auto-approves Write and Bash operations to saves/ directory for seamless gameplay

# Read hook input from stdin
input=$(cat)

# Extract tool name
tool_name=$(echo "$input" | jq -r '.tool_name // ""')

# Check based on tool type
should_approve=false

if [[ "$tool_name" == "Write" ]]; then
  # For Write tool, check file_path
  file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""')
  if [[ "$file_path" == */saves/* ]]; then
    should_approve=true
  fi
elif [[ "$tool_name" == "Bash" ]]; then
  # For Bash tool, check if command writes to saves/
  command=$(echo "$input" | jq -r '.tool_input.command // ""')
  # Match: cat > .../saves/... or echo > .../saves/... or similar
  if [[ "$command" == *"/saves/"* ]] && [[ "$command" == *">"* || "$command" == *"mkdir"* ]]; then
    should_approve=true
  fi
fi

if [[ "$should_approve" == "true" ]]; then
  # Output JSON to auto-approve
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "Auto-approved: game save operation"
  }
}
EOF
  exit 0
fi

# For other operations, don't interfere (let normal permission flow proceed)
exit 0
