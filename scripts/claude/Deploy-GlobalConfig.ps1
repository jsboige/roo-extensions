<#
.SYNOPSIS
    Deploy global Claude Code configuration from roo-extensions templates.

.DESCRIPTION
    Copies agents, skills, commands, and CLAUDE.md from .claude/configs/
    to ~/.claude/ for global availability across all workspaces.

.PARAMETER Target
    What to deploy: all, agents, skills, commands, claude-md

.PARAMETER DryRun
    Show what would be deployed without actually copying.

.EXAMPLE
    .\Deploy-GlobalConfig.ps1
    .\Deploy-GlobalConfig.ps1 -Target agents
    .\Deploy-GlobalConfig.ps1 -DryRun
#>
param(
    [ValidateSet("all", "agents", "skills", "commands", "claude-md")]
    [string]$Target = "all",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Paths
$repoRoot = (git rev-parse --show-toplevel 2>$null) -replace '/', '\'
if (-not $repoRoot) {
    $repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
}
$configsDir = Join-Path $repoRoot ".claude\configs"
$globalDir = Join-Path $env:USERPROFILE ".claude"

Write-Host "=== Deploy Global Claude Code Config ===" -ForegroundColor Cyan
Write-Host "Source: $configsDir"
Write-Host "Target: $globalDir"
Write-Host "Mode: $(if ($DryRun) { 'DRY RUN' } else { 'DEPLOY' })"
Write-Host ""

function Deploy-Files {
    param([string]$SourceDir, [string]$TargetDir, [string]$Label)

    if (-not (Test-Path $SourceDir)) {
        Write-Host "  SKIP $Label (source not found: $SourceDir)" -ForegroundColor Yellow
        return 0
    }

    $count = 0
    Get-ChildItem -Path $SourceDir -Recurse -File | ForEach-Object {
        $relativePath = $_.FullName.Substring($SourceDir.Length).TrimStart('\', '/')
        $destPath = Join-Path $TargetDir $relativePath
        $destDir = Split-Path -Parent $destPath

        if (-not $DryRun) {
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item -Path $_.FullName -Destination $destPath -Force
        }

        $status = if (Test-Path $destPath) { "UPDATE" } else { "NEW" }
        Write-Host "  $status $relativePath" -ForegroundColor $(if ($status -eq "NEW") { "Green" } else { "White" })
        $count++
    }
    return $count
}

$totalFiles = 0

# Deploy CLAUDE.md
if ($Target -in "all", "claude-md") {
    Write-Host "`n--- CLAUDE.md ---" -ForegroundColor Yellow
    $claudeMdSource = Join-Path $configsDir "user-global-claude.md"
    $claudeMdDest = Join-Path $globalDir "CLAUDE.md"
    if (Test-Path $claudeMdSource) {
        if (-not $DryRun) {
            Copy-Item -Path $claudeMdSource -Destination $claudeMdDest -Force
        }
        Write-Host "  DEPLOY user-global-claude.md -> CLAUDE.md" -ForegroundColor Green
        $totalFiles++
    }
}

# Deploy Agents
if ($Target -in "all", "agents") {
    Write-Host "`n--- Agents ---" -ForegroundColor Yellow
    $agentsSrc = Join-Path $configsDir "agents"
    $agentsDst = Join-Path $globalDir "agents"
    $totalFiles += (Deploy-Files -SourceDir $agentsSrc -TargetDir $agentsDst -Label "agents")
}

# Deploy Skills
if ($Target -in "all", "skills") {
    Write-Host "`n--- Skills ---" -ForegroundColor Yellow
    $skillsSrc = Join-Path $configsDir "skills"
    $skillsDst = Join-Path $globalDir "skills"
    $totalFiles += (Deploy-Files -SourceDir $skillsSrc -TargetDir $skillsDst -Label "skills")
}

# Deploy Commands
if ($Target -in "all", "commands") {
    Write-Host "`n--- Commands ---" -ForegroundColor Yellow
    $cmdsSrc = Join-Path $configsDir "commands"
    $cmdsDst = Join-Path $globalDir "commands"
    $totalFiles += (Deploy-Files -SourceDir $cmdsSrc -TargetDir $cmdsDst -Label "commands")
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Files deployed: $totalFiles"
if ($DryRun) {
    Write-Host "(DRY RUN - no files were actually copied)" -ForegroundColor Yellow
}
Write-Host "Done." -ForegroundColor Green
