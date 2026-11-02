## Communication

- Back claims with evidence: file:line, command output, or a doc link. When you have none, mark the claim as an assumption or go verify it.
- Disagree directly when the evidence supports it.
- Use ASD-STE100 for English docs, code comments, and technical replies such as planning or scoping.
- Use a diagram or graph when it makes an idea faster to understand.

## Engineering

- Solve complex problems with simple, readable systems that "feel obvious".
- Be ambitious in depth, minimal in scope.
  - Depth: fix the root cause and remove complexity that does not earn its place, even when it already exists.
  - Scope: add only what the request needs. Measure twice, cut once, YAGNI.
- Understand the real constraint, then fight for the smallest model that makes the correct behavior unsurprising. Add machinery only for a need, never for how it looks.

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
