<#
.SYNOPSIS
    Nettoie un worktree apres merge de la PR.

.DESCRIPTION
    - Supprime le worktree Git
    - Supprime la branche locale et remote
    - Nettoie le dossier sur disque

.PARAMETER IssueNumber
    Numero de l'issue GitHub

.PARAMETER WorktreeRoot
    Dossier racine des worktrees (defaut: ../roo-extensions-wt)

.PARAMETER KeepRemote
    Ne pas supprimer la branche remote (defaut: false)

.PARAMETER Force
    Forcer la suppression meme si non merge (defaut: false)

.EXAMPLE
    .\cleanup-worktree.ps1 -IssueNumber 417
    .\cleanup-worktree.ps1 -IssueNumber 417 -Force
#>

param(
    [Parameter(Mandatory=$true)]
    [int]$IssueNumber,

    [string]$WorktreeRoot = "",

    [switch]$KeepRemote,

    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Detecter le repo racine
$RepoRoot = git rev-parse --show-toplevel 2>$null
if (-not $RepoRoot) {
    Write-Error "Pas dans un depot Git."
    exit 1
}

if (-not $WorktreeRoot) {
    $WorktreeRoot = Join-Path (Split-Path $RepoRoot -Parent) "roo-extensions-wt"
}

Write-Host "=== Worktree Cleanup ===" -ForegroundColor Cyan
Write-Host "Repo:    $RepoRoot"
Write-Host "Issue:   #$IssueNumber"
Write-Host ""

# 1. Trouver la branche et le worktree correspondant
Write-Host "[1/4] Recherche worktree pour issue #$IssueNumber..." -ForegroundColor Yellow

$worktreeList = git worktree list --porcelain 2>$null
$targetBranch = $null
$targetPath = $null

# Chercher dans les worktrees existants
$worktrees = git worktree list 2>$null
foreach ($wt in $worktrees) {
    if ($wt -match "\[(.+)\]") {
        $branch = $Matches[1]
        if ($branch -match "feature/$IssueNumber-") {
            $targetBranch = $branch
            $targetPath = ($wt -split '\s+')[0]
            break
        }
    }
}

# Aussi chercher par nom de branche si worktree non trouve
if (-not $targetBranch) {
    $branches = git branch --list "feature/$IssueNumber-*" 2>$null
    if ($branches) {
        $targetBranch = ($branches[0] -replace '^\s*\*?\s*', '').Trim()
        # Chercher le dossier
        $possiblePath = Get-ChildItem $WorktreeRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match "^$IssueNumber-" } |
            Select-Object -First 1
        if ($possiblePath) {
            $targetPath = $possiblePath.FullName
        }
    }
}

if (-not $targetBranch) {
    Write-Error "Aucun worktree ou branche trouve pour issue #$IssueNumber"
    Write-Host "Worktrees existants:"
    git worktree list 2>$null
    Write-Host ""
    Write-Host "Branches feature existantes:"
    git branch --list "feature/*" 2>$null
    exit 1
}

Write-Host "  Branche: $targetBranch"
Write-Host "  Chemin:  $targetPath"
Write-Host ""

# 2. Verifier si la branche est mergee
Write-Host "[2/4] Verification merge..." -ForegroundColor Yellow
$isMerged = git branch --merged main --list $targetBranch 2>$null
if (-not $isMerged -and -not $Force) {
    Write-Warning "La branche '$targetBranch' n'est PAS encore mergee dans main."
    $response = Read-Host "Supprimer quand meme? (o/N)"
    if ($response -ne "o" -and $response -ne "O") {
        Write-Host "Annule. Utilisez -Force pour forcer." -ForegroundColor Red
        exit 0
    }
}
if ($isMerged) {
    Write-Host "  Branche mergee dans main."
} else {
    Write-Host "  Branche NON mergee (suppression forcee)." -ForegroundColor Yellow
}

# 3. Supprimer le worktree
Write-Host "[3/4] Suppression worktree..." -ForegroundColor Yellow
if ($targetPath -and (git worktree list 2>$null | Select-String $targetPath)) {
    if ($Force) {
        git worktree remove $targetPath --force 2>&1
    } else {
        git worktree remove $targetPath 2>&1
    }
    Write-Host "  Worktree supprime."
} elseif ($targetPath -and (Test-Path $targetPath)) {
    Write-Host "  Worktree pas dans git, suppression dossier..."
    Remove-Item $targetPath -Recurse -Force
    Write-Host "  Dossier supprime."
} else {
    Write-Host "  Pas de worktree a supprimer."
}

# Nettoyer les references worktree invalides
git worktree prune 2>$null

# 4. Supprimer les branches
Write-Host "[4/4] Suppression branches..." -ForegroundColor Yellow

# Branche locale
$deleteFlag = if ($Force -or -not $isMerged) { "-D" } else { "-d" }
git branch $deleteFlag $targetBranch 2>&1 | Out-Null
Write-Host "  Branche locale '$targetBranch' supprimee."

# Branche remote
if (-not $KeepRemote) {
    $remoteBranch = git ls-remote --heads origin $targetBranch 2>$null
    if ($remoteBranch) {
        git push origin --delete $targetBranch 2>&1 | Out-Null
        Write-Host "  Branche remote supprimee."
    } else {
        Write-Host "  Pas de branche remote a supprimer."
    }
}

# Nettoyer le dossier racine si vide
if ((Test-Path $WorktreeRoot) -and -not (Get-ChildItem $WorktreeRoot -Directory)) {
    Remove-Item $WorktreeRoot -Force
    Write-Host "  Dossier racine worktrees supprime (vide)."
}

Write-Host ""
Write-Host "=== Cleanup termine ===" -ForegroundColor Green
Write-Host ""
Write-Host "Worktrees restants:" -ForegroundColor Cyan
git worktree list
