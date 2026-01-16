local config = require("fsm.config")
local log = require("fsm.log")

local M = {}

--- Check if tmux is available
---@return boolean
function M.available()
  local result = vim.fn.system("which tmux")
  return vim.v.shell_error == 0 and result ~= ""
end

--- Check if running inside tmux
---@return boolean
function M.inside_tmux()
  return vim.env.TMUX ~= nil
end

--- Get session name for a focus
---@param slug string
---@return string
function M.session_name(slug)
  local cfg = config.get()
  return cfg.tmux.session_prefix .. slug
end

--- Check if a tmux session exists
---@param name string Session name
---@return boolean
function M.session_exists(name)
  vim.fn.system(string.format("tmux has-session -t %s 2>/dev/null", vim.fn.shellescape(name)))
  return vim.v.shell_error == 0
end

--- Create a new tmux session
---@param name string Session name
---@param cwd? string Working directory
---@return boolean ok
---@return string? error
function M.create_session(name, cwd)
  local cmd = "tmux new-session -d -s " .. vim.fn.shellescape(name)
  if cwd then
    cmd = cmd .. " -c " .. vim.fn.shellescape(cwd)
  end

  log.debug("Running: %s", cmd)
  vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    return false, "Failed to create tmux session: " .. name
  end

  log.debug("Created tmux session: %s", name)
  return true, nil
end

--- Kill a tmux session
---@param name string Session name
---@return boolean ok
---@return string? error
function M.kill_session(name)
  vim.fn.system(string.format("tmux kill-session -t %s 2>/dev/null", vim.fn.shellescape(name)))
  if vim.v.shell_error ~= 0 then
    return false, "Failed to kill tmux session: " .. name
  end
  log.debug("Killed tmux session: %s", name)
  return true, nil
end

--- Get command to attach to a session
---@param name string Session name
---@return string
function M.get_attach_command(name)
  return string.format("tmux new-session -A -s %s", vim.fn.shellescape(name))
end

--- List all tmux sessions
---@return string[]
function M.list_sessions()
  local result = vim.fn.system("tmux list-sessions -F '#{session_name}' 2>/dev/null")
  if vim.v.shell_error ~= 0 then
    return {}
  end

  local sessions = {}
  for line in result:gmatch("[^\n]+") do
    table.insert(sessions, line)
  end
  return sessions
end

--- List focus-related sessions
---@return string[]
function M.list_focus_sessions()
  local cfg = config.get()
  local prefix = cfg.tmux.session_prefix
  local all = M.list_sessions()
  local focus_sessions = {}

  for _, session in ipairs(all) do
    if session:sub(1, #prefix) == prefix then
      table.insert(focus_sessions, session)
    end
  end

  return focus_sessions
end

--- Get the shell command to launch a terminal with tmux
---@param slug string Focus slug
---@param cwd? string Working directory
---@return string
function M.get_terminal_command(slug, cwd)
  local cfg = config.get()
  local session = M.session_name(slug)
  local attach_cmd = M.get_attach_command(session)

  -- If session doesn't exist, create it first
  if not M.session_exists(session) then
    M.create_session(session, cwd)
  end

  -- Format terminal command: terminal_template expects (class, command)
  return string.format(cfg.apps.terminal, slug, attach_cmd)
end

--- Ensure session exists for a focus
---@param slug string Focus slug
---@param cwd? string Working directory
---@return boolean ok
---@return string? error
function M.ensure_session(slug, cwd)
  local cfg = config.get()
  if not cfg.tmux.enabled then
    return true, nil
  end

  if not M.available() then
    return false, "tmux is not available"
  end

  local session = M.session_name(slug)
  if M.session_exists(session) then
    log.debug("tmux session already exists: %s", session)
    return true, nil
  end

  return M.create_session(session, cwd)
end

--- Send keys to a tmux session
---@param name string Session name
---@param keys string Keys to send
---@return boolean ok
function M.send_keys(name, keys)
  vim.fn.system(string.format("tmux send-keys -t %s %s", vim.fn.shellescape(name), vim.fn.shellescape(keys)))
  return vim.v.shell_error == 0
end

return M
