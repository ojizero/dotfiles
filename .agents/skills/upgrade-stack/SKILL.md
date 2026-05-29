---
name: upgrade-stack
description: Upgrade image tags in Synology Docker Compose stacks under synology/docker and report changelog and breaking-change impact. Use when intent is upgrading stack services, bumping compose image versions, or refreshing service tags for these homelab stacks.
---

# Upgrade Docker Compose Stack

Upgrade all service images in a Docker Compose stack to their latest compatible versions.

## Inputs

- Stack name argument, corresponding to `synology/docker/<stack>/`
- Compose file path: `synology/docker/<stack>/compose.yml`

If the stack name is missing, ask for it before proceeding.

## Workflow

### 1) Parse Current State

Read `synology/docker/<stack>/compose.yml` and extract each service image tag.
Keep the exact tag format used by each image (for example `YYYY.MM.DD-hash`, `branch-hash`, `semver`).

### 2) Research Latest Versions (in parallel)

For each service image, launch parallel research to:

1. Find the latest available tag that matches the current tag format:
   - `quay.io`: query the quay tags API (`/api/v1/repository/<namespace>/<repo>/tag/`)
   - Docker Hub official images (for example `postgres`): query `/v2/repositories/library/<image>/tags/`
   - Docker Hub non-official images: query `/v2/repositories/<namespace>/<image>/tags/`
   - `ghcr.io`: use GitHub Container Registry API or project GitHub releases/tags
   - Cross-check with upstream GitHub releases/tags so tag meaning is understood
2. Review changes between current and latest:
   - Release notes, commits, and pull requests
   - Breaking changes, required migrations, schema changes
   - New, renamed, or removed config and environment variables
3. Return: exact target tag, key change summary, and required manual steps.

### 3) Verify Candidate Tags

For each upgrade candidate, verify the tag exists:

`docker manifest inspect <image>:<tag>`

If verification fails, re-check via the registry API and pick the correct existing tag.

### 4) Apply Upgrades

Update image tags in `synology/docker/<stack>/compose.yml`.

Also apply simple, unambiguous config updates required by the upgrade when obvious:

- Renamed environment variables
- Changed default ports
- Newly required config keys with clear defaults
- Deprecated keys that should be removed or replaced

Do not implement complex or ambiguous breaking-change migrations. Report them instead.

### 5) Report

Present a summary table:

| Service | Old Tag | New Tag | Changes |
|---------|---------|---------|---------|

For each upgraded service include:

- 1-3 changelog highlights
- Any breaking changes marked with **BREAKING**
- What was auto-fixed vs what remains manual
- Any extra steps beyond `docker compose down && docker compose up -d`

For services already current, report "already latest" and skip edits.

### 6) Commit

Stage all modified files (for example `compose.yml`, `.env.sample`, config files) and commit using this format:

```text
Upgrade <service names> in <stack> stack

- <service>: <old tag> -> <new tag> (brief reason)
...
```

Do not push.

## Rules

- Never use `latest` tags; always pin exact versions
- Preserve each service's existing tag style
- For databases, stay within the current major line (for example `postgres 18.x` stays in `18.x`)
- Never create or modify `.env` files
- If new variables are required, update `.env.sample`
- **Archive stack — verify Meilisearch compatibility first:** when upgrading `synology/docker/archive`, check the current Karakeep documentation before changing `getmeili/meilisearch`. Keep it pinned to the Karakeep-recommended version for your deployed Karakeep release, and if a bump requires data migration (for example wiping `data.ms` and full bookmark reindex), report that clearly before applying it. See [Karakeep Meilisearch upgrade guide](https://docs.karakeep.app/administration/troubleshooting#upgrading-meilisearch---migrating-the-meilisearch-db-version).
