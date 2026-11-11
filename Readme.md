# Agentic engineering workflow

Collection of agents and skills to support agentic engineering: a four-agent framework with strict separation of authority, usable from both Claude Code and VS Code Copilot.

## The four-agent framework

Work is assigned to four cooperating roles (the exact end-to-end workflow is documented in [docs/agentic-workflow.md](docs/agentic-workflow.md)):

- **Dev** implements tasks and prepares all changes locally — never pushes or submits. Git: feature branch in a dedicated worktree. Perforce: prepared and *shelved* changelists.
- **QA** runs the full local verification (lint, typecheck, complete test suite, build) and produces a test report — writes no production code.
- **Reviewer** audits the changes against the rule core and produces a quality report (verdict `approve | rework`) — read-only.
- **Release** is the only role with transfer authority. It releases strictly sequentially, one task at a time, only after a clean QA report, Reviewer approval, artifact-integrity check, and an explicit user instruction.

Parallel instances coordinate through a shared registry (`.agent/registry.yml`) and a per-workspace state file (`.agent/current_task.yml`). File claims are hard for Perforce (blocking) and soft for Git (intent only — the branch diff wins). Git worktrees are unlimited; Perforce clients are limit-guarded with recycling.

## Repository layout

- `.agents/developer.agent.md`, `.agents/qa.agent.md`, `.agents/reviewer.agent.md`, `.agents/release.agent.md` — the four role definitions
- `.agents/skills/agent-session-protocol/` — shared coordination protocol loaded by all roles
- `.agents/skills/project-setup/` — harness mirror sync (see below)
- `.agents/skills/commit-message/` — mandated for all Git commit messages and Perforce changelist descriptions
- `AGENTS.md` — single source of truth for shared AI instructions; `CLAUDE.md` (Claude Code) and `.github/copilot-instructions.md` (VS Code Copilot) hold only harness-specifics and point there

## Setup

After a fresh clone, mirror the canonical `.agents/` folder into the harness locations (junctions for Claude Code skills, hard links for VS Code Copilot agents):

```powershell
powershell -File .agents\skills\project-setup\sync-mirrors.ps1
```

The script is idempotent; rerun it after adding, renaming, or removing skills or agents. Mirrors are gitignored and machine-local. Afterwards, restart Claude Code / reload the VS Code window.

## Conventions

- All generated code, comments, identifiers, commit/changelist descriptions, and test names are always in English.
- Every commit message and changelist description is generated with the `commit-message` skill.
- Text files use LF line endings (`.gitattributes`); PowerShell/batch scripts keep CRLF.