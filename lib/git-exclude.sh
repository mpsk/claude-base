#!/usr/bin/env bash
# Shared function only; sourcing this file has no side effects.
add_git_exclude() {
  local target="$1" relative="$2" dry_run="$3" exclude
  exclude=$(git -C "$target" rev-parse --git-path info/exclude 2>/dev/null) || return 0
  case "$exclude" in /*) ;; *) exclude="$target/$exclude" ;; esac
  if [ -f "$exclude" ] && grep -qxF "$relative" "$exclude"; then return 0; fi
  if "$dry_run"; then echo "would exclude: $target -> $relative"; return; fi
  mkdir -p "$(dirname "$exclude")"
  printf '%s\n' "$relative" >> "$exclude"
}
