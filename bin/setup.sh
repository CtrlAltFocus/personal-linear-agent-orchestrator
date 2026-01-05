#!/bin/bash
# PLAO Setup Script
# Run this once to initialize the environment

set -e

PLAO_DIR="$HOME/.plao"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== PLAO Setup ==="
echo ""

# Create directories
echo "Creating directories..."
mkdir -p "$PLAO_DIR/logs"
touch "$PLAO_DIR/seen_tasks.txt"
echo "  Created: $PLAO_DIR"
echo "  Created: $PLAO_DIR/logs"
echo "  Created: $PLAO_DIR/seen_tasks.txt"

# Create sample config.json if it doesn't exist
if [ ! -f "$PLAO_DIR/config.json" ]; then
    cat > "$PLAO_DIR/config.json" << 'EOF'
{
  "linear_api_key": "lin_api_xxxxx",
  "projects": {
    "PROD": "/Users/andy/Documents/Projects/my-product",
    "API": "/Users/andy/Documents/Projects/api-server"
  }
}
EOF
    echo "  Created: $PLAO_DIR/config.json (sample - please edit!)"
else
    echo "  Exists: $PLAO_DIR/config.json"
fi
echo ""

# Check for dependencies
echo "Checking dependencies..."

if ! command -v pueue &> /dev/null; then
    echo "  ERROR: pueue not found. Install with: brew install pueue"
    exit 1
fi
echo "  pueue: OK"

if ! command -v jq &> /dev/null; then
    echo "  ERROR: jq not found. Install with: brew install jq"
    exit 1
fi
echo "  jq: OK"

if ! command -v claude &> /dev/null; then
    echo "  WARNING: claude CLI not found"
else
    echo "  claude: OK"
fi

if ! command -v gemini &> /dev/null; then
    echo "  WARNING: gemini CLI not found"
else
    echo "  gemini: OK"
fi

echo ""

# Initialize pueue
echo "Initializing pueue..."

# Start daemon if not running
if ! pueue status &> /dev/null; then
    echo "  Starting pueue daemon..."
    pueued -d
    sleep 1
fi

# Create group if it doesn't exist
if ! pueue group | grep -q "plao"; then
    echo "  Creating 'plao' group..."
    pueue group add plao
fi

# Set parallelism
pueue parallel 2 --group plao
echo "  Set parallelism to 2 for 'plao' group"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo ""
echo "1. Add the poller to cron (runs every minute):"
echo "   crontab -e"
echo "   * * * * * $SCRIPT_DIR/poller.sh >> $PLAO_DIR/poller.log 2>&1"
echo ""
echo "2. Or run as a loop for testing:"
echo "   while true; do $SCRIPT_DIR/poller.sh; sleep 60; done"
echo ""
echo "3. Monitor the queue:"
echo "   watch -n 2 'pueue status --group plao'"
echo ""
