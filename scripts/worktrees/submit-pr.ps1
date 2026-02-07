<#
.SYNOPSIS
    Soumet une PR depuis un worktree vers main.

.DESCRIPTION
    - Pousse la branche feature vers origin
    - Cree une PR via gh cli avec template standardise
    - Assigne le reviewer (coordinateur)

.PARAMETER IssueNumber
    Numero de l'issue GitHub liee

.PARAMETER Reviewer
    Reviewer GitHub (defaut: jsboige)

.PARAMETER Draft
    Creer en mode draft (defaut: false)

.EXAMPLE
    .\submit-pr.ps1 -IssueNumber 417
    .\submit-pr.ps1 -IssueNumber 420 -Draft
#>

param(
    [Parameter(Mandatory=$true)]
    [int]$IssueNumber,

    [string]$Reviewer = "jsboige",

    [switch]$Draft
)

$ErrorActionPreference = "Stop"

Write-Host "=== PR Submitter ===" -ForegroundColor Cyan

# Verifier qu'on est dans un worktree (pas main)
$currentBranch = git branch --show-current 2>$null
if (-not $currentBranch) {
    Write-Error "Pas dans un depot Git."
    exit 1
}

if ($currentBranch -eq "main") {
    Write-Error "Vous etes sur main. Executez depuis un worktree feature."
    exit 1
}

Write-Host "Branche:  $currentBranch"
Write-Host "Issue:    #$IssueNumber"
Write-Host "Reviewer: $Reviewer"
Write-Host ""

# 1. Verifier qu'il y a des commits a pousser
Write-Host "[1/4] Verification commits..." -ForegroundColor Yellow
$commitCount = git rev-list --count "origin/main..$currentBranch" 2>$null
if ($commitCount -eq 0) {
    Write-Warning "Aucun commit a pousser par rapport a origin/main."
    $response = Read-Host "Continuer quand meme? (o/N)"
    if ($response -ne "o" -and $response -ne "O") {
        exit 0
    }
}
Write-Host "  $commitCount commit(s) a inclure."

# 2. Verifier build et tests
Write-Host "[2/4] Verification build..." -ForegroundColor Yellow
$mcpDir = Join-Path (git rev-parse --show-toplevel) "mcps" "internal" "servers" "roo-state-manager"
if (Test-Path $mcpDir) {
    Push-Location $mcpDir
    try {
        $buildResult = npx tsc --noEmit 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Build TypeScript echoue! Corrigez avant de soumettre."
            Write-Host $buildResult -ForegroundColor Red
            $response = Read-Host "Continuer malgre les erreurs? (o/N)"
            if ($response -ne "o" -and $response -ne "O") {
                exit 1
            }
        } else {
            Write-Host "  Build OK."
        }
    } finally {
        Pop-Location
    }
}

# 3. Pousser la branche
Write-Host "[3/4] Push branche vers origin..." -ForegroundColor Yellow
git push -u origin $currentBranch 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Push echoue."
    exit 1
}
Write-Host "  Branche poussee."

# 4. Creer la PR
Write-Host "[4/4] Creation PR..." -ForegroundColor Yellow

# Recuperer les commits pour le summary
$commitLog = git log --oneline "origin/main..$currentBranch" 2>$null

# Recuperer le titre de l'issue
$prTitle = ""
try {
    $issueJson = gh issue view $IssueNumber --repo jsboige/roo-extensions --json title 2>$null | ConvertFrom-Json
    $prTitle = $issueJson.title -replace '^\[.*?\]\s*', ''
} catch {
    $prTitle = "Feature #$IssueNumber"
}

$prBody = @"
## Summary

Closes #$IssueNumber

### Changes
$($commitLog | ForEach-Object { "- $_" } | Out-String)

## Test plan

- [ ] Build TypeScript: ``npx tsc --noEmit``
- [ ] Tests unitaires: ``npx vitest run``
- [ ] Validation manuelle

## Machine

``$($env:COMPUTERNAME)``

---
Generated with [Claude Code](https://claude.com/claude-code)
"@

$ghArgs = @(
    "pr", "create",
    "--repo", "jsboige/roo-extensions",
    "--title", $prTitle,
    "--body", $prBody,
    "--base", "main",
    "--reviewer", $Reviewer
)

if ($Draft) {
    $ghArgs += "--draft"
}

$prUrl = & gh @ghArgs 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Creation PR echouee: $prUrl"
    exit 1
}

Write-Host ""
Write-Host "=== PR creee avec succes ===" -ForegroundColor Green
Write-Host "URL: $prUrl" -ForegroundColor Cyan
Write-Host ""
Write-Host "Prochaines etapes:" -ForegroundColor Yellow
Write-Host "  1. Attendre review du coordinateur"
Write-Host "  2. Apres merge: .\scripts\worktrees\cleanup-worktree.ps1 -IssueNumber $IssueNumber"
