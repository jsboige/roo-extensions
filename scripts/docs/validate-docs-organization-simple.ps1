# Script SDDD Simplifie : Validation Organisation docs/
# Mission : Phase 2 SDDD - Action A.1 Organisation Racine docs/
# Auteur : Roo Code Mode
# Date : 2025-10-24

param(
    [string]$DocsPath = "docs",
    [string]$OutputPath = "outputs",
    [switch]$Verbose = $false,
    [switch]$GenerateMetrics = $false,
    [switch]$FixLinks = $false
)

# Configuration SDDD
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

# Structure des categories attendues
$ExpectedCategories = @("analyses", "corrections", "deployment", "rapports", "investigations", "donnees", "divers")

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
    Write-SdddLog "Verification des prerequis SDDD..." "INFO"
    
    # Verifier que le repertoire docs existe
    if (-not (Test-Path $DocsPath)) {
        throw "Repertoire docs introuvable : $DocsPath"
    }
    
    # Verifier que le repertoire outputs existe
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        Write-SdddLog "Repertoire outputs cree : $OutputPath" "INFO"
    }
    
    Write-SdddLog "Prerequis SDDD verifies avec succes" "SUCCESS"
}

function Validate-DirectoryStructure {
    Write-SdddLog "Validation de la structure des repertoires..." "VALIDATE"
    
    $validationResults = @{
        ExpectedCategories = $ExpectedCategories
        ExistingCategories = @()
        MissingCategories = @()
        TotalFiles = 0
        OrphanedFiles = @()
        StructureValid = $true
    }
    
    # Verifier les categories attendues
    foreach ($category in $ExpectedCategories) {
        $categoryPath = Join-Path $DocsPath $category
        if (Test-Path $categoryPath) {
            $validationResults.ExistingCategories += $category
            $files = Get-ChildItem -Path $categoryPath -Filter "*.md" -File
            $validationResults.TotalFiles += $files.Count
            
            if ($Verbose) {
                Write-SdddLog "Categorie '$category' : $($files.Count) fichiers" "VALIDATE"
            }
        } else {
            $validationResults.MissingCategories += $category
            $validationResults.StructureValid = $false
            Write-SdddLog "Categorie manquante : $category" "WARN"
        }
    }
    
    # Verifier les fichiers orphelins a la racine
    $rootFiles = Get-ChildItem -Path $DocsPath -Filter "*.md" -File | Where-Object { 
        $_.Name -notin @("INDEX.md", "README.md") 
    }
    
    foreach ($file in $rootFiles) {
        $fileInfo = @{
            Name = $file.Name
            Path = $file.FullName
            Size = $file.Length
            LastModified = $file.LastWriteTime
        }
        $validationResults.OrphanedFiles += $fileInfo
    }
    
    if ($validationResults.OrphanedFiles.Count -gt 0) {
        $validationResults.StructureValid = $false
        Write-SdddLog "Fichiers orphelins detectes : $($validationResults.OrphanedFiles.Count)" "WARN"
    }
    
    $validationResults.TotalFiles += $validationResults.OrphanedFiles.Count
    
    Write-SdddLog "Validation structure terminee : $($validationResults.ExistingCategories.Count)/$($ExpectedCategories.Count) categories" "SUCCESS"
    return $validationResults
}

