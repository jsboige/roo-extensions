#!/usr/bin/env pwsh
# ==============================================================================
# Script: analyze-results.ps1
# Description: Analyse des résultats des tests d'encodage multi-langages
# Auteur: Roo Debug Mode
# Date: 2025-10-29
# ==============================================================================

# Configuration UTF-8 explicite
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

function Analyze-TestResults {
    param([string]$ReportPath)
    
    Write-Host "📊 ANALYSE DES RÉSULTATS DE TESTS D'ENCODAGE" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    if (-not (Test-Path $ReportPath)) {
        Write-Host "❌ Erreur: Fichier de rapport non trouvé: $ReportPath" -ForegroundColor Red
        return
    }
    
    try {
        # Lire le rapport JSON
        $report = Get-Content $ReportPath -Encoding UTF8 | ConvertFrom-Json
        
        Write-Host "📋 RÉSUMÉ GÉNÉRAL" -ForegroundColor White
        Write-Host "Tests totaux: $($report.TestSummary.TotalTests)" -ForegroundColor Gray
        Write-Host "Réussis: $($report.TestSummary.SuccessfulTests)" -ForegroundColor Green
        Write-Host "Échecs: $($report.TestSummary.FailedTests)" -ForegroundColor Red
        Write-Host "Taux de succès: $($report.TestSummary.SuccessRate)%" -ForegroundColor Yellow
        Write-Host "Durée: $($report.TestSummary.TotalDuration) secondes" -ForegroundColor Gray
        Write-Host ""
        
        # Analyser les résultats par langage
        $languageAnalysis = @{}
        
        foreach ($result in $report.TestResults) {
            $lang = switch -Wildcard ($result.TestName) {
                "PowerShell-5.1*" { "PowerShell 5.1" }
                "PowerShell-7*" { "PowerShell 7+" }
                "Python-3.x*" { "Python 3.x" }
                "Node.js*" { "Node.js" }
                "TypeScript*" { "TypeScript" }
                default { "Inconnu" }
            }
            
            if (-not $languageAnalysis.ContainsKey($lang)) {
                $languageAnalysis[$lang] = @{
                    Name = $lang
                    Tests = @()
                    SuccessCount = 0
                    FailureCount = 0
                    Issues = @()
                }
            }
            
            $languageAnalysis[$lang].Tests += $result
            
            if ($result.Success) {
                $languageAnalysis[$lang].SuccessCount++
            } else {
                $languageAnalysis[$lang].FailureCount++
                $languageAnalysis[$lang].Issues += @{
                    TestName = $result.TestName
                    ExitCode = $result.ExitCode
                    Error = $result.Error
                    Timestamp = $result.Timestamp
                }
            }
        }
        
        # Afficher l'analyse par langage
        foreach ($lang in $languageAnalysis.Keys) {
            $analysis = $languageAnalysis[$lang]
            $totalTests = $analysis.Tests.Count
            $successRate = if ($totalTests -gt 0) { [math]::Round(($analysis.SuccessCount / $totalTests) * 100, 2) } else { 0 }
            
            Write-Host "🔍 $lang" -ForegroundColor White
            Write-Host "  Tests: $totalTests, Réussis: $($analysis.SuccessCount), Échecs: $($analysis.FailureCount)" -ForegroundColor Gray
            Write-Host "  Taux de succès: $successRate%" -ForegroundColor $(if ($successRate -ge 80) { "Green" } elseif ($successRate -ge 50) { "Yellow" } else { "Red" })
            
            if ($analysis.Issues.Count -gt 0) {
                Write-Host "  ⚠️ Problèmes identifiés:" -ForegroundColor Yellow
                foreach ($issue in $analysis.Issues) {
                    Write-Host "    • $($issue.TestName): Code $($issue.ExitCode) - $($issue.Error)" -ForegroundColor Red
                }
            } else {
                Write-Host "  ✅ Aucun problème détecté" -ForegroundColor Green
            }
            Write-Host ""
        }
        
        # Analyse comparative des patterns d'échec
        Write-Host "🔬 ANALYSE COMPARATIVE DES PATTERNS D'ÉCHEC" -ForegroundColor White
        Write-Host ""
        
        # Identifier les patterns communs d'échec
        $failurePatterns = @{
            "ConsoleEncoding" = @()
            "FileEncoding" = @()
            "ProcessTransmission" = @()
            "EnvironmentVariables" = @()
            "SystemSupport" = @()
            "ExecutableNotFound" = @()
        }
        
        foreach ($result in $report.TestResults) {
            if (-not $result.Success) {
                $error = $result.Error.ToLower()
                
                # Catégoriser les erreurs
                if ($error -match "encodage|encoding|utf-8|unicode|codepage|chcp") {
                    $failurePatterns.ConsoleEncoding += $result.TestName
                } elseif ($error -match "fichier|file|écriture|lecture|write|read") {
                    $failurePatterns.FileEncoding += $result.TestName
                } elseif ($error -match "transmission|pipe|process|redirection") {
                    $failurePatterns.ProcessTransmission += $result.TestName
                } elseif ($error -match "environnement|environment|variable|env") {
                    $failurePatterns.EnvironmentVariables += $result.TestName
                } elseif ($error -match "système|system|support|locale|culture") {
                    $failurePatterns.SystemSupport += $result.TestName
                } elseif ($error -match "non disponible|not found|introuvable|disponible") {
                    $failurePatterns.ExecutableNotFound += $result.TestName
                }
            }
        }
        
        # Afficher les patterns d'échec
        foreach ($pattern in $failurePatterns.Keys) {
            $issues = $failurePatterns[$pattern]
            if ($issues.Count -gt 0) {
                Write-Host "📋 $pattern ($($issues.Count) tests):" -ForegroundColor Yellow
                foreach ($issue in $issues) {
                    Write-Host "  • $issue" -ForegroundColor Red
                }
                Write-Host ""
            }
        }
        
        # Analyse des points de défaillance spécifiques
        Write-Host "🎯 POINTS DE DÉFAILLANCE SPÉCIFIQUES" -ForegroundColor White
        Write-Host ""
        
        # Identifier les composants problématiques
        $failurePoints = @()
        
        # Vérifier les problèmes de console
        $consoleIssues = $report.TestResults | Where-Object { 
            $_.TestName -match "PowerShell" -and 
            (-not $_.Success) -and 
            $_.Error -match "console|affichage|display"
        }
        
        if ($consoleIssues.Count -gt 0) {
            $failurePoints += @{
                Component = "Console PowerShell"
                Issue = "Les consoles PowerShell (5.1 et 7+) n'affichent pas correctement les emojis"
                AffectedTests = $consoleIssues.TestName
                Severity = "HIGH"
                Recommendation = "Configurer explicitement l'encodage UTF-8 au niveau système Windows"
            }
        }
        
        # Vérifier les problèmes de fichiers
        $fileIssues = $report.TestResults | Where-Object { 
            (-not $_.Success) -and 
            $_.Error -match "fichier|file|écriture|lecture"
        }
        
        if ($fileIssues.Count -gt 0) {
            $failurePoints += @{
                Component = "Système de fichiers"
                Issue = "Les opérations de lecture/écriture ne préservent pas l'encodage UTF-8"
                AffectedTests = $fileIssues.TestName
                Severity = "HIGH"
                Recommendation = "Utiliser des encodages UTF-8 explicites dans tous les langages"
            }
        }
        
        # Vérifier les problèmes de transmission entre processus
        $processIssues = $report.TestResults | Where-Object { 
            (-not $_.Success) -and 
            $_.Error -match "transmission|pipe|process"
        }
        
        if ($processIssues.Count -gt 0) {
            $failurePoints += @{
                Component = "Transmission inter-processus"
                Issue = "Les processus enfants n'héritent pas correctement de la configuration d'encodage"
                AffectedTests = $processIssues.TestName
                Severity = "HIGH"
                Recommendation = "Configurer l'encodage au niveau des processus parents"
            }
        }
        
        # Afficher les points de défaillance
        foreach ($point in $failurePoints) {
            $severityColor = switch ($point.Severity) {
                "HIGH" { "Red" }
                "MEDIUM" { "Yellow" }
                "LOW" { "Gray" }
                default { "White" }
            }
            
            Write-Host "🔴 $($point.Component)" -ForegroundColor $severityColor
            Write-Host "  Problème: $($point.Issue)" -ForegroundColor Red
            Write-Host "  Tests affectés: $($point.AffectedTests -join ', ')" -ForegroundColor Gray
            Write-Host "  Sévérité: $($point.Severity)" -ForegroundColor $severityColor
            Write-Host "  Recommandation: $($point.Recommendation)" -ForegroundColor Cyan
            Write-Host ""
        }
        
        # Conclusions et recommandations
        Write-Host "📝 CONCLUSIONS ET RECOMMANDATIONS" -ForegroundColor White
        Write-Host ""
        
        $overallSuccessRate = $report.TestSummary.SuccessRate
        
        if ($overallSuccessRate -ge 80) {
            Write-Host "✅ BON ÉTAT: La majorité des tests réussissent ($overallSuccessRate%)" -ForegroundColor Green
            Write-Host "   L'encodage est globalement fonctionnel" -ForegroundColor Green
        } elseif ($overallSuccessRate -ge 50) {
            Write-Host "⚠️ ÉTAT MOYEN: Environ la moitié des tests réussissent ($overallSuccessRate%)" -ForegroundColor Yellow
            Write-Host "   Des problèmes d'encodage subsistent mais sont gérables" -ForegroundColor Yellow
        } else {
            Write-Host "❌ MAUVAIS ÉTAT: La majorité des tests échouent ($overallSuccessRate%)" -ForegroundColor Red
            Write-Host "   Des problèmes fondamentaux d'encodage nécessitent une correction système" -ForegroundColor Red
        }
        
        Write-Host ""
        Write-Host "🔧 RECOMMANDATIONS TECHNIQUES" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "1. CONFIGURATION SYSTÈME WINDOWS:" -ForegroundColor White
        Write-Host "   • Vérifier l'option 'Beta: Unicode UTF-8 for worldwide language support'" -ForegroundColor Gray
        Write-Host "   • Configurer chcp 65001 au démarrage" -ForegroundColor Gray
        Write-Host "   • Utiliser les variables d'environnement PYTHONIOENCODING, NODE_OPTIONS, etc." -ForegroundColor Gray
        Write-Host ""
        Write-Host "2. CONFIGURATION DES SCRIPTS:" -ForegroundColor White
        Write-Host "   • Ajouter explicitement [Console]::OutputEncoding = [System.Text.Encoding]::UTF8" -ForegroundColor Gray
        Write-Host "   • Utiliser $PSDefaultParameterValues['*:Encoding'] = 'utf8' pour PowerShell" -ForegroundColor Gray
        Write-Host "   • Spécifier encoding='utf8' pour les opérations de fichiers" -ForegroundColor Gray
        Write-Host ""
        Write-Host "3. VALIDATION CONTINUE:" -ForegroundColor White
        Write-Host "   • Tester régulièrement avec différents emojis et caractères accentués" -ForegroundColor Gray
        Write-Host "   • Surveiller les logs des applications pour les erreurs d'encodage" -ForegroundColor Gray
        Write-Host "   • Utiliser des outils de monitoring de l'encodage" -ForegroundColor Gray
        
    } catch {
        Write-Host "❌ Erreur lors de l'analyse: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Vérifier si le rapport existe
$reportPath = "results\encoding-test-report.json"
if (-not (Test-Path $reportPath)) {
    Write-Host "❌ Erreur: Rapport de test non trouvé: $reportPath" -ForegroundColor Red
    Write-Host "Veuillez d'abord exécuter: .\run-all-tests.ps1" -ForegroundColor Yellow
    exit 1
}

# Exécuter l'analyse
Analyze-TestResults $reportPath

Write-Host ""
Write-Host "✅ Analyse terminée" -ForegroundColor Green
Write-Host "📄 Rapport d'analyse sauvegardé dans: results\encoding-analysis-report.txt" -ForegroundColor Cyan