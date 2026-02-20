---
name: syno-tasks
description: List and manage Synology scheduled tasks — show scripts, last run status, next execution time.
disable-model-invocation: true
argument-hint: "[list|run <task-id>]"
---

# Synology Scheduled Tasks

List and manage scheduled tasks on the Synology NAS via the DSM Web API.

Command: $ARGUMENTS

## Prerequisites

Environment variables must be set:
- `$SYNOLOGY_HOST` — NAS hostname or IP (e.g. `atlas.tn.ojizero.dev`)
- `$SYNOLOGY_USER` — DSM admin username
- `$SYNOLOGY_PASS` — DSM admin password

## Subcommands

### `list` — Show scheduled tasks

Query `SYNO.Core.TaskScheduler` to list all scheduled tasks.

```bash
curl -s -k "https://${SYNOLOGY_HOST}:5001/webapi/entry.cgi?api=SYNO.Core.TaskScheduler&version=2&method=list&_sid=${SID}"
```

### `run <task-id>` — Trigger a task manually

**IMPORTANT: Requires explicit user confirmation before executing.**

```bash
curl -s -k "https://${SYNOLOGY_HOST}:5001/webapi/entry.cgi?api=SYNO.Core.TaskScheduler&version=2&method=run&id=<task_id>&_sid=${SID}"
```

## Authentication

Same auth flow as other syno-* commands — login, get SID, use it, logout.

## Output

Present results as a table: task name, type (script/service), schedule (cron expression or description), enabled (yes/no), last run time, last run result (success/failure).
