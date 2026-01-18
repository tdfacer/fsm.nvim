local config = require("fsm.config")
local store = require("fsm.store")
local state = require("fsm.state")
local log = require("fsm.log")
local i3 = require("fsm.drivers.i3")
local tmux = require("fsm.drivers.tmux")
local nvim = require("fsm.drivers.nvim")
local browser = require("fsm.drivers.browser")

local M = {}

--- Start a new focus
---@param name string Focus name
---@param opts? { urls: string[] }
---@return boolean ok
---@return string? error
function M.start(name, opts)
  opts = opts or {}

  log.info("Starting focus: %s", name)

  -- Allocate workspace
  local workspace_num, alloc_err
  if i3.available() then
    local cfg = config.get()
    workspace_num, alloc_err = i3.alloc_workspace(cfg.workspace_range[1], cfg.workspace_range[2])
    if not workspace_num then
      log.warn("Could not allocate workspace: %s", alloc_err)
    end
  else
    log.debug("i3 not available, skipping workspace allocation")
  end

  -- Create focus in store
  local focus, create_err = store.create(name, workspace_num)
  if not focus then
    return false, create_err
  end

  -- Capture current working directory if enabled
  local cfg = config.get()
  if cfg.tmux.enabled and cfg.tmux.track_cwd then
    -- Use pwd as initial directory for new focus
    focus.cwd = vim.fn.getcwd()
    log.debug("Set initial working directory: %s", focus.cwd)
    store.save(focus)
  end

  -- Set as current focus
  state.set_current(focus.slug)

  -- Switch to workspace and rename
  if workspace_num and i3.available() then
    i3.goto_workspace_num(workspace_num)
    i3.rename_workspace(focus.workspace_name)
  end

  -- Determine initial command for tmux (nvim with notes if auto_open)
  local cfg = config.get()
  local initial_cmd = nil
  if cfg.notes.auto_open then
    local notes_path = store.notes_path(focus.slug)
    initial_cmd = string.format("nvim %s", vim.fn.shellescape(notes_path))
  end

  -- Ensure tmux session exists and launch terminal
  if cfg.tmux.enabled and tmux.available() then
    local ok, tmux_err = tmux.ensure_session(focus.slug, focus.cwd, initial_cmd)
    if ok then
      focus.tmux_session = tmux.session_name(focus.slug)
      store.save(focus)
    else
      log.warn("Failed to create tmux session: %s", tmux_err)
    end

    -- Launch terminal with tmux
    local terminal_cmd = tmux.get_terminal_command(focus.slug, focus.cwd, initial_cmd)
    log.debug("Launching terminal: %s", terminal_cmd)
    vim.fn.jobstart(terminal_cmd, { detach = true })
  end

  -- Open browser URLs if provided
  if opts.urls and #opts.urls > 0 then
    store.save_urls(focus.slug, opts.urls)
    if browser.available() then
      browser.open_urls(opts.urls)
    end
  end

  -- Set nvim context (for statusline in launcher nvim)
  nvim.set_focus_context(focus)

  -- Mark windows after a delay (let terminal spawn)
  if i3.available() then
    vim.defer_fn(function()
      i3.mark_focus_windows(focus.slug)
    end, 500)
  end

  log.info("Focus started: %s (workspace %s)", focus.slug, focus.workspace_name or "N/A")
  return true, nil
end

