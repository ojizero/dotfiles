-- Editor options

vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- AI feature flags (override in ~/.local/nvim/init.lua via :Toggle* commands)
if vim.g.enable_avante == nil then vim.g.enable_avante = false end
if vim.g.enable_codecompanion == nil then vim.g.enable_codecompanion = false end

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

-- Folding (treesitter-based)
vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.o.foldlevelstart = 99
vim.o.foldtext = ""

-- Gutter: signs + line number + clickable fold indicator
vim.o.foldcolumn = "0"
_G.fold_click = function()
  local pos = vim.fn.getmousepos()
  vim.api.nvim_win_set_cursor(pos.winid, { pos.line, 0 })
  vim.cmd("normal! za")
end
_G.fold_indicator = function()
  local lnum = vim.v.lnum
  local level = vim.fn.foldlevel(lnum)
  if level <= 0 then return " " end
  if vim.fn.foldclosed(lnum) ~= -1 then return "▶" end
  local fde = vim.wo.foldexpr
  if fde ~= "" then
    local ok, result = pcall(vim.fn.eval, fde)
    if ok and type(result) == "string" and result:sub(1, 1) == ">" then
      return "▼"
    end
  end
  if level > vim.fn.foldlevel(lnum + 1) then return "▲" end
  return " "
end
vim.o.statuscolumn = '%s%l %@v:lua.fold_click@%{v:lua.fold_indicator()}%X'

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
vim.o.laststatus = 3

-- Splits
vim.o.splitright = true
vim.o.splitbelow = true

-- Mouse
vim.o.mouse = "a"
vim.o.mousemodel = "extend"

-- System clipboard
vim.o.clipboard = "unnamedplus"

-- Comment continuation: auto-insert comment leader on Enter/o/O
vim.api.nvim_create_autocmd("FileType", {
  callback = function()
    vim.opt_local.formatoptions:append("ro")
  end,
})

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
