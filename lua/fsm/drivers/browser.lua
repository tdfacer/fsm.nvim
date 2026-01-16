local config = require("fsm.config")
local log = require("fsm.log")

local M = {}

--- Check if browser is available
---@return boolean
function M.available()
  local result = vim.fn.system("which firefox")
  return vim.v.shell_error == 0 and result ~= ""
end

--- Open URLs in browser
---@param urls string[]
---@param class? string Window class for i3 matching
---@return boolean ok
---@return string? error
function M.open_urls(urls, class)
  if #urls == 0 then
    return true, nil
  end

  local cfg = config.get()

  -- Build URL string
  local url_str = table.concat(urls, " ")

  -- Format browser command
  local cmd = string.format(cfg.apps.browser, url_str)

  -- Add class modifier if provided (for Firefox)
  if class then
    -- Firefox doesn't support --class directly, but we can use a new window
    -- The i3 marking will happen after window appears
    cmd = cmd .. " &"
  else
    cmd = cmd .. " &"
  end

  log.debug("Running: %s", cmd)
  vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    return false, "Failed to open browser"
  end

  log.info("Opened %d URL(s) in browser", #urls)
  return true, nil
end

--- Open a single URL
---@param url string
---@return boolean ok
---@return string? error
function M.open_url(url)
  return M.open_urls({ url })
end

--- Get focused browser windows for URL extraction (placeholder)
--- Note: Full browser integration requires a browser extension
---@return string[]
function M.get_current_urls()
  -- This would require browser extension integration
  -- For v1, we just return empty - users can manually add URLs
  log.debug("Browser URL extraction not implemented in v1")
  return {}
end

--- Validate URL format
---@param url string
---@return boolean
function M.is_valid_url(url)
  -- Basic URL validation
  return url:match("^https?://") ~= nil or url:match("^file://") ~= nil
end

--- Parse URLs from text (for importing from clipboard, etc.)
---@param text string
---@return string[]
function M.parse_urls(text)
  local urls = {}
  for url in text:gmatch("https?://[%w%-%.%_%~%:%/%?%#%[%]%@%!%$%&%'%(%)%*%+%,%;%%=]+") do
    table.insert(urls, url)
  end
  return urls
end

return M
