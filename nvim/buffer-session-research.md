# Buffer, Session & Dashboard Plugin Research

> Research conducted 2026-04-02. Stars and maintenance status may change.

## Buffer Management Plugins

Only 3 are worth considering in 2026 — the rest are archived/abandoned.

### mini.bufremove (echasnovski/mini.nvim)

- **Stars:** 8,937 (mini.nvim suite) | **Active:** Yes
- Preserves window layout, falls back to empty scratch buffer on last close
- API: `MiniBufremove.delete(buf, force)`, `.wipeout()`, `.unshow()`
- No user commands (Lua-only), no batch ops (delete all/others)
- No "quit on last buffer" option
- **Minimal config** — single `silent` boolean option
- Replacement priority: alternate buffer → previous listed buffer → new scratch buffer

### snacks.nvim bufdelete (folke/snacks.nvim)

- **Stars:** 7,349 | **Active:** Yes (folke)
- Preserves layout, falls back to empty buffer or can trigger dashboard
- API: `Snacks.bufdelete()`, `.all()`, `.other()` with filter functions
- No user commands (Lua-only)
- No "quit on last buffer" — but can pair with snacks.dashboard
- Replacement priority: alternate buffer → most recently used → new empty buffer
- **Trade-off:** pulls in the full snacks.nvim package (modules are lazy-loaded)

### nvim-bufdel (ojroques/nvim-bufdel)

- **Stars:** 183 | **Active:** No (last commit April 2023)
- **Only plugin with a built-in `quit` option** — quits Neovim when last buffer is deleted
- Has `:BufDel`, `:BufDelAll`, `:BufDelOthers` commands
- Configurable next-buffer strategy: `"tabs"`, `"cycle"`, `"alternate"`, or custom function
- ~120 lines — trivially forkable
- **Unmaintained but simple enough to own**

### Buffer Plugin Comparison

| Feature              | mini.bufremove | snacks bufdelete | nvim-bufdel            |
| -------------------- | -------------- | ---------------- | ---------------------- |
| Preserves layout     | Yes            | Yes              | Yes                    |
| Last buffer → quit   | No             | No               | **Yes (configurable)** |
| Batch delete         | No             | Yes              | Yes                    |
| User commands        | No             | No               | Yes                    |
| Maintained           | Yes            | Yes              | No (2023)              |

---

## Session Management Plugins

### auto-session (rmagatti) — "Just works"

- **Stars:** 1,801 | **Active:** Yes
- Fully automatic save on quit, restore on `nvim` with no args
- **Best file-vs-directory handling:** `nvim` restores, `nvim .` restores, `nvim file.txt` does NOT restore
- Git branch-aware, `suppressed_dirs`/`allowed_dirs` filtering
- Picker support: Telescope, fzf-lua, Snacks, vim.ui.select
- Closes non-file windows (Neo-tree, terminals) before saving
- **Trade-off:** most "magic" — can surprise you if you don't understand the filtering

### persistence.nvim (folke) — Minimal auto-save

- **Stars:** 972 | **Active:** Yes
- Auto-saves on exit, **never auto-restores** (you wire that yourself)
- Git branch-aware, `need = 1` prevents saving empty sessions
- No picker, no session management UI
- **Best for:** smallest footprint, pair with a dashboard for restore

### persisted.nvim (olimorris) — Enhanced persistence

- **Stars:** 532 | **Active:** Yes (v3.0.0 Jan 2026)
- Git branch-aware, `autoload` option, `allowed_dirs`/`ignored_dirs`
- Native Telescope extension (no fzf-lua support)
- Skips auto-load when args are passed (`nvim file.txt` = no restore)
- 0 open issues

### nvim-possession (gennaro-tedesco) — fzf-lua native

- **Stars:** 286 | **Active:** Yes
- **Hard dependency on fzf-lua** — no Telescope option
- Named sessions (not automatic per-directory)
- `autoswitch` cleans up buffers between session switches
- Statusline component for current session name
- Skips autoload when file args are passed

### resession.nvim (stevearc) — Maximum control

