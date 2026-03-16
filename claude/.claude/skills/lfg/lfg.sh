#!/usr/bin/env bash
set -euo pipefail

branch="$1"
prefix=$(git config user.name 2>/dev/null | tr '[:upper:]' '[:lower:]' | sed 's/\([a-z]\)[^ ]*/\1/g' | tr -d ' ')
if [ -n "$prefix" ]; then prefix="$prefix/"; fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Error: You have uncommitted or unstaged changes. Commit or stash them first." >&2
  exit 1
fi
base=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@') || {
  git remote set-head origin --auto
  base=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
}
git fetch origin "$base"
git checkout -b "$prefix$branch" "origin/$base"
