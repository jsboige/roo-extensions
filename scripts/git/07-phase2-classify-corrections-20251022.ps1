# ================================================================================================
# Script: Phase 2.5 - Classification des Corrections
# ================================================================================================
# Description: Analyse sémantique des lignes uniques pour classifier les corrections
#              en: CRITIQUE / IMPORTANT / UTILE / DOUBLON / OBSOLETE
#
# Auteur: Roo Code (Mode Complex)
# Date: 2025-10-22
# Version: 1.0.0
# ================================================================================================

param(
    [switch]$Verbose = $false
)

# Configuration UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# Couleurs
$Colors = @{
    Critical = 'Red'
    Important = 'Yellow'
    Useful = 'Cyan'
    Duplicate = 'Gray'
    Obsolete = 'DarkGray'
    Header = 'Magenta'
    Success = 'Green'
}

function Write-ColorLog {
    param([string]$Message, [string]$Color = 'White')
    Write-Host $Message -ForegroundColor $Color
}

Write-ColorLog "`n╔════════════════════════════════════════════════════════════════════════════════╗" $Colors.Header
Write-ColorLog "║              CLASSIFICATION SÉMANTIQUE DES CORRECTIONS - Phase 2.5            ║" $Colors.Header
Write-ColorLog "╚════════════════════════════════════════════════════════════════════════════════╝`n" $Colors.Header

# Chargement du rapport JSON
$WorkDir = "docs/git/phase2-migration-check"
$JsonReportPath = Join-Path $WorkDir "unique-lines-report.json"
$CurrentFile = Join-Path $WorkDir "current-version.ps1"

if (-not (Test-Path $JsonReportPath)) {
    Write-ColorLog "❌ Fichier JSON non trouvé: $JsonReportPath" $Colors.Critical
    exit 1
}

Write-ColorLog "📖 Chargement du rapport JSON..." $Colors.Success
$report = Get-Content $JsonReportPath -Raw | ConvertFrom-Json

# Lecture de la version actuelle pour comparaisons
$currentContent = Get-Content $CurrentFile -Encoding UTF8
Write-ColorLog "📖 Version actuelle chargée: $($currentContent.Count) lignes`n" $Colors.Success

# Patterns de classification
$ClassificationPatterns = @{
    Critical = @(
        # Gestion d'erreurs robuste
        @{ Pattern = '2>&1'; Reason = 'Capture stderr pour meilleure gestion erreurs Git' },
        @{ Pattern = '\$LASTEXITCODE'; Reason = 'Vérification code retour Git (critique)' },
        @{ Pattern = 'ErrorActionPreference.*Stop'; Reason = 'Gestion globale des erreurs' },
        @{ Pattern = 'try\s*{'; Reason = 'Gestion d''exception' },
        @{ Pattern = 'throw\s+'; Reason = 'Levée d''exception explicite' },
        
        # Sécurité
        @{ Pattern = '-Force'; Reason = 'Opération forcée (potentiel risque)' },
        @{ Pattern = 'Remove-Item'; Reason = 'Suppression de fichiers' },
        
        # Validation
        @{ Pattern = 'Test-Path.*-not'; Reason = 'Validation existence critique' },
        @{ Pattern = 'if\s*\(-not'; Reason = 'Condition négative (validation)' }
    )
    
    Important = @(
        # Logging amélioré
        @{ Pattern = 'Write-Host.*console.*visibility'; Reason = 'Amélioration visibilité logs scheduler' },
        @{ Pattern = 'Log-Message.*ERREUR'; Reason = 'Log d''erreur structuré' },
        @{ Pattern = 'Get-Date.*Format'; Reason = 'Timestamp formaté' },
        
        # Vérifications Git
        @{ Pattern = 'Get-Command\s+git'; Reason = 'Vérification disponibilité Git' },
        @{ Pattern = 'git\s+rev-parse\s+HEAD'; Reason = 'Capture état Git' },
        @{ Pattern = 'git\s+status.*porcelain'; Reason = 'Vérification état Git' },
        
        # Gestion de stash
        @{ Pattern = 'git\s+stash\s+list'; Reason = 'Liste des stashs' },
        @{ Pattern = 'StashApplied'; Reason = 'Tracking état stash' },
        
        # Nouveaux répertoires/fichiers
        @{ Pattern = 'New-Item.*Directory'; Reason = 'Création répertoire' },
        @{ Pattern = 'ConflictLogDir'; Reason = 'Gestion logs de conflits' }
    )
    
    Useful = @(
        # Commentaires explicatifs
        @{ Pattern = '#\s*---\s*Étape'; Reason = 'Commentaire de structure' },
        @{ Pattern = '#\s*Vérif'; Reason = 'Commentaire de vérification' },
        @{ Pattern = '#\s*ERREUR:'; Reason = 'Commentaire d''erreur' },
        
        # Messages informatifs
        @{ Pattern = 'Log-Message.*Début'; Reason = 'Message de début' },
        @{ Pattern = 'Log-Message.*réussi'; Reason = 'Message de succès' },
        
        # Variables de contexte
        @{ Pattern = '\$RepoPath'; Reason = 'Variable de chemin' },
        @{ Pattern = '\$LogFile'; Reason = 'Variable de log' }
    )
}

