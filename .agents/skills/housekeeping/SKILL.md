---
name: housekeeping
description: Check macOS disk headroom and review configured development storage trends during routine housekeeping or low-space triage.
---

# Housekeeping

Run from dotfiles with Python 3. Default to report-only.

1. Run `python3 .agents/skills/housekeeping/scripts/collect.py --config "$HOME/.config/housekeeping.json"`. For a broader review, add `--review`.
2. Return the JSON status and notices in T3. A healthy daily check ends with a short no-op. For warning, urgent, or unknown results, run one broader review and explain the missing evidence or next decision. Urgency never expands authority.
3. On setup or a storage decision, read [policy.md](references/policy.md). On scheduling requests, read [prompts.md](references/prompts.md). No schedule is installed by this skill.

Missing configuration means unconfigured, not permission to guess scan paths. The collector writes only its private routine telemetry outside the repository. It rotates that telemetry under fixed bounds. All host storage is inventory-only; there is no host cleanup/apply mode. Retain candidates with unknown ownership, activity, dependencies, or merge proof. Historical cleanup permission grants no standing authority.
