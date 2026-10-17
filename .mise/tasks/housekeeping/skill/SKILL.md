---
name: housekeeping
description: Check on this Mac's scheduled disk cleanup (housekeeping) and diagnose disk space. Shows when it last ran, what it removed or left alone, its HTML report, and where the space goes. Use when the user asks "did housekeeping run", "what did it clean", why the disk is full or low on space, what is taking up space, wants a storage breakdown or to free up space, or asks about caches, worktrees, Docker disk use, swap or memory pressure on this Mac.
---

# Housekeeping

Housekeeping is a set of mise tasks that clean this Mac's disk on a weekly schedule. Your job is to read their output and explain it. Every task below runs from any directory.

| Task | What it does | Time |
|---|---|---|
| `mise run housekeeping:status` | Schedule, a run in progress, the last run's summary, and the largest things it left alone | seconds |
| `mise run housekeeping:disk` | Disk and memory health, Docker usage, and space per location. Removes nothing | up to 2 minutes |
| `mise run housekeeping` | Runs the cleanup now | up to 10 minutes |
| `mise run housekeeping:periodic` | Turns on the weekly schedule, Saturdays 03:00 by default (`--day`, `--at` to change). `--remove` turns it off | seconds |

## Checkup

1. Run `mise run housekeeping:status`.
2. If its output has a `Report:` line and the user wants to see the report:
   - If you have the `html_render` tool (T3 Code): read that file, then call `html_render` with `html` set to the file's exact contents, `title` set to `Housekeeping`, and `height` set to `2000`.
   - Otherwise: give the user the file path to open in a browser.
3. Reply with what the status says. Keep every `FAILED:` line, word for word.

## Diagnostics

When the user asks where space went, or the disk is `warning` or `urgent`:

1. Run `mise run housekeeping:disk`. Use your shell tool's timeout of at least `180000` ms.
2. Report the largest locations and, for each, what housekeeping does with it (in brackets in the output).
3. For space it leaves alone, read [policy.md](references/policy.md) to explain why. Do not delete anything yourself.

## Running or scheduling

Only when the user asks for it:

- To clean now, run `mise run housekeeping` with a timeout of `600000` ms, then do the checkup steps 2 and 3. To preview without removing anything, run `mise run housekeeping --dry-run`.
- To change the schedule, run `mise run housekeeping:periodic --day <weekday> --at <HH:MM>` (it replaces the current one), or `mise run housekeeping:periodic --remove`.

A run that is already going makes a second one exit with `another run is in progress`. Then run `housekeeping:status` to show its progress.

Read [policy.md](references/policy.md) when the user asks what it cleans, why something was kept, or how to change its settings.
