# Claude Code Instructions

Shared instructions live in [AGENTS.md](AGENTS.md), imported below — it is the single source of truth. **Add new cross-harness instructions to `AGENTS.md`; add Claude-Code-specific instructions to this file.**

@AGENTS.md

## Claude Code specifics

- **Skills:** Claude Code loads project skills only from `.claude/skills/`, so each skill in `.agents/skills/` gets a **directory junction** there (junctions need no admin rights on Windows). `.claude/skills/` is gitignored so Git never traverses the junction and duplicates skill content. **Setup and sync are handled by the `project-setup` skill** — after a fresh clone or after adding/renaming/removing a skill, run `powershell -File .agents\skills\project-setup\sync-mirrors.ps1` (idempotent; also syncs the Copilot agent mirrors).
- **Instructions:** This file imports `AGENTS.md` via the `@AGENTS.md` syntax above — do not copy instruction content into this file.
