#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# Detect platform and install stow if needed
if ! command -v stow &>/dev/null; then
  echo "Installing GNU Stow..."
  if [[ "$OSTYPE" == darwin* ]]; then
    brew install stow
  elif command -v apt &>/dev/null; then
    sudo apt update && sudo apt install -y stow
  else
    echo "Error: unsupported platform. Install GNU Stow manually." >&2
    exit 1
  fi
fi

# Find all packages (top-level dirs that aren't dotfiles or hidden)
packages=()
for dir in "$DOTFILES_DIR"/*/; do
  pkg="$(basename "$dir")"
  [[ "$pkg" == .* ]] && continue
  packages+=("$pkg")
done

if [[ ${#packages[@]} -eq 0 ]]; then
  echo "No packages found."
  exit 0
fi

echo "Packages: ${packages[*]}"

# Deploy each package
for pkg in "${packages[@]}"; do
  echo "Stowing $pkg..."

  # Back up any real (non-symlink) files that would conflict
  while IFS= read -r -d '' file; do
    relative="${file#"$DOTFILES_DIR/$pkg/"}"
    target="$HOME/$relative"
    if [[ -e "$target" && ! -L "$target" ]]; then
      backup="$target.backup.$(date +%Y%m%d%H%M%S)"
      echo "  Backing up $target → $backup"
      mv "$target" "$backup"
    fi
  done < <(find "$DOTFILES_DIR/$pkg" -type f -print0)

  stow -d "$DOTFILES_DIR" -t "$HOME" "$pkg"
done

echo "Done."
