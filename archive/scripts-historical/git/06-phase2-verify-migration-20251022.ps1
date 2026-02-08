# ================================================================================================
# Script: Phase 2.5 - Vérification Migration sync_roo_environment.ps1
# ================================================================================================
# Description: Compare 5 versions historiques (stashs) avec la version actuelle (RooSync/)
#              pour identifier et récupérer les corrections manquantes
#
# Auteur: Roo Code (Mode Complex)
# Date: 2025-10-22
# Version: 1.0.0
# ================================================================================================

param(
    [switch]$Verbose = $false,
    [switch]$GenerateHtml = $false
)

# Configuration UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# Couleurs et styles
$Colors = @{
    Header = 'Cyan'
    Success = 'Green'
    Warning = 'Yellow'
    Error = 'Red'
    Info = 'White'
    Highlight = 'Magenta'
}

function Write-ColorLog {
    param(
        [string]$Message,
        [string]$Color = 'White',
        [switch]$NoNewline
    )
    Write-Host $Message -ForegroundColor $Color -NoNewline:$NoNewline
}

Write-ColorLog "`n╔════════════════════════════════════════════════════════════════════════════════╗" $Colors.Header
Write-ColorLog "║         VÉRIFICATION MIGRATION sync_roo_environment.ps1 - Phase 2.5           ║" $Colors.Header
Write-ColorLog "╚════════════════════════════════════════════════════════════════════════════════╝`n" $Colors.Header

# Chemins
$WorkDir = "docs/git/phase2-migration-check"
$CurrentFile = Join-Path $WorkDir "current-version.ps1"
$StashFiles = @(
    @{ Index = 1; File = Join-Path $WorkDir "stash1-version.ps1" },
    @{ Index = 5; File = Join-Path $WorkDir "stash5-version.ps1" },
    @{ Index = 7; File = Join-Path $WorkDir "stash7-version.ps1" },
    @{ Index = 8; File = Join-Path $WorkDir "stash8-version.ps1" },
    @{ Index = 9; File = Join-Path $WorkDir "stash9-version.ps1" }
)

# Vérification des fichiers
Write-ColorLog "🔍 Vérification des fichiers sources..." $Colors.Info
$allFilesExist = $true
if (-not (Test-Path $CurrentFile)) {
    Write-ColorLog "   ❌ Fichier current-version.ps1 manquant!" $Colors.Error
    $allFilesExist = $false
}

foreach ($stash in $StashFiles) {
    if (-not (Test-Path $stash.File)) {
        Write-ColorLog "   ❌ Fichier stash$($stash.Index)-version.ps1 manquant!" $Colors.Error
        $allFilesExist = $false
    }
}

if (-not $allFilesExist) {
    Write-ColorLog "`n❌ Fichiers manquants détectés. Exécutez d'abord l'extraction." $Colors.Error
    exit 1
}

Write-ColorLog "   ✅ Tous les fichiers sources sont présents`n" $Colors.Success

# Lecture de la version actuelle
Write-ColorLog "📖 Lecture de la version actuelle..." $Colors.Info
$currentContent = Get-Content $CurrentFile -Encoding UTF8
$currentLineCount = $currentContent.Count
Write-ColorLog "   Version actuelle: $currentLineCount lignes`n" $Colors.Success

# Structure pour stocker les résultats
$analysisResults = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    CurrentVersion = @{
        File = "RooSync/sync_roo_environment.ps1"
        Lines = $currentLineCount
        Size = (Get-Item $CurrentFile).Length
    }
    Stashs = @()
    Summary = @{
        TotalUniqueLines = 0
        TotalAddedInStashs = 0
        TotalRemovedFromCurrent = 0
        StashsAnalyzed = 5
    }
}

# Fonction pour analyser le type de ligne
function Get-LineType {
    param([string]$Line)
    
    $trimmed = $Line.Trim()
    
    if ($trimmed -eq "" -or $trimmed -eq "") {
        return "empty"
    }
    if ($trimmed.StartsWith("#")) {
        return "comment"
    }
    if ($trimmed -match "^(param|function|if|else|foreach|while|try|catch|finally)\b") {
        return "control"
    }
    if ($trimmed -match "^(\$\w+\s*=|Set-|Get-|Write-|New-|Remove-|Test-)") {
        return "code"
    }
    if ($trimmed -match "^(}|{|\))$") {
        return "structure"
    }
    
    return "code"
}

