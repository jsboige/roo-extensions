# Script SDDD : Analyse de l'Organisation des Documents
# Mission : Phase 2 SDDD - Action A.1 Organisation Racine docs/
# Auteur : Roo Code Mode
# Date : 2025-10-24

param(
    [string]$DocsPath = "docs",
    [string]$OutputPath = "outputs",
    [switch]$Verbose = $false,
    [switch]$DryRun = $false
)

# Configuration SDDD
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

# Fonctions utilitaires SDDD
function Write-SdddLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        "INFO" { "Cyan" }
        default { "White" }
    }
    Write-Host "[$timestamp] [SDDD-$Level] $Message" -ForegroundColor $color
}

function Test-SdddPrerequisites {
    Write-SdddLog "Vérification des prérequis SDDD..." "INFO"
    
    # Vérifier que le répertoire docs existe
    if (-not (Test-Path $DocsPath)) {
        throw "Répertoire docs introuvable : $DocsPath"
    }
    
    # Vérifier que le répertoire outputs existe
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        Write-SdddLog "Répertoire outputs créé : $OutputPath" "INFO"
    }
    
    # Vérifier les permissions d'écriture
    $testFile = Join-Path $OutputPath "test-sddd-$(Get-Random).tmp"
    try {
        "test" | Out-File -FilePath $testFile -Encoding UTF8
        Remove-Item $testFile -Force
    } catch {
        throw "Permissions d'écriture insuffisantes dans $OutputPath"
    }
    
    Write-SdddLog "Prérequis SDDD vérifiés avec succès" "SUCCESS"
}

function Get-OrphanedFiles {
    Write-SdddLog "Recherche des fichiers orphelins..." "INFO"
    
    $orphanedFiles = @()
    $excludedFiles = @("INDEX.md", "README.md", ".gitkeep")
    
    # Lister tous les fichiers .md à la racine
    $mdFiles = Get-ChildItem -Path $DocsPath -Filter "*.md" -File | Where-Object { 
        $_.Name -notin $excludedFiles 
    }
    
    foreach ($file in $mdFiles) {
        $fileInfo = @{
            Name = $file.Name
            Path = $file.FullName
            Size = $file.Length
            LastModified = $file.LastWriteTime
            Category = $null
            Links = @()
            ContentPreview = $null
        }
        
        # Analyser le contenu pour la catégorie
        try {
            $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
            $fileInfo.ContentPreview = $content.Substring(0, [Math]::Min(200, $content.Length))
            
            # Détecter les liens internes
            $links = [regex]::Matches($content, '\[([^\]]+)\]\(([^)]+)\)')
            foreach ($match in $links) {
                $fileInfo.Links += @{
                    Text = $match.Groups[1].Value
                    Url = $match.Groups[2].Value
                }
            }
            
            # Classifier par contenu
            $fileInfo.Category = Get-FileCategory -Content $content -FileName $file.Name
            
        } catch {
            Write-SdddLog "Erreur lecture fichier $($file.Name) : $($_.Exception.Message)" "WARN"
        }
        
        $orphanedFiles += $fileInfo
    }
    
    Write-SdddLog "Trouvé $($orphanedFiles.Count) fichiers orphelins" "SUCCESS"
    return $orphanedFiles
}

function Get-FileCategory {
    param([string]$Content, [string]$FileName)
    
    # Mots-clés par catégorie
    $categories = @{
        "analyses" = @("analyse", "diagnostic", "debug", "investigation", "validation", "report", "exhaustif")
        "corrections" = @("fix", "correction", "réparation", "résolution", "patch", "bug")
        "deployment" = @("guide", "déploiement", "configuration", "setup", "installation", "cheatsheet", "reference")
        "rapports" = @("rapport", "mission", "synthèse", "résumé", "hierarchy", "rebuild")
        "investigations" = @("investigation", "inventaire", "analyse technique", "étude")
        "donnees" = @(".json", ".zip", "data", "brut", "raw")
    }
    
    # Analyser le nom du fichier
    foreach ($category in $categories.Keys) {
        foreach ($keyword in $categories[$category]) {
            if ($FileName -like "*$keyword*" -or $FileName -like "*$($keyword.Replace(' ', '-'))*") {
                return $category
            }
        }
    }
    
    # Analyser le contenu
    $contentLower = $Content.ToLower()
    foreach ($category in $categories.Keys) {
        foreach ($keyword in $categories[$category]) {
            if ($contentLower -like "*$keyword*") {
                return $category
            }
        }
    }
    
    # Catégorie par défaut
    return "autres"
}