# Fonction de classification d'une ligne
function Classify-Line {
    param(
        [string]$Line,
        [string]$LineType,
        [array]$CurrentContent
    )
    
    $line = $Line.Trim()
    
    # Vérifier si déjà présent dans current (doublon)
    $isDuplicate = $CurrentContent | Where-Object { $_.Trim() -eq $line }
    if ($isDuplicate) {
        return @{
            Category = 'DOUBLON'
            Reason = 'Ligne déjà présente dans version actuelle'
            Priority = 0
            Color = $Colors.Duplicate
        }
    }
    
    # Vérifier si ligne vide ou structurelle basique
    if ($line -eq '' -or $line -match '^[{})]$') {
        return @{
            Category = 'OBSOLETE'
            Reason = 'Ligne structurelle ou vide'
            Priority = 0
            Color = $Colors.Obsolete
        }
    }
    
    # Classifier selon patterns critiques
    foreach ($pattern in $ClassificationPatterns.Critical) {
        if ($line -match $pattern.Pattern) {
            return @{
                Category = 'CRITIQUE'
                Reason = $pattern.Reason
                Priority = 100
                Color = $Colors.Critical
            }
        }
    }
    
    # Classifier selon patterns importants
    foreach ($pattern in $ClassificationPatterns.Important) {
        if ($line -match $pattern.Pattern) {
            return @{
                Category = 'IMPORTANT'
                Reason = $pattern.Reason
                Priority = 50
                Color = $Colors.Important
            }
        }
    }
    
    # Classifier selon patterns utiles
    foreach ($pattern in $ClassificationPatterns.Useful) {
        if ($line -match $pattern.Pattern) {
            return @{
                Category = 'UTILE'
                Reason = $pattern.Reason
                Priority = 25
                Color = $Colors.Useful
            }
        }
    }
    
    # Par défaut : OBSOLETE si commentaire basique ou ligne non identifiée
    if ($line.StartsWith('#') -and $line.Length -lt 20) {
        return @{
            Category = 'OBSOLETE'
            Reason = 'Commentaire court sans valeur ajoutée'
            Priority = 0
            Color = $Colors.Obsolete
        }
    }
    
    # Ligne non classifiée : UTILE par défaut
    return @{
        Category = 'UTILE'
        Reason = 'Ligne de code non critique mais potentiellement utile'
        Priority = 10
        Color = $Colors.Useful
    }
}

# Classification de chaque stash
$classificationResults = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Stashs = @()
    GlobalStats = @{
        TotalLines = 0
        Critical = 0
        Important = 0
        Useful = 0
        Duplicate = 0
        Obsolete = 0
    }
}

