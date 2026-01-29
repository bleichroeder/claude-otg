#!/bin/bash
# Fix line endings just in case
sed -i 's/\r$//' "$0"

echo "----------------------------------------------------"
echo "Uninstalling Claude-OTG..."
echo "----------------------------------------------------"

# 1. KILL THE SESSION
if tmux has-session -t ai-mobile 2>/dev/null; then
    tmux kill-session -t ai-mobile
    echo "Killed active 'ai-mobile' session."
else
    echo "No active session found."
fi

# 2. KILL THE TUNNEL
if pgrep -f "code tunnel" > /dev/null; then
    pkill -f "code tunnel"
    echo "Stopped background Tunnel."
else
    echo "No tunnel running."
fi

# 3. REMOVE THE MAIN COMMAND
if [ -f /usr/local/bin/claude-otg ]; then
    sudo rm /usr/local/bin/claude-otg
    echo "Removed 'claude-otg' command."
else
    echo "Command already removed."
fi

# 4. REMOVE HELPER SCRIPTS
if [ -d /usr/local/share/claude-otg ]; then
    sudo rm -rf /usr/local/share/claude-otg
    echo "Removed helper scripts."
else
    echo "Helper scripts already removed."
fi

# 5. CLEAN UP TMUX CONFIG
CONF=~/.tmux.conf
if [ -f "$CONF" ] && grep -q "claude-otg-config" "$CONF"; then
    # Remove the config block between the markers
    sed -i '/# --- claude-otg-config ---/,/# --- end-claude-otg-config ---/d' "$CONF"
    echo "Removed tmux configuration."
    # Remove the file if it's now empty
    if [ ! -s "$CONF" ]; then
        rm "$CONF"
        echo "Removed empty .tmux.conf file."
    fi
else
    echo "No tmux config to clean."
fi

# 6. CLEAN UP DOWNLOADED VS CODE CLI
if [ -f ./code ]; then
    rm -f ./code
    echo "Removed downloaded VS Code CLI."
fi
if [ -f ./vscode_cli.tar.gz ]; then
    rm -f ./vscode_cli.tar.gz
    echo "Removed VS Code CLI archive."
fi

echo "----------------------------------------------------"
echo "Clean uninstall complete."
echo "(Note: Dependencies like tmux/nodejs were left installed)"
