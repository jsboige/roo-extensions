<#
.SYNOPSIS
    Cree un worktree Git pour travailler sur une issue GitHub en isolation.

.DESCRIPTION
    - Cree une branche feature/ISSUE-NNN-titre depuis main
    - Cree un worktree dans le dossier parent (../roo-extensions-wt/)
    - Initialise les submodules dans le worktree
    - Copie .env et configs locales si presentes
    - Affiche les instructions pour commencer a travailler

.PARAMETER IssueNumber
    Numero de l'issue GitHub (ex: 417)

.PARAMETER BaseBranch
    Branche de base (defaut: main)

.PARAMETER WorktreeRoot
    Dossier racine des worktrees (defaut: ../roo-extensions-wt)

.EXAMPLE
    .\create-worktree.ps1 -IssueNumber 417
    .\create-worktree.ps1 -IssueNumber 420 -BaseBranch main
#>

param(
    [Parameter(Mandatory=$true)]
    [int]$IssueNumber,

    [string]$BaseBranch = "main",

    [string]$WorktreeRoot = ""
)

$ErrorActionPreference = "Stop"

# Detecter le repo racine
$RepoRoot = git rev-parse --show-toplevel 2>$null
if (-not $RepoRoot) {
    Write-Error "Pas dans un depot Git. Executez depuis roo-extensions."
    exit 1
}

# Dossier worktree par defaut: a cote du repo principal
if (-not $WorktreeRoot) {
    $WorktreeRoot = Join-Path (Split-Path $RepoRoot -Parent) "roo-extensions-wt"
}

Write-Host "=== Worktree Creator ===" -ForegroundColor Cyan
Write-Host "Repo:       $RepoRoot"
Write-Host "Issue:      #$IssueNumber"
Write-Host "Base:       $BaseBranch"
Write-Host "WT Root:    $WorktreeRoot"
Write-Host ""

# 1. Recuperer le titre de l'issue via gh cli
Write-Host "[1/6] Recuperation titre issue #$IssueNumber..." -ForegroundColor Yellow
$issueTitle = ""
try {
    $issueJson = gh issue view $IssueNumber --repo jsboige/roo-extensions --json title 2>$null | ConvertFrom-Json
    $issueTitle = $issueJson.title
} catch {
    Write-Warning "Impossible de recuperer le titre de l'issue. Utilisation du numero seul."
}

# Nettoyer le titre pour un nom de branche
$cleanTitle = if ($issueTitle) {
    $issueTitle `
        -replace '^\[.*?\]\s*', '' `
        -replace '[^a-zA-Z0-9\s-]', '' `
        -replace '\s+', '-' `
        -replace '-+', '-' `
        -replace '^-|-$', ''
    | ForEach-Object { $_.ToLower().Substring(0, [Math]::Min($_.Length, 40)) }
} else {
    "issue"
}

$branchName = "feature/$IssueNumber-$cleanTitle"
$worktreePath = Join-Path $WorktreeRoot $branchName.Replace("feature/", "")

Write-Host "  Titre:    $issueTitle"
Write-Host "  Branche:  $branchName"
Write-Host "  Chemin:   $worktreePath"
Write-Host ""

# 2. Verifier que la branche n'existe pas deja
Write-Host "[2/6] Verification branche..." -ForegroundColor Yellow
$existingBranch = git branch --list $branchName 2>$null
if ($existingBranch) {
    Write-Warning "La branche '$branchName' existe deja."
    $response = Read-Host "Continuer avec la branche existante? (o/N)"
    if ($response -ne "o" -and $response -ne "O") {
        Write-Host "Annule." -ForegroundColor Red
        exit 0
    }
}

# Verifier que le worktree n'existe pas deja
if (Test-Path $worktreePath) {
    Write-Error "Le dossier worktree existe deja: $worktreePath"
    exit 1
}

# 3. S'assurer d'etre a jour
Write-Host "[3/6] Mise a jour de $BaseBranch..." -ForegroundColor Yellow
Push-Location $RepoRoot
try {
    git fetch origin 2>&1 | Out-Null
    # Verifier si on est sur la bonne branche
    $currentBranch = git branch --show-current
    if ($currentBranch -eq $BaseBranch) {
        git pull origin $BaseBranch --ff-only 2>&1 | Out-Null
        Write-Host "  $BaseBranch mis a jour."
    } else {
        Write-Host "  Branche courante: $currentBranch (fetch only, pas de pull)"
    }
} finally {
    Pop-Location
}

# 4. Creer le dossier parent si necessaire
Write-Host "[4/6] Creation worktree..." -ForegroundColor Yellow
if (-not (Test-Path $WorktreeRoot)) {
    New-Item -ItemType Directory -Path $WorktreeRoot -Force | Out-Null
    Write-Host "  Dossier racine cree: $WorktreeRoot"
}

# Creer la branche et le worktree
Push-Location $RepoRoot
try {
    if (-not $existingBranch) {
        git branch $branchName "origin/$BaseBranch" 2>&1 | Out-Null
        Write-Host "  Branche '$branchName' creee depuis origin/$BaseBranch"
    }
    git worktree add $worktreePath $branchName 2>&1
    Write-Host "  Worktree cree: $worktreePath"
} finally {
    Pop-Location
}

# 5. Initialiser submodules dans le worktree
Write-Host "[5/6] Initialisation submodules..." -ForegroundColor Yellow
Push-Location $worktreePath
try {
    git submodule update --init --recursive 2>&1 | Out-Null
    Write-Host "  Submodules initialises."
} catch {
    Write-Warning "Erreur init submodules: $_"
} finally {
    Pop-Location
}

# 6. Copier configs locales
Write-Host "[6/6] Copie configs locales..." -ForegroundColor Yellow
$configsCopied = @()

# .env
$envFile = Join-Path $RepoRoot ".env"
if (Test-Path $envFile) {
    Copy-Item $envFile (Join-Path $worktreePath ".env")
    $configsCopied += ".env"
}

# .claude/local/ (INTERCOM etc.)
$claudeLocal = Join-Path $RepoRoot ".claude" "local"
if (Test-Path $claudeLocal) {
    $wtClaudeLocal = Join-Path $worktreePath ".claude" "local"
    if (-not (Test-Path $wtClaudeLocal)) {
        New-Item -ItemType Directory -Path $wtClaudeLocal -Force | Out-Null
    }
    Copy-Item "$claudeLocal\*" $wtClaudeLocal -Recurse -Force
    $configsCopied += ".claude/local/"
}

if ($configsCopied.Count -gt 0) {
    Write-Host "  Copies: $($configsCopied -join ', ')"
} else {
    Write-Host "  Aucune config locale a copier."
}

# Resume final
Write-Host ""
Write-Host "=== Worktree cree avec succes ===" -ForegroundColor Green
Write-Host ""
Write-Host "Pour commencer a travailler:" -ForegroundColor Cyan
Write-Host "  cd $worktreePath"
Write-Host ""
Write-Host "Pour lancer les tests:" -ForegroundColor Cyan
Write-Host "  cd mcps/internal/servers/roo-state-manager"
Write-Host "  npx vitest run"
Write-Host ""
Write-Host "Quand c'est pret, soumettre une PR:" -ForegroundColor Cyan
Write-Host "  .\scripts\worktrees\submit-pr.ps1 -IssueNumber $IssueNumber"
Write-Host ""
Write-Host "Pour nettoyer apres merge:" -ForegroundColor Cyan
Write-Host "  .\scripts\worktrees\cleanup-worktree.ps1 -IssueNumber $IssueNumber"
