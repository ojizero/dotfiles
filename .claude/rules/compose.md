---
paths:
  - "synology/docker/**/*.yml"
  - "synology/docker/**/compose.yml"
---

Docker Compose conventions for Synology stacks:

- Use `compose.yml` filename (not `docker-compose.yml`)
- Start with `---` YAML document separator
- Images pinned to exact versions, never `latest`
- `restart: unless-stopped` on all services
- Services behind Traefik must join the `servicenet` external network
- Services behind Traefik use `expose` (not `ports`) for the HTTP port, unless direct host access is also needed
- Internal-only networks use `internal: true` and descriptive names with `-sphere` or `-net` suffix
- Database networks must be internal
- Use YAML anchors (`x-*` prefix) for shared configuration across services in the same stack
- Environment variables with secrets must have a corresponding `.env.sample` entry
