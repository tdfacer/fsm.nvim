if vim.g.loaded_fsm then
  return
end
vim.g.loaded_fsm = true

local function create_commands()
  local fsm = require("fsm")
  local store = require("fsm.store")
  local utils = require("fsm.utils")

  -- :FocusStart [name]
  vim.api.nvim_create_user_command("FocusStart", function(opts)
    local name = opts.args
    if name == "" then
      -- Prompt for name if not provided
      vim.ui.input({ prompt = "Focus name: " }, function(input)
        if input and input ~= "" then
          local ok, err = fsm.start(input)
          if not ok then
            vim.notify("[FSM] " .. err, vim.log.levels.ERROR)
          end
        end
      end)
      return
    end
    local ok, err = fsm.start(name)
    if not ok then
      vim.notify("[FSM] " .. err, vim.log.levels.ERROR)
    end
  end, {
    nargs = "?",
    desc = "Start a new focus",
    complete = function()
      return {}
    end,
  })

  -- :FocusSuspend [name]
  vim.api.nvim_create_user_command("FocusSuspend", function(opts)
    local slug = opts.args
    if slug == "" then
      -- Use picker if no argument
      local picker = require("fsm.ui.picker")
      picker.pick_focus(function(focus)
        if focus then
          local ok, err = fsm.suspend(focus.slug)
          if not ok then
            vim.notify("[FSM] " .. err, vim.log.levels.ERROR)
          end
        end
      end, { filter_state = "active" })
      return
    end
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

  -- :FocusResume [name]
  vim.api.nvim_create_user_command("FocusResume", function(opts)
    local slug = opts.args
    if slug == "" then
      -- Use picker if no argument
      local picker = require("fsm.ui.picker")
      picker.pick_focus(function(focus)
        if focus then
          local ok, err = fsm.resume(focus.slug)
          if not ok then
            vim.notify("[FSM] " .. err, vim.log.levels.ERROR)
          end
        end
      end, { filter_state = "suspended" })
      return
    end
    local ok, err = fsm.resume(slug)
    if not ok then
      vim.notify("[FSM] " .. err, vim.log.levels.ERROR)
    end
  end, {
    nargs = "?",
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

  -- :FocusArchive [name]
  vim.api.nvim_create_user_command("FocusArchive", function(opts)
    local slug = opts.args
    if slug == "" then
      -- Use picker if no argument
      local picker = require("fsm.ui.picker")
      picker.pick_focus(function(focus)
        if focus then
          local ok, err = fsm.archive(focus.slug)
          if not ok then
            vim.notify("[FSM] " .. err, vim.log.levels.ERROR)
          end
        end
      end, { include_archived = false })
      return
    end
    local ok, err = fsm.archive(slug)
    if not ok then
      vim.notify("[FSM] " .. err, vim.log.levels.ERROR)
    end
  end, {
    nargs = "?",
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

  -- :FocusDelete [name]
  vim.api.nvim_create_user_command("FocusDelete", function(opts)
    local slug = opts.args
    if slug == "" then
      -- Use picker if no argument (only show archived)
      local picker = require("fsm.ui.picker")
      picker.pick_focus(function(focus)
        if focus then
          vim.ui.select({ "Yes", "No" }, {
            prompt = string.format("Delete focus '%s' permanently? ", focus.name),
          }, function(choice)
            if choice == "Yes" then
              local ok, err = fsm.delete(focus.slug)
              if not ok then
                vim.notify("[FSM] " .. err, vim.log.levels.ERROR)
              end
            end
          end)
        end
      end, { filter_state = "archived", include_archived = true })
      return
    end
    -- Confirm deletion
    vim.ui.select({ "Yes", "No" }, {
      prompt = string.format("Delete focus '%s' permanently? ", slug),
    }, function(choice)
      if choice == "Yes" then
        local ok, err = fsm.delete(slug)
        if not ok then
          vim.notify("[FSM] " .. err, vim.log.levels.ERROR)
        end
      end
    end)
  end, {
    nargs = "?",
    desc = "Delete a focus permanently",
    complete = function()
      local focuses = store.by_state("archived")
      local slugs = {}
      for _, f in ipairs(focuses) do
        table.insert(slugs, f.slug)
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
    -- If no slug provided and no current focus, show picker
    if not slug and not fsm.current() then
      local picker = require("fsm.ui.picker")
      picker.pick_focus(function(focus)
        if focus then
          local ok, err = fsm.notes(focus.slug)
          if not ok then
            vim.notify("[FSM] " .. err, vim.log.levels.ERROR)
          end
        end
      end, { include_archived = true })
      return
    end
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
    -- If no slug provided and no current focus, show picker
    if not slug and not fsm.current() then
      local picker = require("fsm.ui.picker")
      picker.pick_focus(function(focus)
        if focus then
          local ok, err = fsm.todo(focus.slug)
          if not ok then
            vim.notify("[FSM] " .. err, vim.log.levels.ERROR)
          end
        end
      end, { include_archived = true })
      return
    end
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

  -- :FocusUrls [slug]
  vim.api.nvim_create_user_command("FocusUrls", function(opts)
    local slug = opts.args ~= "" and utils.slugify(opts.args) or nil
    -- If no slug provided and no current focus, show picker
    if not slug and not fsm.current() then
      local picker = require("fsm.ui.picker")
      picker.pick_focus(function(focus)
        if focus then
          local ok, err = fsm.open_urls(focus.slug)
          if not ok then
            vim.notify("[FSM] " .. err, vim.log.levels.ERROR)
          end
        end
      end, { include_archived = true })
      return
    end
    local ok, err = fsm.open_urls(slug)
    if not ok then
      vim.notify("[FSM] " .. err, vim.log.levels.ERROR)
    end
  end, {
    nargs = "?",
    desc = "Open URLs for focus in browser",
    complete = function()
      local focuses = store.list_all()
      local slugs = {}
      for _, f in ipairs(focuses) do
        table.insert(slugs, f.slug)
      end
      return slugs
    end,
  })

  -- :FocusAddUrl [url]
  vim.api.nvim_create_user_command("FocusAddUrl", function(opts)
    local url = opts.args ~= "" and opts.args or nil

    -- Helper to add URL once we have both url and slug
    local function do_add_url(target_url, slug)
      local ok, err = fsm.add_url(target_url, slug)
      if not ok then
        vim.notify("[FSM] " .. err, vim.log.levels.ERROR)
      else
        vim.notify("[FSM] URL added", vim.log.levels.INFO)
      end
    end

    -- Helper to prompt for URL then add
    local function prompt_and_add(slug)
      vim.ui.input({ prompt = "URL: " }, function(input)
        if input and input ~= "" then
          do_add_url(input, slug)
        end
      end)
    end

    -- If no current focus, show picker first
    if not fsm.current() then
      local picker = require("fsm.ui.picker")
      picker.pick_focus(function(focus)
        if focus then
          if url then
            do_add_url(url, focus.slug)
          else
            prompt_and_add(focus.slug)
          end
        end
      end, { include_archived = false })
      return
    end

    -- Have current focus
    if url then
      do_add_url(url, nil)
    else
      prompt_and_add(nil)
    end
  end, {
    nargs = "?",
    desc = "Add URL to focus",
  })

  -- :FocusListUrls [slug]
  vim.api.nvim_create_user_command("FocusListUrls", function(opts)
    local slug = opts.args ~= "" and utils.slugify(opts.args) or nil
    local urls, err = fsm.list_urls(slug)
    if not urls then
      vim.notify("[FSM] " .. err, vim.log.levels.ERROR)
      return
    end
    if #urls == 0 then
      vim.notify("[FSM] No URLs saved for this focus", vim.log.levels.INFO)
      return
    end
    local lines = { "URLs:" }
    for i, url in ipairs(urls) do
      table.insert(lines, string.format("  %d. %s", i, url))
    end
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
  end, {
    nargs = "?",
    desc = "List URLs for focus",
    complete = function()
      local focuses = store.list_all()
      local slugs = {}
      for _, f in ipairs(focuses) do
        table.insert(slugs, f.slug)
      end
      return slugs
    end,
  })
  -- :FocusRepair [--dry-run]
  vim.api.nvim_create_user_command("FocusRepair", function(opts)
    local dry_run = opts.args == "--dry-run"
    local results = fsm.repair({ dry_run = dry_run })

    if #results.issues == 0 then
      vim.notify("[FSM] All focuses are healthy", vim.log.levels.INFO)
      return
    end

    local lines = {}
    if dry_run then
      table.insert(lines, "Issues found (dry run - no changes made):")
    else
      table.insert(lines, string.format("Repaired %d focus(es):", results.fixed))
    end

    for _, issue in ipairs(results.issues) do
      table.insert(lines, string.format("  • %s: %s", issue.name, table.concat(issue.problems, ", ")))
    end

    vim.notify(table.concat(lines, "\n"), dry_run and vim.log.levels.WARN or vim.log.levels.INFO)
  end, {
    nargs = "?",
    desc = "Repair orphaned focuses after crash/reboot",
  })

  -- :FocusHealth
  vim.api.nvim_create_user_command("FocusHealth", function()
    local status_list = fsm.health_check()

    if #status_list == 0 then
      vim.notify("[FSM] No focuses found", vim.log.levels.INFO)
      return
    end

    local lines = { "Focus Health:" }
    for _, status in ipairs(status_list) do
      local icon = status.healthy and "✓" or "✗"
      local state_icon = ({ active = "●", suspended = "○", archived = "◌" })[status.state] or "?"

      local line = string.format("  %s %s %s (%s)", icon, state_icon, status.name, status.state)

      if status.state == "active" then
        local details = {}
        if status.workspace_num then
          table.insert(details, "ws:" .. status.workspace_num .. (status.workspace_exists and "✓" or "✗"))
        end
        if status.tmux_session then
          table.insert(details, "tmux:" .. (status.tmux_exists and "✓" or "✗"))
        end
        if #details > 0 then
          line = line .. " [" .. table.concat(details, " ") .. "]"
        end
      end

      if #status.issues > 0 then
        line = line .. " - " .. table.concat(status.issues, ", ")
      end

      table.insert(lines, line)
    end

    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
  end, {
    desc = "Show health status of all focuses",
  })
end

create_commands()