function Validate-InternalLinks {
    Write-SdddLog "Validation des liens internes..." "VALIDATE"
    
    $linkValidation = @{
        TotalFiles = 0
        TotalLinks = 0
        ValidLinks = 0
        BrokenLinks = 0
        UpdatedLinks = 0
        LinkDetails = @()
    }
    
    # Parcourir tous les fichiers Markdown
    $allMdFiles = Get-ChildItem -Path $DocsPath -Filter "*.md" -File -Recurse
    
    foreach ($file in $allMdFiles) {
        $linkValidation.TotalFiles++
        
        try {
            $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
            $links = [regex]::Matches($content, '\[([^\]]+)\]\(([^)]+)\)')
            
            foreach ($match in $links) {
                $linkValidation.TotalLinks++
                $linkText = $match.Groups[1].Value
                $linkTarget = $match.Groups[2].Value
                
                $linkInfo = @{
                    SourceFile = $file.Name
                    SourcePath = $file.FullName
                    LinkText = $linkText
                    LinkTarget = $linkTarget
                    IsValid = $false
                    TargetExists = $false
                    Updated = $false
                }
                
                # Verifier si le lien est valide
                if ($linkTarget -like "http*") {
                    # Lien externe - considere comme valide
                    $linkInfo.IsValid = $true
                    $linkInfo.TargetExists = $true
                    $linkValidation.ValidLinks++
                } elseif ($linkTarget -like "#*") {
                    # Lien d'ancre - considere comme valide
                    $linkInfo.IsValid = $true
                    $linkInfo.TargetExists = $true
                    $linkValidation.ValidLinks++
                } else {
                    # Lien interne - verifier la cible
                    $targetPath = Join-Path $file.DirectoryName $linkTarget
                    $targetPath = [System.IO.Path]::GetFullPath($targetPath)
                    
                    if (Test-Path $targetPath) {
                        $linkInfo.IsValid = $true
                        $linkInfo.TargetExists = $true
                        $linkValidation.ValidLinks++
                    } else {
                        $linkInfo.IsValid = $false
                        $linkInfo.TargetExists = $false
                        $linkValidation.BrokenLinks++
                        
                        # Tenter de reparer le lien si option active
                        if ($FixLinks) {
                            $newTarget = Repair-Link -LinkTarget $linkTarget -SourceFile $file.FullName
                            if ($newTarget -ne $linkTarget) {
                                $content = $content -replace [regex]::Escape($linkTarget), $newTarget
                                Set-Content -Path $file.FullName -Value $content -Encoding UTF8
                                $linkInfo.Updated = $true
                                $linkInfo.LinkTarget = $newTarget
                                $linkValidation.UpdatedLinks++
                            }
                        }
                    }
                }
                
                $linkValidation.LinkDetails += $linkInfo
            }
        } catch {
            Write-SdddLog "Erreur validation liens dans $($file.Name) : $($_.Exception.Message)" "WARN"
        }
    }
    
    Write-SdddLog "Validation liens terminee : $($linkValidation.ValidLinks)/$($linkValidation.TotalLinks) valides" "SUCCESS"
    return $linkValidation
}

