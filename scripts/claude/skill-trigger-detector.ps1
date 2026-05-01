<#
.SYNOPSIS
    Skill trigger detector for Claude Code UserPromptSubmit hook.
.DESCRIPTION
    Reads user prompt from stdin JSON, scans skill files for trigger keywords,
    and outputs matching skill names as conversation context.
    Supports 4 trigger types: keywords, exact, patterns (regex), context.

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

.TRIGGER_TYPES
    keywords  - Case-insensitive substring match (default, broadest)
    exact     - Case-insensitive whole-word match (precise, no partials)
    patterns  - Regex match (flexible, for complex patterns)
    context   - Session-context match (executor, idle, coordinator)

.NOTES
    Issue: #1854 — Skill auto-injection with triggers
    ADR: docs/harness/adr/006-skill-auto-injection-triggers.md
    Requires: PowerShell 7+ (pwsh) for utf8NoBOM encoding
#>

param()

$ErrorActionPreference = 'Stop'

function Get-ContextFlags {
    <# Detect current session context from environment #>
    $flags = @()
    if ($env:ROOSYNC_MACHINE_ID) { $flags += 'executor' }
    if ($env:CLAUDE_CODE_SESSION_START) { $flags += 'interactive' }
    # Check if running from a scheduler (no TTY = scheduled)
    try {
        $null = [Console]::IsOutputRedirected
        if ([Console]::IsOutputRedirected) { $flags += 'scheduled' }
    } catch { }
    return $flags
}

function ConvertFrom-YamlList {
    <# Extract items from a YAML list block (e.g., "- "item1"\n- "item2"") #>
    param([string]$Block)
    $items = @()
    $yamlMatches = [regex]::Matches($Block, '-\s*[''"](.*?)[''"]')
    foreach ($m in $yamlMatches) {
        $items += $m.Groups[1].Value
    }
    # Also handle unquoted items
    $unquoted = [regex]::Matches($Block, '-\s*([^\s''"][^\r\n]*)')
    foreach ($m in $unquoted) {
        $val = $m.Groups[1].Value.Trim().TrimEnd('"').TrimEnd("'")
        if ($val -and $items -notcontains $val) {
            $items += $val
        }
    }
    return $items
}

function ConvertFrom-Triggers {
    <# Parse triggers section from YAML frontmatter #>
    param([string]$Frontmatter)

    $triggers = @{
        Keywords = @()
        Exact    = @()
        Patterns = @()
        Context  = @()
        Priority = 'normal'
    }

    # Extract priority
    $prioMatch = [regex]::Match($Frontmatter, '(?:triggers:\s*\r?\n(?:\s+.*\r?\n)*\s+)?priority:\s*(\w+)')
    if ($prioMatch.Success) {
        $triggers.Priority = $prioMatch.Groups[1].Value.ToLowerInvariant()
    }

    # Extract keywords (substring match)
    $kwMatch = [regex]::Match($Frontmatter, 'keywords:\s*\r?\n((?:\s+-\s+.*\r?\n?)+)')
    if ($kwMatch.Success) {
        $block = $kwMatch.Groups[1].Value
        # Stop before next top-level key
        if ($block -match '(.*?)(?=\r?\n\s{0,2}\S)') { $block = $Matches[1] }
        $triggers.Keywords = ConvertFrom-YamlList $block
    }

    # Extract exact matches
    $exactMatch = [regex]::Match($Frontmatter, 'exact:\s*\r?\n((?:\s+-\s+.*\r?\n?)+)')
    if ($exactMatch.Success) {
        $block = $exactMatch.Groups[1].Value
        if ($block -match '(.*?)(?=\r?\n\s{0,2}\S)') { $block = $Matches[1] }
        $triggers.Exact = ConvertFrom-YamlList $block
    }

    # Extract patterns (regex)
    $patMatch = [regex]::Match($Frontmatter, 'patterns:\s*\r?\n((?:\s+-\s+.*\r?\n?)+)')
    if ($patMatch.Success) {
        $block = $patMatch.Groups[1].Value
        if ($block -match '(.*?)(?=\r?\n\s{0,2}\S)') { $block = $Matches[1] }
        $triggers.Patterns = ConvertFrom-YamlList $block
    }

    # Extract context triggers
    $ctxMatch = [regex]::Match($Frontmatter, 'context:\s*\r?\n((?:\s+-\s+.*\r?\n?)+)')
    if ($ctxMatch.Success) {
        $block = $ctxMatch.Groups[1].Value
        if ($block -match '(.*?)(?=\r?\n\s{0,2}\S)') { $block = $Matches[1] }
        $triggers.Context = ConvertFrom-YamlList $block
    }

    return $triggers
}

