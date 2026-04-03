-- Catppuccin theme with system dark/light mode

require("catppuccin").setup({
  flavour = "auto", -- follows vim.o.background
  background = { light = "latte", dark = "mocha" },
  transparent_background = false,
  custom_highlights = function(colors)
    return {
      -- CursorLine bg is nearly identical to mantle in Latte; use surface0 for sidebar/float contrast
      NeoTreeCursorLine = { bg = colors.surface0 },
      FzfLuaCursorLine = { bg = colors.surface0 },
      GitSignsCurrentLineBlame = { fg = colors.overlay0, italic = true },
    }
  end,
  integrations = {
    blink_cmp = true,
    gitsigns = true,
    indent_blankline = { enabled = true },
    neotree = true,
    noice = true,
    notify = true,
    rainbow_delimiters = true,
    treesitter = true,
    native_lsp = {
      enabled = true,
      underlines = {
        errors = { "undercurl" },
        hints = { "undercurl" },
        warnings = { "undercurl" },
        information = { "undercurl" },
      },
    },
  },
})

vim.cmd.colorscheme("catppuccin")