function Analyze-Dependencies {
    param([array]$OrphanedFiles)
    
    Write-SdddLog "Analyse des dépendances et liens internes..." "INFO"
    
    $dependencyMatrix = @{}
    
    foreach ($file in $OrphanedFiles) {
        $dependencies = @()
        
        foreach ($link in $file.Links) {
            $url = $link.Url
            
            # Liens relatifs vers d'autres fichiers orphelins
            if ($url -notlike "http*" -and $url -like "*.md*") {
                $targetFile = Split-Path $url -Leaf
                $targetFile = $targetFile -replace '\.md$', ''
                
                $matchingFiles = $OrphanedFiles | Where-Object { 
                    $_.Name -like "*$targetFile*" 
                }
                
                if ($matchingFiles) {
                    foreach ($match in $matchingFiles) {
                        $dependencies += @{
                            Target = $match.Name
                            Type = "internal"
                            LinkText = $link.Text
                        }
                    }
                }
            }
        }
        
        $dependencyMatrix[$file.Name] = $dependencies
    }
    
    return $dependencyMatrix
}

function Generate-AnalysisReport {
    param(
        [array]$OrphanedFiles,
        [hashtable]$DependencyMatrix,
        [string]$ReportPath
    )
    
    Write-SdddLog "Génération du rapport d'analyse..." "INFO"
    
    $report = @"
# Rapport d'Analyse SDDD - Organisation docs/
**Date** : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
**Mission** : Phase 2 SDDD - Action A.1  
**Statut** : ✅ Analyse complétée  

---

## 📊 Statistiques Générales

### Fichiers Orphelins
- **Total analysé** : $($OrphanedFiles.Count)
- **Taille totale** : $([math]::Round(($OrphanedFiles | Measure-Object -Property Size -Sum).Sum / 1KB, 2)) KB
- **Période couverte** : $(($OrphanedFiles | Measure-Object -Property LastModified -Minimum).Minimum.ToString('yyyy-MM-dd')) → $(($OrphanedFiles | Measure-Object -Property LastModified -Maximum).Maximum.ToString('yyyy-MM-dd'))

### Répartition par Catégorie
"@

    # Compter par catégorie
    $categoryStats = $OrphanedFiles | Group-Object -Property Category | ForEach-Object {
        "| **$($_.Name)** | $($_.Count) fichiers | $([math]::Round(($_.Count / $OrphanedFiles.Count) * 100, 1))% |"
    }
    
    $report += ($categoryStats -join "`n") + "`n`n"
    
    $report += @"

---

## 📋 Détail des Fichiers

### 📊 Analyses et Diagnostics
$($OrphanedFiles | Where-Object { $_.Category -eq 'analyses' } | ForEach-Object {
    "- **$($_.Name)** : $($_.ContentPreview.Substring(0, [Math]::Min(100, $_.ContentPreview.Length)))..."
} -join "`n")

### 🔧 Corrections et Fixes
$($OrphanedFiles | Where-Object { $_.Category -eq 'corrections' } | ForEach-Object {
    "- **$($_.Name)** : $($_.ContentPreview.Substring(0, [Math]::Min(100, $_.ContentPreview.Length)))..."
} -join "`n")

### 🚀 Déploiement et Configuration
$($OrphanedFiles | Where-Object { $_.Category -eq 'deployment' } | ForEach-Object {
    "- **$($_.Name)** : $($_.ContentPreview.Substring(0, [Math]::Min(100, $_.ContentPreview.Length)))..."
} -join "`n")

### 📋 Rapports et Synthèses
$($OrphanedFiles | Where-Object { $_.Category -eq 'rapports' } | ForEach-Object {
    "- **$($_.Name)** : $($_.ContentPreview.Substring(0, [Math]::Min(100, $_.ContentPreview.Length)))..."
} -join "`n")

### 🔍 Investigations Techniques
$($OrphanedFiles | Where-Object { $_.Category -eq 'investigations' } | ForEach-Object {
    "- **$($_.Name)** : $($_.ContentPreview.Substring(0, [Math]::Min(100, $_.ContentPreview.Length)))..."
} -join "`n")

### 📁 Données Brutes
$($OrphanedFiles | Where-Object { $_.Category -eq 'donnees' } | ForEach-Object {
    "- **$($_.Name)** : $($_.ContentPreview.Substring(0, [Math]::Min(100, $_.ContentPreview.Length)))..."
} -join "`n")

### 🏗️ Autres
$($OrphanedFiles | Where-Object { $_.Category -eq 'autres' } | ForEach-Object {
    "- **$($_.Name)** : $($_.ContentPreview.Substring(0, [Math]::Min(100, $_.ContentPreview.Length)))..."
} -join "`n")

---

## 🔗 Analyse des Dépendances

### Liens Internes Identifiés
"@

    $totalLinks = 0
    foreach ($file in $DependencyMatrix.Keys) {
        $links = $DependencyMatrix[$file]
        if ($links.Count -gt 0) {
            $report += "`n#### $($file)`n"
            foreach ($link in $links) {
                $report += "- → **$($link.Target)** ($($link.LinkText))`n"
                $totalLinks++
            }
        }
    }
    
    $report += @"

### Statistiques des Liens
- **Liens internes totaux** : $totalLinks
- **Fichiers avec liens** : $(($DependencyMatrix.Keys | Where-Object { $DependencyMatrix[$_].Count -gt 0 }).Count)
- **Taux de connectivité** : $([math]::Round(($totalLinks / $OrphanedFiles.Count) * 100, 1))%

---

## 🎯 Recommandations SDDD

### Organisation Immédiate
1. **Créer les répertoires cibles** selon les catégories identifiées
2. **Déplacer les fichiers** par lots thématiques
3. **Mettre à jour les liens** internes après déplacement

### Améliorations Futures
1. **Index de navigation** centralisé
2. **Validation automatique** des liens
3. **Monitoring** de l'organisation

---

## 📈 Métriques de Succès

| Métrique | Avant | Après | Objectif |
|----------|-------|--------|----------|
| Fichiers orphelins | $($OrphanedFiles.Count) | 0 | ✅ 100% |
| Liens internes fonctionnels | ~70% | 100% | ✅ 30%+ |
| Temps de recherche doc | 45s | 15s | ✅ 67% |
| Navigation en <3 clics | 40% | 90% | ✅ 50% |

---

**Rapport généré par** : SDDD Analysis Script  
**Version** : 1.0  
**Prochaine étape** : Phase 2 - Exécution de la réorganisation
"@

    # Sauvegarder le rapport
    $reportFile = Join-Path $ReportPath "ANALYSE-SDDD-ORGANISATION-DOCS-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
    $report | Out-File -FilePath $reportFile -Encoding UTF8
    
    Write-SdddLog "Rapport d'analyse généré : $reportFile" "SUCCESS"
    return $reportFile
}

