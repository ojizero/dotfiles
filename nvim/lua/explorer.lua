-- Neo-tree file explorer (left sidebar)

-- Disable netrw (neo-tree replaces it)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Notify LSP when neo-tree renames/moves files (updates imports)
local function on_file_rename(args)
  local changes = {
    files = {
      {
        oldUri = vim.uri_from_fname(args.source),
        newUri = vim.uri_from_fname(args.destination),
      },
    },
  }
  for _, client in ipairs(vim.lsp.get_clients()) do
    if client:supports_method("workspace/willRenameFiles") then
      local resp = client:request_sync("workspace/willRenameFiles", changes, 1000, 0)
      if resp and resp.result then
        vim.lsp.util.apply_workspace_edit(resp.result, client.offset_encoding)
      end
    end
    if client:supports_method("workspace/didRenameFiles") then
      client:notify("workspace/didRenameFiles", changes)
    end
  end
end

local events = require("neo-tree.events")

require("neo-tree").setup({
  close_if_last_window = true,
  popup_border_style = "rounded",
  open_files_do_not_replace_types = { "terminal", "Trouble", "qf" },
  event_handlers = {
    { event = events.FILE_RENAMED, handler = on_file_rename },
    { event = events.FILE_MOVED, handler = on_file_rename },
  },
  window = {
    position = "left",
    width = 30,
    mappings = {
      ["b"] = "noop", -- free <leader>b for global toggle
      ["<space>"] = "none",
      ["l"] = "open",
      ["h"] = "close_node",
    },
  },
  filesystem = {
    follow_current_file = { enabled = true },
    use_libuv_file_watcher = true,
    bind_to_cwd = false,
    filtered_items = {
      hide_dotfiles = false,
      hide_gitignored = true,
    },
  },
  default_component_configs = {
    indent = {
      with_markers = true,
      indent_size = 2,
    },
    git_status = {
      symbols = {
        added = "✚",
        modified = "",
        deleted = "✖",
        renamed = "󰁕",
        untracked = "",
        ignored = "",
        unstaged = "󰄱",
        staged = "",
        conflict = "",
      },
    },
  },
})

-- Apply higher-contrast cursorline in Neo-tree windows (see theme.lua)
vim.api.nvim_create_autocmd("FileType", {
  pattern = "neo-tree",
  callback = function()
    vim.wo.winhighlight = "CursorLine:NeoTreeCursorLine"
    vim.wo.statuscolumn = ""
  end,
})

-- Persist Neo-tree open/closed state across sessions
local state_dir = vim.fn.stdpath("state")
local state_file = state_dir .. "/neo-tree-open"

local function is_neo_tree_open()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "neo-tree" then
      return true
    end
  end
  return false
end

-- Save state on exit
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    if is_neo_tree_open() then
      vim.fn.writefile({ "open" }, state_file)
    else
      vim.fn.delete(state_file)
    end
  end,
})

-- Restore on startup (deferred so plugins finish loading)
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if vim.fn.filereadable(state_file) == 1 then
      -- Don't open if nvim was launched with a specific file via stdin or diff mode
      if vim.fn.argc() <= 1 and not vim.o.diff then
        vim.cmd("Neotree show")
      end
    end
  end,
})
