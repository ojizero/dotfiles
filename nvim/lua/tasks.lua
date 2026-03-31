-- Custom task commands + todo-comments

-- todo-comments.nvim
require("todo-comments").setup({
  signs = true,
  keywords = {
    TODO = { icon = " ", color = "info" },
    FIXME = { icon = " ", color = "error" },
    HACK = { icon = " ", color = "warning" },
    NOTE = { icon = " ", color = "hint" },
  },
})

-- Git operations
vim.api.nvim_create_user_command("GitGone", "!git gone", {})
vim.api.nvim_create_user_command("GitStashPush", "!git stash push --include-untracked", {})
vim.api.nvim_create_user_command("GitStashPop", "!git stash pop", {})
vim.api.nvim_create_user_command("GitStashApply", "!git stash apply", {})

-- Elixir workflow
vim.api.nvim_create_user_command("IexMix", "terminal iex -S mix", {})
vim.api.nvim_create_user_command("MixPhxServer", "terminal mix phx.server", {})
vim.api.nvim_create_user_command("IexPhxServer", "terminal iex -S mix phx.server", {})
vim.api.nvim_create_user_command("MixTest", "!mix test", {})
