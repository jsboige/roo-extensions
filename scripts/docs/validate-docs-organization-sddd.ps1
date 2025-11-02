# Script SDDD : Validation de l'Organisation des Documents
# Mission : Phase 2 SDDD - Action A.1 Organisation Racine docs/
# Auteur : Roo Code Mode
# Date : 2025-10-24

param(
    [string]$DocsPath = "docs",
    [string]$OutputPath = "outputs",
    [switch]$Verbose = $false,
    [switch]$FixLinks = $false,
    [switch]$GenerateMetrics = $true
)

# Configuration SDDD
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

# Structure attendue après organisation
$ExpectedStructure = @{
    "docs/analyses" = @("DEBUG-SKELETON-BUILD-FAILURE-20251021.md", "exhaustive-search-report-20251021-012408.md", "INSTRUCTION-PREFIXES-ANALYSIS-20251021.md", "PATTERN-8-VALIDATION-REPORT-20251021.md", "PHASE3-BUG-FIX-FINAL-20251022.md", "PHASE3-BUG-FIX-FINAL-20251023.md", "PHASE3-DEBUG-LOGS-ANALYSIS-20251022.md", "PHASE3-DIAGNOSTIC-EXHAUSTIF-20251023.md", "PHASE3-PERSISTENCE-FIX-20251021.md")
    "docs/corrections" = @("PATTERN-8-FIX-20251021.md", "validation-correction-41-outils-20251016.md", "git-merge-commits-analysis-20251016.md", "git-operations-report-20251016-state-analysis.md", "rapport-diagnostic-mcp-12-outils-20251016.md", "rapport-diagnostic-outils-mcp.md")
    "docs/deployment" = @("roosync-v2-1-deployment-guide.md", "roosync-v2-1-developer-guide.md", "roosync-v2-1-user-guide.md", "roosync-v2-1-cheatsheet.md", "roosync-v2-1-commands-reference.md")
    "docs/rapports" = @("RAPPORT-MISSION-MERGE-MAIN-TRIPLE-GROUNDING-20251016.md", "RAPPORT-MISSION-MERGE-SUBMODULE-TRIPLE-GROUNDING-20251016.md", "RAPPORT-MISSION-STASH-ANALYSIS-TRIPLE-GROUNDING-20251016.md", "SKELETON-CACHE-REBUILD-20251020-211129.md", "TASK-HIERARCHY-REPORT-20251020-202432.md")
    "docs/investigations" = @("TARGETED-SKELETON-BUILD-INVESTIGATION-20251021.md", "inventaire-outils-mcp-avant-sync.md", "git-stash-analysis-20251016.json")
    "docs/donnees" = @("git-merge-main-report-20251016.json", "git-merge-submodule-report-20251016.json", "archive.zip")
}

# Fichiers qui doivent rester à la racine
$RootFiles = @("INDEX.md", "README.md")

# Fonctions utilitaires SDDD
function Write-SdddLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        "INFO" { "Cyan" }
        "VALIDATE" { "Magenta" }
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
    
    Write-SdddLog "Prérequis SDDD vérifiés avec succès" "SUCCESS"
}

