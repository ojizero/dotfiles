---
name: traefik-dynamic
description: How Traefik's file provider works for non-containerized backends. Use when editing synology/docker/gateway/config/dynamic.yml.
user-invocable: false
---

# Traefik Dynamic File Provider

The file provider handles routing for services that are NOT Docker containers — they run directly on the Synology host and cannot use Docker labels.

## Configuration

- File: `/etc/traefik/dynamic.yml` (mounted from `synology/docker/gateway/config/dynamic.yml`)
- Hot-reload enabled (`watch: true`) — changes take effect without restarting Traefik

## Current Routes

**DSM (Synology web interface):**
```yaml
routers:
  dsm:
    entryPoints: [web-secure]
    rule: Host("atlas.ojizero.dev") || Host("atlas.tn.ojizero.dev") || Host("atlas.ln.ojizero.dev")
    service: dsm
services:
  dsm:
    loadbalancer:
      servers:
        - url: http://host.docker.internal:5000
```

**AdGuard Home DNS:**
```yaml
routers:
  dns:
    entryPoints: [web-secure]
    rule: Host("d.ojizero.dev") || Host("d.tn.ojizero.dev") || Host("d.ln.ojizero.dev")
    service: dns
services:
  dns:
    loadbalancer:
      servers:
        - url: http://host.docker.internal:3000
```

## Pattern for Adding New File-Based Routes

```yaml
http:
  routers:
    {name}:
      entryPoints: [web-secure]
      rule: Host("{sub}.tn.ojizero.dev") || Host("{sub}.ln.ojizero.dev")
      service: {name}
  services:
    {name}:
      loadbalancer:
        servers:
          - url: http://host.docker.internal:{port}
```

## Key Details

- `host.docker.internal` resolves to the NAS host from within the Traefik container
- File-based routes and Docker-based routes are both active simultaneously
- Use this provider for: DSM, AdGuard Home, or any other service running directly on the host
- Use Docker labels instead for containerized services
