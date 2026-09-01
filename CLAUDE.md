
## Project logbook workflow

This repository explicitly uses the `TODO.md` to `avances.md` logbook workflow. The absence of these files in a fresh clone does not disable the workflow.

- At the beginning of the first planned project task, create `TODO.md` and `avances.md` if either file is missing.
- Write both files in English.
- `TODO.md` is the work queue. It must contain pending tasks only.
- Add planned work to `TODO.md` before implementation begins.
- Do not leave completed tasks, completion checkboxes, progress history, or verification reports in `TODO.md`.
- `avances.md` is an append-only project log. Never modify, reorder, or delete an existing entry.
- Each new `avances.md` entry must identify the completed task, summarize what was implemented, and record exactly how it was verified.
- Remove a task from `TODO.md` only after its implementation is complete and its verification has succeeded.
- In the same change that removes the completed task, append its completion and verification record to `avances.md`.
- If a task remains incomplete or verification fails, keep it in `TODO.md` and do not record it as completed.

When this workflow conflicts with an explicit user instruction for a specific task, follow the user's instruction and note the exception clearly.

## 5. Mandatory Git workflow

Never modify files directly on `main` or `master`.

- Check the active branch and working tree before the first modification.
- If the active branch is `main` or `master`, create a short-lived branch before editing.
- Use `feature/<descriptive-name>` for features and documentation additions.
- Use `fix/<descriptive-name>` for corrections.
- Follow a more specific repository convention if one is introduced later.
- If already on an appropriate work branch, continue on it.
- Never discard, hide, overwrite, or silently include existing user changes in order to create a branch.
- Keep commits focused and use concise English commit messages.
- Do not push, create pull requests, merge, tag, or publish releases unless the user requests that external action.

## 6. Safety and privacy

- Treat the repository as public from the first line committed.
- Never commit API keys, access tokens, passwords, session cookies, private keys, private prompts, terminal transcripts, or raw environment dumps.
- Keep runtime databases, sockets, logs, terminal captures, and machine-specific configuration outside version-controlled project content by default.
- Do not introduce telemetry or network communication without an explicit product decision and user authorization.
- Treat child process output and project content as potentially sensitive.
- Do not describe Relayterm as a security sandbox. Agent processes normally inherit the launching user's operating-system permissions.
- Validate paths and external command arguments. Do not construct shell commands through unsafe string interpolation.
- Prefer reversible operations. Ask before deleting or overwriting material data.

## 7. Change discipline

- Make the smallest coherent change that fully satisfies the task.
- Preserve separation between domain, application, protocol, persistence, PTY, Git, daemon, and client layers.
- Do not add provider-specific assumptions to the neutral domain model.
- Do not implement items listed as MVP exclusions unless the specification is deliberately revised.
- Add or update tests in proportion to behavioral risk.
- Update public documentation when user-facing behavior, architecture, protocol, or persistence changes.
- Record significant architectural decisions in concise architecture decision records when that structure is introduced.
