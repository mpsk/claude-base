---
name: pr-line-stats
description: Count changed lines in a pull request (or the current branch) grouped by file kind — `*.md`, tests (`*.test.*` / `*.spec.*`), lockfiles, generated (contracts bundle, snapshots) and other code — and show what the "PR size" check would count after its exclude-regex, with a warn/fail verdict. Use whenever the user asks for PR stats, diff size, "how big is PR #N", how many lines are tests vs code, whether a PR will pass or trip the PR size check, or wants to know if a branch needs splitting — even if they don't name this skill.
---

# PR line stats

Run the bundled script instead of adding up numbers by hand. The script gives the same result every time, and it reads the real PR file list from GitHub. A local `main...HEAD` diff can pull in thousands of unrelated files after a `staging` merge.

## Run

From inside the target repo:

```bash
bash ~/MPI/titan/.claude-base/skills/pr-line-stats/scripts/pr_line_stats.sh [PR_NUMBER] [--base <ref>] [--list]
```

- `PR_NUMBER` — optional, `#452` or `452`. Omitted: uses the current branch's PR.
- No PR found: falls back to `git diff --numstat <base>...HEAD`. Base defaults to `origin/staging`, else `origin/main`; override with `--base`. Tell the user the numbers came from the local diff, because they may differ from the PR.
- `--list` — also print each file with its group, counts and whether the size check excludes it. Use it when the user asks which files drive the size.

The script calls `gh` with `GITHUB_TOKEN=` cleared, so `gh` uses keyring credentials (same as `/pr-comments`). If `gh` says it is not authenticated, tell the user to run `gh auth login`.

## Groups

Each file goes into the first matching group:

| Group | Matches |
|---|---|
| lockfiles | `pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`, `go.sum`, `uv.lock`, `poetry.lock` |
| generated | `packages/contracts/contracts/**`, `__snapshots__/`, `*.snap` |
| md | `*.md` |
| test | `*.test.*` / `*.spec.*` (`ts`, `tsx`, `js`, `jsx`, `mjs`, `cjs`) |
| other | everything else |

"Changed" = added + removed.

## PR size section

When the repo has `.github/workflows/pr-size.yml`, the script reads `exclude-regex` and the warn/fail limits from it. It then prints the counted lines and files with a verdict: `ok`, `WARN` or `FAIL`. The real check runs in `Titandxp/cicd-scripts` (`RW_pr_size.yml`). The script assumes that check counts added + removed lines on files not matched by `exclude-regex`. If the user reports a mismatch with the CI comment, trust CI and say so.

No `pr-size.yml`: the section is skipped. Report only the groups.

## Report

Show the group table as a markdown table. Then add 2–4 short bullets:
- the share of changed lines that are tests,
- the biggest files, if `--list` was used,
- the PR size verdict. On `WARN` or `FAIL`, point to the split options in the repo's `CLAUDE.md` ("PR size" section).

Don't paste the raw script output as well as the table.