- **Stars:** 297 | **Active:** Yes
- **Does NOT use `:mksession`** — custom serialization
- **Tab-scoped sessions** (unique feature)
- Extension system for plugin state save/restore (dap, quickfix, etc.)
- Does nothing automatically — you wire everything yourself
- **Best for:** tab-per-project workflows, proper plugin state persistence

### sessions.nvim (natecraddock) — Building block

- **Stars:** 155 | **Stable** (intentionally minimal)
- Just `SessionsSave` and `SessionsLoad` commands
- Companion: workspaces.nvim for project management
- No auto-anything, no picker, no git awareness
- **Best for:** full DIY with explicit control

### Session Plugin Comparison

| Feature        | auto-session  | persistence | persisted       | nvim-possession | resession  | sessions  |
| -------------- | ------------- | ----------- | --------------- | --------------- | ---------- | --------- |
| Auto-save      | Yes           | On exit     | On exit         | On quit         | Manual     | On events |
| Auto-restore   | Yes           | No          | Optional        | Optional        | No         | No        |
| Git branch     | Yes           | Yes         | Yes             | No              | Manual     | No        |
| fzf-lua        | Yes           | No          | No              | **Required**    | No         | No        |
| Telescope      | Yes           | No          | Yes             | No              | No         | No        |
| File vs dir    | Sophisticated | Manual      | Skips with args | Skips with args | Manual     | Manual    |
| Tab-scoped     | No            | No          | No              | No              | **Yes**    | No        |
| Dependencies   | None          | None        | None            | fzf-lua         | None       | None      |

---

## Dashboard/Starter Plugins

**Key finding:** None of these natively show the dashboard when the last buffer is closed. All require a ~10-15 line `BufDelete` autocmd. This is a standard community pattern.

### snacks.nvim dashboard — Best integration surface

- Declarative section-based layout, multi-pane support
- Auto-detects 5 session managers (persistence, persisted, session-manager, possession, mini.sessions)
- Picker integration with fzf-lua, Telescope, and mini.pick
- **Combined with snacks.bufdelete** this is the closest to a unified solution, but they aren't wired together — you need glue code
- No built-in session save/load — detect-and-display only

### mini.starter — Cleanest API

- Type-ahead filtering, `sections.sessions()` for mini.sessions integration
- `MiniStarter.open()` is a clean public API for the buffer-close autocmd
- Part of the mini.nvim ecosystem (consistent with mini.bufremove, mini.sessions)
- Less flashy, more functional

### alpha-nvim — Most programmable

- Everything is a Lua data structure — maximum customization
- Benchmarked as the fastest greeter
- No native session support (wire it yourself)
- 38 open issues, sporadic maintenance

### dashboard-nvim — Least recommended

- Session support was deliberately removed
- 73 open issues
- Recommends a separate `dbsession.nvim` plugin

---

## Ecosystem Combinations

Context: this config uses **fzf-lua**, **Neo-tree**, and **vim.pack** (not lazy.nvim).

### Option A — mini.nvim suite (minimal, cohesive)

`mini.bufremove` + `mini.sessions` + `mini.starter`

- Same author, same API style, no external deps
- Missing: auto-restore, git branch sessions, fzf-lua integration

### Option B — snacks.nvim (folke ecosystem)

`snacks.bufdelete` + `snacks.dashboard` + `persistence.nvim`

- Richest dashboard, good session detection
- Trade-off: pulls in snacks.nvim (large but lazy-loaded), no auto-restore without custom code

### Option C — fzf-lua native

`mini.bufremove` (or snacks.bufdelete) + `nvim-possession` + no dashboard

- Session management lives in fzf-lua picker
- Lean, no dashboard overhead
- Trade-off: named sessions (not automatic per-directory)

### Option D — Auto-everything

`mini.bufremove` + `auto-session` + optional dashboard

- Most automatic: save on quit, restore on open, handles file-vs-directory natively
- fzf-lua picker support built in
- Trade-off: most "magic", can surprise you

### Option E — DIY maximum control

`mini.bufremove` + `resession.nvim` + custom autocmds

- Tab-scoped sessions, extension system for Neo-tree state
- You wire everything yourself
- Best if you later implement the multi-project workspace from the research doc
