-- Editor options

vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Indentation
vim.o.tabstop = 2
vim.o.shiftwidth = 2
vim.o.expandtab = true
vim.o.smartindent = true

-- Line wrapping
vim.o.wrap = true
vim.o.linebreak = true
vim.o.textwidth = 100
vim.o.colorcolumn = "100"

-- Line numbers
vim.o.number = true
vim.o.relativenumber = true

-- Scrolling
vim.o.scrolloff = 8
vim.o.sidescrolloff = 8

-- Search
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.hlsearch = true
vim.o.incsearch = true

-- Appearance
vim.o.termguicolors = true
vim.o.signcolumn = "yes"
vim.o.cursorline = true

-- Splits
vim.o.splitright = true
vim.o.splitbelow = true

-- Mouse
vim.o.mouse = "a"
vim.o.mousemodel = "extend"

-- System clipboard
vim.o.clipboard = "unnamedplus"

-- Persistent undo
vim.o.undofile = true

-- Performance
vim.o.updatetime = 250
vim.o.timeoutlen = 300

-- Disable swap files (persistent undo is enough)
vim.o.swapfile = false

-- GUI font (for remote GUI clients like Neovide)
vim.o.guifont = "FiraCode Nerd Font:h18"

-- Inactive window dimming (approximation of Zed's inactive_opacity: 0.75)
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
    if normal.bg then
      -- Blend background toward black for inactive windows
      local bg = normal.bg
      local r = math.floor(bit.rshift(bit.band(bg, 0xFF0000), 16) * 0.85)
      local g = math.floor(bit.rshift(bit.band(bg, 0x00FF00), 8) * 0.85)
      local b = math.floor(bit.band(bg, 0x0000FF) * 0.85)
      vim.api.nvim_set_hl(0, "NormalNC", { bg = bit.bor(bit.lshift(r, 16), bit.lshift(g, 8), b) })
    end
  end,
})
