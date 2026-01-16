# FSM Utility Scripts

This directory contains utility scripts for managing FSM (Focus Set Manager) workspaces and focuses from outside Neovim.

## Scripts

### `fsm-workspace-switch` - GUI Workspace Switcher

Quick workspace switching with FSM awareness using dmenu or rofi.

**Usage:**
```bash
fsm-workspace-switch          # Uses dmenu by default
fsm-workspace-switch rofi     # Use rofi instead
```

**Features:**
- Shows all i3 workspaces with visual indicators:
  - `●` Current workspace
  - `◆` FSM focus workspace
  - `  ` Regular workspace
- Quick selection via dmenu/rofi
- FSM focus workspaces are highlighted

**i3 Keybinding Example:**
```
# In ~/.config/i3/config
bindsym $mod+Tab exec --no-startup-id ~/code/fsm.nvim/bin/fsm-workspace-switch rofi
```

### `fsm-control` - Full FSM Control Panel

Complete FSM management interface via dmenu/rofi.

**Usage:**
```bash
fsm-control          # Uses dmenu by default
fsm-control rofi     # Use rofi instead
```

**Features:**
- Create new focuses
- Switch between focuses
- Suspend/Resume/Archive focuses
- Open notes and todos
- Manage URLs
- Delete archived focuses
- Visual status indicators:
  - `●` Active focus
  - `○` Suspended focus
  - `◌` Archived focus

**i3 Keybinding Example:**
```
# In ~/.config/i3/config
bindsym $mod+Shift+f exec --no-startup-id ~/code/fsm.nvim/bin/fsm-control rofi
```

### `fsm-ws` - Terminal Workspace Switcher

Terminal-based workspace switcher using fzf.

**Usage:**
```bash
fsm-ws
```

**Features:**
- Runs in terminal with fzf
- Shows all workspaces with colors and indicators
- Shows focus names for FSM workspaces
- Quick fuzzy filtering

**Shell Alias Example:**
```bash
# In ~/.bashrc or ~/.zshrc
alias ws='~/code/fsm.nvim/bin/fsm-ws'
```

## Installation

1. Make sure the scripts are executable:
   ```bash
   chmod +x ~/code/fsm.nvim/bin/*
   ```

2. Add the bin directory to your PATH (optional):
   ```bash
   # In ~/.bashrc or ~/.zshrc
   export PATH="$PATH:$HOME/code/fsm.nvim/bin"
   ```

3. Or create symlinks in a directory already in PATH:
   ```bash
   ln -s ~/code/fsm.nvim/bin/fsm-workspace-switch ~/.local/bin/
   ln -s ~/code/fsm.nvim/bin/fsm-control ~/.local/bin/
   ln -s ~/code/fsm.nvim/bin/fsm-ws ~/.local/bin/
   ```

## Dependencies

### Required:
- `i3-msg` - i3 window manager IPC
- `jq` - JSON processor
- `bash` - Bash shell

### Picker-specific:
- `dmenu` - For dmenu mode (default)
- `rofi` - For rofi mode
- `fzf` - For fsm-ws terminal mode

### Optional:
- `nvim` - For fsm-control to send commands to Neovim
- `notify-send` - For desktop notifications (fallback)

## Tips

1. **Quick Workspace Switching**: Bind `fsm-workspace-switch` to a convenient key like `$mod+Tab` for fast workspace navigation.

2. **Focus Management**: Use `fsm-control` when you need to manage focuses without opening Neovim.

3. **Terminal Workflow**: If you prefer staying in the terminal, use `fsm-ws` with an alias for quick access.

4. **Launcher Integration**: These scripts work well with application launchers:
   - Add to rofi's modi: `rofi -modi "fsm:fsm-control rofi" -show fsm`
   - Create desktop entries in `~/.local/share/applications/`

5. **Custom Styling**: Both dmenu and rofi can be styled. For rofi, create a custom theme. For dmenu, modify the color variables in the scripts.

## Troubleshooting

### "Command not found" errors
Make sure all dependencies are installed:
```bash
# Arch Linux
sudo pacman -S i3-wm jq dmenu rofi fzf

# Ubuntu/Debian
sudo apt install i3 jq dmenu rofi fzf
```

### Scripts not sending commands to Neovim
The `fsm-control` script tries to send commands to a Neovim instance with a server at `/tmp/nvim-launcher.pipe`. Make sure your launcher Neovim is started with:
```bash
nvim --listen /tmp/nvim-launcher.pipe
```

### No workspaces showing
Make sure i3 IPC is working:
```bash
i3-msg -t get_workspaces
```

If this doesn't return JSON data, check your i3 configuration.