Write-ColorLog "🔬 CLASSIFICATION PAR STASH`n" $Colors.Header
Write-ColorLog "═══════════════════════════════════════════════════════════════════════════════`n" $Colors.Header

foreach ($stash in $report.Stashs) {
    Write-ColorLog "`n┌─────────────────────────────────────────────────────────────────────────────┐" $Colors.Header
    Write-ColorLog "│ STASH @{$($stash.Index)} - Classification en cours..." $Colors.Header
    Write-ColorLog "└─────────────────────────────────────────────────────────────────────────────┘" $Colors.Header
    
    $stashClassification = @{
        Index = $stash.Index
        TotalUniqueLines = $stash.Comparison.UniqueInStash
        Categories = @{
            Critical = @()
            Important = @()
            Useful = @()
            Duplicate = @()
            Obsolete = @()
        }
        Stats = @{
            Critical = 0
            Important = 0
            Useful = 0
            Duplicate = 0
            Obsolete = 0
        }
    }
    
    # Classifier chaque ligne unique
    foreach ($lineAnalysis in $stash.Comparison.UniqueAnalysis) {
        $classification = Classify-Line -Line $lineAnalysis.Line -LineType $lineAnalysis.Type -CurrentContent $currentContent
        
        $classifiedLine = @{
            Line = $lineAnalysis.Line
            Type = $lineAnalysis.Type
            Index = $lineAnalysis.Index
            Category = $classification.Category
            Reason = $classification.Reason
            Priority = $classification.Priority
        }
        
        $stashClassification.Categories[$classification.Category] += $classifiedLine
        $stashClassification.Stats[$classification.Category]++
        $classificationResults.GlobalStats[$classification.Category]++
    }
    
    $classificationResults.GlobalStats.TotalLines += $stashClassification.TotalUniqueLines
    
    # Afficher statistiques
    Write-ColorLog "`n   📊 Statistiques de classification:" $Colors.Success
    Write-ColorLog "      • CRITIQUE    : $($stashClassification.Stats.Critical) lignes" $Colors.Critical
    Write-ColorLog "      • IMPORTANT   : $($stashClassification.Stats.Important) lignes" $Colors.Important
    Write-ColorLog "      • UTILE       : $($stashClassification.Stats.Useful) lignes" $Colors.Useful
    Write-ColorLog "      • DOUBLON     : $($stashClassification.Stats.Duplicate) lignes" $Colors.Duplicate
    Write-ColorLog "      • OBSOLETE    : $($stashClassification.Stats.Obsolete) lignes" $Colors.Obsolete
    
    # Afficher échantillon des corrections critiques
    if ($stashClassification.Categories.Critical.Count -gt 0) {
        Write-ColorLog "`n   🚨 CORRECTIONS CRITIQUES (échantillon):" $Colors.Critical
        $topCritical = $stashClassification.Categories.Critical | Select-Object -First 3
        foreach ($item in $topCritical) {
            Write-ColorLog "      • L$($item.Index + 1): $($item.Reason)" $Colors.Critical
            Write-ColorLog "        $($item.Line.Trim())" $Colors.Critical
        }
    }
    
    # Afficher échantillon des corrections importantes
    if ($stashClassification.Categories.Important.Count -gt 0) {
        Write-ColorLog "`n   ⚠️  CORRECTIONS IMPORTANTES (échantillon):" $Colors.Important
        $topImportant = $stashClassification.Categories.Important | Select-Object -First 3
        foreach ($item in $topImportant) {
            Write-ColorLog "      • L$($item.Index + 1): $($item.Reason)" $Colors.Important
            Write-ColorLog "        $($item.Line.Trim())" $Colors.Important
        }
    }
    
    $classificationResults.Stashs += $stashClassification
    Write-ColorLog "`n   ✅ Classification de stash@{$($stash.Index)} terminée" $Colors.Success
}

