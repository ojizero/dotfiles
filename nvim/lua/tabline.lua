-- Tabline (barbar.nvim)

require("barbar").setup({
  animation = true,
  auto_hide = 1,
  icons = {
    diagnostics = {
      [vim.diagnostic.severity.ERROR] = { enabled = true },
      [vim.diagnostic.severity.WARN] = { enabled = true },
    },
    gitsigns = {
      added = { enabled = true, icon = "+" },
      changed = { enabled = true, icon = "~" },
      deleted = { enabled = true, icon = "-" },
    },
    pinned = { button = "", filename = true },
  },
})
