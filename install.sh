#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Agentico Installer -- macOS & Linux
# Supports both: curl -fsSL https://raw.githubusercontent.com/Ser-GY/agentico/main/install.sh | bash
#            and: ./install.sh  (from a cloned repo)
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config"
CONFIG_FILE="$CONFIG_DIR/agents-projects.json"

GITHUB_REPO="Ser-GY/agentico"
GITHUB_BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}"

print_header() {
    echo ""
    echo -e "${CYAN}${BOLD}  ═══════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}     AGENTICO -- Multi-Agent Development Environment ${NC}"
    echo -e "${CYAN}${BOLD}  ═══════════════════════════════════════════════════${NC}"
    echo ""
}

info()    { echo -e "  ${CYAN}[INFO]${NC} $1"; }
success() { echo -e "  ${GREEN}[OK]${NC}   $1"; }
warn()    { echo -e "  ${YELLOW}[WARN]${NC} $1"; }
fail()    { echo -e "  ${RED}[FAIL]${NC} $1"; exit 1; }

# ─── Detect OS ────────────────────────────────────────────────────────────────

detect_os() {
    case "$(uname -s)" in
        Darwin*) OS="macos" ;;
        Linux*)  OS="linux" ;;
        *)       fail "Unsupported operating system: $(uname -s). Agentic requires macOS or Linux." ;;
    esac
    info "Detected OS: $OS"
}

# ─── Detect Package Manager ───────────────────────────────────────────────────

detect_pkg_manager() {
    if [ "$OS" = "macos" ]; then
        if command -v brew &>/dev/null; then
            PKG_MANAGER="brew"
        else
            PKG_MANAGER="none"
        fi
        return
    fi

    # Linux: probe in order of prevalence
    if   command -v apt-get &>/dev/null; then PKG_MANAGER="apt"
    elif command -v dnf     &>/dev/null; then PKG_MANAGER="dnf"
    elif command -v yum     &>/dev/null; then PKG_MANAGER="yum"
    elif command -v pacman  &>/dev/null; then PKG_MANAGER="pacman"
    elif command -v zypper  &>/dev/null; then PKG_MANAGER="zypper"
    elif command -v apk     &>/dev/null; then PKG_MANAGER="apk"
    else                                      PKG_MANAGER="unknown"
    fi
    info "Detected package manager: $PKG_MANAGER"
}

# Return the right install command for a given package name
pkg_hint() {
    local pkg="$1"
    case "$PKG_MANAGER" in
        brew)    echo "brew install $pkg" ;;
        apt)     echo "sudo apt install $pkg" ;;
        dnf)     echo "sudo dnf install $pkg" ;;
        yum)     echo "sudo yum install $pkg" ;;
        pacman)  echo "sudo pacman -S $pkg" ;;
        zypper)  echo "sudo zypper install $pkg" ;;
        apk)     echo "sudo apk add $pkg" ;;
        none)    echo "install Homebrew first: https://brew.sh — then: brew install $pkg" ;;
        *)       echo "install $pkg via your system package manager" ;;
    esac
}

# Return the command to install multiple packages at once
pkg_hint_multi() {
    local pkgs="$*"
    case "$PKG_MANAGER" in
        brew)    echo "brew install $pkgs" ;;
        apt)     echo "sudo apt install $pkgs" ;;
        dnf)     echo "sudo dnf install $pkgs" ;;
        yum)     echo "sudo yum install $pkgs" ;;
        pacman)  echo "sudo pacman -S $pkgs" ;;
        zypper)  echo "sudo zypper install $pkgs" ;;
        apk)     echo "sudo apk add $pkgs" ;;
        *)       echo "" ;;
    esac
}

# ─── Check Dependencies ──────────────────────────────────────────────────────

