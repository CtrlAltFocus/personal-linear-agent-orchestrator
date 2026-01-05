# Personal Linear Agent Orchestrator (PLAO)

A label-driven automation system for Linear. Add a label like `gemini-research-todo` to a ticket, and an AI agent will execute the work and post results back.

## Quick Start

```bash
# 1. Add bin/ to your PATH (or create alias)
export PATH="$PATH:/path/to/personal-linear-agent-orchestrator/bin"

# 2. Run setup
plao setup

# 3. Register your project
cd /path/to/your/project
plao add

# 4. Edit .plao.config.json with your Linear API key

# 5. Start the daemon
plao start
```

## Commands

```bash
plao help         # Show usage
plao setup        # Initialize pueue
plao add          # Register current directory
plao list         # Show registered projects
plao start        # Start polling daemon
plao stop         # Stop polling daemon
plao status       # Check status
plao logs         # Watch poller logs
plao follow <id>  # Follow task output
```

## Label Format

```
<model>-<steps>-<status>
```

Examples:
- `gemini-research-todo` - Gemini Flash does research
- `opus-plan-todo` - Claude Opus creates a plan
- `sonnet-review-todo` - Claude Sonnet reviews work

## Documentation

See [docs/README.md](docs/README.md) for full documentation.
