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

-- Pickers (snacks.picker)
map("n", "<leader>f", function() Snacks.picker.files() end, { desc = "Find files" })
map("n", "<leader>sb", function() Snacks.picker.buffers() end, { desc = "Switch buffer" })
map("n", "<leader>sg", function() Snacks.picker.grep() end, { desc = "Live grep" })
map("n", "<leader>:", function() Snacks.picker.commands() end, { desc = "Command palette" })
map("n", "<leader>o", function() Snacks.picker.lsp_symbols() end, { desc = "Document symbols" })
map("n", "<leader>O", function() Snacks.picker.lsp_symbols({ workspace = true }) end, { desc = "Workspace symbols" })
map("n", "<leader>sw", function() Snacks.picker.grep_word() end, { desc = "Grep word under cursor" })
map("n", "<leader>sh", function() Snacks.picker.help() end, { desc = "Help tags" })
map("n", "<leader>sd", function() Snacks.picker.diagnostics_buffer() end, { desc = "Document diagnostics" })
map("n", "<leader>sD", function() Snacks.picker.diagnostics() end, { desc = "Workspace diagnostics" })
map("n", "<leader>s.", function() Snacks.picker.resume() end, { desc = "Resume last picker" })
map("n", "<leader>sk", function() Snacks.picker.keymaps() end, { desc = "Keymaps" })
map("n", '<leader>s"', function() Snacks.picker.registers() end, { desc = "Registers" })
map("n", "<leader>so", function() Snacks.picker.recent() end, { desc = "Recent files" })

-- Marks / bookmarks
map("n", "<leader>m", function() Snacks.picker.marks() end, { desc = "Search marks" })

-- File explorer
map("n", "<leader>b", function() Snacks.explorer() end, { desc = "Toggle file explorer" })

-- Buffer navigation
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<leader>w", function() Snacks.bufdelete() end, { desc = "Close buffer" })
map("n", "<leader>bd", function() Snacks.bufdelete() end, { desc = "Delete buffer" })

-- Git log (current file)
map("n", "<leader>gl", function() Snacks.picker.git_log_file() end, { desc = "Git log (file)" })

-- TODO comments
map("n", "<leader>st", function() Snacks.picker.todo_comments() end, { desc = "Search TODOs" })
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
map("n", "<leader>gc", function() Snacks.picker.git_log() end, { desc = "Git commits" })
map("n", "<leader>gs", function() Snacks.picker.git_status() end, { desc = "Git status" })
map("n", "<leader>gS", function() Snacks.picker.git_stash() end, { desc = "Git stash" })
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

-- Smart Escape: dismiss notifications, close panels, or clear search highlight
map("n", "<Esc>", function()
  require("noice").cmd("dismiss")
  Snacks.notifier.hide()
  pcall(vim.cmd, "cclose")
  pcall(vim.cmd, "lclose")
  vim.cmd("nohlsearch")
end, { desc = "Close panels/floats or clear search" })

-- Better escape from terminal mode
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Git browse (open file on GitHub)
map("n", "<leader>go", function() Snacks.gitbrowse() end, { desc = "Open in browser" })

-- LSP reference navigation
map("n", "]]", function() Snacks.words.jump(1) end, { desc = "Next reference" })
map("n", "[[", function() Snacks.words.jump(-1) end, { desc = "Previous reference" })

-- Toggles (snacks.toggle integrates with which-key)
Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
Snacks.toggle.diagnostics():map("<leader>ud")
Snacks.toggle.inlay_hints():map("<leader>uh")

-- which-key.nvim — keybinding discovery popup
require("which-key").setup()

require("which-key").add({
  { "<leader>s", group = "Search" },
  { "<leader>g", group = "Git" },
  { "<leader>gh", group = "Hunks" },
  { "<leader>x", group = "Trouble" },
  { "<leader>k", group = "Case" },
  { "<leader>n", group = "Noice" },
  { "<leader>u", group = "Toggle" },
})