check_dependency() {
    local cmd="$1"
    local name="$2"
    local install_hint="$3"

    if command -v "$cmd" &>/dev/null; then
        success "$name is installed"
        return 0
    else
        warn "$name is not installed"
        echo -e "    ${GRAY}Install with: ${install_hint}${NC}"
        return 1
    fi
}

check_dependencies() {
    info "Checking dependencies..."
    echo ""

    local missing=0
    local missing_pkgs=()

    # tmux
    if ! check_dependency tmux "tmux" "$(pkg_hint tmux)"; then
        missing=1; missing_pkgs+=(tmux)
    fi

    # jq
    if ! check_dependency jq "jq" "$(pkg_hint jq)"; then
        missing=1; missing_pkgs+=(jq)
    fi

    # git — on macOS, Xcode CLT is the canonical path even if brew is present
    local git_hint
    if [ "$OS" = "macos" ]; then
        git_hint="xcode-select --install"
    else
        git_hint="$(pkg_hint git)"
    fi
    if ! check_dependency git "git" "$git_hint"; then
        missing=1
        [ "$OS" != "macos" ] && missing_pkgs+=(git)
    fi

    # curl
    if ! check_dependency curl "curl" "$(pkg_hint curl)"; then
        missing=1; missing_pkgs+=(curl)
    fi

    # Claude CLI — npm, not a system package
    if ! check_dependency claude "Claude CLI" \
        "npm install -g @anthropic-ai/claude-code  (requires Claude Pro subscription)"; then
        missing=1
    fi

    echo ""

    if [ "$missing" -eq 1 ]; then
        # If multiple system packages are missing, print a ready-to-paste one-liner
        if [ "${#missing_pkgs[@]}" -gt 1 ]; then
            local one_liner
            one_liner="$(pkg_hint_multi "${missing_pkgs[@]}")"
            if [ -n "$one_liner" ]; then
                echo -e "  ${CYAN}Install all missing packages at once:${NC}"
                echo -e "    ${BOLD}$one_liner${NC}"
                echo ""
            fi
        fi

        warn "Some dependencies are missing. Install them and re-run this script."
        # In pipe mode (curl | bash), stdin is not a TTY — skip interactive prompt and continue
        if [ -t 0 ]; then
            echo ""
            read -p "  Continue anyway? (y/N) " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        else
            warn "Running non-interactively -- continuing with available dependencies"
        fi
    fi
}

# ─── Find Script Source Directory (local clone) ───────────────────────────────

find_scripts_dir() {
    # BASH_SOURCE[0] is empty or /dev/stdin when piped via curl | bash
    local script_path="${BASH_SOURCE[0]:-}"
    if [ -n "$script_path" ] && [ "$script_path" != "/dev/stdin" ] && [ -f "$script_path" ]; then
        local script_dir
        script_dir="$(cd "$(dirname "$script_path")" && pwd)"
        if [ -d "$script_dir/scripts" ]; then
            SCRIPTS_DIR="$script_dir/scripts"
            TEMPLATES_DIR="$script_dir/templates"
            INSTALL_MODE="local"
            info "Installing from local clone: $script_dir"
            return 0
        fi
    fi
    # Fall back to remote download
    INSTALL_MODE="remote"
    info "Installing from GitHub: ${GITHUB_REPO}@${GITHUB_BRANCH}"
}

# ─── Download a file from GitHub ─────────────────────────────────────────────

download_file() {
    local remote_path="$1"
    local dest="$2"
    local url="${RAW_BASE}/${remote_path}"

    if curl -fsSL "$url" -o "$dest"; then
        return 0
    else
        warn "Failed to download: $url"
        return 1
    fi
}

# ─── Install Scripts ─────────────────────────────────────────────────────────

