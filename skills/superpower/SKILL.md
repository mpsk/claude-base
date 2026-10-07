---
name: superpower
description: Routes work through the correct worker agents before any task action, requiring explicit worker selection and visible compliance. Use at the start of any non-trivial task.
---

## Purpose

This skill enforces structured execution by routing tasks through the right workers before any planning, coding, or investigation begins. It prevents jumping straight into implementation without the right specialist framing.

Workers are **dedicated agents** defined in `.claude/agents/` and spawned via the Agent tool.

---

## Worker Catalog

| Worker                | When to use                                                                                                      |
| --------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `task-planner`        | Non-trivial feature, refactor, or bug fix — before any code is written. Outputs a plan file in `.claude/plans/`. |
| `feature-implementer` | Executing a specific plan step. One step at a time, minimal diff.                                                |
| `researcher`          | Unfamiliar library, undocumented API, uncertain integration — before planning.                                   |
| `docs-updater`        | Public behavior, API, or config changed. Updates `docs/`, co-located `.md`, and `CLAUDE.md`.                     |

---

## Orchestrator Role

The **main thread is the orchestrator**. Workers cannot spawn other workers (subagents have no Agent tool), so orchestration always lives here.

The orchestrator:

1. **Routes** — selects the pipeline (see Routing Step below).
2. **Spawns workers** via the Agent tool, passing only the scoped context that worker needs (the plan step, relevant file paths — not the whole conversation).
3. **Manages results** — reads each worker's output before advancing. If a `feature-implementer` diff drifts from its plan step or looks off, re-spawn with corrective feedback instead of patching it inline.
4. **Keeps context lean** — large worker outputs and diffs go to `.backpressure/` if the project uses that convention, otherwise a scratch location outside the conversation.
5. **Checks for locked decisions** — after `task-planner` returns, read its "3a. Decisions Locked" section if present and act on it before moving on to `feature-implementer`.

The orchestrator does not implement plan steps itself when a pipeline is active — that is `feature-implementer`'s job.

### Parallel implementation

When a plan has independent steps that touch **disjoint files**, spawn multiple `feature-implementer` workers concurrently (one Agent call per step, same message). Steps with shared files or sequential dependencies run one at a time — parallel edits to the same files will conflict.

---

## Model Policy

Model tiers are pinned in each agent's frontmatter — do not override them per-call without reason:

| Role                         | Model             | Why                                                                                                 |
| ---------------------------- | ------------------ | ---------------------------------------------------------------------------------------------------- |
| Orchestration (main thread)  | session model      | Run complex tasks on capable sessions — the orchestrator holds full context and judges results.       |
| `task-planner`               | `opus` (pinned)    | Planning quality floor, regardless of session model.                                                  |
| `researcher`                 | `opus` (pinned)    | Research/synthesis quality floor.                                                                     |
| `feature-implementer`        | `sonnet` (pinned)  | Scoped, well-specified diffs — cost-efficient.                                                        |
| `docs-updater`                | `haiku` (pinned)   | Mechanical doc sync.                                                                                   |

The expensive model plans and verifies; the cheap models execute well-specified steps.

---

## Task Triage (Required First)

Before selecting workers, classify the task. Machinery must match task size — an Opus planner spawned for a one-line fix is pure waste.

| Tier        | Signals                                                                                                            | Pipeline                                                                                                                             |
| ----------- | -------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| **Trivial** | 1 file, obvious change (typo, copy, one-liner, config tweak), no behavior risk                                       | No workers — the orchestrator edits directly.                                                                                          |
| **Small**   | 1–3 files, clear approach, no ambiguity, no API/schema change                                                          | No `task-planner`. Orchestrator writes a 3–5 line inline mini-plan in its response, then one `feature-implementer` (or edits inline if the diff is tiny). No plan file. |
| **Complex** | Multi-file, new feature, ambiguity, API/schema/auth/payment changes, or the affected area is documented in `docs/`     | Full pipeline (`task-planner → feature-implementer → …`) with a plan file in `.claude/plans/`.                                        |

**Escalation rule:** if a Trivial/Small task reveals hidden scope mid-flight (more files than expected, ambiguity, documented behavior affected), stop and re-triage upward — do not push through on the small pipeline.

Plan files in `.claude/plans/` are a Complex-tier artifact only.

**Plan Mode:** when Plan Mode is active, follow the `plan-mode` skill instead of spawning `task-planner`. After the plan is approved, resume this pipeline at `feature-implementer`.

---

## Core Rule

Before any planning, coding, reviewing, testing, or investigation:

1. Identify which workers apply
2. Announce the selected pipeline and the first active worker
3. Execute the current worker in its role format
4. Move to the next worker when the current one is done

