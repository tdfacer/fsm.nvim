local config = require("fsm.config")
local utils = require("fsm.utils")
local log = require("fsm.log")

local M = {}

--- Ensure foci directory exists
---@return boolean ok
---@return string? error
local function ensure_foci_dir()
  local dir = config.foci_dir()
  if not utils.path_exists(dir) then
    return utils.mkdir_p(dir)
  end
  return true, nil
end

--- Get path to meta.json for a focus
---@param slug string
---@return string
local function meta_path(slug)
  return config.focus_dir(slug) .. "/meta.json"
end

--- List all focus slugs
---@return string[]
function M.list()
  local ok, err = ensure_foci_dir()
  if not ok then
    log.error("Failed to ensure foci directory: %s", err)
    return {}
  end
  return utils.list_dirs(config.foci_dir())
end

--- Check if a focus exists
---@param slug string
---@return boolean
function M.exists(slug)
  return utils.path_exists(meta_path(slug))
end

--- Load focus metadata
---@param slug string
---@return FocusMeta? focus
---@return string? error
function M.load(slug)
  local path = meta_path(slug)
  local content, err = utils.read_file(path)
  if not content then
    return nil, err
  end

  local ok, meta = pcall(vim.json.decode, content)
  if not ok then
    return nil, "Failed to parse meta.json: " .. tostring(meta)
  end

  return meta, nil
end

--- Save focus metadata
---@param focus FocusMeta
---@return boolean ok
---@return string? error
function M.save(focus)
  local ok, err = ensure_foci_dir()
  if not ok then
    return false, err
  end

  local focus_dir = config.focus_dir(focus.slug)
  if not utils.path_exists(focus_dir) then
    ok, err = utils.mkdir_p(focus_dir)
    if not ok then
      return false, err
    end
  end

  -- Update timestamp
  focus.updated_at = utils.timestamp()

  local content = vim.json.encode(focus)
  local path = meta_path(focus.slug)

  ok, err = utils.write_file(path, content)
  if not ok then
    return false, err
  end

  log.debug("Saved focus: %s", focus.slug)
  return true, nil
end

--- Create a new focus
---@param name string
---@param workspace_num? number
---@return FocusMeta? focus
---@return string? error
function M.create(name, workspace_num)
  local valid, err = utils.validate_name(name)
  if not valid then
    return nil, err
  end

  local slug = utils.slugify(name)
  if M.exists(slug) then
    return nil, "Focus already exists: " .. slug
  end

  local now = utils.timestamp()
  ---@type FocusMeta
  local focus = {
    slug = slug,
    name = name,
    state = "active",
    workspace_num = workspace_num,
    workspace_name = workspace_num and string.format("%d:FOCUS-%s", workspace_num, slug) or nil,
    created_at = now,
    updated_at = now,
    cwd = vim.fn.getcwd(),
  }

  local ok
  ok, err = M.save(focus)
  if not ok then
    return nil, err
  end

  -- Create initial files
  local focus_dir = config.focus_dir(slug)
  utils.write_file(focus_dir .. "/notes.md", "# " .. name .. "\n\n")
  utils.write_file(focus_dir .. "/todo.md", "# " .. name .. " - TODO\n\n- [ ] \n")
  utils.write_file(focus_dir .. "/urls.txt", "")

  log.info("Created focus: %s", slug)
  return focus, nil
end

--- Delete a focus (removes directory)
---@param slug string
---@return boolean ok
---@return string? error
function M.delete(slug)
  if not M.exists(slug) then
    return false, "Focus not found: " .. slug
  end

  local focus_dir = config.focus_dir(slug)
  local ok = vim.fn.delete(focus_dir, "rf")
  if ok ~= 0 then
    return false, "Failed to delete focus directory"
  end

  log.info("Deleted focus: %s", slug)
  return true, nil
end

--- Archive a focus
---@param slug string
---@return boolean ok
---@return string? error
function M.archive(slug)
  local focus, err = M.load(slug)
  if not focus then
    return false, err
  end

  focus.state = "archived"
  focus.workspace_num = nil
  focus.workspace_name = nil

  local ok
  ok, err = M.save(focus)
  if not ok then
    return false, err
  end

  log.info("Archived focus: %s", slug)
  return true, nil
end

--- List all focuses with full metadata
---@return FocusMeta[]
function M.list_all()
  local slugs = M.list()
  local focuses = {}
  for _, slug in ipairs(slugs) do
    local focus = M.load(slug)
    if focus then
      table.insert(focuses, focus)
    end
  end
  return focuses
end

--- Get focuses by state
---@param state FocusState
---@return FocusMeta[]
function M.by_state(state)
  local all = M.list_all()
  local result = {}
  for _, focus in ipairs(all) do
    if focus.state == state then
      table.insert(result, focus)
    end
  end
  return result
end

--- Get active focuses
---@return FocusMeta[]
function M.active()
  return M.by_state("active")
end

--- Get suspended focuses
---@return FocusMeta[]
function M.suspended()
  return M.by_state("suspended")
end

--- Save URLs for a focus
---@param slug string
---@param urls string[]
---@return boolean ok
---@return string? error
function M.save_urls(slug, urls)
  local path = config.focus_dir(slug) .. "/urls.txt"
  local content = table.concat(urls, "\n")
  return utils.write_file(path, content)
end

--- Load URLs for a focus
---@param slug string
---@return string[]
function M.load_urls(slug)
  local path = config.focus_dir(slug) .. "/urls.txt"
  local content = utils.read_file(path)
  if not content or content == "" then
    return {}
  end
  local urls = {}
  for line in content:gmatch("[^\n]+") do
    local trimmed = utils.trim(line)
    if trimmed ~= "" then
      table.insert(urls, trimmed)
    end
  end
  return urls
end

--- Get notes file path
---@param slug string
---@return string
function M.notes_path(slug)
  return config.focus_dir(slug) .. "/notes.md"
end

--- Get todo file path
---@param slug string
---@return string
function M.todo_path(slug)
  return config.focus_dir(slug) .. "/todo.md"
end

--- Get nvim session file path
---@param slug string
---@return string
function M.session_path(slug)
  return config.focus_dir(slug) .. "/nvim_session.vim"
end

--- Get nvim state file path
---@param slug string
---@return string
function M.nvim_state_path(slug)
  return config.focus_dir(slug) .. "/nvim_state.json"
end

--- Get i3 layout file path
---@param slug string
---@return string
function M.i3_layout_path(slug)
  return config.focus_dir(slug) .. "/i3_layout.json"
end

--- Get i3 marks file path
---@param slug string
---@return string
function M.i3_marks_path(slug)
  return config.focus_dir(slug) .. "/i3_marks.json"
end

return M
