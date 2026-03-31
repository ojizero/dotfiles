-- noice.nvim + nvim-notify for modern UI

require("notify").setup({
  stages = "fade",
  timeout = 3000,
  render = "compact",
})

require("noice").setup({
  lsp = {
    -- Override markdown rendering for LSP hover/signature
    override = {
      ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
      ["vim.lsp.util.stylize_markdown"] = true,
      ["cmp.entry.get_documentation"] = true,
    },
  },
  presets = {
    bottom_search = true,
    command_palette = true,
    long_message_to_split = true,
    lsp_doc_border = true,
  },
})
