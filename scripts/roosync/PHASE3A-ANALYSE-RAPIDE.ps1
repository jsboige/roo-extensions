# =============================================================================
# PHASE 3A - ANALYSE RAPIDE DES PROBLÈMES ROOSYNC
# =============================================================================
# Script simplifié pour analyser l'état actuel et identifier les problèmes
# Auteur : Roo Code Mode
# Date : 2025-11-08
# Version : 1.0
# =============================================================================

# Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

# Fonction de logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(
        switch ($Level) {
            "ERROR" { "Red" }
            "WARN" { "Yellow" }
            "SUCCESS" { "Green" }
            default { "White" }
        }
    )
}

# =============================================================================
# ANALYSE DU FICHIER SYNC-ROADMAP.MD
# =============================================================================

function Analyze-SyncRoadmap {
    Write-Log "DÉBUT DE L'ANALYSE DU SYNC-ROADMAP.MD" "SUCCESS"
    Write-Log "=========================================" "SUCCESS"
    
    $roadmapPath = "../../Drive/.shortcut-targets-by-id/1jEQqHabwXrIukTEI1vE05gWsJNYNNFVB/.shared-state/sync-roadmap.md"
    
    if (!(Test-Path $roadmapPath)) {
        Write-Log "Fichier sync-roadmap.md introuvable à : $roadmapPath" "ERROR"
        return @{
            success = $false
            error = "Fichier introuvable"
            path = $roadmapPath
        }
    }
    
    try {
        $content = Get-Content -Path $roadmapPath -Raw -Encoding UTF8
        Write-Log "Fichier sync-roadmap.md trouvé et lu avec succès" "SUCCESS"
        
        $analysis = @{
            timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
            filePath = $roadmapPath
            fileSize = (Get-Item $roadmapPath).Length
            totalDecisions = 0
            pendingDecisions = 0
            approvedDecisions = 0
            duplicateIds = @()
            corruptedHardware = @()
            statusInconsistencies = @()
            issues = @()
        }
        
        # Analyser les blocs de décision
        $decisionBlocks = [regex]::Matches($content, '(<!-- DECISION_BLOCK_START -->([\s\S]*?)<!-- DECISION_BLOCK_END -->)')
        $analysis.totalDecisions = $decisionBlocks.Count
        Write-Log "Nombre total de blocs de décision : $($analysis.totalDecisions)" "INFO"
        
        # Extraire et analyser chaque décision
        $decisionIds = @()
        
        foreach ($match in $decisionBlocks) {
            $block = $match.Groups[1].Value
            
            # Extraire l'ID
            if ($block -match '\*\*ID:\*\* `([^`]+)`') {
                $decisionId = $matches[1]
                $decisionIds += $decisionId
                
                # Vérifier les doublons
                if ($decisionIds.Count -gt 1 -and $decisionIds[0..($decisionIds.Count-2)] -contains $decisionId) {
                    $analysis.duplicateIds += $decisionId
                    Write-Log "ID en double détecté : $decisionId" "WARN"
                }
            }
            
            # Analyser le statut
            if ($block -match '\*\*Statut:\*\* (\w+)') {
                $status = $matches[1].ToLower()
                if ($status -eq "pending") {
                    $analysis.pendingDecisions++
                } elseif ($status -eq "approved") {
                    $analysis.approvedDecisions++
                    
                    # Vérifier les métadonnées d'approbation
                    if ($block -notmatch '\*\*Approuvé le:\*\*') {
                        $analysis.statusInconsistencies += @{
                            type = "MISSING_APPROVAL_METADATA"
                            decisionId = if ($block -match '\*\*ID:\*\* `([^`]+)`') { $matches[1] } else { "UNKNOWN" }
                            description = "Décision approved sans métadonnées d'approbation"
                        }
                        Write-Log "Décision approved sans métadonnées détectée" "WARN"
                    }
                }
            }
            
            # Détecter les données hardware corrompues
            if ($block -match '\*\*Valeur Source:\*\* 0') {
                $analysis.corruptedHardware += @{
                    type = "ZERO_VALUE"
                    decisionId = if ($block -match '\*\*ID:\*\* `([^`]+)`') { $matches[1] } else { "UNKNOWN" }
                    description = "Valeur source à 0"
                }
                Write-Log "Donnée hardware corrompue détectée (valeur 0)" "WARN"
            }
            
            if ($block -match '\*\*Valeur Source:\*\* "Unknown"') {
                $analysis.corruptedHardware += @{
                    type = "UNKNOWN_VALUE"
                    decisionId = if ($block -match '\*\*ID:\*\* `([^`]+)`') { $matches[1] } else { "UNKNOWN" }
                    description = "Valeur source 'Unknown'"
                }
                Write-Log "Donnée hardware corrompue détectée (valeur Unknown)" "WARN"
            }
        }
        
        # Résumé de l'analyse
        Write-Log "RÉSUMÉ DE L'ANALYSE" "SUCCESS"
        Write-Log "===================" "SUCCESS"
        Write-Log "Décisions totales : $($analysis.totalDecisions)" "INFO"
        Write-Log "Décisions pending : $($analysis.pendingDecisions)" "INFO"
        Write-Log "Décisions approved : $($analysis.approvedDecisions)" "INFO"
        Write-Log "IDs en double : $($analysis.duplicateIds.Count)" "WARN"
        Write-Log "Données hardware corrompues : $($analysis.corruptedHardware.Count)" "WARN"
        Write-Log "Incohérences de statut : $($analysis.statusInconsistencies.Count)" "WARN"
        
        # Identifier les problèmes critiques
        if ($analysis.duplicateIds.Count -gt 0) {
            $analysis.issues += @{
                type = "DUPLICATE_DECISIONS"
                severity = "HIGH"
                count = $analysis.duplicateIds.Count
                description = "Décisions en double détectées"
                details = $analysis.duplicateIds
            }
        }
        
        if ($analysis.corruptedHardware.Count -gt 0) {
            $analysis.issues += @{
                type = "CORRUPTED_HARDWARE_DATA"
                severity = "HIGH"
                count = $analysis.corruptedHardware.Count
                description = "Données hardware corrompues"
                details = $analysis.corruptedHardware
            }
        }
        
        if ($analysis.statusInconsistencies.Count -gt 0) {
            $analysis.issues += @{
                type = "STATUS_INCONSISTENCIES"
                severity = "MEDIUM"
                count = $analysis.statusInconsistencies.Count
                description = "Incohérences statut/métadonnées"
                details = $analysis.statusInconsistencies
            }
        }
        
        $analysis.success = $true
        return $analysis
        
    } catch {
        Write-Log "ERREUR lors de l'analyse du fichier : $($_.Exception.Message)" "ERROR"
        return @{
            success = $false
            error = $_.Exception.Message
            exception = $_.Exception
        }
    }
}

