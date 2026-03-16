#!/usr/bin/env bash
# Gathers Claude session memory files and git logs for a date range.
# Reads repo paths and git authors from config.json.
# Usage: bash session-history.sh <start-date> <end-date-plus-1>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$SCRIPT_DIR/config.json"

START_DATE="${1:?Usage: session-history.sh <start-date> <end-date-plus-1>}"
END_DATE_PLUS_1="${2:?Usage: session-history.sh <start-date> <end-date-plus-1>}"

echo "=== MEMORY FILES ==="
for index in ~/.claude/projects/*/memory/MEMORY.md; do
  [ -f "$index" ] || continue
  project=$(basename "$(dirname "$(dirname "$index")")")
  echo "--- $project/MEMORY.md ---"
  cat "$index"
  echo ""
  dir=$(dirname "$index")
  for f in "$dir"/*.md; do
    [ "$f" = "$index" ] && continue
    [ -f "$f" ] || continue
    echo "--- $project/$(basename "$f") ---"
    cat "$f"
    echo ""
  done
done

echo ""
echo "=== GIT LOGS ==="

# Read config
AGENT_DIRS=$(jq -r '.repos.agent_dirs[]' "$CONFIG" 2>/dev/null || echo "$HOME/src/agents/*/primary")
AUTHORS=$(jq -r '.repos.git_authors[]' "$CONFIG" 2>/dev/null)
if [ -z "$AUTHORS" ]; then
  AUTHORS="$(whoami)"
fi

# Expand globs from config
for pattern in $AGENT_DIRS; do
  expanded=$(eval echo "$pattern")
  for repo in $expanded; do
    [ -d "$repo/.git" ] || continue
    name=$(basename "$(dirname "$repo")")
    commits=""
    while IFS= read -r author; do
      result=$(git -C "$repo" log --oneline --after="$START_DATE" --before="$END_DATE_PLUS_1" --author="$author" 2>/dev/null || true)
      if [ -n "$result" ]; then
        commits="$commits
$result"
      fi
    done <<< "$AUTHORS"
    commits=$(echo "$commits" | sort -u | sed '/^$/d')
    if [ -n "$commits" ]; then
      echo "--- $name ---"
      echo "$commits"
      echo ""
    fi
  done
done
