# Agent Workflow

This document describes the exact workflow the four agents (Dev, QA, Reviewer, Release) follow for a single task, from session start to release. It summarizes the binding definitions in `.agents/skills/agent-session-protocol/SKILL.md` and the four role files under `.agents/*.agent.md` — in case of conflict, those files win.

## Pipeline overview

```
User ──▶ Dev ──handover──▶ QA ──test report──▶ Reviewer ──quality report──▶ Release ──▶ remote/depot
           ▲                   │ findings (blockers)                              ▲
           └─────── rework ────┴──────────── verdict: rework ─────────────────────┘
```

- **Dev** implements, never transfers (Rule 40a).
- **QA** verifies locally, writes no production code.
- **Reviewer** audits code against the rule core, read-only.
- **Release** is the only role with transfer authority and works strictly sequentially — one task at a time.

Every step is tied to a globally unique **task ID** (e.g. `rabatt-042`; a Jira ticket number when available), which appears in the registry, workspace name, branch name, changelist/shelf descriptions, state file, and all reports.

## Phase 0 — Session start and task assignment

Applies to every agent instance, in this order:

1. **Read the state file** `.agent/current_task.yml` in the workspace.
   - `in_progress` / `awaiting_*` → continue the existing task. No new branch, no new registry entry.
   - `done` or missing → begin a new task.
   - If the prompt clearly addresses a new topic while a task is active → ask the user ("Continue or finish active task X?").
2. **Consistency check:** reconcile the state file with the actual workspace state (current branch / open changelists; for Perforce also shelf ≡ changelist). Discrepancy → **stop and ask the user, never guess**.
3. **Acquire a workspace** (one task = one dedicated workspace; two Dev instances never share one):
   - *Git:* worktree without any limit check: `git worktree add ../project-<task-id> -b feature/<concern>-<task-id> develop`.
   - *Perforce:* run the client-limit protocol — count `active` clients in the registry pool against `AGENT_PERFORCE_CLIENT_LIMIT`. Free/unlimited → create client. Full but a `recyclable` client exists → recycle it (verify no open files, sync to latest revision). Otherwise → **abort with a limit message**. Agents never delete clients.
4. **Register the task** in `.agent/registry.yml` (append-only; every instance writes only its own entry): task ID, workspace, `vcs`, `qa_mode`, branch/changelists/shelves, claims, status.
5. **Fix the QA mode** (`shared | separate`) per the resolution order — handover object → registry → `AGENT_QA_SEPARATE_WORKSPACE` env var → tool default (Git = `separate`, Perforce = `shared`). It is fixed in the registry at task start.
6. **Register file claims** (`files_claimed`):
   - *Perforce (hard):* a file claimed by another active task → **abort before opening anything**.
   - *Git (soft):* foreign claims cause no abort, only a warning in the own report.
7. **Sync check** (Rule 40b): Git — `fetch` on `origin/develop`; missing commits → abort with a message, no autonomous pull/merge/rebase. Perforce — verify the latest revision of all affected files locally.

## Phase 1 — Development (Dev)

### Git

1. Ensure `origin/develop` exists (create from `origin/main` and push, once, if missing).
2. All work happens exclusively on the feature branch — never on `develop` or `main`; the branch is never recreated mid-task.
3. Commit after each green cycle (Rule 36), one concern per commit (37), every commit leaves the system green (38). **Every commit message is generated with the `commit-message` skill** — English, task-ID traceable (Rule 39).
4. If scope expands: update the Git claims in the registry (soft; the branch remains the authoritative claim).

### Perforce

1. Collision check: any needed file open in any changelist (own or foreign) or hard-claimed in the registry → **abort with a message**.
2. Check out files per planned **submit unit**, each in its own purpose-named changelist (the default changelist as a collection bin is forbidden). **Descriptions are generated with the `commit-message` skill** — English, referencing the task ID.
3. Prepare one submit unit at a time; start the next only after the previous one was submitted.

## Phase 2 — Handover to QA (Dev)

- **Git:** the handover artifact is the **feature branch** — no push. All commits live locally on the branch.
- **Perforce:** the handover artifact is the **shelved changelist per submit unit**. Every prepared changelist is shelved before handover; any later change to a shelved file → re-shelve (a stale shelf means rejection). The open changelist stays in the Dev client for the later release submit.
- Dev sets state file and registry to `awaiting_review` — **this starts the QA lock: Dev does not touch the files again until feedback arrives.**
- Dev produces the handover object (task ID, workspace, `qa_mode`, branch or changelist/shelf numbers, submit units, test count, notes).

