# Shared Claude and Codex settings

`.claude-base` is the source of shared agents, skills, and workflows for the
workspace containing this repository. Pull its updates on each laptop, then run
`sync.sh` for Claude or `sync.sh codex` for Codex.

## Layout

```text
<workspace>/
  .claude-base/
    agents/<name>.agent.md       # Claude agent definitions
    skills/<name>/SKILL.md       # shared skills and optional resources
    commands/<name>.md           # Claude command workflows
    sync.sh                     # selects targets and syncs settings
    lib/
      destinations.sh           # discovery and interactive selection
      git-exclude.sh            # shared Git exclude function
      sync-claude.sh            # Claude links and cleanup for one destination
      claude-to-codex.sh         # Codex conversion for one destination
      claude-to-codex.awk        # metadata and instruction conversion
    tests/claude-to-codex.sh     # conversion and sync regression tests
  <project>/
```

The workspace path is derived from the location of `sync.sh`; there are no
machine-specific workspace paths. Discovery covers immediate child folders,
not nested projects or hidden child folders. `.claude-base` itself is skipped.

## Usage

From `.claude-base`:

```bash
./sync.sh                       # Claude; local Git excludes enabled
./sync.sh codex                 # Codex; local Git excludes enabled
./sync.sh claude codex          # both
./sync.sh claude codex --dry-run # preview without destination changes
./sync.sh codex git-exclude=false
./sync.sh codex --all           # all eligible destinations, no prompt
./sync.sh codex --target my-project
./sync.sh claude codex --target . --target my-project
```

From the workspace root, use `.claude-base/sync.sh` with the same arguments.

Interactive runs list eligible destinations and let you choose `0` (all), a numbered
selection such as `1,3`, or `cancel`; `all` also still works. The workspace root is listed
as `.`. The menu shows which configuration folders will be created and, for the `claude`
target, which child repos will get `plansDirectory` set. Selection applies to file
generation, Git excludes, and cleanup for both targets.

Use `--all` or repeatable `--target NAME` for noninteractive runs. `--target .`
selects the workspace root. Unknown targets fail before destination changes.
`--dry-run` previews all eligible destinations without prompting unless specific
targets were supplied. Use `--interactive` to read menu input from a pipe.

| Target | Destinations | Output |
| --- | --- | --- |
| `claude` (default) | Immediate child Git repos and the workspace root | `.claude/{agents,skills,commands}` symlinks; in child repos also `plansDirectory` in `.claude/settings.local.json` |
| `codex` | Immediate child Git repos, the workspace root, and non-Git child folders already containing `.codex/` | TOML agents and converted skills |

`sync.sh codex` creates `.codex/agents/` and `.agents/skills/` automatically in
the workspace root and immediate child Git repositories. Non-Git child folders
are selected only if they already contain `.codex/`. Other folders are skipped.

Claude sync also sets `plansDirectory` to `<repo>/.claude/plans` (absolute path) in each
child repo's `.claude/settings.local.json`, so Plan Mode writes plans into the repo instead of
`~/.claude/plans/`. Existing keys are kept, an existing `plansDirectory` is preserved, and the
file is added to the local Git exclude. The step needs `jq` and is skipped without it. The
workspace root is skipped: plans made there are copied to the target repo by `plan-mode`.

Existing Claude symlinks expose source edits immediately. Rerun Claude sync to
install new names or clean up deletions and renames. Codex files are generated
copies: rerun Codex sync after every source update.

`git-exclude` defaults to `true`. It appends output paths to Git's local exclude
file, including in linked worktrees; no `.gitignore` is edited. Codex folders
outside a Git checkout have no exclude file to update. Exclude entries are not
removed when a definition is deleted.

## Available definitions

### Skills

`skills/<name>/SKILL.md`. Claude selects a skill from its description, or you
invoke it as `/<name>`. In Codex, use `$<name>`.