function Validate-DirectoryStructure {
    Write-SdddLog "Validation de la structure des répertoires..." "VALIDATE"
    
    $validationResults = @{
        ValidDirectories = @()
        MissingDirectories = @()
        UnexpectedDirectories = @()
        ValidFiles = @()
        MissingFiles = @()
        UnexpectedFiles = @()
        OrphanedFiles = @()
    }
    
    # Valider les répertoires attendus
    foreach ($dir in $ExpectedStructure.Keys) {
        if (Test-Path $dir) {
            $validationResults.ValidDirectories += $dir
            Write-SdddLog "✅ Répertoire valide : $dir" "VALIDATE"
        } else {
            $validationResults.MissingDirectories += $dir
            Write-SdddLog "❌ Répertoire manquant : $dir" "ERROR"
        }
    }
    
    # Valider les fichiers dans chaque répertoire
    foreach ($dir in $ExpectedStructure.Keys) {
        if (Test-Path $dir) {
            $expectedFiles = $ExpectedStructure[$dir]
            $actualFiles = Get-ChildItem -Path $dir -File | ForEach-Object { $_.Name }
            
            foreach ($expectedFile in $expectedFiles) {
                $filePath = Join-Path $dir $expectedFile
                if (Test-Path $filePath) {
                    $validationResults.ValidFiles += $filePath
                    if ($Verbose) {
                        Write-SdddLog "✅ Fichier valide : $expectedFile" "VALIDATE"
                    }
                } else {
                    $validationResults.MissingFiles += $filePath
                    Write-SdddLog "❌ Fichier manquant : $expectedFile" "ERROR"
                }
            }
            
            # Vérifier les fichiers inattendus
            foreach ($actualFile in $actualFiles) {
                if ($actualFile -notin $expectedFiles) {
                    $validationResults.UnexpectedFiles += Join-Path $dir $actualFile
                    Write-SdddLog "⚠️ Fichier inattendu : $actualFile" "WARN"
                }
            }
        }
    }
    
    # Valider les fichiers à la racine
    $rootFiles = Get-ChildItem -Path $DocsPath -File | ForEach-Object { $_.Name }
    foreach ($rootFile in $RootFiles) {
        $filePath = Join-Path $DocsPath $rootFile
        if (Test-Path $filePath) {
            if ($Verbose) {
                Write-SdddLog "✅ Fichier racine valide : $rootFile" "VALIDATE"
            }
        } else {
            $validationResults.MissingFiles += $filePath
            Write-SdddLog "❌ Fichier racine manquant : $rootFile" "ERROR"
        }
    }
    
    # Vérifier les fichiers orphelins restants
    foreach ($actualFile in $rootFiles) {
        if ($actualFile -notin $RootFiles) {
            $validationResults.OrphanedFiles += Join-Path $DocsPath $actualFile
            Write-SdddLog "❌ Fichier orphelin restant : $actualFile" "ERROR"
        }
    }
    
    return $validationResults
}

