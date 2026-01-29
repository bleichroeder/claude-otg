#!/bin/bash
# Fix line endings
sed -i 's/\r$//' "$0"

# ═══════════════════════════════════════════════════════════════
# COLORS & UI HELPERS
# ═══════════════════════════════════════════════════════════════
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

LOG_FILE="/tmp/claude-otg-install.log"
> "$LOG_FILE"  # Clear log

TOTAL_STEPS=6
CURRENT_STEP=0

# Spinner animation for a running task
spin() {
    local msg="$1"
    local pid="$2"
    local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        echo -ne "\r  ${CYAN}${chars:$i:1}${NC} ${msg}"
        i=$(( (i+1) % ${#chars} ))
        sleep 0.08
    done
}

# Show step with spinner, run command in background
step() {
    local msg="$1"
    shift
    CURRENT_STEP=$((CURRENT_STEP + 1))

    # Run command in background, capture exit code
    "$@" >> "$LOG_FILE" 2>&1 &
    local pid=$!

    spin "[$CURRENT_STEP/$TOTAL_STEPS] $msg" "$pid"
    wait "$pid"
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo -e "\r  ${GREEN}✓${NC} [$CURRENT_STEP/$TOTAL_STEPS] $msg"
    else
        echo -e "\r  ${RED}✗${NC} [$CURRENT_STEP/$TOTAL_STEPS] $msg"
        echo ""
        echo -e "${RED}Error: Step failed. Check log: $LOG_FILE${NC}"
        exit 1
    fi
}

# Show step that's already done (skip)
step_skip() {
    local msg="$1"
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo -e "  ${DIM}○${NC} [$CURRENT_STEP/$TOTAL_STEPS] $msg ${DIM}(already installed)${NC}"
}

# Show header
clear
echo ""
echo -e "${CYAN}${BOLD}   ┌─────────────────────────────┐${NC}"
echo -e "${CYAN}${BOLD}   │  ◉  ${NC}${BOLD}CLAUDE─OTG${NC}  ${DIM}installer${NC}${CYAN}${BOLD}  │${NC}"
echo -e "${CYAN}${BOLD}   └─────────────────────────────┘${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════
# STEP 1: NODE.JS & NPM
# ═══════════════════════════════════════════════════════════════
# Load nvm first if it exists (so we can detect nvm-installed node)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

if ! command -v node &> /dev/null; then
    # Install nvm and Node.js
    step "Installing Node.js via nvm" bash -c '
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        nvm install --lts
    '
    # Reload nvm after install
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
else
    step_skip "Node.js"
fi

# ═══════════════════════════════════════════════════════════════
# STEP 2: CLAUDE CLI
# ═══════════════════════════════════════════════════════════════

if ! command -v claude &> /dev/null; then
    step "Installing Claude Code CLI" npm install -g @anthropic-ai/claude-code
else
    step_skip "Claude Code CLI"
fi

# ═══════════════════════════════════════════════════════════════
# STEP 3: QRENCODE
# ═══════════════════════════════════════════════════════════════
if ! command -v qrencode &> /dev/null; then
    step "Installing qrencode" bash -c 'sudo apt-get update -qq && sudo apt-get install -y -qq qrencode'
else
    step_skip "qrencode"
fi

# ═══════════════════════════════════════════════════════════════
# STEP 4: HELPER SCRIPTS
# ═══════════════════════════════════════════════════════════════
CURRENT_STEP=$((CURRENT_STEP + 1))

sudo mkdir -p /usr/local/share/claude-otg

sudo tee /usr/local/share/claude-otg/help.txt > /dev/null << 'EOF'
╔════════════════════════════════════════════════════════════╗
║              CLAUDE-OTG SHORTCUTS (Ctrl+A)                 ║
╠════════════════════════════════════════════════════════════╣
║  NAVIGATION              │  ACTIONS                        ║
║  1-9   Jump to window    │  S   Save to ~/claude_dump.md   ║
║  n/p   Next/Prev window  │  C   Copy last response         ║
║  w     Window list       │  m   Toggle mouse mode          ║
║  Tab   Last window       │  ?   Show this help             ║
╠════════════════════════════════════════════════════════════╣
║  SCROLLING               │  SESSION                        ║
║  [     Scroll mode (q)   │  d   Detach (keeps alive)       ║
║  PgUp  Page up           │  Q   Kill session & exit        ║
║  wheel Mouse scroll      │  $   Rename session             ║
╠════════════════════════════════════════════════════════════╣
║               Press 'q' to close                           ║
╚════════════════════════════════════════════════════════════╝
EOF

# 5. CREATE THE WELCOME SCRIPT
sudo tee /usr/local/share/claude-otg/welcome.sh > /dev/null << 'EOF'
#!/bin/bash
TUNNEL_NAME="${1:-my-claude-box}"
BLUE='\033[0;34m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

clear
echo ""
# Minimal banner
echo -e "${CYAN}${BOLD}   ┌─────────────────────────────┐${NC}"; sleep 0.03
echo -e "${CYAN}${BOLD}   │  ◉  ${NC}${BOLD}CLAUDE─OTG${NC}${CYAN}${BOLD}            │${NC}"; sleep 0.03
echo -e "${CYAN}${BOLD}   └─────────────────────────────┘${NC}"; sleep 0.05
echo ""

# QR Code for mobile access
TUNNEL_URL="https://vscode.dev/tunnel/${TUNNEL_NAME}"
if command -v qrencode &> /dev/null; then
    echo -e "  ${CYAN}Scan to connect:${NC}"
    echo ""
    qrencode -t ANSIUTF8 -m 1 "$TUNNEL_URL" | sed 's/^/  /'
    echo ""
fi
echo -e "  ${DIM}${TUNNEL_URL}${NC}"
echo ""
echo -e "  ${YELLOW}Quick Reference:${NC}"; sleep 0.03
echo -e "  ${DIM}──────────────────────────────────────────────────────${NC}"; sleep 0.02
echo -e "  ${BOLD}Ctrl+A ?${NC}     Show all shortcuts"; sleep 0.02
echo -e "  ${BOLD}Ctrl+A S${NC}     Save conversation to file"; sleep 0.02
echo -e "  ${BOLD}Ctrl+A d${NC}     Detach (session stays alive)"; sleep 0.02
echo -e "  ${BOLD}Ctrl+A Q${NC}     Kill session and exit"; sleep 0.02
echo -e "  ${DIM}──────────────────────────────────────────────────────${NC}"; sleep 0.05
echo ""

# Brief pause to read, then auto-start
sleep 1

# Loading animation then start
chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
for ((j=0; j<2; j++)); do
    for ((i=0; i<${#chars}; i++)); do
        echo -ne "\r  \033[0;36m${chars:$i:1} Starting Claude...\033[0m"
        sleep 0.06
    done
done
echo -e "\r  \033[0;32m✓\033[0m Starting Claude...    "
echo ""
EOF
sudo chmod +x /usr/local/share/claude-otg/welcome.sh

# 6. CREATE COPY-LAST-RESPONSE SCRIPT
sudo tee /usr/local/share/claude-otg/copy-response.sh > /dev/null << 'EOF'
#!/bin/bash
# Captures the pane content and extracts the last Claude response
TEMP_FILE=$(mktemp)
tmux capture-pane -p -S -500 > "$TEMP_FILE"

# Try to find the last response block (between prompts)
# This looks for content after the last ">" prompt indicator
RESPONSE=$(tac "$TEMP_FILE" | awk '
    /^[>$] / { if (found) exit; next }
    /^claude/ { if (found) exit; next }
    { found=1; lines[NR]=$0 }
    END { for (i=NR; i>=1; i--) print lines[i] }
')

if [ -n "$RESPONSE" ]; then
    echo "$RESPONSE" | tmux load-buffer -
    tmux display-message "Copied last response to tmux buffer (Prefix+] to paste)"
else
    tmux display-message "Could not find Claude response"
fi

rm "$TEMP_FILE"
EOF
sudo chmod +x /usr/local/share/claude-otg/copy-response.sh

# 7. CREATE GIT BRANCH SCRIPT FOR STATUS BAR
sudo tee /usr/local/share/claude-otg/git-status.sh > /dev/null << 'EOF'
#!/bin/bash
# Get git branch for current pane's directory
PANE_PATH=$(tmux display-message -p -F "#{pane_current_path}")
cd "$PANE_PATH" 2>/dev/null || exit

if git rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD)
    DIRTY=""
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        DIRTY="*"
    fi
    echo "#[fg=magenta]${BRANCH}${DIRTY}#[default]"
fi
EOF
sudo chmod +x /usr/local/share/claude-otg/git-status.sh

echo -e "  ${GREEN}✓${NC} [$CURRENT_STEP/$TOTAL_STEPS] Creating helper scripts"

# ═══════════════════════════════════════════════════════════════
# STEP 5: MAIN SCRIPT
# ═══════════════════════════════════════════════════════════════
CURRENT_STEP=$((CURRENT_STEP + 1))

sudo tee /usr/local/bin/claude-otg > /dev/null << 'EOF'
#!/bin/bash
SESSION_NAME="claude-otg"
TUNNEL_NAME="${CLAUDE_OTG_TUNNEL:-my-claude-box}"
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Animated spinner - usage: spinner "message" duration_loops
spinner() {
    local msg="$1"
    local loops="${2:-2}"
    local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    for ((j=0; j<loops; j++)); do
        for ((i=0; i<${#chars}; i++)); do
            echo -ne "\r${CYAN}${chars:$i:1}${NC} ${msg}"
            sleep 0.08
        done
    done
    echo -ne "\r${GREEN}✓${NC} ${msg}\n"
}

# Handle commands
if [ "$1" = "kill" ] || [ "$1" = "--kill" ]; then
    if tmux has-session -t $SESSION_NAME 2>/dev/null; then
        tmux kill-session -t $SESSION_NAME
        spinner "Terminating session" 2
    else
        echo -e "${YELLOW}No active session found.${NC}"
    fi
    exit 0
fi

if [ "$1" = "status" ] || [ "$1" = "--status" ]; then
    echo ""
    echo -e "${CYAN}${BOLD}Claude-OTG Status${NC}"
    echo -e "${DIM}─────────────────────────────────────${NC}"

    # Check tmux session
    if tmux has-session -t $SESSION_NAME 2>/dev/null; then
        WINDOWS=$(tmux list-windows -t $SESSION_NAME -F "#W" 2>/dev/null | wc -l)
        echo -e "  Session:  ${GREEN}● Running${NC} ($WINDOWS windows)"
    else
        echo -e "  Session:  ${DIM}○ Not running${NC}"
    fi

    # Check tunnel
    if pgrep -f "code tunnel" > /dev/null; then
        echo -e "  Tunnel:   ${GREEN}● Running${NC}"
    else
        echo -e "  Tunnel:   ${DIM}○ Not running${NC}"
    fi

    # Check auth status
    AUTH_FILE="$HOME/.claude-otg-tunnel-auth"
    if [ -f "$AUTH_FILE" ]; then
        echo -e "  Auth:     ${GREEN}● Authenticated${NC}"
    else
        echo -e "  Auth:     ${YELLOW}○ Not authenticated${NC}"
        echo ""
        echo -e "  ${DIM}Run 'claude-otg --tunnel' to authenticate${NC}"
    fi

    echo ""
    echo -e "  Tunnel URL: ${BLUE}https://vscode.dev/tunnel/${TUNNEL_NAME}${NC}"
    echo ""
    exit 0
fi

if [ "$1" = "tunnel" ] || [ "$1" = "--tunnel" ]; then
    echo ""
    echo -e "${CYAN}${BOLD}VS Code Tunnel Setup${NC}"
    echo -e "${DIM}─────────────────────────────────────${NC}"
    echo ""

    # Kill any existing tunnel
    pkill -f "code tunnel" 2>/dev/null
    sleep 1

    # Remove auth marker to force re-auth
    rm -f "$HOME/.claude-otg-tunnel-auth"

    # Find or download VS Code CLI
    CODE_DIR="/usr/local/share/claude-otg"
    CODE_CMD=""
    CODE_PATH=$(command -v code)
    if [[ "$CODE_PATH" == *"/mnt/c/"* ]] || [ -z "$CODE_PATH" ]; then
        if [ ! -f "$CODE_DIR/code" ]; then
            echo -e "${YELLOW}Downloading VS Code CLI...${NC}"
            curl -Lk 'https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64' --output /tmp/vscode_cli.tar.gz
            sudo tar -xf /tmp/vscode_cli.tar.gz -C "$CODE_DIR" && rm -f /tmp/vscode_cli.tar.gz
        fi
        CODE_CMD="$CODE_DIR/code"
    else
        CODE_CMD="code"
    fi

    TUNNEL_LOG="/tmp/claude-otg-tunnel.log"
    > "$TUNNEL_LOG"

    echo -ne "${CYAN}⠋${NC} Starting tunnel..."
    $CODE_CMD tunnel --name "$TUNNEL_NAME" --accept-server-license-terms >> "$TUNNEL_LOG" 2>&1 &
    TUNNEL_PID=$!

    # Wait for tunnel to stabilize or show auth prompt
    AUTH_SHOWN=false
    for i in {1..20}; do
        sleep 0.5

        # Check if process died
        if ! kill -0 $TUNNEL_PID 2>/dev/null; then
            echo -e "\r${RED}✗${NC} Tunnel process exited                          "
            echo ""
            cat "$TUNNEL_LOG"
            exit 1
        fi

        # Check for GitHub auth prompt
        if [ "$AUTH_SHOWN" = false ] && grep -q "github.com/login/device" "$TUNNEL_LOG" 2>/dev/null; then
            AUTH_CODE=$(grep -Eo '[A-Z0-9]{4}-[A-Z0-9]{4}' "$TUNNEL_LOG" 2>/dev/null | head -1)
            echo -e "\r                                                      "
            echo ""
            echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${YELLOW}║  GitHub Authentication Required                            ║${NC}"
            echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
            echo ""
            echo -e "  1. Open:  ${CYAN}https://github.com/login/device${NC}"
            if [ -n "$AUTH_CODE" ]; then
                echo -e "  2. Enter: ${GREEN}${BOLD}$AUTH_CODE${NC}"
            else
                echo -e "  2. Code: ${DIM}cat $TUNNEL_LOG${NC}"
            fi
            echo ""
            AUTH_SHOWN=true

            # Wait for auth - check log size to detect activity
            LOG_SIZE=$(wc -c < "$TUNNEL_LOG" 2>/dev/null || echo 0)
            echo -ne "${CYAN}⠋${NC} Waiting for authentication..."
            for j in {1..90}; do
                sleep 1
                if ! kill -0 $TUNNEL_PID 2>/dev/null; then
                    echo -e "\r${RED}✗${NC} Tunnel exited during auth                     "
                    cat "$TUNNEL_LOG"
                    exit 1
                fi
                # Check if log grew (indicates auth completed)
                NEW_SIZE=$(wc -c < "$TUNNEL_LOG" 2>/dev/null || echo 0)
                if [ "$NEW_SIZE" -gt "$LOG_SIZE" ]; then
                    if ! tail -5 "$TUNNEL_LOG" 2>/dev/null | grep -q "github.com/login/device"; then
                        touch "$HOME/.claude-otg-tunnel-auth"
                        echo -e "\r${GREEN}✓${NC} Tunnel authenticated                          "
                        echo ""
                        echo -e "Tunnel URL: ${BLUE}https://vscode.dev/tunnel/${TUNNEL_NAME}${NC}"
                        echo ""
                        exit 0
                    fi
                    LOG_SIZE=$NEW_SIZE
                fi
                chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
                echo -ne "\r${CYAN}${chars:$((j % 10)):1}${NC} Waiting for authentication..."
            done
            # Timeout but still running = probably ok
            if kill -0 $TUNNEL_PID 2>/dev/null; then
                touch "$HOME/.claude-otg-tunnel-auth"
                echo -e "\r${GREEN}✓${NC} Tunnel running                                  "
                echo ""
                echo -e "Tunnel URL: ${BLUE}https://vscode.dev/tunnel/${TUNNEL_NAME}${NC}"
                exit 0
            fi
        fi

        chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
        echo -ne "\r${CYAN}${chars:$((i % 10)):1}${NC} Starting tunnel..."
    done

    # If process is still running, success
    if kill -0 $TUNNEL_PID 2>/dev/null; then
        touch "$HOME/.claude-otg-tunnel-auth"
        echo -e "\r${GREEN}✓${NC} Tunnel running                                  "
        echo ""
        echo -e "Tunnel URL: ${BLUE}https://vscode.dev/tunnel/${TUNNEL_NAME}${NC}"
        echo ""
        echo -e "${DIM}Tunnel is running in background. Use 'claude-otg' to start a session.${NC}"
    else
        echo -e "\r${RED}✗${NC} Tunnel failed to stay running                  "
        cat "$TUNNEL_LOG"
        exit 1
    fi
    exit 0
fi

# Allow tunnel name override via argument (only if not a command)
if [ -n "$1" ] && [[ "$1" != -* ]]; then TUNNEL_NAME="$1"; fi

# Load nvm if installed (in case Node.js was installed via nvm)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Check for claude CLI
if ! command -v claude &> /dev/null; then
    echo -e "${RED}ERROR: 'claude' CLI not found.${NC}"
    echo "Install it with: npm install -g @anthropic-ai/claude-code"
    exit 1
fi

IN_VSCODE=false
if [ -n "$VSCODE_IPC_HOOK_CLI" ] || [[ "$TERM_PROGRAM" == "vscode" ]]; then IN_VSCODE=true; fi

if ! command -v tmux &> /dev/null; then
    echo -e "${YELLOW}Installing tmux...${NC}"; sudo apt update && sudo apt install -y tmux
fi

# Apply tmux configuration
CONF=~/.tmux.conf

# Remove old config if exists (for clean updates)
if [ -f $CONF ] && grep -q "claude-otg-config" $CONF; then
    echo -e "${YELLOW}Updating Claude-OTG tmux configuration...${NC}"
    sed -i '/# --- claude-otg-config ---/,/# --- end-claude-otg-config ---/d' $CONF
else
    echo -e "${YELLOW}Applying Claude-OTG tmux configuration...${NC}"
fi

cat >> $CONF << 'TMUXCONF'
# --- claude-otg-config ---

# ═══════════════════════════════════════════════════════════
# PREFIX KEY - Changed to Ctrl+A (easier on mobile)
# ═══════════════════════════════════════════════════════════
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# ═══════════════════════════════════════════════════════════
# GENERAL SETTINGS
# ═══════════════════════════════════════════════════════════
set -g mouse on
set -g history-limit 50000
set -g display-time 2000
set -g status-interval 5
set -g focus-events on
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
setw -g aggressive-resize on

# Visual bell (useful for mobile - flash instead of beep)
set -g visual-bell on
set -g visual-activity on
setw -g monitor-activity on

# ═══════════════════════════════════════════════════════════
# COLOR THEME - Optimized for mobile readability
# ═══════════════════════════════════════════════════════════
# Status bar
set -g status-style 'bg=#1a1a2e,fg=#eaeaea'
set -g status-left-length 40
set -g status-right-length 80

# Status left: session name
set -g status-left '#[fg=#00d9ff,bold] #S #[fg=#444]|'

# Status right: git branch + time
set -g status-right '#(bash /usr/local/share/claude-otg/git-status.sh) #[fg=#444]|#[fg=#00ff88] %I:%M %p #[fg=#444]|#[fg=#ffcc00] %m/%d '

# Window status
set -g window-status-format ' #[fg=#888]#I:#W '
set -g window-status-current-format '#[fg=#1a1a2e,bg=#00d9ff,bold] #I:#W '
set -g window-status-activity-style 'fg=#ffcc00,bold'
set -g window-status-separator ''

# Pane borders
set -g pane-border-style 'fg=#333333'
set -g pane-active-border-style 'fg=#00d9ff'

# Message styling
set -g message-style 'bg=#00d9ff,fg=#1a1a2e,bold'

# ═══════════════════════════════════════════════════════════
# KEY BINDINGS
# ═══════════════════════════════════════════════════════════

# Help menu
bind ? display-popup -w 64 -h 18 -E "less -cKQ /usr/local/share/claude-otg/help.txt"

# Save pane to file
bind S capture-pane -S - \; save-buffer ~/claude_dump.md \; display-message "Saved to ~/claude_dump.md"

# Copy last Claude response
bind C run-shell "bash /usr/local/share/claude-otg/copy-response.sh"

# Toggle mouse
bind m set -g mouse \; display-message "Mouse: #{?mouse,ON,OFF}"

# Reload config
bind r source-file ~/.tmux.conf \; display-message "Config reloaded"

# Quick window navigation
bind Tab last-window

# Split panes (more intuitive keys)
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# Easy pane navigation
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Page up/down in copy mode
bind -n PageUp copy-mode -u
bind -n PageDown send-keys PageDown

# Quick window creation in current directory
bind c new-window -c "#{pane_current_path}"

# Kill session and exit
bind Q confirm-before -p "Kill session and exit? (y/n)" "kill-session"

# ═══════════════════════════════════════════════════════════
# COPY MODE IMPROVEMENTS
# ═══════════════════════════════════════════════════════════
setw -g mode-keys vi
bind -T copy-mode-vi v send-keys -X begin-selection
bind -T copy-mode-vi y send-keys -X copy-selection-and-cancel

# --- end-claude-otg-config ---
TMUXCONF

# Reload if tmux is running
if pgrep tmux >/dev/null; then
    tmux source-file $CONF 2>/dev/null
    echo -e "${GREEN}Configuration applied to running tmux.${NC}"
fi

# Handle VS Code tunnel
AUTH_FILE="$HOME/.claude-otg-tunnel-auth"
TUNNEL_LOG="/tmp/claude-otg-tunnel.log"

if [ "$IN_VSCODE" = true ]; then
    echo -e "${GREEN}✓ VS Code Terminal detected${NC}"
else
    # Find or download VS Code CLI (to fixed location, not current dir)
    CODE_DIR="/usr/local/share/claude-otg"
    CODE_CMD=""
    CODE_PATH=$(command -v code)
    if [[ "$CODE_PATH" == *"/mnt/c/"* ]] || [ -z "$CODE_PATH" ]; then
        if [ ! -f "$CODE_DIR/code" ]; then
            echo -e "${YELLOW}Downloading VS Code CLI...${NC}"
            if ! curl -Lk 'https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64' --output /tmp/vscode_cli.tar.gz 2>/dev/null; then
                echo -e "${RED}ERROR: Failed to download VS Code CLI.${NC}"
                exit 1
            fi
            sudo tar -xf /tmp/vscode_cli.tar.gz -C "$CODE_DIR" && rm -f /tmp/vscode_cli.tar.gz
        fi
        CODE_CMD="$CODE_DIR/code"
    else
        CODE_CMD="code"
    fi

    # Start tunnel if not running
    if ! pgrep -f "code tunnel" > /dev/null; then
        > "$TUNNEL_LOG"  # Clear log

        echo -ne "${CYAN}⠋${NC} Starting tunnel..."

        # Start tunnel, capture both stdout and stderr
        $CODE_CMD tunnel --name "$TUNNEL_NAME" --accept-server-license-terms >> "$TUNNEL_LOG" 2>&1 &
        TUNNEL_PID=$!

        # Wait for tunnel to stabilize or show auth prompt
        AUTH_SHOWN=false
        for i in {1..20}; do
            sleep 0.5

            # Check if process died (bad sign)
            if ! kill -0 $TUNNEL_PID 2>/dev/null; then
                echo -e "\r${RED}✗${NC} Tunnel process exited                         "
                echo ""
                cat "$TUNNEL_LOG"
                echo ""
                rm -f "$AUTH_FILE"
                echo -e "${YELLOW}Try: claude-otg --tunnel${NC}"
                exit 1
            fi

            # Check for GitHub auth prompt
            if [ "$AUTH_SHOWN" = false ] && grep -q "github.com/login/device" "$TUNNEL_LOG" 2>/dev/null; then
                AUTH_CODE=$(grep -Eo '[A-Z0-9]{4}-[A-Z0-9]{4}' "$TUNNEL_LOG" 2>/dev/null | head -1)
                echo -e "\r                                                      "
                echo ""
                echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${YELLOW}║  GitHub Authentication Required                            ║${NC}"
                echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
                echo ""
                echo -e "  1. Open:  ${CYAN}https://github.com/login/device${NC}"
                if [ -n "$AUTH_CODE" ]; then
                    echo -e "  2. Enter: ${GREEN}${BOLD}$AUTH_CODE${NC}"
                else
                    echo -e "  2. Code: ${DIM}cat $TUNNEL_LOG${NC}"
                fi
                echo ""
                AUTH_SHOWN=true

                # Wait for auth - check log size to detect activity after auth
                LOG_SIZE=$(wc -c < "$TUNNEL_LOG" 2>/dev/null || echo 0)
                echo -ne "${CYAN}⠋${NC} Waiting for authentication..."
                for j in {1..90}; do
                    sleep 1
                    if ! kill -0 $TUNNEL_PID 2>/dev/null; then
                        echo -e "\r${RED}✗${NC} Tunnel exited during auth                     "
                        cat "$TUNNEL_LOG"
                        exit 1
                    fi
                    # Check if log grew (indicates auth completed and tunnel is doing stuff)
                    NEW_SIZE=$(wc -c < "$TUNNEL_LOG" 2>/dev/null || echo 0)
                    if [ "$NEW_SIZE" -gt "$LOG_SIZE" ]; then
                        # Log grew, check if it's not just more auth prompts
                        if ! tail -5 "$TUNNEL_LOG" 2>/dev/null | grep -q "github.com/login/device"; then
                            touch "$AUTH_FILE"
                            echo -e "\r${GREEN}✓${NC} Tunnel authenticated                          "
                            break 2  # Break out of both loops
                        fi
                        LOG_SIZE=$NEW_SIZE
                    fi
                    chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
                    echo -ne "\r${CYAN}${chars:$((j % 10)):1}${NC} Waiting for authentication..."
                done
                # If we get here without breaking, assume timeout but process running = success
                if kill -0 $TUNNEL_PID 2>/dev/null; then
                    touch "$AUTH_FILE"
                    echo -e "\r${GREEN}✓${NC} Tunnel running (auth may have completed)      "
                fi
                break
            fi

            # Animate spinner
            chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
            echo -ne "\r${CYAN}${chars:$((i % 10)):1}${NC} Starting tunnel..."
        done

        # If process is still running after initial wait, consider it success
        if kill -0 $TUNNEL_PID 2>/dev/null; then
            if [ "$AUTH_SHOWN" = false ]; then
                echo -e "\r${GREEN}✓${NC} Tunnel started                                "
                touch "$AUTH_FILE"
            fi
        fi
    else
        echo -e "${GREEN}✓${NC} Tunnel already running"
    fi
fi

# Don't nest tmux sessions
if [ -n "$TMUX" ]; then
    echo -e "${YELLOW}Already inside session!${NC}"
    exit 0
fi

CURRENT_DIR=$(pwd)
PROJECT_NAME=$(basename "$CURRENT_DIR")
IS_HOME=false
if [[ "$CURRENT_DIR" == "$HOME" ]]; then IS_HOME=true; fi

# Session management
if tmux has-session -t $SESSION_NAME 2>/dev/null; then
    if [ "$IS_HOME" = true ]; then
        spinner "Reconnecting to session" 2
        # Show session info on reconnect
        echo ""
        echo -e "${BLUE}Active windows:${NC}"
        tmux list-windows -t $SESSION_NAME -F "  #I: #W #{?window_active,(active),}" 2>/dev/null
        echo ""
        sleep 0.5
        tmux attach -t $SESSION_NAME
    else
        spinner "Opening project '${PROJECT_NAME}'" 2
        tmux new-window -t $SESSION_NAME -n "$PROJECT_NAME" -c "$CURRENT_DIR" "claude"
        tmux attach -t $SESSION_NAME
    fi
else
    spinner "Creating new AI Session" 2
    # New session: show welcome screen first, then start claude
    tmux new-session -d -s $SESSION_NAME -n "$PROJECT_NAME" -c "$CURRENT_DIR"
    tmux send-keys -t $SESSION_NAME "bash /usr/local/share/claude-otg/welcome.sh '$TUNNEL_NAME' && claude" Enter
    tmux attach -t $SESSION_NAME
fi
EOF

sudo chmod +x /usr/local/bin/claude-otg

echo -e "  ${GREEN}✓${NC} [$CURRENT_STEP/$TOTAL_STEPS] Installing claude-otg command"

# ═══════════════════════════════════════════════════════════════
# STEP 6: FINALIZE
# ═══════════════════════════════════════════════════════════════
CURRENT_STEP=$((CURRENT_STEP + 1))
echo -e "  ${GREEN}✓${NC} [$CURRENT_STEP/$TOTAL_STEPS] Installation complete"

echo ""
echo -e "${GREEN}${BOLD}   ┌─────────────────────────────┐${NC}"
echo -e "${GREEN}${BOLD}   │  ✓  ${NC}${BOLD}Ready to go${NC}${GREEN}${BOLD}            │${NC}"
echo -e "${GREEN}${BOLD}   └─────────────────────────────┘${NC}"
echo ""
echo -e "  ${CYAN}Commands:${NC}"
echo -e "    ${BOLD}claude-otg${NC}              Start session"
echo -e "    ${BOLD}claude-otg my-tunnel${NC}   Custom tunnel name"
echo -e "    ${BOLD}claude-otg --status${NC}    Check tunnel & session"
echo -e "    ${BOLD}claude-otg --tunnel${NC}    Re-authenticate tunnel"
echo -e "    ${BOLD}claude-otg --kill${NC}      Kill session"
echo ""
echo -e "  ${CYAN}Quick Start:${NC}"
echo -e "    1. Run ${BOLD}claude-otg${NC} from any project directory"
echo -e "    2. Scan QR code with your phone"
echo -e "    3. Press ${BOLD}Ctrl+A ?${NC} for all shortcuts"
echo ""
echo -e "  ${DIM}Log file: $LOG_FILE${NC}"
echo ""
