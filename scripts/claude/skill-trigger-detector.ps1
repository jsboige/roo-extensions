<#
.SYNOPSIS
    Skill trigger detector for Claude Code UserPromptSubmit hook.
.DESCRIPTION
    Reads user prompt from stdin JSON, scans skill files for trigger keywords,
    and outputs matching skill names as conversation context.
    Designed to be used as a Claude Code UserPromptSubmit hook.

    Hook configuration (.claude/settings.json or ~/.claude/settings.json):
    {
      "hooks": {
        "UserPromptSubmit": [
          {
            "matcher": "",
            "hooks": [
              {
                "type": "command",
                "command": "pwsh -ExecutionPolicy Bypass -File scripts/claude/skill-trigger-detector.ps1",
                "timeout": 5
              }
            ]
          }
        ]
      }
    }

.NOTES
    Issue: #1854 — Skill auto-injection with triggers
    ADR: docs/harness/adr/006-skill-auto-injection-triggers.md
    Requires: PowerShell 7+ (pwsh) for utf8NoBOM encoding
#>

param()

$ErrorActionPreference = 'SilentlyContinue'

# Read JSON from stdin
$stdin = [System.Console]::In.ReadToEnd()
if (-not $stdin) { exit 0 }

$prompt = ''
try {
    $json = $stdin | ConvertFrom-Json
    $prompt = $json.prompt
} catch {
    $prompt = $stdin
}

if (-not $prompt -or $prompt.Trim().Length -eq 0) { exit 0 }

# Skip if user is explicitly invoking a slash command
if ($prompt -match '^\s*/') { exit 0 }

$promptLower = $prompt.ToLowerInvariant()

# Collect skill directories (project first, then global)
$skillDirs = @()

# Project skills
$projectDir = $env:CLAUDE_PROJECT_DIR
if (-not $projectDir) {
    $projectDir = (Get-Location).Path
}
$projectSkills = Join-Path $projectDir '.claude\skills'
if (Test-Path $projectSkills) { $skillDirs += $projectSkills }

# Global skills
$globalSkills = Join-Path $env:USERPROFILE '.claude\skills'
if (Test-Path $globalSkills) { $skillDirs += $globalSkills }

if ($skillDirs.Count -eq 0) { exit 0 }

# Track skills by name (project overrides global)
$skills = @{}

foreach ($dir in $skillDirs) {
    $skillFiles = Get-ChildItem -Path $dir -Filter 'SKILL.md' -Recurse -Depth 1
    foreach ($file in $skillFiles) {
        $content = Get-Content $file.FullName -Raw -Encoding utf8
        if (-not $content) { continue }

        # Parse YAML frontmatter (between --- markers)
        if ($content -notmatch '(?s)^---\s*\r?\n(.*?)\r?\n---') { continue }
        $frontmatter = $Matches[1]

        # Extract skill name
        $nameMatch = [regex]::Match($frontmatter, 'name:\s*[''"]?([^\s''"]+)')
        if (-not $nameMatch.Success) { continue }
        $name = $nameMatch.Groups[1].Value

        # Check for triggers keywords
        $triggersMatch = [regex]::Match($frontmatter, '(?s)triggers:\s*\r?\n\s*keywords:\s*\r?\n((?:\s+-\s+.*\r?\n?)+)')
        if (-not $triggersMatch.Success) { continue }
        $keywordsBlock = $triggersMatch.Groups[1].Value

        # Extract keywords from YAML list
        $keywords = @()
        $kwMatches = [regex]::Matches($keywordsBlock, '-\s*[''"](.+?)[''"]')
        foreach ($m in $kwMatches) {
            $keywords += $m.Groups[1].Value
        }

        # Extract priority
        $priority = 'normal'
        $prioMatch = [regex]::Match($frontmatter, 'priority:\s*(\w+)')
        if ($prioMatch.Success) {
            $priority = $prioMatch.Groups[1].Value.ToLowerInvariant()
        }

        if ($keywords.Count -gt 0) {
            $skills[$name] = @{
                Keywords = $keywords
                Priority = $priority
            }
        }
    }
}

# Match keywords against prompt
$matchesFound = @()

foreach ($entry in $skills.GetEnumerator()) {
    $skillName = $entry.Key
    $data = $entry.Value

    foreach ($kw in $data.Keywords) {
        if ($promptLower.Contains($kw.ToLowerInvariant())) {
            $matchesFound += @{
                Name     = $skillName
                Keyword  = $kw
                Priority = $data.Priority
            }
            break
        }
    }
}

# PowerShell unwraps single-element arrays to a scalar hashtable
# Force proper array context
if ($matchesFound -is [hashtable]) {
    $matchesFound = @($matchesFound)
}
if ($null -eq $matchesFound -or $matchesFound.Count -eq 0) { exit 0 }

# Sort by priority (force array to prevent pipeline unwrapping)
$prioOrder = @{ high = 0; normal = 1; low = 2 }
$sorted = @($matchesFound | Sort-Object { $prioOrder[$_.Priority] })

# Output
if ($sorted.Count -eq 1) {
    $m = $sorted[0]
    Write-Output "[SKILL-TRIGGER] User input matches skill `"$($m.Name)`" (keyword: `"$($m.Keyword)`"). Invoke /$($m.Name) for the relevant workflow."
} else {
    Write-Output "[SKILL-TRIGGER] Multiple skills matched:"
    foreach ($m in $sorted) {
        Write-Output "  - `"$($m.Name)`" (keyword: `"$($m.Keyword)`") -> /$($m.Name)"
    }
}

exit 0
