# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PLAO (Personal Linear Agent Orchestrator) is a label-driven automation system for Linear. Users add labels like `gemini-research-todo` to Linear tickets, and AI agents (Gemini CLI or Claude CLI) execute the work and post results back as comments.

## Architecture

Three bash scripts in `bin/`:

- **plao** - Main CLI entrypoint. Handles commands: `start`, `stop`, `status`, `add`, `remove`, `list`, `logs`, `follow`, `setup`
- **plao-poll** - Runs once per poll cycle. Queries Linear GraphQL API for tickets with `*-todo` labels, filters by team, queues work via pueue
- **plao-worker** - Executes a single task. Parses label grammar, invokes appropriate AI CLI (gemini/claude), posts results back to Linear via MCP

Data flow: `plao start` → spawns daemon running `plao-poll` every N seconds → `plao-poll` finds tickets → queues `plao-worker` tasks via pueue → worker invokes AI CLI → AI uses Linear MCP to post results

## Key Files

```
~/.plao/
├── config.json       # Global config (poll_interval_seconds, log_max_lines)
├── projects.txt      # Registered project paths (one per line)
├── seen_tasks.txt    # Deduplication: "ISSUE_ID:LABEL" entries
├── plao.pid          # Daemon PID
└── poller.log        # Poller output (auto-rotates)

/project/.plao.config.json  # Per-project: linear_api_key, teams[]
```

## Label Grammar

```
<model>-<step1>[-<step2>...]-<status>
```

- Models: `gemini`/`geminiflash`, `geminipro`, `opus`/`claude`, `sonnet`
- Steps: `research`, `plan`, `review`
- Status: `todo` (triggers work), `wip`, `done`

Example: `opus-research-plan-todo` → Claude Opus runs research then plan steps

## Commands

```bash
plao setup              # Initialize pueue group
plao add [path]         # Register project (creates .plao.config.json template)
plao start              # Start daemon
plao stop               # Stop daemon (also shuts down pueue if idle)
plao status             # Show daemon + pueue status
plao logs               # Tail poller.log
plao follow <id>        # Follow pueue task output
```

## Dependencies

- `pueue` - Task queue manager (brew install pueue)
- `jq` - JSON parsing (brew install jq)
- `gemini` or `claude` CLI - AI agents with Linear MCP configured

## Testing Changes

No test suite. Manual testing:

1. `plao stop && plao start` to restart daemon
2. Add a `*-todo` label to a Linear ticket in a registered project's team
3. `plao logs` to watch for pickup
4. `plao follow <id>` to watch task execution

## macOS Notes

- Worker sources `~/.zshrc` to get PATH (nvm, homebrew paths)
- For Automator/Login Items auto-start, must use full absolute path to `plao`
