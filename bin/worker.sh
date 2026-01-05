#!/bin/bash
# PLAO Worker Script
# Parses labels, invokes the correct AI CLI, manages status updates

set -e

ID="$1"       # Linear issue UUID
CODE="$2"     # e.g., "PROJ-123"
LABEL="$3"    # e.g., "gemini-research-todo"

if [ -z "$ID" ] || [ -z "$CODE" ] || [ -z "$LABEL" ]; then
    echo "Usage: worker.sh <issue-id> <issue-code> <label>"
    exit 1
fi

PLAO_DIR="$HOME/.plao"
LOG_DIR="$PLAO_DIR/logs"
SEEN_FILE="$PLAO_DIR/seen_tasks.txt"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/${CODE}-$(date +%Y%m%d-%H%M%S).log"

# Redirect all output to log file
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== PLAO Worker ==="
echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Issue: $CODE (ID: $ID)"
echo "Label: $LABEL"
echo ""

# Parse the label
# Format: <model>-<steps...>-<status>
# Extract model (first segment)
MODEL=$(echo "$LABEL" | cut -d'-' -f1)

# Extract status (last segment)
STATUS=$(echo "$LABEL" | rev | cut -d'-' -f1 | rev)

# Extract steps (everything in between)
# Remove model prefix and status suffix
STEPS=$(echo "$LABEL" | sed "s/^${MODEL}-//" | sed "s/-${STATUS}$//")

echo "Parsed:"
echo "  Model: $MODEL"
echo "  Steps: $STEPS"
echo "  Status: $STATUS"
echo ""

# Map model to CLI command
case "$MODEL" in
    gemini|geminiflash)
        CLI_CMD="gemini"
        CLI_MODEL="gemini-3-flash-preview"
        CLI_TYPE="gemini"
        ;;
    geminipro)
        CLI_CMD="gemini"
        CLI_MODEL="gemini-3-pro-preview"
        CLI_TYPE="gemini"
        ;;
    opus)
        CLI_CMD="claude"
        CLI_MODEL="opus"
        CLI_TYPE="claude"
        ;;
    sonnet)
        CLI_CMD="claude"
        CLI_MODEL="sonnet"
        CLI_TYPE="claude"
        ;;
    claude)
        CLI_CMD="claude"
        CLI_MODEL="opus"
        CLI_TYPE="claude"
        ;;
    *)
        echo "ERROR: Unknown model: $MODEL"
        exit 1
        ;;
esac

echo "CLI Configuration:"
echo "  Command: $CLI_CMD"
echo "  Model: $CLI_MODEL"
echo ""

# Convert steps from hyphen-separated to comma-separated for display
STEPS_DISPLAY=$(echo "$STEPS" | tr '-' ', ')

# Build the done label
DONE_LABEL="${MODEL}-${STEPS}-done"

# Build the prompt
read -r -d '' PROMPT << 'PROMPT_END' || true
You are an autonomous agent working on Linear ticket ${CODE}.

## Your Task

1. First, use the Linear MCP tool to fetch the full details of issue ID: ${ID}
2. Read the ticket title, description, comments, and any linked documents
3. Execute the following steps in order: ${STEPS_DISPLAY}

## Step Definitions

- **research**: Investigate the codebase and gather relevant context. Search for related code, understand the architecture, and summarize your findings.
- **plan**: Based on research (yours or in comments), create a detailed implementation plan with specific files to modify and changes to make.
- **review**: Review the existing work, code, or plan. Provide constructive feedback and suggestions for improvement.

## Output Requirements

After completing ALL steps:
1. Add a comprehensive comment to the Linear ticket with your findings using Linear MCP
2. Format your comment with clear headers for each step completed
3. Be thorough but concise - focus on actionable insights

## Label Update (IMPORTANT)

When you have completed all steps and posted your comment, you MUST update the labels:
1. FIRST: Add the label "${DONE_LABEL}" to the issue
2. THEN: Remove the label "${LABEL}" from the issue

Use the Linear MCP tool to perform these label updates.

## Notes

- If you encounter any blockers or need clarification, note it clearly in your comment
- Do not implement code changes - only research, plan, and review
- Be specific when referencing code files and line numbers
PROMPT_END

# Substitute variables into the prompt
PROMPT=$(echo "$PROMPT" | sed "s/\${CODE}/$CODE/g" | sed "s/\${ID}/$ID/g" | sed "s/\${STEPS_DISPLAY}/$STEPS_DISPLAY/g" | sed "s/\${DONE_LABEL}/$DONE_LABEL/g" | sed "s/\${LABEL}/$LABEL/g")

echo "=== Executing Agent ==="
echo ""

# Execute the agent
if [ "$CLI_TYPE" = "claude" ]; then
    # Claude CLI
    $CLI_CMD -p "$PROMPT" --model "$CLI_MODEL" --dangerously-skip-permissions
else
    # Gemini CLI
    $CLI_CMD "$PROMPT" -m "$CLI_MODEL" -y
fi

EXIT_CODE=$?

echo ""
echo "=== Agent Completed ==="
echo "Exit code: $EXIT_CODE"
echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"

# Remove from seen file to allow re-triggering
TASK_KEY="${ID}:${LABEL}"
if [ -f "$SEEN_FILE" ]; then
    # Use temporary file for safe in-place edit
    grep -vF "$TASK_KEY" "$SEEN_FILE" > "$SEEN_FILE.tmp" 2>/dev/null || true
    mv "$SEEN_FILE.tmp" "$SEEN_FILE"
    echo "Removed from seen list (can be re-triggered with new *-todo label)"
fi

echo ""
echo "=== Worker Complete ==="
