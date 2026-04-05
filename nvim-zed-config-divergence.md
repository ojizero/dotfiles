# Nvim ↔ Zed Configuration Divergence

## Zed: Settings Divergences from Defaults (Vim Mode Off)

### Appearance
| Setting | Zed Default | Config |
|---|---|---|
| Theme | One Dark / One Light | Catppuccin Mocha / Latte |
| Icon theme | Zed (Default) | Catppuccin Mocha / Latte |
| Buffer font | .ZedMono, 15px | FiraCode Nerd Font, 18px |
| UI font size | 13 | 18 |

### Editor Behavior
| Setting | Zed Default | Config |
|---|---|---|
| Tab size | 4 | 2 |
| Soft wrap | `"none"` | `"bounded"` |
| Preferred line length | 80 | 100 |
| seed_search_query_from_cursor | `"always"` | `"selection"` |

### UI & Layout
| Setting | Zed Default | Config |
|---|---|---|
| tabs.close_position | `"right"` | `"left"` |
| tabs.file_icons | `false` | `true` |
| tabs.git_status | `false` | `true` |
| tabs.show_diagnostics | `"off"` | `"all"` |
| toolbar.quick_actions | `true` | `false` |
| toolbar.selections_menu | `true` | `false` |
| toolbar.agent_review | `true` | `false` |
| inactive_opacity | `1.0` | `0.75` |
| indent_guides.coloring | `"fixed"` | `"indent_aware"` |
| outline_panel button | shown | disabled |
| notification_panel button | shown | disabled |
| collaboration_panel button | shown | disabled |
| show_onboarding_banner | `true` | `false` |

### Terminal
| Setting | Zed Default | Config |
|---|---|---|
| dock | `"bottom"` | `"right"` |
| blinking | `"terminal_controlled"` | `"on"` |
| max_scroll_history | default | `100000` |
| breadcrumbs | enabled | disabled |

### Telemetry & Misc
| Setting | Zed Default | Config |
|---|---|---|
| telemetry.diagnostics | `true` | `false` |
| telemetry.metrics | `true` | `false` |
| calls.mute_on_join | `false` | `true` |
| calls.share_on_join | `true` | `false` |
| edit_predictions.mode | default | `"subtle"` |

### Custom Keybindings (Divergences from VSCode base)
| Binding | Default Action | Override |
|---|---|---|
| `cmd-g` | Find next | `go_to_line::Toggle` |
| `cmd->` (cmd-shift-.) | — | `assistant::InlineAssist` |
| `ctrl-enter` | Various | Disabled (`null`) in Editor + Terminal |
| `cmd-k cmd-k` | — | `terminal::Clear` |
| `cmd-k cmd-u` | — | `ConvertToUpperCase` |
| `cmd-k cmd-l` | — | `ConvertToLowerCase` |
| `cmd-k cmd-p` | — | `ConvertToUpperCamelCase` |
| `cmd-k cmd-c` | — | `ConvertToLowerCamelCase` |
| `cmd-e` | Find in workspace? | `outline::Toggle` |

---

## Nvim ↔ Zed: Cross-Editor Alignment

### Shared Design Choices (intentional parity)
- Catppuccin with system light/dark auto-switching
- FiraCode Nerd Font at size 18
- Tab size 2, line length 100
- Indent guides with scope/indent-aware coloring
- Bracket colorization (rainbow delimiters in nvim)
- Git gutter + inline blame
- File explorer on left (Neo-tree ↔ Project Panel)
- Fuzzy finder (fzf-lua ↔ built-in)
- LSP with format on save
- AI integration (CodeCompanion ↔ Zed Agent with Claude Opus)
- TODO/FIXME highlighting + search
- Identical task set (git gone/stash, elixir iex/mix/phx)
- Inactive window dimming (NormalNC blend ↔ `inactive_opacity: 0.75`)
- Case conversion keybindings (`<leader>k*` ↔ `cmd-k cmd-*`)

