#!/usr/bin/env bash
# Sync Claude definitions for one workspace or project destination.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(dirname "$SCRIPT_DIR")"
TARGET_DIR="$(dirname "$SOURCE_DIR")"
DRY_RUN=false
GIT_EXCLUDE=false
help() {
  echo 'Usage: lib/sync-claude.sh [--source DIR] [--target DIR] [--dry-run] [--git-exclude]'
}
while [ "$#" -gt 0 ]; do
  case "$1" in
    --source|--target)
      [ "$#" -ge 2 ] || { help >&2; exit 1; }
      if [ "$1" = --source ]; then SOURCE_DIR="$2"; else TARGET_DIR="$2"; fi
      shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --git-exclude) GIT_EXCLUDE=true; shift ;;
    -h|--help) help; exit 0 ;;
    *) help >&2; exit 1 ;;
  esac
done
SOURCE_DIR="$(cd "$SOURCE_DIR" && pwd)"
case "$TARGET_DIR" in /*) ;; *) TARGET_DIR="$PWD/$TARGET_DIR" ;; esac
if [ -d "$TARGET_DIR" ]; then TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"; fi
source "$SCRIPT_DIR/git-exclude.sh"
# Preserve the existing relative layout for workspace and child projects.
if [ "$TARGET_DIR" = "$(dirname "$SOURCE_DIR")" ]; then
  LINK_PREFIX="../../$(basename "$SOURCE_DIR")"
elif [ "$(dirname "$TARGET_DIR")" = "$(dirname "$SOURCE_DIR")" ]; then
  LINK_PREFIX="../../../$(basename "$SOURCE_DIR")"
else
  LINK_PREFIX="$SOURCE_DIR"
fi
for kind in skills agents commands; do
  for item in "$SOURCE_DIR/$kind"/*; do
    [ -e "$item" ] || continue
    name="$(basename "$item")"
    dst="$TARGET_DIR/.claude/$kind/$name"
    if [ ! -e "$dst" ] && [ ! -L "$dst" ]; then
      if $DRY_RUN; then echo "would link: $dst -> $item"; else
        mkdir -p "$(dirname "$dst")"
        ln -s "$LINK_PREFIX/$kind/$name" "$dst"
        echo "linked: $dst -> $item"
      fi
    fi
    if $GIT_EXCLUDE && [ "$TARGET_DIR" != "$(dirname "$SOURCE_DIR")" ]; then
      add_git_exclude "$TARGET_DIR" ".claude/$kind/$name" "$DRY_RUN"
    fi
  done
  for dst in "$TARGET_DIR/.claude/$kind"/*; do
    [ -L "$dst" ] || continue
    name="$(basename "$dst")"
    [ "$(readlink "$dst")" = "$LINK_PREFIX/$kind/$name" ] || continue
    [ ! -e "$SOURCE_DIR/$kind/$name" ] || continue
    if $DRY_RUN; then echo "would remove stale link: $dst"; else
      rm -f "$dst"
      echo "removed stale link: $dst"
    fi
  done
done
# Point Plan Mode at the repo's own plans folder via the personal (uncommitted)
# settings file. Child repos only; an existing plansDirectory is preserved.
if [ "$TARGET_DIR" != "$(dirname "$SOURCE_DIR")" ]; then
  settings="$TARGET_DIR/.claude/settings.local.json"
  plans_dir="$TARGET_DIR/.claude/plans"
  if ! command -v jq >/dev/null 2>&1; then
    echo "skipped plansDirectory (jq not found): $settings"
  elif [ -f "$settings" ] && jq -e 'has("plansDirectory")' "$settings" >/dev/null; then
    echo "preserved plansDirectory: $settings"
  elif $DRY_RUN; then
    echo "would set plansDirectory: $settings -> $plans_dir"
  else
    mkdir -p "$(dirname "$settings")"
    [ -f "$settings" ] || printf '{}\n' > "$settings"
    jq --arg dir "$plans_dir" '.plansDirectory = $dir' "$settings" > "$settings.tmp"
    mv "$settings.tmp" "$settings"
    echo "set plansDirectory: $settings -> $plans_dir"
  fi
  if $GIT_EXCLUDE; then add_git_exclude "$TARGET_DIR" ".claude/settings.local.json" "$DRY_RUN"; fi
fi
