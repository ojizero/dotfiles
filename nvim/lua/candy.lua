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
  dashboard  = {
    enabled = true,
    preset = {
      header = "│ ╲ ││\n││╲╲││\n││ ╲ │\n\nNVIM",
    },
    sections = {
      { section = "header" },
      { section = "keys", gap = 1, padding = 1 },
    },
  },
})

-- Show dashboard when last buffer is closed
vim.api.nvim_create_autocmd("BufDelete", {
  callback = function()
    vim.schedule(function()
      local buf = vim.api.nvim_get_current_buf()
      if vim.bo[buf].buftype ~= ""
        or vim.api.nvim_buf_get_name(buf) ~= ""
        or vim.bo[buf].filetype == "snacks_dashboard" then
        return
      end
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      if #lines <= 1 and (lines[1] or "") == "" then
        Snacks.dashboard.open()
      end
    end)
  end,
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
