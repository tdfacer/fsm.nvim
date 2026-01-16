local state = require("fsm.state")

local M = {}

--- Get statusline component
---@return string
function M.statusline()
  local current = state.current()
  if not current then
    return ""
  end

  local icon = ({ active = "●", suspended = "○", archived = "◌" })[current.state] or "?"
  return string.format(" %s %s ", icon, current.name)
end

--- Get statusline component with more details
---@return string
function M.statusline_full()
  local current = state.current()
  if not current then
    return ""
  end

  local icon = ({ active = "●", suspended = "○", archived = "◌" })[current.state] or "?"
  local ws = current.workspace_name and (" [" .. current.workspace_num .. "]") or ""
  return string.format(" %s %s%s ", icon, current.name, ws)
end

--- Get focus name for statusline
---@return string
function M.focus_name()
  local current = state.current()
  if not current then
    return ""
  end
  return current.name
end

--- Get focus state icon
---@return string
function M.focus_icon()
  local current = state.current()
  if not current then
    return ""
  end
  return ({ active = "●", suspended = "○", archived = "◌" })[current.state] or "?"
end

--- Check if there is an active focus
---@return boolean
function M.has_focus()
  return state.has_current()
end

--- Lualine component configuration
---@return table
function M.lualine_component()
  return {
    M.statusline,
    cond = M.has_focus,
    color = function()
      local current = state.current()
      if current and current.state == "active" then
        return { fg = "#98c379" } -- Green for active
      end
      return { fg = "#e5c07b" } -- Yellow for suspended
    end,
  }
end

return M
