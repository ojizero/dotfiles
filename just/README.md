# Global just

Provide global justfile at the user level, useful for adding recipes and other
script or helpers to use system wide.

Right now this only provides a recipe to update all packages installed via
Homebrew in one go, `j -g up` (or `j -g update` or `j -g upgrade`).
