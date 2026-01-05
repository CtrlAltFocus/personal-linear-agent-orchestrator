# Personal Linear Agent Orchestrator (PLAO)

A label-driven automation system for Linear. Add a label like `gemini-research-todo` to a ticket, and an AI agent will execute the work and post results back.

## Quick Start

```bash
# 1. Run setup
./bin/setup.sh

# 2. Add to cron (or run as loop)
* * * * * /path/to/bin/poller.sh >> ~/.plao/poller.log 2>&1

# 3. Add a label to a Linear ticket
# e.g., "opus-plan-todo" on ticket PROJ-123
```

## Label Format

```
<model>-<steps>-<status>
```

Examples:
- `gemini-research-todo` - Gemini Flash does research
- `opus-plan-implement-todo` - Claude Opus plans then implements
- `sonnet-review-todo` - Claude Sonnet reviews existing work

## Documentation

See [docs/README.md](docs/README.md) for full documentation.
