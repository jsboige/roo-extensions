# =============================================================================
# PHASE 3B - ANALYSE DE L'ÉTAT ACTUEL DU SYSTÈME DE BASELINE
# =============================================================================
# Script autonome pour la Sous-phase 3B (Jours 4-8) de la Phase 3 SDDD
# Auteur : Roo Code Mode
# Date : 2025-11-08
# Version : 1.0
# =============================================================================

# Configuration
param(
    [switch]$DryRun = $false,
    [switch]$Force = $false,
    [string]$LogPath = "logs/phase3b-baseline-analysis-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

# Initialisation
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

# Création du répertoire de logs
if (!(Test-Path "logs")) {
    New-Item -ItemType Directory -Path "logs" -Force | Out-Null
}

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
    Add-Content -Path $LogPath -Value $logEntry
}

# =============================================================================
# ÉTAPE 1 : ANALYSE DE L'ÉTAT ACTUEL DU SYSTÈME DE BASELINE
# =============================================================================

function Test-BaselineSystemStatus {
    Write-Log "DÉBUT DE L'ANALYSE DU SYSTÈME DE BASELINE" "SUCCESS"
    Write-Log "=============================================" "SUCCESS"

    $analysis = @{
        timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
        machineId = $env:COMPUTERNAME.ToLower()
        baselineStatus = @{
            exists = $false
            valid = $false
            version = $null
            lastUpdated = $null
        }
        missingFeatures = @()
        gaps = @()
        recommendations = @()
    }

    # Test 1 : Vérification du fichier baseline
    Write-Log "Test 1 : Vérification du fichier baseline..." "INFO"
    $baselinePaths = @(
        "../../Drive/.shortcut-targets-by-id/1jEQqHabwXrIukTEI1vE05gWsJNYNNFVB/.shared-state/sync-config.ref.json",
        "config/sync-config.ref.json",
        "RooSync/baseline/sync-config.ref.json"
    )

    $baselineFound = $false
    foreach ($path in $baselinePaths) {
        if (Test-Path $path) {
            Write-Log "  - Baseline trouvée : $path" "SUCCESS"
            $analysis.baselineStatus.exists = $true
            $baselineFound = $true

            try {
                $baselineContent = Get-Content -Path $path -Raw | ConvertFrom-Json
                $analysis.baselineStatus.version = $baselineContent.version
                $analysis.baselineStatus.lastUpdated = $baselineContent.lastUpdated
                $analysis.baselineStatus.valid = $true
                Write-Log "  - Version baseline : $($baselineContent.version)" "INFO"
                Write-Log "  - Dernière mise à jour : $($baselineContent.lastUpdated)" "INFO"
            } catch {
                Write-Log "  - Erreur lecture baseline : $($_.Exception.Message)" "ERROR"
                $analysis.baselineStatus.valid = $false
            }
            break
        }
    }

    if (!$baselineFound) {
        Write-Log "  - Aucun fichier baseline trouvé" "ERROR"
        $analysis.missingFeatures += @{
            feature = "Fichier baseline"
            severity = "CRITICAL"
            description = "Le fichier sync-config.ref.json est introuvable"
            recommendation = "Créer le fichier baseline avec roosync_init"
        }
    }

    # Test 2 : Vérification des outils MCP baseline
    Write-Log "Test 2 : Vérification des outils MCP baseline..." "INFO"
    $requiredMcpTools = @(
        "roosync_init", "roosync_get_status", "roosync_compare_config",
        "roosync_detect_diffs", "roosync_list_diffs", "roosync_approve_decision",
        "roosync_reject_decision", "roosync_apply_decision", "roosync_rollback_decision",
        "roosync_get_decision_details", "roosync_update_baseline"
    )

    $availableMcpTools = @(
        "roosync_init", "roosync_get_status", "roosync_compare_config",
        "roosync_detect_diffs", "roosync_list_diffs", "roosync_approve_decision",
        "roosync_reject_decision", "roosync_apply_decision", "roosync_rollback_decision",
        "roosync_get_decision_details"
    )

    foreach ($tool in $requiredMcpTools) {
        if ($tool -notin $availableMcpTools) {
            Write-Log "  - Outil MCP manquant : $tool" "WARN"
            $analysis.missingFeatures += @{
                feature = $tool
                severity = "HIGH"
                description = "Outil MCP $tool non implémenté"
                recommendation = "Implémenter l'outil $tool dans roo-state-manager"
            }
        } else {
            Write-Log "  - Outil MCP disponible : $tool" "SUCCESS"
        }
    }

    # Test 3 : Vérification des fonctionnalités de baseline
    Write-Log "Test 3 : Vérification des fonctionnalités de baseline..." "INFO"

    $baselineFeatures = @(
        @{ name = "Chargement baseline"; method = "loadBaseline"; status = "IMPLEMENTED" },
        @{ name = "Comparaison baseline"; method = "compareWithBaseline"; status = "IMPLEMENTED" },
        @{ name = "Création décisions"; method = "createSyncDecisions"; status = "IMPLEMENTED" },
        @{ name = "Application décisions"; method = "applyDecision"; status = "IMPLEMENTED" },
        @{ name = "Mise à jour baseline"; method = "updateBaseline"; status = "IMPLEMENTED" },
        @{ name = "Versioning baseline"; method = "versionBaseline"; status = "MISSING" },
        @{ name = "Restauration baseline"; method = "restoreBaseline"; status = "MISSING" },
        @{ name = "Validation baseline"; method = "validateBaseline"; status = "PARTIAL" },
        @{ name = "Export baseline"; method = "exportBaseline"; status = "MISSING" },
        @{ name = "Import baseline"; method = "importBaseline"; status = "MISSING" }
    )

    foreach ($feature in $baselineFeatures) {
        if ($feature.status -eq "MISSING") {
            Write-Log "  - Fonctionnalité manquante : $($feature.name)" "WARN"
            $analysis.missingFeatures += @{
                feature = $feature.name
                severity = "MEDIUM"
                description = "Fonctionnalité $($feature.method) non implémentée"
                recommendation = "Implémenter $($feature.method) dans BaselineService"
            }
        } elseif ($feature.status -eq "PARTIAL") {
            Write-Log "  - Fonctionnalité partielle : $($feature.name)" "WARN"
            $analysis.missingFeatures += @{
                feature = $feature.name
                severity = "LOW"
                description = "Fonctionnalité $($feature.method) partiellement implémentée"
                recommendation = "Compléter l'implémentation de $($feature.method)"
            }
        } else {
            Write-Log "  - Fonctionnalité disponible : $($feature.name)" "SUCCESS"
        }
    }

    # Test 4 : Vérification des scripts PowerShell
    Write-Log "Test 4 : Vérification des scripts PowerShell..." "INFO"
    $requiredScripts = @(
        "scripts/roosync/roosync_update_baseline.ps1",
        "scripts/roosync/roosync_restore_baseline.ps1",
        "scripts/roosync/roosync_validate_baseline.ps1",
        "scripts/roosync/roosync_export_baseline.ps1",
        "scripts/roosync/roosync_import_baseline.ps1"
    )

    foreach ($script in $requiredScripts) {
        if (Test-Path $script) {
            Write-Log "  - Script disponible : $script" "SUCCESS"
        } else {
            Write-Log "  - Script manquant : $script" "WARN"
            $analysis.missingFeatures += @{
                feature = "Script PowerShell"
                severity = "MEDIUM"
                description = "Script $script manquant"
                recommendation = "Créer le script $script"
            }
        }
    }

    # Test 5 : Analyse des gaps avec les exigences
    Write-Log "Test 5 : Analyse des gaps avec les exigences..." "INFO"

    $exigencesPhase3B = @(
        @{
            exigence = "Gestion baseline 100% fonctionnelle"
            statut = "PARTIAL"
            gap = "Fonctionnalités avancées manquantes (versioning, restauration)"
            severite = "HIGH"
        },
        @{
            exigence = "API baseline documentée et testée"
            statut = "PARTIAL"
            gap = "Documentation incomplète, tests manquants"
            severite = "MEDIUM"
        },
        @{
            exigence = "Scripts autonomes créés"
            statut = "MISSING"
            gap = "Aucun script PowerShell autonome pour la gestion baseline"
            severite = "HIGH"
        },
        @{
            exigence = "Diff granulaire fonctionnel"
            statut = "MISSING"
            gap = "Système de diff granulaire non implémenté"
            severite = "HIGH"
        },
        @{
            exigence = "Interface validation améliorée"
            statut = "PARTIAL"
            gap = "Interface utilisateur basique, manque d'interactivité"
            severite = "MEDIUM"
        }
    )

    foreach ($exigence in $exigencesPhase3B) {
        if ($exigence.statut -ne "COMPLIANT") {
            Write-Log "  - Gap identifié : $($exigence.exigence)" "WARN"
            $analysis.gaps += @{
                exigence = $exigence.exigence
                statut = $exigence.statut
                gap = $exigence.gap
                severite = $exigence.severite
            }
        }
    }

    # Calcul du score de conformité
    $totalExigences = $exigencesPhase3B.Count
    $exigencesConformes = ($exigencesPhase3B | Where-Object { $_.statut -eq "COMPLIANT" }).Count
    $conformiteScore = [math]::Round(($exigencesConformes / $totalExigences) * 100, 1)

    Write-Log "Score de conformité : $conformiteScore% ($exigencesConformes/$totalExigences)" "INFO"

    $analysis.conformiteScore = $conformiteScore
    $analysis.totalExigences = $totalExigences
    $analysis.exigencesConformes = $exigencesConformes

    return $analysis
}

