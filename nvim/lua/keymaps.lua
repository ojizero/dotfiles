-- All keybindings
-- Leader is <Space> (set in options.lua)
--
-- NOTE: Cmd+C in visual mode will "cut" (delete + insert mode) instead of copying.
-- This is because the terminal leaks the `c` keypress to Neovim, where `c` in visual
-- mode means "change". Use `y` to yank — clipboard is already synced via unnamedplus.

local map = vim.keymap.set

-- Change without yanking (use black hole register)
map({ "n", "v" }, "c", '"_c', { desc = "Change without yanking" })
map({ "n", "v" }, "C", '"_C', { desc = "Change to EOL without yanking" })

-- File finder (Cmd+P equivalent)
map("n", "<leader>f", "<cmd>FzfLua files<cr>", { desc = "Find files" })
map("n", "<leader>b", "<cmd>FzfLua buffers<cr>", { desc = "Switch buffer" })
map("n", "<leader>sg", "<cmd>FzfLua live_grep<cr>", { desc = "Live grep" })
map("n", "<leader>:", "<cmd>FzfLua commands<cr>", { desc = "Command palette" })
map("n", "<leader>o", "<cmd>FzfLua lsp_document_symbols<cr>", { desc = "Document symbols" })
map("n", "<leader>sw", "<cmd>FzfLua grep_cword<cr>", { desc = "Grep word under cursor" })
map("n", "<leader>sh", "<cmd>FzfLua help_tags<cr>", { desc = "Help tags" })
map("n", "<leader>sd", "<cmd>FzfLua diagnostics_document<cr>", { desc = "Document diagnostics" })

-- Marks / bookmarks
map("n", "<leader>m", "<cmd>FzfLua marks<cr>", { desc = "Search marks" })

-- File explorer
map("n", "<leader>e", "<cmd>Neotree toggle<cr>", { desc = "Toggle file explorer" })

-- Go to line
map("n", "<leader>gl", ":", { desc = "Go to line" })

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

-- AI (CodeCompanion)
map({ "n", "v" }, "<leader>ai", "<cmd>CodeCompanionActions<cr>", { desc = "AI actions" })
map({ "n", "v" }, "<leader>ac", "<cmd>CodeCompanionChat toggle<cr>", { desc = "AI chat" })

-- Git (gitsigns)
map("n", "<leader>gb", "<cmd>Gitsigns blame_line<cr>", { desc = "Git blame line" })
map("n", "]h", "<cmd>Gitsigns next_hunk<cr>", { desc = "Next hunk" })
map("n", "[h", "<cmd>Gitsigns prev_hunk<cr>", { desc = "Previous hunk" })

-- Window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Move to below window" })
map("n", "<C-k>", "<C-w>k", { desc = "Move to above window" })
map("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

-- Better escape from terminal mode
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
