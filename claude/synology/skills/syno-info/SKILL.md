---
name: syno-info
description: Query Synology NAS system info — uptime, DSM version, CPU/RAM usage, temperature.
disable-model-invocation: true
---

# Synology System Info

Query the Synology NAS for system information via the DSM Web API.

## Workflow

### 1. Authenticate

Use the shared auth flow from the plugin context.

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

### 4. Present Results

Format the response into a readable dashboard:
- DSM Version
- Uptime
- CPU usage (%)
- RAM usage (used / total)
- System temperature
- Model and serial number
