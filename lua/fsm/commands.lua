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

  if i3.available() then
    -- Save marks
    i3.save_marks(slug)

    -- Get browsers to park from the focus's workspace
    if cfg.suspend_policy.browsers == "park" and focus.workspace_name then
      local browsers = i3.get_browsers_on_workspace(focus.workspace_name)
      if #browsers > 0 then
        parked_ids = i3.park_windows(browsers)
        log.debug("Parked %d browser windows", #parked_ids)
      end
    end
  end

  -- Update focus state
  focus.state = "suspended"
  focus.suspended_at = require("fsm.utils").timestamp()
  focus.parked_containers = parked_ids

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

  -- If we're resuming something that was active, still set context
  if focus.state == "active" and focus.workspace_name then
    -- Just switch to the workspace
    if i3.available() then
      i3.goto_workspace(focus.workspace_name)
    end
    state.set_current(slug)
    nvim.set_focus_context(focus)
    return true, nil
  end

  -- Allocate workspace if needed
  if not focus.workspace_num and i3.available() then
    local cfg = config.get()
    local num, err = i3.alloc_workspace(cfg.workspace_range[1], cfg.workspace_range[2])
    if num then
      focus.workspace_num = num
      focus.workspace_name = string.format("%d:FOCUS-%s", num, focus.slug)
    else
      log.warn("Could not allocate workspace: %s", err)
    end
  end

  -- Switch to workspace
  if focus.workspace_name and i3.available() then
    i3.goto_workspace_num(focus.workspace_num)
    i3.rename_workspace(focus.workspace_name)
  end

  -- Unpark windows
  if focus.parked_containers and #focus.parked_containers > 0 and i3.available() then
    if focus.workspace_name then
      i3.unpark_windows(focus.parked_containers, focus.workspace_name)
    end
    focus.parked_containers = nil
  end

  -- Open URLs if configured
  local cfg = config.get()
  if cfg.urls and cfg.urls.auto_open_on_resume then
    local urls = store.load_urls(slug)
    if #urls > 0 and browser.available() then
      browser.open_urls(urls)
      log.debug("Opened %d URL(s) on resume", #urls)
    end
  end

  -- Load nvim state
  nvim.load_state(slug)

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

  -- Ensure tmux session
  local cfg = config.get()
  if cfg.tmux.enabled and tmux.available() then
    tmux.ensure_session(focus.slug, focus.cwd)
  end

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

return M