install_scripts() {
    info "Installing scripts to $INSTALL_DIR/ ..."
    mkdir -p "$INSTALL_DIR"

    if [ "$INSTALL_MODE" = "local" ]; then
        # Local mode: copy from cloned repo
        local scripts=(
            "agentico"
            "agentico-stats"
            "agentico-session-stats"
            "agentico-pane-stats"
            "agentico-relay"
            "agentico-relay-status"
            "agentico-bulletin-write"
            "agentico-skill-write"
            "agentico-watcher"
        )
        for script in "${scripts[@]}"; do
            if [ -f "$SCRIPTS_DIR/$script" ]; then
                cp "$SCRIPTS_DIR/$script" "$INSTALL_DIR/$script"
                chmod +x "$INSTALL_DIR/$script"
                success "Installed $script"
            else
                warn "Script not found: $script (skipping)"
            fi
        done
    else
        # Remote mode: download compiled binaries from latest GitHub release
        info "Downloading binaries from latest release..."
        if [ "$OS" = "macos" ]; then
            local RELEASE_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/agentico-macos-arm64.tar.gz"
        else
            local RELEASE_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/agentico-linux.tar.gz"
        fi
        local TEMP_DIR=$(mktemp -d)
        local TARBALL="$TEMP_DIR/agentico.tar.gz"

        if curl -fsSL "$RELEASE_URL" -o "$TARBALL" 2>/dev/null; then
            tar -xzf "$TARBALL" -C "$TEMP_DIR"
            for bin in "$TEMP_DIR"/*; do
                local name=$(basename "$bin")
                if [ "$name" != "agentic.tar.gz" ] && [ -f "$bin" ]; then
                    cp "$bin" "$INSTALL_DIR/$name"
                    chmod +x "$INSTALL_DIR/$name"
                    success "Installed $name"
                fi
            done
            rm -rf "$TEMP_DIR"
        else
            fail "Could not download release. Check your internet connection."
        fi
    fi

    # Ensure PATH is set in ALL relevant shell profiles (fixes "command not found" on fresh installs)
    # Use grep-based shell detection so /usr/bin/zsh, /usr/bin/bash, etc. are all caught.
    local path_line='export PATH="$HOME/.local/bin:$PATH"'
    local profiles_updated=0

    if echo "${SHELL:-}" | grep -q "zsh" || [ -f "$HOME/.zshrc" ] || [ -f "$HOME/.zprofile" ]; then
        # Add to .zprofile (login shells — new Terminal windows)
        if ! grep -q '\.local/bin' "$HOME/.zprofile" 2>/dev/null; then
            echo "$path_line" >> "$HOME/.zprofile"
            profiles_updated=1
        fi
        # Add to .zshrc (interactive shells — subshells, tmux panes)
        if ! grep -q '\.local/bin' "$HOME/.zshrc" 2>/dev/null; then
            echo "$path_line" >> "$HOME/.zshrc"
            profiles_updated=1
        fi
    fi

    if echo "${SHELL:-}" | grep -q "bash" || [ -f "$HOME/.bashrc" ] || [ -f "$HOME/.bash_profile" ]; then
        if ! grep -q '\.local/bin' "$HOME/.bashrc" 2>/dev/null; then
            echo "$path_line" >> "$HOME/.bashrc"
            profiles_updated=1
        fi
        if ! grep -q '\.local/bin' "$HOME/.bash_profile" 2>/dev/null; then
            echo "$path_line" >> "$HOME/.bash_profile"
            profiles_updated=1
        fi
    fi

    # Fallback for other shells (fish, dash, etc.): update ~/.profile
    if ! echo "${SHELL:-}" | grep -qE "(zsh|bash)" && \
       [ ! -f "$HOME/.zshrc" ] && [ ! -f "$HOME/.zprofile" ] && \
       [ ! -f "$HOME/.bashrc" ] && [ ! -f "$HOME/.bash_profile" ]; then
        if ! grep -q '\.local/bin' "$HOME/.profile" 2>/dev/null; then
            echo "$path_line" >> "$HOME/.profile"
            profiles_updated=1
        fi
    fi

    if [ "$profiles_updated" -eq 1 ]; then
        success "Added PATH entry to shell profiles"
    elif [[ ":$PATH:" == *":$INSTALL_DIR:"* ]]; then
        success "PATH already configured"
    fi

    # Source for this session
    export PATH="$HOME/.local/bin:$PATH"
}

# ─── Install Config ──────────────────────────────────────────────────────────

install_config() {
    mkdir -p "$CONFIG_DIR"

    if [ -f "$CONFIG_FILE" ]; then
        info "Config already exists at $CONFIG_FILE (not overwriting)"
        return
    fi

    local config_written=0

    if [ "$INSTALL_MODE" = "local" ] && [ -f "$TEMPLATES_DIR/agents-projects.json" ]; then
        cp "$TEMPLATES_DIR/agents-projects.json" "$CONFIG_FILE"
        config_written=1
    elif [ "$INSTALL_MODE" = "remote" ]; then
        if download_file "templates/agents-projects.json" "$CONFIG_FILE"; then
            config_written=1
        fi
    fi

    if [ "$config_written" -eq 1 ]; then
        success "Created config at $CONFIG_FILE"
    else
        # Fallback: write minimal inline config
        cat > "$CONFIG_FILE" << 'EOF'
{
  "projects": [],
  "settings": {
    "slow_mode": false,
    "dangerous_mode": true,
    "auto_relay": true,
    "solo_mode": false,
    "multi_projects": ""
  }
}
EOF
        success "Created default config at $CONFIG_FILE"
    fi

    # Create agentico-config.json for cost tracker display
    if [ ! -f "$CONFIG_DIR/agentico-config.json" ]; then
        cat > "$CONFIG_DIR/agentico-config.json" << 'EOF'
{
  "show_token_stats": true
}
EOF
        success "Enabled cost tracker display"
    fi

    # Create initial metrics file so cost calculator shows from first launch
    if [ ! -f "$CONFIG_DIR/agentico-metrics.json" ]; then
        echo '{}' > "$CONFIG_DIR/agentico-metrics.json"
    fi
}

# ─── Install tmux Config ─────────────────────────────────────────────────────

install_tmux_config() {
    if [ -f "$HOME/.tmux.conf" ]; then
        info "tmux config already exists at ~/.tmux.conf (not overwriting)"
        echo -e "    ${GRAY}See templates/tmux.conf for recommended settings${NC}"
        return
    fi

    local tmux_conf_written=0

    if [ "$INSTALL_MODE" = "local" ] && [ -f "$TEMPLATES_DIR/tmux.conf" ]; then
        cp "$TEMPLATES_DIR/tmux.conf" "$HOME/.tmux.conf"
        tmux_conf_written=1
    elif [ "$INSTALL_MODE" = "remote" ]; then
        if download_file "templates/tmux.conf" "$HOME/.tmux.conf"; then
            tmux_conf_written=1
        fi
    fi

    if [ "$tmux_conf_written" -eq 1 ]; then
        success "Installed tmux config to ~/.tmux.conf"
    fi
}

# ─── Configure Claude Code for TeamCreate ────────────────────────────────────

configure_claude_settings() {
    local claude_dir="$HOME/.claude"
    local settings_file="$claude_dir/settings.json"
    local hook_script="$claude_dir/hooks/capture-tokens.sh"

    mkdir -p "$claude_dir/hooks"

    # Install capture-tokens hook if not already present.
    # Priority: (1) compiled binary from INSTALL_DIR, (2) shell script from templates.
    if [ ! -f "$hook_script" ]; then
        if [ -f "$INSTALL_DIR/agentico-capture-tokens" ]; then
            cp "$INSTALL_DIR/agentico-capture-tokens" "$hook_script"
            chmod +x "$hook_script"
        elif [ "$INSTALL_MODE" = "local" ] && [ -f "$TEMPLATES_DIR/hooks/capture-tokens.sh" ]; then
            cp "$TEMPLATES_DIR/hooks/capture-tokens.sh" "$hook_script"
            chmod +x "$hook_script"
        elif [ "$INSTALL_MODE" = "remote" ]; then
            if download_file "templates/hooks/capture-tokens.sh" "$hook_script"; then
                chmod +x "$hook_script"
            fi
        fi
    fi

    # Build the desired settings with teammateMode and Stop hook
    local needs_update=false

    if [ ! -f "$settings_file" ]; then
        echo '{}' > "$settings_file"
        needs_update=true
    fi

    # Check all required fields
    if ! jq -e '.teammateMode' "$settings_file" &>/dev/null; then needs_update=true; fi
    if ! jq -e '.hooks.Stop' "$settings_file" &>/dev/null; then needs_update=true; fi
    if ! jq -e '.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' "$settings_file" &>/dev/null; then needs_update=true; fi
    if ! jq -e '.skipDangerousModePermissionPrompt' "$settings_file" &>/dev/null; then needs_update=true; fi
    if ! jq -e '.statusLine' "$settings_file" &>/dev/null; then needs_update=true; fi

    if [ "$needs_update" = true ]; then
        local tmp_file
        tmp_file=$(mktemp)
        local status_cmd='input=$(cat); model=$(echo \"$input\" | jq -r '"'"'.model.display_name // \"Claude\"'"'"'); remaining=$(echo \"$input\" | jq -r '"'"'.context_window.remaining_percentage // empty'"'"'); time=$(date +\"%H:%M:%S\"); date=$(date \"+%b %d\"); if [ -n \"$remaining\" ]; then r=$(printf \"%.0f\" \"$remaining\"); if [ \"$r\" -gt 50 ] 2>/dev/null; then ctx=$(printf \"\\033[32m%s%%\\033[0m\" \"$r\"); elif [ \"$r\" -gt 20 ] 2>/dev/null; then ctx=$(printf \"\\033[33m%s%%\\033[0m\" \"$r\"); else ctx=$(printf \"\\033[31m%s%%\\033[0m\" \"$r\"); fi; else ctx=\"\\033[2m--\\033[0m\"; fi; printf \"\\033[36m%s\\033[0m \\033[2m|\\033[0m %s \\033[2m|\\033[0m \\033[34m%s\\033[0m \\033[2m%s\\033[0m\" \"$model\" \"$ctx\" \"$time\" \"$date\"'
        jq --arg hook "$hook_script" --arg statuscmd "$status_cmd" '
            .teammateMode = "tmux" |
            .theme = "dark" |
            .skipDangerousModePermissionPrompt = true |
            .env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1" |
            .statusLine //= {"type": "command", "command": $statuscmd} |
            .hooks.Stop //= [{"hooks": [{"type": "command", "command": $hook}]}] |
            if (.hooks.Stop | map(.hooks[]? | select(.command == $hook)) | length) == 0
            then .hooks.Stop += [{"hooks": [{"type": "command", "command": $hook}]}]
            else . end
        ' "$settings_file" > "$tmp_file" && mv "$tmp_file" "$settings_file"
        success "Agent teams, status line, and token capture configured"
    else
        success "All settings already configured"
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    print_header
    detect_os
    detect_pkg_manager
    find_scripts_dir
    echo ""
    check_dependencies
    echo ""
    install_scripts
    echo ""
    install_config
    echo ""
    install_tmux_config
    echo ""
    configure_claude_settings
    echo ""

    echo -e "${GREEN}${BOLD}  ═══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}     Installation Complete                          ${NC}"
    echo -e "${GREEN}${BOLD}  ═══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${BOLD}Next steps:${NC}"
    echo ""
    echo -e "  Just run:"
    echo -e "     ${CYAN}agentico${NC}"
    echo ""
    echo -e "  The built-in menu will guide you through creating your first project."
    echo ""
    echo -e "  ${GRAY}Documentation: https://github.com/${GITHUB_REPO}${NC}"
    echo ""
}

main "$@"
