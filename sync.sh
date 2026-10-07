#!/usr/bin/env bash
# Symlinks base skills/agents from .claude-base into:
#   - every immediate child Git repository
#   - the parent workspace root
# Safe to rerun: preserve handwritten overrides; refresh converter-owned Codex files.
#
# Targets (default: claude):
#   claude - <target>/.claude/{skills,agents,commands} as symlinks (dir created if missing)
#   codex  - create TOML agents and converted skills in child Git repos and
#            the workspace root; also sync non-Git child folders with .codex.
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

Symlinks base skills/agents from .claude-base into immediate child Git repositories and the workspace root.
Safe to rerun: preserve handwritten overrides; refresh output and prune stale owned files.

Targets (default: claude):
  claude   .claude/{skills,agents,commands} symlinks (dir created if missing)
  codex    workspace, immediate child Git repos, and non-Git child folders with .codex;
           run lib/claude-to-codex.sh to generate TOML agents
           and adapted skills/commands under .agents/skills. See helper --help.

Options:
  git-exclude=<true|false>   add linked paths to each repo's .git/info/exclude (default true)
  --dry-run                 show actions without changing destination files
  --all                     sync all eligible destinations without prompting
  --target NAME             select a child folder; use . for workspace (repeatable)
  --interactive             prompt even when stdin is piped
  -h, --help                 show this help
EOF
}

GIT_EXCLUDE=true
DRY_RUN=false
TARGETS=()
ALL=false
INTERACTIVE=false
REQUESTED=()
while [ "$#" -gt 0 ]; do
  arg="$1"
  case "$arg" in
    -h | --help) help; exit 0 ;;
    claude | codex) TARGETS+=("$arg") ;;
    git-exclude=true | git-exclude=false) GIT_EXCLUDE="${arg#git-exclude=}" ;;
    --dry-run) DRY_RUN=true ;;
    --all) ALL=true ;;
    --interactive) INTERACTIVE=true ;;
    --target)
      [ "$#" -ge 2 ] || usage
      REQUESTED+=("$2"); shift ;;
    *) usage ;;
  esac
  shift
done
[ ${#TARGETS[@]} -gt 0 ] || TARGETS=(claude)

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(dirname "$BASE_DIR")"

source "$BASE_DIR/lib/destinations.sh"
select_destinations

helper_args=()
$DRY_RUN && helper_args+=(--dry-run)
[ "$GIT_EXCLUDE" = false ] || helper_args+=(--git-exclude)
for destination in "${SELECTED[@]}"; do
  if wants_target claude && { [ "$destination" = "$WORKSPACE_ROOT" ] || [ -e "$destination/.git" ]; }; then
    bash "$BASE_DIR/lib/sync-claude.sh" --source "$BASE_DIR" --target "$destination" ${helper_args[@]+"${helper_args[@]}"}
  fi
  if wants_target codex; then
    bash "$BASE_DIR/lib/claude-to-codex.sh" --source "$BASE_DIR" --target "$destination" ${helper_args[@]+"${helper_args[@]}"}
  fi
done
