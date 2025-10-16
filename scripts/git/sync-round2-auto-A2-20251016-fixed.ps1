# Script de Synchronisation Autonome Round 2 - Action A.2
# Date: 2025-10-16
# Objectif: Synchroniser le dépôt avec origin/main en autonomie maximale

param(
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

Write-Host "=== SYNCHRONISATION AUTONOME ROUND 2 ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
if ($DryRun) {
    Write-Host "MODE DRY-RUN ACTIVE" -ForegroundColor Yellow
}
Write-Host ""

try {
    # Phase 1 : Diagnostic Rapide
    Write-Host "=== PHASE 1 : DIAGNOSTIC ===" -ForegroundColor Cyan
    
    # Fetch pour récupérer les infos du remote
    Write-Host "Fetch origin..." -ForegroundColor Yellow
    git fetch origin 2>&1 | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        throw "Erreur lors du fetch"
    }
    
    # Calculer l'état de synchronisation
    $behind = (git rev-list --count HEAD..origin/main 2>$null)
    $ahead = (git rev-list --count origin/main..HEAD 2>$null)
    
    Write-Host "État de synchronisation:" -ForegroundColor White
    Write-Host "   - Commits locaux (ahead):  $ahead" -ForegroundColor $(if ($ahead -eq 0) { "Green" } else { "Yellow" })
    Write-Host "   - Commits distants (behind): $behind" -ForegroundColor $(if ($behind -eq 0) { "Green" } else { "Yellow" })
    Write-Host ""
    
    # Cas 1 : Déjà à jour
    if ($behind -eq 0 -and $ahead -eq 0) {
        Write-Host "RESULTAT : Deja synchronise" -ForegroundColor Green
        Write-Host ""
        Write-Host "Etat des sous-modules:" -ForegroundColor Cyan
        git submodule status
        Write-Host ""
        Write-Host "Aucune action necessaire" -ForegroundColor Green
        
        # Créer rapport
        $reportFile = "outputs/sync-round2-already-synced-$timestamp.md"
        $reportContent = @"
# Synchronisation Round 2 - Deja a jour
Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Resultat
Le depot est deja synchronise avec origin/main

## Statistiques
* Commits ahead: 0
* Commits behind: 0

## Etat des sous-modules
``````
$(git submodule status)
``````
"@
        $reportContent | Out-File -FilePath $reportFile -Encoding UTF8
        
        Write-Host "Rapport: $reportFile" -ForegroundColor Cyan
        exit 0
    }
    
    # Cas 2 : Simple pull (pas de divergence, seulement en retard)
    if ($ahead -eq 0 -and $behind -gt 0) {
        Write-Host "=== PHASE 2 : PULL SIMPLE (FAST-FORWARD) ===" -ForegroundColor Cyan
        Write-Host "Pull de $behind commit(s)..." -ForegroundColor Yellow
        
        if (-not $DryRun) {
            git pull origin main
            
            if ($LASTEXITCODE -ne 0) {
                throw "Erreur lors du pull"
            }
            
            Write-Host "Pull reussi" -ForegroundColor Green
        } else {
            Write-Host "DRY-RUN: git pull origin main" -ForegroundColor Yellow
        }
        Write-Host ""
        
        # Mettre à jour les sous-modules
        Write-Host "Mise a jour des sous-modules..." -ForegroundColor Yellow
        if (-not $DryRun) {
            git submodule update --init --recursive --remote
        } else {
            Write-Host "DRY-RUN: git submodule update --init --recursive --remote" -ForegroundColor Yellow
        }
        
        # Vérifier s'il y a des changements de références de sous-modules
        $status = git status --porcelain
        if ($status) {
            Write-Host "Modifications detectees (references de sous-modules)" -ForegroundColor Yellow
            Write-Host $status
            Write-Host ""
            
            if (-not $DryRun) {
                Write-Host "Commit des changements de sous-modules..." -ForegroundColor Yellow
                git add .
                git commit -m "chore: sync submodules after pull round 2"
                
                Write-Host "Push vers origin/main..." -ForegroundColor Yellow
                git push origin main
                
                if ($LASTEXITCODE -ne 0) {
                    throw "Erreur lors du push"
                }
                
                Write-Host "Push reussi" -ForegroundColor Green
            } else {
                Write-Host "DRY-RUN: git add + git commit + git push" -ForegroundColor Yellow
            }
        } else {
            Write-Host "Aucune modification de sous-module a committer" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "=== RESULTAT FINAL ===" -ForegroundColor Green
        Write-Host "Type: Fast-forward pull" -ForegroundColor Green
        Write-Host "Commits recuperes: $behind" -ForegroundColor Green
        Write-Host "Push effectue: $(if ($status) { 'OUI' } else { 'NON' })" -ForegroundColor Green
        Write-Host ""
        
        # Créer rapport
        $reportFile = "outputs/sync-round2-success-$timestamp.md"
        $commits = git log --oneline HEAD~$behind..HEAD
        $submoduleStatus = git submodule status
        $reportContent = @"
# Synchronisation Round 2 - Succes
Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Resultat
Synchronisation reussie (fast-forward pull)

## Statistiques
* Type: Fast-forward pull
* Commits recuperes: $behind
* Push effectue: $(if ($status) { 'OUI' } else { 'NON' })

## Commits Recuperes
``````
$commits
``````

## Etat des sous-modules
``````
$submoduleStatus
``````
"@
        $reportContent | Out-File -FilePath $reportFile -Encoding UTF8
        
        Write-Host "Rapport: $reportFile" -ForegroundColor Cyan
        exit 0
    }
    
    # Cas 3 : Divergence détectée
    if ($ahead -gt 0 -and $behind -gt 0) {
        Write-Host "=== PHASE 3 : ANALYSE DE DIVERGENCE ===" -ForegroundColor Yellow
        Write-Host "Divergence detectee: $ahead en avance, $behind en retard" -ForegroundColor Yellow
        Write-Host ""
        
        # Analyser les fichiers modifiés côté distant
        Write-Host "Analyse des modifications distantes..." -ForegroundColor Yellow
        $remoteFiles = git diff --name-only HEAD origin/main
        
        Write-Host "Fichiers modifies cote distant:" -ForegroundColor White
        $remoteFiles | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
        Write-Host ""
        
        # Vérifier si seulement des sous-modules
        $onlySubmodules = $true
        $nonSubmoduleFiles = @()
        foreach ($file in $remoteFiles) {
            if ($file -notmatch '^(mcps/.*|roo-code.*|\.gitmodules)$') {
                $onlySubmodules = $false
                $nonSubmoduleFiles += $file
                Write-Host "Fichier non-submodule detecte: $file" -ForegroundColor Yellow
            }
        }
        Write-Host ""
        
        if ($onlySubmodules) {
            Write-Host "Seulement des sous-modules modifies" -ForegroundColor Green
            Write-Host "Merge automatique en cours..." -ForegroundColor Yellow
            Write-Host ""
            
            if (-not $DryRun) {
                git pull origin main --no-rebase
                
                # Vérifier s'il y a des conflits
                $statusAfterMerge = git status --porcelain
                $hasConflicts = $statusAfterMerge -match '^(UU|AA|DD) '
                
                if ($hasConflicts) {
                    Write-Host "Conflits de sous-modules detectes, resolution automatique..." -ForegroundColor Yellow
                    
                    # Résoudre en choisissant la version remote
                    git checkout --theirs .gitmodules 2>$null
                    
                    # Résoudre pour chaque sous-module
                    $submodules = git submodule status | ForEach-Object { $_.Trim().Split()[1] }
                    foreach ($sm in $submodules) {
                        if ($sm) {
                            git checkout --theirs $sm 2>$null
                        }
                    }
                    
                    git submodule update --init --recursive --remote
                    git add .
                    git commit -m "merge: resolve submodule conflicts (chose remote) - round 2"
                    
                    Write-Host "Conflits resolus" -ForegroundColor Green
                }
                
                Write-Host ""
                Write-Host "Push vers origin/main..." -ForegroundColor Yellow
                git push origin main
                
                if ($LASTEXITCODE -ne 0) {
                    throw "Erreur lors du push"
                }
                
                Write-Host "Push reussi" -ForegroundColor Green
            } else {
                Write-Host "DRY-RUN: git pull origin main --no-rebase + resolution conflits + push" -ForegroundColor Yellow
            }
            
            Write-Host ""
            Write-Host "=== RESULTAT FINAL ===" -ForegroundColor Green
            Write-Host "Type: Merge automatique (sous-modules uniquement)" -ForegroundColor Green
            Write-Host "Commits recuperes: $behind" -ForegroundColor Green
            Write-Host "Commits locaux preserves: $ahead" -ForegroundColor Green
            Write-Host "Push effectue: OUI" -ForegroundColor Green
            Write-Host ""
            
            # Créer rapport
            $reportFile = "outputs/sync-round2-merge-success-$timestamp.md"
            $filesJoined = $remoteFiles -join "`n"
            $distantCommits = git log --oneline HEAD~$behind..origin/main
            $submoduleStatus = git submodule status
            $reportContent = @"
# Synchronisation Round 2 - Merge Reussi
Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Resultat
Merge automatique reussi (sous-modules uniquement)

## Statistiques
* Type: Merge automatique
* Commits recuperes: $behind
* Commits locaux preserves: $ahead
* Push effectue: OUI

## Fichiers Merges
``````
$filesJoined
``````

## Commits Merges (Distants)
``````
$distantCommits
``````

## Etat des sous-modules
``````
$submoduleStatus
``````
"@
            $reportContent | Out-File -FilePath $reportFile -Encoding UTF8
            
            Write-Host "Rapport: $reportFile" -ForegroundColor Cyan
            exit 0
        }
        
        # Cas 4 : Situation complexe - STOP
        Write-Host "STOP : ANALYSE MANUELLE REQUISE" -ForegroundColor Red
        Write-Host ""
        Write-Host "Raison: Fichiers non-submodules modifies des deux cotes" -ForegroundColor Yellow
        Write-Host ""
        
        # Générer rapport détaillé
        $reportFile = "outputs/sync-round2-analysis-$timestamp.md"
        
        $distantCommits = git log --oneline HEAD..origin/main
        $localCommits = git log --oneline origin/main..HEAD
        $diffStatus = git diff --name-status HEAD origin/main
        $distantStats = git log --stat HEAD..origin/main
        $nonSubmoduleFilesJoined = $nonSubmoduleFiles -join "`n"
        
        $reportContent = @"
# Analyse Synchronisation Round 2
Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## STOP : Analyse Manuelle Requise

## Statistiques
* Commits locaux (ahead): $ahead
* Commits distants (behind): $behind
* Type de situation: Divergence avec fichiers non-submodules

## Commits Distants a Integrer
``````
$distantCommits
``````

## Commits Locaux Non Pousses
``````
$localCommits
``````

## Fichiers Modifies (Distants vs Local)
``````
$diffStatus
``````

## Detail des Modifications Distantes
``````
$distantStats
``````

## Fichiers en Conflit Potentiel (Non-Submodules)
``````
$nonSubmoduleFilesJoined
``````

## Recommandation
Analyse manuelle requise - fichiers non-submodules modifies des deux cotes.

### Actions Suggerees
1. Examiner les commits distants et locaux
2. Decider de la strategie (rebase, merge, cherry-pick)
3. Verifier qu'aucun travail important n'est perdu
4. Executer la strategie choisie manuellement

### Commandes Suggerees
``````powershell
# Examiner les differences
git diff HEAD origin/main -- <fichier>

# Visualiser l'historique
git log --graph --oneline --all

# Strategie merge (recommandee pour preserver l'historique)
git pull origin main --no-rebase
# Resoudre conflits manuellement
git mergetool
git commit

# Ou strategie rebase (pour historique lineaire)
git pull origin main --rebase
# Resoudre conflits pas a pas
git rebase --continue
``````
"@
        
        $reportContent | Out-File -FilePath $reportFile -Encoding UTF8
        
        Write-Host "Rapport genere: $reportFile" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "=== RESUME ===" -ForegroundColor Yellow
        Write-Host "Situation: Divergence complexe" -ForegroundColor Yellow
        Write-Host "Ahead: $ahead | Behind: $behind" -ForegroundColor Yellow
        Write-Host "Rapport: $reportFile" -ForegroundColor Yellow
        Write-Host "Fichiers non-submodules: $($nonSubmoduleFiles.Count)" -ForegroundColor Yellow
        Write-Host ""
        
        exit 1
    }
    
    # Cas inattendu
    Write-Host "Situation inattendue detectee" -ForegroundColor Yellow
    Write-Host "Ahead: $ahead | Behind: $behind" -ForegroundColor Yellow
    
    # Créer rapport d'erreur
    $reportFile = "outputs/sync-round2-unexpected-$timestamp.md"
    $gitStatus = git status
    $reportContent = @"
# Synchronisation Round 2 - Situation Inattendue
Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Situation
Situation inattendue detectee

## Statistiques
* Commits ahead: $ahead
* Commits behind: $behind

## Etat Git
``````
$gitStatus
``````
"@
    $reportContent | Out-File -FilePath $reportFile -Encoding UTF8
    
    Write-Host "Rapport: $reportFile" -ForegroundColor Cyan
    exit 1
    
} catch {
    Write-Host ""
    Write-Host "ERREUR CRITIQUE" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    
    # Créer rapport d'erreur
    $reportFile = "outputs/sync-round2-error-$timestamp.md"
    $gitStatus = git status
    $reportContent = @"
# Synchronisation Round 2 - Erreur
Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Erreur
``````
$($_.Exception.Message)
``````

## Stack Trace
``````
$($_.ScriptStackTrace)
``````

## Etat Git au moment de l'erreur
``````
$gitStatus
``````
"@
    $reportContent | Out-File -FilePath $reportFile -Encoding UTF8
    
    Write-Host "Rapport d'erreur: $reportFile" -ForegroundColor Cyan
    exit 1
}