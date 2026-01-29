<p align="center">
  <img src="./otg.png" alt="Claude-OTG Logo" width="200">
</p>

# Claude-OTG (On The Go)

**Stop babysitting your terminal from your desk chair.**

You know the drill. You ask Claude to do something, it's chugging along, you figure you'll grab a snack. You come back 10 minutes later to find it's been sitting there waiting for you to approve a file edit. Cool. Thanks for the notification, computer.

Or maybe you're "working from home" and need to check if Claude is done refactoring that component... but your PC is upstairs and you're downstairs. On the couch. Horizontal. As one should be.

Or perhaps you're in the bathroom (we're all adults here) and you just want to peek at your phone to see if that build finished.

**Claude-OTG lets you monitor and interact with Claude Code from your phone, tablet, or literally any device with a browser.**

Run one command, get a URL, and suddenly you're approving file changes from the toilet like a *senior engineer*.

---

## How It Works (The Non-Silly Version)

Claude-OTG creates a VS Code tunnel to your machine and wraps Claude Code in a mobile-friendly tmux session. You get:

- A URL you can open on any device
- A persistent session that survives disconnects
- Mobile-optimized shortcuts (because typing `Ctrl+B` on a phone keyboard is pain)
- Visual alerts when Claude needs your attention

## Quick Start

### Windows (WSL)

```batch
git clone https://github.com/YOUR_USERNAME/claude-otg.git
cd claude-otg
install.bat
```

### Linux / macOS

```bash
git clone https://github.com/YOUR_USERNAME/claude-otg.git
cd claude-otg
chmod +x setup.sh
./setup.sh
```

Then run from any project directory:

```bash
claude-otg
```

A URL appears. Open it on your phone. That's it. Go lie down.

## Requirements

- **Windows**: WSL with Ubuntu (or any Linux distro with bash)
- **Linux/macOS**: bash, curl

Everything else (Node.js, npm, Claude Code, tmux) is installed automatically. We gotchu.

## Usage

```bash
# Start with default tunnel name
claude-otg

# Start with custom tunnel name (if someone stole yours)
claude-otg my-special-tunnel

# Or set via environment variable
export CLAUDE_OTG_TUNNEL="my-tunnel"
claude-otg
```

### Mobile Access

1. Run `claude-otg` from your project directory
2. Copy the tunnel URL: `https://vscode.dev/tunnel/your-tunnel-name`
3. Open it on your phone
4. Sign in with GitHub
5. Open the terminal
6. Resume your horizontal lifestyle

## Keyboard Shortcuts

Prefix key is **Ctrl+A** (way easier on mobile than the default Ctrl+B).

| Shortcut | Action |
|----------|--------|
| `Ctrl+A ?` | Show all shortcuts (you'll forget these) |
| `Ctrl+A S` | Save conversation to `~/claude_dump.md` |
| `Ctrl+A C` | Copy last Claude response |
| `Ctrl+A m` | Toggle mouse mode |
| `Ctrl+A d` | Detach (session keeps running) |
| `Ctrl+A w` | List all windows |
| `Ctrl+A 1-9` | Jump to window |
| `Ctrl+A Tab` | Last active window |
| `Ctrl+A \|` | Split pane horizontally |
| `Ctrl+A -` | Split pane vertically |

### Scrolling

| Shortcut | Action |
|----------|--------|
| `Ctrl+A [` | Enter scroll mode (`q` to exit) |
| `PageUp/Down` | Scroll pages |
| Mouse wheel | Scroll (when mouse mode on) |

## Status Bar

```
 SESSION | main* | 02:30 PM | 01/29
```

- Session name
- Git branch (`*` = uncommitted changes)
- Time and date

Windows flash yellow when there's new activity. So you know when Claude wants attention. Like a cat, but useful.

## Project Structure

```
claude-otg/
├── install.bat      # Windows entry point
├── uninstall.bat    # Windows cleanup
├── setup.sh         # The real installer (does everything)
└── uninstall.sh     # Linux/macOS cleanup
```

### What Gets Installed

| Location | What |
|----------|------|
| `/usr/local/bin/claude-otg` | The main command |
| `/usr/local/share/claude-otg/` | Helper scripts |
| `~/.tmux.conf` | Tmux config (appends, doesn't overwrite) |

## Uninstall

### Windows

```batch
uninstall.bat
```

### Linux / macOS

```bash
./uninstall.sh
```

Removes the command, helper scripts, tmux config additions, and any running sessions. Leaves Node.js and tmux alone in case you use them for other stuff.

## Troubleshooting

### "No WSL distribution found"

```powershell
wsl --install -d Ubuntu
```

### Tunnel name conflict

Pick something unique:

```bash
claude-otg not-a-common-name-12345
```

### Can't scroll on mobile

`Ctrl+A m` toggles mouse mode. Or `Ctrl+A [` enters scroll mode (press `q` to exit).

### Colors look weird

Your terminal might not support 256 colors. VS Code web handles this fine though.

## Tips

- **Detach, don't close** - `Ctrl+A d` keeps your session alive
- **Save the good stuff** - `Ctrl+A S` dumps the whole conversation to a file
- **Multiple projects** - Run `claude-otg` from different directories for separate windows
- **Reconnect** - Run `claude-otg` from home directory to rejoin an existing session

## License

MIT - Do whatever you want with it.

---

*Built for people who code from the couch, and aren't ashamed to admit it.*
