# Personal Linear Agent Orchestrator (PLAO)

A label-driven automation system that watches Linear tickets for special labels, dispatches work to AI agents (Gemini or Claude), and posts results back to Linear.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         YOUR LAPTOP                             │
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐  │
│  │   Poller     │───▶│    pueue     │───▶│  Worker Script   │  │
│  │  (cron/loop) │    │  (task queue)│    │                  │  │
│  └──────────────┘    └──────────────┘    │  ┌────────────┐  │  │
│         │                                │  │ claude -p  │  │  │
│         │ Linear API                     │  │ gemini     │  │  │
│         │ (GraphQL)                      │  └────────────┘  │  │
│         ▼                                │        │         │  │
│  ┌──────────────┐                        │        ▼         │  │
│  │ Fetch issues │                        │  Linear MCP      │  │
│  │ with *-todo  │                        │  (update ticket) │  │
│  │ labels       │                        └──────────────────┘  │
│  └──────────────┘                                              │
└─────────────────────────────────────────────────────────────────┘
```

The poller uses the Linear GraphQL API directly (no AI calls) to efficiently check for new tasks every minute.

## Label Grammar

Labels act as commands. The system parses them to determine which model to use, which steps to execute, and the current status.

```
<model>-<step1>[-<step2>...][-<stepN>]-<status>
```

### Examples

| Label | Model | Steps | Status |
|-------|-------|-------|--------|
| `gemini-research-todo` | Gemini Flash | research | todo |
| `opus-research-plan-todo` | Claude Opus | research, plan | todo |
| `sonnet-review-todo` | Claude Sonnet | review | todo |
| `geminipro-plan-implement-test-todo` | Gemini Pro | plan, implement, test | todo |

### Models

| Label Prefix | CLI | Model |
|--------------|-----|-------|
| `gemini` | gemini | gemini-3-flash-preview |
| `geminiflash` | gemini | gemini-3-flash-preview |
| `geminipro` | gemini | gemini-3-pro-preview |
| `opus` | claude | opus |
| `sonnet` | claude | sonnet |
| `claude` | claude | opus |

### Steps

| Step | Description |
|------|-------------|
| `research` | Investigate codebase, gather context, summarize findings |
| `plan` | Create implementation plan based on research |
| `review` | Review existing code/comments/plan, provide feedback |
| `implement` | Write code (Milestone 2) |
| `test` | Run and verify tests (Milestone 2) |

### Status

| Status | Meaning |
|--------|---------|
| `todo` | Ready to be picked up by the system |
| `wip` | Currently being processed |
| `done` | Completed |

## Setup

### Prerequisites

- [pueue](https://github.com/Nukesor/pueue) - Task queue manager
- [jq](https://jqlang.github.io/jq/) - JSON processor
- `claude` CLI - Authenticated and configured with Linear MCP
- `gemini` CLI - Authenticated and configured with Linear MCP
- **Linear API key** - For the poller to query tickets

### Installation

1. **Get a Linear API key:**

   - Go to Linear → Settings → API → Personal API keys
   - Create a new key and add to your shell profile:

   ```bash
   # Add to ~/.zshrc or ~/.bashrc
   export PLAO_LINEAR_API_KEY="lin_api_xxxxx"
   ```

2. **Install dependencies:**

   ```bash
   # pueue
   brew install pueue
   # or: cargo install pueue

   # jq
   brew install jq
   ```

3. **Run the setup script:**

   ```bash
   ./bin/setup.sh
   ```

   This will:
   - Create `~/.plao/` directory for logs and state
   - Initialize pueue daemon
   - Create the `plao` task group
   - Display the cron entry to add

4. **Add to cron (or run as loop):**

   ```bash
   # Via cron (every minute)
   * * * * * /path/to/bin/poller.sh >> ~/.plao/poller.log 2>&1

   # Or run as a loop
   while true; do ./bin/poller.sh; sleep 60; done
   ```

## Usage

### Basic Workflow

1. Create a Linear ticket in the Product team
2. Add a label like `gemini-research-todo`
3. Wait for the poller to pick it up (runs every 60 seconds)
4. The agent will:
   - Fetch the ticket details
   - Execute the requested steps
   - Post results as a comment
   - Update label to `gemini-research-done`

### Monitoring

```bash
# Watch the queue status
watch -n 2 'pueue status --group plao'

# Follow a specific task's output
pueue follow <task_id>

# View recent logs
tail -f ~/.plao/logs/*.log

# View poller log
tail -f ~/.plao/poller.log
```

### Manual Task Execution

You can manually run the worker for testing:

```bash
./bin/worker.sh "<issue-uuid>" "PROJ-123" "gemini-research-todo"
```

## File Structure

```
personal-linear-agent-orchestrator/
├── README.md           # Brief overview
├── docs/
│   └── README.md       # This file (full documentation)
├── bin/
│   ├── setup.sh        # One-time setup script
│   ├── poller.sh       # Finds work, enqueues to pueue
│   └── worker.sh       # Executes AI work
└── .gitignore
```

## Configuration

### Data Directory

All runtime data is stored in `~/.plao/`:

```
~/.plao/
├── seen_tasks.txt      # Deduplication tracking
├── poller.log          # Poller output
└── logs/               # Individual task logs
    └── PROJ-123-20240105-143022.log
```

### pueue Settings

The system uses a dedicated pueue group `plao` with 2 concurrent workers:

```bash
# Adjust concurrency
pueue parallel 3 --group plao

# Pause the queue
pueue pause --group plao

# Resume the queue
pueue start --group plao
```

## Troubleshooting

### Tasks not being picked up

1. Check if `PLAO_LINEAR_API_KEY` is set: `echo $PLAO_LINEAR_API_KEY`
2. Check if the poller is running: `tail -f ~/.plao/poller.log`
3. Verify the label matches the pattern `*-todo`
4. Ensure the ticket is in the Product team
5. Check `~/.plao/seen_tasks.txt` for duplicates

### Agent errors

1. Check the task log: `~/.plao/logs/PROJ-123-*.log`
2. Verify Linear MCP is configured: `claude mcp list` and `gemini mcp`
3. Test manually with the worker script

### pueue issues

```bash
# Restart pueue daemon
pueue kill
pueued -d

# Reset failed tasks
pueue reset --group plao
```

## Roadmap

### Milestone 1 (Current)
- [x] Poller script
- [x] Worker script
- [x] Steps: research, plan, review
- [x] pueue integration

### Milestone 2 (Future)
- [ ] `implement` step with git worktrees
- [ ] `test` step with test runner integration
- [ ] PR creation via GitHub MCP
- [ ] Branch management with `par` CLI
