-- LazyVim entry point. See lua/config/lazy.lua for bootstrap.
require("config.lazy")

-- Per-machine, git-ignored overrides (options/keymaps/vim.g), sourced last.
-- For per-machine plugins, add a tracked spec under lua/plugins/ instead.
local local_init = vim.fn.expand("~/.local/nvim/init.lua")
if vim.fn.filereadable(local_init) == 1 then
  dofile(local_init)
end
