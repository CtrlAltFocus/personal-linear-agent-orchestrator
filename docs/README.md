# PLAO Documentation

> **Note:** Tested on macOS only. Linux should work but is untested.

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

## How It Works

```
┌─────────┐          ┌─────────┐          ┌─────────┐          ┌─────────┐
│   You   │          │ Linear  │          │  PLAO   │          │ AI CLI  │
└────┬────┘          └────┬────┘          └────┬────┘          └────┬────┘
     │                    │                    │                    │
     │ Create ticket      │                    │                    │
     │ "Investigate auth" │                    │                    │
     ├───────────────────>│                    │                    │
     │                    │                    │                    │
     │ Add label          │                    │                    │
     │ gemini-research-todo                    │                    │
     ├───────────────────>│                    │                    │
     │                    │                    │                    │
     │                    │  Poll (every 60s)  │                    │
     │                    │<───────────────────┤                    │
     │                    │                    │                    │
     │                    │  Found ticket!     │                    │
     │                    ├───────────────────>│                    │
     │                    │                    │                    │
     │                    │                    │ Run gemini         │
     │                    │                    │ with prompt        │
     │                    │                    ├───────────────────>│
     │                    │                    │                    │
     │                    │                    │    Research done   │
     │                    │                    │<───────────────────┤
     │                    │                    │                    │
     │                    │  Add comment       │                    │
     │                    │<───────────────────┤                    │
     │                    │                    │                    │
     │                    │  Update labels:    │                    │
     │                    │  +gemini-research-done                  │
     │                    │  -gemini-research-todo                  │
     │                    │<───────────────────┤                    │
     │                    │                    │                    │
     │ Notification:      │                    │                    │
     │ "Comment added"    │                    │                    │
     │<───────────────────┤                    │                    │
     │                    │                    │                    │
     │ Read research,     │                    │                    │
     │ add label          │                    │                    │
     │ opus-plan-todo     │                    │                    │
     ├───────────────────>│                    │                    │
     │                    │                    │                    │
     │                    │  Poll              │                    │
     │                    │<───────────────────┤                    │
     │                    │                    │                    │
     │                    │                    │ Run claude         │
     │                    │                    │ with prompt        │
     │                    │                    ├───────────────────>│
     │                    │                    │                    │
     │                    │                    │    Plan done       │
     │                    │                    │<───────────────────┤
     │                    │                    │                    │
     │                    │  Add comment       │                    │
     │                    │  +opus-plan-done   │                    │
     │                    │  -opus-plan-todo   │                    │
     │                    │<───────────────────┤                    │
     │                    │                    │                    │
     │ Notification:      │                    │                    │
     │ "Comment added"    │                    │                    │
     │<───────────────────┤                    │                    │
     │                    │                    │                    │
     ▼                    ▼                    ▼                    ▼
```

### Summary

1. **Polling**: The daemon polls Linear every N seconds (default: 60) for tickets with `*-todo` labels
2. **Filtering**: Only tickets from teams listed in your project's config are processed
3. **Queuing**: Matching tickets are added to a pueue task queue (group: `plao`)
4. **Execution**: The worker parses the label, invokes the appropriate CLI (gemini/claude), and runs in your project directory
5. **Completion**: Results are posted as comments, labels updated (`-todo` → `-done`)

## Running the Daemon

There are two ways to run PLAO:

### Manual (start/stop)

```bash
plao start   # Start daemon in background
plao stop    # Stop the daemon
```

The daemon runs as a background process. Stops when you log out or reboot.

### Auto-start on Login

Two simple options to start PLAO automatically when you log in:

#### Option A: Shell Profile (simplest)

Add to `~/.zprofile`:

```bash
# Start PLAO if not already running
pgrep -qf "plao-poll" || /path/to/plao start
```

**Pros:** One line, no setup.
**Cons:** Only starts when you open Terminal (which most developers do anyway).

#### Option B: Automator App (true login start)

1. Open **Automator** → New → **Application**
2. Add action: **Run Shell Script**
3. Paste the **full path** (required!):
   ```bash
   /full/path/to/personal-linear-agent-orchestrator/bin/plao start
   ```
4. Save as `PLAO.app` (e.g., to `~/Applications/`)
5. Go to **System Settings → General → Login Items** → add `PLAO.app`

**Pros:** Starts immediately on login, no Terminal needed.
**Cons:** Requires one-time Automator setup.

**Important:** You must use the full absolute path to `plao` (e.g., `/Users/you/Projects/.../bin/plao`). Automator runs without your shell's PATH, so `plao` alone won't work.

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
- [x] launchd install/uninstall for auto-start

### Milestone 2 (Future)
- [ ] `implement` step with git worktrees
- [ ] `test` step with test runner integration
- [ ] PR creation via GitHub MCP
- [ ] Label whitelist/blacklist in config
