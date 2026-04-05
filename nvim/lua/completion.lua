-- blink.cmp completion engine

require("blink.cmp").setup({
  keymap = {
    preset = "default",
    ["<Tab>"] = { "snippet_forward", "select_next", "fallback" },
    ["<S-Tab>"] = { "snippet_backward", "select_prev", "fallback" },
    ["<CR>"] = { "accept", "fallback" },
    ["<C-Space>"] = { "show" },
    ["<C-e>"] = { "cancel" },
    ["<C-d>"] = { "scroll_documentation_down" },
    ["<C-u>"] = { "scroll_documentation_up" },
  },
  sources = {
    default = { "lsp", "path", "snippets", "buffer" },
  },
  completion = {
    documentation = { auto_show = true, auto_show_delay_ms = 200 },
    ghost_text = { enabled = true },
    menu = {
      draw = { treesitter = { "lsp" } },
    },
  },
  signature = { enabled = true },
})