# Résumé global
Write-ColorLog "`n`n╔════════════════════════════════════════════════════════════════════════════════╗" $Colors.Header
Write-ColorLog "║                         RÉSUMÉ GLOBAL DE CLASSIFICATION                        ║" $Colors.Header
Write-ColorLog "╚════════════════════════════════════════════════════════════════════════════════╝`n" $Colors.Header

Write-ColorLog "📊 Statistiques globales:" $Colors.Success
Write-ColorLog "   • Total lignes analysées : $($classificationResults.GlobalStats.TotalLines)" $Colors.Success
Write-ColorLog "   • CRITIQUES à récupérer  : $($classificationResults.GlobalStats.Critical)" $Colors.Critical
Write-ColorLog "   • IMPORTANTES à réviser  : $($classificationResults.GlobalStats.Important)" $Colors.Important
Write-ColorLog "   • UTILES optionnelles    : $($classificationResults.GlobalStats.Useful)" $Colors.Useful
Write-ColorLog "   • DOUBLONS détectés      : $($classificationResults.GlobalStats.Duplicate)" $Colors.Duplicate
Write-ColorLog "   • OBSOLETES à ignorer    : $($classificationResults.GlobalStats.Obsolete)" $Colors.Obsolete

# Calculer pourcentage à récupérer
$toRecover = $classificationResults.GlobalStats.Critical + $classificationResults.GlobalStats.Important
$percentToRecover = [math]::Round(($toRecover / $classificationResults.GlobalStats.TotalLines) * 100, 1)

Write-ColorLog "`n🎯 DÉCISION STRATÉGIQUE:" $Colors.Header
Write-ColorLog "   À RÉCUPÉRER: $toRecover lignes ($percentToRecover% du total)" $Colors.Critical

if ($percentToRecover -gt 20) {
    Write-ColorLog "   ⚠️  ALERTE: Pourcentage élevé de corrections à récupérer!" $Colors.Critical
    Write-ColorLog "   RECOMMANDATION: Analyse manuelle approfondie OBLIGATOIRE" $Colors.Critical
} elseif ($percentToRecover -gt 10) {
    Write-ColorLog "   ⚡ ATTENTION: Corrections significatives détectées" $Colors.Important
    Write-ColorLog "   RECOMMANDATION: Révision détaillée recommandée" $Colors.Important
} else {
    Write-ColorLog "   ✅ OK: Volume de corrections gérable" $Colors.Success
    Write-ColorLog "   RECOMMANDATION: Validation rapide possible" $Colors.Success
}

# Top 3 des stashs prioritaires
$topStashs = $classificationResults.Stashs | Sort-Object { $_.Stats.Critical + $_.Stats.Important } -Descending | Select-Object -First 3

Write-ColorLog "`n🏆 Top 3 des stashs PRIORITAIRES:" $Colors.Header
foreach ($top in $topStashs) {
    $priority = $top.Stats.Critical + $top.Stats.Important
    Write-ColorLog "   $($top.Index). Stash @{$($top.Index)} : $priority corrections (C:$($top.Stats.Critical) + I:$($top.Stats.Important))" $Colors.Important
}

# Sauvegarder le rapport de classification
$classificationJsonPath = Join-Path $WorkDir "classification-report.json"
Write-ColorLog "`n💾 Sauvegarde du rapport de classification..." $Colors.Success
$classificationResults | ConvertTo-Json -Depth 10 | Out-File $classificationJsonPath -Encoding UTF8
Write-ColorLog "   ✅ Rapport JSON sauvegardé: $classificationJsonPath" $Colors.Success

# Générer rapport Markdown détaillé
$mdPath = Join-Path $WorkDir "classification-detailed-report.md"
Write-ColorLog "`n📄 Génération du rapport Markdown détaillé..." $Colors.Success

$mdContent = @"
# RAPPORT DÉTAILLÉ DE CLASSIFICATION DES CORRECTIONS