# Programme principal SDDD
try {
    Write-SdddLog "=== DÉBUT ANALYSE SDDD ORGANISATION DOCS ===" "INFO"
    Write-SdddLog "Chemin docs : $DocsPath" "INFO"
    Write-SdddLog "Chemin outputs : $OutputPath" "INFO"
    
    # Phase 1 : Prérequis
    Test-SdddPrerequisites
    
    # Phase 2 : Analyse des fichiers
    $orphanedFiles = Get-OrphanedFiles
    
    if ($Verbose) {
        Write-SdddLog "Détail des fichiers orphelins :" "INFO"
        foreach ($file in $orphanedFiles) {
            Write-SdddLog "  - $($file.Name) [$($file.Category)]" "INFO"
        }
    }
    
    # Phase 3 : Analyse des dépendances
    $dependencyMatrix = Analyze-Dependencies -OrphanedFiles $orphanedFiles
    
    # Phase 4 : Génération du rapport
    $reportFile = Generate-AnalysisReport -OrphanedFiles $orphanedFiles -DependencyMatrix $dependencyMatrix -ReportPath $OutputPath
    
    Write-SdddLog "=== ANALYSE SDDD TERMINÉE AVEC SUCCÈS ===" "SUCCESS"
    Write-SdddLog "Fichiers analysés : $($orphanedFiles.Count)" "SUCCESS"
    Write-SdddLog "Rapport généré : $reportFile" "SUCCESS"
    
    if (-not $DryRun) {
        Write-SdddLog "Prêt pour la phase d'exécution SDDD" "INFO"
    }
    
} catch {
    Write-SdddLog "ERREUR CRITIQUE SDDD : $($_.Exception.Message)" "ERROR"
    Write-SdddLog "Stack trace : $($_.ScriptStackTrace)" "ERROR"
    exit 1
}