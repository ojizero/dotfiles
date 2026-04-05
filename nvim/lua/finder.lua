-- fzf-lua fuzzy finder (Cmd+P, command palette, grep, symbols)

-- Use fzf-lua for vim.ui.select (used by AvanteACPModels, etc.)
require("fzf-lua").register_ui_select()

require("fzf-lua").setup({
  "default-title",
  fzf_colors = true,
  winopts = {
    preview = {
      border = "rounded",
    },
  },
  keymap = {
    fzf = {
      ["ctrl-q"] = "select-all+accept",
    },
  },
})
