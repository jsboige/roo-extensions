<#
.SYNOPSIS
    Génère un rapport de validation UTF-8 basé sur les résultats du script de validation
.DESCRIPTION
    Ce script analyse les résultats de validation UTF-8 et génère un rapport
    structuré pour suivre l'efficacité de l'activation UTF-8 beta.
    Il consolide les données de validation et produit des métriques de performance.
.PARAMETER ValidationResultsPath
    Chemin vers le fichier de résultats de validation (JSON)
.PARAMETER OutputFormat
    Format de sortie du rapport (Markdown, HTML, JSON)
.PARAMETER IncludeRecommendations
    Inclut des recommandations basées sur les résultats
.EXAMPLE
    .\Generate-UTF8ValidationReport.ps1 -ValidationResultsPath "results\validation-results.json"
.EXAMPLE
    .\Generate-UTF8ValidationReport.ps1 -ValidationResultsPath "results\validation-results.json" -OutputFormat HTML -IncludeRecommendations
.NOTES
    Auteur: Roo Architect Complex Mode
    Version: 1.0
    Date: 2025-10-30
    ID Correction: SYS-001-REPORT
    Priorité: CRITIQUE
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ValidationResultsPath,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Markdown", "HTML", "JSON")]
    [string]$OutputFormat = "Markdown",
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeRecommendations
)

# Configuration du script
$script:LogFile = "logs\Generate-UTF8ValidationReport-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Fonctions de logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    Write-Host $logEntry -ForegroundColor $(
        switch ($Level) {
            "ERROR" { "Red" }
            "WARN" { "Yellow" }
            "SUCCESS" { "Green" }
            "INFO" { "Cyan" }
            default { "White" }
        }
    )
    
    # Création du répertoire de logs si nécessaire
    if (!(Test-Path "logs")) {
        New-Item -ItemType Directory -Path "logs" -Force | Out-Null
    }
    
    # Écriture dans le fichier de log
    Add-Content -Path $script:LogFile -Value $logEntry -Encoding UTF8
}

function Write-Success {
    param([string]$Message)
    Write-Log $Message "SUCCESS"
}

function Write-Error {
    param([string]$Message)
    Write-Log $Message "ERROR"
}

function Write-Info {
    param([string]$Message)
    Write-Log $Message "INFO"
}

# Analyse des résultats de validation
function Read-ValidationResults {
    param([string]$ResultsPath)
    
    Write-Info "Lecture des résultats de validation: $ResultsPath"
    
    try {
        if (-not (Test-Path $ResultsPath)) {
            Write-Error "Fichier de résultats introuvable: $ResultsPath"
            return $null
        }
        
        $content = Get-Content -Path $ResultsPath -Raw -Encoding UTF8
        
        # Tentative de parsing JSON
        try {
            $results = $content | ConvertFrom-Json
            Write-Success "Résultats de validation chargés: $($results.PSObject.Properties.Count) entrées"
            return $results
        } catch {
            Write-Error "Erreur lors du parsing JSON: $($_.Exception.Message)"
            return $null
        }
        
    } catch {
        Write-Error "Erreur lors de la lecture des résultats: $($_.Exception.Message)"
        return $null
    }
}

