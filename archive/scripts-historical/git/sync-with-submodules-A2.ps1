# Synchronisation Git Complète avec Sous-modules - Action A.2
# Date: 2025-10-13
# But: Gérer les commits/pull/push du dépôt principal ET tous ses sous-modules

[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host "=== SYNCHRONISATION COMPLETE AVEC SOUS-MODULES - Action A.2 ===" -ForegroundColor Cyan
Write-Host "Timestamp: $timestamp" -ForegroundColor Gray
if ($DryRun) {
    Write-Host "MODE SIMULATION (DryRun)" -ForegroundColor Yellow
}
Write-Host ""

# Tableau pour suivre les actions
$submoduleActions = @()
$mainRepoUpdated = $false

function Invoke-SafeGitCommand {
    param(
        [string]$Description,
        [string]$Command,
        [switch]$ContinueOnError
    )
    
    Write-Host "  >>> $Description" -ForegroundColor Cyan
    Write-Host "      Commande: $Command" -ForegroundColor Gray
    
    if ($DryRun) {
        Write-Host "      [SIMULATION]" -ForegroundColor Yellow
        return $true
    }
    
    try {
        $output = Invoke-Expression $Command 2>&1
        if ($output) {
            $output | ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
        }
        Write-Host "      [OK]" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "      [ERREUR] $_" -ForegroundColor Red
        if (-not $ContinueOnError) {
            throw
        }
        return $false
    }
}

try {
    # =============================================
    # PHASE 1: ANALYSE DE L'ÉTAT
    # =============================================
    Write-Host "=== PHASE 1: ANALYSE DE L'ÉTAT ===" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "Dépôt principal:" -ForegroundColor Cyan
    $mainBranch = git branch --show-current
    Write-Host "  Branche: $mainBranch" -ForegroundColor Gray
    
    $mainStatus = git status --short
    if ($mainStatus) {
        Write-Host "  Status: MODIFICATIONS DÉTECTÉES" -ForegroundColor Yellow
        $mainStatus | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
    } else {
        Write-Host "  Status: PROPRE" -ForegroundColor Green
    }
    Write-Host ""
    
    # Liste des sous-modules
    Write-Host "Analyse des sous-modules..." -ForegroundColor Cyan
    $submodules = git submodule status | ForEach-Object {
        if ($_ -match '^\s*(\+|\-|\s)([a-f0-9]+)\s+([^\s]+)\s+(.*)$') {
            @{
                Hash = $matches[2]
                Path = $matches[3]
                Info = $matches[4]
                Status = $matches[1]
            }
        }
    }
    
    Write-Host "  Sous-modules trouvés: $($submodules.Count)" -ForegroundColor Gray
    Write-Host ""
    
    # =============================================
    # PHASE 2: TRAITEMENT DES SOUS-MODULES
    # =============================================
    Write-Host "=== PHASE 2: TRAITEMENT DES SOUS-MODULES ===" -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($submodule in $submodules) {
        $subPath = $submodule.Path
        Write-Host "--- Sous-module: $subPath ---" -ForegroundColor Magenta
        
        if (-not (Test-Path $subPath)) {
            Write-Host "  [SKIP] Chemin introuvable" -ForegroundColor Gray
            continue
        }
        
        Push-Location $subPath
        try {
            # Vérifier l'état
            $subStatus = git status --short
            $subBranch = git branch --show-current
            
            Write-Host "  Branche: $subBranch" -ForegroundColor Gray
            
            if (-not $subStatus) {
                Write-Host "  [PROPRE] Aucune modification" -ForegroundColor Green
                
                # Pull quand même pour être à jour
                Invoke-SafeGitCommand -Description "Pull origin/$subBranch" `
                    -Command "git pull origin $subBranch --ff-only" -ContinueOnError
                
                $submoduleActions += @{
                    Path = $subPath
                    Action = "Pull uniquement"
                    Success = $true
                }
                
            } else {
                Write-Host "  [MODIFICATIONS] Fichiers modifiés détectés:" -ForegroundColor Yellow
                $subStatus | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
                
                # Pull d'abord (fast-forward uniquement pour éviter merges automatiques)
                Write-Host "  Étape 1: Pull des dernières modifications" -ForegroundColor Cyan
                if (-not $DryRun) {
                    try {
                        git pull origin $subBranch --ff-only 2>&1 | Out-Null
                        Write-Host "      [OK] Pull fast-forward réussi" -ForegroundColor Green
                    } catch {
                        Write-Host "      [ATTENTION] Pull fast-forward impossible - Merge requis!" -ForegroundColor Red
                        Write-Host "      ARRÊT: Résolution manuelle nécessaire dans $subPath" -ForegroundColor Yellow
                        Write-Host "      Actions manuelles:" -ForegroundColor Yellow
                        Write-Host "        1. cd $subPath" -ForegroundColor Gray
                        Write-Host "        2. git pull origin $subBranch" -ForegroundColor Gray
                        Write-Host "        3. Résoudre les conflits si nécessaire" -ForegroundColor Gray
                        Write-Host "        4. Relancer ce script" -ForegroundColor Gray
                        throw "Merge requis - Intervention manuelle nécessaire"
                    }
                } else {
                    Write-Host "      [SIMULATION] Pull --ff-only" -ForegroundColor Yellow
                }
                
                # Staging
                Write-Host "  Étape 2: Staging des modifications" -ForegroundColor Cyan
                $modifiedFiles = git diff --name-only
                $modifiedFiles | ForEach-Object {
                    Invoke-SafeGitCommand -Description "Add $_" `
                        -Command "git add `"$_`"" -ContinueOnError
                }
                
                # Commit
                Write-Host "  Étape 3: Commit" -ForegroundColor Cyan
                $commitMsg = "fix(docs): correction chemins relatifs - Action A.2 (sous-module)

Corrections des chemins relatifs suite à la réorganisation:
- ../docs/ -> ../../docs/ pour les serveurs internes

Synchronisé avec dépôt principal"
                
                if (-not $DryRun) {
                    $staged = git diff --cached --name-only
                    if ($staged) {
                        Invoke-SafeGitCommand -Description "Commit" `
                            -Command "git commit -m `"$commitMsg`""
                    } else {
                        Write-Host "      [SKIP] Aucun fichier stagé" -ForegroundColor Gray
                    }
                }
                
                # Push
                Write-Host "  Étape 4: Push vers origin" -ForegroundColor Cyan
                Invoke-SafeGitCommand -Description "Push origin/$subBranch" `
                    -Command "git push origin $subBranch"
                
                $submoduleActions += @{
                    Path = $subPath
                    Action = "Pull + Commit + Push"
                    Success = $true
                }
                
                $mainRepoUpdated = $true
            }
            
        } catch {
            Write-Host "  [ERREUR] $($_.Exception.Message)" -ForegroundColor Red
            $submoduleActions += @{
                Path = $subPath
                Action = "ERREUR"
                Success = $false
                Error = $_.Exception.Message
            }
        } finally {
            Pop-Location
        }
        
        Write-Host ""
    }
    
    # =============================================
    # PHASE 3: MISE À JOUR DU DÉPÔT PRINCIPAL
    # =============================================
    Write-Host "=== PHASE 3: MISE A JOUR DU DEPOT PRINCIPAL ===" -ForegroundColor Yellow
    Write-Host ""
    
    if ($mainRepoUpdated) {
        Write-Host "Mise à jour des références de sous-modules..." -ForegroundColor Cyan
        
        Invoke-SafeGitCommand -Description "Update submodule references" `
            -Command "git submodule update --remote --merge"
        
        Invoke-SafeGitCommand -Description "Stage submodule updates" `
            -Command "git add -u"
    }
    
    # Vérifier s'il y a des modifications en attente
    $finalStatus = git status --short
    if ($finalStatus) {
        Write-Host "Modifications en attente dans le dépôt principal:" -ForegroundColor Yellow
        $finalStatus | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        Write-Host ""
        
        # Pull (fast-forward uniquement pour éviter merges automatiques)
        Write-Host "Étape 1: Pull origin/main" -ForegroundColor Cyan
        if (-not $DryRun) {
            try {
                git pull origin main --ff-only 2>&1 | Out-Null
                Write-Host "  [OK] Pull fast-forward réussi" -ForegroundColor Green
            } catch {
                Write-Host "  [ATTENTION] Pull fast-forward impossible - Merge requis!" -ForegroundColor Red
                Write-Host "  ARRÊT: Résolution manuelle nécessaire dans le dépôt principal" -ForegroundColor Yellow
                Write-Host "  Actions manuelles:" -ForegroundColor Yellow
                Write-Host "    1. git pull origin main" -ForegroundColor Gray
                Write-Host "    2. Résoudre les conflits si nécessaire" -ForegroundColor Gray
                Write-Host "    3. Relancer ce script" -ForegroundColor Gray
                throw "Merge requis - Intervention manuelle nécessaire"
            }
        } else {
            Write-Host "  [SIMULATION] Pull --ff-only" -ForegroundColor Yellow
        }
        
        # Staging (si nécessaire)
        $unstaged = git diff --name-only
        if ($unstaged) {
            Write-Host "Étape 2: Staging des fichiers modifiés" -ForegroundColor Cyan
            $unstaged | ForEach-Object {
                Invoke-SafeGitCommand -Description "Add $_" `
                    -Command "git add `"$_`"" -ContinueOnError
            }
        }
        
        # Commit
        Write-Host "Étape 3: Commit" -ForegroundColor Cyan
        $mainCommitMsg = "chore: mise à jour références sous-modules - Action A.2

Synchronisation des sous-modules après corrections:
- Mise à jour des références de sous-modules
- Corrections propagées dans les sous-modules

Action A.2 - Phase 2 SDDD"
        
        if (-not $DryRun) {
            $staged = git diff --cached --name-only
            if ($staged) {
                Invoke-SafeGitCommand -Description "Commit main repo" `
                    -Command "git commit -m `"$mainCommitMsg`""
            } else {
                Write-Host "  [INFO] Aucun fichier à commiter" -ForegroundColor Gray
            }
        }
        
        # Push
        Write-Host "Étape 4: Push origin/main" -ForegroundColor Cyan
        Invoke-SafeGitCommand -Description "Push origin/main" `
            -Command "git push origin main"
        
    } else {
        Write-Host "[INFO] Dépôt principal déjà à jour" -ForegroundColor Green
    }
    
    # =============================================
    # PHASE 4: RAPPORT FINAL
    # =============================================
    Write-Host ""
    Write-Host "=== PHASE 4: RAPPORT FINAL ===" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "Résumé des actions sur les sous-modules:" -ForegroundColor Cyan
    foreach ($action in $submoduleActions) {
        $status = if ($action.Success) { "OK" } else { "ERREUR" }
        $color = if ($action.Success) { "Green" } else { "Red" }
        Write-Host "  [$status] $($action.Path): $($action.Action)" -ForegroundColor $color
        if ($action.Error) {
            Write-Host "        Erreur: $($action.Error)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "Vérification finale..." -ForegroundColor Cyan
    if (-not $DryRun) {
        $finalCheck = git status --short
        if (-not $finalCheck) {
            Write-Host "  [OK] Tous les dépôts sont synchronisés" -ForegroundColor Green
        } else {
            Write-Host "  [ATTENTION] Modifications restantes:" -ForegroundColor Yellow
            $finalCheck | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        }
    }
    
    Write-Host ""
    Write-Host "=== SYNCHRONISATION COMPLETE REUSSIE ===" -ForegroundColor Green
    Write-Host "Timestamp fin: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    
} catch {
    Write-Host ""
    Write-Host "=== ERREUR CRITIQUE ===" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Utilisez 'git status' et 'git submodule foreach git status' pour vérifier l'état" -ForegroundColor Yellow
    exit 1
}