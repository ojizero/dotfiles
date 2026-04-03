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