--- Suspend a focus
---@param slug? string Focus slug (defaults to current)
---@return boolean ok
---@return string? error
function M.suspend(slug)
  slug = slug or state.current_slug()
  if not slug then
    return false, "No focus to suspend"
  end

  log.info("Suspending focus: %s", slug)

  local focus, load_err = store.load(slug)
  if not focus then
    return false, load_err
  end

  if focus.state == "suspended" then
    return false, "Focus is already suspended"
  end

  if focus.state == "archived" then
    return false, "Cannot suspend archived focus"
  end

  -- Save nvim session and state
  nvim.save_session(slug)
  nvim.save_state(slug)

  -- Handle windows based on suspend policy
  local cfg = config.get()
  local parked_ids = {}

  -- Capture current working directory from tmux if enabled
  if cfg.tmux.enabled and cfg.tmux.track_cwd and tmux.available() then
    local session = tmux.session_name(slug)
    local cwd = tmux.get_pane_cwd(session)
    if cwd then
      focus.cwd = cwd
      log.debug("Captured working directory: %s", cwd)
    end
  end

  if i3.available() and focus.workspace_name then
    -- Save marks
    i3.save_marks(slug)

    -- Handle browsers based on policy
    if cfg.suspend_policy.browsers == "park" then
      local browsers = i3.get_browsers_on_workspace(focus.workspace_name)
      if #browsers > 0 then
        local parked = i3.park_windows(browsers)
        for _, id in ipairs(parked) do
          table.insert(parked_ids, id)
        end
        log.debug("Parked %d browser windows", #browsers)
      end
    end

    -- Handle terminals based on policy
    if cfg.suspend_policy.terminals == "park" then
      local terminals = i3.get_terminals_on_workspace(focus.workspace_name)
      if #terminals > 0 then
        local parked = i3.park_windows(terminals)
        for _, id in ipairs(parked) do
          table.insert(parked_ids, id)
        end
        log.debug("Parked %d terminal windows", #terminals)
      end
    end

    -- If we parked everything, release the workspace number so it can be reused
    local remaining = i3.get_windows_on_workspace(focus.workspace_name)
    if #remaining == 0 then
      log.debug("All windows parked, releasing workspace %d", focus.workspace_num)
      focus.workspace_num = nil
      focus.workspace_name = nil
    end
  end

  -- Update focus state
  focus.state = "suspended"
  focus.suspended_at = require("fsm.utils").timestamp()
  focus.parked_containers = #parked_ids > 0 and parked_ids or nil

  local ok, save_err = store.save(focus)
  if not ok then
    return false, save_err
  end

  -- Clear current if this was current
  if state.current_slug() == slug then
    state.set_current(nil)
    nvim.clear_focus_context()
  end

  log.info("Focus suspended: %s", slug)
  return true, nil
end

--- Resume a focus
---@param slug string Focus slug
---@return boolean ok
---@return string? error
function M.resume(slug)
  if not slug then
    return false, "Focus slug required"
  end

  log.info("Resuming focus: %s", slug)

  local focus, load_err = store.load(slug)
  if not focus then
    return false, load_err
  end

  if focus.state == "archived" then
    return false, "Cannot resume archived focus"
  end

  local cfg = config.get()

  -- Check if this focus still has a valid workspace with windows
  if focus.workspace_num and i3.available() then
    local ws_exists = i3.workspace_exists(focus.workspace_num)
    local has_windows = ws_exists and #i3.get_windows_on_workspace(focus.workspace_name) > 0

    if ws_exists and has_windows then
      -- Workspace exists with windows - just switch to it
      i3.goto_workspace(focus.workspace_name)

      -- Ensure tmux session exists
      if cfg.tmux.enabled and tmux.available() then
        tmux.ensure_session(slug, focus.cwd)
      end

      -- Update state
      focus.state = "active"
      focus.resumed_at = require("fsm.utils").timestamp()
      store.save(focus)

      state.set_current(slug)
      nvim.set_focus_context(focus)
      log.info("Switched to existing workspace for focus: %s", slug)
      return true, nil
    else
      -- Workspace is gone or empty - need full resume
      log.info("Focus %s workspace missing or empty, performing full resume", slug)
      focus.workspace_num = nil
      focus.workspace_name = nil
    end
  end

  -- Full resume: allocate new workspace, restore parked windows, create tmux session

  -- Allocate workspace
  if i3.available() then
    local num, alloc_err = i3.alloc_workspace(cfg.workspace_range[1], cfg.workspace_range[2])
    if num then
      focus.workspace_num = num
      focus.workspace_name = string.format("%d:FOCUS-%s", num, focus.slug)
    else
      log.warn("Could not allocate workspace: %s", alloc_err)
    end
  end

  -- Switch to workspace
  if focus.workspace_name and i3.available() then
    i3.goto_workspace_num(focus.workspace_num)
    i3.rename_workspace(focus.workspace_name)
  end

  -- Unpark windows (only if they still exist)
  if focus.parked_containers and #focus.parked_containers > 0 and i3.available() then
    if focus.workspace_name then
      i3.unpark_windows(focus.parked_containers, focus.workspace_name)
    end
    focus.parked_containers = nil
  end

  -- Update focus state
  focus.state = "active"
  focus.resumed_at = require("fsm.utils").timestamp()

  local ok, save_err = store.save(focus)
  if not ok then
    return false, save_err
  end

  -- Set as current
  state.set_current(slug)
  nvim.set_focus_context(focus)

  -- Ensure tmux session exists and launch terminal
  if cfg.tmux.enabled and tmux.available() then
    local session = tmux.session_name(slug)
    local session_created = false

    if not tmux.session_exists(session) then
      -- Determine initial command (nvim with notes if auto_open)
      local initial_cmd = nil
      if cfg.notes.auto_open then
        local notes_path = store.notes_path(slug)
        initial_cmd = string.format("nvim %s", vim.fn.shellescape(notes_path))
      end

      local tmux_ok, tmux_err = tmux.create_session(session, focus.cwd, initial_cmd)
      if tmux_ok then
        focus.tmux_session = session
        store.save(focus)
        session_created = true
      else
        log.warn("Failed to create tmux session: %s", tmux_err)
      end
    end

    -- Launch terminal attached to tmux session
    local terminal_cmd = tmux.get_terminal_command(slug, focus.cwd, nil)
    log.debug("Launching terminal: %s", terminal_cmd)
    vim.fn.jobstart(terminal_cmd, { detach = true })
  end

  -- Open URLs if configured
  if cfg.urls and cfg.urls.auto_open_on_resume then
    local urls = store.load_urls(slug)
    if #urls > 0 and browser.available() then
      browser.open_urls(urls)
      log.debug("Opened %d URL(s) on resume", #urls)
    end
  end

  -- Load nvim state
  nvim.load_state(slug)

  log.info("Focus resumed: %s", slug)
  return true, nil
end

--- Archive a focus
---@param slug string Focus slug
---@return boolean ok
---@return string? error
function M.archive(slug)
  if not slug then
    return false, "Focus slug required"
  end

  log.info("Archiving focus: %s", slug)

  -- Suspend first if active
  local focus = store.load(slug)
  if focus and focus.state == "active" then
    local ok, err = M.suspend(slug)
    if not ok then
      log.warn("Failed to suspend before archive: %s", err)
    end
  end

  -- Kill tmux session if it exists
  local cfg = config.get()
  if cfg.tmux.enabled and tmux.available() then
    local session = tmux.session_name(slug)
    if tmux.session_exists(session) then
      local ok, err = tmux.kill_session(session)
      if ok then
        log.debug("Killed tmux session: %s", session)
      else
        log.warn("Failed to kill tmux session: %s", err)
      end
    end
  end

  local ok, err = store.archive(slug)
  if not ok then
    return false, err
  end

  -- Clear current if this was current
  if state.current_slug() == slug then
    state.set_current(nil)
    nvim.clear_focus_context()
  end

  log.info("Focus archived: %s", slug)
  return true, nil
end

--- Delete a focus permanently
---@param slug string Focus slug
---@param opts? { force: boolean }
---@return boolean ok
---@return string? error
function M.delete(slug, opts)
  opts = opts or {}
  if not slug then
    return false, "Focus slug required"
  end

  local focus = store.load(slug)
  if not focus then
    return false, "Focus not found: " .. slug
  end

  -- Require archived state unless force is specified
  if focus.state ~= "archived" and not opts.force then
    return false, "Focus must be archived before deletion. Use :FocusArchive first, or pass { force = true }"
  end

  log.info("Deleting focus: %s", slug)

  -- Kill tmux session if it exists
  local cfg = config.get()
  if cfg.tmux.enabled and tmux.available() then
    local session = tmux.session_name(slug)
    if tmux.session_exists(session) then
      tmux.kill_session(session)
    end
  end

  -- Clear current if this was current
  if state.current_slug() == slug then
    state.set_current(nil)
    nvim.clear_focus_context()
  end

  local ok, err = store.delete(slug)
  if not ok then
    return false, err
  end

  log.info("Focus deleted: %s", slug)
  return true, nil
end

--- List all focuses
---@param opts? { state: FocusState? }
---@return FocusMeta[]
function M.list(opts)
  opts = opts or {}
  if opts.state then
    return store.by_state(opts.state)
  end
  return store.list_all()
end

--- Switch from current focus to another
---@param to_slug string Focus to switch to
---@return boolean ok
---@return string? error
function M.switch(to_slug)
  local current = state.current_slug()

  -- Suspend current if exists
  if current then
    local ok, err = M.suspend(current)
    if not ok then
      log.warn("Failed to suspend current focus: %s", err)
      -- Continue anyway
    end
  end

  -- Resume target
  return M.resume(to_slug)
end

--- Get status of current focus
---@return table status
function M.status()
  local current = state.current()
  local result = {
    has_focus = current ~= nil,
    focus = current,
    i3_available = i3.available(),
    tmux_available = tmux.available(),
  }

  if current and i3.available() then
    -- Check for drift (windows without marks, windows on wrong workspace, etc.)
    local marked = i3.find_by_mark("^focus:" .. current.slug .. "$")
    result.marked_windows = #marked
  end

  return result
end

--- Open notes for current or specified focus
---@param slug? string Focus slug (defaults to current)
---@return boolean ok
---@return string? error
function M.notes(slug)
  slug = slug or state.current_slug()
  if not slug then
    return false, "No focus specified"
  end

  if not store.exists(slug) then
    return false, "Focus not found: " .. slug
  end

  nvim.open_focus_files(slug, { notes = true, todo = false })
  return true, nil
end

--- Open todo for current or specified focus
---@param slug? string Focus slug (defaults to current)
---@return boolean ok
---@return string? error
function M.todo(slug)
  slug = slug or state.current_slug()
  if not slug then
    return false, "No focus specified"
  end

  if not store.exists(slug) then
    return false, "Focus not found: " .. slug
  end

  nvim.open_focus_files(slug, { notes = false, todo = true })
  return true, nil
end

--- Edit URLs file for current or specified focus
---@param slug? string Focus slug (defaults to current)
---@return boolean ok
---@return string? error
function M.edit_urls(slug)
  slug = slug or state.current_slug()
  if not slug then
    return false, "No focus specified"
  end

  if not store.exists(slug) then
    return false, "Focus not found: " .. slug
  end

  local path = store.urls_path(slug)
  vim.cmd("edit " .. vim.fn.fnameescape(path))
  return true, nil
end

--- Add a quick note to focus without opening the file
---@param message string Note message
---@param slug? string Focus slug (defaults to current)
---@return boolean ok
---@return string? error
function M.quick_note(message, slug)
  slug = slug or state.current_slug()
  if not slug then
    return false, "No focus specified"
  end

  if not message or message == "" then
    return false, "Note message required"
  end

  if not store.exists(slug) then
    return false, "Focus not found: " .. slug
  end

  local path = store.notes_path(slug)
  local timestamp = os.date("%Y-%m-%d %H:%M")
  local note_line = string.format("\n- [%s] %s\n", timestamp, message)

  -- Append to file
  local file = io.open(path, "a")
  if not file then
    return false, "Failed to open notes file"
  end
  file:write(note_line)
  file:close()

  log.info("Added note to %s: %s", slug, message)
  return true, nil
end

--- Add URLs to current focus
---@param urls string[]
---@param slug? string Focus slug (defaults to current)
---@return boolean ok
---@return string? error
function M.add_urls(urls, slug)
  slug = slug or state.current_slug()
  if not slug then
    return false, "No focus specified"
  end

  if not store.exists(slug) then
    return false, "Focus not found: " .. slug
  end

  local existing = store.load_urls(slug)
  local added = 0
  for _, url in ipairs(urls) do
    if browser.is_valid_url(url) then
      -- Avoid duplicates
      local already_exists = false
      for _, existing_url in ipairs(existing) do
        if existing_url == url then
          already_exists = true
          break
        end
      end
      if not already_exists then
        table.insert(existing, url)
        added = added + 1
      end
    end
  end

  if added > 0 then
    local ok, err = store.save_urls(slug, existing)
    if ok then
      log.info("Added %d URL(s) to %s", added, slug)
    end
    return ok, err
  end

  return true, nil
end

--- Add a single URL to current focus
---@param url string
---@param slug? string Focus slug (defaults to current)
---@return boolean ok
---@return string? error
function M.add_url(url, slug)
  if not url or url == "" then
    return false, "URL required"
  end
  if not browser.is_valid_url(url) then
    return false, "Invalid URL (must start with http:// or https://)"
  end
  return M.add_urls({ url }, slug)
end

--- Open URLs for a focus in browser
---@param slug? string Focus slug (defaults to current)
---@return boolean ok
---@return string? error
function M.open_urls(slug)
  slug = slug or state.current_slug()
  if not slug then
    return false, "No focus specified"
  end

  local focus = store.load(slug)
  if not focus then
    return false, "Focus not found: " .. slug
  end

  local urls = store.load_urls(slug)
  if #urls == 0 then
    return false, "No URLs saved for this focus"
  end

  if not browser.available() then
    return false, "Browser not available"
  end

  -- Switch to focus workspace before opening browser
  if focus.workspace_name and i3.available() then
    i3.goto_workspace(focus.workspace_name)
  end

  local ok, err = browser.open_urls(urls)
  if ok then
    log.info("Opened %d URL(s) for %s", #urls, slug)
  end
  return ok, err
end

--- List URLs for a focus
---@param slug? string Focus slug (defaults to current)
---@return string[]? urls
---@return string? error
function M.list_urls(slug)
  slug = slug or state.current_slug()
  if not slug then
    return nil, "No focus specified"
  end

  if not store.exists(slug) then
    return nil, "Focus not found: " .. slug
  end

  return store.load_urls(slug), nil
end

--- Repair/reconcile focus state with actual system state
--- Useful after a crash or power cycle
---@param opts? { dry_run: boolean }
---@return table results Report of what was fixed
function M.repair(opts)
  opts = opts or {}
  local dry_run = opts.dry_run or false

  local results = {
    checked = 0,
    fixed = 0,
    issues = {},
  }

  local cfg = config.get()
  local focuses = store.list_all()

  for _, focus in ipairs(focuses) do
    results.checked = results.checked + 1

    if focus.state == "active" then
      local issues_found = {}

      -- Check if workspace exists
      if focus.workspace_num and i3.available() then
        if not i3.workspace_exists(focus.workspace_num) then
          table.insert(issues_found, "workspace " .. focus.workspace_num .. " does not exist")
        end
      end

      -- Check if tmux session exists
      if cfg.tmux.enabled and tmux.available() then
        local session = tmux.session_name(focus.slug)
        if not tmux.session_exists(session) then
          table.insert(issues_found, "tmux session '" .. session .. "' does not exist")
        end
      end

      -- If issues found, fix them
      if #issues_found > 0 then
        table.insert(results.issues, {
          slug = focus.slug,
          name = focus.name,
          problems = issues_found,
        })

        if not dry_run then
          -- Reset focus to suspended state, clear stale workspace info
          focus.state = "suspended"
          focus.workspace_num = nil
          focus.workspace_name = nil
          focus.parked_containers = nil
          focus.tmux_session = nil

          local ok, err = store.save(focus)
          if ok then
            results.fixed = results.fixed + 1
            log.info("Repaired focus: %s (reset to suspended)", focus.slug)
          else
            log.error("Failed to repair focus %s: %s", focus.slug, err)
          end
        end
      end
    end
  end

  return results
end

--- Get status of all focuses including their actual resource state
---@return table[] status_list
function M.health_check()
  local cfg = config.get()
  local focuses = store.list_all()
  local status_list = {}

  for _, focus in ipairs(focuses) do
    local status = {
      slug = focus.slug,
      name = focus.name,
      state = focus.state,
      workspace_num = focus.workspace_num,
      workspace_name = focus.workspace_name,
      workspace_exists = false,
      tmux_session = focus.tmux_session,
      tmux_exists = false,
      healthy = true,
      issues = {},
    }

    if focus.state == "active" then
      -- Check workspace
      if focus.workspace_num and i3.available() then
        status.workspace_exists = i3.workspace_exists(focus.workspace_num)
        if not status.workspace_exists then
          status.healthy = false
          table.insert(status.issues, "workspace missing")
        end
      end

      -- Check tmux
      if cfg.tmux.enabled and tmux.available() then
        local session = tmux.session_name(focus.slug)
        status.tmux_exists = tmux.session_exists(session)
        if not status.tmux_exists then
          status.healthy = false
          table.insert(status.issues, "tmux session missing")
        end
      end
    elseif focus.state == "suspended" then
      -- Suspended focuses are healthy if they have valid metadata
      status.healthy = true
    elseif focus.state == "archived" then
      -- Archived focuses are always healthy
      status.healthy = true
    end

    table.insert(status_list, status)
  end

  return status_list
end

return M