# Fonction pour extraire le contexte autour d'une ligne
function Get-LineContext {
    param(
        [array]$AllLines,
        [int]$LineIndex,
        [int]$ContextSize = 2
    )
    
    $startIdx = [Math]::Max(0, $LineIndex - $ContextSize)
    $endIdx = [Math]::Min($AllLines.Count - 1, $LineIndex + $ContextSize)
    
    $context = @()
    for ($i = $startIdx; $i -le $endIdx; $i++) {
        $marker = if ($i -eq $LineIndex) { ">>>" } else { "   " }
        $context += "$marker L$($i + 1): $($AllLines[$i])"
    }
    
    return $context -join "`n"
}

# Comparaison pour chaque stash
Write-ColorLog "🔬 ANALYSE DIFFÉRENTIELLE PAR STASH`n" $Colors.Header
Write-ColorLog "═══════════════════════════════════════════════════════════════════════════════`n" $Colors.Header

foreach ($stash in $StashFiles) {
    $stashIndex = $stash.Index
    $stashFile = $stash.File
    
    Write-ColorLog "`n┌─────────────────────────────────────────────────────────────────────────────┐" $Colors.Highlight
    Write-ColorLog "│ STASH @{$stashIndex} - Analyse en cours..." $Colors.Highlight
    Write-ColorLog "└─────────────────────────────────────────────────────────────────────────────┘`n" $Colors.Highlight
    
    # Lecture du contenu du stash
    $stashContent = Get-Content $stashFile -Encoding UTF8
    $stashLineCount = $stashContent.Count
    
    Write-ColorLog "   📊 Statistiques fichier:" $Colors.Info
    Write-ColorLog "      • Lignes: $stashLineCount" $Colors.Info
    Write-ColorLog "      • Taille: $([math]::Round((Get-Item $stashFile).Length / 1KB, 2)) KB" $Colors.Info
    Write-ColorLog "      • Delta lignes vs current: $($stashLineCount - $currentLineCount)" $Colors.Info
    
    # Comparaison ligne par ligne
    Write-ColorLog "`n   🔍 Comparaison différentielle..." $Colors.Info
    
    $diff = Compare-Object -ReferenceObject $stashContent -DifferenceObject $currentContent -IncludeEqual
    
    # Lignes uniques dans le stash (absentes dans current)
    $uniqueInStash = $diff | Where-Object { $_.SideIndicator -eq '<=' }
    
    # Lignes uniques dans current (absentes dans stash)
    $uniqueInCurrent = $diff | Where-Object { $_.SideIndicator -eq '=>' }
    
    # Lignes communes
    $commonLines = $diff | Where-Object { $_.SideIndicator -eq '==' }
    
    Write-ColorLog "      ✅ Lignes communes: $($commonLines.Count)" $Colors.Success
    Write-ColorLog "      ⚠️  Lignes uniques dans stash@{$stashIndex}: $($uniqueInStash.Count)" $Colors.Warning
    Write-ColorLog "      ℹ️  Lignes uniques dans current: $($uniqueInCurrent.Count)" $Colors.Info
    
    # Analyse détaillée des lignes uniques dans le stash
    $uniqueAnalysis = @()
    
    if ($uniqueInStash.Count -gt 0) {
        Write-ColorLog "`n   🔬 Analyse des lignes uniques dans stash@{$stashIndex}:" $Colors.Header
        
        # Regrouper les lignes par type
        $linesByType = @{}
        
        foreach ($line in $uniqueInStash) {
            $lineText = $line.InputObject
            $lineType = Get-LineType -Line $lineText
            
            if (-not $linesByType.ContainsKey($lineType)) {
                $linesByType[$lineType] = @()
            }
            
            # Trouver l'index de la ligne dans le stash original
            $lineIndex = [array]::IndexOf($stashContent, $lineText)
            
            $lineAnalysis = @{
                Line = $lineText
                Type = $lineType
                Index = $lineIndex
                Context = if ($lineIndex -ge 0) { Get-LineContext -AllLines $stashContent -LineIndex $lineIndex } else { "N/A" }
            }
            
            $linesByType[$lineType] += $lineAnalysis
            $uniqueAnalysis += $lineAnalysis
        }
        
        # Afficher statistiques par type
        Write-ColorLog "      📋 Répartition par type:" $Colors.Info
        foreach ($type in $linesByType.Keys | Sort-Object) {
            $count = $linesByType[$type].Count
            Write-ColorLog "         • $type : $count lignes" $Colors.Info
        }
        
        # Afficher les 10 premières lignes uniques les plus intéressantes (code/control)
        $interestingLines = $uniqueAnalysis | Where-Object { $_.Type -in @('code', 'control', 'comment') } | Select-Object -First 10
        
        if ($interestingLines.Count -gt 0) {
            Write-ColorLog "`n      🎯 Lignes significatives (échantillon):" $Colors.Highlight
            foreach ($item in $interestingLines) {
                Write-ColorLog "         • L$($item.Index + 1) [$($item.Type)]:" $Colors.Info
                Write-ColorLog "           $($item.Line.Trim())" $Colors.Info
            }
        }
    }
    
    # Ajouter les résultats au rapport global
    $stashResult = @{
        Index = $stashIndex
        File = Split-Path $stashFile -Leaf
        Lines = $stashLineCount
        Size = (Get-Item $stashFile).Length
        Comparison = @{
            CommonLines = $commonLines.Count
            UniqueInStash = $uniqueInStash.Count
            UniqueInCurrent = $uniqueInCurrent.Count
            UniqueAnalysis = $uniqueAnalysis
        }
    }
    
    $analysisResults.Stashs += $stashResult
    $analysisResults.Summary.TotalUniqueLines += $uniqueInStash.Count
    
    Write-ColorLog "`n   ✅ Analyse de stash@{$stashIndex} terminée" $Colors.Success
}

