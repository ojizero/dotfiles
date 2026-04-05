-- snacks.nvim setup (file named "candy" to avoid collision with the snacks module)
-- Must load early (before UIEnter/BufReadPre) for bigfile, scroll, notifier, etc.

require("snacks").setup({
  bigfile    = { enabled = true },
  quickfile  = { enabled = true },
  scroll     = { enabled = true },
  indent     = { enabled = true, indent = { char = "│" }, scope = { enabled = true } },
  notifier   = { enabled = true, timeout = 3000, style = "compact" },
  statuscolumn = { enabled = true },
  words      = { enabled = true },
  input      = { enabled = true },
  rename     = { enabled = true },
  picker     = { enabled = true, ui_select = true },
  explorer   = { enabled = true, replace_netrw = true },
})

-- Persist explorer open/closed state across sessions
local state_file = vim.fn.stdpath("state") .. "/explorer-open"

vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    local pickers = Snacks.picker.get({ source = "explorer" })
    if #pickers > 0 then
      vim.fn.writefile({ "open" }, state_file)
    else
      vim.fn.delete(state_file)
    end
  end,
})

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if vim.fn.filereadable(state_file) == 1 then
      if vim.fn.argc() <= 1 and not vim.o.diff then
        Snacks.explorer()
      end
    end
  end,
})
