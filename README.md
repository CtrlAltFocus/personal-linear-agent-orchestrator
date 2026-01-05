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

## Usage

```bash
plao help      # Show all commands
plao status    # Check daemon and queue
plao logs      # Watch activity
```

Add labels to Linear tickets: `gemini-research-todo`, `opus-plan-todo`, `sonnet-review-todo`

## Documentation

See [docs/README.md](docs/README.md) for how it works, configuration options, and troubleshooting.

## Contributing

This is a personal project, but forks and contributions are welcome. Feel free to open issues or PRs.
