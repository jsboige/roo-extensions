# cleanup-worktrees.ps1
# Nettoyage automatique des worktrees orphelins et branches wt/* inutilisées
# Issue #652 - Accumulation branches worktree orphelines

param(
    [switch]$DryRun,
    [int]$MaxAgeHours = 24,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

function Get-ScriptDirectory {
    Split-Path -Parent $PSCommandPath
}

$repoRoot = Join-Path (Get-ScriptDirectory) "../.."
$repoRoot = Resolve-Path $repoRoot
$cutoffTime = (Get-Date).AddHours(-$MaxAgeHours)

Write-Host "=== Worktree Cleanup ===" -ForegroundColor Cyan
Write-Host "Repository: $repoRoot"
Write-Host "Max age: $MaxAgeHours hours"
Write-Host "Cutoff time: $($cutoffTime.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host ""

if ($DryRun) {
    Write-Host "*** DRY RUN MODE - Aucune suppression ne sera effectuée ***" -ForegroundColor Yellow
    Write-Host ""
}

# Changer vers le repo
Push-Location $repoRoot

try {
    # 1. Lister les worktrees
    Write-Host "## 1. Analyse des worktrees..." -ForegroundColor Cyan
    $worktrees = git worktree list --porcelain | Where-Object { $_ -match "^worktree (.+)" } |
        ForEach-Object { $matches[1] } |
        Where-Object { $_ -ne $repoRoot } # Exclure le worktree principal (main)

    $inactiveWorktrees = @()
    foreach ($wt in $worktrees) {
        $wtName = Split-Path $wt -Leaf
        $wtPath = $wt

        # Vérifier l'âge du worktree (dernière modification)
        if (Test-Path $wtPath) {
            $lastModified = (Get-Item $wtPath -Force).LastWriteTime

            if ($lastModified -lt $cutoffTime) {
                $ageHours = [math]::Round(((Get-Date) - $lastModified).TotalHours, 1)
                Write-Host "  - $wtName (inactif depuis ${ageHours}h)" -ForegroundColor Yellow

                $inactiveWorktrees += @{
                    Path = $wtPath
                    Name = $wtName
                    LastModified = $lastModified
                    AgeHours = $ageHours
                }
            } else {
                Write-Host "  - $wtName (actif, $($lastModified.ToString('yyyy-MM-dd HH:mm')))" -ForegroundColor Green
            }
        }
    }

    # 2. Lister les branches wt/* orphelines (sans worktree correspondant)
    Write-Host ""
    Write-Host "## 2. Analyse des branches wt/*..." -ForegroundColor Cyan

    $wtBranches = git branch --list 'wt/*' | ForEach-Object { $_.Trim() }
    $orphanBranches = @()

    foreach ($branch in $wtBranches) {
        $branchName = $branch
        $worktreeExists = $false

        # Vérifier si un worktree correspondant existe
        foreach ($wt in $worktrees) {
            if ($wt -like "*$branchName*") {
                $worktreeExists = $true
                break
            }
        }

        if (-not $worktreeExists) {
            Write-Host "  - $branchName (orpheline - pas de worktree)" -ForegroundColor Red
            $orphanBranches += $branchName
        } else {
            Write-Host "  - $branchName (has worktree)" -ForegroundColor Green
        }
    }

    # 3. Lister les branches distantes wt/*
    Write-Host ""
    Write-Host "## 3. Analyse des branches distantes wt/*..." -ForegroundColor Cyan

    $remoteBranches = git branch -r --list 'origin/wt/*' 2>$null | ForEach-Object { $_.Trim().Replace('origin/', '') }

    if ($remoteBranches) {
        foreach ($branch in $remoteBranches) {
            Write-Host "  - $branch (distante)" -ForegroundColor Magenta
        }
    } else {
        Write-Host "  (Aucune branche distante wt/* trouvée)" -ForegroundColor Green
    }

    # 4. Actions de nettoyage
    Write-Host ""
    Write-Host "## 4. Actions de nettoyage..." -ForegroundColor Cyan

    $actions = @()

    # Supprimer les worktrees inactifs
    foreach ($wt in $inactiveWorktrees) {
        $action = "Remove-Worktree: $($wt.Name)"
        if ($DryRun) {
            Write-Host "  [DRY-RUN] Supprimer worktree: $($wt.Name)" -ForegroundColor Yellow
        } else {
            Write-Host "  Supprimer worktree: $($wt.Name)" -ForegroundColor Red
            git worktree remove $wt.Path
        }
        $actions += $action
    }

    # Supprimer les branches orphelines
    foreach ($branch in $orphanBranches) {
        $action = "Delete-Branch: $branch"
        if ($DryRun) {
            Write-Host "  [DRY-RUN] Supprimer branche: $branch" -ForegroundColor Yellow
        } else {
            Write-Host "  Supprimer branche: $branch" -ForegroundColor Red
            git branch -D $branch 2>$null
        }
        $actions += $action
    }

    # Supprimer les branches distantes wt/*
    if ($remoteBranches) {
        if (-not $DryRun) {
            Write-Host ""
            Write-Host "## 5. Nettoyage branches distantes..." -ForegroundColor Cyan
            Write-Host "  Les branches distantes wt/* doivent être nettoyées avec:" -ForegroundColor Yellow
            Write-Host "  git push origin --delete wt/..." -ForegroundColor Gray
        }
    }

    # 5. Rapport
    Write-Host ""
    Write-Host "## Rapport" -ForegroundColor Cyan
    Write-Host "Worktrees inactifs: $($inactiveWorktrees.Count)"
    Write-Host "Branches orphelines: $($orphanBranches.Count)"
    Write-Host "Branches distantes: $(if ($remoteBranches) { $remoteBranches.Count } else { 0 })"
    Write-Host "Actions totales: $($actions.Count)"

    if ($DryRun -and $actions.Count -gt 0) {
        Write-Host ""
        Write-Host "*** Pour exécuter le nettoyage, relancer sans -DryRun ***" -ForegroundColor Yellow
    }

    if ($actions.Count -eq 0) {
        Write-Host ""
        Write-Host "✅ Aucun nettoyage nécessaire - Repository propre!" -ForegroundColor Green
    }

} finally {
    Pop-Location
}