If no worker applies, say so explicitly and proceed normally.

---

## Routing Step (Required Before Any Work)

Output this block before doing anything else:

```
Tier: <trivial | small | complex>
Selected workers: <ordered list, e.g. task-planner → feature-implementer; "none" for trivial>
Reason: <why this tier and these workers>
Current worker: <first worker to execute, or "none">
```

Do not write code, propose steps, or ask implementation-detail questions until this block is output.

---

## Worker Self-Identification (Required)

Every worker response must begin with:

```
Active worker: <worker name>
Purpose: <one sentence>
Scope: <what is in scope> / Out of scope: <what is not>
```

---

## Worker Compliance Footer (Required)

Every worker response must end with:

```
Worker compliance: followed <worker-name> format
```

If a worker cannot follow its format due to missing context, it must say so and stop.

---

## Default Pipelines

Use these pipelines unless there is a clear reason to deviate. Triage tier decides which applies.

### Simple feature / behavior change (Complex, well-understood area)

```
task-planner → feature-implementer
```

Add `docs-updater` if public behavior, API, or config changes.

### Complex feature, or refactor touching existing functionality (Complex)

```
researcher → task-planner → feature-implementer
```

Use `researcher` first when the work involves an unfamiliar library or API, **or** builds on / reshapes existing functionality that must be understood before planning — investigate the current behavior, related `docs/` and co-located `.md` files, and integration points, then hand findings to `task-planner`.
Add `docs-updater` at the end if public behavior, API, or config changes.

### Bug fix

Most bug fixes are **Small**: state repro + cause + fix as an inline mini-plan, then:

```
feature-implementer
```

Escalate to `task-planner → feature-implementer` only when the cause is unclear, the fix spans multiple modules, or documented behavior is affected.

### Refactor / simplification (Small)

Mechanical, 1–3 files: inline mini-plan → `feature-implementer`.
Anything reshaping existing functionality: use the Complex-feature pipeline above.

### Docs only

```
docs-updater
```

---

## Softness Clause

This skill is a **guideline**, not a hard gate. Use judgment:

- Announcing the triage block costs nothing — always do it.
- Spawning workers costs real usage (each starts with zero context and re-reads files). When in doubt about **tier**, prefer the cheaper tier and rely on the escalation rule.
- Any task with ambiguity, API/schema changes, or documented behavior: Complex, no exceptions.

---

## Worker Role Boundaries

Workers stay in role. One worker should not silently do another's job.

| Worker                | Does                                           | Does not                              |
| --------------------- | ----------------------------------------------- | -------------------------------------- |
| `task-planner`        | Clarify goals, define scope, produce plan file  | Write production code                  |
| `feature-implementer` | Implement one plan step, minimal diff           | Refactor broadly, write tests, review  |
| `researcher`          | Investigate and synthesize findings             | Write production code                  |
| `docs-updater`        | Update docs for recent changes                  | Invent undocumented behavior           |

---

## If No Worker Applies

Output:

```
Tier: <trivial | small>
Selected workers: none
Reason: <why no worker applies>
Current worker: none
```

Then proceed with a normal response. Do not skip this output silently.

---

## Execution Template

```
# Step 1 — Triage & route
Tier: ...
Selected workers: ...
Reason: ...
Current worker: ...

# Step 2 — Execute current worker
Active worker: ...
Purpose: ...
Scope: ... / Out of scope: ...

[worker output]

Worker compliance: followed <worker-name> format

# Step 3 — Advance (if pipeline continues)
Current worker: <next worker>
```

---

## Examples

**"Fix the typo in the settings page header"**

```
Tier: trivial
Selected workers: none
Reason: one file, copy-only change, no behavior risk — orchestrator edits directly
Current worker: none
```

**"Fix TypeError in the request handler"**

```
Tier: small
Selected workers: feature-implementer
Reason: cause is identifiable, fix is localized — inline mini-plan (repro + cause + fix), no plan file
Current worker: feature-implementer
```

**"Add a download button to the reports page"**

```
Tier: complex
Selected workers: task-planner → feature-implementer
Reason: feature change with behavioral impact in a well-understood area requires a plan before implementation
Current worker: task-planner
```

**"Rework the streaming flow to support multiple channels"**

```
Tier: complex
Selected workers: researcher → task-planner → feature-implementer → docs-updater
Reason: reshapes existing documented functionality — investigate current behavior and docs first, then plan; docs must be synced after
Current worker: researcher
```

**"Update the docs to match the new streaming API"**

```
Tier: small
Selected workers: docs-updater
Reason: explicit docs update request
Current worker: docs-updater
```

---

## Principle

User instructions define **what** needs to happen.
This skill defines **how** to approach it — systematically, with the right specialist framing at each step.
