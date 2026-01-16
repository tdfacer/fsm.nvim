# fsm.nvim

Focus Set Manager for Neovim - manage named work contexts spanning i3 workspaces, tmux sessions, Neovim state, and browser windows.

Designed for DevOps workflows with heavy context switching. Start a focus, get a dedicated workspace with a tmux session and notes file. Suspend it to park browser windows and save state. Resume later exactly where you left off.

## Features

- **Workspace Management**: Automatically allocates i3 workspaces (10-19) for each focus
- **tmux Integration**: One tmux session per focus, persists across suspend/resume
- **Session Persistence**: Saves and restores Neovim sessions and working directory
- **Browser Parking**: Parks browser windows to workspace 99 on suspend, restores on resume
- **Focus Files**: Each focus gets `notes.md` and `todo.md` for context
- **Window Marking**: Tracks windows via i3 marks for reliable state management
- **Telescope Integration**: Quick focus switching with preview
- **Statusline Component**: Show current focus in your statusline
- **Graceful Degradation**: Works without i3 or tmux (with reduced functionality)

## Requirements

**Required:**
- Neovim 0.9+

**Recommended:**
- i3 4.x (workspace management)
- tmux 3.x (session management)
- alacritty (default terminal)
- firefox (default browser)

**Optional:**
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (enhanced picker)

Run `:checkhealth fsm` to verify your setup.

## Installation

### lazy.nvim

```lua
{
  "your-username/fsm.nvim",
  config = function()
    require("fsm").setup()
  end,
  keys = {
    { "<leader>Fs", "<cmd>FocusStart<cr>", desc = "Start new focus" },
    { "<leader>Fw", "<cmd>FocusSwitch<cr>", desc = "Switch focus" },
    { "<leader>Fp", "<cmd>FocusSuspend<cr>", desc = "Suspend focus" },
    { "<leader>Fr", "<cmd>FocusResume<cr>", desc = "Resume focus" },
    { "<leader>Fl", "<cmd>FocusList<cr>", desc = "List focuses" },
    { "<leader>Fi", "<cmd>FocusStatus<cr>", desc = "Focus info/status" },
    { "<leader>Fn", "<cmd>FocusNotes<cr>", desc = "Open focus notes" },
    { "<leader>Ft", "<cmd>FocusTodo<cr>", desc = "Open focus todo" },
    { "<leader>Fa", "<cmd>FocusArchive<cr>", desc = "Archive focus" },
  },
}
```

### packer.nvim

```lua
use {
  "your-username/fsm.nvim",
  config = function()
    require("fsm").setup()
  end,
}
```

## Configuration

```lua
require("fsm").setup({
  -- Workspace range for focus allocation (default: 10-19)
  workspace_range = { 10, 19 },

  -- Workspace for parked windows during suspend
  parking_workspace = 99,

  -- How to handle windows on suspend
  suspend_policy = {
    terminals = "keep",   -- "keep" | "park" | "close"
    browsers = "park",    -- "keep" | "park" | "close"
  },

  -- Application launch commands
  -- %s placeholders: terminal gets (slug, tmux_cmd), browser gets (urls)
  apps = {
    terminal = 'alacritty --class "focus-%s,Alacritty" -e %s',
    browser = "firefox %s",
  },

  -- tmux configuration
  tmux = {
    enabled = true,
    session_prefix = "focus/",  -- tmux sessions named "focus/<slug>"
  },

  -- Notes configuration
  notes = {
    auto_open = true,  -- Open notes.md on FocusStart
  },

  -- Environment variable patterns to redact from saved state
  redact_env_vars = { ".*SECRET.*", ".*TOKEN.*", ".*KEY.*", ".*PASSWORD.*" },

  -- Data storage location
  data_dir = "~/.local/share/focus",
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:FocusStart <name>` | Create focus, allocate workspace, launch terminal, open notes |
| `:FocusSuspend [slug]` | Save state, park browser windows (defaults to current focus) |
| `:FocusResume <slug>` | Restore workspace, unpark windows, load session |
| `:FocusSwitch` | Telescope picker to suspend current + resume selected |
| `:FocusList` | List all focuses with state indicators |
| `:FocusStatus` | Show current focus details and driver availability |
| `:FocusArchive <slug>` | Mark focus as archived (read-only) |
| `:FocusNotes [slug]` | Open notes.md for focus |
| `:FocusTodo [slug]` | Open todo.md for focus |

## Keymaps

Recommended keymaps using `<leader>F` prefix:

```lua
local opts = { noremap = true, silent = true }

-- Core workflow
vim.keymap.set("n", "<leader>Fs", "<cmd>FocusStart<cr>", vim.tbl_extend("force", opts, { desc = "Start new focus" }))
vim.keymap.set("n", "<leader>Fw", "<cmd>FocusSwitch<cr>", vim.tbl_extend("force", opts, { desc = "Switch focus" }))
vim.keymap.set("n", "<leader>Fp", "<cmd>FocusSuspend<cr>", vim.tbl_extend("force", opts, { desc = "Suspend focus" }))
vim.keymap.set("n", "<leader>Fr", "<cmd>FocusResume<cr>", vim.tbl_extend("force", opts, { desc = "Resume focus" }))

-- Info and lists
vim.keymap.set("n", "<leader>Fl", "<cmd>FocusList<cr>", vim.tbl_extend("force", opts, { desc = "List focuses" }))
vim.keymap.set("n", "<leader>Fi", "<cmd>FocusStatus<cr>", vim.tbl_extend("force", opts, { desc = "Focus info" }))

-- Focus files
vim.keymap.set("n", "<leader>Fn", "<cmd>FocusNotes<cr>", vim.tbl_extend("force", opts, { desc = "Focus notes" }))
vim.keymap.set("n", "<leader>Ft", "<cmd>FocusTodo<cr>", vim.tbl_extend("force", opts, { desc = "Focus todo" }))

-- Archive (less common)
vim.keymap.set("n", "<leader>Fa", "<cmd>FocusArchive<cr>", vim.tbl_extend("force", opts, { desc = "Archive focus" }))
```

