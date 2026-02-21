# Synology NAS Plugin

Skills for managing a Synology NAS via the DSM Web API.

## Authentication

All skills share the same auth flow. Environment variables must be set:
- `$SYNOLOGY_HOST` — NAS hostname or IP (e.g. `atlas.tn.ojizero.dev`)
- `$SYNOLOGY_USER` — DSM admin username
- `$SYNOLOGY_PASS` — DSM admin password

### Auth Flow

1. Login — get a session ID:
```bash
curl -s -k "https://${SYNOLOGY_HOST}:5001/webapi/auth.cgi?api=SYNO.API.Auth&version=6&method=login&account=${SYNOLOGY_USER}&passwd=${SYNOLOGY_PASS}&format=sid"
```
Extract `sid` from the JSON response.

2. Use `_sid=${SID}` as a query parameter on all subsequent API calls.

3. Logout when done:
```bash
curl -s -k "https://${SYNOLOGY_HOST}:5001/webapi/auth.cgi?api=SYNO.API.Auth&version=6&method=logout&_sid=${SID}"
```