| Skill | What it does | When to use |
| --- | --- | --- |
| `agent-mode-instructions` | Propose 1–3 options with trade-offs, wait for a decision, then implement. Questions get answers only, no file edits. Has an explicit “apply without asking” exception. | Start of any non-trivial task. |
| `superpower` | Triages a task as trivial, small, or complex and routes it through the worker agents below, with a visible routing step and compliance footer. | Start of any non-trivial task, before planning or coding. |
| `plan-mode` | Plan Mode workflow: the main thread plans instead of `task-planner`, optional `researcher` for unfamiliar libraries/APIs, shared plan template, then hand-off to `superpower` at `feature-implementer`. Holds `plan-template.md`, which `task-planner` also uses. | Plan Mode is active. |
| `pr-line-stats` | Counts changed lines in a PR or the current branch, grouped as lockfiles, generated, `*.md`, tests, and other. Applies the repo's `pr-size.yml` exclude regex and reports an `ok` / `WARN` / `FAIL` verdict. | PR size questions, tests vs code share, or whether a branch needs splitting. |

`pr-line-stats` runs a bundled script from inside the target repo:

```bash
bash <workspace>/.claude-base/skills/pr-line-stats/scripts/pr_line_stats.sh [PR_NUMBER] [--base <ref>] [--list]
```

Without a PR it falls back to `git diff <base>...HEAD`; `--base` defaults to
`origin/staging`, else `origin/main`. `--list` prints per-file counts. It needs
`gh` authenticated through the keyring (`gh auth login`).

### Agents

`agents/<name>.agent.md`. Spawned as subagents, usually by `superpower`.

| Agent | Role | When to use | Model | Tools |
| --- | --- | --- | --- | --- |
| `researcher` | Investigates external APIs, libraries, and framework behavior. Produces guidance and option comparisons, not production code. | Before planning, when a library, API, or integration approach is unfamiliar. | `opus` | Read, Grep, Glob, WebFetch, WebSearch, Bash |
| `task-planner` | Turns a task into a minimal plan with scoped steps, risks, and a test strategy. Writes plan files to `.claude/plans/`. | Beginning of any non-trivial implementation. | `opus` | Read, Grep, Glob, Bash, Edit, Write, WebFetch, WebSearch |
| `feature-implementer` | Implements one plan step with a minimal, reviewable diff that follows project conventions. No unrelated cleanup. | After `task-planner` produces a plan. | `sonnet` | Read, Edit, Write, Grep, Glob, Bash, WebFetch, WebSearch |
| `docs-updater` | Updates developer docs, README notes, migration guidance, and changelogs to match code changes, without inventing behavior. | After changes that affect `docs/`, co-located `.md` files, or `CLAUDE.md`. | `haiku` | Read, Edit, Write, Grep, Glob, Bash |

