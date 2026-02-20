---
paths:
  - "synology/docker/**/.env*"
---

Environment file conventions:

- `.env` files are NEVER committed — they are git-ignored and contain secrets
- Every stack using `.env` must have a `.env.sample` with all variable names documented
- `.env.sample` entries should include:
  - Comments explaining each variable's purpose
  - Generation commands for secrets (e.g. `openssl rand -base64 36`)
  - Sensible defaults where applicable
- Common variables: `PUID`, `PGID`, `TZ`, `DATA_VAULT_PATH`
