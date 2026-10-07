# Plan template

Shared by Plan Mode (`plan-mode` skill) and the `task-planner` agent. Always produce a plan with exactly these sections:

---

# Plan: [Feature Name]

**Date**: YYYY-MM-DD
**Repo**: (target repo folder name, e.g. `frontend-monorepo`; list each repo if the plan spans several)
**Branch**: (suggest a branch name, e.g. `feat/feature-name`)

## 1. Goal Restatement

Precise description of what behavior should change, what must stay unchanged, and what is explicitly out of scope.

## 2. Scope / Non-Goals

- **In scope**: ...
- **Out of scope**: ...

## 3. Assumptions

List every assumption made. Flag anything that needs confirmation before coding starts.

## 3a. Decisions Locked

List any durable choice settled during planning that will still matter after this PR closes (e.g. a named entity, a threshold, an option picked over a debated alternative, a scope cut). One line each: the choice, in plain terms. Omit this section if none. Do not log task picks (branch name, which step ships first) — only choices that constrain future code, data, or behaviour.

## 4. Files Likely to Change

| File | Change type | Description |
| --- | --- | --- |
| `src/...` | modify / create / delete | Brief description |

## 5. Step-by-Step Plan

Ordered steps. Each step must be independently verifiable. Separate production changes from tests/docs.

Step 1. **Step title** — description
Step 2. ...

Step numbering rules:

- Label every step `Step N.` (`Step 1.`, `Step 2.`, ...), never `A1.` / `1.` / `S1`. Sub-steps use `Step N.M` (e.g. `Step 4.0`).
- If the plan has several parts (e.g. Part A / Part B), number steps **per part**: each part restarts at `Step 1`.
- In prose, tables and "Depends on" columns, refer to a step in the same part as `Step N`, and to a step in another part as `Part A, Step N`. Never use bare IDs like `A4`.
- Completed steps are marked with ✅ right after the label (e.g. `Step 1. ✅ **Step title**`). Do not use `[x]` for steps. Leave steps unmarked when you write the plan; `feature-implementer` marks them done. (Definition of Done checkboxes in section 8 stay `- [ ]`.)

## 6. Risks / Edge Cases

- Risk 1 (severity: high/medium/low) — mitigation
- ...

## 7. Test Plan

- Which existing tests to run
- New unit/integration tests needed
- Failure modes to cover
- Validation commands (use whatever this project actually uses, e.g. `pnpm test` / `npm test` / `go test ./...` / `pytest`)

## 8. Definition of Done

Concrete, checkable criteria:

- [ ] ...
- [ ] typecheck/build passes (project-appropriate command)
- [ ] lint passes (project-appropriate command)
- [ ] tests pass (project-appropriate command)

## 9. Open Questions

List any unresolved questions that should be answered before or during implementation. Omit section if none.

---
