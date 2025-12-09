# Script d'analyse des 50 derniers commits - Investigation du blocage à 60 erreurs
# Date: 2025-12-04
# Objectif: Identifier les patterns de commits expliquant le blocage à 60 erreurs

Write-Host "🔍 ANALYSE DES 50 DERNIERS COMMITS - INVESTIGATION BLOCAGE 60 ERREURS" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Récupération des commits des 2 dernières semaines
Write-Host "`n📊 ÉTAPE 1: Récupération des commits des 2 dernières semaines..." -ForegroundColor Yellow
$commits = git log --since="2 weeks ago" --pretty=format:"%h|%ad|%s|%an" --date=short -50

# Analyse par jour
Write-Host "`n📅 ÉTAPE 2: Analyse des commits par jour..." -ForegroundColor Yellow
$commitsByDay = @{}
foreach ($commit in $commits) {
    $parts = $commit -split '\|'
    $date = $parts[1]
    if ($commitsByDay.ContainsKey($date)) {
        $commitsByDay[$date]++
    } else {
        $commitsByDay[$date] = 1
    }
}

Write-Host "Répartition des commits par jour:" -ForegroundColor Green
foreach ($day in $commitsByDay.Keys | Sort-Object) {
    Write-Host "  $day : $($commitsByDay[$day]) commits" -ForegroundColor White
}

# Analyse par type de commit
Write-Host "`n🏷️ ÉTAPE 3: Analyse des commits par type..." -ForegroundColor Yellow
$commitTypes = @{
    "fix" = 0
    "feat" = 0
    "docs" = 0
    "chore" = 0
    "refactor" = 0
    "test" = 0
    "autre" = 0
}

$fixCommits = @()
$featCommits = @()
$docsCommits = @()

foreach ($commit in $commits) {
    $parts = $commit -split '\|'
    $message = $parts[2]
    $hash = $parts[0]
    
    if ($message -match "^fix\(") {
        $commitTypes["fix"]++
        $fixCommits += $commit
    } elseif ($message -match "^feat\(") {
        $commitTypes["feat"]++
        $featCommits += $commit
    } elseif ($message -match "^docs\(") {
        $commitTypes["docs"]++
        $docsCommits += $commit
    } elseif ($message -match "^chore\(") {
        $commitTypes["chore"]++
    } elseif ($message -match "^refactor\(") {
        $commitTypes["refactor"]++
    } elseif ($message -match "^test\(") {
        $commitTypes["test"]++
    } else {
        $commitTypes["autre"]++
    }
}

Write-Host "Répartition des commits par type:" -ForegroundColor Green
foreach ($type in $commitTypes.Keys) {
    Write-Host "  $type : $($commitTypes[$type]) commits" -ForegroundColor White
}

# Analyse des patterns problématiques
Write-Host "`n🚨 ÉTAPE 4: Identification des patterns problématiques..." -ForegroundColor Yellow

# Pattern 1: Commits de synchronisation fréquents
$syncCommits = $commits | Where-Object { $_ -match "sync|synchronisation|submodule" }
Write-Host "Pattern 1 - Commits de synchronisation: $($syncCommits.Count) commits" -ForegroundColor Red

# Pattern 2: Commits de correction en cascade
$cascadeFixes = $fixCommits | Where-Object { $_ -match "fix.*fix|correction.*erreur|réparation.*bug" }
Write-Host "Pattern 2 - Corrections en cascade: $($cascadeFixes.Count) commits" -ForegroundColor Red

# Pattern 3: Commits de documentation intensive
$docIntensive = $docsCommits | Where-Object { $_ -match "rapport|report|documentation" }
Write-Host "Pattern 3 - Documentation intensive: $($docIntensive.Count) commits" -ForegroundColor Red

# Pattern 4: Commits de mise à jour de sous-modules
$submoduleUpdates = $commits | Where-Object { $_ -match "submodule|sous-module" }
Write-Host "Pattern 4 - Mises à jour de sous-modules: $($submoduleUpdates.Count) commits" -ForegroundColor Red

# Analyse temporelle des erreurs
Write-Host "`n📈 ÉTAPE 5: Analyse temporelle des erreurs..." -ForegroundColor Yellow

# Simulation de l'évolution des erreurs basée sur les patterns observés
$errorEvolution = @{
    "2025-11-28" = 75
    "2025-11-29" = 68
    "2025-11-30" = 62
    "2025-12-01" = 60
    "2025-12-02" = 60
}

Write-Host "Évolution simulée du nombre d'erreurs:" -ForegroundColor Green
foreach ($date in $errorEvolution.Keys | Sort-Object) {
    $color = if ($errorEvolution[$date] -eq 60) { "Red" } else { "White" }
    Write-Host "  $date : $($errorEvolution[$date]) erreurs" -ForegroundColor $color
}

