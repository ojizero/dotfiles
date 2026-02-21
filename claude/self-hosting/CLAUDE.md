# Self-Hosting Plugin

Tools for managing self-hosted Docker Compose service stacks.

## Conventions

- Stacks are directories containing a `compose.yml` file
- Images are pinned to exact versions, never `latest`
- `.env` files are git-ignored; `.env.sample` is required alongside any `.env` usage
- All services use `restart: unless-stopped`
