local config = require("fsm.config")
local utils = require("fsm.utils")
local store = require("fsm.store")
local log = require("fsm.log")

local M = {}

--- Check if i3 is available
---@return boolean
function M.available()
  local result = vim.fn.system("which i3-msg")
  return vim.v.shell_error == 0 and result ~= ""
end

--- Run i3-msg command and return parsed JSON
---@param args string|string[]
---@return any? result
---@return string? error
local function i3_msg(args)
  local cmd
  if type(args) == "table" then
    -- Already a list of arguments
    cmd = vim.list_extend({ "i3-msg" }, args)
  elseif args:match("^%-t ") then
    -- Type query like "-t get_workspaces" - split into separate args
    local flag, msg_type = args:match("^(%-t)%s+(.+)$")
    cmd = { "i3-msg", flag, msg_type }
  else
    -- Command string - pass as single argument to avoid shell interpretation
    cmd = { "i3-msg", args }
  end

  log.debug("Running: i3-msg %s", type(args) == "table" and table.concat(args, " ") or args)
  local result = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    return nil, "i3-msg failed: " .. result
  end

  -- Try to parse as JSON
  local ok, parsed = pcall(vim.json.decode, result)
  if not ok then
    return nil, "Failed to parse i3 output: " .. result
  end

  return parsed, nil
end

--- Get all workspaces
---@return table[]? workspaces
---@return string? error
function M.get_workspaces()
  return i3_msg("-t get_workspaces")
end

--- Get the i3 tree
---@return table? tree
---@return string? error
function M.get_tree()
  return i3_msg("-t get_tree")
end

--- Find next available workspace number in range
---@param min number
---@param max number
---@return number? workspace_num
---@return string? error
function M.alloc_workspace(min, max)
  local workspaces, err = M.get_workspaces()
  if not workspaces then
    return nil, err
  end

  -- Collect used numbers
  local used = {}
  for _, ws in ipairs(workspaces) do
    used[ws.num] = true
  end

  -- Find first available
  for num = min, max do
    if not used[num] then
      return num, nil
    end
  end

  return nil, string.format("No available workspace in range %d-%d", min, max)
end

--- Go to a workspace
---@param name string
---@return boolean ok
---@return string? error
function M.goto_workspace(name)
  local result, err = i3_msg(string.format('workspace "%s"', name))
  if not result then
    return false, err
  end
  return true, nil
end

--- Go to workspace by number
---@param num number
---@return boolean ok
---@return string? error
function M.goto_workspace_num(num)
  local result, err = i3_msg(string.format("workspace number %d", num))
  if not result then
    return false, err
  end
  return true, nil
end

--- Rename current workspace
---@param new_name string
---@return boolean ok
---@return string? error
function M.rename_workspace(new_name)
  local result, err = i3_msg(string.format('rename workspace to "%s"', new_name))
  if not result then
    return false, err
  end
  return true, nil
end

--- Mark a window/container
---@param con_id number Container ID
---@param mark string Mark name
---@return boolean ok
---@return string? error
function M.mark_window(con_id, mark)
  local result, err = i3_msg(string.format('[con_id=%d] mark --add "%s"', con_id, mark))
  if not result then
    return false, err
  end
  return true, nil
end

--- Unmark a window
---@param mark string Mark name
---@return boolean ok
---@return string? error
function M.unmark(mark)
  local result, err = i3_msg(string.format('unmark "%s"', mark))
  if not result then
    return false, err
  end
  return true, nil
end

--- Find containers by mark
---@param mark_pattern string Pattern to match (regex)
---@return table[] containers
function M.find_by_mark(mark_pattern)
  local tree, err = M.get_tree()
  if not tree then
    log.error("Failed to get tree: %s", err)
    return {}
  end

  local results = {}

  local function traverse(node)
    if node.marks then
      for _, mark in ipairs(node.marks) do
        if mark:match(mark_pattern) then
          table.insert(results, {
            id = node.id,
            name = node.name,
            window = node.window,
            marks = node.marks,
            class = node.window_properties and node.window_properties.class,
            instance = node.window_properties and node.window_properties.instance,
          })
          break
        end
      end
    end
    if node.nodes then
      for _, child in ipairs(node.nodes) do
        traverse(child)
      end
    end
    if node.floating_nodes then
      for _, child in ipairs(node.floating_nodes) do
        traverse(child)
      end
    end
  end

  traverse(tree)
  return results
end

--- Find containers on a workspace
---@param workspace_name string
---@return table[] containers
function M.find_on_workspace(workspace_name)
  local tree, err = M.get_tree()
  if not tree then
    log.error("Failed to get tree: %s", err)
    return {}
  end

  local results = {}

  local function find_ws(node)
    if node.type == "workspace" and node.name == workspace_name then
      return node
    end
    if node.nodes then
      for _, child in ipairs(node.nodes) do
        local found = find_ws(child)
        if found then
          return found
        end
      end
    end
    return nil
  end

  local ws = find_ws(tree)
  if not ws then
    return results
  end

  local function collect_windows(node)
    if node.window then
      table.insert(results, {
        id = node.id,
        name = node.name,
        window = node.window,
        marks = node.marks or {},
        class = node.window_properties and node.window_properties.class,
        instance = node.window_properties and node.window_properties.instance,
      })
    end
    if node.nodes then
      for _, child in ipairs(node.nodes) do
        collect_windows(child)
      end
    end
    if node.floating_nodes then
      for _, child in ipairs(node.floating_nodes) do
        collect_windows(child)
      end
    end
  end

  collect_windows(ws)
  return results
