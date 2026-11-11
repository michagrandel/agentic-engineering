---
name: project-setup
description: >
  Sets up and syncs the local harness mirrors of this repository's canonical
  .agents/ folder: directory junctions in .claude/skills/ for Claude Code and
  hard links in .github/agents/ for VS Code Copilot custom agents. Run after a
  fresh clone and after adding, renaming, or removing skills or agent files.
version: 1.0
---

# Project Setup — Harness Mirror Sync

**Mission:** Make the canonical sources under `.agents/` usable by each AI harness **without copying content**: skills via junctions for Claude Code, agent definitions via hard links for VS Code Copilot. `.agents/` is always the single source of truth; the mirrors are local-only and gitignored.

## What gets mirrored where

| Canonical source | Mirror | Mechanism | Consumer |
| --- | --- | --- | --- |
| `.agents/skills/<name>/` | `.claude/skills/<name>` | directory junction | Claude Code skills |
| `.agents/*.agent.md` | `.github/agents/<name>.agent.md` | hard link (same file, no drift) | VS Code Copilot agent dropdown |

No mirror is needed for Copilot skills (VS Code reads `.agents/skills/` natively) or for instructions (`AGENTS.md` / `CLAUDE.md` / `.github/copilot-instructions.md` are already wired).

## Workflow

1. **Run the sync script** from the repository root:
   ```powershell
   powershell -File .agents\skills\project-setup\sync-mirrors.ps1
   ```
   It is idempotent: creates missing mirrors, reuses correct ones, removes stale ones, and ensures `.gitignore` covers `.claude/skills/` and `.github/agents/`.
2. **Verify the result:**
   - `Test-Path .claude\skills\<skill>\SKILL.md` is `True` for every skill.
   - `.github\agents\` contains one `.agent.md` per `.agents/*.agent.md`, identical in content (hard link).
   - `git status` shows **no** files under `.claude/` or `.github/agents/`.
3. **Reload consumers:** restart the Claude Code session / reload the VS Code window so the harnesses pick up new skills and agents.

## Rules

The mirror rules live in `AGENTS.md` ("Mirror rules (always active, every session)") so they are loaded in every session, not only when this skill runs. They are binding here too — in short: never edit or commit mirrors (`.claude/skills/`, `.github/agents/`), edit only the canonical `.agents/` sources, rerun the script after renames/removals, and never fall back to copying files.
