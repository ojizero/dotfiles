-- Plugin declarations using Neovim 0.12+ built-in pack manager
-- vim.pack.add() takes a list of specs; src must be a full git URL

local gh = "https://github.com/"

vim.pack.add({
  -- Shared dependencies
  gh .. "nvim-lua/plenary.nvim",
  gh .. "MunifTanjim/nui.nvim",
  gh .. "echasnovski/mini.icons",

  -- Theme
  gh .. "catppuccin/nvim",

  -- Syntax
  gh .. "nvim-treesitter/nvim-treesitter",
  gh .. "HiPhish/rainbow-delimiters.nvim",
  gh .. "lukas-reineke/indent-blankline.nvim",
  gh .. "folke/ts-comments.nvim",

  -- LSP, completion, formatting
  gh .. "neovim/nvim-lspconfig",
  { src = gh .. "saghen/blink.cmp", version = vim.version.range("1.x") },
  gh .. "rafamadriz/friendly-snippets",
  gh .. "stevearc/conform.nvim",
  gh .. "b0o/SchemaStore.nvim",

  -- Navigation
  gh .. "nvim-neo-tree/neo-tree.nvim",
  gh .. "ibhagwan/fzf-lua",
  gh .. "folke/flash.nvim",

  -- UI
  gh .. "nvim-lualine/lualine.nvim",
  gh .. "rcarriga/nvim-notify",
  gh .. "folke/noice.nvim",
  gh .. "folke/which-key.nvim",
  gh .. "folke/trouble.nvim",

  -- Editing
  gh .. "karb94/neoscroll.nvim",
  gh .. "MagicDuck/grug-far.nvim",

  -- Git
  gh .. "lewis6991/gitsigns.nvim",

  -- TODO comments
  gh .. "folke/todo-comments.nvim",

  -- Markdown rendering (always-on; also used by avante)
  gh .. "MeanderingProgrammer/render-markdown.nvim",
})

-- avante (default on, toggle via :ToggleAvante)
if vim.g.enable_avante then
  vim.pack.add({
    gh .. "yetone/avante.nvim",
  })
end

-- CodeCompanion (gated)
if vim.g.enable_codecompanion then
  vim.pack.add({
    gh .. "olimorris/codecompanion.nvim",
  })
end

-- 99 (gated)
if vim.g.enable_99 then
  vim.pack.add({
    gh .. "ThePrimeagen/99",
    { src = gh .. "saghen/blink.compat", version = vim.version.range("2.x") },
  })
end
