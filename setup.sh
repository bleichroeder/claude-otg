#!/bin/bash
# 1. CLEANUP
sed -i 's/\r$//' "$0"

echo "----------------------------------------------------"
echo "Installing Claude-OTG Environment..."
echo "----------------------------------------------------"

# 2. PRE-FLIGHT CHECKS & AUTO-INSTALL
if ! command -v claude &> /dev/null; then
    echo "Claude CLI not found. Attempting to install..."
    echo ""

    # Check for npm
    if ! command -v npm &> /dev/null; then
        echo "npm not found. Checking for Node.js..."

        # Check for node
        if ! command -v node &> /dev/null; then
            echo "Node.js not found. Installing via nvm..."
            echo ""

            # Install nvm and Node.js
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

            # Load nvm immediately
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

            # Install latest LTS Node.js
            nvm install --lts
            nvm use --lts

            if ! command -v npm &> /dev/null; then
                echo "ERROR: Failed to install Node.js/npm."
                echo "Please install Node.js manually: https://nodejs.org/"
                exit 1
            fi
            echo "Node.js installed successfully."
        else
            echo "ERROR: Node.js found but npm is missing."
            echo "Please reinstall Node.js: https://nodejs.org/"
            exit 1
        fi
    fi

    echo "Installing Claude Code..."
    npm install -g @anthropic-ai/claude-code

    if ! command -v claude &> /dev/null; then
        echo "ERROR: Failed to install Claude Code."
        echo "Try manually: npm install -g @anthropic-ai/claude-code"
        exit 1
    fi
    echo "Claude Code installed successfully."
    echo ""
fi

# 3. CREATE HELPER SCRIPTS DIRECTORY
sudo mkdir -p /usr/local/share/claude-otg

