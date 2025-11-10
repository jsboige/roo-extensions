# Script PowerShell pour analyser le système de diff actuel
# Phase 3B - Analyse du système de diff granulaire

param(
    [string]$OutputDir = "roo-config/reports",
    [switch]$Verbose = $false
)

# Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Fonctions utilitaires
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-CommandExists {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Get-ScriptDirectory {
    return Split-Path -Parent $PSCommandPath
}

# Vérification des prérequis
function Test-Prerequisites {
    Write-Log "Vérification des prérequis..."
    
    $requiredCommands = @("git", "node")
    foreach ($cmd in $requiredCommands) {
        if (-not (Test-CommandExists $cmd)) {
            throw "Prérequis manquant: $cmd"
        }
    }
    
    Write-Log "Prérequis validés" "SUCCESS"
}

# Analyse du système de diff actuel
function Analyze-DiffSystem {
    Write-Log "Analyse du système de diff actuel..."
    
    $diffAnalysis = @{
        currentCapabilities = @()
        missingFeatures = @()
        limitations = @()
        recommendations = @()
        complianceScore = 0
    }
    
    # Vérifier l'existence du DiffDetector
    $diffDetectorPath = "mcps/internal/servers/roo-state-manager/src/services/DiffDetector.ts"
    if (Test-Path $diffDetectorPath) {
        Write-Log "DiffDetector.ts trouvé" "SUCCESS"
        $diffAnalysis.currentCapabilities += "DiffDetector.ts exists"
        
        # Analyser le contenu du DiffDetector
        $content = Get-Content $diffDetectorPath -Raw
        
        # Vérifier les méthodes existantes
        if ($content -match "compareBaselineWithMachine") {
            $diffAnalysis.currentCapabilities += "compareBaselineWithMachine method"
        }
        
        if ($content -match "compareInventories") {
            $diffAnalysis.currentCapabilities += "compareInventories method"
        }
        
        if ($content -match "compareObjects") {
            $diffAnalysis.currentCapabilities += "compareObjects method"
        }
        
        if ($content -match "determineSeverity") {
            $diffAnalysis.currentCapabilities += "determineSeverity method"
        }
        
        # Vérifier les types de différences supportés
        if ($content -match "BaselineDifference") {
            $diffAnalysis.currentCapabilities += "BaselineDifference type"
        }
        
        if ($content -match "DetectedDifference") {
            $diffAnalysis.currentCapabilities += "DetectedDifference type"
        }
        
        if ($content -match "ComparisonReport") {
            $diffAnalysis.currentCapabilities += "ComparisonReport type"
        }
        
        # Analyser les limitations
        if ($content -match "JSON\.stringify") {
            $diffAnalysis.limitations += "Uses JSON.stringify for comparison (not robust for complex objects)"
        }
        
        if (-not ($content -match "granular")) {
            $diffAnalysis.missingFeatures += "Granular diff functionality"
        }
        
        if (-not ($content -match "parameter.*by.*parameter")) {
            $diffAnalysis.missingFeatures += "Parameter-by-parameter comparison"
        }
        
        if (-not ($content -match "nested.*object")) {
            $diffAnalysis.missingFeatures += "Nested object diff analysis"
        }
        
        if (-not ($content -match "array.*diff")) {
            $diffAnalysis.missingFeatures += "Array diff analysis"
        }
        
        if (-not ($content -match "semantic.*diff")) {
            $diffAnalysis.missingFeatures += "Semantic diff analysis"
        }
        
        if (-not ($content -match "visual.*diff")) {
            $diffAnalysis.missingFeatures += "Visual diff representation"
        }
        
        if (-not ($content -match "export.*diff")) {
            $diffAnalysis.missingFeatures += "Diff export functionality"
        }
        
        if (-not ($content -match "merge.*conflict")) {
            $diffAnalysis.missingFeatures += "Merge conflict resolution"
        }
        
        if (-not ($content -match "interactive.*diff")) {
            $diffAnalysis.missingFeatures += "Interactive diff validation"
        }
        
        if (-not ($content -match "diff.*history")) {
            $diffAnalysis.missingFeatures += "Diff history tracking"
        }
        
        if (-not ($content -match "batch.*diff")) {
            $diffAnalysis.missingFeatures += "Batch diff processing"
        }
        
        if (-not ($content -match "custom.*rules")) {
            $diffAnalysis.missingFeatures += "Custom diff rules"
        }
        
        if (-not ($content -match "performance.*metrics")) {
            $diffAnalysis.missingFeatures += "Performance metrics for diff operations"
        }
        
    } else {
        Write-Log "DiffDetector.ts non trouvé" "ERROR"
        $diffAnalysis.missingFeatures += "DiffDetector.ts implementation"
    }
    
    # Vérifier les outils MCP de diff
    $mcpToolsPath = "mcps/internal/servers/roo-state-manager/src/tools/roosync"
    if (Test-Path $mcpToolsPath) {
        $diffTools = Get-ChildItem -Path $mcpToolsPath -Filter "*diff*.ts" -ErrorAction SilentlyContinue
        if ($diffTools.Count -eq 0) {
            $diffAnalysis.missingFeatures += "MCP tools for granular diff"
        } else {
            foreach ($tool in $diffTools) {
                $diffAnalysis.currentCapabilities += "MCP tool: $($tool.Name)"
            }
        }
    } else {
        $diffAnalysis.missingFeatures += "MCP tools directory for roosync"
    }
    
    # Vérifier les scripts PowerShell de diff
    $scriptsPath = "scripts/roosync"
    if (Test-Path $scriptsPath) {
        $diffScripts = Get-ChildItem -Path $scriptsPath -Filter "*diff*.ps1" -ErrorAction SilentlyContinue
        if ($diffScripts.Count -eq 0) {
            $diffAnalysis.missingFeatures += "PowerShell scripts for granular diff"
        } else {
            foreach ($script in $diffScripts) {
                $diffAnalysis.currentCapabilities += "PowerShell script: $($script.Name)"
            }
        }
    }
    
    # Calculer le score de conformité
    $totalFeatures = 15  # Nombre total de fonctionnalités attendues
    $implementedFeatures = $diffAnalysis.currentCapabilities.Count
    $diffAnalysis.complianceScore = [math]::Round(($implementedFeatures / $totalFeatures) * 100, 2)
    
    # Générer des recommandations
    if ($diffAnalysis.complianceScore -lt 50) {
        $diffAnalysis.recommendations += "Priorité haute: Implémenter les fonctionnalités de base du diff granulaire"
    }
    
    if ($diffAnalysis.missingFeatures -contains "Granular diff functionality") {
        $diffAnalysis.recommendations += "Créer un service GranularDiffDetector avec des algorithmes avancés"
    }
    
    if ($diffAnalysis.missingFeatures -contains "MCP tools for granular diff") {
        $diffAnalysis.recommendations += "Développer des outils MCP pour le diff granulaire"
    }
    
    if ($diffAnalysis.missingFeatures -contains "PowerShell scripts for granular diff") {
        $diffAnalysis.recommendations += "Créer des scripts PowerShell autonomes pour le diff granulaire"
    }
    
    if ($diffAnalysis.missingFeatures -contains "Visual diff representation") {
        $diffAnalysis.recommendations += "Implémenter une interface utilisateur pour la validation des diffs"
    }
    
    return $diffAnalysis
}

# Génération du rapport
function New-DiffAnalysisReport {
    param(
        [hashtable]$Analysis,
        [string]$OutputDir
    )
    
    Write-Log "Génération du rapport d'analyse du diff..."
    
    # Créer le répertoire de sortie
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
    
    # Générer le nom du fichier
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $reportPath = Join-Path $OutputDir "PHASE3B-DIFF-ANALYSIS-$timestamp.md"
    
    # Construire le rapport
    $report = @"
# Phase 3B - Analyse du Système de Diff

**Date**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")  
**Score de conformité**: $($Analysis.complianceScore)%  

## Résumé Exécutif

L'analyse du système de diff actuel révèle un score de conformité de **$($Analysis.complianceScore)%** par rapport aux exigences du diff granulaire. Le système dispose de fonctionnalités de base mais manque de capacités avancées de comparaison paramétrique.

## Capacités Actuelles

$($Analysis.currentCapabilities | ForEach-Object { "- $_" } | Out-String)

## Fonctionnalités Manquantes

$($Analysis.missingFeatures | ForEach-Object { "- $_" } | Out-String)

## Limitations Identifiées

$($Analysis.limitations | ForEach-Object { "- $_" } | Out-String)

## Recommandations

$($Analysis.recommendations | ForEach-Object { "- $_" } | Out-String)

## Plan d'Action

### Actions Immédiates (Jour 6-7)

1. **Implémenter GranularDiffDetector**
   - Créer un service dédié au diff granulaire
   - Développer des algorithmes de comparaison avancés
   - Supporter les objets imbriqués et les tableaux

2. **Développer les outils MCP**
   - `roosync_granular_diff`: Comparaison granulaire
   - `roosync_validate_diff`: Validation interactive
   - `roosync_export_diff`: Export des résultats

3. **Créer les scripts PowerShell**
   - `roosync_granular_diff.ps1`: Script autonome
   - `roosync_diff_validation.ps1`: Interface de validation
   - `roosync_batch_diff.ps1`: Traitement par lots

### Actions de Moyen Terme (Jour 8)

1. **Interface utilisateur**
   - Représentation visuelle des diffs
   - Validation interactive des changements
   - Résolution des conflits de fusion

2. **Performance et optimisation**
   - Métriques de performance
   - Optimisation des algorithmes
   - Cache des résultats de diff

## Prochaines Étapes

1. Implémenter le service GranularDiffDetector
2. Créer les outils MCP correspondants
3. Développer les scripts PowerShell autonomes
4. Valider 85% de conformité (Checkpoint 2)
5. Préparer Checkpoint 3 (90% de conformité)

---

*Ce rapport a été généré automatiquement par le script PHASE3B-ANALYSE-DIFF.ps1*
"@
    
    # Écrire le rapport
    $report | Out-File -FilePath $reportPath -Encoding UTF8 -Force
    
    Write-Log "Rapport généré: $reportPath" "SUCCESS"
    return $reportPath
}

# Fonction principale
function Main {
    try {
        Write-Log "Début de l'analyse du système de diff - Phase 3B" "SUCCESS"
        
        # Vérifier les prérequis
        Test-Prerequisites
        
        # Analyser le système de diff
        $diffAnalysis = Analyze-DiffSystem
        
        # Afficher les résultats
        Write-Log "Score de conformité: $($diffAnalysis.complianceScore)%" "SUCCESS"
        Write-Log "Capacités actuelles: $($diffAnalysis.currentCapabilities.Count)"
        Write-Log "Fonctionnalités manquantes: $($diffAnalysis.missingFeatures.Count)"
        
        if ($Verbose) {
            Write-Log "Capacités actuelles:"
            $diffAnalysis.currentCapabilities | ForEach-Object { Write-Log "  - $_" }
            
            Write-Log "Fonctionnalités manquantes:"
            $diffAnalysis.missingFeatures | ForEach-Object { Write-Log "  - $_" "WARN" }
        }
        
        # Générer le rapport
        $reportPath = New-DiffAnalysisReport -Analysis $diffAnalysis -OutputDir $OutputDir
        
        Write-Log "Analyse du système de diff terminée avec succès" "SUCCESS"
        Write-Log "Rapport disponible: $reportPath"
        
        # Retourner le code de sortie basé sur le score de conformité
        if ($diffAnalysis.complianceScore -ge 50) {
            exit 0
        } else {
            exit 1
        }
    }
    catch {
        Write-Log "Erreur lors de l'analyse: $($_.Exception.Message)" "ERROR"
        exit 2
    }
}

# Exécuter la fonction principale
Main