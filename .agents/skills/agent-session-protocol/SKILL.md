---
name: agent-session-protocol
description: >
  Shared session, registry, and coordination protocol for all agent roles (Dev, QA,
  Reviewer, Release) in the four-agent framework. Loaded by all agents. Contains:
  registry format, state file, two-tier file claims, handover artifact rules, QA
  workspace mode, and the Perforce client limit. References the rule core
  ("Agent Rules: Common Core"; rule numbers refer to it).
version: 1.0
applies-to: [dev, qa, reviewer, release]
---

# Shared Session and Registry Protocol

## Principles

- The rule core is binding for **all four roles**: Dev follows it, QA and Reviewer audit against it, Release presumes its fulfillment.
- **Parallel instances:** Multiple Dev/QA instances may run in parallel — but only under the task isolation protocol (Rule 40c): **one task = one dedicated workspace** (Git worktree or Perforce client). Two Dev instances **never** share a workspace. Coordination runs exclusively through the shared registry.
- **Git worktrees are unlimited by design** — workspace limits apply exclusively to Perforce.

## Language Policy (binding for all roles)

Independent of the language used in the user's prompt or conversation, **all generated code — including comments, docstrings, identifiers, commit/changelist descriptions, and test names — must always be written in English.** This applies to every role and every VCS. Reports, findings, and messages to the user may be written in the user's language; code and everything embedded in code is always English.

## 1. Registry (Coordination Hub, in the Main Workspace)

A file `.agent/registry.yml` in the main workspace is the **single coordination instance** for parallel tasks. **Append-only and instance-safe:** every instance reads the entire registry and writes only its own task entry.

```yaml
tasks:
  - id: rabatt-042                      # globally unique task id - if known, use a Jira Ticket number
    workspace: "../projekt-rabatt-042"  # git worktree path or perforce client name
    qa_workspace: "../qa-rabatt-042"   # only if qa_mode: separate
    vcs: git
    qa_mode: separate                   # shared | separate — fixed per task
    branch: feature/rabatt-berechnung-042
    changelists: []                     # perforce: open CLs (submit units)
    shelves: []                          # perforce: shelf CLs per submit unit
    files_claimed: [src/preis.py, src/rabatt.py]
                                        # perforce: HARD — blocks other instances
                                        # git: SOFT — intent announcement only, never blocking
    status: in_progress                 # in_progress | awaiting_review | awaiting_release | done
    dev_agent: dev-instance-042
    qa_agent: qa-instance-042
    updated: "<timestamp>"

clients:                                 # perforce client pool — limit-relevant
  - name: "user-rabatt-042"
    task_id: rabatt-042                  # use task id from task list
    state: active                        # active | recyclable
    role: dev                            # dev | qa
    qa_separate: false
  - name: "user-alt-039"
    task_id: alt-039                     # previous task, already done
    state: recyclable
    role: dev
    qa_separate: false
# Git worktrees are NOT managed in the pool — they are unlimited.
```

## 2. State File (per Workspace, Across Sessions)

Every task workspace contains `.agent/current_task.yml` (not committed; in `.gitignore` or, for Perforce, outside the depot). It is the source of truth for "is a task still running?" — a feature branch applies **per task**, not per prompt:

```yaml
task: "implement discount calculation"
task_id: rabatt-042
vcs: git
qa_mode: separate
active_branch: feature/rabatt-berechnung-042
submit_units_planned: 4
submit_units_done: 2
status: in_progress     # in_progress | awaiting_review | awaiting_release | done
```

**Protocol for all agent instances:**

- **Session start:** Read the state file. Shows `in_progress` (or `awaiting_*`) → continue the existing task, **no new branch, no new registry entry**. Shows `done` or does not exist → begin a new task.
- **Consistency check:** Reconcile the state file with the actual workspace state (current branch / open changelists; for Perforce additionally: compare shelf content with changelist content). Discrepancy → **stop and ask the user, never guess**.
- **Topic change:** If the prompt clearly addresses a new topic while the file shows `in_progress` → briefly ask ("Continue or finish active task X?") instead of continuing automatically.
- **Task end:** Set `status` to `done` only after formal handover (to QA or Release); update the registry entry in parallel. Setting `done` is part of the handover object.

## 3. File Claims — Two-Tier: Perforce Hard, Git Soft

**Principle: Where the tool itself makes the conflict state visible, the registry may only inform. Where it remains invisible, the registry must reliably block.**

### Perforce — Hard Blocking

- Pending changes are invisible on the depot side until submitted; `p4 opened` across foreign clients fails in practice due to protections. The registry is therefore the **only coordination instance** for open files.
- Before any agent touches a Perforce file: **read the registry.** Claimed by another active task (`status != done`) → **abort with a message** or ask the user — never edit a Perforce file claimed by a foreign task (Rule 40c).
- Enter your own claims at task start and update them whenever scope expands. Perforce claims may only ever be **too generous** (claiming more than ultimately changed), never too narrow. A stale Perforce claim is a coordination error.

### Git — Soft, Non-Blocking

- Worktrees and feature branches fully isolate during development; the conflict arises only at integration — where the **Release Agent is the sequencer**, computing overlap mechanically from fresh branch diffs.
- **The branch itself is the claim** (`git diff --name-only develop..<branch>` yields the authoritative file list at any time). Registry claims are only an **intent announcement** for other instances.
- **Git claims never block.** No agent aborts because of a foreign Git claim; overlap instead produces a **warning** ("Task-042 announced preis.py — coordinate merge order later").
- **Trust rule:** On discrepancy between registry claim and branch reality, **the branch always wins**. In Git, the registry is advance notice only, never a decision basis.

