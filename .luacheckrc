std = "luajit"
cache = true

read_globals = {
  "vim",
  "describe",
  "it",
  "before_each",
  "after_each",
  "assert",
  "pending",
}

globals = {
  "vim.g",
  "vim.b",
  "vim.w",
  "vim.o",
  "vim.bo",
  "vim.wo",
  "vim.opt",
  "vim.env",
}

ignore = {
  "212/_.*", -- unused argument starting with _
}

max_line_length = 120
