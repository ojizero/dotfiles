# MCP

> Define a custom MCP catalog for use with Docker MCP Toolkit.

The general aim of this catalog is to centralize, under Docker MCP's tooling,
all MCPs used that are not defined by Docker MCP registry including those
that don't particularly aim to be there but can be.

## Usage

- Make sure Docker Desktop is installed and up to date.
- `docker mcp catalog import <path to dotfiles>/mcp/catalog/ojizero.yaml`.
- Add needed secrets, e.g. `docker mcp secret set "linear.personal_api_key=<linear api key>"`.
- Enable MCP servers, e.g. `docker mcp server enable linear`.
- Confirm tools from new servers are pulled correctly when running `docker mcp gateway run`.
