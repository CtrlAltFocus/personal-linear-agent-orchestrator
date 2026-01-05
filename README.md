# Personal Linear Agent Orchestrator (PLAO)

A label-driven automation system for Linear. Add a label like `gemini-research-todo` to a ticket, and an AI agent will execute the work and post results back.

## What It Does

- Watches your Linear tickets for labels ending in `-todo`
- Dispatches work to AI agents (Gemini or Claude CLI)
- Posts results back as comments on the ticket
- Updates labels automatically (`-todo` → `-done`)

## Who It's For

Developers who want to automate repetitive ticket work like:
- **Research** - investigating codebases, gathering context
- **Planning** - creating implementation plans
- **Review** - reviewing code, PRs, or documentation

## Installation

```bash
# 1. Clone or download
git clone https://github.com/yourusername/personal-linear-agent-orchestrator.git

# 2. Add to PATH
echo 'export PATH="$PATH:/path/to/personal-linear-agent-orchestrator/bin"' >> ~/.zshrc
source ~/.zshrc

# 3. Install dependencies
brew install pueue jq

# 4. Run setup
plao setup

# 5. Register a project and configure
cd /path/to/your/project
plao add
# Edit .plao.config.json with your Linear API key

# 6. Start
plao start
```

## Daily Usage

Once installed, just add labels to your Linear tickets:

1. **Create a ticket** in Linear (or use an existing one)
2. **Add a label** like `gemini-research-todo`
3. **Wait a few minutes** - PLAO polls every 60 seconds by default
4. **Get notified** - Linear notifies you when a comment is added
5. **Review the results** - the AI's work appears as a comment, label changes to `-done`

### Example Workflow

```
Ticket: "Investigate why auth tokens expire early"

You add label:        gemini-research-todo
  ↓ (1-2 min)
PLAO posts comment:   [Research findings about token expiration...]
Label changes to:     gemini-research-done

You read research, then add:  opus-plan-todo
  ↓ (2-5 min)
PLAO posts comment:   [Implementation plan with steps...]
Label changes to:     opus-plan-done
```

### Available Labels

| Label | What it does |
|-------|--------------|
| `gemini-research-todo` | Fast research with Gemini Flash |
| `opus-research-todo` | Deep research with Claude Opus |
| `opus-plan-todo` | Create implementation plan |
| `sonnet-review-todo` | Review code or documentation |

## CLI Commands

```bash
plao help      # Show all commands
plao status    # Check daemon and queue
plao logs      # Watch activity
```

## Documentation

See [docs/README.md](docs/README.md) for how it works, configuration options, and troubleshooting.

## Contributing

This is a personal project, but forks and contributions are welcome. Feel free to open issues or PRs.
