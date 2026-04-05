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

-- Helper: run an action on the snacks explorer picker
local function explorer_action(action)
  return ("<cmd>lua do local p = Snacks.picker.get({ source = 'explorer' })[1] if p then p:action('%s') end end<cr>"):format(action)
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

-- Explorer menu: file operations via snacks.picker actions
define_menu("ExplorerMenu", {
  { "Open",              explorer_action("confirm") },
  { "New File",          explorer_action("explorer_add") },
  { sep = "-sep1-" },
  { "Rename",            explorer_action("explorer_rename") },
  { "Delete",            explorer_action("explorer_del") },
  { "Copy",              explorer_action("explorer_copy") },
  { "Move",              explorer_action("explorer_move") },
  { sep = "-sep2-" },
  { "Copy Path",         explorer_action("explorer_yank") },
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

  if ft == "snacks_picker_list" then
    vim.cmd("popup ExplorerMenu")
  elseif buftype == "terminal" then
    vim.cmd("popup TerminalMenu")
  else
    vim.cmd("popup PopUp")
  end
end, { desc = "Context menu" })
