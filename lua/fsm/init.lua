local config = require("fsm.config")
local commands = require("fsm.commands")
local state = require("fsm.state")
local store = require("fsm.store")
local log = require("fsm.log")

local M = {}

--- Setup the plugin
---@param opts? table User configuration
function M.setup(opts)
  config.setup(opts)

  -- Set log level from config if provided
  if opts and opts.log_level then
    log.set_level(opts.log_level)
  end

  log.debug("FSM plugin initialized")
end

-- Export public API

--- Start a new focus
---@param name string Focus name
---@param opts? { urls: string[] }
---@return boolean ok
---@return string? error
function M.start(name, opts)
  return commands.start(name, opts)
end

--- Suspend a focus
---@param slug? string Focus slug (defaults to current)
---@return boolean ok
---@return string? error
function M.suspend(slug)
  return commands.suspend(slug)
end

--- Resume a focus
---@param slug string Focus slug
---@return boolean ok
---@return string? error
function M.resume(slug)
  return commands.resume(slug)
end

--- Archive a focus
---@param slug string Focus slug
---@return boolean ok
---@return string? error
function M.archive(slug)
  return commands.archive(slug)
end

--- Delete a focus permanently
---@param slug string Focus slug
---@param opts? { force: boolean }
---@return boolean ok
---@return string? error
function M.delete(slug, opts)
  return commands.delete(slug, opts)
end

--- List all focuses
---@param opts? { state: FocusState? }
---@return FocusMeta[]
function M.list(opts)
  return commands.list(opts)
end

--- Switch from current focus to another
---@param to_slug string Focus to switch to
---@return boolean ok
---@return string? error
function M.switch(to_slug)
  return commands.switch(to_slug)
end

--- Get status of current focus
---@return table status
function M.status()
  return commands.status()
end

--- Get current focus slug
---@return string?
function M.current()
  return state.current_slug()
end

--- Get current focus metadata
---@return FocusMeta?
function M.current_focus()
  return state.current()
end

--- Open notes for focus
---@param slug? string
---@return boolean ok
---@return string? error
function M.notes(slug)
  return commands.notes(slug)
end

--- Open todo for focus
---@param slug? string
---@return boolean ok
---@return string? error
function M.todo(slug)
  return commands.todo(slug)
end

--- Add URLs to focus
---@param urls string[]
---@param slug? string
---@return boolean ok
---@return string? error
function M.add_urls(urls, slug)
  return commands.add_urls(urls, slug)
end

--- Check if focus exists
---@param slug string
---@return boolean
function M.exists(slug)
  return store.exists(slug)
end

--- Load focus metadata
---@param slug string
---@return FocusMeta?
function M.load(slug)
  return store.load(slug)
end

return M
