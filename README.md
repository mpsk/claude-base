# Titan .claude-base

Shared Claude Code skills and agents for all repos under `~/MPI/titan`.

## Layout

```
.claude-base/
  skills/<name>/SKILL.md      # base skills
  agents/<name>.agent.md      # base agents
  commands/<name>.md          # base slash commands
  sync.sh                     # symlinks the above into every repo
```

## Available now

- **`skills/agent-mode-instructions`** — propose-first workflow: present options, wait for confirmation, then implement. Never edit files in the same response as a proposal/answer.
- **`skills/superpower`** — triages every non-trivial task by tier (trivial/small/complex) and routes it through the matching worker agents before any code is written. Named `superpower` (singular), not `superpowers`, to avoid clashing with the global `superpowers` plugin (`/superpowers:brainstorming`, etc).
- **`commands/pr-comments`** — `/pr-comments`: fetches PR-level + review comments for the current branch's PR, formats them, offers to fix, then resolves addressed threads via GraphQL. Repos with their own `/pr-comments` (e.g. Studio, signer-experience) keep theirs.
- **`agents/task-planner`**, **`agents/feature-implementer`**, **`agents/researcher`**, **`agents/docs-updater`** — the workers `superpower` routes to. Each reads the target repo's own `CLAUDE.md`/`docs/coding-standards.md` for conventions rather than assuming a stack.

## How it works

`sync.sh` walks every git repo directly under `~/MPI/titan/*` (skipping
`.claude-base` itself), plus the workspace root `~/MPI/titan/.claude/` (Titan
is not a git repo — no `git-exclude` there). For each base skill/agent it
creates a symlink:

```
<repo>/.claude/skills/<name>          -> ../../../.claude-base/skills/<name>
<repo>/.claude/agents/<name>.agent.md -> ../../../.claude-base/agents/<name>.agent.md
<repo>/.claude/commands/<name>.md      -> ../../../.claude-base/commands/<name>.md

~/MPI/titan/.claude/skills/<name>     -> ../../.claude-base/skills/<name>
~/MPI/titan/.claude/agents/<name>.agent.md -> ../../.claude-base/agents/<name>.agent.md
```

It only creates a link when the target path doesn't already exist. A repo
that defines its own real skill/agent with the same name is never touched —
**the repo's own file always overrides the base one.**

## Usage

Run once after adding a new repo under Titan, or after adding a new
base skill/agent name. `git-exclude=true|false` is required, controls
whether `.git/info/exclude` entries are also written:

```bash
./sync.sh git-exclude=false   # symlink only
./sync.sh git-exclude=true    # symlink + write .git/info/exclude entries
```

No rerun needed after editing an *existing* base skill's content — every
repo already symlinks to the same file, so the change is visible
immediately everywhere.

## Adding a new base skill

```bash
mkdir -p skills/<name>
# write skills/<name>/SKILL.md
./sync.sh git-exclude=true
```

## Adding a new base agent

```bash
# write agents/<name>.agent.md
./sync.sh git-exclude=true
```

## Overriding in one repo

Just create a real file/dir at `<repo>/.claude/skills/<name>` (or a real
`<repo>/.claude/agents/<name>.agent.md`) with the same name as the base
one. `sync.sh` will skip it on future runs, and Claude Code will use the
repo's version.

## Excluding symlinks from each repo's git

The symlinks `sync.sh` creates live inside each repo's `.claude/` and show
up as untracked in that repo's `git status`. Not committed yet — pick one:

1. **`.git/info/exclude`** (per repo, local only, no diff) — automated:
   ```bash
   ./sync.sh git-exclude=true
   ```
   Appends each base skill/agent path to every repo's `.git/info/exclude`. Idempotent, safe to rerun.

2. **`.gitignore`** (committed, visible to whole team) — same lines, but
   signals to teammates these paths are local-machine-only.

3. **Global gitignore** (`git config --global core.excludesFile ~/.gitignore_global`,
   recommended) — one file, applies to every repo on this machine, no
   per-repo edit, and future base skills/agents auto-covered if the
   pattern is broad enough (e.g. `.claude/agents/*.agent.md` if all
   base agents live there and no repo defines its own agent files).

`.git/info/exclude` is the current setup, applied via `./sync.sh git-exclude=true`.

## Notes

- **Correction (superseded the note below):** in practice, `model:` in `agents/<name>.agent.md` frontmatter is **not honored** by the Agent tool for these base agents — confirmed by observing `task-planner` run on Sonnet despite `model: opus` in its frontmatter. Suspected cause: the harness only reads the pinned model from files named exactly `<name>.md`, not `<name>.agent.md` (this repo's symlinks use the `.agent.md` suffix so `sync.sh` can tell base-agent symlinks apart from a repo's own real agent files). Until confirmed/fixed, **always pass `model: "opus"` explicitly** on the Agent tool call when spawning `task-planner` or `researcher`, and `model: "sonnet"` for `feature-implementer` — do not rely on the frontmatter pin alone.
