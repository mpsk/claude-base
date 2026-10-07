#!/usr/bin/env bash
# Changed-line stats for a PR (or the local branch), grouped by file kind,
# plus the totals the "PR size" check would count after its exclude-regex.
#
# Usage:
#   pr_line_stats.sh [PR_NUMBER] [--base <ref>] [--list]
#
#   PR_NUMBER   PR to measure. Omitted: the current branch's PR; if none, the
#               local diff <base>...HEAD.
#   --base REF  Base ref for the local fallback (default: origin/<PR base>,
#               else origin/staging, else origin/main).
#   --list      Also print every file with its group and counts.
#
# Run from inside the target repo. Reads limits and exclude-regex from
# .github/workflows/pr-size.yml when present.

set -euo pipefail

pr_number=""
base_ref=""
show_list=0

while [ $# -gt 0 ]; do
  case "$1" in
    --base) base_ref="$2"; shift 2 ;;
    --list) show_list=1; shift ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) pr_number="${1#\#}"; shift ;;
  esac
done

repo_root=$(git rev-parse --show-toplevel)
numstat=$(mktemp)
trap 'rm -f "$numstat"' EXIT

# GITHUB_TOKEN= makes gh fall back to keyring credentials (see /pr-comments).
gh_cmd() { GITHUB_TOKEN= gh "$@"; }

if [ -z "$pr_number" ]; then
  pr_number=$(gh_cmd pr view --json number --jq .number 2>/dev/null || true)
fi

if [ -n "$pr_number" ]; then
  name_with_owner=$(gh_cmd repo view --json nameWithOwner --jq .nameWithOwner)
  pr_meta=$(gh_cmd pr view "$pr_number" --json title,headRefName,baseRefName \
    --jq '"#'"$pr_number"' \(.title)  (\(.headRefName) -> \(.baseRefName))"')
  source_label="PR $pr_meta"
  # REST files endpoint, paginated (gh pr view --json files can truncate).
  gh_cmd api --paginate "repos/$name_with_owner/pulls/$pr_number/files?per_page=100" \
    --jq '.[] | "\(.additions)\t\(.deletions)\t\(.filename)"' > "$numstat"
else
  if [ -z "$base_ref" ]; then
    for candidate in origin/staging origin/main; do
      if git rev-parse --verify --quiet "$candidate" >/dev/null; then
        base_ref="$candidate"; break
      fi
    done
  fi
  source_label="local diff $base_ref...HEAD (no PR found)"
  # Binary files report "-"; awk treats them as 0.
  git diff --numstat "$base_ref...HEAD" > "$numstat"
fi

size_yml="$repo_root/.github/workflows/pr-size.yml"
yml_value() {
  [ -f "$size_yml" ] || return 0
  grep -E "^[[:space:]]*$1:" "$size_yml" | head -1 \
    | sed -E "s/^[[:space:]]*$1:[[:space:]]*//; s/^'(.*)'\$/\1/; s/^\"(.*)\"\$/\1/"
}

# Passed via ENVIRON so awk does not eat the regex backslashes.
EXCLUDE_RE=$(yml_value exclude-regex) \
WARN_LINES=$(yml_value warn-lines) WARN_FILES=$(yml_value warn-files) \
FAIL_LINES=$(yml_value fail-lines) FAIL_FILES=$(yml_value fail-files) \
SOURCE_LABEL="$source_label" SHOW_LIST="$show_list" \
awk -F'\t' '
function group_of(path) {
  if (path ~ /(^|\/)(pnpm-lock\.yaml|package-lock\.json|yarn\.lock|go\.sum|uv\.lock|poetry\.lock)$/) return "lockfiles"
  if (path ~ /^packages\/contracts\/contracts\// || path ~ /(^|\/)__snapshots__\// || path ~ /\.snap$/) return "generated"
  if (path ~ /\.md$/) return "md"
  if (path ~ /\.(test|spec)\.[cm]?[jt]sx?$/) return "test"
  return "other"
}
function row(label, files, added, removed) {
  printf "%-12s %6d %8s %8s %9d\n", label, files, "+" added, "-" removed, added + removed
}
{
  added = ($1 == "-") ? 0 : $1
  removed = ($2 == "-") ? 0 : $2
  path = $3
  group = group_of(path)
  files[group]++; adds[group] += added; dels[group] += removed
  total_files++; total_adds += added; total_dels += removed
  excluded = (ENVIRON["EXCLUDE_RE"] != "" && path ~ ENVIRON["EXCLUDE_RE"])
  if (!excluded) { counted_files++; counted_lines += added + removed }
  if (ENVIRON["SHOW_LIST"] == 1) listing[NR] = sprintf("%-10s %6s %6s  %s%s", group, "+" added, "-" removed, path, excluded ? "  (excluded)" : "")
}
END {
  print ENVIRON["SOURCE_LABEL"]
  print ""
  printf "%-12s %6s %8s %8s %9s\n", "group", "files", "added", "removed", "changed"
  split("md test lockfiles generated other", order, " ")
  for (index_ = 1; index_ <= 5; index_++) {
    name = order[index_]
    row(name, files[name], adds[name], dels[name])
  }
  row("total", total_files, total_adds, total_dels)

  if (ENVIRON["EXCLUDE_RE"] != "") {
    warn_lines = ENVIRON["WARN_LINES"]; warn_files = ENVIRON["WARN_FILES"]
    fail_lines = ENVIRON["FAIL_LINES"]; fail_files = ENVIRON["FAIL_FILES"]
    verdict = "ok"
    if (counted_lines > warn_lines || counted_files > warn_files) verdict = "WARN"
    if (counted_lines > fail_lines || counted_files > fail_files) verdict = "FAIL"
    print ""
    printf "PR size check (after exclude-regex): %d lines, %d files -> %s\n", counted_lines, counted_files, verdict
    printf "  limits: warn > %s lines / %s files, fail > %s lines / %s files\n", warn_lines, warn_files, fail_lines, fail_files
  }
  if (ENVIRON["SHOW_LIST"] == 1) {
    print ""
    for (line_no = 1; line_no <= NR; line_no++) print listing[line_no]
  }
}
' "$numstat"
