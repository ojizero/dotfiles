---
name: upgrade-stacks
description: Upgrade Docker Compose stacks — check for image updates, analyze changelogs, migrate configs, and generate deployment commands. Uses parallel Claude sessions per stack.
disable-model-invocation: true
argument-hint: "<stack-name|all>"
---

# Upgrade Stacks

Orchestrate the full upgrade process for Docker Compose stacks under `synology/docker/`. Uses Claude teams (parallel sessions) to process each stack concurrently.

Target: $ARGUMENTS

## Inventory

Scan `synology/docker/*/compose.yml` to identify stacks and their images:
!`grep -rh 'image:' synology/docker/*/compose.yml | sed 's/.*image: *//' | sort -u`

Available stacks:
!`ls -d synology/docker/*/compose.yml 2>/dev/null | sed 's|synology/docker/||;s|/compose.yml||'`

## Workflow

### Phase 1: Inventory

If `$ARGUMENTS` is `all`, enumerate every stack. Otherwise, target only the named stack(s).

For each stack, extract all `image:tag` references from its `compose.yml`.

### Phase 2: Parallel Upgrade Sessions

Spawn a **separate Claude session per stack** using teams. Each session handles the full lifecycle:

#### a. Version Discovery
- Extract all `image:tag` from the stack's `compose.yml`
- Query the appropriate container registry for latest stable releases:
  - Docker Hub: `https://hub.docker.com/v2/repositories/{namespace}/{name}/tags?page_size=100&ordering=last_updated`
  - GitHub Container Registry (ghcr.io): `https://ghcr.io/v2/{owner}/{name}/tags/list`
  - Quay.io: `https://quay.io/api/v1/repository/{namespace}/{name}/tag/`
- Filter out pre-release tags: `rc`, `alpha`, `beta`, `dev`, `nightly`
- Understand linuxserver.io tag conventions (e.g. `10.11.6ubu2404-ls20`)

#### b. Changelog Analysis
For each image with an available update:
- Find the project's GitHub repository (from Docker Hub description, image labels, or web search)
- Fetch release notes / changelogs between the current and latest version
- Identify: breaking changes, deprecations, new required env vars, changed ports, removed features, migration steps
- Classify: patch (safe), minor (review config), major (likely breaking)

#### c. Config Migration
Based on changelog findings, apply necessary changes:
- **New/renamed env vars** → update `.env.sample`, flag `.env` for manual update
- **Changed ports** → update Traefik labels and `expose`/`ports`
- **Changed volume paths** → update `volumes:` entries
- **New dependencies** → update `depends_on`, add services
- **Deprecated options** → remove or replace in compose file
- **Traefik label changes** → update labels per the traefik-docker skill conventions

After changes, validate: `docker compose -f synology/docker/{stack}/compose.yml config`

#### d. Per-Stack Report
Produce for each stack:
- Image: current version → available version
- Change type: patch / minor / major
- Breaking changes and what was done to address them
- Config diff summary (what files were changed and how)
- Manual steps still required (e.g. database migrations, `.env` secret updates)
- Recommendation: ready to deploy / needs manual review

### Phase 3: Consolidation

Collect all per-stack reports into a unified summary table:

| Stack | Images Updated | Change Type | Breaking | Status |
|-------|---------------|-------------|----------|--------|
| ... | ... | ... | ... | ... |

### Phase 4: User Review

Present the consolidated report. User confirms per stack which upgrades to:
- **Keep** — commit the changes
- **Revert** — undo the changes for this stack
- **Defer** — keep changes staged but don't deploy yet

### Phase 5: Deployment Commands

For each approved stack, generate:
```bash
cd /path/to/synology/docker/{stack}
docker compose pull
docker compose up -d
```

If manual migration steps are needed, list them before the deployment commands.
