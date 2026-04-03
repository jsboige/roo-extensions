#!/bin/bash

# Check modeApiConfigs drift between model-configs.json and VS Code state
# This script uses the roo-state-manager MCP to read VS Code state

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

MODEL_CONFIGS_PATH="${1:-$REPO_ROOT/roo-config/model-configs.json}"

echo "modeApiConfigs Drift Check"
echo "=========================="
echo "Source of truth: $MODEL_CONFIGS_PATH"
echo "VS Code state: $APPDATA/Code/User/globalStorage/state.vscdb"
echo ""

# Check if model-configs.json exists
if [ ! -f "$MODEL_CONFIGS_PATH" ]; then
    echo "ERROR: model-configs.json not found at: $MODEL_CONFIGS_PATH"
    exit 1
fi

# Extract modeApiConfigs from model-configs.json
SOURCE_MODE_API_CONFIGS=$(node -e "
const fs = require('fs');
const modelConfigs = JSON.parse(fs.readFileSync('$MODEL_CONFIGS_PATH', 'utf-8'));
console.log(JSON.stringify(modelConfigs.modeApiConfigs || {}));
")

echo "Source of truth modeApiConfigs:"
echo "$SOURCE_MODE_API_CONFIGS" | jq -r 'to_entries | .[] | "  \(.key): \(.value)"'
echo ""

# Note: We need the roo-state-manager MCP to read VS Code state
# This script is a simplified version that just shows the source of truth
echo "To check VS Code state, use the roo-state-manager MCP:"
echo "  - roosync_compare_config with granularity=settings"
echo "  - Or manually check state.vscdb with SQLite browser"
