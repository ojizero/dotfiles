-- Context-aware right-click menus

vim.o.mousemodel = "popup"

-- Clear default popup entries
pcall(function() vim.cmd("aunmenu PopUp") end)

-- Helper: define a named menu group
local function define_menu(name, items)
  for _, item in ipairs(items) do
    if item.sep then
      vim.cmd(("menu %s.%s <Nop>"):format(name, item.sep))
    else
      local label = item[1]:gsub(" ", "\\ ")
      vim.cmd(("menu %s.%s %s"):format(name, label, item[2]))
    end
  end
end

-- Buffer menu: LSP + editing + git
define_menu("PopUp", {
  { "Go to Definition",  "<cmd>lua vim.lsp.buf.definition()<cr>" },
  { "References",        "<cmd>lua vim.lsp.buf.references()<cr>" },
  { "Rename",            "<cmd>lua vim.lsp.buf.rename()<cr>" },
  { "Code Action",       "<cmd>lua vim.lsp.buf.code_action()<cr>" },
  { sep = "-sep1-" },
  { "Cut",               '"+x' },
  { "Copy",              '"+y' },
  { "Paste",             '"+p' },
  { sep = "-sep2-" },
  { "Toggle Blame",      "<cmd>Gitsigns toggle_current_line_blame<cr>" },
})

-- Neo-tree menu: file operations
define_menu("NeoTreeMenu", {
  { "Open",              "<cmd>lua require('neo-tree.sources.common.commands').open_tabnew(require('neo-tree.sources.manager').get_state('filesystem'))<cr>" },
  { "New File",          "<cmd>lua require('neo-tree.sources.common.commands').add(require('neo-tree.sources.manager').get_state('filesystem'))<cr>" },
  { "New Directory",     "<cmd>lua require('neo-tree.sources.common.commands').add_directory(require('neo-tree.sources.manager').get_state('filesystem'))<cr>" },
  { sep = "-sep1-" },
  { "Rename",            "<cmd>lua require('neo-tree.sources.common.commands').rename(require('neo-tree.sources.manager').get_state('filesystem'))<cr>" },
  { "Delete",            "<cmd>lua require('neo-tree.sources.common.commands').delete(require('neo-tree.sources.manager').get_state('filesystem'))<cr>" },
  { "Copy",              "<cmd>lua require('neo-tree.sources.common.commands').copy_to_clipboard(require('neo-tree.sources.manager').get_state('filesystem'))<cr>" },
  { "Cut",               "<cmd>lua require('neo-tree.sources.common.commands').cut_to_clipboard(require('neo-tree.sources.manager').get_state('filesystem'))<cr>" },
  { "Paste",             "<cmd>lua require('neo-tree.sources.common.commands').paste_from_clipboard(require('neo-tree.sources.manager').get_state('filesystem'))<cr>" },
  { sep = "-sep2-" },
  { "Copy Path",         "<cmd>lua local n = require('neo-tree.ui.renderer').get_node_at_cursor() if n then vim.fn.setreg('+', n:get_id()) vim.notify('Copied: ' .. n:get_id()) end<cr>" },
})

-- Terminal menu: just paste
define_menu("TerminalMenu", {
  { "Paste", '"+p' },
})

-- Jump focus and cursor to the window+line under the mouse, then show the right menu
vim.keymap.set({ "n", "v", "i" }, "<RightMouse>", function()
  -- Get mouse position: window and line/col within it
  local mouse = vim.fn.getmousepos()
  if mouse.winid == 0 then return end

  -- Switch to the window under the mouse
  vim.api.nvim_set_current_win(mouse.winid)

  -- Move cursor to the clicked line/column within that window
  local line_count = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(mouse.winid))
  local row = math.min(mouse.line, line_count)
  local col = math.max(mouse.column - 1, 0)
  pcall(vim.api.nvim_win_set_cursor, mouse.winid, { row, col })

  -- Detect context from the target window's buffer
  local buf = vim.api.nvim_win_get_buf(mouse.winid)
  local ft = vim.bo[buf].filetype
  local buftype = vim.bo[buf].buftype

  if ft == "neo-tree" then
    vim.cmd("popup NeoTreeMenu")
  elseif buftype == "terminal" then
    vim.cmd("popup TerminalMenu")
  else
    vim.cmd("popup PopUp")
  end
end, { desc = "Context menu" })
