local M = {}

---@alias LogLevel "trace" | "debug" | "info" | "warn" | "error"

local levels = {
  trace = 0,
  debug = 1,
  info = 2,
  warn = 3,
  error = 4,
}

local current_level = "info"

--- Set the log level
---@param level LogLevel
function M.set_level(level)
  if levels[level] then
    current_level = level
  end
end

--- Get current log level
---@return LogLevel
function M.get_level()
  return current_level
end

--- Check if a level should be logged
---@param level LogLevel
---@return boolean
local function should_log(level)
  return levels[level] >= levels[current_level]
end

--- Format log message
---@param level LogLevel
---@param msg string
---@param ... any
---@return string
local function format_msg(level, msg, ...)
  local args = { ... }
  if #args > 0 then
    msg = string.format(msg, ...)
  end
  return string.format("[FSM %s] %s", level:upper(), msg)
end

--- Log at trace level
---@param msg string
---@param ... any
function M.trace(msg, ...)
  if should_log("trace") then
    vim.notify(format_msg("trace", msg, ...), vim.log.levels.TRACE)
  end
end

--- Log at debug level
---@param msg string
---@param ... any
function M.debug(msg, ...)
  if should_log("debug") then
    vim.notify(format_msg("debug", msg, ...), vim.log.levels.DEBUG)
  end
end

--- Log at info level
---@param msg string
---@param ... any
function M.info(msg, ...)
  if should_log("info") then
    vim.notify(format_msg("info", msg, ...), vim.log.levels.INFO)
  end
end

--- Log at warn level
---@param msg string
---@param ... any
function M.warn(msg, ...)
  if should_log("warn") then
    vim.notify(format_msg("warn", msg, ...), vim.log.levels.WARN)
  end
end

--- Log at error level
---@param msg string
---@param ... any
function M.error(msg, ...)
  if should_log("error") then
    vim.notify(format_msg("error", msg, ...), vim.log.levels.ERROR)
  end
end

return M