# 4. CREATE THE HELP SCRIPT
sudo tee /usr/local/share/claude-otg/help.txt > /dev/null << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                   CLAUDE-OTG SHORTCUTS                       ║
╠══════════════════════════════════════════════════════════════╣
║  Prefix = Ctrl+A  (press first, then the key below)         ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  NAVIGATION                                                  ║
║  ─────────────────────────────────────────────────────────── ║
║  Prefix + 1-9     Jump to window 1-9                        ║
║  Prefix + n       Next window                               ║
║  Prefix + p       Previous window                           ║
║  Prefix + w       Window list (interactive)                 ║
║  Prefix + Tab     Last active window                        ║
║                                                              ║
║  ACTIONS                                                     ║
║  ─────────────────────────────────────────────────────────── ║
║  Prefix + S       Save pane to ~/claude_dump.md             ║
║  Prefix + C       Copy last Claude response                 ║
║  Prefix + m       Toggle mouse mode                         ║
║  Prefix + r       Reload tmux config                        ║
║  Prefix + ?       Show this help                            ║
║                                                              ║
║  SCROLLING                                                   ║
║  ─────────────────────────────────────────────────────────── ║
║  Prefix + [       Enter scroll mode (q to exit)             ║
║  Prefix + PgUp    Scroll up one page                        ║
║  Mouse wheel      Scroll (when mouse mode is on)            ║
║                                                              ║
║  SESSION                                                     ║
║  ─────────────────────────────────────────────────────────── ║
║  Prefix + d       Detach (keeps session running)            ║
║  Prefix + Q       Kill session and exit (cleanup)           ║
║  Prefix + $       Rename session                            ║
║  Prefix + ,       Rename window                             ║
║  Prefix + &       Close window                              ║
║                                                              ║
║  Press 'q' or Enter to close this help                      ║
╚══════════════════════════════════════════════════════════════╝
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
echo -e "${GREEN}${BOLD}  ╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}  ║           CLAUDE-OTG - Mobile AI Session              ║${NC}"
echo -e "${GREEN}${BOLD}  ╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Mobile Access URL:${NC}"
echo -e "  ${BLUE}${BOLD}https://vscode.dev/tunnel/${TUNNEL_NAME}${NC}"
echo ""
echo -e "  ${YELLOW}Quick Reference:${NC}"
echo -e "  ${DIM}──────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Ctrl+A ?${NC}     Show all shortcuts"
echo -e "  ${BOLD}Ctrl+A S${NC}     Save conversation to file"
echo -e "  ${BOLD}Ctrl+A C${NC}     Copy last response"
echo -e "  ${BOLD}Ctrl+A d${NC}     Detach (session stays alive)"
echo -e "  ${BOLD}Ctrl+A w${NC}     List all windows"
echo -e "  ${DIM}──────────────────────────────────────────────────────${NC}"
echo ""
echo -e "  ${DIM}Press Enter to start Claude...${NC}"
read -r
echo ""
echo -e "  ${CYAN}Starting Claude...${NC}"
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

# 8. CREATE THE MAIN SCRIPT
sudo tee /usr/local/bin/claude-otg > /dev/null << 'EOF'
#!/bin/bash
SESSION_NAME="ai-mobile"
TUNNEL_NAME="${CLAUDE_OTG_TUNNEL:-my-claude-box}"
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Handle commands
if [ "$1" = "kill" ] || [ "$1" = "--kill" ]; then
    if tmux has-session -t $SESSION_NAME 2>/dev/null; then
        echo -e "${YELLOW}Killing session '$SESSION_NAME'...${NC}"
        tmux kill-session -t $SESSION_NAME
        echo -e "${GREEN}Session terminated.${NC}"
    else
        echo -e "${YELLOW}No active session found.${NC}"
    fi
    exit 0
fi

# Allow tunnel name override via argument
if [ -n "$1" ]; then TUNNEL_NAME="$1"; fi

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
if [ ! -f $CONF ] || ! grep -q "claude-otg-config" $CONF; then
    echo -e "${YELLOW}Applying Claude-OTG tmux configuration...${NC}"
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
bind ? display-popup -w 68 -h 38 -E "cat /usr/local/share/claude-otg/help.txt && read -n 1"

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
fi

# Handle VS Code tunnel
if [ "$IN_VSCODE" = true ]; then
    echo -e "${GREEN}Detected VS Code Terminal.${NC}"
else
    if ! pgrep -f "code tunnel" > /dev/null; then
        echo -e "${YELLOW}Starting Headless Tunnel...${NC}"
        CODE_PATH=$(command -v code)
        if [[ "$CODE_PATH" == *"/mnt/c/"* ]] || [ -z "$CODE_PATH" ]; then
            if [ ! -f ./code ]; then
                echo -e "${YELLOW}Downloading VS Code CLI...${NC}"
                if ! curl -Lk 'https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64' --output vscode_cli.tar.gz; then
                    echo -e "${RED}ERROR: Failed to download VS Code CLI.${NC}"
                    echo "Check your internet connection and try again."
                    exit 1
                fi
                if ! tar -xf vscode_cli.tar.gz; then
                    echo -e "${RED}ERROR: Failed to extract VS Code CLI.${NC}"
                    rm -f vscode_cli.tar.gz
                    exit 1
                fi
                rm -f vscode_cli.tar.gz
            fi
            ./code tunnel --name "$TUNNEL_NAME" --accept-server-license-terms > /dev/null 2>&1 &
        else
            nohup code tunnel --name "$TUNNEL_NAME" --accept-server-license-terms > /dev/null 2>&1 &
        fi
        sleep 2
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
        echo -e "Reconnecting to session..."
        # Show session info on reconnect
        echo ""
        echo -e "${BLUE}Active windows:${NC}"
        tmux list-windows -t $SESSION_NAME -F "  #I: #W #{?window_active,(active),}" 2>/dev/null
        echo ""
        sleep 1
        tmux attach -t $SESSION_NAME
    else
        echo -e "Opening project '${PROJECT_NAME}'..."
        tmux new-window -t $SESSION_NAME -n "$PROJECT_NAME" -c "$CURRENT_DIR" "claude"
        tmux attach -t $SESSION_NAME
    fi
else
    echo -e "Creating new AI Session..."
    # New session: show welcome screen first, then start claude
    tmux new-session -d -s $SESSION_NAME -n "$PROJECT_NAME" -c "$CURRENT_DIR"
    tmux send-keys -t $SESSION_NAME "bash /usr/local/share/claude-otg/welcome.sh '$TUNNEL_NAME' && claude" Enter
    tmux attach -t $SESSION_NAME
fi
EOF

# 9. SET PERMISSIONS
sudo chmod +x /usr/local/bin/claude-otg

echo ""
echo "----------------------------------------------------"
echo "Success! Claude-OTG is installed with enhanced UI."
echo "----------------------------------------------------"
echo ""
echo "Usage:"
echo "  claude-otg              # Use default tunnel name"
echo "  claude-otg my-tunnel    # Use custom tunnel name"
echo "  claude-otg --kill       # Kill session and clean up"
echo ""
echo "New Features:"
echo "  - Press Ctrl+A then ? for help menu"
echo "  - Mobile-optimized color theme"
echo "  - Git branch in status bar"
echo "  - Welcome screen with quick reference"
echo "  - Visual activity alerts"
echo ""
