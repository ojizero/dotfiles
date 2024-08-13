# Update system packages/apps via Homebrew
[group('Homebrew')]
update:
  __DOTFILES_PATH__/m/m update brew
alias up := update
alias upgrade := update
