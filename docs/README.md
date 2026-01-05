# Personal Linear Agent Orchestrator (PLAO)

A label-driven automation system that watches Linear tickets for special labels, dispatches work to AI agents (Gemini or Claude), and posts results back to Linear.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         YOUR LAPTOP                             │
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐  │
│  │ plao daemon  │───▶│    pueue     │───▶│   plao-worker    │  │
│  │  (polling)   │    │  (task queue)│    │                  │  │
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

## Quick Start

```bash
# 1. Run setup
plao setup

# 2. Register your project
cd /path/to/your/project
plao add

# 3. Configure .plao.config.json (created automatically)
# Add your Linear API key and teams to watch

# 4. Start the daemon
plao start

# 5. Add a label to a Linear ticket
# e.g., "gemini-research-todo" on any ticket
```

## CLI Commands

| Command | Description |
|---------|-------------|
| `plao help` | Show help and usage |
| `plao setup` | Install dependencies, initialize pueue |
| `plao add [path]` | Register a project (default: current directory) |
| `plao list` | List all registered projects |
| `plao remove [path]` | Unregister a project |
| `plao start` | Start the polling daemon |
| `plao stop` | Stop the polling daemon |
| `plao status` | Show daemon and queue status |
| `plao logs` | Tail the poller logs |
| `plao follow <id>` | Follow a task's output (wraps `pueue follow`) |

## Configuration

### Global Config (`~/.plao/config.json`)

Controls daemon behavior. Created automatically with defaults on first run.

```json
{
  "poll_interval_seconds": 60,
  "log_max_lines": 10000
}
```

| Field | Default | Description |
|-------|---------|-------------|
| `poll_interval_seconds` | 60 | How often to check Linear for new tasks |
| `log_max_lines` | 10000 | Max lines in poller.log before rotation (truncates to 50%) |

**Note:** Changes require daemon restart: `plao stop && plao start`

### Project Config (`.plao.config.json`)

Each registered project has a `.plao.config.json` file in its root:

```json
{
  "linear_api_key": "lin_api_xxxxx",
  "teams": ["Product", "Engineering"]
}
```

| Field | Description |
|-------|-------------|
| `linear_api_key` | Your Linear API key (Settings → API → Personal API keys) |
| `teams` | Array of Linear team names to watch for *-todo labels |

**Note:** `.plao.config.json` is automatically added to `.gitignore` since it contains your API key.

## Label Grammar

Labels act as commands. The system parses them to determine which model to use and which steps to execute.

```
<model>-<step1>[-<step2>...][-<stepN>]-<status>
```

### Examples

| Label | Model | Steps | Status |
|-------|-------|-------|--------|
| `gemini-research-todo` | Gemini Flash | research | todo |
| `opus-research-plan-todo` | Claude Opus | research, plan | todo |
| `sonnet-review-todo` | Claude Sonnet | review | todo |

### Models

| Label Prefix | CLI | Model |
|--------------|-----|-------|
| `gemini` / `geminiflash` | gemini | gemini-3-flash-preview |
| `geminipro` | gemini | gemini-3-pro-preview |
| `opus` / `claude` | claude | opus |
| `sonnet` | claude | sonnet |

### Steps

| Step | Description |
|------|-------------|
| `research` | Investigate codebase, gather context, summarize findings |
| `plan` | Create implementation plan based on research |
| `review` | Review existing code/comments/plan, provide feedback |

### Status

| Status | Meaning |
|--------|---------|
| `todo` | Ready to be picked up by the system |
| `wip` | Currently being processed |
| `done` | Completed |

## File Structure

```
~/.plao/
├── config.json         # Global config (poll interval, log limits)
├── projects.txt        # List of registered project paths
├── seen_tasks.txt      # Deduplication tracking
├── plao.pid            # Daemon PID file
├── poller.log          # Poller output (auto-rotated)
└── logs/               # Individual task logs

/your/project/
└── .plao.config.json   # Project-specific config (API key, teams)
```

## Monitoring

```bash
# Check daemon and queue status
plao status

# Watch the poller logs
plao logs

# Follow a specific task's output
plao follow <task_id>

# View individual task logs
tail -f ~/.plao/logs/*.log

# Watch pueue queue directly (alternative)
watch -n 2 'pueue status --group plao'
```

## Prerequisites

- [pueue](https://github.com/Nukesor/pueue) - Task queue manager
- [jq](https://jqlang.github.io/jq/) - JSON processor
- `claude` CLI - Authenticated and configured with Linear MCP
- `gemini` CLI - Authenticated and configured with Linear MCP

Install with:
```bash
brew install pueue jq
```

## Troubleshooting

### Tasks not being picked up

1. Check daemon is running: `plao status`
2. Check project config: `plao list`
3. Verify API key is valid in `.plao.config.json`
4. Check team names match exactly (case-sensitive)
5. View logs: `plao logs`
6. Check `~/.plao/seen_tasks.txt` for duplicates

### Agent errors

1. Check task logs: `~/.plao/logs/<CODE>-*.log`
2. Verify Linear MCP is configured: `claude mcp list` and `gemini mcp`
3. Check pueue: `pueue status --group plao`

### Daemon issues

```bash
# Restart the daemon
plao stop
plao start

# Reset pueue
pueue kill
pueued -d
pueue group add plao
```

## Roadmap

### Milestone 1 (Complete)
- [x] CLI with start/stop daemon
- [x] Per-project configuration
- [x] Steps: research, plan, review
- [x] pueue integration
- [x] Configurable poll interval
- [x] Log rotation with watermarks

### Milestone 2 (Future)
- [ ] `implement` step with git worktrees
- [ ] `test` step with test runner integration
- [ ] PR creation via GitHub MCP
- [ ] Label whitelist/blacklist in config
