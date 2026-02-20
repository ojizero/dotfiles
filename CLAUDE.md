# Dotfiles Repository

Personal dotfiles for macOS and self-hosted Docker Compose service stacks running on a Synology NAS ("Atlas").

## Repository Layout

```
.zshrc, .zprofile          # Shell config (zsh + Oh-My-Zsh + oh-my-posh)
.gitconfig                 # Git config (aliases, SSH URLs, diff-so-fancy)
.asdfrc, .tool-versions    # ASDF version manager
Brewfile                   # Homebrew packages
omp.toml                   # Oh-My-Posh prompt config
omz/auto/*.zsh             # Auto-loaded shell modules (aliases, completions, history, keybindings, misc)
omz/completions/           # Custom completions
m/                         # Custom CLI tool - dispatches to m/commands/*
bootstrap/common/          # Cross-platform setup scripts (numbered, sourced in order)
bootstrap/macos/           # macOS-specific setup scripts
.local/                    # Git-ignored local overrides (.gitconfig, .zprofile, Brewfile, bin/)
zed/                       # Zed editor config
iTerm2/                    # iTerm2 settings plist
.aws/                      # AWS profiles
.brew-aliases/             # Homebrew alias shortcuts
synology/docker/           # Docker Compose stacks for Synology NAS
mcp/                       # MCP catalog for Docker Desktop
```

## Key Patterns

### Symlink Installation
All dotfiles are symlinked from this repo to `$HOME` via bootstrap scripts.
Pattern: `rm -fr "$HOME/<file>" && ln -s "$DOTFILES_PATH/<file>" "$HOME/<file>"`

Managed symlinks:
- `~/.zshrc` -> `.zshrc`
- `~/.zprofile` -> `.zprofile`
- `~/.gitconfig` -> `.gitconfig`
- `~/.asdfrc` -> `.asdfrc`
- `~/.tool-versions` -> `.tool-versions`
- `~/.local` -> `.local`
- `~/.brew-aliases` -> `.brew-aliases`
- `~/.Brewfile` -> `Brewfile`

### Local Override Pattern
`.local/` is git-ignored. It provides per-machine customization:
- `.local/.gitconfig` — included via `[include]` in `.gitconfig`
- `.local/.zprofile` — sourced in `.zprofile` if it exists
- `.local/Brewfile` — concatenated with main `Brewfile` during `m dotfiles bundle`
- `.local/bin/` — added to `$PATH`

### Bootstrap Scripts
- `bootstrap/common/NN-name.setup` — numbered, run in order on all platforms
- `bootstrap/macos/NN-name.setup` — macOS-specific
- `*.setup.once` — runs once per machine, tracked in `bootstrap/.cache/`
- `*.setup.once.disable` — disabled one-time scripts
- All scripts must be idempotent and use `#!/usr/bin/env zsh`
- Variable convention: `cfg_*` for repo path, `home_*` for home path

### The `m` CLI
Located at `m/m`. Dispatches to scripts in `m/commands/`. Commands follow a `case/esac` pattern with a `usage` function and `help` subcommand. Has alias support via `convert-alias`.

### Shell Auto-Loading
Files in `omz/auto/*.zsh` are sourced via `cat` glob in `.zshrc`. Adding a file there makes it auto-loaded.

## Synology NAS Conventions

### Docker Compose Stacks
Each stack is a directory under `synology/docker/<name>/` containing `compose.yml`.

Services:
- `gateway` — Traefik v3 reverse proxy
- `admin` — Docker socket proxy
- `cloudflare` — Cloudflared tunnel
- `adguard` — AdGuard Home DNS
- `media` — Jellyfin, Sonarr, Radarr, Lidarr, Bazarr, Prowlarr, Transmission, Flaresolverr, Watcharr, Cleanuparr
- `archive` — Karakeep + Meilisearch + headless Chrome
- `bayt-al-hikma` — Audiobookshelf
- `youtube` — Invidious + PostgreSQL + Companion

### Domain Routing
- `*.tn.ojizero.dev` — Tailscale (tailnet)
- `*.ln.ojizero.dev` — Local network
- `*.ojizero.dev` — Public (via Cloudflare tunnel)

Subdomain mnemonics: `m` (media/Jellyfin), `srr` (Sonarr), `rrr` (Radarr), `lrr` (Lidarr), `brr` (Bazarr), `prr` (Prowlarr), `q` (Transmission), `wrr` (Watcharr), `crr` (Cleanuparr), `keep` (Karakeep), `abs` (Audiobookshelf), `yt` (Invidious), `d` (DNS/AdGuard), `atlas` (DSM)

### Network Architecture
- `servicenet` — external bridge, all Traefik-routed services must join this
- `admin-dockernet` — internal, Traefik + Docker socket proxy only
- Service-specific internal networks use descriptive `-sphere` or `-net` suffixes

### Compose File Conventions
- Filename: `compose.yml` (not `docker-compose.yml`)
- Images pinned to exact versions, never `latest`
- `restart: unless-stopped` on all services
- `.env` files git-ignored, `.env.sample` required alongside
- YAML anchors (`x-*`) for shared config (e.g. `x-data-vault`, `x-environment`)

## Safety Rules

1. NEVER commit `.env` files — they contain secrets
2. NEVER use `latest` tags for Docker images
3. NEVER modify `.local/` contents from git
4. NEVER remove symlink bootstrap scripts without removing the target symlink
5. Always create `.env.sample` alongside any `.env` usage
6. Bootstrap scripts must be idempotent
7. Never hardcode paths — use `$DOTFILES_PATH`, `$HOME`, or relative paths
8. Default branch is `master`