# Calcul des statistiques globales
Write-ColorLog "`n`n╔════════════════════════════════════════════════════════════════════════════════╗" $Colors.Header
Write-ColorLog "║                           RÉSUMÉ GLOBAL D'ANALYSE                              ║" $Colors.Header
Write-ColorLog "╚════════════════════════════════════════════════════════════════════════════════╝`n" $Colors.Header

Write-ColorLog "📊 Statistiques globales:" $Colors.Info
Write-ColorLog "   • Stashs analysés: $($analysisResults.Summary.StashsAnalyzed)" $Colors.Info
Write-ColorLog "   • Total lignes uniques trouvées: $($analysisResults.Summary.TotalUniqueLines)" $Colors.Info
Write-ColorLog "   • Version actuelle: $currentLineCount lignes" $Colors.Info

# Top 3 des stashs avec le plus de lignes uniques
$topStashs = $analysisResults.Stashs | Sort-Object { $_.Comparison.UniqueInStash } -Descending | Select-Object -First 3

Write-ColorLog "`n🏆 Top 3 des stashs avec corrections potentielles:" $Colors.Highlight
foreach ($top in $topStashs) {
    Write-ColorLog "   $($top.Index). Stash @{$($top.Index)} : $($top.Comparison.UniqueInStash) lignes uniques" $Colors.Warning
}

# Génération du rapport JSON
$jsonReportPath = Join-Path $WorkDir "unique-lines-report.json"
Write-ColorLog "`n💾 Sauvegarde du rapport JSON..." $Colors.Info
$analysisResults | ConvertTo-Json -Depth 10 | Out-File $jsonReportPath -Encoding UTF8
Write-ColorLog "   ✅ Rapport JSON sauvegardé: $jsonReportPath" $Colors.Success

# Génération du rapport Markdown
$mdReportPath = Join-Path $WorkDir "migration-verification-report.md"
Write-ColorLog "`n📄 Génération du rapport Markdown..." $Colors.Info

$mdContent = @"
# RAPPORT VÉRIFICATION MIGRATION sync_roo_environment.ps1

**Date**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")  
**Script**: 06-phase2-verify-migration-20251022.ps1

---

## 📋 Résumé Exécutif

| Métrique | Valeur |
|----------|--------|
| **Versions historiques analysées** | $($analysisResults.Summary.StashsAnalyzed) |
| **Total lignes uniques identifiées** | $($analysisResults.Summary.TotalUniqueLines) |
| **Version actuelle** | $($analysisResults.CurrentVersion.Lines) lignes |
| **Taille version actuelle** | $([math]::Round($analysisResults.CurrentVersion.Size / 1KB, 2)) KB |

---

## 🔍 Analyse Détaillée par Stash

"@

