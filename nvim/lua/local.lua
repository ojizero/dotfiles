-- Load optional per-machine overrides from ~/.local/nvim/init.lua
-- This file is inside .local/ which is git-ignored

local local_init = vim.fn.expand("~/.local/nvim/init.lua")
if vim.fn.filereadable(local_init) == 1 then
  dofile(local_init)
end
