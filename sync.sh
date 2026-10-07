#!/usr/bin/env bash
# Symlinks base skills/agents from .claude-base into:
#   - every Titan git repo
#   - the workspace root ~/MPI/titan (not a git repo)
# Safe to rerun: preserve handwritten overrides; refresh converter-owned Codex files.
#
# Targets (default: claude):
#   claude - <target>/.claude/{skills,agents,commands} as symlinks (dir created if missing)
#   codex  - use claude-to-codex.sh where .codex already exists: TOML agents,
#            adapted skills and commands under .agents/skills.
#
# Usage:
#   ./sync.sh [claude] [codex] [git-exclude=<true|false>]
#     (no target)  - same as `claude`
#     claude codex - both targets
#     git-exclude  - default true: also add each base skill/agent path to every repo's
#                    .git/info/exclude (workspace root skipped); false skips it
set -euo pipefail

usage() {
  echo "usage: $0 [claude] [codex] [git-exclude=<true|false>] [--dry-run] [-h|--help]" >&2
  exit 1
}

help() {
  cat <<EOF
Usage: $0 [claude] [codex] [git-exclude=<true|false>] [--dry-run] [-h|--help]

Symlinks base skills/agents from .claude-base into every Titan git repo and the workspace root.
Safe to rerun: preserve handwritten overrides; refresh output and prune stale owned files.

Targets (default: claude):
  claude   .claude/{skills,agents,commands} symlinks (dir created if missing)
  codex    workspace and immediate child folders with .codex, including non-Git folders;
           run claude-to-codex.sh to generate TOML agents
           and adapted skills/commands under .agents/skills. See helper --help.

Options:
  git-exclude=<true|false>   add linked paths to each repo's .git/info/exclude (default true)
  --dry-run                 show actions without changing destination files
  -h, --help                 show this help
EOF
}

GIT_EXCLUDE=true
DRY_RUN=false
TARGETS=()
for arg in "$@"; do
  case "$arg" in
    -h | --help) help; exit 0 ;;
    claude | codex) TARGETS+=("$arg") ;;
    git-exclude=true | git-exclude=false) GIT_EXCLUDE="${arg#git-exclude=}" ;;
    --dry-run) DRY_RUN=true ;;
    *) usage ;;
  esac
done
[ ${#TARGETS[@]} -gt 0 ] || TARGETS=(claude)

wants_target() {
  local t
  for t in "${TARGETS[@]}"; do [ "$t" = "$1" ] && return 0; done
  return 1
}

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

# Claude symlinks are handled here; Codex conversion is delegated to the helper.
config_dirs_for() {
  local kind="$1" repo="$2"
  if wants_target claude; then
    echo ".claude"
  fi
}

git_exclude_entry() {
  local kind="$1" name="$2" repo="$3"
  local exclude_file
  exclude_file=$(git -C "$repo" rev-parse --git-path info/exclude)
  case "$exclude_file" in /*) ;; *) exclude_file="$repo/$exclude_file" ;; esac
  local cfg rel_path

  for cfg in $(config_dirs_for "$kind" "$repo"); do
    rel_path="$cfg/$kind/$name"
    if [ -f "$exclude_file" ] && grep -qxF "$rel_path" "$exclude_file"; then continue; fi
    if $DRY_RUN; then echo "would exclude: $repo -> $rel_path"; continue; fi
    mkdir -p "$(dirname "$exclude_file")"
    echo "$rel_path" >> "$exclude_file"
    echo "excluded: $repo -> $rel_path"
  done
}

link_entry() {
  local kind="$1" name="$2" repo="$3" item="$4" link_prefix="$5"
  local cfg target_dir target_path

  for cfg in $(config_dirs_for "$kind" "$repo"); do
    target_dir="$repo/$cfg/$kind"
    target_path="$target_dir/$name"

    if [ -e "$target_path" ] || [ -L "$target_path" ]; then
      continue # real file/dir or existing symlink: leave as-is
    fi

    if $DRY_RUN; then echo "would link: $target_path -> $item"; continue; fi
    mkdir -p "$target_dir"
    ln -s "$link_prefix/$kind/$name" "$target_path"
    echo "linked: $target_path -> $item"
  done
}

cleanup_claude_links() {
  local repo="$1" link_prefix="$2" kind path name
  for kind in skills agents commands; do
    for path in "$repo/.claude/$kind"/*; do
      [ -L "$path" ] || continue
      name="$(basename "$path")"
      # Match only links created by this sync layout, not unrelated links.
      [ "$(readlink "$path")" = "$link_prefix/$kind/$name" ] || continue
      [ ! -e "$BASE_DIR/$kind/$name" ] || continue
      if $DRY_RUN; then echo "would remove stale link: $path"; else
        rm -f "$path"
        echo "removed stale link: $path"
      fi
    done
  done
}

for_each_base_item_and_repo "skills" link_entry
for_each_base_item_and_repo "agents" link_entry
for_each_base_item_and_repo "commands" link_entry
for_each_base_item_workspace "skills" link_entry
for_each_base_item_workspace "agents" link_entry
for_each_base_item_workspace "commands" link_entry

if wants_target claude; then
  for repo in "$TITAN_ROOT"/*/; do
    repo="${repo%/}"
    [ "$repo" != "$BASE_DIR" ] || continue
    [ -d "$repo/.git" ] || [ -f "$repo/.git" ] || continue
    cleanup_claude_links "$repo" "$REPO_CLAUDE_LINK_PREFIX"
  done
  cleanup_claude_links "$TITAN_ROOT" "$WORKSPACE_CLAUDE_LINK_PREFIX"
fi

if [ "$GIT_EXCLUDE" = "true" ]; then
  for_each_base_item_and_repo "skills" git_exclude_entry
  for_each_base_item_and_repo "agents" git_exclude_entry
  for_each_base_item_and_repo "commands" git_exclude_entry
fi

if wants_target codex; then
  converter_args=()
  $DRY_RUN && converter_args+=(--dry-run)
  [ "$GIT_EXCLUDE" = false ] || converter_args+=(--git-exclude)
  for repo in "$TITAN_ROOT"/*/ "$TITAN_ROOT/"; do
    repo="${repo%/}"
    [ "$repo" != "$BASE_DIR" ] || continue
    [ -d "$repo/.codex" ] || continue
    bash "$BASE_DIR/claude-to-codex.sh" --source "$BASE_DIR" --target "$repo" ${converter_args[@]+"${converter_args[@]}"}
  done
fi
