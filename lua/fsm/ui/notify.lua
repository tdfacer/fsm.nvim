local M = {}

--- Notification levels
M.levels = {
  trace = vim.log.levels.TRACE,
  debug = vim.log.levels.DEBUG,
  info = vim.log.levels.INFO,
  warn = vim.log.levels.WARN,
  error = vim.log.levels.ERROR,
}

--- Show a notification
---@param msg string
---@param level? number vim.log.levels.*
---@param opts? table Additional options
function M.notify(msg, level, opts)
  level = level or vim.log.levels.INFO
  opts = opts or {}

  -- Prefix with FSM
  local prefix = "[FSM] "
  if opts.title then
    prefix = "[FSM:" .. opts.title .. "] "
  end

  vim.notify(prefix .. msg, level)
end

--- Info notification
---@param msg string
---@param opts? table
function M.info(msg, opts)
  M.notify(msg, vim.log.levels.INFO, opts)
end

--- Warning notification
---@param msg string
---@param opts? table
function M.warn(msg, opts)
  M.notify(msg, vim.log.levels.WARN, opts)
end

--- Error notification
---@param msg string
---@param opts? table
function M.error(msg, opts)
  M.notify(msg, vim.log.levels.ERROR, opts)
end

--- Success notification (info level with success title)
---@param msg string
function M.success(msg)
  M.notify(msg, vim.log.levels.INFO, { title = "Success" })
end

--- Notify about focus action
---@param action string Action name (started, suspended, resumed, etc.)
---@param focus_name string Focus name
function M.focus_action(action, focus_name)
  M.info(string.format("Focus %s: %s", action, focus_name))
end

return M