### Both Tools

Claims are paths relative to the depot/repo root; wildcards allowed for directories (`src/rabatt/**`) to keep claim maintenance affordable.

## 4. Handover Artifact Rules

- **Git:** The handover artifact is the **feature branch**. It is the only valid reference for QA, Reviewer, and Release — commits not on the branch do not belong to the handover.
- **Perforce:** The handover artifact is the **shelved changelist per submit unit**:
  - Dev **shelves every prepared changelist before handover** and keeps the shelf in sync: any subsequent change to a shelved file → **re-shelve**, otherwise the shelf is stale.
  - QA, Reviewer, and Release verify at the start that shelf revisions match the states stated by Dev. **Stale shelf → rejection back to Dev.**
  - The open changelist remains in the Dev workspace (for the later release submit); the shelf is the readable handover copy, **never the submit target**.

## 5. Workspace Mode and Perforce Client Limit

Two environment variables control workspace management and consumption.

### `AGENT_QA_SEPARATE_WORKSPACE` — QA Workspace Mode (Git and Perforce)

- **`1` (separate):** QA gets its own workspace for the task (Git: own worktree; Perforce: own client `qa-<task-id>`). QA syncs to latest revision, unshelves the shelf numbers, tests, and afterwards reverts everything. Dev and QA never operate on the same file set simultaneously.
- **`0` (shared):** QA works **in the workspace of the associated Dev Agent**. Prerequisite: status `awaiting_review` (the state file is the lock — Dev does not touch the files). QA **changes and reverts nothing**, leaves the workspace byte-identical.
- **Unset → tool-specific default:** Git = `1` (separate, because worktrees are free); Perforce = `0` (shared, because every client counts against the limit).
- **Resolution order (always in this order):** (1) handover object `qa_mode`, (2) registry entry `qa_mode`, (3) environment variable, (4) tool-specific default. The value is **fixed** in the registry entry at task start — later changes take effect only on the next task.
- Invalid value (explicitly set but not `0`/`1`) → **abort with a message** (report the misconfiguration instead of interpreting it). Unset is not a misconfiguration.

### `AGENT_PERFORCE_CLIENT_LIMIT` — Perforce Client Limit (Perforce only)

- Limits the **total number of simultaneously existing Perforce clients** (Dev and QA clients across all active Perforce tasks). Unset or `<= 0` → unlimited.
- **Limit protocol before every Perforce client creation:**
  1. Count active clients (`state: active`) in the `clients` pool (QA separate clients count).
  2. Count < limit (or unlimited) → client may be created.
  3. Otherwise: a `recyclable` client exists → **recycle it** (see below).
  4. Neither free capacity nor a recyclable client → **abort with a message** (limit X, occupied Y; options: postpone task, release a completed task, raise the limit). **Never silently exceed the limit.**
- **Recycling:** After task completion (`done` + release finished) the client is set to `recyclable`. Before reuse: verify no open files (`p4 opened` empty; revert leftovers only after approval by the previous task owner), sync to latest revision, record the recycling in the pool.
- **Release:** Deleting a client is a **user decision** — agents only mark `recyclable`. The limit is thus safe upward only; no agent deletes clients to create space. **Git worktrees**, by contrast, agents may clean up themselves after task completion (optional, lossless — the branch remains).
- **Rule of thumb:** With limit N, at most `floor(N/2)` Perforce tasks can run in separate mode, or N tasks in shared mode, in parallel. **Git tasks are unaffected by any of these formulas** — only hardware limits them.

## 6. Task-ID Convention (All Roles)

Every task receives a globally unique **task ID** at start (e.g. `rabatt-042`), appearing consistently in: registry entry, workspace name, branch name (`feature/<concern>-<task-id>`), changelist and shelf descriptions, state file, handover object, and all reports. This makes the assignment **machine-checkable** at every level — essential for parallel operation.

## 7. Orchestration Overview

```
User ──tasks──▶ Registry (.agent/registry.yml, append-only)
  │  tasks:   one entry per task (task-id, workspace, qa_mode, claims)
  │  claims:  PERFORCE hard (blocking) · GIT soft (intent-only)
  │  clients: PERFORCE client pool only, limit-guarded (AGENT_PERFORCE_CLIENT_LIMIT)
  │           git worktrees: NOT in the pool — always unlimited
  │  qa_mode: AGENT_QA_SEPARATE_WORKSPACE (0=shared, 1=separate)
  │           unset → git=1/separate, perforce=0/shared
  ▼
  task-a (git):      [dev-a ⇄ qa-a → reviewer-a → release]  (free, default separate;
                     overlaps checked at release time from branch diffs)
  task-b (perforce): [dev-b ⇄ qa-b → reviewer-b ⏳]         (within client limit,
                     default shared; claims block hard)

  Release Agent: sequencer — pushes branches / submits changelists (never shelves),
                 one task at a time; computes GIT overlaps freshly from branch diffs
                 (registry claims = advisory only).
  Reviewer: limit-neutral (read-only diffs only).
  Perforce client pool: active → recyclable → (deletion by the user only).
```

## 8. Enforcement (Recommendation)

The role separation is textual (this file) and should additionally be **enforced technically**: Dev/QA/Reviewer agents without remote write access or submit protections; Release Agent with dedicated credentials. Prompt rules ask — **permissions enforce.** The Perforce client limit can be doubly secured: environment variable per agent process *and* a pre-check script that blocks client creation once the limit is reached. No technical enforcement is needed on the Git side — the limit deliberately does not exist there; conflict checking lies mechanically with the Release Agent.