Claude does not honor the frontmatter `model:` pin for `.agent.md` files. Pass
`model` explicitly on the Agent call. Codex model mapping is described under
[Codex conversion](#codex-conversion).

### Commands

`commands/<name>.md`. Invoke as `/<name>` in Claude, or `$<name>` in Codex.

| Command | What it does |
| --- | --- |
| `pr-comments` | Fetches PR-level and review comments for the current branch's PR, then works through actionable comments one by one. It does not resolve GitHub review threads. Uses `gh` with keyring credentials. |

## Codex conversion

| Claude source | Codex output | Invocation |
| --- | --- | --- |
| `agents/<name>.agent.md` | `.codex/agents/<name>.toml` | Named custom agent when supported by the runtime |
| `skills/<name>/` | `.agents/skills/<name>/` | `$<name>` or implicit skill selection |
| `commands/<name>.md` | `.agents/skills/<name>/SKILL.md` | Explicit `$<name>`, e.g. `$pr-comments` |

Codex discovers project skills under `.agents/skills/`. Converted commands are
skills with `allow_implicit_invocation: false` in `agents/openai.yaml`. They are
not custom CLI slash commands. The converter does not generate `.codex/prompts/`:
Codex's deprecated custom prompts use the user-level `~/.codex/prompts/` directory.

The converter uses Bash and `awk`. It supports plain or quoted single-line YAML
frontmatter and rejects unsupported syntax before installing output for that
target. Agent `name`, `description`, and body become TOML `name`, `description`,
and `developer_instructions`. Known Claude-specific instructions are adapted to
`AGENTS.md`, Codex subagent tools, and `.codex/plans/`.

Claude-only `tools`, `disallowedTools`, `permissionMode`, and `maxTurns` are
reported and omitted. Commands also omit `allowed-tools`, `argument-hint`, and
`disable-model-invocation`; converted commands always require explicit invocation.
Tool lists are not translated into permissions. Agents inherit session permissions.
Skill resources are copied, Markdown references adapted, and executable files
left intact. Agent filename collisions and skill/command folder collisions fail.

This converts the shared definitions, not arbitrary Claude plugins, hooks, MCP
servers, or settings JSON. Review new source instructions for assumptions needing
additional conversion rules. The scripts do not create or repair `AGENTS.md`.

Agents inherit the parent model by default. Optional environment variables map
Claude tiers to exact Codex model IDs available on that laptop:

```bash
CODEX_MODEL_OPUS=gpt-6.1-sol CODEX_MODEL_SONNET=gpt-6-luna \
CODEX_MODEL_HAIKU=gpt-6-luna CODEX_REASONING_EFFORT=high \
./sync.sh codex
```

`CODEX_REASONING_EFFORT` applies only to explicitly mapped models. Model
availability and supported reasoning levels must match your account and client.

The helpers can sync one target directly. Codex needs no existing `.codex/`:

```bash
./lib/claude-to-codex.sh --target ../my-project --dry-run
./lib/claude-to-codex.sh --target ../my-project --git-exclude
./lib/sync-claude.sh --target ../my-project --dry-run
```

Both helpers default to this repository above `lib/` as the source and its parent
workspace as the target. Use `--source DIR` to supply a different source tree.
The helpers default to no Git exclude updates; `sync.sh` forwards its policy.

`lib/destinations.sh` and `lib/git-exclude.sh` define functions only. The entry
point selects destinations once, then calls the sync helpers for each selection.

## Overrides and cleanup

Claude preserves existing files, directories, and symlinks. To override a shared
Claude definition, replace its symlink with a real file or directory.

Codex refreshes files and skill folders carrying the converter's generation
marker. To override generated content, remove the marker before editing. New
handwritten agents and skill folders are preserved.

On deletion or renaming, Claude removes only links matching the base sync layout.
Codex removes only obsolete agents or skill folders with its generation marker.
A generated skill folder is owned as a whole, including its resources. Unrelated
links and handwritten overrides survive. Old sync-generated `.agent.md` files
and `.codex/skills` symlinks pointing into `.claude-base` are also removed.

Cleanup runs only for the selected target. `--dry-run` previews generation and
cleanup without changing destination files. Conversion is staged per destination;
there is no transaction across all projects if a later target fails.

## Verification

Tests require Bash, Git, and standard macOS/Linux command-line tools; ripgrep
is not required.

```bash
bash tests/claude-to-codex.sh
for script in sync.sh lib/*.sh tests/claude-to-codex.sh; do
  bash -n "$script" || exit 1
done
```

Tests cover UTF-8, conversion, dry runs, reruns, overrides, legacy migration,
non-Git Codex targets, deletion/rename cleanup, and malformed input. They run in
temporary workspaces and do not prove discovery by an already-running client.

Official Codex references: [skills](https://developers.openai.com/codex/skills/),
[custom agents](https://developers.openai.com/codex/subagents/), and
[deprecated custom prompts](https://developers.openai.com/codex/custom-prompts/).
