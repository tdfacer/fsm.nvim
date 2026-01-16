local store = require("fsm.store")
local log = require("fsm.log")

local M = {}

--- Runtime state
---@class RuntimeState
---@field current_slug? string Currently active focus slug
---@field last_slug? string Previously active focus slug

---@type RuntimeState
local state = {
  current_slug = nil,
  last_slug = nil,
}

--- Get current focus slug
---@return string?
function M.current_slug()
  return state.current_slug
end

--- Get current focus metadata
---@return FocusMeta?
function M.current()
  if not state.current_slug then
    return nil
  end
  return store.load(state.current_slug)
end

--- Set current focus
---@param slug? string
function M.set_current(slug)
  if state.current_slug then
    state.last_slug = state.current_slug
  end
  state.current_slug = slug
  if slug then
    log.debug("Current focus set to: %s", slug)
  else
    log.debug("Current focus cleared")
  end
end

--- Get last focus slug
---@return string?
function M.last_slug()
  return state.last_slug
end

--- Get last focus metadata
---@return FocusMeta?
function M.last()
  if not state.last_slug then
    return nil
  end
  return store.load(state.last_slug)
end

--- Clear runtime state
function M.clear()
  state.current_slug = nil
  state.last_slug = nil
  log.debug("Runtime state cleared")
end

--- Check if there is an active focus
---@return boolean
function M.has_current()
  return state.current_slug ~= nil
end

--- Detect current focus from i3 workspace
--- This checks if we're on a FOCUS-* workspace and sets state accordingly
---@param workspaces table[] Output from i3 driver get_workspaces
function M.detect_from_workspace(workspaces)
  for _, ws in ipairs(workspaces) do
    if ws.focused then
      local slug = ws.name:match("^%d+:FOCUS%-(.+)$")
      if slug then
        if state.current_slug ~= slug then
          log.debug("Detected focus from workspace: %s", slug)
          M.set_current(slug)
        end
        return
      end
    end
  end
  -- Not on a focus workspace
  if state.current_slug then
    log.debug("No longer on focus workspace")
  end
end

return M