**Date**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")  
**Script**: 07-phase2-classify-corrections-20251022.ps1

---

## 📊 Résumé Exécutif

| Catégorie | Nombre de Lignes | Pourcentage | Action |
|-----------|------------------|-------------|--------|
| **🚨 CRITIQUE** | **$($classificationResults.GlobalStats.Critical)** | **$([math]::Round(($classificationResults.GlobalStats.Critical / $classificationResults.GlobalStats.TotalLines) * 100, 1))%** | **✅ À RÉCUPÉRER IMPÉRATIVEMENT** |
| **⚠️  IMPORTANT** | **$($classificationResults.GlobalStats.Important)** | **$([math]::Round(($classificationResults.GlobalStats.Important / $classificationResults.GlobalStats.TotalLines) * 100, 1))%** | **🔍 À RÉVISER ET RÉCUPÉRER** |
| ℹ️  UTILE | $($classificationResults.GlobalStats.Useful) | $([math]::Round(($classificationResults.GlobalStats.Useful / $classificationResults.GlobalStats.TotalLines) * 100, 1))% | ⚡ Optionnel (amélioration) |
| 🔄 DOUBLON | $($classificationResults.GlobalStats.Duplicate) | $([math]::Round(($classificationResults.GlobalStats.Duplicate / $classificationResults.GlobalStats.TotalLines) * 100, 1))% | ❌ IGNORER (déjà présent) |
| ⚪ OBSOLETE | $($classificationResults.GlobalStats.Obsolete) | $([math]::Round(($classificationResults.GlobalStats.Obsolete / $classificationResults.GlobalStats.TotalLines) * 100, 1))% | ❌ IGNORER (non pertinent) |

**TOTAL**: $($classificationResults.GlobalStats.TotalLines) lignes analysées

---

## 🎯 Décision Stratégique

**Lignes à récupérer**: $toRecover / $($classificationResults.GlobalStats.TotalLines) (**$percentToRecover%**)

"@

if ($percentToRecover -gt 20) {
    $mdContent += @"
### ⚠️  ALERTE HAUTE PRIORITÉ

Le pourcentage de corrections à récupérer est **supérieur à 20%**.  
**Une analyse manuelle approfondie est OBLIGATOIRE avant tout drop de stash.**

"@
} elseif ($percentToRecover -gt 10) {
    $mdContent += @"
### ⚡ ATTENTION MODÉRÉE

Le pourcentage de corrections à récupérer est **entre 10% et 20%**.  
**Une révision détaillée est fortement recommandée.**

"@
} else {
    $mdContent += @"
### ✅ VOLUME GÉRABLE

Le pourcentage de corrections à récupérer est **inférieur à 10%**.  
**Validation rapide possible, mais vérification recommandée.**

"@
}

$mdContent += @"

---

## 📋 Analyse Détaillée par Stash

"@