# =============================================================================
# GÉNÉRATION DU RAPPORT D'ANALYSE
# =============================================================================

function New-AnalysisReport {
    param([hashtable]$Analysis)
    
    Write-Log "GÉNÉRATION DU RAPPORT D'ANALYSE" "SUCCESS"
    Write-Log "=================================" "SUCCESS"
    
    $reportPath = "roo-config/reports/PHASE3A-ANALYSE-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
    
    $reportContent = @"
# Rapport d'Analyse Phase 3A - RooSync

**Date** : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
**Sous-phase** : 3A (Jours 1-3)  
**Statut** : ANALYSE COMPLÉTÉE  
**Conformité** : SDDD (Semantic Documentation Driven Design)

---

## 📋 Résumé Exécutif

### Objectif
Analyser l'état actuel du système RooSync et identifier les problèmes critiques pour la Sous-phase 3A.

### Résultats Principaux
- **Décisions totales** : $($Analysis.totalDecisions)
- **Décisions pending** : $($Analysis.pendingDecisions)
- **Décisions approved** : $($Analysis.approvedDecisions)
- **Problèmes critiques identifiés** : $($Analysis.issues.Count)

---

## 🔍 Analyse Détaillée

### Structure du Fichier
- **Chemin** : $($Analysis.filePath)
- **Taille** : $($Analysis.fileSize) octets
- **Date d'analyse** : $($Analysis.timestamp)

### Distribution des Statuts
| Statut | Nombre | Pourcentage |
|---------|--------|-------------|
| Pending | $($Analysis.pendingDecisions) | $(if($Analysis.totalDecisions -gt 0) { [math]::Round(($Analysis.pendingDecisions / $Analysis.totalDecisions) * 100, 1) } else { 0 })% |
| Approved | $($Analysis.approvedDecisions) | $(if($Analysis.totalDecisions -gt 0) { [math]::Round(($Analysis.approvedDecisions / $Analysis.totalDecisions) * 100, 1) } else { 0 })% |

---

## 🚨 Problèmes Identifiés

$(if($Analysis.issues.Count -gt 0) {
    foreach($issue in $Analysis.issues) {
@"
### $($issue.type)
- **Sévérité** : $($issue.severity)
- **Nombre** : $($issue.count)
- **Description** : $($issue.description)
- **Détails** : $(if($issue.details) { $issue.details | ConvertTo-Json -Compress } else { "N/A" })

"@
    }
} else {
"Aucun problème critique détecté."
})

---

## 📊 Métriques Clés

### Indicateurs de Qualité
- **Taux de décisions valides** : $(if($Analysis.totalDecisions -gt 0) { [math]::Round((($Analysis.totalDecisions - $Analysis.duplicateIds.Count) / $Analysis.totalDecisions) * 100, 1) } else { 0 })%
- **Taux de données corrompues** : $(if($Analysis.totalDecisions -gt 0) { [math]::Round(($Analysis.corruptedHardware.Count / $Analysis.totalDecisions) * 100, 1) } else { 0 })%
- **Taux d'incohérences** : $(if($Analysis.totalDecisions -gt 0) { [math]::Round(($Analysis.statusInconsistencies.Count / $Analysis.totalDecisions) * 100, 1) } else { 0 })%

### Score de Santé
$($healthScore = if($Analysis.issues.Count -eq 0) { 100 } else { [math]::Max(0, 100 - ($Analysis.issues.Count * 10)) })
- **Score global** : $healthScore/100
- **Statut** : $(if($healthScore -ge 85) { "EXCELLENT" } elseif($healthScore -ge 70) { "BON" } elseif($healthScore -ge 50) { "MOYEN" } else { "CRITIQUE" })

---

## 🎯 Recommandations

### Actions Immédiates (Priorité HAUTE)
$(if($Analysis.duplicateIds.Count -gt 0) {
"- **Nettoyer les décisions en double** : Supprimer les doublons dans sync-roadmap.md"
})

$(if($Analysis.corruptedHardware.Count -gt 0) {
"- **Corriger les données hardware** : Remplacer les valeurs corrompues par des valeurs détectées"
})

$(if($Analysis.statusInconsistencies.Count -gt 0) {
"- **Réparer les incohérences de statut** : Ajouter les métadonnées manquantes aux décisions approved"
})

### Actions Préventives (Priorité MOYENNE)
- **Mettre en place des validations automatiques** lors de la création des décisions
- **Implémenter des tests unitaires** pour le workflow RooSync
- **Documenter les procédures de correction** pour référence future

---

## 📝 Prochaines Étapes

1. **Appliquer les corrections critiques** identifiées dans ce rapport
2. **Valider les corrections** avec des tests E2E
3. **Générer le rapport Checkpoint 1** selon le plan SDDD
4. **Préparer la transition** vers la Sous-phase 3B

---

**Rapport généré le** : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
**Auteur** : Roo Code Mode  
**Prochaine étape** : Application des corrections

---

*Ce rapport suit la méthodologie SDDD (Semantic-Documentation-Driven-Design) et sert de référence pour la correction des problèmes identifiés.*
"@
    
    # Créer le répertoire de rapports si nécessaire
    if (!(Test-Path "roo-config/reports")) {
        New-Item -ItemType Directory -Path "roo-config/reports" -Force | Out-Null
    }
    
    $reportContent | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Log "Rapport d'analyse généré : $reportPath" "SUCCESS"
    
    return $reportPath
}

