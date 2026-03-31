-- LSP server configurations using Neovim 0.12+ native API
-- Each server is only enabled if its binary is found on $PATH

-- Diagnostics display
vim.diagnostic.config({
  virtual_text = { spacing = 4, prefix = "●" },
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
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
    vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
    vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)
    vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts)
    vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
    vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)

    -- Format on save
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client:supports_method("textDocument/formatting") then
      vim.api.nvim_create_autocmd("BufWritePre", {
        buffer = ev.buf,
        callback = function()
          vim.lsp.buf.format({ bufnr = ev.buf })
        end,
      })
    end
  end,
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
enable_if_available("gopls", { cmd = { "gopls" } })

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
enable_if_available("yamlls", { cmd = { "yaml-language-server", "--stdio" } })

-- CSS
enable_if_available("cssls", { cmd = { "vscode-css-language-server", "--stdio" } })

-- JSON
enable_if_available("jsonls", { cmd = { "vscode-json-language-server", "--stdio" } })

-- HTML
enable_if_available("html", { cmd = { "vscode-html-language-server", "--stdio" } })

-- Elixir
enable_if_available("elixirls", { cmd = { "elixir-ls" } })

-- Erlang
enable_if_available("elp", { cmd = { "elp", "server" } })
