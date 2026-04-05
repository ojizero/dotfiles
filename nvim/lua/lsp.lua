-- LSP server configurations using Neovim 0.12+ native API
-- Each server is only enabled if its binary is found on $PATH

-- Diagnostics display
vim.diagnostic.config({
  virtual_text = { spacing = 4, prefix = "●", source = "if_many" },
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = { border = "rounded" },
})

-- LSP keymaps on attach
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local opts = { buffer = ev.buf }
    local client = vim.lsp.get_client_by_id(ev.data.client_id)

    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
    vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
    vim.keymap.set("n", "gy", vim.lsp.buf.type_definition, opts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "gK", vim.lsp.buf.signature_help, opts)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
    vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)
    vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts)
    vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
    vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)

    -- Inlay hints
    if client and client:supports_method("textDocument/inlayHint") then
      vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
    end

    -- Disable ruff hover (basedpyright provides hover for Python)
    if client and client.name == "ruff" then
      client.server_capabilities.hoverProvider = false
    end
  end,
})

-- Format on save via conform.nvim (timeout-safe, supports non-LSP formatters)
require("conform").setup({
  format_on_save = {
    timeout_ms = 3000,
    lsp_format = "fallback",
  },
  formatters_by_ft = {
    lua = { "stylua" },
    python = { "ruff_format" },
    javascript = { "prettierd", "prettier", stop_after_first = true },
    typescript = { "prettierd", "prettier", stop_after_first = true },
    javascriptreact = { "prettierd", "prettier", stop_after_first = true },
    typescriptreact = { "prettierd", "prettier", stop_after_first = true },
    css = { "prettierd", "prettier", stop_after_first = true },
    html = { "prettierd", "prettier", stop_after_first = true },
    json = { "prettierd", "prettier", stop_after_first = true },
    yaml = { "prettierd", "prettier", stop_after_first = true },
    markdown = { "prettierd", "prettier", stop_after_first = true },
    go = { "gofumpt", "goimports" },
  },
})

-- Helper: only configure a server if its binary exists
local function enable_if_available(name, config)
  local cmd = (config and config.cmd and config.cmd[1]) or name
  if vim.fn.executable(cmd) == 1 then
    vim.lsp.config(name, config or {})
    vim.lsp.enable(name)
  end
end

-- Rust
enable_if_available("rust_analyzer", { cmd = { "rust-analyzer" } })

-- Python
enable_if_available("basedpyright", { cmd = { "basedpyright-langserver", "--stdio" } })
enable_if_available("ruff", { cmd = { "ruff", "server" } })

-- TypeScript / JavaScript
enable_if_available("vtsls", { cmd = { "vtsls", "--stdio" } })

-- Go
enable_if_available("gopls", {
  cmd = { "gopls" },
  settings = {
    gopls = {
      gofumpt = true,
      staticcheck = true,
      completeUnimported = true,
      usePlaceholders = true,
      hints = {
        assignVariableTypes = true,
        compositeLiteralFields = true,
        compositeLiteralTypes = true,
        constantValues = true,
        functionTypeParameters = true,
        parameterNames = true,
        rangeVariableTypes = true,
      },
    },
  },
})

-- C / C++
enable_if_available("clangd", { cmd = { "clangd" } })

-- Bash / Zsh
enable_if_available("bashls", { cmd = { "bash-language-server", "start" } })

-- Lua
enable_if_available("lua_ls", {
  cmd = { "lua-language-server" },
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      workspace = {
        library = vim.api.nvim_get_runtime_file("", true),
        checkThirdParty = false,
      },
    },
  },
})

-- YAML
enable_if_available("yamlls", {
  cmd = { "yaml-language-server", "--stdio" },
  settings = {
    yaml = {
      schemaStore = { enable = false, url = "" },
      schemas = require("schemastore").yaml.schemas(),
    },
  },
})

-- CSS
enable_if_available("cssls", { cmd = { "vscode-css-language-server", "--stdio" } })

-- JSON
enable_if_available("jsonls", {
  cmd = { "vscode-json-language-server", "--stdio" },
  settings = {
    json = {
      schemas = require("schemastore").json.schemas(),
      validate = { enable = true },
    },
  },
})

-- HTML
enable_if_available("html", { cmd = { "vscode-html-language-server", "--stdio" } })

-- Elixir
enable_if_available("elixirls", { cmd = { "elixir-ls" } })

-- Erlang
enable_if_available("elp", { cmd = { "elp", "server" } })