function Test-SkillTrigger {
    <# Test if a prompt matches a skill's triggers. Returns match info or $null #>
    param(
        [string]$PromptLower,
        [string]$PromptOriginal,
        [hashtable]$Triggers,
        [string[]]$ContextFlags
    )

    # 1. Keywords (substring match)
    foreach ($kw in $Triggers.Keywords) {
        if ($PromptLower.Contains($kw.ToLowerInvariant())) {
            return @{ Type = 'keyword'; Value = $kw }
        }
    }

    # 2. Exact (whole-word match using word boundary)
    $words = $PromptLower -split '\s+'
    foreach ($ex in $Triggers.Exact) {
        $exLower = $ex.ToLowerInvariant()
        foreach ($word in $words) {
            $cleanWord = $word -replace '[^\w]', ''
            if ($cleanWord -eq $exLower) {
                return @{ Type = 'exact'; Value = $ex }
            }
        }
        # Also check multi-word exact matches as substring
        if ($ex.Contains(' ') -and $PromptLower.Contains($exLower)) {
            return @{ Type = 'exact'; Value = $ex }
        }
    }

    # 3. Patterns (regex)
    foreach ($pat in $Triggers.Patterns) {
        try {
            if ($PromptOriginal -match $pat) {
                return @{ Type = 'pattern'; Value = $pat }
            }
        } catch {
            # Invalid regex — skip silently
        }
    }

    # 4. Context (session-context match)
    # Context triggers fire only when the prompt IS an explicit idle/automated signal.
    # Must match known patterns exactly — no substring matching.
    foreach ($ctx in $Triggers.Context) {
        if ($ContextFlags -contains $ctx) {
            $trimmed = $PromptOriginal.Trim().ToLowerInvariant()
            $isIdleSignal = $trimmed -match '^(go|start|run|execute|idle|continue|\?|ok|\.|\.\.)$'
            if ($isIdleSignal) {
                return @{ Type = 'context'; Value = $ctx }
            }
        }
    }

    return $null
}

try {
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

    # Detect session context
    $contextFlags = Get-ContextFlags

    # Collect skill directories (project first, then global)
    $skillDirs = @()

    $projectDir = $env:CLAUDE_PROJECT_DIR
    if (-not $projectDir) {
        $projectDir = (Get-Location).Path
    }
    $projectSkills = Join-Path $projectDir '.claude\skills'
    if (Test-Path $projectSkills) { $skillDirs += $projectSkills }

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

            # Parse YAML frontmatter
            if ($content -notmatch '(?s)^---\s*\r?\n(.*?)\r?\n---') { continue }
            $frontmatter = $Matches[1]

            # Check for triggers section
            if ($frontmatter -notmatch 'triggers:') { continue }

            # Extract skill name
            $nameMatch = [regex]::Match($frontmatter, 'name:\s*[''"]?([^\s''"]+)')
            if (-not $nameMatch.Success) { continue }
            $name = $nameMatch.Groups[1].Value

            # Parse all trigger types
            $triggers = ConvertFrom-Triggers $frontmatter

            $hasTriggers = ($triggers.Keywords.Count + $triggers.Exact.Count +
                           $triggers.Patterns.Count + $triggers.Context.Count) -gt 0

            if ($hasTriggers) {
                $skills[$name] = $triggers
            }
        }
    }

    # Match triggers against prompt
    $matchesFound = @()

    foreach ($entry in $skills.GetEnumerator()) {
        $skillName = $entry.Key
        $triggers = $entry.Value

        $match = Test-SkillTrigger $promptLower $prompt $triggers $contextFlags
        if ($null -ne $match) {
            $matchesFound += @{
                Name     = $skillName
                Type     = $match.Type
                Value    = $match.Value
                Priority = $triggers.Priority
            }
        }
    }

    # PowerShell unwraps single-element arrays to a scalar hashtable
    if ($matchesFound -is [hashtable]) {
        $matchesFound = @($matchesFound)
    }
    if ($null -eq $matchesFound -or $matchesFound.Count -eq 0) { exit 0 }

    # Sort by priority
    $prioOrder = @{ high = 0; normal = 1; low = 2 }
    $sorted = @($matchesFound | Sort-Object { $prioOrder[$_.Priority] })

    # Output
    if ($sorted.Count -eq 1) {
        $m = $sorted[0]
        Write-Output "[SKILL-TRIGGER] User input matches skill `"$($m.Name)`" ($($m.Type): `"$($m.Value)`"). Invoke /$($m.Name) for the relevant workflow."
    } else {
        Write-Output "[SKILL-TRIGGER] Multiple skills matched:"
        foreach ($m in $sorted) {
            Write-Output "  - `"$($m.Name)`" ($($m.Type): `"$($m.Value)`") -> /$($m.Name)"
        }
    }
} catch {
    # Hook must never crash — silently exit on unexpected errors
}
exit 0
