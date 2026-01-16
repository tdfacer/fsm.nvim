local utils = require("fsm.utils")

local M = {}

---@type FocusConfig
local defaults = {
  workspace_range = { 10, 19 },
  parking_workspace = 99,
  suspend_policy = {
    terminals = "keep",
    browsers = "park",
  },
  apps = {
    terminal = 'alacritty --class "focus-%s,Alacritty" -e %s',
    browser = "firefox %s",
  },
  tmux = {
    enabled = true,
    session_prefix = "focus/",
  },
  notes = {
    auto_open = true,
  },
  redact_env_vars = { ".*SECRET.*", ".*TOKEN.*", ".*KEY.*", ".*PASSWORD.*" },
  data_dir = vim.fn.expand("~/.local/share/focus"),
}

---@type FocusConfig
M.config = vim.deepcopy(defaults)

--- Setup configuration with user overrides
---@param opts? table
function M.setup(opts)
  opts = opts or {}
  M.config = utils.deep_merge(defaults, opts)

  -- Expand data_dir path
  M.config.data_dir = vim.fn.expand(M.config.data_dir)
end

--- Get current configuration
---@return FocusConfig
function M.get()
  return M.config
end

--- Get foci directory path
---@return string
function M.foci_dir()
  return M.config.data_dir .. "/foci"
end

--- Get focus directory path
---@param slug string
---@return string
function M.focus_dir(slug)
  return M.foci_dir() .. "/" .. slug
end

return M
