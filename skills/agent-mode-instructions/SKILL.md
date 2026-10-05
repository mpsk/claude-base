---
name: agent-mode-instructions
description: Use at the start of any non-trivial task in this repo - propose approach first, wait for confirmation, then implement. Applies to both questions and implementation requests.
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

**CRITICAL: Never edit files in the same response as a proposal or answer** — except when the user has invoked **apply without asking** for that work. Answering/proposing and implementing must otherwise be separate responses.