foreach ($stash in $analysisResults.Stashs) {
    $mdContent += @"

### Stash @{$($stash.Index)}

**Fichier**: ``$($stash.File)``  
**Lignes**: $($stash.Lines)  
**Taille**: $([math]::Round($stash.Size / 1KB, 2)) KB

#### Statistiques de Comparaison

| Catégorie | Nombre de Lignes |
|-----------|------------------|
| Lignes communes | $($stash.Comparison.CommonLines) |
| **Lignes uniques dans stash** | **$($stash.Comparison.UniqueInStash)** |
| Lignes uniques dans current | $($stash.Comparison.UniqueInCurrent) |

"@

    if ($stash.Comparison.UniqueInStash -gt 0) {
        # Regrouper par type
        $byType = $stash.Comparison.UniqueAnalysis | Group-Object -Property Type | Sort-Object Count -Descending
        
        $mdContent += @"

#### Répartition des Lignes Uniques par Type

| Type | Nombre | Pourcentage |
|------|--------|-------------|
"@
        foreach ($group in $byType) {
            $percent = [math]::Round(($group.Count / $stash.Comparison.UniqueInStash) * 100, 1)
            $mdContent += "`n| $($group.Name) | $($group.Count) | $percent% |"
        }
        
        # Afficher échantillons de code
        $codeLines = $stash.Comparison.UniqueAnalysis | Where-Object { $_.Type -in @('code', 'control') } | Select-Object -First 5
        
        if ($codeLines.Count -gt 0) {
            $mdContent += @"

#### Échantillon de Code Unique (Top 5)

``````powershell
"@
            foreach ($line in $codeLines) {
                $mdContent += "`n# Ligne $($line.Index + 1) [$($line.Type)]`n$($line.Line)`n"
            }
            $mdContent += "``````"
        }
    } else {
        $mdContent += @"

> ✅ **Aucune ligne unique** - Ce stash ne contient aucune correction absente de la version actuelle.
"@
    }
}

$mdContent += @"

---

## 🎯 Recommandations

### Actions Prioritaires

"@

# Identifier les stashs nécessitant une attention
$highPriorityStashs = $analysisResults.Stashs | Where-Object { $_.Comparison.UniqueInStash -gt 20 }

if ($highPriorityStashs.Count -gt 0) {
    $mdContent += @"
**⚠️ HAUTE PRIORITÉ** - Les stashs suivants contiennent des corrections significatives:

"@
    foreach ($priority in $highPriorityStashs) {
        $mdContent += "- **Stash @{$($priority.Index)}**: $($priority.Comparison.UniqueInStash) lignes uniques`n"
    }
} else {
    $mdContent += "✅ **Aucune action urgente** - Les différences sont mineures.`n"
}

$mdContent += @"

### Prochaines Étapes

1. ✅ **VALIDATION COMPLÈTE** - Analyser manuellement les lignes uniques identifiées
2. 🔍 **CLASSIFICATION** - Déterminer pour chaque correction: Pertinent / Obsolète / Doublon
3. 💾 **RÉCUPÉRATION** - Appliquer les corrections pertinentes à RooSync/sync_roo_environment.ps1
4. ✅ **TESTS** - Valider la syntaxe PowerShell après modifications
5. 📝 **DOCUMENTATION** - Documenter toutes les décisions prises

---

## 📊 Annexe: Données Brutes

Consultez le fichier JSON pour les données complètes:  
``$jsonReportPath``

---

**Rapport généré automatiquement par**: 06-phase2-verify-migration-20251022.ps1
"@

$mdContent | Out-File $mdReportPath -Encoding UTF8
Write-ColorLog "   ✅ Rapport Markdown sauvegardé: $mdReportPath" $Colors.Success

# Résumé final
Write-ColorLog "`n`n╔════════════════════════════════════════════════════════════════════════════════╗" $Colors.Success
Write-ColorLog "║                          ✅ ANALYSE TERMINÉE AVEC SUCCÈS                       ║" $Colors.Success
Write-ColorLog "╚════════════════════════════════════════════════════════════════════════════════╝`n" $Colors.Success

Write-ColorLog "📁 Fichiers générés:" $Colors.Info
Write-ColorLog "   • Rapport JSON: $jsonReportPath" $Colors.Success
Write-ColorLog "   • Rapport Markdown: $mdReportPath" $Colors.Success

Write-ColorLog "`n🎯 Prochaine étape: Analyser le rapport Markdown pour identifier les corrections à récupérer`n" $Colors.Highlight