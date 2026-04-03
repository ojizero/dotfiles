-- fzf-lua fuzzy finder (Cmd+P, command palette, grep, symbols)

local function bat_theme()
  return vim.o.background == "light" and "Catppuccin Latte" or "Catppuccin Mocha"
end

-- Use fzf-lua for vim.ui.select (used by AvanteACPModels, etc.)
require("fzf-lua").register_ui_select()

require("fzf-lua").setup({
  winopts = {
    preview = {
      default = "bat",
      border = "rounded",
    },
  },
  previewers = {
    bat = {
      theme = bat_theme(),
    },
  },
  keymap = {
    fzf = {
      ["ctrl-q"] = "select-all+accept",
    },
  },
})

-- Sync bat preview theme when background changes
vim.api.nvim_create_autocmd("OptionSet", {
  pattern = "background",
  callback = function()
    require("fzf-lua").setup({ previewers = { bat = { theme = bat_theme() } } })
  end,
})
