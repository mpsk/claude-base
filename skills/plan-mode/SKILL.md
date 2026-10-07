---
name: plan-mode
description: Use when Plan Mode is active. Defines how to research, which plan template to use, and how to hand off to the superpower pipeline after the plan is approved.
---

## Purpose

In Plan Mode the main thread is the planner. It replaces the `task-planner` stage of `superpower`.

Plan Mode allows writes only to the harness-assigned plan file until `ExitPlanMode` is approved.
Do not spawn `task-planner`, `feature-implementer` or `docs-updater` while Plan Mode is active.

## Research

Pick the cheapest tool that answers the question:

| Need | Tool |
| --- | --- |
| One or two known files | Read directly |
| Locate code across the repo | built-in `Explore` agent |
| Unfamiliar library or API, external docs, or a large sweep of existing documented functionality | `researcher` agent (`model: "opus"`) |

`researcher` keeps large reads out of the main context, but it starts from zero context and runs on Opus.
Do not use it for lookups that a direct read or `Explore` answers.

When spawning `researcher`, include in the prompt:

- "Plan Mode is active: return all findings inline. Do not write files."
- The exact question, the target repo, and relevant file paths. Do not pass the whole conversation.

Use the "Implementation hints" section of its output in the plan.

## Plan file

- Use the template in `.claude/skills/plan-mode/plan-template.md` (source: `.claude-base/skills/plan-mode/plan-template.md`).
- The header must include `**Repo**:`. When the session runs at the workspace root, this is the only record of the target repo.

## After ExitPlanMode is approved

1. Save the plan as `<repo>/.claude/plans/YYYY-MM-DD-<feature>.md`:
   - If the plan file is already in that folder (via `plansDirectory`), rename it to this pattern.
   - Otherwise copy it there.
2. Continue with `superpower` at the `feature-implementer` stage, one plan step at a time.