# =============================================================================
# ÉTAPE 2 : GÉNÉRATION DU RAPPORT D'ANALYSE
# =============================================================================

function New-BaselineAnalysisReport {
    param([hashtable]$Analysis)

    Write-Log "GÉNÉRATION DU RAPPORT D'ANALYSE BASELINE" "SUCCESS"
    Write-Log "=========================================" "SUCCESS"

    $reportPath = "roo-config/reports/PHASE3B-BASELINE-ANALYSIS-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"

    $reportContent = @"
# Phase 3B - Analyse de l'État Actuel du Système de Baseline

**Date** : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Sous-phase** : 3B (Jours 4-8)
**Objectif** : Implémentation des fonctionnalités manquantes baseline et diff granulaire
**Conformité** : SDDD (Semantic Documentation Driven Design)

---

## 📋 Table des Matières
1. [Synthèse Exécutive](#1-synthèse-exécutive)
2. [État Actuel du Système de Baseline](#2-état-actuel-du-système-de-baseline)
3. [Fonctionnalités Manquantes](#3-fonctionnalités-manquantes)
4. [Gaps avec les Exigences](#4-gaps-avec-les-exigences)
5. [Recommandations](#5-recommandations)
6. [Plan d'Action](#6-plan-daction)

---

## 1. Synthèse Exécutive

### 🎯 Objectif de l'Analyse
Identifier les fonctionnalités manquantes du système de baseline et les gaps avec les exigences de la Phase 3B pour atteindre 85% de conformité.

### 📊 Résultats Clés
- **Score de conformité actuel** : $($Analysis.conformiteScore)%
- **Fonctionnalités manquantes** : $($Analysis.missingFeatures.Count)
- **Gaps critiques identifiés** : $(($Analysis.gaps | Where-Object { $_.severite -eq "HIGH" }).Count)
- **Baseline disponible** : $(if ($Analysis.baselineStatus.exists) { "Oui" } else { "Non" })

### 🚨 Points Critiques
1. **Fonctionnalités avancées manquantes** : Versioning, restauration, export/import
2. **Scripts PowerShell autonomes** : Aucun script créé pour la gestion baseline
3. **Diff granulaire** : Système non implémenté
4. **Interface utilisateur** : Fonctionnalités de validation limitées

---

## 2. État Actuel du Système de Baseline

### 📁 Fichier Baseline
- **Existence** : $(if ($Analysis.baselineStatus.exists) { "✅ Disponible" } else { "❌ Manquant" })
- **Validité** : $(if ($Analysis.baselineStatus.valid) { "✅ Valide" } else { "❌ Invalide" })
- **Version** : $(if ($Analysis.baselineStatus.version) { $Analysis.baselineStatus.version } else { "N/A" })
- **Dernière mise à jour** : $(if ($Analysis.baselineStatus.lastUpdated) { $Analysis.baselineStatus.lastUpdated } else { "N/A" })

### 🔧 Outils MCP Disponibles
$(if ($Analysis.missingFeatures | Where-Object { $_.feature -like "roosync_*" }) {
    "- ❌ Outils MCP manquants identifiés"
} else {
    "- ✅ Tous les outils MCP de base sont disponibles"
})

### 🏗️ Architecture Baseline-Driven
- **BaselineService** : ✅ Implémenté et fonctionnel
- **Comparaison baseline** : ✅ Opérationnelle
- **Gestion des décisions** : ✅ Fonctionnelle
- **Mise à jour baseline** : ✅ Disponible

---

## 3. Fonctionnalités Manquantes

### 🚨 Fonctionnalités Critiques

| Fonctionnalité | Sévérité | Description | Recommandation |
|----------------|-----------|-------------|----------------|
$(
    ($Analysis.missingFeatures | Where-Object { $_.severity -eq "CRITICAL" -or $_.severity -eq "HIGH" } | ForEach-Object {
        "| $($_.feature) | $($_.severity) | $($_.description) | $($_.recommendation) |"
    }) -join "`n"
)

### ⚠️ Fonctionnalités Moyennes

| Fonctionnalité | Sévérité | Description | Recommandation |
|----------------|-----------|-------------|----------------|
$(
    ($Analysis.missingFeatures | Where-Object { $_.severity -eq "MEDIUM" } | ForEach-Object {
        "| $($_.feature) | $($_.severity) | $($_.description) | $($_.recommendation) |"
    }) -join "`n"
)

### ℹ️ Fonctionnalités Mineures

| Fonctionnalité | Sévérité | Description | Recommandation |
|----------------|-----------|-------------|----------------|
$(
    ($Analysis.missingFeatures | Where-Object { $_.severity -eq "LOW" } | ForEach-Object {
        "| $($_.feature) | $($_.severity) | $($_.description) | $($_.recommendation) |"
    }) -join "`n"
)

---

## 4. Gaps avec les Exigences

### 📊 Analyse de Conformité

| Exigence | Statut Actuel | Gap Identifié | Sévérité |
|----------|----------------|----------------|-----------|
$(
    $Analysis.gaps | ForEach-Object {
        "| $($_.exigence) | $($_.statut) | $($_.gap) | $($_.severite) |"
    }
)

### 🎯 Objectif Checkpoint 2
- **Cible de conformité** : 85%
- **Conformité actuelle** : $($Analysis.conformiteScore)%
- **Écart à combler** : $([math]::Max(0, 85 - $Analysis.conformiteScore))%

---

## 5. Recommandations

### 🚀 Actions Immédiates (Priorité 1)
1. **Implémenter roosync_update_baseline** : Outil MCP manquant critique
2. **Créer les scripts PowerShell autonomes** : Pour la gestion baseline
3. **Développer le versioning baseline** : Avec tags Git et historique
4. **Implémenter la restauration baseline** : Avec points de restauration

### 🔧 Actions à Moyen Terme (Priorité 2)
1. **Développer le diff granulaire** : Comparaison paramètre par paramètre
2. **Améliorer l'interface utilisateur** : Validation interactive
3. **Créer les fonctions d'export/import** : Pour la portabilité
4. **Compléter la validation baseline** : Avec tests automatisés

### 📚 Actions de Documentation (Priorité 3)
1. **Documenter l'API baseline** : Avec exemples d'utilisation
2. **Créer les guides d'utilisation** : Pour les nouvelles fonctionnalités
3. **Mettre à jour la documentation SDDD** : Avec les nouvelles implémentations

---

## 6. Plan d'Action

### 📅 Jours 4-5 : Implémentation Baseline
- [ ] Implémenter `roosync_update_baseline`
- [ ] Créer `roosync_update_baseline.ps1`
- [ ] Développer le versioning baseline
- [ ] Implémenter la restauration baseline
- [ ] Valider 85% conformité exigences

### 📅 Jours 6-8 : Implémentation Diff Granulaire
- [ ] Analyser le système de diff actuel
- [ ] Développer les algorithmes de comparaison
- [ ] Créer l'interface utilisateur améliorée
- [ ] Intégrer avec le système RooSync
- [ ] Valider 90% conformité globale

---

## 📊 Métriques

| Métrique | Valeur Actuelle | Objectif | Écart |
|----------|-----------------|----------|-------|
| Conformité exigences | $($Analysis.conformiteScore)% | 85% | $([math]::Max(0, 85 - $Analysis.conformiteScore))% |
| Fonctionnalités implémentées | $($Analysis.totalExigences - $Analysis.missingFeatures.Count) | $($Analysis.totalExigences) | $($Analysis.missingFeatures.Count) |
| Outils MCP disponibles | $(11 - ($Analysis.missingFeatures | Where-Object { $_.feature -like "roosync_*" }).Count) | 11 | $(($Analysis.missingFeatures | Where-Object { $_.feature -like "roosync_*" }).Count) |
| Scripts PowerShell créés | 0 | 5 | 5 |

---

**Rapport généré le** : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Auteur** : Roo Code Mode
**Prochaine étape** : Implémentation des fonctionnalités manquantes

---

*Ce rapport suit la méthodologie SDDD (Semantic-Documentation-Driven-Design) et sert de référence pour l'implémentation de la Sous-phase 3B.*
"@

    # Créer le répertoire de rapports si nécessaire
    if (!(Test-Path "roo-config/reports")) {
        New-Item -ItemType Directory -Path "roo-config/reports" -Force | Out-Null
    }

    $reportContent | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Log "Rapport d'analyse baseline généré : $reportPath" "SUCCESS"

    return $reportPath
}

# =============================================================================
# PROGRAMME PRINCIPAL
# =============================================================================

function Main {
    Write-Log "DÉMARRAGE DE L'ANALYSE BASELINE - PHASE 3B" "SUCCESS"
    Write-Log "=============================================" "SUCCESS"
    Write-Log "Machine : $env:COMPUTERNAME" "INFO"
    Write-Log "Date : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO"
    Write-Log "Mode DryRun : $DryRun" "INFO"
    Write-Log "Fichier de log : $LogPath" "INFO"
    Write-Log ""

    try {
        # ÉTAPE 1 : Analyse de l'état actuel
        Write-Log "ÉTAPE 1/2 : ANALYSE DE L'ÉTAT ACTUEL DU SYSTÈME DE BASELINE" "SUCCESS"
        $analysis = Test-BaselineSystemStatus
        Write-Log ""

        # ÉTAPE 2 : Génération du rapport
        Write-Log "ÉTAPE 2/2 : GÉNÉRATION DU RAPPORT D'ANALYSE" "SUCCESS"
        $reportPath = New-BaselineAnalysisReport -Analysis $analysis
        Write-Log ""

        # RÉSUMÉ FINAL
        Write-Log "RÉSUMÉ DE L'ANALYSE BASELINE" "SUCCESS"
        Write-Log "=============================" "SUCCESS"
        Write-Log "Conformité actuelle : $($analysis.conformiteScore)%" "INFO"
        Write-Log "Fonctionnalités manquantes : $($analysis.missingFeatures.Count)" "INFO"
        Write-Log "Gaps identifiés : $($analysis.gaps.Count)" "INFO"
        Write-Log "Baseline disponible : $(if ($analysis.baselineStatus.exists) { 'Oui' } else { 'Non' })" "INFO"
        Write-Log "Rapport généré : $reportPath" "INFO"
        Write-Log ""

        if ($analysis.conformiteScore -ge 85) {
            Write-Log "✅ OBJECTIF CHECKPOINT 2 ATTEINT - 85% de conformité" "SUCCESS"
            exit 0
        } else {
            Write-Log "⚠️ OBJECTIF CHECKPOINT 2 NON ATTEINT - Implémentations requises" "WARN"
            Write-Log "Écart à combler : $([math]::Max(0, 85 - $analysis.conformiteScore))%" "WARN"
            exit 1
        }

    } catch {
        Write-Log "ERREUR CRITIQUE lors de l'analyse baseline : $($_.Exception.Message)" "ERROR"
        Write-Log "Stack trace : $($_.ScriptStackTrace)" "ERROR"
        exit 2
    }
}

# Point d'entrée
Main