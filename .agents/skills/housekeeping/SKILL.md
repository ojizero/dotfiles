---
name: housekeeping
description: Autonomous macOS disk cleanup (Docker, package caches, merged worktrees, Xcode) with a visual report of what it did and left alone. Use for scheduled housekeeping, low disk space, or "what would housekeeping clean".
---

# Housekeeping

One script does all measuring, cleaning, and reporting. Your job is to run it once and relay its result. It decides every deletion itself through built-in safety gates, so a run needs no questions to the user.

1. From the dotfiles repository root, run:

   ```sh
   python3 .agents/skills/housekeeping/scripts/housekeeping.py
   ```

   It takes up to 10 minutes. Use your shell tool's longest timeout (Claude Code: `600000` ms) and wait for it to exit. Run it exactly once per request. Add `--dry-run` only when the user asks what it *would* clean; a dry run removes nothing.

   Done when the output's last line starts with `Report:`, or the output starts with `Housekeeping did not run` or `Housekeeping supports macOS only`.

2. Show the report named on the `Report:` line.
   - If you have the `html_render` tool (T3 Code): read that file, then call `html_render` with `html` set to the file's exact contents, `title` set to `Housekeeping`, and `height` set to `2000`.
   - Otherwise: give the user the file path to open in a browser.

3. Reply with the script's printed lines, unchanged, and nothing else. Every `FAILED:` line stays in the reply.

Read [policy.md](references/policy.md) when the user asks what it cleans, why something was kept, or how to change its settings.
