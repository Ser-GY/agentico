# Agentico

**Run multiple AI agents in parallel — each working on a different part of your project at the same time.**

Agentico is a shell-based orchestration layer for [Claude Code](https://claude.ai/code). You describe what you want built, and Agentico spins up a tmux session where multiple Claude agents work simultaneously, each in its own terminal pane, each on its own task. You watch them build in real time.

---

## What It Does

- Launches a configurable number of Claude Code agents in a tmux session
- Each agent runs in its own isolated pane and receives its own instructions
- A coordinator agent (the "relay") can pass messages between agents and route work
- Token usage and cost are tracked automatically after each agent response
- A live status line shows the active model, context window usage, and current time

Think of it as a development team where every member is an AI — all working in parallel, all visible at once.

---

## How It Works

1. You configure a project in `~/.config/agents-projects.json` — giving it a name, a path, and a prompt that describes the work
2. You run `agentico` and pick your project from the menu
3. Agentico creates a new tmux session and opens panes for each agent
4. Each pane starts a Claude Code instance with the configured prompt and settings
5. The relay agent watches for inter-agent messages and routes them
6. A hook fires after every Claude response to capture token/cost metrics
7. You interact with the agents directly inside each pane, or let them run autonomously

---

## Requirements

| Tool | Purpose | Install |
|------|---------|---------|
| [Node.js 18+](https://nodejs.org) | Required by Claude CLI | See nodejs.org |
| [Claude Code CLI](https://claude.ai/code) | The AI engine | `npm install -g @anthropic-ai/claude-code` |
| [tmux](https://github.com/tmux/tmux) | Terminal multiplexer for multi-pane layout | See below |
| [jq](https://stedolan.github.io/jq/) | JSON processing for config and metrics | See below |
| git | Version control | Usually pre-installed |
| curl | Downloading files | Usually pre-installed |

A **Claude Pro subscription** (or API key) is required to use Claude Code.

---

## Installation

### macOS

Install prerequisites with Homebrew:

```bash
brew install tmux jq
```

Then install Agentico:

```bash
curl -fsSL https://raw.githubusercontent.com/Ser-GY/agentico/main/install.sh | bash
```

### Linux

Install prerequisites first, then run the installer.

**Debian / Ubuntu:**
```bash
sudo apt update && sudo apt install -y tmux jq git curl
curl -fsSL https://raw.githubusercontent.com/Ser-GY/agentico/main/install.sh | bash
```

**Fedora / RHEL 8+ / CentOS Stream:**
```bash
sudo dnf install -y tmux jq git curl
curl -fsSL https://raw.githubusercontent.com/Ser-GY/agentico/main/install.sh | bash
```

**RHEL 7 / CentOS 7:**
```bash
sudo yum install -y tmux jq git curl
curl -fsSL https://raw.githubusercontent.com/Ser-GY/agentico/main/install.sh | bash
```

**Arch Linux:**
```bash
sudo pacman -S tmux jq git curl
curl -fsSL https://raw.githubusercontent.com/Ser-GY/agentico/main/install.sh | bash
```

### What the installer does

- Detects your OS and package manager
- Checks for required dependencies and tells you exactly how to install any that are missing
- Downloads the Agentico binaries to `~/.local/bin/`
- Adds `~/.local/bin` to your `$PATH` in the appropriate shell profile
- Creates the default config file at `~/.config/agents-projects.json`
- Installs a recommended tmux config at `~/.tmux.conf` (only if one doesn't already exist)
- Configures Claude Code's `~/.claude/settings.json` to enable agent teams, the status line, and the token-capture hook

### From a local clone

If you've cloned the repo, you can run the installer directly:

```bash
git clone https://github.com/Ser-GY/agentico.git
cd agentico
./install.sh
```

---

## Quick Start / Configuration

After installation, open `~/.config/agents-projects.json` in any editor. This is where you define your projects.

### Minimal example

```json
{
  "projects": [
    {
      "name": "My App",
      "path": "/Users/you/my-app",
      "prompt": "You are working on a Node.js REST API. Build the feature described in TODO.md."
    }
  ],
  "settings": {
    "slow_mode": false,
    "dangerous_mode": true,
    "auto_relay": true,
    "solo_mode": false,
    "multi_projects": ""
  }
}
```

### Project fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Display name shown in the project menu |
| `path` | Yes | Absolute path to the project directory where agents will work |
| `prompt` | Yes | The initial instructions given to each agent when it starts |

### Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `slow_mode` | `false` | Adds a delay between agent actions (useful for debugging) |
| `dangerous_mode` | `true` | Skips Claude's permission prompts so agents can run without interruption |
| `auto_relay` | `true` | Automatically starts the relay agent for inter-agent communication |
| `solo_mode` | `false` | Launches a single agent instead of the full multi-agent team |
| `multi_projects` | `""` | Comma-separated list of project names to run simultaneously |

---

## Usage

After installation, open a new terminal (so the updated `$PATH` takes effect) and run:

```bash
agentico
```

You'll see a menu listing your configured projects. Select one and the tmux session launches immediately.

Inside the session:
- Each pane is an independent Claude Code agent
- You can type into any pane to give that agent additional instructions
- Use standard tmux navigation to move between panes (`Ctrl+a` then arrow keys, with the installed tmux config)
- To detach from the session without stopping it: `Ctrl+a d`
- To reattach later: `tmux attach -t agentico`

---

## CLI Options

```bash
agentico [OPTIONS]
```

| Flag | Description |
|------|-------------|
| `--help` | Show usage information |
| `--version` | Print the installed version |
| `--list` | List all configured projects without launching |
| `--project <name>` | Launch a specific project by name, skipping the menu |
| `--solo` | Launch in single-agent mode regardless of config |

---

## Companion Scripts

Agentico installs several helper binaries alongside the main `agentico` command. All are placed in `~/.local/bin/`.

### `agentico-stats`
Prints a summary of token usage and estimated cost across all agents in the current session. Reads from `~/.config/agentico-metrics.json`.

```bash
agentico-stats
```

### `agentico-session-stats`
Like `agentico-stats` but scoped to a specific tmux session. Useful when running multiple sessions simultaneously.

```bash
agentico-session-stats <session-name>
```

### `agentico-pane-stats`
Shows per-pane token and cost breakdown for the active tmux session. Lets you see which agent is consuming the most context.

```bash
agentico-pane-stats
```

### `agentico-relay`
The inter-agent message router. Normally started automatically when `auto_relay` is enabled. You can start it manually if needed.

```bash
agentico-relay
```

### `agentico-relay-status`
Shows whether the relay agent is running and how many messages it has routed.

```bash
agentico-relay-status
```

### `agentico-bulletin-write`
Writes a message to the shared bulletin board — a file that all agents can read. Useful for broadcasting context or status to the whole team.

```bash
agentico-bulletin-write "Feature X is complete. All agents can proceed to integration."
```

### `agentico-skill-write`
Adds a reusable skill (a short instruction block) to the shared skills file. Agents can reference these skills by name in their prompts.

```bash
agentico-skill-write "run-tests" "Run the test suite with: npm test. Fix any failures before continuing."
```

### `agentico-watcher`
Monitors the project directory for file changes and can trigger agent actions when files are modified. Useful for continuous-feedback workflows.

```bash
agentico-watcher
```

---

## Token Tracking & Cost Display

Agentico includes a token capture hook (`~/.claude/hooks/capture-tokens.sh`) that runs automatically after every Claude response. It writes token counts and cost estimates to `~/.config/agentic-metrics.json`.

The status bar at the bottom of each Claude pane shows:
- The active model name
- Remaining context window (color-coded: green > 50%, yellow > 20%, red below)
- Current time and date

To disable the cost tracker display, set `"show_token_stats": false` in `~/.config/agentico-config.json`.

---

## tmux Configuration

The installer places a recommended tmux config at `~/.tmux.conf`. Key bindings:

| Shortcut | Action |
|----------|--------|
| `Ctrl+a` | Prefix key (replaces default `Ctrl+b`) |
| `Ctrl+a d` | Detach from session |
| `Ctrl+a arrow` | Move between panes |
| `Alt+1` through `Alt+4` | Switch to window 1–4 |
| Mouse click | Focus a pane or window |
| Mouse scroll | Scroll pane output |

If you already have a `~/.tmux.conf`, the installer will not overwrite it. You can review the recommended settings in `templates/tmux.conf`.

---

## Troubleshooting

**`agentico: command not found` after installation**

The installer adds `~/.local/bin` to your PATH. Open a new terminal window or run:
```bash
source ~/.zshrc    # zsh
source ~/.bashrc   # bash
```

**Agents are waiting for permission prompts**

Make sure `dangerous_mode` is set to `true` in your project config, and that `skipDangerousModePermissionPrompt` is set in `~/.claude/settings.json`. The installer sets this automatically.

**tmux session won't start**

Verify tmux is installed: `tmux -V`. If the command isn't found, install it with your package manager (see Requirements).

**`jq: command not found`**

jq is required for config parsing. Install it:
- macOS: `brew install jq`
- Ubuntu/Debian: `sudo apt install jq`
- Fedora/RHEL: `sudo dnf install jq`

**Claude CLI isn't authenticated**

Run `claude` in your terminal and follow the login prompts. You need a Claude Pro subscription or an Anthropic API key.

**Token metrics not updating**

Check that the hook is installed and executable:
```bash
ls -la ~/.claude/hooks/capture-tokens.sh
```
If missing, re-run the installer to restore it.

---

## License

Proprietary. All rights reserved. See [LICENSE](LICENSE) for details.
