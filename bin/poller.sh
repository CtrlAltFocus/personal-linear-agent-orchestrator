#!/bin/bash
# PLAO Poller Script
# Runs periodically to find Linear tickets with *-todo labels and enqueue them

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLAO_DIR="$HOME/.plao"
SEEN_FILE="$PLAO_DIR/seen_tasks.txt"

# Ensure files exist
mkdir -p "$PLAO_DIR"
touch "$SEEN_FILE"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Polling for *-todo labels..."

# Query Linear for tickets with *-todo labels in the Product team using Gemini Flash
PROMPT='Use the Linear MCP tool to search for issues in the "Product" team that have labels ending with "-todo".

Return ONLY a valid JSON array with this exact format (no markdown, no explanation):
[{"id": "uuid", "identifier": "PROJ-123", "title": "Issue title", "labels": ["label1", "label2"]}]

If no issues found, return: []'

RESPONSE=$(gemini "$PROMPT" -m gemini-3-flash-preview -y -o text 2>/dev/null)

# Try to extract JSON from the response (handle potential markdown wrapping)
TICKETS=$(echo "$RESPONSE" | grep -o '\[.*\]' | head -1)

# Validate we got JSON
if [ -z "$TICKETS" ] || ! echo "$TICKETS" | jq empty 2>/dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] No valid JSON response from Gemini"
    exit 0
fi

# Process each ticket
echo "$TICKETS" | jq -c '.[]' 2>/dev/null | while read -r ticket; do
    ID=$(echo "$ticket" | jq -r '.id')
    CODE=$(echo "$ticket" | jq -r '.identifier')
    TITLE=$(echo "$ticket" | jq -r '.title')

    # Find the *-todo label
    LABEL=$(echo "$ticket" | jq -r '.labels[]' 2>/dev/null | grep -E '.*-todo$' | head -1)

    if [ -z "$LABEL" ]; then
        continue
    fi

    # Skip if already seen (dedup by ID + label combination)
    TASK_KEY="${ID}:${LABEL}"
    if grep -qF "$TASK_KEY" "$SEEN_FILE"; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Skipping (already seen): $CODE - $LABEL"
        continue
    fi

    # Enqueue the task
    pueue add --group plao -- "$SCRIPT_DIR/worker.sh" "$ID" "$CODE" "$TITLE" "$LABEL"

    # Mark as seen
    echo "$TASK_KEY" >> "$SEEN_FILE"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Enqueued: $CODE - $LABEL"
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Polling complete"
