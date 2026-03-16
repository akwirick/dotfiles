#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# Files that get post-processed by org sync — copy instead of symlink
COPY_FILES=(
  "claude/.claude/CLAUDE.md"
  "claude/.claude/settings.json"
)

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

# Replace symlinks with copies for files that get post-processed by org sync.
# Stow creates the symlinks above; we swap them for copies so sync.sh can
# modify them without writing back into the dotfiles repo.
for cf in "${COPY_FILES[@]}"; do
  target="$HOME/${cf#*/}"  # strip package prefix (e.g. claude/) to get ~/.claude/...
  source="$DOTFILES_DIR/$cf"
  if [[ -f "$source" ]]; then
    if [[ -L "$target" ]]; then
      rm "$target"
    fi
    mkdir -p "$(dirname "$target")"
    cp "$source" "$target"
    echo "Copied (not symlinked): $target"
  fi
done

# Sync org commons (opt-in, requires gh CLI)
if command -v gh &>/dev/null; then
  echo "Syncing org commons..."
  if [ -f "$HOME/.claude/org/claude/sync.sh" ]; then
    bash "$HOME/.claude/org/claude/sync.sh"
  else
    bash <(gh api repos/cortexapps/eng-commons/contents/claude/sync.sh -q '.content' | base64 -d) || echo "  Skipped org commons sync (run manually later)"
  fi
else
  echo "Skipping org commons sync (gh CLI not found)"
fi

echo "Done."