end

--- Move container to workspace
---@param con_id number
---@param workspace string Workspace name or number
---@return boolean ok
---@return string? error
function M.move_to_workspace(con_id, workspace)
  local result, err = i3_msg(string.format('[con_id=%d] move container to workspace "%s"', con_id, workspace))
  if not result then
    return false, err
  end
  return true, nil
end

--- Park windows to parking workspace
---@param containers table[] Containers to park
---@return number[] Parked container IDs
function M.park_windows(containers)
  local cfg = config.get()
  local parked = {}

  for _, container in ipairs(containers) do
    local ok, err = M.move_to_workspace(container.id, tostring(cfg.parking_workspace))
    if ok then
      table.insert(parked, container.id)
      log.debug("Parked container %d to workspace %d", container.id, cfg.parking_workspace)
    else
      log.warn("Failed to park container %d: %s", container.id, err)
    end
  end

  return parked
end

--- Unpark windows from parking workspace
---@param container_ids number[]
---@param workspace_name string Target workspace
---@return boolean ok
function M.unpark_windows(container_ids, workspace_name)
  local success = true
  for _, con_id in ipairs(container_ids) do
    local ok, err = M.move_to_workspace(con_id, workspace_name)
    if not ok then
      log.warn("Failed to unpark container %d: %s", con_id, err)
      success = false
    else
      log.debug("Unparked container %d to %s", con_id, workspace_name)
    end
  end
  return success
end

--- Capture layout of current workspace
---@param slug string Focus slug
---@return boolean ok
---@return string? error
function M.capture_layout(slug)
  local path = store.i3_layout_path(slug)
  local cmd = string.format("i3-save-tree --workspace $(i3-msg -t get_workspaces | jq -r '.[] | select(.focused) | .name') > %s 2>/dev/null", utils.shell_escape(path))

  local result = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    log.debug("Layout capture not available or failed")
    return false, "Failed to capture layout"
  end

  log.debug("Captured layout for %s", slug)
  return true, nil
end

--- Mark all windows on current workspace with focus mark
---@param slug string Focus slug
---@return number Number of windows marked
function M.mark_focus_windows(slug)
  local workspaces, err = M.get_workspaces()
  if not workspaces then
    log.error("Failed to get workspaces: %s", err)
    return 0
  end

  local current_ws = nil
  for _, ws in ipairs(workspaces) do
    if ws.focused then
      current_ws = ws.name
      break
    end
  end

  if not current_ws then
    return 0
  end

  local containers = M.find_on_workspace(current_ws)
  local marked = 0

  for _, container in ipairs(containers) do
    -- Add focus mark
    local focus_mark = "focus:" .. slug
    local ok = M.mark_window(container.id, focus_mark)
    if ok then
      marked = marked + 1
    end

    -- Add role mark based on window class
    local role = "other"
    if container.class then
      local class = container.class:lower()
      if class:match("alacritty") or class:match("terminal") then
        role = "terminal"
      elseif class:match("firefox") or class:match("chromium") or class:match("browser") then
        role = "browser"
      end
    end
    M.mark_window(container.id, "role:" .. role)
  end

  log.debug("Marked %d windows for focus %s", marked, slug)
  return marked
end

--- Save marks for a focus
---@param slug string Focus slug
---@return boolean ok
function M.save_marks(slug)
  local containers = M.find_by_mark("^focus:" .. slug .. "$")
  local marks_data = {}

  for _, container in ipairs(containers) do
    table.insert(marks_data, {
      id = container.id,
      marks = container.marks,
      class = container.class,
      instance = container.instance,
    })
  end

  local path = store.i3_marks_path(slug)
  local content = vim.json.encode(marks_data)
  return utils.write_file(path, content)
end

--- Get browsers on a workspace
---@param workspace_name? string Workspace name (defaults to focused workspace)
---@return table[] Browser containers
function M.get_browsers_on_workspace(workspace_name)
  if not workspace_name then
    -- Fall back to focused workspace
    local workspaces, err = M.get_workspaces()
    if not workspaces then
      return {}
    end

    for _, ws in ipairs(workspaces) do
      if ws.focused then
        workspace_name = ws.name
        break
      end
    end

    if not workspace_name then
      return {}
    end
  end

  local containers = M.find_on_workspace(workspace_name)
  local browsers = {}

  for _, container in ipairs(containers) do
    if container.class then
      local class = container.class:lower()
      if class:match("firefox") or class:match("chromium") or class:match("browser") then
        table.insert(browsers, container)
      end
    end
  end

  return browsers
end

return M