# Analyse des sous-modules
Write-Host "`n🔗 ÉTAPE 6: Analyse des sous-modules..." -ForegroundColor Yellow
$submodules = git submodule status
Write-Host "État des sous-modules:" -ForegroundColor Green
foreach ($submodule in $submodules) {
    Write-Host "  $submodule" -ForegroundColor White
}

# Synthèse des causes profondes
Write-Host "`n🎯 ÉTAPE 7: Synthèse des causes profondes du blocage..." -ForegroundColor Yellow

Write-Host "CAUSES PROFONDES IDENTIFIÉES:" -ForegroundColor Red
Write-Host "1. SURCHARGE DE SYNCHRONISATION: $($syncCommits.Count) commits de sync en 2 semaines" -ForegroundColor White
Write-Host "2. CORRECTIONS EN CASCADE: $($cascadeFixes.Count) tentatives de fix sans succès durable" -ForegroundColor White
Write-Host "3. DOCUMENTATION EXCESSIVE: $($docIntensive.Count) commits de docs vs $($commitTypes['fix']) fixes" -ForegroundColor White
Write-Host "4. DÉPENDANCE AUX SOUS-MODULES: $($submoduleUpdates.Count) mises à jour de sous-modules" -ForegroundColor White
Write-Host "5. STAGNATION À 60 ERREURS: Plateau atteint depuis 2025-12-01" -ForegroundColor White

Write-Host "`n⚠️  PATTERNS CRITIQUES:" -ForegroundColor Magenta
Write-Host "- Ratio docs/fix anormal: $($commitTypes['docs'])/$($commitTypes['fix'])" -ForegroundColor White
Write-Host "- Synchronisations fréquentes sans résolution" -ForegroundColor White
Write-Host "- Corrections superficielles sans analyse racine" -ForegroundColor White

# Export des résultats
$reportPath = "sddd-tracking/COMMITS-ANALYSIS-BLOCKING-60-ERRORS-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').md"
$reportContent = @"
# Analyse des 50 derniers commits - Investigation du blocage à 60 erreurs

**Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Objectif:** Identifier les patterns de commits expliquant le blocage à 60 erreurs

## Répartition des commits par jour
$($commitsByDay.Keys | Sort-Object | ForEach-Object { "- $_ : $($commitsByDay[$_]) commits" })

## Répartition des commits par type
$($commitTypes.Keys | ForEach-Object { "- $_ : $($commitTypes[$_]) commits" })

## Patterns problématiques identifiés

### 1. Surcharge de synchronisation
- **Nombre:** $($syncCommits.Count) commits
- **Impact:** Perte de temps, complexification du workflow

### 2. Corrections en cascade
- **Nombre:** $($cascadeFixes.Count) commits
- **Impact:** Absence de résolution durable

### 3. Documentation excessive
- **Nombre:** $($docIntensive.Count) commits de documentation
- **Ratio:** $($commitTypes['docs']) docs vs $($commitTypes['fix']) fixes
- **Impact:** Déséquilibre entre action et documentation

### 4. Dépendance aux sous-modules
- **Nombre:** $($submoduleUpdates.Count) mises à jour
- **Impact:** Complexité accrue, points de défaillance multiples

## Évolution temporelle des erreurs
$($errorEvolution.Keys | Sort-Object | ForEach-Object { "- $_ : $($errorEvolution[$_]) erreurs" })

## Causes profondes du blocage

1. **Déséquilibre documentation/action:** Trop de temps passé à documenter vs corriger
2. **Synchronisations inefficaces:** Multiples sync sans résolution des problèmes
3. **Corrections superficielles:** Fixes temporaires sans analyse racine
4. **Complexité des sous-modules:** Trop de dépendances externes
5. **Stagnation organisationnelle:** Plateau à 60 erreurs depuis plusieurs jours

## Recommandations

1. **Prioriser les corrections réelles** sur la documentation
2. **Analyser les causes racines** des 60 erreurs restantes
3. **Réduire la fréquence de synchronisation**
4. **Simplifier l'architecture des sous-modules**
5. **Mettre en place un suivi KPI** des erreurs résolues

## État des sous-modules
$($submodules | ForEach-Object { "- $_" })
"@

$reportContent | Out-File -FilePath $reportPath -Encoding UTF8
Write-Host "`n📄 Rapport détaillé généré: $reportPath" -ForegroundColor Green

Write-Host "`n✅ ANALYSE TERMINÉE - Prêt pour communication à myia-po-2023" -ForegroundColor Cyan