### which-key.nvim

```lua
require("which-key").register({
  ["<leader>F"] = {
    name = "+focus",
    s = { "<cmd>FocusStart<cr>", "Start new focus" },
    w = { "<cmd>FocusSwitch<cr>", "Switch focus" },
    p = { "<cmd>FocusSuspend<cr>", "Suspend focus" },
    r = { "<cmd>FocusResume<cr>", "Resume focus" },
    l = { "<cmd>FocusList<cr>", "List focuses" },
    i = { "<cmd>FocusStatus<cr>", "Focus info" },
    n = { "<cmd>FocusNotes<cr>", "Focus notes" },
    t = { "<cmd>FocusTodo<cr>", "Focus todo" },
    a = { "<cmd>FocusArchive<cr>", "Archive focus" },
  },
})
```

## Statusline

### lualine.nvim

```lua
require("lualine").setup({
  sections = {
    lualine_x = {
      require("fsm.ui.status").lualine_component(),
      "encoding",
      "fileformat",
      "filetype",
    },
  },
})
```

### Manual Integration

```lua
local status = require("fsm.ui.status")

-- Returns "● Focus Name" when active, "" otherwise
status.statusline()

-- Returns "● Focus Name [10]" with workspace number
status.statusline_full()

-- Individual components
status.focus_name()   -- "my-focus" or ""
status.focus_icon()   -- "●" (active), "○" (suspended), "◌" (archived)
status.has_focus()    -- boolean
```

## Lua API

```lua
local fsm = require("fsm")

-- Start a new focus
fsm.start("incident-rds-outage", { urls = { "https://console.aws.amazon.com" } })

-- Suspend current or specific focus
fsm.suspend()           -- current
fsm.suspend("my-focus") -- specific

-- Resume a focus
fsm.resume("my-focus")

-- Switch (suspend current + resume target)
fsm.switch("other-focus")

-- Archive a focus
fsm.archive("old-focus")

-- List focuses
fsm.list()                        -- all
fsm.list({ state = "active" })    -- filtered
fsm.list({ state = "suspended" })

-- Get current focus
fsm.current()        -- returns slug or nil
fsm.current_focus()  -- returns full metadata or nil

-- Status info
fsm.status()  -- { has_focus, focus, i3_available, tmux_available, ... }

-- Focus files
fsm.notes("my-focus")
fsm.todo("my-focus")

-- Add URLs to focus
fsm.add_urls({ "https://example.com" }, "my-focus")
```

## Data Storage

Focus data is stored at `~/.local/share/focus/foci/<slug>/`:

```
~/.local/share/focus/foci/incident-rds/
├── meta.json         # Focus metadata (name, state, workspace, etc.)
├── nvim_session.vim  # Neovim session (:mksession output)
├── nvim_state.json   # Buffer list, cwd
├── i3_layout.json    # Workspace layout (if captured)
├── i3_marks.json     # Window marks
├── urls.txt          # Canonical URLs (one per line)
├── notes.md          # Focus notes
└── todo.md           # Focus todos
```

## Workflow Example

```
# Start working on an incident
:FocusStart RDS Outage Investigation

# You now have:
# - Workspace 10:FOCUS-rds-outage-investigation
# - tmux session focus/rds-outage-investigation
# - notes.md open in Neovim
# - Alacritty terminal attached to tmux

# Open relevant URLs, work on the issue...
# Get interrupted by something urgent

:FocusSuspend
# Browser windows parked to workspace 99
# Neovim session saved

:FocusStart Urgent Deploy Fix
# New workspace, new tmux session, fresh context

# Fix the urgent issue, then switch back
:FocusSwitch
# Telescope picker shows your focuses
# Select "rds-outage-investigation"
# Suspends current, resumes previous
# Browser windows restored, back where you left off

# Done with the incident
:FocusArchive rds-outage-investigation
```

## Focus States

| State | Icon | Description |
|-------|------|-------------|
| `active` | ● | Currently active, has allocated workspace |
| `suspended` | ○ | Saved state, windows parked, can resume |
| `archived` | ◌ | Read-only, workspace freed, kept for reference |

## Tips

- **Naming**: Use descriptive names like "incident-rds-outage" or "feature-user-auth" - they become slugs and tmux session names
- **URLs**: Add canonical URLs to `urls.txt` for quick reference; they'll open on resume (future feature)
- **Notes**: Use `notes.md` for context that helps you resume - what you were doing, next steps
- **Workspaces**: Keep workspaces 1-9 for non-focus work; FSM uses 10-19 by default
- **Parking**: Workspace 99 holds parked browser windows - don't put other stuff there

## Health Check

Run `:checkhealth fsm` to verify:
- Neovim version
- i3 availability and connection
- tmux installation
- Terminal (alacritty) availability
- Browser (firefox) availability
- Data directory status
- Optional dependencies (telescope)

## License

MIT