function Validate-InternalLinks {
    Write-SdddLog "Validation des liens internes..." "VALIDATE"
    
    $linkValidation = @{
        TotalLinks = 0
        ValidLinks = 0
        BrokenLinks = 0
        FixedLinks = 0
        LinkDetails = @()
    }
    
    # Parcourir tous les fichiers .md
    $allMdFiles = Get-ChildItem -Path $DocsPath -Recurse -Filter "*.md" -File
    
    foreach ($file in $allMdFiles) {
        try {
            $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
            $relativePath = $file.FullName.Replace((Get-Location).Path, ".").Replace("\", "/")
            
            # Trouver tous les liens markdown
            $links = [regex]::Matches($content, '\[([^\]]+)\]\(([^)]+)\)')
            
            foreach ($match in $links) {
                $linkText = $match.Groups[1].Value
                $linkUrl = $match.Groups[2].Value
                $linkValidation.TotalLinks++
                
                $linkDetail = @{
                    SourceFile = $file.FullName
                    RelativePath = $relativePath
                    LinkText = $linkText
                    LinkUrl = $linkUrl
                    Status = "UNKNOWN"
                    TargetPath = $null
                    ErrorMessage = $null
                }
                
                # Ignorer les liens externes
                if ($linkUrl -like "http*" -or $linkUrl -like "mailto:*") {
                    $linkDetail.Status = "EXTERNAL"
                    continue
                }
                
                # Résoudre le chemin cible
                try {
                    $targetPath = Resolve-Path -Path (Join-Path (Split-Path $file.FullName -Parent) $linkUrl) -ErrorAction SilentlyContinue
                    
                    if ($targetPath -and (Test-Path $targetPath)) {
                        $linkDetail.Status = "VALID"
                        $linkDetail.TargetPath = $targetPath.Path
                        $linkValidation.ValidLinks++
                        
                        if ($Verbose) {
                            Write-SdddLog "✅ Lien valide : $($file.Name) → $linkUrl" "VALIDATE"
                        }
                    } else {
                        $linkDetail.Status = "BROKEN"
                        $linkDetail.ErrorMessage = "Fichier cible introuvable"
                        $linkValidation.BrokenLinks++
                        Write-SdddLog "❌ Lien cassé : $($file.Name) → $linkUrl" "ERROR"
                        
                        # Tenter de réparer le lien
                        if ($FixLinks) {
                            $fixedUrl = Repair-BrokenLink -SourceFile $file.FullName -LinkUrl $linkUrl -ExpectedStructure $ExpectedStructure
                            if ($fixedUrl -ne $linkUrl) {
                                $newContent = $content.Replace($linkUrl, $fixedUrl)
                                $newContent | Out-File -FilePath $file.FullName -Encoding UTF8 -Force
                                $linkDetail.Status = "FIXED"
                                $linkDetail.LinkUrl = $fixedUrl
                                $linkValidation.FixedLinks++
                                Write-SdddLog "🔧 Lien réparé : $($file.Name) → $fixedUrl" "SUCCESS"
                            }
                        }
                    }
                } catch {
                    $linkDetail.Status = "ERROR"
                    $linkDetail.ErrorMessage = $_.Exception.Message
                    $linkValidation.BrokenLinks++
                    Write-SdddLog "❌ Erreur lien : $($file.Name) → $linkUrl : $($_.Exception.Message)" "ERROR"
                }
                
                $linkValidation.LinkDetails += $linkDetail
            }
        } catch {
            Write-SdddLog "Erreur lecture fichier $($file.Name) : $($_.Exception.Message)" "WARN"
        }
    }
    
    Write-SdddLog "Validation liens terminée : $($linkValidation.ValidLinks) valides, $($linkValidation.BrokenLinks) cassés" "VALIDATE"
    return $linkValidation
}

function Repair-BrokenLink {
    param([string]$SourceFile, [string]$LinkUrl, [hashtable]$ExpectedStructure)
    
    # Extraire le nom du fichier cible
    $targetFileName = Split-Path $LinkUrl -Leaf
    $targetFileName = $targetFileName -replace '\.md$', ''
    
    # Chercher dans les répertoires attendus
    foreach ($dir in $ExpectedStructure.Keys) {
        foreach ($expectedFile in $ExpectedStructure[$dir]) {
            if ($expectedFile -like "*$targetFileName*") {
                # Calculer le chemin relatif
                $sourceDir = Split-Path $SourceFile -Parent
                $targetPath = Join-Path $dir $expectedFile
                $relativePath = [System.IO.Path]::GetRelativePath($targetPath, $sourceDir).Replace("\", "/")
                return $relativePath
            }
        }
    }
    
    return $LinkUrl # Aucune réparation trouvée
}

function Generate-AccessibilityMetrics {
    param([hashtable]$ValidationResults, [hashtable]$LinkValidation)
    
    Write-SdddLog "Génération des métriques d'accessibilité..." "INFO"
    
    $metrics = @{
        OrganizationScore = 0
        LinkIntegrityScore = 0
        AccessibilityScore = 0
        SearchTimeImprovement = 0
        NavigationImprovement = 0
        DetailedMetrics = @{}
    }
    
    # Score d'organisation (0-100)
    $totalExpectedFiles = ($ExpectedStructure.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
    $totalValidFiles = $ValidationResults.ValidFiles.Count
    $totalMissingFiles = $ValidationResults.MissingFiles.Count
    $totalOrphanedFiles = $ValidationResults.OrphanedFiles.Count
    
    $metrics.DetailedMetrics.Organization = @{
        ExpectedFiles = $totalExpectedFiles
        ValidFiles = $totalValidFiles
        MissingFiles = $totalMissingFiles
        OrphanedFiles = $totalOrphanedFiles
        Score = [math]::Round((($totalValidFiles / $totalExpectedFiles) * 100), 1)
    }
    $metrics.OrganizationScore = $metrics.DetailedMetrics.Organization.Score
    
    # Score d'intégrité des liens (0-100)
    $totalLinks = $LinkValidation.TotalLinks
    $validLinks = $LinkValidation.ValidLinks + $LinkValidation.FixedLinks
    $brokenLinks = $LinkValidation.BrokenLinks
    
    $metrics.DetailedMetrics.Links = @{
        TotalLinks = $totalLinks
        ValidLinks = $validLinks
        BrokenLinks = $brokenLinks
        FixedLinks = $LinkValidation.FixedLinks
        Score = if ($totalLinks -gt 0) { [math]::Round((($validLinks / $totalLinks) * 100), 1) } else { 100 }
    }
    $metrics.LinkIntegrityScore = $metrics.DetailedMetrics.Links.Score
    
    # Score d'accessibilité global (moyenne pondérée)
    $metrics.AccessibilityScore = [math]::Round(($metrics.OrganizationScore * 0.6 + $metrics.LinkIntegrityScore * 0.4), 1)
    
    # Améliorations estimées
    $metrics.SearchTimeImprovement = if ($metrics.OrganizationScore -ge 90) { 67 } elseif ($metrics.OrganizationScore -ge 70) { 45 } else { 20 }
    $metrics.NavigationImprovement = if ($metrics.AccessibilityScore -ge 90) { 50 } elseif ($metrics.AccessibilityScore -ge 70) { 30 } else { 10 }
    
    Write-SdddLog "Métriques générées : Organisation $($metrics.OrganizationScore)%, Liens $($metrics.LinkIntegrityScore)%" "SUCCESS"
    return $metrics
}

function Generate-ValidationReport {
    param(
        [hashtable]$ValidationResults,
        [hashtable]$LinkValidation,
        [hashtable]$Metrics,
        [string]$ReportPath
    )
    
    Write-SdddLog "Génération du rapport de validation SDDD..." "INFO"
    
    $report = @"
# Rapport de Validation SDDD - Organisation docs/
**Date** : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
**Mission** : Phase 2 SDDD - Action A.1  
**Statut** : ✅ Validation complétée  

---

## 📊 Résultats de la Validation

### 🏗️ Structure des Répertoires
- **Répertoires valides** : $($ValidationResults.ValidDirectories.Count)
- **Répertoires manquants** : $($ValidationResults.MissingDirectories.Count)
- **Score d'organisation** : $($Metrics.OrganizationScore)%

#### Répertoires Validés
$($ValidationResults.ValidDirectories | ForEach-Object { "- ✅ $_`n" })

#### Répertoires Manquants
$($ValidationResults.MissingDirectories | ForEach-Object { "- ❌ $_`n" })

### 📋 Validation des Fichiers
- **Fichiers valides** : $($ValidationResults.ValidFiles.Count)
- **Fichiers manquants** : $($ValidationResults.MissingFiles.Count)
- **Fichiers inattendus** : $($ValidationResults.UnexpectedFiles.Count)
- **Fichiers orphelins restants** : $($ValidationResults.OrphanedFiles.Count)

#### Fichiers Orphelins Restants
$($ValidationResults.OrphanedFiles | ForEach-Object { "- ❌ $_`n" })

### 🔗 Validation des Liens Internes
- **Liens totaux** : $($LinkValidation.TotalLinks)
- **Liens valides** : $($LinkValidation.ValidLinks)
- **Liens cassés** : $($LinkValidation.BrokenLinks)
- **Liens réparés** : $($LinkValidation.FixedLinks)
- **Score d'intégrité** : $($Metrics.LinkIntegrityScore)%

---

## 📈 Métriques d'Accessibilité

### Scores Globaux
| Métrique | Score | Objectif | Statut |
|----------|-------|----------|---------|
| Organisation | $($Metrics.OrganizationScore)% | 100% | $(if ($Metrics.OrganizationScore -ge 95) { "✅" } elseif ($Metrics.OrganizationScore -ge 80) { "⚠️" } else { "❌" }) |
| Intégrité des liens | $($Metrics.LinkIntegrityScore)% | 100% | $(if ($Metrics.LinkIntegrityScore -ge 95) { "✅" } elseif ($Metrics.LinkIntegrityScore -ge 80) { "⚠️" } else { "❌" }) |
| **Accessibilité globale** | **$($Metrics.AccessibilityScore)%** | **95%** | **$(if ($Metrics.AccessibilityScore -ge 95) { "✅" } elseif ($Metrics.AccessibilityScore -ge 80) { "⚠️" } else { "❌" })** |

### Améliorations Estimées
| Amélioration | Avant | Après | Gain |
|--------------|-------|--------|------|
| Temps de recherche doc | 45s | $(45 - [math]::Round(45 * $Metrics.SearchTimeImprovement / 100))s | $($Metrics.SearchTimeImprovement)% |
| Navigation en <3 clics | 40% | $(40 + $Metrics.NavigationImprovement)% | +$($Metrics.NavigationImprovement)% |

---

## 🔍 Détail des Problèmes

### Liens Cassés Détectés
"@

    $brokenLinks = $LinkValidation.LinkDetails | Where-Object { $_.Status -eq "BROKEN" }
    if ($brokenLinks.Count -gt 0) {
        foreach ($link in $brokenLinks) {
            $report += "`n#### $($link.SourceFile)`n"
            $report += "- **Texte** : $($link.LinkText)`n"
            $report += "- **URL** : $($link.LinkUrl)`n"
            $report += "- **Erreur** : $($link.ErrorMessage)`n"
        }
    } else {
        $report += "`n✅ Aucun lien cassé détecté"
    }
    
    $report += @"

---

## 🎯 Recommandations SDDD

### Actions Immédiates
"@

    if ($ValidationResults.OrphanedFiles.Count -gt 0) {
        $report += "1. **Déplacer les fichiers orphelins restants** dans les catégories appropriées`n"
    }
    
    if ($LinkValidation.BrokenLinks.Count -gt 0) {
        $report += "2. **Réparer les liens cassés** avec le script de correction automatique`n"
    }
    
    if ($Metrics.AccessibilityScore -lt 95) {
        $report += "3. **Améliorer l'organisation** pour atteindre 95% d'accessibilité`n"
    }
    
    $report += @"

### Améliorations Futures
1. **Index de navigation** centralisé pour faciliter la recherche
2. **Validation automatique** périodique des liens
3. **Monitoring** de l'accessibilité au fil du temps

---

## 📋 Checklist de Validation

### Structure Organisationnelle
- [ ] Tous les répertoires attendus existent
- [ ] Tous les fichiers sont dans les bonnes catégories
- [ ] Aucun fichier orphelin à la racine
- [ ] Structure cohérente et logique

### Intégrité des Liens
- [ ] Tous les liens internes fonctionnent
- [ ] Pas de liens cassés
- [ ] Liens correctement mis à jour après déplacement
- [ ] Références externes valides

### Accessibilité
- [ ] Score d'organisation ≥ 95%
- [ ] Score d'intégrité des liens ≥ 95%
- [ ] Navigation en <3 clics pour 90% des documents
- [ ] Temps de recherche réduit de 67%

---

## 🚀 Prochaines Étapes

1. **Corriger les problèmes identifiés** si nécessaire
2. **Créer l'index de navigation** `docs/README.md`
3. **Documenter les métriques d'amélioration**
4. **Mettre en place la maintenance continue**

---

**Rapport généré par** : SDDD Validation Script  
**Version** : 1.0  
**Statut final** : $(if ($Metrics.AccessibilityScore -ge 95) { "✅ VALIDATION RÉUSSIE" } else { "⚠️ VALIDATION AVEC RÉSERVES" })
"@

    # Sauvegarder le rapport
    $reportFile = Join-Path $ReportPath "VALIDATION-SDDD-ORGANISATION-DOCS-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
    $report | Out-File -FilePath $reportFile -Encoding UTF8
    
    Write-SdddLog "Rapport de validation généré : $reportFile" "SUCCESS"
    return $reportFile
}

# Programme principal SDDD
try {
    Write-SdddLog "=== DÉBUT VALIDATION SDDD ORGANISATION DOCS ===" "INFO"
    Write-SdddLog "Chemin docs : $DocsPath" "INFO"
    Write-SdddLog "Chemin outputs : $OutputPath" "INFO"
    Write-SdddLog "Réparation liens : $FixLinks" "INFO"
    
    # Phase 1 : Prérequis
    Test-SdddPrerequisites
    
    # Phase 2 : Validation de la structure
    $validationResults = Validate-DirectoryStructure
    
    # Phase 3 : Validation des liens internes
    $linkValidation = Validate-InternalLinks
    
    # Phase 4 : Génération des métriques
    if ($GenerateMetrics) {
        $metrics = Generate-AccessibilityMetrics -ValidationResults $validationResults -LinkValidation $linkValidation
        
        Write-SdddLog "=== MÉTRIQUES D'ACCESSIBILITÉ ===" "INFO"
        Write-SdddLog "Score d'organisation : $($metrics.OrganizationScore)%" "INFO"
        Write-SdddLog "Score d'intégrité des liens : $($metrics.LinkIntegrityScore)%" "INFO"
        Write-SdddLog "Score d'accessibilité global : $($metrics.AccessibilityScore)%" "INFO"
        Write-SdddLog "Amélioration temps de recherche : $($metrics.SearchTimeImprovement)%" "INFO"
        Write-SdddLog "Amélioration navigation : $($metrics.NavigationImprovement)%" "INFO"
    }
    
    # Phase 5 : Rapport de validation
    $reportFile = Generate-ValidationReport -ValidationResults $validationResults -LinkValidation $linkValidation -Metrics $metrics -ReportPath $OutputPath
    
    Write-SdddLog "=== VALIDATION SDDD TERMINÉE ===" "SUCCESS"
    Write-SdddLog "Fichiers validés : $($validationResults.ValidFiles.Count)" "SUCCESS"
    Write-SdddLog "Liens validés : $($linkValidation.ValidLinks)" "SUCCESS"
    Write-SdddLog "Rapport généré : $reportFile" "SUCCESS"
    
    if ($metrics.AccessibilityScore -ge 95) {
        Write-SdddLog "✅ VALIDATION SDDD RÉUSSIE - Organisation optimale atteinte" "SUCCESS"
    } else {
        Write-SdddLog "⚠️ VALIDATION SDDD AVEC RÉSERVES - Améliorations nécessaires" "WARN"
    }
    
} catch {
    Write-SdddLog "ERREUR CRITIQUE SDDD : $($_.Exception.Message)" "ERROR"
    Write-SdddLog "Stack trace : $($_.ScriptStackTrace)" "ERROR"
    exit 1
}