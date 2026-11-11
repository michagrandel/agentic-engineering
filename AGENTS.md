# Agent Instructions — agentic-engineering

> **This file is the single source of truth for shared AI agent instructions in this repository.** All future cross-harness instructions, conventions, and guidance for AI assistants go here. Harness-specific instructions go to the harness's own file instead: `CLAUDE.md` (Claude Code) or `.github/copilot-instructions.md` (VS Code Copilot) — those files import/point here and hold only their harness's specifics.

## What this repository is

This is a **prompt/agent-definition repository, not a code project**. It contains the definition of a four-agent framework for agentic engineering (Dev, QA, Reviewer, Release) as Markdown files with YAML frontmatter:

- `.agents/developer.agent.md`, `.agents/qa.agent.md`, `.agents/reviewer.agent.md`, `.agents/release.agent.md` — the four role definitions
- `.agents/skills/agent-session-protocol/SKILL.md` — the shared coordination protocol loaded by all four roles
- `Readme.md` — one-line project description

**There is no build, test, or lint setup** — no package manifests, no CI, no test suites. Validation of a change means: the Markdown is consistent, cross-references resolve, and the YAML frontmatter and embedded YAML schemas stay well-formed and mutually consistent across files.

## High-level architecture

The framework assigns work to four cooperating agent roles with strict separation of authority:

- **Dev** implements; never pushes/submits (Rule 40a). Git: works on a feature branch in a dedicated worktree. Perforce: prepares and *shelves* changelists, never submits.
- **QA** runs the full local verification (lint, typecheck, complete test suite, build) and produces a test report. Writes no production code. Works in its own workspace (`qa_mode: separate`) or read-only in Dev's workspace (`qa_mode: shared`); resolution order: handover object → registry → `AGENT_QA_SEPARATE_WORKSPACE` env var → tool default (Git = separate, Perforce = shared).
- **Reviewer** audits the changes against the rule core and produces a quality report with blocker/warning/hint severities and verdict `approve | rework`. Read-only, limit-neutral (no workspace/client).
- **Release** is the only role with transfer authority. It releases strictly sequentially, one task at a time, only after QA report without blockers, Reviewer verdict `approve`, artifact-integrity check, and an explicit user instruction.

Coordination between parallel instances runs through two artifacts defined in the skill:

- **`.agent/registry.yml`** (main workspace, append-only): one entry per task — task ID, workspace, `qa_mode`, file claims, status, and the Perforce client pool.
- **`.agent/current_task.yml`** (per task workspace, never committed): state file that decides at session start whether to continue an existing task or begin a new one.

Two protocol asymmetries are central and must never be blurred:

1. **File claims: Perforce hard, Git soft.** Perforce claims block other tasks (abort on foreign claim). Git claims are intent announcements only and never block; the branch diff is the authoritative claim, and on registry/branch discrepancy **the branch always wins**.
2. **Workspaces: Git unlimited, Perforce limited.** Git worktrees need no limit check. Perforce clients are counted against `AGENT_PERFORCE_CLIENT_LIMIT`; exhausted → recycle a `recyclable` client or abort; **agents never delete clients** (user decision), they only mark `recyclable`.

Handover artifacts differ by VCS: **Git = the feature branch** (never pushed by Dev), **Perforce = shelved changelists per submit unit** (the open changelist stays in the Dev client; Release submits the changelist, never the shelf).

## Key conventions

- **Rule core references:** Agent and skill files cite rules by number (e.g. "Rule 40a", "rules 1–43") from an external document "Agent Rules: Common Core" that is **not part of this repository**. Never renumber, invent, or paraphrase rule numbers; keep existing citations intact.
- **Skill section references:** Cross-references to the shared protocol use the form "Skill §N" (e.g. "Skill §3" for file claims). If you restructure `SKILL.md`, update every "§N" reference in all four agent files.
- **Single source of truth (protocol):** The skill holds the shared protocol (registry format, state file, claims, handover rules, workspace mode, limits, task-ID convention, orchestration). Agent files contain only role-specific mission, workflow, handover/report schema, and prohibitions — **do not duplicate protocol content into agent files**.
- **YAML schemas must stay synchronized:** The Dev handover object, QA test report, Reviewer quality report, and Release release report share field names and semantics (e.g. `task_id`, `qa_mode`, shelf/changelist fields, `blocker|warning|hint` severities, status enum `in_progress | awaiting_review | awaiting_release | done`). When changing one schema, check the others and the skill's registry example for consistency.
- **Frontmatter format:** Every agent file has `name`, `role`, `uses-skills: [agent-session-protocol]`, `description`, `version`. The skill file has `name`, `description`, `version`, `applies-to: [dev, qa, reviewer, release]`. Preserve this structure when editing.
- **Language policy (a rule of the framework itself):** All generated code — comments, docstrings, identifiers, commit/changelist descriptions, test names — is always English, regardless of prompt language. Reports and user-facing messages may use the user's language. When editing these definitions, keep their own prose consistent with the existing style (English headings, precise imperative wording, bolded prohibitions).
- **Commit/submit messages (binding for every agent, every VCS):** Every Git commit message and every Perforce changelist/submit description is generated with the **`commit-message` skill** (`.agents/skills/commit-message/`) — never written freehand, regardless of which role creates the commit or changelist. The skill is strictly read-only (it only drafts the message); committing/submitting stays with the role that owns that step.
- **Structure of each agent file:** Mission paragraph → Startup/Workflow sections (Git and Perforce separated where relevant) → handover/report YAML schema → "Explicit Prohibitions" list (optionally followed by a "*Not* prohibited" clarification). Follow this layout for edits.

## Customization file locations (shared, cross-harness)

- **Skills live in `.agents/skills/<skill-name>/SKILL.md`** (Agent Skills open standard) — the one physical copy used by every harness. **New skills go there**, each in its own folder with a `SKILL.md` (frontmatter: `name`, `description`; keep the existing `version` / `applies-to` fields). How each harness is wired to this location is documented in its own instructions file.
- **Agent role definitions live in `.agents/*.agent.md`.**
- **Harness mirrors are managed by the `project-setup` skill** (`.agents/skills/project-setup/`): it syncs `.agents/skills/` → `.claude/skills/` (junctions, Claude Code) and `.agents/*.agent.md` → `.github/agents/` (hard links, VS Code Copilot). Both mirror locations are gitignored and local-only. Run it after a fresh clone and after adding/renaming/removing skills or agents.

### Mirror rules (always active, every session)

- **Never edit a mirror file** (`.claude/skills/...`, `.github/agents/...`) — edit the canonical file in `.agents/`; hard links and junctions make the change visible on both sides instantly.
- **Never commit anything under `.claude/skills/` or `.github/agents/`** — mirrors are machine-local; a fresh clone recreates them via the `project-setup` skill.
- When a skill or agent is **renamed or removed** in `.agents/`, rerun `powershell -File .agents\skills\project-setup\sync-mirrors.ps1` so stale mirrors are deleted.
- If junction creation fails (unlikely — no admin needed), report it; **do not fall back to copying files**.

Harness-specific setup: see `CLAUDE.md` (Claude Code) and `.github/copilot-instructions.md` (VS Code Copilot).
