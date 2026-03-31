-- Treesitter parser installation + rainbow delimiters + indent guides
-- Neovim 0.12+ has built-in treesitter highlight/indent;
-- nvim-treesitter plugin handles parser installation only

require("nvim-treesitter").install({
  "bash", "c", "cpp", "css", "dockerfile", "elixir", "erlang",
  "go", "html", "javascript", "json", "lua", "markdown",
  "markdown_inline", "python", "rust", "sql", "toml", "tsx",
  "typescript", "yaml",
})

-- Rainbow delimiters (colorized brackets)
require("rainbow-delimiters.setup").setup({})

-- Indent guides (indent-aware coloring)
require("ibl").setup({
  indent = { char = "│" },
  scope = { enabled = true },
})
