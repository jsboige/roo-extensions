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
# cmd-layer stderr discard (#3731 class, lot 2): a PS-level `2>$null` still lets
# PS 5.1 mint ErrorRecords from stderr under the file-global EAP=Stop; `2>nul`
# inside cmd never creates one, under any EAP.
$currentBranch = (& cmd /c "git branch --show-current 2>nul") | Select-Object -First 1
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
$commitCount = (& cmd /c "git rev-list --count origin/main..$currentBranch 2>nul") | Select-Object -First 1
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
        # cmd-layer stderr merge (#3731 class): PS 5.1 `2>&1` on a native + EAP=Stop
        # turns stderr warnings into a terminating NativeCommandError
        $buildResult = & cmd /c "npx tsc --noEmit 2>&1"
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
& cmd /c "git push -u origin $currentBranch 2>&1"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Push echoue."
    exit 1
}
Write-Host "  Branche poussee."

# 3.5. Guard #1404: Verifier que le diff contient des changements reels
Write-Host "[3.5/4] Verification changements reels..." -ForegroundColor Yellow
$diffStat = & cmd /c "git diff origin/main..$currentBranch --stat 2>&1"
if ($LASTEXITCODE -ne 0 -or $diffStat.Trim() -eq "") {
    Write-Warning "Aucun changement de fichier detecte dans le diff."
    Write-Warning "PR vide bloquee (issue #1404)."
    exit 0
}
Write-Host "  Changements detectes:"
$diffStat | ForEach-Object { Write-Host "    $_" }

# 4. Creer la PR
Write-Host "[4/4] Creation PR..." -ForegroundColor Yellow

# Recuperer les commits pour le summary
$commitLog = & cmd /c "git log --oneline origin/main..$currentBranch 2>nul"

# Recuperer le titre de l'issue
$prTitle = ""
try {
    $issueJson = & cmd /c "gh issue view $IssueNumber --repo jsboige/roo-extensions --json title 2>nul" | ConvertFrom-Json
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

# #3731 class: no PS-level `2>&1` here — the splatted args (multiline --body) make the
# cmd /c form unquoteable, and ANY PS redirect mints ErrorRecords that EAP=Stop turns
# terminating (gh writes progress to stderr). Un-redirected stderr shows on console
# and cannot terminate; the exit code below remains the gate.
$prUrl = & gh @ghArgs
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
