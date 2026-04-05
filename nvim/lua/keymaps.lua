-- All keybindings
-- Leader is <Space> (set in options.lua)
--
-- NOTE: Cmd+C in visual mode will "cut" (delete + insert mode) instead of copying.
-- This is because the terminal leaks the `c` keypress to Neovim, where `c` in visual
-- mode means "change". Use `y` to yank — clipboard is already synced via unnamedplus.

local map = vim.keymap.set

-- Smart j/k: move by display lines when no count (for wrap=true)
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

-- Change without yanking (use black hole register)
map({ "n", "v" }, "c", '"_c', { desc = "Change without yanking" })
map({ "n", "v" }, "C", '"_C', { desc = "Change to EOL without yanking" })

-- Move lines up/down with Alt+j/k
map("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move line down" })
map("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move line up" })
map("i", "<A-j>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move line down" })
map("i", "<A-k>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move line up" })
map("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })
map("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move selection up" })

-- Better visual indenting (stay in visual mode)
map("v", "<", "<gv")
map("v", ">", ">gv")

-- File finder (Cmd+P equivalent)
map("n", "<leader>f", "<cmd>FzfLua files<cr>", { desc = "Find files" })
map("n", "<leader>sb", "<cmd>FzfLua buffers<cr>", { desc = "Switch buffer" })
map("n", "<leader>sg", "<cmd>FzfLua live_grep<cr>", { desc = "Live grep" })
map("n", "<leader>:", "<cmd>FzfLua commands<cr>", { desc = "Command palette" })
map("n", "<leader>o", "<cmd>FzfLua lsp_document_symbols<cr>", { desc = "Document symbols" })
map("n", "<leader>O", "<cmd>FzfLua lsp_workspace_symbols<cr>", { desc = "Workspace symbols" })
map("n", "<leader>sw", "<cmd>FzfLua grep_cword<cr>", { desc = "Grep word under cursor" })
map("n", "<leader>sh", "<cmd>FzfLua help_tags<cr>", { desc = "Help tags" })
map("n", "<leader>sd", "<cmd>FzfLua diagnostics_document<cr>", { desc = "Document diagnostics" })
map("n", "<leader>sD", "<cmd>FzfLua diagnostics_workspace<cr>", { desc = "Workspace diagnostics" })
map("n", "<leader>s.", "<cmd>FzfLua resume<cr>", { desc = "Resume last picker" })
map("n", "<leader>sk", "<cmd>FzfLua keymaps<cr>", { desc = "Keymaps" })
map("n", '<leader>s"', "<cmd>FzfLua registers<cr>", { desc = "Registers" })
map("n", "<leader>so", "<cmd>FzfLua oldfiles<cr>", { desc = "Recent files" })

-- Marks / bookmarks
map("n", "<leader>m", "<cmd>FzfLua marks<cr>", { desc = "Search marks" })

-- File explorer
map("n", "<leader>b", "<cmd>Neotree toggle<cr>", { desc = "Toggle file explorer" })

-- Buffer navigation
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<leader>w", "<cmd>bdelete<cr>", { desc = "Close buffer" })
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete buffer" })

-- Git log (current file)
map("n", "<leader>gl", "<cmd>FzfLua git_bcommits<cr>", { desc = "Git log (file)" })

-- TODO comments
map("n", "<leader>st", function() require("todo-comments.fzf").todo() end, { desc = "Search TODOs" })
map("n", "]t", function() require("todo-comments").jump_next() end, { desc = "Next TODO" })
map("n", "[t", function() require("todo-comments").jump_prev() end, { desc = "Previous TODO" })

-- Case conversions (visual mode)
map("v", "<leader>ku", "gU", { desc = "Uppercase" })
map("v", "<leader>kl", "gu", { desc = "Lowercase" })

