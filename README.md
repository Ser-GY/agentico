# Agentic

**Multi-agent development that builds while you watch.**

One command. Multiple AI agents. All working in parallel on your project — visible in real time.

---

## What It Does

- You describe what you want built
- Agentic breaks it into tasks and assigns them to specialist agents
- Every agent works simultaneously in its own environment
- You watch them build, then review the result

---

## Install

**macOS / Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/EliCrossDev/agentic/main/install.sh | bash
```

**Requirements:** Node.js 18+, Claude CLI (`npm install -g @anthropic-ai/claude-code`), tmux, jq

### Linux prerequisites

Install the required system packages before running the installer:

**Debian / Ubuntu:**
```bash
sudo apt update && sudo apt install -y tmux jq git curl
```

**RHEL / CentOS / Fedora:**
```bash
# dnf (Fedora, RHEL 8+, CentOS Stream)
sudo dnf install -y tmux jq git curl

# yum (RHEL 7 / CentOS 7)
sudo yum install -y tmux jq git curl
```

**Other distros:** install `tmux`, `jq`, `git`, and `curl` via your package manager, then re-run the installer.

---

## Usage

```bash
agentic
```

Select a project from the menu and go.

---

## Support

For help, open an issue on this repo.

---

## License

Proprietary. All rights reserved. See [LICENSE](LICENSE) for details.
