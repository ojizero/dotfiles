---
name: syno-info
description: Query Synology NAS system info — uptime, DSM version, CPU/RAM usage, temperature.
disable-model-invocation: true
---

# Synology System Info

Query the Synology NAS for system information via the DSM Web API.

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

### 2. Query System Info

**DSM Info** (version, uptime):
```bash
curl -s -k "https://${SYNOLOGY_HOST}:5001/webapi/dsm/info.cgi?api=SYNO.DSM.Info&version=1&method=getinfo&_sid=${SID}"
```

**System Status** (CPU, RAM, temperature):
```bash
curl -s -k "https://${SYNOLOGY_HOST}:5001/webapi/entry.cgi?api=SYNO.Core.System.Utilization&version=1&method=get&_sid=${SID}"
```

### 3. Logout

```bash
curl -s -k "https://${SYNOLOGY_HOST}:5001/webapi/auth.cgi?api=SYNO.API.Auth&version=6&method=logout&_sid=${SID}"
```

### 4. Present Results

Format the response into a readable dashboard:
- DSM Version
- Uptime
- CPU usage (%)
- RAM usage (used / total)
- System temperature
- Model and serial number
