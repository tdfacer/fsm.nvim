-- Minimal init for testing
local plenary_dir = os.getenv("PLENARY_DIR") or "/tmp/plenary.nvim"

if vim.fn.isdirectory(plenary_dir) == 0 then
  vim.fn.system({ "git", "clone", "https://github.com/nvim-lua/plenary.nvim", plenary_dir })
end

vim.opt.rtp:append(".")
vim.opt.rtp:append(plenary_dir)

vim.cmd("runtime plugin/plenary.vim")

-- Use a temporary directory for test data
vim.g.fsm_test_data_dir = vim.fn.tempname()

-- Setup fsm with test configuration
require("fsm").setup({
  data_dir = vim.g.fsm_test_data_dir,
  tmux = { enabled = false }, -- Disable tmux in tests
})
