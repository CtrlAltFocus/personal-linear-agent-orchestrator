#!/bin/bash
# PLAO Poller Script
# Runs periodically to find Linear tickets with *-todo labels and enqueue them
# Uses Linear GraphQL API directly (no AI calls)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLAO_DIR="$HOME/.plao"
SEEN_FILE="$PLAO_DIR/seen_tasks.txt"

# Ensure files exist
mkdir -p "$PLAO_DIR"
touch "$SEEN_FILE"

# Check for config file
CONFIG_FILE="$PLAO_DIR/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $CONFIG_FILE not found. Run setup.sh first."
    exit 1
fi

# Validate config has projects
PROJECT_COUNT=$(jq '.projects | length' "$CONFIG_FILE")
if [ "$PROJECT_COUNT" -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: No projects configured in $CONFIG_FILE"
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Polling for *-todo labels across $PROJECT_COUNT project(s)..."

# GraphQL query template for fetching issues with *-todo labels
# We query all issues with -todo labels, then filter by prefix
QUERY='query {
  issues(
    filter: {
      labels: { some: { name: { endsWith: "-todo" } } }
    }
    first: 50
  ) {
    nodes {
      id
      identifier
      title
      labels {
        nodes {
          name
        }
      }
    }
  }
}'

# Iterate through each configured project
jq -c '.projects[]' "$CONFIG_FILE" | while read -r project; do
    LINEAR_PREFIX=$(echo "$project" | jq -r '.linear_prefix')
    LINEAR_API_KEY=$(echo "$project" | jq -r '.linear_api_key')
    PROJECT_PATH=$(echo "$project" | jq -r '.path')

    # Validate project config
    if [ -z "$LINEAR_PREFIX" ] || [ "$LINEAR_PREFIX" = "null" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: Project missing linear_prefix, skipping"
        continue
    fi

    if [ -z "$LINEAR_API_KEY" ] || [ "$LINEAR_API_KEY" = "null" ] || [ "$LINEAR_API_KEY" = "lin_api_xxxxx" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: Project $LINEAR_PREFIX missing valid linear_api_key, skipping"
        continue
    fi

    if [ -z "$PROJECT_PATH" ] || [ "$PROJECT_PATH" = "null" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: Project $LINEAR_PREFIX missing path, skipping"
        continue
    fi

    if [ ! -d "$PROJECT_PATH" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: Project path does not exist: $PROJECT_PATH, skipping"
        continue
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Checking project: $LINEAR_PREFIX -> $PROJECT_PATH"

    # Make the API request
    RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: $LINEAR_API_KEY" \
        -d "$(jq -n --arg q "$QUERY" '{query: $q}')" \
        https://api.linear.app/graphql)

    # Check for errors
    if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] API Error for $LINEAR_PREFIX: $(echo "$RESPONSE" | jq -r '.errors[0].message')"
        continue
    fi

    # Extract issues
    ISSUES=$(echo "$RESPONSE" | jq -c '.data.issues.nodes[]' 2>/dev/null)

    if [ -z "$ISSUES" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] No issues with *-todo labels found for $LINEAR_PREFIX"
        continue
    fi

    # Process each issue
    echo "$ISSUES" | while read -r issue; do
        ID=$(echo "$issue" | jq -r '.id')
        CODE=$(echo "$issue" | jq -r '.identifier')

        # Check if this issue belongs to this project (matches prefix)
        ISSUE_PREFIX=$(echo "$CODE" | cut -d'-' -f1)
        if [ "$ISSUE_PREFIX" != "$LINEAR_PREFIX" ]; then
            continue
        fi

        # Find the *-todo label
        LABEL=$(echo "$issue" | jq -r '.labels.nodes[].name' 2>/dev/null | grep -E '.*-todo$' | head -1)

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
        pueue add --group plao -- "$SCRIPT_DIR/worker.sh" "$ID" "$CODE" "$LABEL" "$PROJECT_PATH"

        # Mark as seen
        echo "$TASK_KEY" >> "$SEEN_FILE"

        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Enqueued: $CODE - $LABEL -> $PROJECT_PATH"
    done
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Polling complete"
