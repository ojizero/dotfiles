---
name: housekeeping
description: Check current macOS disk headroom and memory pressure, for a quick verification or low-space triage.
---

# Housekeeping

A quick, report-only check of current state. Run from the dotfiles repository root.

1. Run `python3 .agents/skills/housekeeping/scripts/collect.py --config "$HOME/.config/housekeeping.json"`. It prints one JSON object and writes nothing.
2. Read `status` and act on it:
   - `healthy`: reply in one line that free space and memory pressure are within thresholds. Stop.
   - `warning`, `urgent` or `unknown`: run the same command once with `--review` added. Report the `status`, every line in `notices`, and the largest entries in `processes` and `roots`. Name each decision the user needs to make.
   - `unconfigured`: report the notices and stop. Use no guessed paths.
   - `unsupported`: report that this skill runs on macOS only and stop.
3. Read [policy.md](references/policy.md) when the user asks to set up the config, or before you recommend any storage change.

Stay report-only at every status, including `urgent`: every item in the report waits for a user decision.
