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

# Check for API key
if [ -z "$PLAO_LINEAR_API_KEY" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: PLAO_LINEAR_API_KEY environment variable not set"
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Polling for *-todo labels..."

# GraphQL query to find issues with labels ending in "-todo" in the Product team
# We fetch issues that have any label, then filter client-side for *-todo pattern
QUERY='query {
  team(id: "Product") {
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
  }
}'

# Make the API request
RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: $PLAO_LINEAR_API_KEY" \
    -d "$(jq -n --arg q "$QUERY" '{query: $q}')" \
    https://api.linear.app/graphql)

# Check for errors
if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    # Try by team name instead of ID
    QUERY='query {
      teams(filter: { name: { eq: "Product" } }) {
        nodes {
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
        }
      }
    }'

    RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: $PLAO_LINEAR_API_KEY" \
        -d "$(jq -n --arg q "$QUERY" '{query: $q}')" \
        https://api.linear.app/graphql)
fi

# Check for errors again
if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] API Error: $(echo "$RESPONSE" | jq -r '.errors[0].message')"
    exit 1
fi

# Extract issues - handle both query formats
ISSUES=$(echo "$RESPONSE" | jq -c '
    (.data.team.issues.nodes // .data.teams.nodes[0].issues.nodes // [])[]
' 2>/dev/null)

if [ -z "$ISSUES" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] No issues with *-todo labels found"
    exit 0
fi

# Process each issue
echo "$ISSUES" | while read -r issue; do
    ID=$(echo "$issue" | jq -r '.id')
    CODE=$(echo "$issue" | jq -r '.identifier')

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

    # Enqueue the task (only pass safe values - ID, CODE, LABEL)
    # The worker/agent will fetch full details from Linear
    pueue add --group plao -- "$SCRIPT_DIR/worker.sh" "$ID" "$CODE" "$LABEL"

    # Mark as seen
    echo "$TASK_KEY" >> "$SEEN_FILE"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Enqueued: $CODE - $LABEL"
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Polling complete"
