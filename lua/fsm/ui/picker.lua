local store = require("fsm.store")
local state = require("fsm.state")

local M = {}

--- Check if Telescope is available
---@return boolean
function M.telescope_available()
  local ok = pcall(require, "telescope")
  return ok
end

--- Pick a focus using Telescope
---@param callback fun(focus: FocusMeta?)
---@param opts? { filter_state: FocusState?, include_archived: boolean? }
function M.pick_focus(callback, opts)
  opts = opts or {}

  if not M.telescope_available() then
    M.pick_focus_builtin(callback, opts)
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  -- Get focuses
  local focuses = store.list_all()
  local items = {}

  for _, focus in ipairs(focuses) do
    local include = true
    if opts.filter_state and focus.state ~= opts.filter_state then
      include = false
    end
    if not opts.include_archived and focus.state == "archived" then
      include = false
    end
    if include then
      table.insert(items, focus)
    end
  end

  if #items == 0 then
    vim.notify("[FSM] No focuses available", vim.log.levels.INFO)
    callback(nil)
    return
  end

  local current = state.current_slug()

  pickers
    .new({}, {
      prompt_title = "Switch Focus",
      finder = finders.new_table({
        results = items,
        entry_maker = function(focus)
          local is_current = focus.slug == current
          local icon = ({ active = "●", suspended = "○", archived = "◌" })[focus.state] or "?"
          local current_marker = is_current and " *" or ""
          local display = string.format("%s %s (%s)%s", icon, focus.name, focus.state, current_marker)
          return {
            value = focus,
            display = display,
            ordinal = focus.name .. " " .. focus.slug,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            callback(selection.value)
          else
            callback(nil)
          end
        end)
        return true
      end,
    })
    :find()
end

--- Builtin picker (fallback when Telescope not available)
---@param callback fun(focus: FocusMeta?)
---@param opts? table
function M.pick_focus_builtin(callback, opts)
  opts = opts or {}

  local focuses = store.list_all()
  local items = {}

  for _, focus in ipairs(focuses) do
    local include = true
    if opts.filter_state and focus.state ~= opts.filter_state then
      include = false
    end
    if not opts.include_archived and focus.state == "archived" then
      include = false
    end
    if include then
      table.insert(items, focus)
    end
  end

  if #items == 0 then
    vim.notify("[FSM] No focuses available", vim.log.levels.INFO)
    callback(nil)
    return
  end

  -- Build menu items
  local menu_items = {}
  local current = state.current_slug()

  for i, focus in ipairs(items) do
    local is_current = focus.slug == current
    local icon = ({ active = "●", suspended = "○", archived = "◌" })[focus.state] or "?"
    local current_marker = is_current and " *" or ""
    table.insert(menu_items, string.format("%d. %s %s (%s)%s", i, icon, focus.name, focus.state, current_marker))
  end

  vim.ui.select(menu_items, {
    prompt = "Select focus:",
  }, function(choice, idx)
    if choice and idx then
      callback(items[idx])
    else
      callback(nil)
    end
  end)
end

--- Pick from suspended focuses only
---@param callback fun(focus: FocusMeta?)
function M.pick_suspended(callback)
  M.pick_focus(callback, { filter_state = "suspended" })
end

--- Pick from active focuses only
---@param callback fun(focus: FocusMeta?)
function M.pick_active(callback)
  M.pick_focus(callback, { filter_state = "active" })
end

return M
