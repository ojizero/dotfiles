-- noice.nvim for modern command palette and message routing
-- Notifications are handled by snacks.notifier (see snacks.lua)

require("noice").setup({
  lsp = {
    -- Override markdown rendering for LSP hover/signature
    override = {
      ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
      ["vim.lsp.util.stylize_markdown"] = true,
    },
  },
  presets = {
    bottom_search = true,
    command_palette = true,
    long_message_to_split = true,
    lsp_doc_border = true,
  },
  routes = {
    {
      filter = {
        event = "msg_show",
        any = {
          { find = "%d+L, %d+B" },
          { find = "; after #%d+" },
          { find = "; before #%d+" },
        },
      },
      view = "mini",
    },
  },
})

-- Noice keymaps
vim.keymap.set("n", "<leader>nh", function() require("noice").cmd("history") end, { desc = "Noice history" })
vim.keymap.set("n", "<leader>nl", function() require("noice").cmd("last") end, { desc = "Noice last message" })
vim.keymap.set("n", "<leader>nd", function()
  require("noice").cmd("dismiss")
  Snacks.notifier.hide()
end, { desc = "Dismiss notifications" })
