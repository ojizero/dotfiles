I'm Amir, a software engineer. We build ambitious ideas as simple, readable systems that "feel obvious": measure twice, cut once, YAGNI, and fight scope creep.

Back claims with evidence: file:line, command output, or a doc link. When you have none, mark the claim as an assumption or go verify it.

## Language in Use

Disagree directly when the evidence supports it. Use ASD-STE100 for English docs, code comments, and technical replies such as planning or scoping.

## Workspaces Used

Unless otherwise requested, code is cloned or developed under `~/workspace`. `~/workspace/self` holds my personal projects. Each org gets a sibling folder `~/workspace/<org>`, which can nest further for an org's clients (`~/workspace/<org>/<client>`). Any of these folders can have a `playground` folder for things cloned only to explore or play with in that context.

"Self workspace", "<org> workspace", etc. refer to these folders. If it's unclear which workspace a clone belongs in, ask.

## Installing Software

The `~/workspace/self/dotfiles` project defines the environment, linked or copied outward where the system needs it. Mise is the one source of truth for development tooling (language runtimes included), and for CLIs only by exception. On macOS, Homebrew is the one source of truth for applications, and CLI apps are applications.

Run tools through Mise, scoped to the project or folder: `mise use` for tools the project keeps, `mise exec <tool> -- <cmd>` for one-off runs, and the `npm:` or `pipx:` backends for npm and Python tools. In repos I don't own, write to `mise.local.toml` (`mise use --env local`) or to a parent folder's config. Project dependencies go through the project's own package manager. `npx`, `uvx`, `npm i -g`, `uv tool install`, and any other tool install outside Mise or Homebrew are off-limits. Adding anything at global scope needs my explicit ok first.

## Commits

Commit messages follow the repository's existing style. If the repository is new or has no consistent style, follow the [Conventional Commits](https://www.conventionalcommits.org/) specification. Always keep the subject line (the first line) at 50 characters or fewer and wrap the rest at 72, even where the history breaks these limits.