foreach ($stash in $classificationResults.Stashs) {
    $mdContent += @"

### Stash @{$($stash.Index)}

**Total lignes uniques**: $($stash.TotalUniqueLines)

#### Répartition par Catégorie

| Catégorie | Nombre | Pourcentage |
|-----------|--------|-------------|
| 🚨 CRITIQUE | $($stash.Stats.Critical) | $([math]::Round(($stash.Stats.Critical / $stash.TotalUniqueLines) * 100, 1))% |
| ⚠️  IMPORTANT | $($stash.Stats.Important) | $([math]::Round(($stash.Stats.Important / $stash.TotalUniqueLines) * 100, 1))% |
| ℹ️  UTILE | $($stash.Stats.Useful) | $([math]::Round(($stash.Stats.Useful / $stash.TotalUniqueLines) * 100, 1))% |
| 🔄 DOUBLON | $($stash.Stats.Duplicate) | $([math]::Round(($stash.Stats.Duplicate / $stash.TotalUniqueLines) * 100, 1))% |
| ⚪ OBSOLETE | $($stash.Stats.Obsolete) | $([math]::Round(($stash.Stats.Obsolete / $stash.TotalUniqueLines) * 100, 1))% |

"@

    # Détailler les corrections CRITIQUES
    if ($stash.Categories.Critical.Count -gt 0) {
        $mdContent += @"

#### 🚨 CORRECTIONS CRITIQUES

"@
        foreach ($item in $stash.Categories.Critical) {
            $mdContent += @"
**Ligne $($item.Index + 1)** - Type: ``$($item.Type)``  
**Raison**: $($item.Reason)  
``````powershell
$($item.Line)
``````

"@
        }
    }
    
    # Détailler les corrections IMPORTANTES
    if ($stash.Categories.Important.Count -gt 0) {
        $mdContent += @"

#### ⚠️  CORRECTIONS IMPORTANTES

"@
        foreach ($item in $stash.Categories.Important | Select-Object -First 5) {
            $mdContent += @"
**Ligne $($item.Index + 1)** - Type: ``$($item.Type)``  
**Raison**: $($item.Reason)  
``````powershell
$($item.Line)
``````

"@
        }
        
        if ($stash.Categories.Important.Count -gt 5) {
            $mdContent += "`n*... et $($stash.Categories.Important.Count - 5) autres corrections importantes*`n"
        }
    }
}

$mdContent += @"

---

## 🏆 Recommandations Finales

### Stashs Prioritaires (par ordre décroissant)

"@

foreach ($top in $topStashs) {
    $priority = $top.Stats.Critical + $top.Stats.Important
    $mdContent += "1. **Stash @{$($top.Index)}** : $priority corrections prioritaires (C:$($top.Stats.Critical) + I:$($top.Stats.Important))`n"
}

$mdContent += @"

### Plan d'Action Recommandé

1. ✅ **PHASE 1: Récupération Critique**
   - Récupérer toutes les lignes classifiées CRITIQUE ($($classificationResults.GlobalStats.Critical) lignes)
   - Priorité absolue: Gestion d'erreurs robuste, sécurité

2. 🔍 **PHASE 2: Révision Importante**
   - Analyser manuellement les lignes IMPORTANTES ($($classificationResults.GlobalStats.Important) lignes)
   - Décider au cas par cas de leur pertinence

3. ⚡ **PHASE 3: Optimisation (Optionnel)**
   - Considérer les lignes UTILES ($($classificationResults.GlobalStats.Useful) lignes) si temps disponible
   - Amélioration de la qualité du code

4. ✅ **PHASE 4: Validation**
   - Tester la syntaxe PowerShell
   - Valider le bon fonctionnement
   - Créer commit dédié

5. 🧹 **PHASE 5: Nettoyage**
   - **SEULEMENT APRÈS validation utilisateur finale**
   - Dropper les 5 stashs en toute sécurité

---

**Rapport généré automatiquement par**: 07-phase2-classify-corrections-20251022.ps1
"@

$mdContent | Out-File $mdPath -Encoding UTF8
Write-ColorLog "   ✅ Rapport Markdown détaillé sauvegardé: $mdPath" $Colors.Success

Write-ColorLog "`n`n╔════════════════════════════════════════════════════════════════════════════════╗" $Colors.Success
Write-ColorLog "║                    ✅ CLASSIFICATION TERMINÉE AVEC SUCCÈS                      ║" $Colors.Success
Write-ColorLog "╚════════════════════════════════════════════════════════════════════════════════╝`n" $Colors.Success

Write-ColorLog "📁 Fichiers générés:" $Colors.Success
Write-ColorLog "   • Rapport JSON       : $classificationJsonPath" $Colors.Success
Write-ColorLog "   • Rapport Markdown   : $mdPath" $Colors.Success

Write-ColorLog "`n🎯 Prochaine étape: Analyser le rapport détaillé et récupérer les corrections CRITIQUES`n" $Colors.Header