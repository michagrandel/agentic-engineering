#Requires -Version 5.1
<#
.SYNOPSIS
  Syncs local harness mirrors with the canonical .agents/ folder.
.DESCRIPTION
  - Claude Code skills:     directory junctions .claude/skills/<name>  -> .agents/skills/<name>
  - VS Code Copilot agents: hard links         .github/agents/<file>   -> .agents/<file>
  Idempotent: creates missing mirrors, reuses correct ones, removes stale ones,
  and ensures .gitignore covers the mirror directories. Run from anywhere;
  the repository root is derived from the script location.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$canonicalSkills = Join-Path $repoRoot '.agents\skills'
$canonicalAgents = Join-Path $repoRoot '.agents'
$claudeSkills = Join-Path $repoRoot '.claude\skills'
$copilotAgents = Join-Path $repoRoot '.github\agents'
$gitignore = Join-Path $repoRoot '.gitignore'

$script:created = [System.Collections.Generic.List[string]]::new()
$script:reused  = [System.Collections.Generic.List[string]]::new()
$script:removed = [System.Collections.Generic.List[string]]::new()

function Sync-SkillJunctions {
    New-Item -ItemType Directory -Force $claudeSkills | Out-Null
    $skills = @(Get-ChildItem $canonicalSkills -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') })

    foreach ($skill in $skills) {
        $link = Join-Path $claudeSkills $skill.Name
        if (Test-Path $link) {
            $item = Get-Item $link -Force
            if ($item.LinkType -and @($item.Target) -contains $skill.FullName) {
                $script:reused.Add(".claude/skills/$($skill.Name)")
                continue
            }
            Remove-Item $link -Recurse -Force
        }
        cmd /c mklink /J "`"$link`"" "`"$($skill.FullName)`"" | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "mklink failed for $($skill.Name)" }
        $script:created.Add(".claude/skills/$($skill.Name)")
    }

    Get-ChildItem $claudeSkills -Force |
        Where-Object { $_.Name -notin $skills.Name } |
        ForEach-Object {
            if ($_.LinkType) {
                Remove-Item $_.FullName -Recurse -Force
                $script:removed.Add(".claude/skills/$($_.Name)")
            } else {
                Write-Warning ".claude/skills/$($_.Name) is not a link and has no canonical counterpart - left untouched, review manually."
            }
        }
}

function Sync-AgentHardlinks {
    New-Item -ItemType Directory -Force $copilotAgents | Out-Null
    $agents = @(Get-ChildItem $canonicalAgents -Filter '*.agent.md' -File)

    foreach ($agent in $agents) {
        $link = Join-Path $copilotAgents $agent.Name
        if (Test-Path $link) {
            $same = (Get-FileHash $link).Hash -eq (Get-FileHash $agent.FullName).Hash
            if ($same) {
                $script:reused.Add(".github/agents/$($agent.Name)")
                continue
            }
            Remove-Item $link -Force
        }
        New-Item -ItemType HardLink -Path $link -Target $agent.FullName | Out-Null
        $script:created.Add(".github/agents/$($agent.Name)")
    }

    Get-ChildItem $copilotAgents -Filter '*.agent.md' -File -Force |
        Where-Object { $_.Name -notin $agents.Name } |
        ForEach-Object {
            Remove-Item $_.FullName -Force
            $script:removed.Add(".github/agents/$($_.Name)")
        }
}

function Ensure-Gitignore {
    $entries = @('.claude/skills/', '.github/agents/')
    $existing = if (Test-Path $gitignore) { Get-Content $gitignore } else { @() }
    $missing = @($entries | Where-Object { $_ -notin $existing })
    if ($missing.Count -gt 0) {
        $block = @('', '# Harness mirrors created by .agents/skills/project-setup - local only, never commit') + $missing
        Add-Content $gitignore $block
        $script:created.Add(".gitignore entries: $($missing -join ', ')")
    }
}

Sync-SkillJunctions
Sync-AgentHardlinks
Ensure-Gitignore

Write-Host ''
Write-Host 'Mirror sync complete.'
Write-Host "  created: $($script:created.Count)"
$script:created | ForEach-Object { Write-Host "    + $_" }
Write-Host "  reused:  $($script:reused.Count)"
Write-Host "  removed: $($script:removed.Count)"
$script:removed | ForEach-Object { Write-Host "    - $_" }