## Phase 3 — Local verification (QA)

1. **Resolve `qa_mode`** (handover object → registry → env var → default). Contradictory values → abort with a message.
2. **Materialize the artifact:**
   - *Git, separate (default):* own worktree, check out the feature branch.
   - *Git, shared:* test directly in the Dev worktree (prerequisite: status `awaiting_review`).
   - *Perforce, shared (default):* the open files in the Dev client are the test subject — test directly; never unshelve/shelve/revert anything. Shelf numbers serve only to verify shelf ≡ open files.
   - *Perforce, separate:* own client per the limit protocol; sync, unshelve the shelf numbers, test, then revert everything.
3. **Full local execution:** linting, static type checking, complete test suite (unit + integration), build — never only the new tests. Rerun to prove determinism; for bug fixes, a reproduction test is required.
4. **No fixes:** defects flow back to Dev as findings; QA changes nothing.
5. **Cleanup:** separate mode — empty the workspace (Perforce: revert + mark client `recyclable`; Git: optionally remove the worktree). Shared mode — leave the workspace byte-identical.
6. Produce the **test report** (build/lint/typecheck/tests/determinism/history check, findings with `blocker|warning|hint`) for Reviewer and user. Blockers → rework loop back to Dev.

## Phase 4 — Quality audit (Reviewer)

1. **Assignment check:** task ID, workspace, QA mode, and artifact must match between registry and handover object; artifact unchanged since report creation (Git: no new commits; Perforce: shelf ≡ stated state). Divergence → reject back to QA/Dev.
2. **Audit basis, read-only:** Git — branch diff against the base. Perforce — shelf diffs (no unshelving, no client; the Reviewer stays limit-neutral).
3. **Rule core as checklist** (chapters: Design 1–8, Code Quality 9–18, Documentation 19–21, Typing 22–25, Tests 26–28, API/Data 32–34, Process 35–40), every changed file.
4. **Severities:** `blocker` (must not be released), `warning` (tolerable risk), `hint` (improvement potential).
5. **Attest positively:** the report lists the rule areas checked and found compliant — a report without proof of checking is invalid.
6. Produce the **quality report** with verdict `approve | rework` (rework if at least one blocker) for Release and user.

## Phase 5 — Release (Release Agent)

All preconditions must hold, otherwise abort with a report:

1. Test report without blockers for exactly this task ID.
2. Quality report with verdict `approve`.
3. Artifact integrity: Git — branch commits unchanged since report creation; Perforce — shelf content ≡ open changelist content, every submit unit present as shelf and open changelist.
4. Conflict check:
   - *Git:* intersect the **freshly computed** branch-diff file list with those of all other active Git tasks (branch diffs, never registry claims — the branch always wins). Overlap → no abort, but inform the user (tasks, files, proposed integration order); the **user decides**.
   - *Perforce:* files open only in the expected changelists, no newer depot revisions, no foreign hard claim — otherwise abort.
5. Sync check again (Rule 40b): Git — `fetch`; branch base behind remote → abort, no autonomous merge/rebase.
6. **Explicit user instruction** to transfer this task.

Then:

- **Git:** push the feature branch (no merge into `develop` without a separate explicit user instruction). The overlap result goes into the release report even when empty.
- **Perforce:** submit the **open changelists — never the shelf** — in the planned submit-unit order. A failed submit → abort with a report, no forced resolve. Afterwards mark the Dev client `recyclable` (deletion and shelf cleanup only on user instruction).
- **Sequencing:** the next parallel task starts only after this one completes; known overlaps are flagged in the report.
- Produce the **release report** and set the registry to `done`.

## Task end

- `status: done` in state file and registry — set only as part of the formal handover/release.
- Perforce clients: `active → recyclable → (deletion by the user only)`.
- Git worktrees may be removed by agents after completion (optional, lossless — the branch remains).

## Always-on rules

- **Language policy:** all generated code — comments, docstrings, identifiers, commit/changelist descriptions, test names — is always English; reports may use the user's language.
- **Commit messages:** every Git commit message and Perforce changelist/submit description is generated with the `commit-message` skill, regardless of role.
- **Never guess on inconsistency:** state-file/workspace or shelf/changelist discrepancies always escalate to the user.
