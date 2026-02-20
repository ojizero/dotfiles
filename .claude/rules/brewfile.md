---
paths:
  - "Brewfile"
  - ".local/Brewfile"
---

Brewfile conventions:

- Organized into sections: taps, formulae, casks, MAS apps
- Each section has a comment header
- Entries within each section are alphabetically sorted
- Use double quotes: `brew "name"`, `cask "name"`
- MAS entries: `mas "Name", id: 12345`
- Machine-specific packages go in `.local/Brewfile`, never in the main `Brewfile`
- Never modify `.local/Brewfile` from git — it is machine-specific and git-ignored
