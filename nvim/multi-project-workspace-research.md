# Multi-Project Workspace Support in Neovim

Research date: 2026-04-02

## What VSCode/Zed Actually Provide

### VSCode Multi-Root Workspaces

`.code-workspace` files open multiple unrelated folder roots in a single window:

- Unified file explorer with all roots as top-level entries
- Cross-root search spanning all roots
- Per-root settings via `.vscode/settings.json`
- LSP awareness across all workspace folders
- Cross-root debugging with folder-name suffixed launch configs
- Persistent `.code-workspace` file committed to version control

### Zed Multi-Root Projects

Zed allows adding multiple folders to a single project window with cross-folder search and file finder. However:

- No `.code-workspace` equivalent — projects are not persisted
- Git panel only shows one repository per window
- Full multi-root support is highly requested (issue #15120, discussion #39292) but incomplete

---

## Neovim's Native Capabilities

### Working Directory Scoping

| Command | Scope | Effect |
|---------|-------|--------|
| `:cd` | Global | Changes cwd for entire instance |
| `:tcd` | Tab-local | Overrides global cwd for current tab |
| `:lcd` | Window-local | Overrides tab cwd for current window |

`:tcd` is the foundation of the "tab-per-project" pattern.

### LSP Workspace Folders

Built-in support via:

- `vim.lsp.buf.add_workspace_folder(path)`
- `vim.lsp.buf.remove_workspace_folder(path)`
- `vim.lsp.buf.list_workspace_folders()`
- `workspace_folders` field in `vim.lsp.ClientConfig`

Most modern LSP servers support this (TypeScript, Rust Analyzer, Lua LS, Pyright, etc.).

### No Native Multi-Root Support Planned

- [Issue #29941](https://github.com/neovim/neovim/issues/29941) (buffer group/namespace) — **closed as "Not Planned"**. Maintainers favor multiple Neovim instances over multi-tenancy.
- [Issue #31982](https://github.com/neovim/neovim/issues/31982) (`.code-workspace` support for LSP) — open but in "needs-owner" milestone.
- [PR #20779](https://github.com/neovim/neovim/pull/20779) (automatic multi-root LSP) — rejected.
- [Issue #30463](https://github.com/neovim/neovim/issues/30463) (multibuffer support) — on roadmap but "needs-owner", no timeline.

---

## Relevant Plugins

### Project Switching (one project at a time)

| Plugin | Stars | Status | Notes |
|--------|-------|--------|-------|
| [project.nvim (DrKJeff16 fork)](https://github.com/DrKJeff16/project.nvim) | 149 | Active (2026) | Supports fzf-lua, snacks.nvim. Requires Neovim >= 0.11 |
| [neovim-project](https://github.com/coffebar/neovim-project) | 286 | Active (2026) | Session history, per-branch sessions, fzf-lua support |
| [telescope-project.nvim](https://github.com/nvim-telescope/telescope-project.nvim) | 667 | Active (2025) | Telescope-only. `cd_scope = "tab"` for tab-per-project |
| [workspaces.nvim](https://github.com/natecraddock/workspaces.nvim) | 372 | Active (2026) | Picker-agnostic, hook system, intentionally minimal |

### Buffer Scoping (the critical missing piece)

| Plugin | Stars | Status | Notes |
|--------|-------|--------|-------|
| [scope.nvim](https://github.com/tiagovla/scope.nvim) | 528 | Active (2025) | Scopes buffers to tabs. Session serialization. Best option |
| [tabscope.nvim](https://github.com/backdround/tabscope.nvim) | 59 | Unmaintained (2023) | Simpler API but fewer features |
| [three.nvim](https://github.com/stevearc/three.nvim) | 23 | Niche (2025) | Opinionated "one tab per project" workflow |

### Session Management

| Plugin | Stars | Status | Notes |
|--------|-------|--------|-------|
| [sessions.nvim](https://github.com/natecraddock/sessions.nvim) | 155 | Active (2026) | Pairs with workspaces.nvim. Wraps `:mksession` |
| [auto-session](https://github.com/rmagatti/auto-session) | 1801 | Active (2026) | Auto saves/restores per cwd. Session lens for Telescope |

### LSP Workspace Folders

| Plugin | Stars | Status | Notes |
|--------|-------|--------|-------|
| [workspace-folders.nvim](https://github.com/mhanberg/workspace-folders.nvim) | 6 | Minimal (2024) | Reads `.code-workspace` for LSP workspace_folders only |

---

## Community Patterns

### Pattern 1: Multiple Neovim Instances (most common, Neovim team recommended)

Separate instances per project in tmux/Zellij/terminal tabs.

- **Pros**: Complete isolation, zero config
- **Cons**: No cross-project navigation within Neovim

### Pattern 2: Tab-Per-Project (closest to VSCode)

Assemble from:
1. `:tcd` (built-in) — tab-local cwd
2. **scope.nvim** — buffer scoping per tab
3. **workspaces.nvim** or **project.nvim (DrKJeff16)** — project picker (fzf-lua compatible)
4. **sessions.nvim** or **auto-session** — persistence
5. **Neo-tree** — file tree follows `:tcd` per tab
6. `vim.lsp.buf.add_workspace_folder()` — multi-root LSP

- **Pros**: Single Neovim instance, instant tab switching, scoped buffers/tree/cwd
- **Cons**: Jumplist/quickfix remain global, no unified file tree, no cross-root search

### Pattern 3: Session Switching (swap entire context)

Save/load full sessions per project. One project visible at a time.

- **Pros**: Clean context, reliable session restore
- **Cons**: Only one project at a time, visible pause on switch

---

## Gap Analysis

| Feature | VSCode | Neovim (best available) | Gap |
|---------|--------|------------------------|-----|
| Multiple roots in one window | Native | `:tcd` per tab | Roots in separate tabs, not unified |
| Unified file tree | Native | Not available | Neo-tree shows one root per instance |
| Cross-root search | Native | Not available | Would need custom multi-dir picker |
| Per-root settings | `.vscode/settings.json` | `.nvim.lua` + `exrc` | Partial — works for LSP |
| Per-root LSP | Native | `workspace_folders` API | Works but manual wiring |
| Buffer scoping | Native | scope.nvim | Works for `:bnext`/`:bprev`, not jumplist |
| Cross-root debugging | Native | Not available | No equivalent |
| Persistent workspace file | `.code-workspace` | No standard | workspace-folders.nvim only for LSP |
| Jumplist scoping | Implicit | Not available | Fundamental Vim limitation |

---

## Recommendation for This Config

Given the current setup (fzf-lua, Neo-tree, no session management, Neovim 0.12+ with vim.pack):

**Best fit: Tab-per-project with scope.nvim + workspaces.nvim + sessions.nvim**

- **workspaces.nvim** over telescope-project.nvim (picker-agnostic, works with fzf-lua)
- **scope.nvim** for buffer isolation per tab
- **sessions.nvim** for persistence (pairs naturally with workspaces.nvim)
- Neo-tree already follows `:tcd` per tab

This gets ~70% of the VSCode experience. The main gaps (unified tree, cross-root search, jumplist scoping) have no plugin solutions.
