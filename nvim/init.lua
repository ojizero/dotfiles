-- Neovim configuration entry point
-- Requires Neovim 0.11+ (vim.pack)

require("options")
require("plugins")
require("candy")
require("theme")
require("treesitter")
require("lsp")
require("completion")
require("statusline")
require("git")
require("ui")
require("editing")
require("ai")
require("tasks")
require("keymaps")
require("mouse")
require("local") -- must be last: overrides anything above
