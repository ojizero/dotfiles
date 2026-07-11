-- Autocmds are automatically loaded on the VeryLazy event.
-- LazyVim defaults: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add overrides here.

-- Keep the bufferline tab bar in sync with Catppuccin's flavour.
-- At startup 'background' defaults to dark, so Catppuccin briefly loads mocha and
-- bufferline caches that palette for its BufferLine* groups. When the terminal
-- background is later detected (or toggled) to light, every native group re-themes
-- to latte but bufferline's cached tab-bar colors stay on the old flavour. Re-assert
-- the colorscheme (deferred, so it runs after the palette has settled) to force
-- bufferline to rebuild its highlights.
local function resync_colorscheme()
  vim.schedule(function()
    if vim.g.colors_name then
      vim.cmd.colorscheme(vim.g.colors_name)
    end
  end)
end

vim.api.nvim_create_autocmd("OptionSet", {
  pattern = "background",
  callback = resync_colorscheme,
})

-- Also run once on load to fix the case where the background was already detected
-- before this autocmd was registered.
resync_colorscheme()
