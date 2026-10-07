---
name: agent-mode-instructions
description: Use at the start of any non-trivial task in this repo and before running scripts or executing code or commands, including trivial tasks. Applies to questions and implementation requests.
---

# Agent Mode Instructions

## Core workflow

- **Propose solutions first** – present 1-3 options or approaches for the user to consider.
- **Explain trade-offs** – briefly outline pros/cons where relevant.
- **Wait for a decision** – do not apply changes until the user chooses an approach.
- **Apply only after confirmation** – implement the selected solution after the user has decided.
- Keep proposed solutions clear, concise, and actionable.

## Questions vs Implementation

**When the user asks a question** (e.g. "Is it possible to...?", "How does X work?"):
Answer fully — explain, analyze, reason through it. Do not write or modify any files. If implementation follows naturally, wait for the user to explicitly request it.

**When the user asks for implementation** (e.g. "Add...", "Fix...", "Refactor..."):
Follow the workflow above: propose first, explain trade-offs, wait for confirmation, then implement — unless **apply without asking** applies (below).

**Apply without asking** — skip the separate proposal turn and implement in the same response when the user clearly opts out of confirmation, for example:

- Says **apply without asking**, **just do it**, **don't wait for confirmation**, or **skip propose** (for this task or this message)
- Gives a direct imperative **and** explicitly ties it to immediate apply (e.g. "make X — apply without asking")

Still require explicit user request before **git commit**, **git push**, or **opening a PR** unless they ask for those in the same message.

## Risky execution

- **Inspect before execution** — read unfamiliar scripts or code and assess their effects, including commands they invoke. If the effects remain uncertain, treat execution as risky.
- **Confirm before risky execution** — obtain explicit user confirmation before executing scripts, code, or commands that may delete or overwrite user data, modify infrastructure or production systems, run database migrations, publish artifacts, or expose secrets. This applies even to trivial tasks.
- **Make the action reviewable** — explain the command or script, its target and environment, expected effects, and material risks before requesting confirmation. Wait for the user's response before execution.
- **Require specific authorization** — general instructions such as **apply without asking**, **just do it**, or approval of an implementation plan do not waive this requirement. Existing explicit authorization is sufficient only when it covers the same risky action, target, and effects; obtain new confirmation if those change.
- **Continue safe checks** — read-only inspection and routine local checks with understood, reversible effects may proceed without separate execution confirmation. Prefer a verified dry run when available; inspect it first rather than assuming a `--dry-run` flag is safe.

**CRITICAL: Never edit files in the same response as a proposal or answer** — except when the user has invoked **apply without asking** for that work. Answering/proposing and implementing must otherwise be separate responses.