### In Nvim but NOT in Zed
- Relative line numbers
- Smooth scrolling (neoscroll)
- Custom fold column with clickable fold indicators
- Change without yanking (`c`/`C` → black hole register)
- Neo-tree state persistence across sessions
- Right-click context menus with custom actions
- Per-machine local overrides (`~/.local/nvim/init.lua`)
- `<leader>m` search marks
- Notification system (nvim-notify + noice)
- Flash.nvim jump labels (`s`/`S`)
- Trouble diagnostics panel (`<leader>x*`)
- which-key keybinding discovery popup
- grug-far multi-file search and replace (`<leader>sr`)
- conform.nvim formatting (non-LSP formatter support)
- Bigfile protection (disables expensive features on large files)

### In Zed but NOT in Nvim
- Edit predictions (Zed AI completions, `"subtle"` mode)
- Agent panel with Docker MCP server
- Tasks UI (nvim has commands, but no task runner panel)
- Native multi-cursor support
- Tab close position on left

---

## If Zed Vim Mode Is Enabled: Additional Divergences

Enabling `"vim_mode": true` gives modal editing in Zed. Here's how it compares to the nvim keybindings:

### LSP Bindings
| Action | Nvim | Zed Vim Default |
|---|---|---|
| Go to definition | `gd` | `g d` (same) |
| Go to declaration | `gD` | `g D` (same) |
| Go to implementation | `gi` | `g I` |
| Hover | `K` | `g h` |
| Code action | `<leader>ca` | `g .` or `gra` |
| Rename | `<leader>rn` | `grn` or `c d` |
| References | `gr` | `grr` or `g A` |
| Document symbols | `<leader>o` | `g s` |
| Workspace symbols | `<leader>O` | `g S` |
| Next diagnostic | `]d` | `] d` (same) |
| Prev diagnostic | `[d` | `[ d` (same) |
| Diagnostics float | `<leader>d` | `g h` (combined with hover) |

### Git Bindings
| Action | Nvim | Zed Vim Default |
|---|---|---|
| Next hunk | `]h` | `] c` |
| Prev hunk | `[h` | `[ c` |
| Blame line | `<leader>gb` | (inline blame always visible) |

### Navigation
| Action | Nvim | Zed Vim Default |
|---|---|---|
| File finder | `<leader>f` | No vim binding (still `cmd-p`) |
| Live grep | `<leader>sg` | No vim binding (still `cmd-shift-f`) |
| Switch buffers | `<leader>sb` | No vim binding |
| Toggle explorer | `<leader>b` | `:E` or `cmd-shift-e` |
| TODO search | `<leader>st` | No vim binding |
| Window nav | `Ctrl-h/j/k/l` | `Ctrl-w h/j/k/l` |

### Editing Features Zed Vim Adds (not in nvim config)
- **Surround** (`ys`/`cs`/`ds`) — built-in, no plugin needed
- **Multi-cursor** (`gl`/`gL`/`ga`/`gA`) — no nvim equivalent configured
- **vim-exchange** (`cx`) — swap text objects
- **vim-indentwise** (`[-`/`]+` etc.) — indent-based motions
- **Subword motions** (optional, for camelCase/snake_case)

### Key Behavioral Differences
- Zed vim `c`/`C` **does** yank into the default register (nvim maps them to black hole)
- Zed vim uses `"always"` system clipboard by default (same as nvim `unnamedplus`)
- Zed vim search regex is Rust-flavored (not Vim-flavored): `(group)` not `\(group\)`, `$1` not `\1`
- Zed vim `g` flag is NOT default in `:s` (unlike some vim setups), but available via `gdefault` setting
- Nvim's `<Esc>` smart dismiss (noice, clist/llist, hlsearch) has no Zed equivalent

---

## Summary

The two configs are deliberately aligned on aesthetics and workflow (theme, font, tasks, LSP). The divergences are mainly:

1. **Nvim has more polish** — custom fold UX, smooth scrolling, session persistence, smarter Escape, black-hole-register change
2. **Zed has more AI** — edit predictions, agent panel with MCP, inline assist
3. **If vim mode is enabled**, the LSP/git keybindings would differ from nvim muscle memory in several places (`K` vs `gh`, `<leader>ca` vs `g.`, `]h` vs `]c`, `gi` vs `gI`)
