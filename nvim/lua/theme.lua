-- mini.icons replaces nvim-web-devicons; mock for backward compatibility
require("mini.icons").setup()
MiniIcons.mock_nvim_web_devicons()

-- Catppuccin theme with system dark/light mode

require("catppuccin").setup({
  flavour = "auto", -- follows vim.o.background
  background = { light = "latte", dark = "mocha" },
  term_colors = true,
  dim_inactive = { enabled = true, shade = "dark", percentage = 0.15 },
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
    blink_cmp = { enabled = true, style = "bordered" },
    gitsigns = true,
    indent_blankline = { enabled = true },
    neotree = true,
    noice = true,
    notify = true,
    rainbow_delimiters = true,
    trouble = true,
    which_key = true,
    flash = true,
    mini = { enabled = true },
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
