# Dotfiles Repository

Personal dotfiles for macOS.

## Repository Layout

```
.zshrc, .zprofile          # Shell config (zsh + Oh-My-Zsh + oh-my-posh)
.gitconfig                 # Git config (aliases, SSH URLs, delta)
.mise.toml                  # Mise version manager + bootstrap config
.mise.local.toml.sample     # Tracked stub for per-machine mise overrides
bunfig.toml                # Bun package manager config
uv/uv.toml                  # uv (Python) package manager config
Brewfile                   # Homebrew packages
omp.toml                   # Oh-My-Posh prompt config
omz/auto/*.zsh             # Auto-loaded shell modules (aliases, completions, history, keybindings, misc)
omz/completions/           # Custom completions
.mise/tasks/               # Global mise tasks (symlinked to ~/.config/mise/tasks)
bootstrap/install.sh       # New-device bootstrap (SSH, Homebrew, mise bootstrap)
bootstrap/macos/extras.setup  # macOS extras task (pmset, gatekeeper, updates)
.local/                    # Git-ignored local overrides (.gitconfig, .zprofile, Brewfile, bin/)
zed/                       # Zed editor config
iTerm2/                    # iTerm2 settings plist
.aws/                      # AWS profiles
.brew-aliases/             # Homebrew alias shortcuts
.claude-x/                 # Alternate Claude Code settings (linked into ~/.claude-x)
mcp/                       # MCP catalog for Docker Desktop
.pi/agent/                 # Pi coding agent config (mirrors ~/.pi/agent: settings.json + extensions/)
.codex/rules/              # Codex global execution-policy rules
dotagent/                  # dotagents skill tracker (agents.toml -> ~/.agents/agents.toml)
```

Synology NAS Compose stacks and DSM tasks live in the separate `island` repository.

## Key Patterns

### Symlink Installation
All dotfiles are symlinked from this repo to `$HOME` via `[dotfiles]` in `.mise.toml` and applied with `mise bootstrap dotfiles apply`.
Pattern: targets in `[dotfiles]` resolve sources relative to the repo root.

Managed symlinks (23 total):

| Target | Source |
|--------|--------|
| `~/.local` | `.local` |
| `~/.brew-aliases` | `.brew-aliases` |
| `~/.Brewfile` | `Brewfile` |
| `~/.zshrc` | `.zshrc` |
| `~/.zprofile` | `.zprofile` |
| `~/.gitconfig` | `.gitconfig` |
| `~/.bunfig.toml` | `bunfig.toml` |
| `~/.config/mise/config.toml` | `.mise.toml` |
| `~/.config/mise/config.local.toml` | `.mise.local.toml` |
| `~/.config/mise/tasks` | `.mise/tasks` |
| `~/.config/uv` | `uv` |
| `~/.claude/settings.json` | `.claude/settings.json` |
| `~/.claude/statusline-command.sh` | `.claude/statusline-command.sh` |
| `~/.claude-x/settings.json` | `.claude-x/settings.json` |
| `~/.claude-x/statusline-command.sh` | `.claude/statusline-command.sh` |
| `~/.config/ghostty` | `ghostty` |
| `~/.config/nvim` | `nvim` |
| `~/.config/worktrunk` | `worktrunk` |
| `~/.pi/agent/settings.json` | `.pi/agent/settings.json` |
| `~/.pi/agent/extensions` | `.pi/agent/extensions` |
| `~/.codex/rules/host-tools.rules` | `.codex/rules/host-tools.rules` |
| `~/.agents/agents.toml` | `dotagent/agents.toml` |
| `~/.claude-x/skills` | `~/.agents/skills` (generated, not repo content) |

Reference-only paths (not symlinked): `omz/`, `omp.toml`, `glow/`, `zed/`, `iTerm2/`.

### Local Override Pattern
`.local/` is git-ignored. It provides per-machine customization:
- `.local/.gitconfig` — included via `[include]` in `.gitconfig`
- `.local/.zprofile` — sourced in `.zprofile` if it exists
- `.local/Brewfile` — concatenated with main `Brewfile` during `mise run dotfiles:bundle`
- `.local/bin/` — added to `$PATH`

`.mise.local.toml` is git-ignored per-machine tool/settings overrides. On first bootstrap, `.mise.local.toml.sample` is copied if missing.

### Bootstrap (Mise)
Machine setup is declared in `.mise.toml` and converged with `mise bootstrap`:

1. `[bootstrap.hooks.pre-packages]` — install Homebrew if missing
2. `[bootstrap.repos]` — clone at `~/workspace/self/dotfiles` (new machines)
3. `[bootstrap.hooks.pre-dotfiles]` — `mkdir -p ~/.agents/skills`, `m dotfiles:seed-local` (both create `[dotfiles]` sources that are not repo content)
4. `[dotfiles]` — apply 23 symlinks
5. `[bootstrap.hooks.post-dotfiles]` — mkdirs, `m dotfiles:bundle` (trusts Brewfile taps first)
6. `[bootstrap.macos.*]` — Dock, Finder, trackpad, defaults
7. `[bootstrap.hooks.post-defaults]` — `killall Dock`
8. `mise install` — tools from `[tools]`
9. `[bootstrap.hooks.post-tools]` — `m dotfiles:trust`, `m dotfiles:agents`
10. `[tasks.bootstrap]` — `bootstrap/macos/extras.setup` (pmset, gatekeeper, updates, battery %)

**Repo path:** `~/workspace/self/dotfiles` — declared in `.mise.toml` `[env].DOTFILES_PATH` and `[bootstrap.repos]`.

**New device:** run `bootstrap/install.sh` (SSH key, clone, Homebrew, `brew install mise`, `mise bootstrap --yes --force-dotfiles`).

**Existing device:** after pulling changes, run `m dotfiles:sync` or the migration runbook below.

Do **not** enable `[bootstrap.mise_shell_activate]` — `.zshrc` already runs `eval "$(mise activate zsh)"`.

### Migration Runbook (Existing Mac)
```bash
m dotfiles:pull
mise bootstrap dotfiles status
mise bootstrap dotfiles apply --dry-run   # expect applied/skipped, no conflicts
mise bootstrap dotfiles apply --yes
mise bootstrap --skip repos --yes
m dotfiles:status                         # should exit 0
```

Use `--force-dotfiles` only when `dotfiles status` reports conflicts (new devices or repair).

### Mise Tasks (the `m` alias)
Global mise tasks live in `.mise/tasks/` (symlinked to `~/.config/mise/tasks`). Tasks are organized as directory-namespaced file scripts (e.g. `.mise/tasks/dns/flush` becomes `mise run dns:flush`). The shell alias `m='mise run'` provides shorthand: `m dns:flush`, `m update:brew`, etc.

Dotfiles tasks:
- `m dotfiles:pull` — git pull
- `m dotfiles:sync` — pull + dotfiles apply + tools + conditional bundle/agents
- `m dotfiles:status` — bootstrap drift + dotfiles status
- `m dotfiles:bootstrap` — full `mise bootstrap --yes`
- `m dotfiles:bundle` — Homebrew bundle from Brewfile
- `m dotfiles:agents` — install agent skills from `dotagent/agents.toml`
- `m dotfiles:seed-local` — seed `.mise.local.toml` from the tracked sample
- `m dotfiles:trust` — trust the repo mise configs
- `m dotfiles:edit` — open repo in `$EDITOR`

### Shell Auto-Loading
Files in `omz/auto/*.zsh` are sourced via `cat` glob in `.zshrc`. Adding a file there makes it auto-loaded.

## Safety Rules

1. NEVER modify `.local/` contents from git
2. NEVER remove dotfile entries from `[dotfiles]` without removing the target symlink
3. Bootstrap hooks and tasks must be idempotent
4. Never hardcode paths — use `$DOTFILES_PATH`, `$HOME`, or relative paths
5. Default branch is `master`
6. Keep Pi config nested under `.pi/agent/` — `.pi/` is Pi's reserved project-config dir, so `pi` run in this repo auto-loads (and executes) anything at `.pi/extensions/`, `.pi/settings.json`, etc. The `agent/` nesting deliberately sidesteps that; do not flatten it.
7. Bootstrap hooks get neither `[env]` nor template rendering — `${DOTFILES_PATH}` is empty inside `[bootstrap.hooks.*]`. Anything needing it must be a `mise run` task, which does get `[env]`.
8. Tasks calling `mise bootstrap [dotfiles] …` must pass `-C "${DOTFILES_PATH}"`. Otherwise mise loads the global config through the `~/.config/mise/config.toml` symlink and resolves every repo-relative `[dotfiles]` source against `~/.config/mise`, which reports them all missing and aborts an apply.
9. Every `[dotfiles]` source must exist before the apply runs — one missing source aborts the whole apply, not just that entry. Sources that are generated rather than repo content need a `pre-dotfiles` hook to create them.
10. Keep the dotagents tracker in `dotagent/` (singular) — same trap as `.pi/`. `.agents/` is dotagents' project-config dir and is scanned for skills, and `agents/` is where it discovers portable subagents. Never run `dotagents init` here either: it writes `agents.toml` through the symlink and replaces the tracked file.