# Génération des recommandations
function New-Recommendations {
    param([hashtable]$ValidationResults)
    
    $recommendations = @()
    
    # Analyse des échecs et recommandations
    foreach ($result in $ValidationResults.results) {
        if (-not $result.Success) {
            switch ($result.TestName) {
                "SystemCodePages" {
                    $recommendations += "Activer les pages de code UTF-8 (65001) via le registre Windows"
                    $recommendations += "Redémarrer le système après modification du registre"
                }
                
                "RegionalSettings" {
                    $recommendations += "Configurer les paramètres régionaux sur fr-FR.UTF-8"
                    $recommendations += "Vérifier la cohérence des paramètres internationaux"
                }
                
                "ConsoleEncoding" {
                    $recommendations += "Exécuter 'chcp 65001' dans chaque session PowerShell"
                    $recommendations += "Configurer Windows Terminal comme terminal par défaut"
                }
                
                "FileSystemEncoding" {
                    $recommendations += "Vérifier les permissions des répertoires de test"
                    $recommendations += "S'assurer que l'espace disque est suffisant"
                }
                
                "PowerShellEncoding" {
                    $recommendations += "Configurer [Console]::OutputEncoding = [System.Text.Encoding]::UTF8"
                    $recommendations += "Mettre à jour PowerShell vers la version 7+ si possible"
                }
                
                "ApplicationCompatibility" {
                    $recommendations += "Mettre à jour les applications non compatibles UTF-8"
                    $recommendations += "Installer les dernières versions des outils de développement"
                }
                
                default {
                    $recommendations += "Consulter les logs détaillés pour diagnostic"
                    $recommendations += "Exécuter le script d'activation UTF-8 avec le paramètre -Force"
                }
            }
        }
    }
    
    # Recommandations générales
    $successRate = $ValidationResults.summary.successRate
    if ($successRate -lt 95) {
        $recommendations += "Le taux de succès global est inférieur à 95% - une révision complète est recommandée"
        $recommendations += "Exécuter le script Enable-UTF8WorldwideSupport.ps1 avec le paramètre -Force pour corriger les problèmes"
    }
    
    if ($successRate -ge 95) {
        $recommendations += "La configuration UTF-8 est validée avec succès"
        $recommendations += "Continuer vers le Jour 3-3: Standardisation Registre UTF-8"
    }
    
    return $recommendations
}

# Génération du rapport Markdown
function New-MarkdownReport {
    param([hashtable]$ValidationResults, [array]$Recommendations)
    
    $report = @"
# Rapport de Validation UTF-8 - Synthèse

**Date**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Script**: Generate-UTF8ValidationReport.ps1
**Version**: 1.0
**ID Correction**: SYS-001-REPORT
**Priorité**: CRITIQUE

## 📊 Résumé Exécutif

### Métriques Globales
- **Tests Total**: $($ValidationResults.summary.totalTests)
- **Tests Réussis**: $($ValidationResults.summary.successfulTests)
- **Tests Échoués**: $($ValidationResults.summary.failedTests)
- **Taux de Succès**: $($ValidationResults.summary.successRate)%
- **Statut Global**: $(if ($ValidationResults.summary.overallSuccess) { "✅ SUCCÈS" } else { "❌ ÉCHEC" })

### Performance Système
- **Temps d'Exécution**: $(if ($ValidationResults.metadata.executionTime) { $ValidationResults.metadata.executionTime } else { "Non disponible" })
- **Mémoire Utilisée**: $(if ($ValidationResults.metadata.memoryUsage) { $ValidationResults.metadata.memoryUsage } else { "Non disponible" })
- **Version Windows**: $(if ($ValidationResults.metadata.windowsVersion) { $ValidationResults.metadata.windowsVersion } else { "Non disponible" })

## 📋 Résultats Détaillés

$($ValidationResults.results | ForEach-Object {
    "### $($_.TestName)"
    "#### Statut"
    - **Résultat**: $(if ($_.Success) { "✅ SUCCÈS" } else { "❌ ÉCHEC" })
    - **Score**: $(if ($_.Score) { $_.Score } else { "N/A" })
    
    "#### Détails Techniques"
    $($_.Details | ForEach-Object {
        "- **$($_.Key)**: $($_.Value)"
    })"
    
    $(if ($_.Issues.Count -gt 0) {
        "#### Problèmes Détectés"
        $($_.Issues | ForEach-Object {
            "- $($_)"
        })"
    })
    
    $(if ($_.Recommendations.Count -gt 0) {
        "#### Recommandations Spécifiques"
        $($_.Recommendations | ForEach-Object {
            "- $($_)"
        })"
    })
    
    ""
})

## 🎯 Recommandations Globales

$(if ($Recommendations.Count -gt 0) {
    $Recommendations | ForEach-Object {
        "- $($_)"
    }
} else {
    "- Aucune recommandation - la validation est réussie"
})

## 📈 Tendances et Prochaines Étapes

### Analyse des Tendances
- **Points forts**: $(if ($ValidationResults.summary.successRate -ge 95) { "Configuration UTF-8 robuste" } else { "Problèmes de configuration détectés" })
- **Axes d'amélioration**: $(if ($ValidationResults.summary.successRate -lt 95) { "Standardisation registre et environnement" } else { "Monitoring et maintenance" })

### Prochaines Actions
$(if ($ValidationResults.summary.overallSuccess) {
    "- ✅ **Continuer vers Jour 3-3**: Standardisation Registre UTF-8"
    "- ✅ **Mettre à jour la matrice de traçabilité**: Enregistrer SYS-001 comme complété"
} else {
    "- ⚠️ **Actions correctives immédiates**:
      1. Réexécuter Enable-UTF8WorldwideSupport.ps1 avec -Force
      2. Diagnostiquer les problèmes persistants
      3. Valider manuellement si nécessaire"
    "- 🔄 **Nouvelle tentative de validation**: Réexécuter Test-UTF8Activation.ps1 après corrections"
})

## 📝 Métadonnées du Rapport

- **Généré le**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- **Source**: Script Generate-UTF8ValidationReport.ps1
- **Format**: Markdown 1.0
- **ID Suivi**: SYS-001-REPORT-$(Get-Date -Format 'yyyyMMdd-HHmmss')

---

**Statut**: $(if ($ValidationResults.summary.overallSuccess) { "✅ VALIDATION RÉUSSIE" } else { "⚠️ VALIDATION PARTIELLE - ACTIONS REQUISES" })
**Prochaine Étape**: $(if ($ValidationResults.summary.overallSuccess) { "Jour 3-3: Standardisation Registre UTF-8" } else { "Correction des problèmes détectés" })
"@
    
    return $report
}

