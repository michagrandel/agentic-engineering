# Copilot Instructions (VS Code)

Shared instructions live in [AGENTS.md](../AGENTS.md) at the repository root — **read that file first**; it is the single source of truth. **Add new cross-harness instructions to `AGENTS.md`; add Copilot-specific instructions to this file.**

## VS Code Copilot specifics

- **AGENTS.md loading** is guaranteed by `"chat.useAgentsMdFile": true` in `.vscode/settings.json` (committed).
- **Skills:** Copilot local sessions discover project skills in `.agents/skills/` natively — no configuration needed. Do **not** add the deprecated `chat.agentSkillsLocations` setting.
- **Custom agents:** VS Code loads selectable chat agents from `.github/agents/`. The canonical role definitions in `.agents/*.agent.md` are mirrored there as **hard links** (same file, no drift) by the `project-setup` skill. `.github/agents/` is gitignored — after a fresh clone or after adding/renaming/removing an agent file, run `powershell -File .agents\skills\project-setup\sync-mirrors.ps1` (idempotent; also syncs the Claude skill junctions), then reload the VS Code window.
