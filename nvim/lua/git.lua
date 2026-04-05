-- Gitsigns for git gutter signs and blame

require("gitsigns").setup({
  signs = {
    add = { text = "│" },
    change = { text = "│" },
    delete = { text = "_" },
    topdelete = { text = "‾" },
    changedelete = { text = "~" },
  },
  current_line_blame = true,
  current_line_blame_opts = {
    virt_text = true,
    virt_text_pos = "eol",
    delay = 500,
    use_focus = true,
  },
  current_line_blame_formatter = " <author> • <author_time:%b %d> • <summary>",
})

-- Hunk operations
local gs = require("gitsigns")

vim.keymap.set("n", "<leader>ghs", gs.stage_hunk, { desc = "Stage hunk" })
vim.keymap.set("n", "<leader>ghr", gs.reset_hunk, { desc = "Reset hunk" })
vim.keymap.set("v", "<leader>ghs", function() gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, { desc = "Stage hunk" })
vim.keymap.set("v", "<leader>ghr", function() gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, { desc = "Reset hunk" })
vim.keymap.set("n", "<leader>ghu", gs.undo_stage_hunk, { desc = "Undo stage hunk" })
vim.keymap.set("n", "<leader>ghp", gs.preview_hunk_inline, { desc = "Preview hunk inline" })
vim.keymap.set("n", "<leader>ghS", gs.stage_buffer, { desc = "Stage buffer" })
vim.keymap.set("n", "<leader>ghR", gs.reset_buffer, { desc = "Reset buffer" })
vim.keymap.set("n", "<leader>ghd", function() gs.diffthis() end, { desc = "Diff this" })
vim.keymap.set("n", "<leader>ght", gs.toggle_current_line_blame, { desc = "Toggle line blame" })

-- Hunk text object
vim.keymap.set({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { desc = "Select hunk" })
