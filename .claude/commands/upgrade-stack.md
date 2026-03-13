# Upgrade Docker Compose Stack

Upgrade all service images in a Docker Compose stack to their latest versions. The stack name is provided as `$ARGUMENTS` and corresponds to a directory under `synology/docker/`.

## Input

- `$ARGUMENTS` — the stack directory name (e.g. `youtube`, `media`, `archive`)
- The compose file is always at `synology/docker/$ARGUMENTS/compose.yml`

## Workflow

### Step 1: Parse Current State

Read `synology/docker/$ARGUMENTS/compose.yml` and extract every service image tag. Note the exact tag format used for each image (e.g. `2026.02.24-21d0d10`, `master-1786e15`, `18.3`).

### Step 2: Research Latest Versions (in parallel)

For **each** service image, launch a background research agent that:

1. **Finds the latest available tag** matching the current tag format:
   - For container registries on `quay.io`, check the quay.io API (`/api/v1/repository/<namespace>/<repo>/tag/`)
   - For Docker Hub official images (e.g. `postgres`), check the Docker Hub API (`/v2/repositories/library/<image>/tags/`)
   - For Docker Hub non-official images, check `/v2/repositories/<namespace>/<image>/tags/`
   - For `ghcr.io`, use the GitHub Container Registry API or the GitHub releases page
   - Cross-reference with the project's **GitHub releases/tags page** to understand what the tag represents
2. **Reviews the changelog** between the current and latest version:
   - Check GitHub commits, release notes, and pull requests between the two versions
   - Identify **breaking changes**, new configuration options, new environment variables, required migrations, and database schema changes
   - Note any deprecations or removed features
3. Returns: the exact new tag string, a summary of changes, and any required manual steps

### Step 3: Verify Tags

For each image that has an upgrade available, verify the tag exists using `docker manifest inspect <image>:<tag>`. If verification fails, fall back to the quay.io/Docker Hub API to double-check and find the correct tag.

### Step 4: Apply Upgrades

Edit `synology/docker/$ARGUMENTS/compose.yml` to update each image tag.

Also apply any **simple, obvious config changes** required by the upgrade — for example:
- Renamed environment variables
- Changed default ports
- New required config keys with clear default values
- Deprecated config keys that should be removed or replaced

Do **not** attempt to address complex or ambiguous breaking changes — report those as-is for the user to handle.

### Step 5: Report

Present a summary table:

| Service | Old Tag | New Tag | Changes |
|---------|---------|---------|---------|

For **every** upgraded service (including ones where you already applied fixes), include:
- Key changelog highlights (1-3 bullet points)
- Any breaking changes or deprecations — flagged with **BREAKING** even if you already fixed them in the compose/config files. If you did fix it, note what you changed. If you could not fix it, describe the required manual steps.
- Any extra steps needed during upgrade beyond `docker compose down && docker compose up -d` (e.g. database migrations, data directory changes, manual config edits on the host)

If a service is already on the latest version, note it as "already latest" and skip it.

### Step 6: Commit

Stage all modified files (compose.yml, .env.sample, config files) and commit with a message following the existing convention:

```
Upgrade <service names> in <stack> stack

- <service>: <old tag> -> <new tag> (brief reason)
...
```

Do **not** push.

## Important Rules

- Never use `latest` tags — always pin to exact versions
- Match the tag format already used in the compose file (e.g. if a service uses `YYYY.MM.DD-hash`, find the latest tag in that format; if it uses `semver`, find the latest semver tag)
- Only upgrade within the same major version line for databases (e.g. postgres 18.x stays on 18.x)
- Report `.env` or `.env.sample` changes needed but never create or modify `.env` files
- If `.env.sample` needs new variables, update it and include that in the commit
