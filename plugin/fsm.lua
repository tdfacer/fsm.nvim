if vim.g.loaded_fsm then
  return
end
vim.g.loaded_fsm = true

local function create_commands()
  local fsm = require("fsm")
  local store = require("fsm.store")
  local utils = require("fsm.utils")

  -- :FocusStart <name>
  vim.api.nvim_create_user_command("FocusStart", function(opts)
    local name = opts.args
    if name == "" then
      vim.notify("[FSM] Focus name required", vim.log.levels.ERROR)
      return
    end
    local ok, err = fsm.start(name)
    if not ok then
      vim.notify("[FSM] " .. err, vim.log.levels.ERROR)
    end
  end, {
    nargs = 1,
    desc = "Start a new focus",
    complete = function()
      return {}
    end,
  })

  -- :FocusSuspend [name]
  vim.api.nvim_create_user_command("FocusSuspend", function(opts)
    local slug = opts.args ~= "" and opts.args or nil
    local ok, err = fsm.suspend(slug)
    if not ok then
      vim.notify("[FSM] " .. err, vim.log.levels.ERROR)
    end
  end, {
    nargs = "?",
    desc = "Suspend current or specified focus",
    complete = function()
      local focuses = store.active()
      local slugs = {}
      for _, f in ipairs(focuses) do
        table.insert(slugs, f.slug)
      end
      return slugs
    end,
  })

  -- :FocusResume <name>
  vim.api.nvim_create_user_command("FocusResume", function(opts)
    local slug = opts.args
    if slug == "" then
      vim.notify("[FSM] Focus slug required", vim.log.levels.ERROR)
      return
    end
    local ok, err = fsm.resume(slug)
    if not ok then
      vim.notify("[FSM] " .. err, vim.log.levels.ERROR)
    end
  end, {
    nargs = 1,
    desc = "Resume a suspended focus",
    complete = function()
      local focuses = store.suspended()
      local slugs = {}
      for _, f in ipairs(focuses) do
        table.insert(slugs, f.slug)
      end
      -- Also include active for switching
      for _, f in ipairs(store.active()) do
        table.insert(slugs, f.slug)
      end
      return slugs
    end,
  })

  -- :FocusArchive <name>
  vim.api.nvim_create_user_command("FocusArchive", function(opts)
    local slug = opts.args
    if slug == "" then
      vim.notify("[FSM] Focus slug required", vim.log.levels.ERROR)
      return
    end
    local ok, err = fsm.archive(slug)
    if not ok then
      vim.notify("[FSM] " .. err, vim.log.levels.ERROR)
    end
  end, {
    nargs = 1,
    desc = "Archive a focus",
    complete = function()
      local focuses = store.list_all()
      local slugs = {}
      for _, f in ipairs(focuses) do
        if f.state ~= "archived" then
          table.insert(slugs, f.slug)
        end
      end
      return slugs
    end,
  })

  -- :FocusList
  vim.api.nvim_create_user_command("FocusList", function()
    local focuses = fsm.list()
    if #focuses == 0 then
      vim.notify("[FSM] No focuses found", vim.log.levels.INFO)
      return
    end

    local lines = { "Focuses:" }
    for _, f in ipairs(focuses) do
      local status_icon = ({ active = "●", suspended = "○", archived = "◌" })[f.state] or "?"
      local ws = f.workspace_name and (" [" .. f.workspace_name .. "]") or ""
      table.insert(lines, string.format("  %s %s (%s)%s", status_icon, f.name, f.state, ws))
    end
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
  end, {
    desc = "List all focuses",
  })

  -- :FocusSwitch
  vim.api.nvim_create_user_command("FocusSwitch", function()
    local picker = require("fsm.ui.picker")
    picker.pick_focus(function(focus)
      if focus then
        fsm.switch(focus.slug)
      end
    end)
  end, {
    desc = "Switch focus using picker",
  })

  -- :FocusStatus
  vim.api.nvim_create_user_command("FocusStatus", function()
    local status = fsm.status()
    local lines = { "FSM Status:" }

    if status.has_focus then
      table.insert(lines, "  Current: " .. status.focus.name .. " (" .. status.focus.state .. ")")
      if status.focus.workspace_name then
        table.insert(lines, "  Workspace: " .. status.focus.workspace_name)
      end
      if status.marked_windows then
        table.insert(lines, "  Marked windows: " .. status.marked_windows)
      end
    else
      table.insert(lines, "  No active focus")
    end

    table.insert(lines, "")
    table.insert(lines, "Drivers:")
    table.insert(lines, "  i3: " .. (status.i3_available and "available" or "not available"))
    table.insert(lines, "  tmux: " .. (status.tmux_available and "available" or "not available"))

    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
  end, {
    desc = "Show current focus status",
  })

  -- :FocusNotes [name]
  vim.api.nvim_create_user_command("FocusNotes", function(opts)
    local slug = opts.args ~= "" and utils.slugify(opts.args) or nil
    local ok, err = fsm.notes(slug)
    if not ok then
      vim.notify("[FSM] " .. err, vim.log.levels.ERROR)
    end
  end, {
    nargs = "?",
    desc = "Open notes for focus",
    complete = function()
      local focuses = store.list_all()
      local slugs = {}
      for _, f in ipairs(focuses) do
        table.insert(slugs, f.slug)
      end
      return slugs
    end,
  })

  -- :FocusTodo [name]
  vim.api.nvim_create_user_command("FocusTodo", function(opts)
    local slug = opts.args ~= "" and utils.slugify(opts.args) or nil
    local ok, err = fsm.todo(slug)
    if not ok then
      vim.notify("[FSM] " .. err, vim.log.levels.ERROR)
    end
  end, {
    nargs = "?",
    desc = "Open todo for focus",
    complete = function()
      local focuses = store.list_all()
      local slugs = {}
      for _, f in ipairs(focuses) do
        table.insert(slugs, f.slug)
      end
      return slugs
    end,
  })
end

create_commands()
