-- AI integration: avante (default on) + CodeCompanion (gated) + 99 (gated)

-- render-markdown.nvim — always-on; renders markdown buffers + avante sidebar
-- Including "Avante" in file_types is harmless when avante is off (filetype never appears)
require("render-markdown").setup({
  file_types = { "markdown", "Avante" },
})

-- avante.nvim — AI sidebar using opencode via ACP
if vim.g.enable_avante then
  require("avante").setup({
    provider = "opencode",
    file_selector = {
      provider = "fzf",
    },
  })
  vim.cmd("AvanteBuild")
end

-- :ToggleAvante runtime command
local _avante_active = vim.g.enable_avante or false

vim.api.nvim_create_user_command("ToggleAvante", function()
  if _avante_active then
    _avante_active = false
    pcall(function() require("avante").toggle() end)
    vim.notify("avante disabled (restart nvim to fully unload)", vim.log.levels.INFO)
  else
    if not pcall(require, "avante") then
      vim.pack.add({ "https://github.com/yetone/avante.nvim" })
      require("avante").setup({
        provider = "opencode",
        file_selector = { provider = "fzf" },
      })
    end
    _avante_active = true
    vim.notify("avante enabled", vim.log.levels.INFO)
  end
end, {})

-- CodeCompanion — gated by vim.g.enable_codecompanion
if vim.g.enable_codecompanion then
  require("codecompanion").setup({
    strategies = {
      chat = { adapter = "opencode" },
      agent = { adapter = "opencode" },
    },
    adapters = {
      http = { opts = { show_presets = false } },
      acp = {
        opts = { show_presets = false },
        opencode = "opencode",
      },
    },
  })
end

-- :ToggleCodeCompanion runtime command
local _cc_active = vim.g.enable_codecompanion or false

local function set_cc_keymaps()
  vim.keymap.set({ "n", "v" }, "<leader>ai", "<cmd>CodeCompanionActions<cr>", { desc = "CC: actions" })
  vim.keymap.set({ "n", "v" }, "<leader>ac", "<cmd>CodeCompanionChat toggle<cr>", { desc = "CC: chat" })
end

local function clear_cc_keymaps()
  pcall(vim.keymap.del, "n", "<leader>ai")
  pcall(vim.keymap.del, "v", "<leader>ai")
  pcall(vim.keymap.del, "n", "<leader>ac")
  pcall(vim.keymap.del, "v", "<leader>ac")
end

if _cc_active then
  set_cc_keymaps()
end

vim.api.nvim_create_user_command("ToggleCodeCompanion", function()
  if _cc_active then
    clear_cc_keymaps()
    _cc_active = false
    vim.notify("CodeCompanion disabled", vim.log.levels.INFO)
  else
    if not pcall(require, "codecompanion") then
      vim.pack.add({ "https://github.com/olimorris/codecompanion.nvim" })
      require("codecompanion").setup({
        strategies = {
          chat = { adapter = "opencode" },
          agent = { adapter = "opencode" },
        },
        adapters = {
          http = { opts = { show_presets = false } },
          acp = { opts = { show_presets = false }, opencode = "opencode" },
        },
      })
    end
    set_cc_keymaps()
    _cc_active = true
    vim.notify("CodeCompanion enabled", vim.log.levels.INFO)
  end
end, {})

-- Toggle AI completion source
local ai_completion_enabled = true
vim.api.nvim_create_user_command("ToggleAICompletion", function()
  ai_completion_enabled = not ai_completion_enabled
  vim.notify(
    "AI completion " .. (ai_completion_enabled and "enabled" or "disabled"),
    vim.log.levels.INFO
  )
end, {})

-- 99 — gated by vim.g.enable_99
if vim.g.enable_99 then
  local _99 = require("99")
  _99.setup({
    provider = _99.Providers.ClaudeCodeProvider,
    completion = { source = "blink" },
  })
end

-- :Toggle99 runtime command
local _99_active = vim.g.enable_99 or false
local _99_keymaps = {}

local function set_99_keymaps()
  local _99 = require("99")
  _99_keymaps = {
    vim.keymap.set("n", "<leader>9s", function() _99.search() end, { desc = "99: search" }),
    vim.keymap.set("v", "<leader>9v", function() _99.visual() end, { desc = "99: visual" }),
    vim.keymap.set("n", "<leader>9w", function() _99.Extensions.Worker.set_work() end, { desc = "99: set work" }),
    vim.keymap.set("n", "<leader>9b", function() _99.vibe() end, { desc = "99: vibe" }),
    vim.keymap.set("n", "<leader>9x", function() _99.stop_all_requests() end, { desc = "99: stop all" }),
  }
end

local function clear_99_keymaps()
  pcall(vim.keymap.del, "n", "<leader>9s")
  pcall(vim.keymap.del, "v", "<leader>9v")
  pcall(vim.keymap.del, "n", "<leader>9w")
  pcall(vim.keymap.del, "n", "<leader>9b")
  pcall(vim.keymap.del, "n", "<leader>9x")
end

-- Set keymaps if already enabled at startup
if _99_active then
  set_99_keymaps()
end

vim.api.nvim_create_user_command("Toggle99", function()
  if _99_active then
    clear_99_keymaps()
    _99_active = false
    vim.notify("99 disabled", vim.log.levels.INFO)
  else
    -- Load plugin if not already loaded
    if not pcall(require, "99") then
      vim.pack.add({
        "https://github.com/ThePrimeagen/99",
        { src = "https://github.com/saghen/blink.compat", version = vim.version.range("2.x") },
      })
      local _99 = require("99")
      _99.setup({
        provider = _99.Providers.ClaudeCodeProvider,
        completion = { source = "blink" },
      })
    end
    set_99_keymaps()
    _99_active = true
    vim.notify("99 enabled", vim.log.levels.INFO)
  end
end, {})
