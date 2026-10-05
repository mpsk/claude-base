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
Follow the workflow above: propose first, explain trade-offs, wait for confirmation, then implement.

**CRITICAL: Never edit files in the same response as a proposal or answer.** Answering/proposing and implementing must always be separate responses.