# Génération du rapport HTML
function New-HTMLReport {
    param([hashtable]$ValidationResults, [array]$Recommendations)
    
    $htmlReport = @"
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Rapport de Validation UTF-8</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .metric { background: #f8f9fa; padding: 15px; border-radius: 6px; text-align: center; }
        .metric-value { font-size: 24px; font-weight: bold; color: #2c3e50; }
        .metric-label { font-size: 12px; color: #6c757d; margin-top: 5px; }
        .success { color: #28a745; }
        .error { color: #dc3545; }
        .warning { color: #ffc107; }
        .test-result { margin-bottom: 20px; padding: 20px; border-left: 4px solid #007bff; background: #f8f9fa; }
        .test-name { font-size: 18px; font-weight: bold; margin-bottom: 10px; color: #495057; }
        .test-status { font-size: 16px; margin-bottom: 15px; }
        .details { margin-top: 10px; }
        .issues { background: #fff3cd; border: 1px solid #ffeaa7; padding: 10px; border-radius: 4px; margin-top: 10px; }
        .recommendations { background: #d1ecf1; border: 1px solid #bee5eb; padding: 15px; border-radius: 4px; margin-top: 10px; }
        .next-steps { background: #e7f3ff; border: 1px solid #b3d4ff; padding: 20px; border-radius: 6px; margin-top: 30px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔧 Rapport de Validation UTF-8</h1>
            <p><strong>Date:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
            <p><strong>ID Correction:</strong> SYS-001-REPORT</p>
        </div>
        
        <div class="summary">
            <div class="metric">
                <div class="metric-value $($ValidationResults.summary.totalTests)">$(ValidationResults.summary.totalTests)</div>
                <div class="metric-label">Tests Total</div>
            </div>
            <div class="metric">
                <div class="metric-value success">$($ValidationResults.summary.successfulTests)</div>
                <div class="metric-label">Tests Réussis</div>
            </div>
            <div class="metric">
                <div class="metric-value error">$($ValidationResults.summary.failedTests)</div>
                <div class="metric-label">Tests Échoués</div>
            </div>
            <div class="metric">
                <div class="metric-value $(if ($ValidationResults.summary.successRate -ge 95) { "success" } else { "error" })">$($ValidationResults.summary.successRate)%</div>
                <div class="metric-label">Taux de Succès</div>
            </div>
            <div class="metric">
                <div class="metric-value $(if ($ValidationResults.summary.overallSuccess) { "success" } else { "error" })">$(if ($ValidationResults.summary.overallSuccess) { "✅" } else { "❌" })</div>
                <div class="metric-label">Statut Global</div>
            </div>
        </div>
        
        <h2>📋 Résultats Détaillés</h2>
        
        $(
            $ValidationResults.results | ForEach-Object {
                "<div class='test-result'>
                    <div class='test-name'>$($_.TestName)</div>
                    <div class='test-status'>
                        <strong>Résultat:</strong> 
                        <span class='$(if ($_.Success) { "success" } else { "error" })'>
                            $(if ($_.Success) { "✅ SUCCÈS" } else { "❌ ÉCHEC" })
                        </span>
                    </div>
                    $(if ($_.Details) {
                        "<div class='details'>
                            <h4>Détails Techniques:</h4>
                            $(
                                $_.Details.PSObject.Properties | ForEach-Object {
                                    "<div><strong>$($_.Name):</strong> $($_.Value)</div>"
                                }
                            )
                        </div>"
                    })
                    $(if ($_.Issues.Count -gt 0) {
                        "<div class='issues'>
                            <h4>Problèmes Détectés:</h4>
                            $(
                                $_.Issues | ForEach-Object {
                                    "<div>• $($_)</div>"
                                }
                            )
                        </div>"
                    })
                    $(if ($_.Recommendations.Count -gt 0) {
                        "<div class='recommendations'>
                            <h4>Recommandations:</h4>
                            $(
                                $_.Recommendations | ForEach-Object {
                                    "<div>• $($_)</div>"
                                }
                            )
                        </div>"
                    })
                </div>"
            }
        )
        
        $(if ($Recommendations.Count -gt 0) {
            "<div class='recommendations'>
                <h2>🎯 Recommandations Globales</h2>
                $(
                    $Recommendations | ForEach-Object {
                        "<div>• $($_)</div>"
                    }
                )
            </div>"
        }
        
        <div class='next-steps'>
            <h2>📈 Prochaines Étapes</h2>
            $(if ($ValidationResults.summary.overallSuccess) {
                "<div class='success'>
                    <p><strong>✅ Continuer vers Jour 3-3:</strong> Standardisation Registre UTF-8</p>
                    <p>Mettre à jour la matrice de traçabilité avec SYS-001 complété</p>
                </div>"
            } else {
                "<div class='error'>
                    <p><strong>⚠️ Actions correctives immédiates:</strong></p>
                    <ol>
                        <li>Réexécuter Enable-UTF8WorldwideSupport.ps1 avec -Force</li>
                        <li>Diagnostiquer les problèmes persistants</li>
                        <li>Valider manuellement si nécessaire</li>
                    </ol>
                    <p><strong>🔄 Nouvelle tentative de validation:</strong> Réexécuter Test-UTF8Activation.ps1 après corrections</p>
                </div>"
            })
        </div>
    </div>
</body>
</html>
"@
    
    return $htmlReport
}

# Programme principal
function Main {
    Write-Info "Début du script Generate-UTF8ValidationReport.ps1"
    Write-Info "ID Correction: SYS-001-REPORT"
    Write-Info "Priorité: CRITIQUE"
    
    try {
        # Lecture des résultats de validation
        $validationResults = Read-ValidationResults -ResultsPath $ValidationResultsPath
        
        if (-not $validationResults) {
            Write-Error "Impossible de lire les résultats de validation"
            exit 1
        }
        
        # Génération des recommandations si demandé
        $recommendations = @()
        if ($IncludeRecommendations) {
            $recommendations = New-Recommendations -ValidationResults $validationResults
        }
        
        # Génération du rapport selon le format
        $reportPath = "results\UTF8-Validation-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').$($OutputFormat.ToLower())"
        
        switch ($OutputFormat) {
            "Markdown" {
                $report = New-MarkdownReport -ValidationResults $validationResults -Recommendations $recommendations
                $report | Out-File -FilePath $reportPath -Encoding UTF8 -Force
            }
            
            "HTML" {
                $report = New-HTMLReport -ValidationResults $validationResults -Recommendations $recommendations
                $report | Out-File -FilePath $reportPath -Encoding UTF8 -Force
            }
            
            "JSON" {
                $validationResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8 -Force
            }
            
            default {
                Write-Error "Format de sortie non supporté: $OutputFormat"
                exit 1
            }
        }
        
        Write-Success "Rapport généré: $reportPath"
        
    } catch {
        Write-Error "Erreur inattendue: $($_.Exception.Message)"
        Write-Error "Stack Trace: $($_.ScriptStackTrace)"
        exit 1
    }
}

# Point d'entrée principal
Main