#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Setup script for multi-agent framework workspace

.DESCRIPTION
    Initializes a new workspace with the multi-agent framework
    (Claude Code + Roo Code + RooSync + Scheduler)

.PARAMETER ProjectName
    Name of the project (used for CLAUDE.md customization)

.PARAMETER Repo
    GitHub repository (format: username/repo)

.PARAMETER MachineId
    Optional machine ID (default: hostname)

.EXAMPLE
    .\setup-workspace.ps1 -ProjectName "MyProject" -Repo "username/repo"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectName,

    [Parameter(Mandatory=$true)]
    [string]$Repo,

    [Parameter(Mandatory=$false)]
    [string]$MachineId = $env:COMPUTERNAME.ToLower()
)

$ErrorActionPreference = "Stop"

# =============================================================================
# Functions
# =============================================================================

function Write-Step {
    param([string]$Message)
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Yellow
}

# =============================================================================
# Main
# =============================================================================

Write-Step "Multi-Agent Framework Setup"

# Check prerequisites
Write-Step "Checking prerequisites"

$prerequisites = @{
    "VS Code" = { code --version }
    "gh CLI" = { gh --version }
    "Node.js" = { node --version }
    "PowerShell" = { $PSVersionTable.PSVersion }
}

foreach ($tool in $prerequisites.Keys) {
    try {
        & $prerequisites[$tool] | Out-Null
        Write-Success "$tool installed"
    } catch {
        Write-Host "❌ $tool not found" -ForegroundColor Red
        exit 1
    }
}

# Create directory structure
Write-Step "Creating directory structure"

$directories = @(
    ".claude/local",
    ".claude/agents",
    ".claude/skills",
    ".claude/rules",
    ".roo/rules",
    "roo-config/modes"
)

foreach ($dir in $directories) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Write-Success "Created $dir"
}

# Create INTERCOM template
Write-Step "Creating INTERCOM template"

$intercomPath = ".claude/local/INTERCOM-$MachineId.md"
@"
# INTERCOM - $MachineId

**Machine:** $MachineId
**Purpose:** Local Claude Code <-> Roo agent communication

---

## Messages

*(Add your messages here)*

"@ | Out-File -FilePath $intercomPath -Encoding utf8

Write-Success "Created $intercomPath"

# Create CLAUDE.md template
Write-Step "Creating CLAUDE.md template"

$claudeMd = @"
# CLAUDE.md - $ProjectName

**Repository:** [$Repo](https://github.com/$Repo)
**Machine:** $MachineId
**Date:** $(Get-Date -Format "yyyy-MM-dd")

---

## Project Overview

**$ProjectName** - [Brief description]

---

## Quick Start

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Run tests:**
   ```bash
   npm test
   ```

3. **Build:**
   ```bash
   npm run build
   ```

---

## INTERCOM Protocol

Communication locale entre Claude Code et Roo via `.claude/local/INTERCOM-$MachineId.md`

---

## Rules

- Testing: [`.claude/rules/testing.md`](.claude/rules/testing.md)
- GitHub CLI: [`.claude/rules/github-cli.md`](.claude/rules/github-cli.md)

---

## Skills

- `/validate` - Run build + tests
- `/git-sync` - Pull + merge conservatif
- `/github-status` - Check Project status

---

**Last updated:** $(Get-Date -Format "yyyy-MM-dd")
"@

$claudeMd | Out-File -FilePath ".claude/CLAUDE.md" -Encoding utf8

Write-Success "Created .claude/CLAUDE.md"

# Create .gitignore entries
Write-Step "Updating .gitignore"

$gitignoreEntries = @(
    ".claude/local/",
    ".roo/schedules.json",
    "node_modules/"
)

if (Test-Path ".gitignore") {
    $existing = Get-Content ".gitignore"
    $newEntries = $gitignoreEntries | Where-Object { $_ -notin $existing }
    if ($newEntries) {
        $newEntries | Add-Content ".gitignore"
        Write-Success "Added new entries to .gitignore"
    } else {
        Write-Info "All .gitignore entries already exist"
    }
} else {
    $gitignoreEntries | Out-File ".gitignore"
    Write-Success "Created .gitignore"
}

# Summary
Write-Step "Setup Complete"

Write-Host "`nWorkspace initialized for: $ProjectName" -ForegroundColor Green
Write-Host "Repository: $Repo" -ForegroundColor Green
Write-Host "Machine ID: $MachineId" -ForegroundColor Green

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Review and customize .claude/CLAUDE.md"
Write-Host "2. Run: git init"
Write-Host "3. Run: gh auth login"
Write-Host "4. Create first task in INTERCOM"

Write-Host "`n⏱️  Estimated time: < 15 minutes" -ForegroundColor Yellow
