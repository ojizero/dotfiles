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
vim.o.grepprg = "rg --vimgrep"
vim.o.grepformat = "%f:%l:%c:%m"

-- Appearance
vim.o.termguicolors = true
vim.o.signcolumn = "yes"
vim.o.showmode = false
vim.o.inccommand = "nosplit"
vim.o.cursorline = true
vim.o.laststatus = 3

-- Splits
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.splitkeep = "screen"

-- Mouse
vim.o.mouse = "a"

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
vim.o.smoothscroll = true
vim.o.confirm = true
vim.o.virtualedit = "block"
vim.o.shiftround = true
vim.o.undolevels = 10000

-- Disable swap files (persistent undo is enough)
vim.o.swapfile = false

-- GUI font (for remote GUI clients like Neovide)
vim.o.guifont = "FiraCode Nerd Font:h18"

-- Highlight yanked text briefly
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.hl.on_yank({ higroup = "IncSearch", timeout = 200 })
  end,
})

-- Restore cursor to last known position when opening a file
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function(ev)
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    local lcount = vim.api.nvim_buf_line_count(ev.buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Auto-reload files changed outside Neovim
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  command = "checktime",
})

-- Close certain filetypes with q
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "help", "qf", "notify", "checkhealth" },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = ev.buf, silent = true })
  end,
})

-- Auto-resize splits on terminal resize
vim.api.nvim_create_autocmd("VimResized", {
  callback = function() vim.cmd("tabdo wincmd =") end,
})

-- Auto-create parent directories when saving a file
vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function(ev)
    if ev.match:match("^%w%w+:///") then return end
    local file = vim.uv.fs_realpath(ev.match) or ev.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

-- Bigfile protection: disable expensive features on files > 1.5 MB
vim.api.nvim_create_autocmd("BufReadPre", {
  callback = function(ev)
    local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(ev.buf))
    if ok and stats and stats.size > 1.5 * 1024 * 1024 then
      vim.b[ev.buf].bigfile = true
      vim.opt_local.foldmethod = "manual"
      vim.opt_local.spell = false
      vim.opt_local.swapfile = false
      vim.opt_local.undofile = false
      vim.cmd("syntax clear")
      pcall(vim.treesitter.stop, ev.buf)
    end
  end,
})
