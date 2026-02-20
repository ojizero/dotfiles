---
name: tool-versions
description: Manage .tool-versions — check for updates to ASDF-managed runtimes and bump versions.
disable-model-invocation: true
argument-hint: "[list|check|bump <tool> [version]|bump-all]"
---

# Tool Versions Manager

Manage the `.tool-versions` file for ASDF-managed runtimes.

Command: $ARGUMENTS

## Subcommands

- `list` — show current versions from `.tool-versions`
- `check` — for each tool, find the latest stable version via `asdf list all <name>` or web search
- `bump <tool> [version]` — update a specific tool's version in `.tool-versions`
- `bump-all` — check and propose updates for all tools (confirm each individually)

## Version Format Rules

These tools have special version formats that must be preserved:

- **elixir**: includes OTP suffix, e.g. `1.19.2-otp-28` — the OTP version may need updating too
- **python**: uses `t` suffix for free-threaded builds, e.g. `3.14.0t` — preserve the `t`
- **erlang**: plain version, e.g. `28.1.1`
- **nodejs**: plain version, e.g. `22.21.1`
- **bun**: plain version, e.g. `1.3.6`
- **uv**: plain version, e.g. `0.9.7`
- **dotnet**: plain version, e.g. `10.0.100`

## Reference Files

- @.tool-versions — current versions
- @bootstrap/common/04-asdf.setup — ASDF plugin registration