# =============================================================================
# PROGRAMME PRINCIPAL
# =============================================================================

function Main {
    Write-Log "DÉMARRAGE DE L'ANALYSE RAPIDE PHASE 3A" "SUCCESS"
    Write-Log "=========================================" "SUCCESS"
    Write-Log "Machine : $env:COMPUTERNAME" "INFO"
    Write-Log "Date : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO"
    Write-Log ""
    
    try {
        # Analyse du fichier sync-roadmap.md
        Write-Log "ÉTAPE 1/2 : ANALYSE DU SYNC-ROADMAP.MD" "SUCCESS"
        $analysis = Analyze-SyncRoadmap
        Write-Log ""
        
        if (!$analysis.success) {
            Write-Log "ERREUR lors de l'analyse : $($analysis.error)" "ERROR"
            exit 1
        }
        
        # Génération du rapport
        Write-Log "ÉTAPE 2/2 : GÉNÉRATION DU RAPPORT D'ANALYSE" "SUCCESS"
        $reportPath = New-AnalysisReport -Analysis $analysis
        Write-Log ""
        
        # Résumé final
        Write-Log "RÉSUMÉ DE L'ANALYSE" "SUCCESS"
        Write-Log "===================" "SUCCESS"
        Write-Log "Décisions analysées : $($analysis.totalDecisions)" "INFO"
        Write-Log "Problèmes identifiés : $($analysis.issues.Count)" "INFO"
        Write-Log "Rapport généré : $reportPath" "INFO"
        Write-Log ""
        
        if ($analysis.issues.Count -eq 0) {
            Write-Log "✅ AUCUN PROBLÈME CRITIQUE DÉTECTÉ" "SUCCESS"
            exit 0
        } else {
            Write-Log "⚠️ PROBLÈMES CRITIQUES DÉTECTÉS - Voir le rapport pour les détails" "WARN"
            exit 1
        }
        
    } catch {
        Write-Log "ERREUR CRITIQUE lors de l'exécution : $($_.Exception.Message)" "ERROR"
        Write-Log "Stack trace : $($_.ScriptStackTrace)" "ERROR"
        exit 2
    }
}

# Point d'entrée
Main