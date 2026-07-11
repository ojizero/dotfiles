-- Catppuccin, following the terminal's light/dark background.
-- Neovim auto-detects the terminal background (OSC 11) and sets vim.o.background;
-- flavour = "auto" then maps that to latte (light) / mocha (dark).
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "auto",
      background = { light = "latte", dark = "mocha" },
      term_colors = true,
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
