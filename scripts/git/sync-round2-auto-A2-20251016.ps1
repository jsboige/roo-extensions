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
    Write-Host "⚠️ MODE DRY-RUN ACTIVÉ" -ForegroundColor Yellow
}
Write-Host ""

try {
    # Phase 1 : Diagnostic Rapide
    Write-Host "=== PHASE 1 : DIAGNOSTIC ===" -ForegroundColor Cyan
    
    # Fetch pour récupérer les infos du remote
    Write-Host "🔍 Fetch origin..." -ForegroundColor Yellow
    git fetch origin 2>&1 | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        throw "Erreur lors du fetch"
    }
    
    # Calculer l'état de synchronisation
    $behind = (git rev-list --count HEAD..origin/main 2>$null)
    $ahead = (git rev-list --count origin/main..HEAD 2>$null)
    
    Write-Host "📊 État de synchronisation:" -ForegroundColor White
    Write-Host "   - Commits locaux (ahead):  $ahead" -ForegroundColor $(if ($ahead -eq 0) { "Green" } else { "Yellow" })
    Write-Host "   - Commits distants (behind): $behind" -ForegroundColor $(if ($behind -eq 0) { "Green" } else { "Yellow" })
    Write-Host ""
    
    # Cas 1 : Déjà à jour
    if ($behind -eq 0 -and $ahead -eq 0) {
        Write-Host "✅ RÉSULTAT : Déjà synchronisé" -ForegroundColor Green
        Write-Host ""
        Write-Host "État des sous-modules:" -ForegroundColor Cyan
        git submodule status
        Write-Host ""
        Write-Host "🎉 Aucune action nécessaire" -ForegroundColor Green
        
        # Créer rapport
        $reportFile = "outputs/sync-round2-already-synced-$timestamp.md"
        @"
# Synchronisation Round 2 - Déjà à jour
Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Résultat
✅ Le dépôt est déjà synchronisé avec origin/main

## Statistiques
- Commits ahead: 0
- Commits behind: 0

## État des sous-modules
``````
$(git submodule status)
``````
"@ | Out-File -FilePath $reportFile -Encoding UTF8
        
        Write-Host "📄 Rapport: $reportFile" -ForegroundColor Cyan
        exit 0
    }
    
    # Cas 2 : Simple pull (pas de divergence, seulement en retard)
    if ($ahead -eq 0 -and $behind -gt 0) {
        Write-Host "=== PHASE 2 : PULL SIMPLE (FAST-FORWARD) ===" -ForegroundColor Cyan
        Write-Host "🔄 Pull de $behind commit(s)..." -ForegroundColor Yellow
        
        if (-not $DryRun) {
            git pull origin main
            
            if ($LASTEXITCODE -ne 0) {
                throw "Erreur lors du pull"
            }
            
            Write-Host "✅ Pull réussi" -ForegroundColor Green
        } else {
            Write-Host "⚠️ DRY-RUN: git pull origin main" -ForegroundColor Yellow
        }
        Write-Host ""
        
        # Mettre à jour les sous-modules
        Write-Host "📦 Mise à jour des sous-modules..." -ForegroundColor Yellow
        if (-not $DryRun) {
            git submodule update --init --recursive --remote
        } else {
            Write-Host "⚠️ DRY-RUN: git submodule update --init --recursive --remote" -ForegroundColor Yellow
        }
        
        # Vérifier s'il y a des changements de références de sous-modules
        $status = git status --porcelain
        if ($status) {
            Write-Host "📝 Modifications détectées (références de sous-modules)" -ForegroundColor Yellow
            Write-Host $status
            Write-Host ""
            
            if (-not $DryRun) {
                Write-Host "💾 Commit des changements de sous-modules..." -ForegroundColor Yellow
                git add .
                git commit -m "chore: sync submodules after pull round 2"
                
                Write-Host "📤 Push vers origin/main..." -ForegroundColor Yellow
                git push origin main
                
                if ($LASTEXITCODE -ne 0) {
                    throw "Erreur lors du push"
                }
                
                Write-Host "✅ Push réussi" -ForegroundColor Green
            } else {
                Write-Host "⚠️ DRY-RUN: git add . && git commit && git push" -ForegroundColor Yellow
            }
        } else {
            Write-Host "✅ Aucune modification de sous-module à committer" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "=== RÉSULTAT FINAL ===" -ForegroundColor Green
        Write-Host "✅ Type: Fast-forward pull" -ForegroundColor Green
        Write-Host "✅ Commits récupérés: $behind" -ForegroundColor Green
        Write-Host "✅ Push effectué: $(if ($status) { 'OUI' } else { 'NON' })" -ForegroundColor Green
        Write-Host ""
        
        # Créer rapport
        $reportFile = "outputs/sync-round2-success-$timestamp.md"
        @"
# Synchronisation Round 2 - Succès
Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Résultat
✅ Synchronisation réussie (fast-forward pull)

## Statistiques
- Type: Fast-forward pull
- Commits récupérés: $behind
- Push effectué: $(if ($status) { 'OUI' } else { 'NON' })

## Commits Récupérés
``````
$(git log --oneline HEAD~$behind..HEAD)
``````

## État des sous-modules
``````
$(git submodule status)
``````
"@ | Out-File -FilePath $reportFile -Encoding UTF8
        
        Write-Host "📄 Rapport: $reportFile" -ForegroundColor Cyan
        exit 0
    }
    
    # Cas 3 : Divergence détectée
    if ($ahead -gt 0 -and $behind -gt 0) {
        Write-Host "=== PHASE 3 : ANALYSE DE DIVERGENCE ===" -ForegroundColor Yellow
        Write-Host "⚠️ Divergence détectée: $ahead en avance, $behind en retard" -ForegroundColor Yellow
        Write-Host ""
        
        # Analyser les fichiers modifiés côté distant
        Write-Host "🔍 Analyse des modifications distantes..." -ForegroundColor Yellow
        $remoteFiles = git diff --name-only HEAD origin/main
        
        Write-Host "Fichiers modifiés côté distant:" -ForegroundColor White
        $remoteFiles | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
        Write-Host ""
        
        # Vérifier si seulement des sous-modules
        $onlySubmodules = $true
        $nonSubmoduleFiles = @()
        foreach ($file in $remoteFiles) {
            if ($file -notmatch '^(mcps/.*|roo-code.*|\.gitmodules)$') {
                $onlySubmodules = $false
                $nonSubmoduleFiles += $file
                Write-Host "⚠️ Fichier non-submodule détecté: $file" -ForegroundColor Yellow
            }
        }
        Write-Host ""
        
        if ($onlySubmodules) {
            Write-Host "✅ Seulement des sous-modules modifiés" -ForegroundColor Green
            Write-Host "🔄 Merge automatique en cours..." -ForegroundColor Yellow
            Write-Host ""
            
            if (-not $DryRun) {
                git pull origin main --no-rebase
                
                # Vérifier s'il y a des conflits
                $statusAfterMerge = git status --porcelain
                $hasConflicts = $statusAfterMerge -match '^(UU|AA|DD) '
                
                if ($hasConflicts) {
                    Write-Host "⚠️ Conflits de sous-modules détectés, résolution automatique..." -ForegroundColor Yellow
                    
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
                    
                    Write-Host "✅ Conflits résolus" -ForegroundColor Green
                }
                
                Write-Host ""
                Write-Host "📤 Push vers origin/main..." -ForegroundColor Yellow
                git push origin main
                
                if ($LASTEXITCODE -ne 0) {
                    throw "Erreur lors du push"
                }
                
                Write-Host "✅ Push réussi" -ForegroundColor Green
            } else {
                Write-Host "⚠️ DRY-RUN: git pull origin main --no-rebase + résolution conflits + push" -ForegroundColor Yellow
            }
            
            Write-Host ""
            Write-Host "=== RÉSULTAT FINAL ===" -ForegroundColor Green
            Write-Host "✅ Type: Merge automatique (sous-modules uniquement)" -ForegroundColor Green
            Write-Host "✅ Commits récupérés: $behind" -ForegroundColor Green
            Write-Host "✅ Commits locaux préservés: $ahead" -ForegroundColor Green
            Write-Host "✅ Push effectué: OUI" -ForegroundColor Green
            Write-Host ""
            
            # Créer rapport
            $reportFile = "outputs/sync-round2-merge-success-$timestamp.md"
            @"
# Synchronisation Round 2 - Merge Réussi
Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Résultat
✅ Merge automatique réussi (sous-modules uniquement)

## Statistiques
- Type: Merge automatique
- Commits récupérés: $behind
- Commits locaux préservés: $ahead
- Push effectué: OUI

## Fichiers Mergés
``````
$($remoteFiles -join "`n")
``````

## Commits Mergés (Distants)
``````
$(git log --oneline HEAD~$behind..origin/main)
``````

## État des sous-modules
``````
$(git submodule status)
``````
"@ | Out-File -FilePath $reportFile -Encoding UTF8
            
            Write-Host "📄 Rapport: $reportFile" -ForegroundColor Cyan
            exit 0
        }
        
        # Cas 4 : Situation complexe - STOP
        Write-Host "🛑 STOP : ANALYSE MANUELLE REQUISE" -ForegroundColor Red
        Write-Host ""
        Write-Host "Raison: Fichiers non-submodules modifiés des deux côtés" -ForegroundColor Yellow
        Write-Host ""
        
        # Générer rapport détaillé
        $reportFile = "outputs/sync-round2-analysis-$timestamp.md"
        
        $report = @"
# Analyse Synchronisation Round 2
Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## 🛑 STOP : Analyse Manuelle Requise

## Statistiques
- **Commits locaux (ahead)**: $ahead
- **Commits distants (behind)**: $behind
- **Type de situation**: Divergence avec fichiers non-submodules

## Commits Distants à Intégrer
``````
$(git log --oneline HEAD..origin/main)
``````

## Commits Locaux Non Poussés
``````
$(git log --oneline origin/main..HEAD)
``````

## Fichiers Modifiés (Distants vs Local)
``````
$(git diff --name-status HEAD origin/main)
``````

## Détail des Modifications Distantes
``````
$(git log --stat HEAD..origin/main)
``````

## Fichiers en Conflit Potentiel (Non-Submodules)
``````
$($nonSubmoduleFiles -join "`n")
``````

## Recommandation
⚠️ **Analyse manuelle requise** - fichiers non-submodules modifiés des deux côtés.

### Actions Suggérées
1. Examiner les commits distants et locaux
2. Décider de la stratégie (rebase, merge, cherry-pick)
3. Vérifier qu'aucun travail important n'est perdu
4. Exécuter la stratégie choisie manuellement

### Commandes Suggérées
``````powershell
# Examiner les différences
git diff HEAD origin/main -- <fichier>

# Visualiser l'historique
git log --graph --oneline --all

# Stratégie merge (recommandée pour préserver l'historique)
git pull origin main --no-rebase
# Résoudre conflits manuellement
git mergetool
git commit

# Ou stratégie rebase (pour historique linéaire)
git pull origin main --rebase
# Résoudre conflits pas à pas
git rebase --continue
``````
"@
        
        $report | Out-File -FilePath $reportFile -Encoding UTF8
        
        Write-Host "📄 Rapport généré: $reportFile" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "=== RÉSUMÉ ===" -ForegroundColor Yellow
        Write-Host "⚠️ Situation: Divergence complexe" -ForegroundColor Yellow
        Write-Host "📊 Ahead: $ahead | Behind: $behind" -ForegroundColor Yellow
        Write-Host "📄 Rapport: $reportFile" -ForegroundColor Yellow
        Write-Host "🔍 Fichiers non-submodules: $($nonSubmoduleFiles.Count)" -ForegroundColor Yellow
        Write-Host ""
        
        exit 1
    }
    
    # Cas inattendu
    Write-Host "⚠️ Situation inattendue détectée" -ForegroundColor Yellow
    Write-Host "Ahead: $ahead | Behind: $behind" -ForegroundColor Yellow
    
    # Créer rapport d'erreur
    $reportFile = "outputs/sync-round2-unexpected-$timestamp.md"
    @"
# Synchronisation Round 2 - Situation Inattendue
Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Situation
⚠️ Situation inattendue détectée

## Statistiques
- Commits ahead: $ahead
- Commits behind: $behind

## État Git
``````
$(git status)
``````
"@ | Out-File -FilePath $reportFile -Encoding UTF8
    
    Write-Host "📄 Rapport: $reportFile" -ForegroundColor Cyan
    exit 1
    
} catch {
    Write-Host ""
    Write-Host "❌ ERREUR CRITIQUE" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    
    # Créer rapport d'erreur
    $reportFile = "outputs/sync-round2-error-$timestamp.md"
    @"
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

## État Git au moment de l'erreur
``````
$(git status)
``````
"@ | Out-File -FilePath $reportFile -Encoding UTF8
    
    Write-Host "📄 Rapport d'erreur: $reportFile" -ForegroundColor Cyan
    exit 1
}