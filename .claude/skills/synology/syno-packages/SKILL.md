---
name: syno-packages
description: List and manage Synology DSM packages — show installed versions, check for updates, start/stop services.
disable-model-invocation: true
argument-hint: "[list|updates|start <pkg>|stop <pkg>]"
---

# Synology Package Manager

List and manage DSM packages via the Synology Web API.

Command: $ARGUMENTS

## Prerequisites

Environment variables must be set:
- `$SYNOLOGY_HOST` — NAS hostname or IP (e.g. `atlas.tn.ojizero.dev`)
- `$SYNOLOGY_USER` — DSM admin username
- `$SYNOLOGY_PASS` — DSM admin password

## Subcommands

### `list` — Show installed packages

Query `SYNO.Core.Package` to list all installed packages with their versions and status (running/stopped).

```bash
curl -s -k "https://${SYNOLOGY_HOST}:5001/webapi/entry.cgi?api=SYNO.Core.Package&version=1&method=list&_sid=${SID}"
```

### `updates` — Check for available updates

Query `SYNO.Core.Package` for packages with available updates.

```bash
curl -s -k "https://${SYNOLOGY_HOST}:5001/webapi/entry.cgi?api=SYNO.Core.Package&version=1&method=list&additional=%5B%22update%22%5D&_sid=${SID}"
```

### `start <pkg>` / `stop <pkg>` — Start or stop a package

**IMPORTANT: Requires explicit user confirmation before executing.**

```bash
curl -s -k "https://${SYNOLOGY_HOST}:5001/webapi/entry.cgi?api=SYNO.Core.Package.Control&version=1&method=start&id=<package_id>&_sid=${SID}"
```

## Authentication

Same auth flow as other syno-* commands — login, get SID, use it, logout.

## Output

Present results as a table: package name, version, status (running/stopped), update available (yes/no + new version).
