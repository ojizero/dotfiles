---
name: add-tool
description: Add a new development tool to the dotfiles stack across Brewfile, ASDF, .tool-versions, and shell config.
disable-model-invocation: true
argument-hint: "<tool-name> [version]"
---

# Add Tool

Add a new development tool to the dotfiles stack. Takes a tool name and optional version as arguments.

Tool name: $ARGUMENTS

## Workflow

1. **Determine installation method:**
   - Is it a Homebrew formula or cask? Search `brew search $ARGUMENTS`
   - Is it an ASDF plugin? Check https://github.com/asdf-vm/asdf-plugins or search
   - Does it need both? (e.g. a runtime managed by ASDF but also needs a Homebrew tap)

2. **Brewfile** (if applicable):
   - Add to `Brewfile` in the correct section (taps, formulae, casks, or MAS)
   - Maintain alphabetical order within the section
   - Use double quotes: `brew "name"` or `cask "name"`
   - Reference: @Brewfile

3. **ASDF** (if applicable):
   - Add `asdf plugin add <name> <repo-url>` to `bootstrap/common/04-asdf.setup`
   - Add a version line to `.tool-versions`
   - Reference: @bootstrap/common/04-asdf.setup and @.tool-versions

4. **Shell configuration** (if needed):
   - Environment variables → `omz/auto/misc.zsh`
   - Aliases → `omz/auto/aliases.zsh`
   - Completions → `omz/auto/completions.zsh` or `omz/completions/`
   - Reference: @omz/auto/

5. **Verify** the changes are consistent and nothing is missing.
