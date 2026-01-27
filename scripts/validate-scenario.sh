#!/bin/bash
# Validates a scenario YAML against the JSON Schema
# Usage: ./scripts/validate-scenario.sh <scenario.yaml>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
SCHEMA="$PLUGIN_ROOT/lib/schema/scenario-schema.json"

if [ -z "$1" ]; then
    echo "Usage: $0 <scenario.yaml>"
    echo "Example: $0 scenarios/dragon_quest.yaml"
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "Error: File not found: $1"
    exit 1
fi

if [ ! -f "$SCHEMA" ]; then
    echo "Error: Schema not found: $SCHEMA"
    exit 1
fi

if ! command -v check-jsonschema &> /dev/null; then
    echo "Warning: check-jsonschema not installed. Install with: pip install check-jsonschema"
    echo "Falling back to basic yq validation..."
    echo ""

    if ! command -v yq &> /dev/null; then
        echo "Error: yq not installed. Install with: pip install yq"
        exit 1
    fi

    # Basic structure check with yq
    RESULT=$(yq 'has("name") and has("start_node") and has("nodes") and has("endings")' "$1")
    if [ "$RESULT" = "true" ]; then
        echo "Basic structure valid (name, start_node, nodes, endings present)"
        exit 0
    else
        echo "Basic structure invalid: missing required fields"
        exit 1
    fi
fi

check-jsonschema --schemafile "$SCHEMA" "$1"
