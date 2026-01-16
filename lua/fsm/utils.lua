local M = {}

--- Slugify a string for use as identifier
---@param name string
---@return string
function M.slugify(name)
  if not name or name == "" then
    return ""
  end
  local slug = name:lower()
  -- Replace spaces and underscores with hyphens
  slug = slug:gsub("[%s_]+", "-")
  -- Remove non-alphanumeric characters except hyphens
  slug = slug:gsub("[^%w%-]", "")
  -- Collapse multiple hyphens
  slug = slug:gsub("%-+", "-")
  -- Trim leading/trailing hyphens
  slug = slug:gsub("^%-+", ""):gsub("%-+$", "")
  return slug
end

--- Validate a focus name
---@param name string
---@return boolean ok
---@return string? error
function M.validate_name(name)
  if not name or name == "" then
    return false, "Name cannot be empty"
  end
  if #name > 64 then
    return false, "Name cannot exceed 64 characters"
  end
  local slug = M.slugify(name)
  if slug == "" then
    return false, "Name must contain at least one alphanumeric character"
  end
  return true, nil
end

--- Get current ISO 8601 timestamp
---@return string
function M.timestamp()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

--- Deep merge two tables (right into left)
---@param t1 table
---@param t2 table
---@return table
function M.deep_merge(t1, t2)
  local result = vim.deepcopy(t1)
  for k, v in pairs(t2) do
    if type(v) == "table" and type(result[k]) == "table" then
      result[k] = M.deep_merge(result[k], v)
    else
      result[k] = v
    end
  end
  return result
end

--- Check if a table is empty
---@param t table
---@return boolean
function M.is_empty(t)
  return next(t) == nil
end

--- Escape string for shell
---@param str string
---@return string
function M.shell_escape(str)
  return "'" .. str:gsub("'", "'\"'\"'") .. "'"
end

--- Split string by delimiter
---@param str string
---@param sep string
---@return string[]
function M.split(str, sep)
  local result = {}
  for match in (str .. sep):gmatch("(.-)" .. sep) do
    table.insert(result, match)
  end
  return result
end

--- Trim whitespace from string
---@param str string
---@return string
function M.trim(str)
  return str:match("^%s*(.-)%s*$")
end

--- Read file contents
---@param path string
---@return string? content
---@return string? error
function M.read_file(path)
  local f = io.open(path, "r")
  if not f then
    return nil, "Cannot open file: " .. path
  end
  local content = f:read("*a")
  f:close()
  return content, nil
end

--- Write content to file
---@param path string
---@param content string
---@return boolean ok
---@return string? error
function M.write_file(path, content)
  local f = io.open(path, "w")
  if not f then
    return false, "Cannot open file for writing: " .. path
  end
  f:write(content)
  f:close()
  return true, nil
end

--- Check if path exists
---@param path string
---@return boolean
function M.path_exists(path)
  local stat = vim.loop.fs_stat(path)
  return stat ~= nil
end

--- Check if path is directory
---@param path string
---@return boolean
function M.is_directory(path)
  local stat = vim.loop.fs_stat(path)
  return stat ~= nil and stat.type == "directory"
end

--- Create directory recursively
---@param path string
---@return boolean ok
---@return string? error
function M.mkdir_p(path)
  local ok = vim.fn.mkdir(path, "p")
  if ok == 0 then
    return false, "Failed to create directory: " .. path
  end
  return true, nil
end

--- Get list of subdirectories
---@param path string
---@return string[]
function M.list_dirs(path)
  local dirs = {}
  local handle = vim.loop.fs_scandir(path)
  if not handle then
    return dirs
  end
  while true do
    local name, type = vim.loop.fs_scandir_next(handle)
    if not name then
      break
    end
    if type == "directory" then
      table.insert(dirs, name)
    end
  end
  return dirs
end

--- Redact sensitive environment variables
---@param env table<string, string>
---@param patterns string[]
---@return table<string, string>
function M.redact_env(env, patterns)
  local result = {}
  for key, value in pairs(env) do
    local redacted = false
    for _, pattern in ipairs(patterns) do
      if key:match(pattern) then
        result[key] = "[REDACTED]"
        redacted = true
        break
      end
    end
    if not redacted then
      result[key] = value
    end
  end
  return result
end

return M
