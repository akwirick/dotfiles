#!/bin/bash

input=$(cat)

# Extract fields
session_id=$(echo "$input" | jq -r '.session_id // empty')
model_name=$(echo "$input" | jq -r '.model.display_name // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // empty')

# Read effort level from settings
effort_level=$(jq -r '.effortLevel // empty' ~/.claude/settings.json 2>/dev/null)

# Look up human-readable session name
cache_dir="$HOME/.claude/.statusline-cache"
cache_file="$cache_dir/$session_id"
session_name=""

if [ -n "$session_id" ]; then
  # Check cache first
  if [ -f "$cache_file" ]; then
    session_name=$(cat "$cache_file")
  else
    # Try sessions-index.json
    lookup_dir="${project_dir:-$current_dir}"
    if [ -n "$lookup_dir" ]; then
      encoded_dir=$(echo "$lookup_dir" | sed 's|/|-|g')
      index_file="$HOME/.claude/projects/${encoded_dir}/sessions-index.json"
      if [ -f "$index_file" ]; then
        session_name=$(jq -r --arg sid "$session_id" '.entries[] | select(.sessionId == $sid) | .summary // empty' "$index_file" 2>/dev/null)
      fi
    fi

    # Fallback: search all session indexes
    if [ -z "$session_name" ]; then
      for idx in "$HOME"/.claude/projects/*/sessions-index.json; do
        [ -f "$idx" ] || continue
        session_name=$(jq -r --arg sid "$session_id" '.entries[] | select(.sessionId == $sid) | .summary // empty' "$idx" 2>/dev/null)
        [ -n "$session_name" ] && break
      done
    fi

    # Fallback: extract first real user prompt from transcript JSONL
    if [ -z "$session_name" ]; then
      transcript=$(echo "$input" | jq -r '.transcript_path // empty')
      if [ -n "$transcript" ] && [ -f "$transcript" ]; then
        session_name=$(head -30 "$transcript" \
          | jq -r 'select(.type == "user") | .message.content | if type == "string" then . else empty end' 2>/dev/null \
          | grep -v '^\s*$' \
          | grep -v '^\s*<' \
          | head -1 \
          | cut -c1-60)
      fi
    fi

    # Cache the result
    if [ -n "$session_name" ]; then
      mkdir -p "$cache_dir"
      echo "$session_name" > "$cache_file"
    fi
  fi
fi

# === Line 1: [Session] [Model + Effort] [Context Bar] ===
session_display=""
if [ -n "$session_name" ]; then
  session_display="$(printf '\033[33m')${session_name}$(printf '\033[0m') "
elif [ -n "$session_id" ]; then
  session_display="$(printf '\033[33m')${session_id:0:8}$(printf '\033[0m') "
fi

model_display="$(printf '\033[35m')${model_name}$(printf '\033[0m')"
if [ -n "$effort_level" ]; then
  effort_cap="$(echo "$effort_level" | cut -c1 | tr '[:lower:]' '[:upper:]')$(echo "$effort_level" | cut -c2-)"
  model_display="${model_display} $(printf '\033[90m')(${effort_cap})$(printf '\033[0m')"
fi

context_display=""
if [ -n "$used_pct" ]; then
  bar_width=10
  used_int="${used_pct%.*}"
  filled=$(( (used_int * bar_width) / 100 ))
  empty=$(( bar_width - filled ))

  if [ "$used_int" -gt 80 ]; then bar_color='\033[31m'
  elif [ "$used_int" -gt 50 ]; then bar_color='\033[33m'
  else bar_color='\033[32m'; fi

  bar="["
  i=0; while [ $i -lt $filled ]; do bar="${bar}█"; i=$((i+1)); done
  i=0; while [ $i -lt $empty ]; do bar="${bar}░"; i=$((i+1)); done
  bar="${bar}]"

  context_display=" $(printf "${bar_color}")${bar}$(printf '\033[0m') ${used_int}%"
fi

echo "${session_display}${model_display}${context_display}"

# === Line 2: [Dir] [Git Info] ===
dir_display="${current_dir/#$HOME/~}"

vcs_info=""
if git -C "$current_dir" -c core.useBuiltinFSMonitor=false rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$current_dir" -c core.useBuiltinFSMonitor=false symbolic-ref --short HEAD 2>/dev/null || git -C "$current_dir" -c core.useBuiltinFSMonitor=false rev-parse --short HEAD 2>/dev/null)
  status_symbols=""

  if ! git -C "$current_dir" -c core.useBuiltinFSMonitor=false diff --quiet 2>/dev/null; then status_symbols="±"; fi
  if ! git -C "$current_dir" -c core.useBuiltinFSMonitor=false diff --cached --quiet 2>/dev/null; then
    [ -n "$status_symbols" ] && status_symbols="${status_symbols}✚" || status_symbols="✚"
  fi

  if [ -n "$status_symbols" ]; then
    vcs_info=" $(printf '\033[33m')⎇ ${branch} ${status_symbols}$(printf '\033[0m')"
  else
    vcs_info=" $(printf '\033[32m')⎇ ${branch}$(printf '\033[0m')"
  fi
fi

echo "$(printf '\033[36m')${dir_display}$(printf '\033[0m')${vcs_info}"
