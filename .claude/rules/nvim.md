---
paths:
  - "nvim/**"
---

Neovim configuration conventions (Neovim 0.12+):

## Plugin management

- MUST use `vim.pack.add()` — the native Neovim 0.12+ pack manager. NEVER use lazy.nvim, packer, or any third-party plugin manager syntax. NEVER `require("lazy")` or depend on any lazy.nvim runtime module (e.g., `lazy.stats`).
- `vim.pack.add()` takes a **list** (table), not a string: `vim.pack.add({ gh .. "author/repo" })`. A bare string argument will crash with `E5113`.
- Versioned plugins use `{ src = gh .. "author/repo", version = vim.version.range("1.x") }`.
- All plugin declarations go in `plugins.lua`. Configuration goes in the relevant module file.
- `vim.pack` has NO build hooks. If a plugin requires a build step (e.g., native compilation), call it explicitly in the module file (e.g., `vim.cmd("silent! AvanteBuild")`).
- Before adding a new plugin, check if snacks.nvim already provides the feature. Snacks covers: picker, explorer, notifier, indent, scroll, statuscolumn, bigfile, dashboard, zen, input, rename, word highlights, quickfile, toggle.

## Module architecture

- Each lua module is one concern. `init.lua` requires them in strict dependency order — read the file for current order.
- `local` MUST always be last (machine-specific overrides from `~/.local/nvim/init.lua`).
- When adding a new module, place the `require()` in `init.lua` after its dependencies.
- Module naming: NEVER name a config file the same as the plugin it configures. Lua's `require()` resolves local files first, causing infinite loops or shadowing. macOS is case-insensitive (`comment.lua` shadows `Comment.nvim`). Example: snacks.nvim config is `candy.lua`, not `snacks.lua`.

## Config placement rules

- Plugin setup/config NEVER goes in `plugins.lua` — only declarations.
- LSP servers, diagnostics, formatters, LspAttach keymaps → `lsp.lua`
- snacks.nvim features → `candy.lua` (not `snacks.lua` — see naming rule)
- AI plugins → `ai.lua` (gated behind `vim.g.enable_*` flags)
- Right-click menus → `mouse.lua`
- All non-LSP keybindings → `keymaps.lua`

## Key patterns

- **Keymaps**: always include `desc` for which-key discovery. Keymaps go in `keymaps.lua` unless they are buffer-local (LSP keymaps in `lsp.lua`, git hunks in `git.lua`).
- **LSP servers**: registered via `enable_if_available(name, config)` which checks `vim.fn.executable()` before calling `vim.lsp.config()` + `vim.lsp.enable()`. NEVER hardcode an LSP server without the executable guard. NEVER use the deprecated `require('lspconfig').<server>.setup()` API.
- **Treesitter**: parser installation via `require("nvim-treesitter").install()`. Highlighting is enabled via a FileType autocmd calling `vim.treesitter.start()`. NEVER use the deprecated `require("nvim-treesitter.configs").setup()` API.
- **AI plugins**: gated behind `vim.g.enable_<name>` flags (default off). The toggle pattern has 4 parts: (1) `vim.g.enable_<name>` flag with conditional `require().setup()`, (2) `:Toggle<Name>` user command, (3) lazy-load via `vim.pack.add()` on first enable if not already loaded, (4) local `_<name>_active` state variable to track toggle state. Follow this exact pattern when adding AI integrations. NOTE: gated plugins have two loading paths — startup (`plugins.lua` conditional) and runtime toggle (`ai.lua` command). Both paths must include the same dependencies.
- **Formatting**: conform.nvim with `lsp_format = "fallback"`. Add new formatters to `formatters_by_ft` in `lsp.lua`.
- **Statusline**: lualine sections X, Y, Z are empty — reserved for Claude Code. NEVER add content to the right side.
- **User commands**: PascalCase (`:GitGone`, `:ToggleAvante`).

## Multi-file coordination

- **Adding a plugin**: (1) declare in `plugins.lua`, (2) configure in the relevant module file, (3) add `require()` to `init.lua` if new module, (4) register catppuccin integration in `theme.lua` if the plugin has one, (5) add keymaps in `keymaps.lua`.
- **Removing a plugin**: (1) remove from `plugins.lua`, (2) remove `require()` from `init.lua`, (3) delete the module file, (4) remove keymaps, (5) remove catppuccin integration from `theme.lua`, (6) remove lualine extensions if any.
- **Do not add custom treesitter queries** (`nvim/queries/`) without first checking if nvim-treesitter already ships one for that language.

## What NOT to do

- Do not suggest telescope, fzf-lua, nvim-tree, nvim-notify, indent-blankline, or neoscroll — snacks.nvim replaced all of these.
- Do not bypass the `enable_if_available` pattern for LSP servers.
- Do not use `vim.api.nvim_set_keymap` — use `vim.keymap.set`.
- Do not add format-on-save via LSP directly — conform.nvim owns formatting.

## Which-key groups

New leader-prefixed keymaps SHOULD fit an existing which-key group (check `keymaps.lua` for current groups) or define a new one.

## Verification

- After editing config: `nvim --headless "+q"` to check for startup errors.
