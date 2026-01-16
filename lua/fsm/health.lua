local M = {}

local function check_executable(name)
  return vim.fn.executable(name) == 1
end

function M.check()
  vim.health.start("FSM - Focus Set Manager")

  -- Check Neovim version
  local nvim_version = vim.version()
  if nvim_version.major >= 0 and nvim_version.minor >= 9 then
    vim.health.ok("Neovim version: " .. tostring(nvim_version))
  else
    vim.health.warn("Neovim 0.9+ recommended, current: " .. tostring(nvim_version))
  end

  -- Check i3
  vim.health.start("i3 Integration")
  if check_executable("i3-msg") then
    vim.health.ok("i3-msg found")
    -- Check if i3 is running
    local result = vim.fn.system("i3-msg -t get_version")
    if vim.v.shell_error == 0 then
      vim.health.ok("i3 is running")
    else
      vim.health.warn("i3-msg available but i3 not running")
    end
  else
    vim.health.warn("i3-msg not found - workspace management disabled")
  end

  if check_executable("i3-save-tree") then
    vim.health.ok("i3-save-tree found (for layout capture)")
  else
    vim.health.info("i3-save-tree not found (optional, for layout capture)")
  end

  -- Check tmux
  vim.health.start("tmux Integration")
  if check_executable("tmux") then
    vim.health.ok("tmux found")
    -- Check tmux version
    local version = vim.fn.system("tmux -V")
    vim.health.ok("tmux version: " .. vim.trim(version))
  else
    vim.health.warn("tmux not found - session management disabled")
  end

  -- Check terminal
  vim.health.start("Terminal")
  if check_executable("alacritty") then
    vim.health.ok("alacritty found")
  else
    vim.health.warn("alacritty not found - configure apps.terminal in setup")
  end

  -- Check browser
  vim.health.start("Browser")
  if check_executable("firefox") then
    vim.health.ok("firefox found")
  else
    vim.health.info("firefox not found - configure apps.browser in setup")
  end

  -- Check data directory
  vim.health.start("Data Storage")
  local config = require("fsm.config")
  local data_dir = config.get().data_dir
  local utils = require("fsm.utils")

  if utils.path_exists(data_dir) then
    vim.health.ok("Data directory exists: " .. data_dir)
    local foci_dir = config.foci_dir()
    if utils.path_exists(foci_dir) then
      local focuses = utils.list_dirs(foci_dir)
      vim.health.ok("Found " .. #focuses .. " focus(es)")
    else
      vim.health.ok("Foci directory will be created on first focus")
    end
  else
    vim.health.ok("Data directory will be created: " .. data_dir)
  end

  -- Check optional dependencies
  vim.health.start("Optional Dependencies")
  local has_telescope = pcall(require, "telescope")
  if has_telescope then
    vim.health.ok("telescope.nvim found (enhanced picker)")
  else
    vim.health.info("telescope.nvim not found (using builtin picker)")
  end

  local has_plenary = pcall(require, "plenary")
  if has_plenary then
    vim.health.ok("plenary.nvim found (for testing)")
  else
    vim.health.info("plenary.nvim not found (optional, for testing)")
  end
end

return M
