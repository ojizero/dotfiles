---
name: syno-storage
description: Query Synology NAS storage status — volume usage, disk health, RAID status.
disable-model-invocation: true
---

# Synology Storage Status

Query the Synology NAS for storage information via the DSM Web API.

## Prerequisites

Environment variables must be set:
- `$SYNOLOGY_HOST` — NAS hostname or IP (e.g. `atlas.tn.ojizero.dev`)
- `$SYNOLOGY_USER` — DSM admin username
- `$SYNOLOGY_PASS` — DSM admin password

## Workflow

### 1. Authenticate

```bash
curl -s -k "https://${SYNOLOGY_HOST}:5001/webapi/auth.cgi?api=SYNO.API.Auth&version=6&method=login&account=${SYNOLOGY_USER}&passwd=${SYNOLOGY_PASS}&format=sid"
```

Extract `sid` from the response JSON.

### 2. Query Storage

**Volume Info** (capacity, usage):
```bash
curl -s -k "https://${SYNOLOGY_HOST}:5001/webapi/entry.cgi?api=SYNO.Core.Storage.Volume&version=1&method=list&_sid=${SID}"
```

**Disk Info** (health, temperature, model):
```bash
curl -s -k "https://${SYNOLOGY_HOST}:5001/webapi/entry.cgi?api=SYNO.Core.Storage.Disk&version=1&method=list&_sid=${SID}"
```

**RAID Status**:
```bash
curl -s -k "https://${SYNOLOGY_HOST}:5001/webapi/entry.cgi?api=SYNO.Core.Storage.Pool&version=1&method=list&_sid=${SID}"
```

### 3. Logout

```bash
curl -s -k "https://${SYNOLOGY_HOST}:5001/webapi/auth.cgi?api=SYNO.API.Auth&version=6&method=logout&_sid=${SID}"
```

### 4. Present Results

Format into a storage dashboard:
- Per-volume: name, total capacity, used space, usage percentage, filesystem status
- Per-disk: model, serial, temperature, health status (SMART), allocation
- RAID/Pool: type (SHR, RAID1, etc.), status (healthy/degraded), member disks

Flag alerts for:
- Volume usage > 85%
- Disk temperature > 50°C
- Any non-healthy SMART status
- Degraded RAID arrays
