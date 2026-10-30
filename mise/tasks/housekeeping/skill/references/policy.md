# What housekeeping cleans, and why

The rules below are enforced in the mise tasks under [`mise/tasks/housekeeping/`](../../); this file explains them. Change behaviour in the code, then here.

## Every run (routine)

| Area | Action | Guard |
|---|---|---|
| Docker | `image prune -af`, `builder prune -af`, `network prune -f`, each `--filter until=168h` | Only when the daemon is already running; it is never started. Volumes and containers are never pruned. |
| Worktrees | `adw purge` with exact run IDs for ADW runs, `wt remove --no-delete-branch` otherwise | All worktree gates below |
| Homebrew | `brew cleanup --prune=all` | Skipped while `brew` runs |
| uv | `uv cache prune` | Skipped while uv installs or syncs, or while another uv process holds the cache |
| pnpm | `pnpm store prune` | Skipped while pnpm installs |
| Simulators | `xcrun simctl delete unavailable` | |
| Xcode | Delete DerivedData folders untouched for 14 days | Skipped while Xcode or `xcodebuild` runs |

## Only while free space is low

When free space is still below the warning line after the routine steps, it also runs `uv cache clean`, `bun pm cache rm`, `npm cache clean --force`, `dotnet nuget locals all --clear`, `go clean -cache`, all Docker build cache, all DerivedData, and the configured `disposable` folders (those untouched for 14 days that no process is inside). These cost re-downloads and rebuilds, so a healthy disk skips them.

## Worktree gates

These follow the Oct 16 retrospective. A worktree is removed only when every gate passes. Any unknown keeps it, and the report says which gate kept it.

- It is a linked worktree (`.git` is a file) of an ADW-registered project or a configured repository. Main checkouts, registered ADW project roots, `~/.t3` worktrees (T3 Code owns those), locked trees, and ADW trees without a run record are kept.
- No ADW run for it is pending or running, and no process has its working directory inside it.
- `git status` is clean: no modified, staged, or untracked files.
- HEAD is incorporated in the default branch after `git fetch --prune origin`. Either it is an ancestor of the default branch, or it was squash or rebase merged: a GitHub PR merged into the default branch has HEAD at or behind its final head, and its landing commit is in the default branch. Branch names, finished runs, closed or unmerged PRs, and PRs merged into another branch are not proof. A commit beyond the PR's final head keeps the worktree.
- Ignored files hold no user data. Regenerable names (`node_modules`, `_build`, `deps`, `.venv`, …) pass. A `.env`-style file passes only when each line is in the main checkout's copy or in ADW's `.ports.env`. Databases, keys, media, and models fail, as does any other ignored directory with files in it.

Removal goes only through the managers, and there is no direct-delete fallback. ADW trees get `adw purge --dry-run` and then `adw purge --yes` with the same run IDs. Records are kept. Other trees use `wt remove --no-delete-branch`. Branch refs stay in both cases. At most 25 worktrees go per run, the first failed removal stops the rest, and after each removal the main checkout must still resolve `HEAD`. Configured `disposable` folders that are or contain a Git checkout are never deleted.

## Always left alone

Docker volumes and stopped containers, Playwright browsers, T3/ADW/agent histories and databases, credentials, APFS snapshots, swap, and running processes. The report lists the large ones under "What it left alone", with their sizes.

## Limits and files

- `mise run housekeeping:periodic` schedules a weekly run as a launchd agent, Saturdays at 03:00 unless given `--day` and `--at` (for example `--day sunday --at 22:30`); launchd runs a missed slot on wake. Scheduled runs post a macOS notification when a step fails or the disk is not healthy. `--remove` unschedules it.
- A run stops starting new steps after 9 minutes and reports the rest as skipped, so it finishes inside a 10-minute shell timeout.
- A second run while one is in progress exits immediately; scheduled and manual runs share this lock.
- A failed `git fetch` does not stop a run. Merge checks then use the local refs, which can only keep more worktrees, and the keep reason says the fetch failed.
- State lives in `~/.local/state/housekeeping/` (`$XDG_STATE_HOME`; Git ignores it in the dotfiles repo): `report.html` (the latest report), `last-run.json` (full detail), `history.jsonl` (one line per run, last 500 kept, which feeds the history chart), `progress.json` (only while a run is going), `scheduled.log` (output of scheduled runs), and `dry-run.*` for dry runs, which add no history.
- Freed space is the host's free-space gain around each action. For Docker it is the larger of that gain and Docker's own figure, because the VM disk returns space to the host gradually.

## Settings

The optional `~/.config/housekeeping.json` takes the keys in [config.example.json](../../lib/config.example.json); a missing file means defaults. Pass `--config PATH` to use another file. An invalid file stops the run with an error rather than falling back.

- `warning_percent` (default 15) and `urgent_gib` (default 25): the low-space lines.
- `repositories`: extra repositories whose worktrees `wt` manages. ADW projects are found automatically.
- `disposable`: build-output folders that may be deleted while space is low.
- `skip`: steps to turn off: `brew`, `uv`, `pnpm`, `simulators`, `docker`, `xcode`, `worktrees`, `deep`.
- `state_dir`: where state is written.