function Repair-Link {
    param([string]$LinkTarget, [string]$SourceFile)
    
    # Essayer de trouver le fichier dans les categories organisees
    $fileName = Split-Path $LinkTarget -Leaf
    
    foreach ($category in $ExpectedCategories) {
        $categoryPath = Join-Path $DocsPath $category
        $targetFile = Join-Path $categoryPath $fileName
        
        if (Test-Path $targetFile) {
            $relativePath = Join-Path $category $fileName
            return $relativePath.Replace("\", "/")
        }
    }
    
    return $LinkTarget
}

function Generate-AccessibilityMetrics {
    param([hashtable]$StructureValidation, [hashtable]$LinkValidation)
    
    Write-SdddLog "Generation des metriques d'accessibilite..." "VALIDATE"
    
    $metrics = @{
        OrganizationScore = 0
        LinkIntegrityScore = 0
        NavigationScore = 0
        OverallScore = 0
        Improvements = @()
    }
    
    # Score d'organisation (0-100)
    $categoryScore = ($StructureValidation.ExistingCategories.Count / $ExpectedCategories.Count) * 100
    $orphanedPenalty = [Math]::Min(($StructureValidation.OrphanedFiles.Count * 5), 50)
    $metrics.OrganizationScore = [Math]::Max($categoryScore - $orphanedPenalty, 0)
    
    # Score d'integrite des liens (0-100)
    if ($LinkValidation.TotalLinks -gt 0) {
        $metrics.LinkIntegrityScore = ($LinkValidation.ValidLinks / $LinkValidation.TotalLinks) * 100
    } else {
        $metrics.LinkIntegrityScore = 100
    }
    
    # Score de navigation (0-100)
    $orphanedScore = if ($StructureValidation.OrphanedFiles.Count -eq 0) { 100 } else { 0 }
    $navigationFactors = @(
        $metrics.OrganizationScore * 0.4,
        $metrics.LinkIntegrityScore * 0.3,
        $orphanedScore * 0.3
    )
    $metrics.NavigationScore = ($navigationFactors | Measure-Object -Sum).Sum
    
    # Score global
    $metrics.OverallScore = ($metrics.OrganizationScore + $metrics.LinkIntegrityScore + $metrics.NavigationScore) / 3
    
    # Ameliorations suggerees
    if ($StructureValidation.MissingCategories.Count -gt 0) {
        $metrics.Improvements += "Creer les categories manquantes : $($StructureValidation.MissingCategories -join ', ')"
    }
    
    if ($StructureValidation.OrphanedFiles.Count -gt 0) {
        $metrics.Improvements += "Deplacer les $($StructureValidation.OrphanedFiles.Count) fichiers orphelins vers les categories appropriees"
    }
    
    if ($LinkValidation.BrokenLinks -gt 0) {
        $metrics.Improvements += "Reparer les $($LinkValidation.BrokenLinks) liens internes casses"
    }
    
    Write-SdddLog "Metriques generees : Score global = $($metrics.OverallScore.ToString('F1'))/100" "SUCCESS"
    return $metrics
}

function Generate-ValidationReport {
    param([hashtable]$StructureValidation, [hashtable]$LinkValidation, [hashtable]$Metrics, [string]$ReportPath)
    
    Write-SdddLog "Generation du rapport de validation SDDD..." "VALIDATE"
    
    $report = @"
# Rapport de Validation SDDD - Organisation docs/
**Date** : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
**Mission** : Phase 2 SDDD - Action A.1  
**Statut** : [OK] Validation completee  

---

## Resume de la Validation

### Structure des Repertoires
- **Categories attendues** : $($ExpectedCategories.Count)
- **Categories existantes** : $($StructureValidation.ExistingCategories.Count)
- **Categories manquantes** : $($StructureValidation.MissingCategories.Count)
- **Fichiers organises** : $($StructureValidation.TotalFiles - $StructureValidation.OrphanedFiles.Count)
- **Fichiers orphelins** : $($StructureValidation.OrphanedFiles.Count)

### Validation des Liens
- **Fichiers analyses** : $($LinkValidation.TotalFiles)
- **Liens totaux** : $($LinkValidation.TotalLinks)
- **Liens valides** : $($LinkValidation.ValidLinks)
- **Liens casses** : $($LinkValidation.BrokenLinks)
- **Liens reparés** : $($LinkValidation.UpdatedLinks)

---

## Metriques d'Accessibilite

| Metrique | Score | Objectif | Statut |
|----------|--------|----------|---------|
| Organisation | $($Metrics.OrganizationScore.ToString('F1'))/100 | 95% | $(if ($Metrics.OrganizationScore -ge 95) { "[OK]" } else { "[WARN]" }) |
| Integrite des liens | $($Metrics.LinkIntegrityScore.ToString('F1'))/100 | 90% | $(if ($Metrics.LinkIntegrityScore -ge 90) { "[OK]" } else { "[WARN]" }) |
| Navigation | $($Metrics.NavigationScore.ToString('F1'))/100 | 85% | $(if ($Metrics.NavigationScore -ge 85) { "[OK]" } else { "[WARN]" }) |
| Score global | $($Metrics.OverallScore.ToString('F1'))/100 | 90% | $(if ($Metrics.OverallScore -ge 90) { "[OK]" } else { "[WARN]" }) |

---

## Detail des Categories
"@
    
    foreach ($category in $StructureValidation.ExistingCategories) {
        $categoryPath = Join-Path $DocsPath $category
        $files = Get-ChildItem -Path $categoryPath -Filter "*.md" -File
        $report += "- **$category** : $($files.Count) fichiers`n"
    }
    
    if ($StructureValidation.MissingCategories.Count -gt 0) {
        $report += "`n### Categories Manquantes`n"
        foreach ($category in $StructureValidation.MissingCategories) {
            $report += "- **$category** : Manquante`n"
        }
    }
    
    if ($StructureValidation.OrphanedFiles.Count -gt 0) {
        $report += "`n### Fichiers Orphelins`n"
        foreach ($file in $StructureValidation.OrphanedFiles) {
            $report += "- **$($file.Name)** : $($file.LastModified.ToString('yyyy-MM-dd'))`n"
        }
    }
    
    if ($LinkValidation.BrokenLinks -gt 0) {
        $report += "`n### Liens Casses`n"
        $brokenLinks = $LinkValidation.LinkDetails | Where-Object { -not $_.IsValid }
        foreach ($link in $brokenLinks | Select-Object -First 10) {
            $report += "- **$($link.SourceFile)** : $($link.LinkTarget) -> $([math]::Round($link.LinkTarget.Length / 1KB, 1)) KB`n"
        }
    }
    
    $report += @"

---

## Ameliorations Suggerees
"@
    
    foreach ($improvement in $Metrics.Improvements) {
        $report += "- $improvement`n"
    }
    
    $report += @"

---

## Prochaines Etapes

1. **Finaliser l'organisation** : Deplacer les fichiers orphelins restants
2. **Reparer les liens** : Corriger les liens internes casses
3. **Optimiser la navigation** : Ameliorer l'accessibilite
4. **Documenter les changements** : Mettre a jour la documentation

---

**Rapport genere par** : SDDD Validation Script  
**Version** : 1.0  
**Phase suivante** : Phase 3 - Validation SDDD
"@
    
    # Sauvegarder le rapport
    $reportFile = Join-Path $ReportPath "VALIDATION-REPORT-SDDD-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
    $report | Out-File -FilePath $reportFile -Encoding UTF8
    
    Write-SdddLog "Rapport de validation genere : $reportFile" "SUCCESS"
    return $reportFile
}

# Programme principal SDDD
try {
    Write-SdddLog "=== DEBUT VALIDATION SDDD ORGANISATION DOCS ===" "VALIDATE"
    Write-SdddLog "Chemin docs : $DocsPath" "INFO"
    Write-SdddLog "Chemin outputs : $OutputPath" "INFO"
    Write-SdddLog "Generation metriques : $GenerateMetrics" "INFO"
    Write-SdddLog "Reparation liens : $FixLinks" "INFO"
    
    # Phase 1 : Prerequis
    Test-SdddPrerequisites
    
    # Phase 2 : Validation de la structure
    $structureValidation = Validate-DirectoryStructure
    
    # Phase 3 : Validation des liens internes
    $linkValidation = Validate-InternalLinks
    
    # Phase 4 : Generation des metriques (si demande)
    $metrics = $null
    if ($GenerateMetrics) {
        $metrics = Generate-AccessibilityMetrics -StructureValidation $structureValidation -LinkValidation $linkValidation
    }
    
    # Phase 5 : Rapport de validation
    $reportFile = Generate-ValidationReport -StructureValidation $structureValidation -LinkValidation $linkValidation -Metrics $metrics -ReportPath $OutputPath
    
    Write-SdddLog "=== VALIDATION SDDD TERMINEE AVEC SUCCES ===" "SUCCESS"
    Write-SdddLog "Categories validees : $($structureValidation.ExistingCategories.Count)/$($ExpectedCategories.Count)" "SUCCESS"
    Write-SdddLog "Liens valides : $($linkValidation.ValidLinks)/$($linkValidation.TotalLinks)" "SUCCESS"
    Write-SdddLog "Rapport genere : $reportFile" "SUCCESS"
    
    if ($metrics) {
        Write-SdddLog "Score global d'accessibilite : $($metrics.OverallScore.ToString('F1'))/100" "SUCCESS"
    }
    
    if ($structureValidation.OrphanedFiles.Count -eq 0 -and $linkValidation.BrokenLinks -eq 0) {
        Write-SdddLog "[OK] ORGANISATION PARFAITE - Aucune action requise" "SUCCESS"
    } else {
        Write-SdddLog "[WARN] ORGANISATION AMELIORABLE - Actions requises" "WARN"
    }
    
} catch {
    Write-SdddLog "ERREUR CRITIQUE SDDD : $($_.Exception.Message)" "ERROR"
    Write-SdddLog "Stack trace : $($_.ScriptStackTrace)" "ERROR"
    exit 1
}