-- PascalCase and camelCase (visual mode)
map("v", "<leader>kp", function()
  local text = vim.fn.getreg("v")
  vim.cmd('normal! "vy')
  text = vim.fn.getreg("v")
  local result = text:gsub("(%a)([%w]*)", function(first, rest)
    return first:upper() .. rest:lower()
  end):gsub("[_%-% ]+", "")
  vim.fn.setreg("v", result)
  vim.cmd('normal! gv"vp')
end, { desc = "PascalCase" })

map("v", "<leader>kc", function()
  local text = vim.fn.getreg("v")
  vim.cmd('normal! "vy')
  text = vim.fn.getreg("v")
  local first = true
  local result = text:gsub("(%a)([%w]*)", function(f, rest)
    if first then
      first = false
      return f:lower() .. rest:lower()
    end
    return f:upper() .. rest:lower()
  end):gsub("[_%-% ]+", "")
  vim.fn.setreg("v", result)
  vim.cmd('normal! gv"vp')
end, { desc = "camelCase" })

-- Git (gitsigns)
map("n", "<leader>gb", "<cmd>Gitsigns blame_line<cr>", { desc = "Git blame line" })
map("n", "<leader>gc", "<cmd>FzfLua git_commits<cr>", { desc = "Git commits" })
map("n", "<leader>gs", "<cmd>FzfLua git_status<cr>", { desc = "Git status" })
map("n", "<leader>gS", "<cmd>FzfLua git_stash<cr>", { desc = "Git stash" })
map("n", "]h", "<cmd>Gitsigns next_hunk<cr>", { desc = "Next hunk" })
map("n", "[h", "<cmd>Gitsigns prev_hunk<cr>", { desc = "Previous hunk" })

-- Window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Move to below window" })
map("n", "<C-k>", "<C-w>k", { desc = "Move to above window" })
map("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })

-- Undo break-points in insert mode
map("i", ",", ",<c-g>u")
map("i", ".", ".<c-g>u")
map("i", ";", ";<c-g>u")

-- Saner n/N: always search forward/backward regardless of / vs ?
map("n", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
map("n", "N", "'nN'[v:searchforward]", { expr = true, desc = "Previous search result" })
map({ "x", "o" }, "n", "'Nn'[v:searchforward]", { expr = true })
map({ "x", "o" }, "N", "'nN'[v:searchforward]", { expr = true })

-- Save with Ctrl-s
map({ "n", "i", "x", "s" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save file" })

-- Flash.nvim (jump labels)
map({ "n", "x", "o" }, "s", function() require("flash").jump() end, { desc = "Flash jump" })
map({ "n", "x", "o" }, "S", function() require("flash").treesitter() end, { desc = "Flash treesitter" })

-- Trouble (diagnostics panel)
map("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Diagnostics (Trouble)" })
map("n", "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", { desc = "Buffer diagnostics" })
map("n", "<leader>xq", "<cmd>Trouble qflist toggle<cr>", { desc = "Quickfix (Trouble)" })
map("n", "<leader>xl", "<cmd>Trouble loclist toggle<cr>", { desc = "Location list (Trouble)" })
map("n", "<leader>xt", "<cmd>Trouble todo toggle<cr>", { desc = "TODOs (Trouble)" })

-- Grug-far (search and replace)
map("n", "<leader>sr", function() require("grug-far").open() end, { desc = "Search and replace" })
map("v", "<leader>sr", function() require("grug-far").with_visual_selection() end, { desc = "Search and replace (selection)" })

-- Smart Escape: dismiss noice, close panels, or clear search highlight
map("n", "<Esc>", function()
  require("noice").cmd("dismiss")
  pcall(vim.cmd, "cclose")
  pcall(vim.cmd, "lclose")
  vim.cmd("nohlsearch")
end, { desc = "Close panels/floats or clear search" })

-- Better escape from terminal mode
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- which-key.nvim — keybinding discovery popup
require("which-key").setup()

require("which-key").add({
  { "<leader>s", group = "Search" },
  { "<leader>g", group = "Git" },
  { "<leader>gh", group = "Hunks" },
  { "<leader>x", group = "Trouble" },
  { "<leader>k", group = "Case" },
  { "<leader>n", group = "Noice" },
})
