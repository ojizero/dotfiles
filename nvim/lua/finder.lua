-- fzf-lua fuzzy finder (Cmd+P, command palette, grep, symbols)

require("fzf-lua").setup({
  winopts = {
    preview = {
      default = "bat",
      border = "rounded",
    },
  },
  keymap = {
    fzf = {
      ["ctrl-q"] = "select-all+accept",
    },
  },
})
