local store = require("fsm.store")
local utils = require("fsm.utils")
local log = require("fsm.log")

local M = {}

--- Save Neovim session for a focus
---@param slug string Focus slug
---@return boolean ok
---@return string? error
function M.save_session(slug)
  local session_path = store.session_path(slug)

  -- Ensure directory exists
  local focus_dir = vim.fn.fnamemodify(session_path, ":h")
  if not utils.path_exists(focus_dir) then
    local ok, err = utils.mkdir_p(focus_dir)
    if not ok then
      return false, err
    end
  end

  -- Save session using mksession
  local ok, err = pcall(vim.cmd, "mksession! " .. vim.fn.fnameescape(session_path))
  if not ok then
    return false, "Failed to save session: " .. tostring(err)
  end

  log.debug("Saved nvim session for %s", slug)
  return true, nil
end

--- Load Neovim session for a focus
---@param slug string Focus slug
---@return boolean ok
---@return string? error
function M.load_session(slug)
  local session_path = store.session_path(slug)

  if not utils.path_exists(session_path) then
    return false, "Session file not found"
  end

  local ok, err = pcall(vim.cmd, "source " .. vim.fn.fnameescape(session_path))
  if not ok then
    return false, "Failed to load session: " .. tostring(err)
  end

  log.debug("Loaded nvim session for %s", slug)
  return true, nil
end

--- Save custom nvim state (buffers, cwd, etc.)
---@param slug string Focus slug
---@return boolean ok
---@return string? error
function M.save_state(slug)
  local state = {
    cwd = vim.fn.getcwd(),
    buffers = {},
  }

  -- Collect buffer info
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name ~= "" and vim.fn.filereadable(name) == 1 then
        table.insert(state.buffers, {
          name = name,
          line = vim.fn.line(".", vim.fn.bufwinid(bufnr)),
        })
      end
    end
  end

  local path = store.nvim_state_path(slug)
  local content = vim.json.encode(state)
  local ok, err = utils.write_file(path, content)
  if not ok then
    return false, err
  end

  log.debug("Saved nvim state for %s", slug)
  return true, nil
end

--- Load custom nvim state
---@param slug string Focus slug
---@return boolean ok
---@return string? error
function M.load_state(slug)
  local path = store.nvim_state_path(slug)
  local content, err = utils.read_file(path)
  if not content then
    return false, err
  end

  local ok, state = pcall(vim.json.decode, content)
  if not ok then
    return false, "Failed to parse nvim state"
  end

  -- Change to saved cwd
  if state.cwd and utils.is_directory(state.cwd) then
    vim.cmd("cd " .. vim.fn.fnameescape(state.cwd))
  end

  log.debug("Loaded nvim state for %s", slug)
  return true, nil
end

--- Set focus context (environment, variables)
---@param focus FocusMeta
function M.set_focus_context(focus)
  -- Set global variable for statusline etc.
  vim.g.fsm_current_focus = focus.slug
  vim.g.fsm_current_focus_name = focus.name

  -- Set buffer-local cwd if different
  if focus.cwd and utils.is_directory(focus.cwd) then
    vim.cmd("cd " .. vim.fn.fnameescape(focus.cwd))
  end

  log.debug("Set focus context for %s", focus.slug)
end

--- Clear focus context
function M.clear_focus_context()
  vim.g.fsm_current_focus = nil
  vim.g.fsm_current_focus_name = nil
  log.debug("Cleared focus context")
end

--- Open focus files (notes, todo)
---@param slug string Focus slug
---@param opts? { notes: boolean, todo: boolean }
function M.open_focus_files(slug, opts)
  opts = opts or { notes = true, todo = false }

  if opts.notes then
    local notes_path = store.notes_path(slug)
    if utils.path_exists(notes_path) then
      vim.cmd("edit " .. vim.fn.fnameescape(notes_path))
      log.debug("Opened notes for %s", slug)
    end
  end

  if opts.todo then
    local todo_path = store.todo_path(slug)
    if utils.path_exists(todo_path) then
      vim.cmd("vsplit " .. vim.fn.fnameescape(todo_path))
      log.debug("Opened todo for %s", slug)
    end
  end
end

--- Get list of focus-related files
---@param slug string Focus slug
---@return string[]
function M.get_focus_files(slug)
  return {
    store.notes_path(slug),
    store.todo_path(slug),
  }
end

--- Check if any focus files are open
---@param slug string Focus slug
---@return boolean
function M.has_focus_files_open(slug)
  local focus_files = M.get_focus_files(slug)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(bufnr)
    for _, focus_file in ipairs(focus_files) do
      if name == focus_file then
        return true
      end
    end
  end
  return false
end

return M
