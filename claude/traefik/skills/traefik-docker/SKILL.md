---
name: traefik-docker
description: How Traefik's Docker provider works in this repo. Use when editing or creating Docker Compose files under synology/docker/ that need Traefik routing.
user-invocable: false
---

# Traefik Docker Provider

Traefik discovers services automatically via Docker labels. Here is how it works in this repo.

## Provider Configuration

- Endpoint: `tcp://docker-proxy:2375` (via linuxserver/socket-proxy, NOT direct socket mount)
- `exposedByDefault: false` — every service must explicitly opt in
- Default network: `servicenet` — all routed services must join this external network

## Standard Label Template

Every service exposed through Traefik needs these labels:

```yaml
labels:
  - traefik.enable=true
  - traefik.http.routers.{name}.entrypoints=web-secure
  - traefik.http.routers.{name}.rule=Host(`{sub}.tn.ojizero.dev`) || Host(`{sub}.ln.ojizero.dev`)
  - traefik.http.routers.{name}.service={name}
  - traefik.http.services.{name}.loadbalancer.server.port={port}
```

Where:
- `{name}` = router/service identifier (usually the service name)
- `{sub}` = subdomain mnemonic (e.g. `m`, `srr`, `keep`)
- `{port}` = the container's internal HTTP port

## Basic Auth Middleware (optional)

Used by Traefik dashboard and Cleanuparr:

```yaml
labels:
  - traefik.http.middlewares.{name}-basic-auth.basicauth.users=${USER}:${PASS_HASH}
  - traefik.http.routers.{name}.middlewares={name}-basic-auth
```

The `PASS_HASH` is an htpasswd-style hash, sourced from `.env`.

## Network Requirements

The service must join the `servicenet` external network:

```yaml
networks:
  servicenet:
    external: true
```

Services may also have internal networks for inter-service communication (databases, search engines). These use `internal: true` and descriptive names with `-sphere` or `-net` suffix.

## TLS

All TLS is automatic via Let's Encrypt with Cloudflare DNS challenge. Wildcard certificates cover `*.tn.ojizero.dev` and `*.ln.ojizero.dev`. No per-service TLS configuration is needed.

## Domain Pattern

Most services are exposed on both tailnet and LAN:
```
Host(`{sub}.tn.ojizero.dev`) || Host(`{sub}.ln.ojizero.dev`)
```

Some services are Tailscale-only (e.g. Invidious: `yt.tn.ojizero.dev` only).

## YAML Anchors

Stacks with multiple services use YAML anchors for shared config:

```yaml
x-data-vault: &data-vault
  type: bind
  source: ${DATA_VAULT_PATH:-/media}
  target: /data

x-environment: &environment
  PUID: ${PUID:-1000}
  PGID: ${PGID:-1000}
  TZ: Asia/Jerusalem
```
