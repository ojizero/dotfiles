## Communication

- Back claims with evidence: file:line, command output, or a doc link. When you have none, mark the claim as an assumption or go verify it.
- Disagree directly when the evidence supports it.
- Use ASD-STE100 for English docs, code comments, and technical replies such as planning or scoping.
- Use a diagram or graph when it makes an idea faster to understand.

## Engineering

- Solve complex problems with simple, readable systems that "feel obvious". Simple and readable means easy to read and easy to change, not the fewest files or functions. Hold all code to this.
- Measure twice, cut once: find the real constraint and the right shape before you write code. Do not copy the shape of a brief or schema into the code structure.
- YAGNI: do not build features or options that no current need asks for. YAGNI never permits code that is less simple or readable.
- Give each job its own home. When the code has several things of one kind, such as commands, add the next one as a new unit, not as a new branch in shared code.
- Add machinery only for a real need. Machinery is code that connects or configures other code but does no work itself: layers, interfaces, registries, plugin systems, generic wrappers. A real need is two or more uses that exist now, or a request that asks for it. A module for each job is not machinery.
- Fix the root cause. In the code you change, remove complexity that does not earn its place. Tell me about a larger mess before you fix it.

## Git

- Commit messages follow the repository's existing style. With no consistent style, follow Conventional Commits.
  - Keep the subject line at 50 characters or fewer and wrap the body at 72, even where the history breaks these limits.
- Pull request titles, or equivalent, follow the same rules as commit subjects.
- Comments on pull requests, or equivalent, follow Conventional Comments.

## Environment

- Projects live in workspaces under `~/workspace`, on all my machines.
  - `~/workspace/self` holds my personal projects.
  - `~/workspace/<org>` holds an org's work, and can nest per client or sub-org as `~/workspace/<org>/<client>`.
  - Any workspace can have a `playground` folder for code cloned only to explore, and for experimental POCs.
  - Create or clone new projects in a workspace. If the workspace is unclear, ask.
- `~/workspace/self/dotfiles` defines the environment. Its configs are linked or copied into place: edit them in dotfiles, not at the target. Changes for this machine only go in its untracked local files.
- Ask me before you add anything at global scope: the global Mise config, Homebrew, or system packages. One-off `mise exec` runs of trusted tools (well-known, from the official source) need no approval.
- Mise is the one source of truth for development tools, runtimes included, and for CLIs that Homebrew does not ship (for example, npm packages or GitHub releases such as Pi).
  - Use `mise use` for tools a project keeps, `mise exec <tool> -- <cmd>` for one-off runs, and the `npm:` or `pipx:` backends for npm and Python tools. These replace `npx`, `uvx`, `npm i -g`, and `uv tool install`.
  - In repos I don't own, write to `mise.local.toml`.
  - Run ad-hoc Python scripts with `uv run`.
  - Project dependencies go through the project's own package manager.
- Applications, CLIs included, come from the platform's package manager.
  - On macOS, use Homebrew (Casks for desktop apps). If only the App Store has an app, tell me and I install it.
  - On Linux, use the distro package manager first, then Homebrew. Use AppImage, Flatpak, or Snap only when it is the sole official option.
- I call my machines by name. Reach each one by the name in brackets: its Tailnet name, SSH host, and hostname, unless noted.
  - Polaris (`polaris`, no SSH): the main MacBook Pro.
  - Obsidian (`fts-macbook`, hostname `Amir-Alkam`): a MacBook Pro.
  - Sagittarius A* (`sagittarius-a`): a MacBook Pro running Ubuntu.
  - Atlas (`atlas`, no agents or dotfiles): a Synology DSM server.
