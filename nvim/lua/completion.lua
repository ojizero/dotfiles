-- blink.cmp completion engine

require("blink.cmp").setup({
  keymap = {
    preset = "default",
    ["<Tab>"] = { "select_next", "fallback" },
    ["<S-Tab>"] = { "select_prev", "fallback" },
    ["<CR>"] = { "accept", "fallback" },
    ["<C-Space>"] = { "show" },
    ["<C-e>"] = { "cancel" },
    ["<C-d>"] = { "scroll_documentation_down" },
    ["<C-u>"] = { "scroll_documentation_up" },
  },
  sources = {
    default = { "lsp", "path", "buffer" },
  },
  completion = {
    documentation = { auto_show = true },
    ghost_text = { enabled = true },
  },
  signature = { enabled = true },
})
