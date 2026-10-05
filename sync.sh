#!/usr/bin/env bash
# Symlinks base skills/agents from .claude-base into:
#   - every Titan git repo's .claude/{skills,agents,commands}
#   - the workspace root ~/MPI/titan/.claude/{skills,agents,commands} (not a git repo)
# Safe to rerun: only creates missing links, never touches an existing real file/dir (override wins).
#
# Usage:
#   ./sync.sh git-exclude=<true|false>
#     true  - create missing symlinks, then also add each base skill/agent
#             path to every repo's .git/info/exclude (workspace root skipped)
#     false - create missing symlinks only, skip git-exclude
set -euo pipefail

if [ $# -ne 1 ] || [[ "$1" != git-exclude=true && "$1" != git-exclude=false ]]; then
  echo "usage: $0 git-exclude=<true|false>" >&2
  exit 1
fi
GIT_EXCLUDE="${1#git-exclude=}"

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TITAN_ROOT="$(dirname "$BASE_DIR")"

# Relative from <target>/.claude/<kind>/<name> to .claude-base/<kind>/<name>
REPO_CLAUDE_LINK_PREFIX="../../../.claude-base"
WORKSPACE_CLAUDE_LINK_PREFIX="../../.claude-base"

for_each_base_item_and_repo() {
  local kind="$1"
  local fn="$2"
  local src_dir="$BASE_DIR/$kind"
  [ -d "$src_dir" ] || return 0

  for item in "$src_dir"/*; do
    [ -e "$item" ] || continue
    local name
    name="$(basename "$item")"

    for repo in "$TITAN_ROOT"/*/; do
      repo="${repo%/}"
      [ "$repo" = "$BASE_DIR" ] && continue
      [ -d "$repo/.git" ] || [ -f "$repo/.git" ] || continue
      "$fn" "$kind" "$name" "$repo" "$item" "$REPO_CLAUDE_LINK_PREFIX"
    done
  done
}

for_each_base_item_workspace() {
  local kind="$1"
  local fn="$2"
  local src_dir="$BASE_DIR/$kind"
  [ -d "$src_dir" ] || return 0

  for item in "$src_dir"/*; do
    [ -e "$item" ] || continue
    local name
    name="$(basename "$item")"
    "$fn" "$kind" "$name" "$TITAN_ROOT" "$item" "$WORKSPACE_CLAUDE_LINK_PREFIX"
  done
}

git_exclude_entry() {
  local kind="$1" name="$2" repo="$3"
  local rel_path=".claude/$kind/$name"
  local exclude_file="$repo/.git/info/exclude"

  mkdir -p "$(dirname "$exclude_file")"
  touch "$exclude_file"
  grep -qxF "$rel_path" "$exclude_file" && return 0

  echo "$rel_path" >> "$exclude_file"
  echo "excluded: $repo -> $rel_path"
}

link_entry() {
  local kind="$1" name="$2" repo="$3" item="$4" link_prefix="$5"
  local target_dir="$repo/.claude/$kind"
  local target_path="$target_dir/$name"

  if [ -e "$target_path" ] || [ -L "$target_path" ]; then
    return 0 # real file/dir or existing symlink: leave as-is
  fi

  mkdir -p "$target_dir"
  ln -s "$link_prefix/$kind/$name" "$target_path"
  echo "linked: $target_path -> $item"
}

for_each_base_item_and_repo "skills" link_entry
for_each_base_item_and_repo "agents" link_entry
for_each_base_item_and_repo "commands" link_entry
for_each_base_item_workspace "skills" link_entry
for_each_base_item_workspace "agents" link_entry
for_each_base_item_workspace "commands" link_entry

if [ "$GIT_EXCLUDE" = "true" ]; then
  for_each_base_item_and_repo "skills" git_exclude_entry
  for_each_base_item_and_repo "agents" git_exclude_entry
  for_each_base_item_and_repo "commands" git_exclude_entry
fi
