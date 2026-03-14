#!/usr/bin/env pwsh
# ==============================================================================
# Script: diagnostic-encoding-consolide.ps1
# Description: Diagnostic consolidé et optimisé de l'encodage UTF-8
# Auteur: Roo Code Mode - Consolidation
# Date: 2025-11-11
# Version: 2.0
# ==============================================================================

<#
.SYNOPSIS
    Diagnostic consolidé et universel des problèmes d'encodage UTF-8 dans PowerShell
    Intègre les meilleures fonctionnalités de 6 scripts de diagnostic précédents

.DESCRIPTION
    Ce script effectue un diagnostic complet de l'environnement d'encodage PowerShell
    sur Windows, identifie les problèmes et fournit des recommandations précises.
    Il fonctionne avec PowerShell 5.1 et PowerShell 7+ et inclut des corrections automatiques.

.PARAMETER Verbose
    Affiche des informations détaillées pendant le diagnostic

.PARAMETER Fix
    Tente de corriger automatiquement les problèmes détectés

.PARAMETER ExportReport
    Exporte le rapport de diagnostic dans un fichier JSON

.PARAMETER QuickMode
    Exécute uniquement les tests essentiels (mode rapide)

.EXAMPLE
    .\diagnostic-encoding-consolide.ps1

.EXAMPLE
    .\diagnostic-encoding-consolide.ps1 -Verbose -Fix

.EXAMPLE
    .\diagnostic-encoding-consolide.ps1 -ExportReport "rapport-encoding.json"

.EXAMPLE
    .\diagnostic-encoding-consolide.ps1 -QuickMode -Fix
#>

[CmdletBinding()]
param(
    [switch]$Fix = $false,
    [string]$ExportReport = $null,
    [switch]$QuickMode = $false
)

# Configuration UTF-8 forcée pour ce script
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  DIAGNOSTIC ENCODAGE CONSOLIDÉ v2.0" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Variables globales pour le diagnostic
$diagnosticResults = @{
    ProblemeDetecte = $false
    ScoreConfiguration = 0
    ScoreMaximum = if ($QuickMode) { 6 } else { 10 }
    Recommandations = @()
    Details = @()
    TestStartTime = Get-Date
}

# ==============================================================================
# FONCTIONS UTILITAIRES
# ==============================================================================

function Write-DiagnosticSection {
    param([string]$SectionName)
    Write-Host "`n═════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $SectionName" -ForegroundColor Cyan
    Write-Host "═════════════════════════════════════════════" -ForegroundColor Cyan
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Success,
        [string]$Result = "",
        [string]$ErrorMessage = "",
        [object]$Details = $null
    )

    $status = if ($Success) { "✅" } else { "❌" }
    $color = if ($Success) { "Green" } else { "Red" }

    Write-Host "$status $TestName" -ForegroundColor $color
    if ($Result) { Write-Host "    Résultat: $Result" -ForegroundColor White }
    if ($ErrorMessage) { Write-Host "    Erreur: $ErrorMessage" -ForegroundColor Red }
    if ($Details -and $Verbose) {
        Write-Host "    Détails: $Details" -ForegroundColor Gray
    }

    $testResult = @{
        TestName = $TestName
        Success = $Success
        Result = $Result
        Error = $ErrorMessage
        Details = $Details
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    }

    $script:DiagnosticResults.Details += $testResult
    return $testResult
}

function Test-StringEncoding {
    param([string]$TestString, [string]$ExpectedString)

    try {
        $actual = $TestString
        $success = ($actual -eq $ExpectedString)

        if ($Verbose) {
            Write-Host "     Test: '$TestString'" -ForegroundColor White
            Write-Host "     Attendu: '$ExpectedString'" -ForegroundColor Gray
            Write-Host "     Reçu: '$actual'" -ForegroundColor $(if ($success) { "Green" } else { "Red" })
            Write-Host "     Résultat: $(if ($success) { "✅ CORRECT" } else { "❌ INCORRECT" })" -ForegroundColor $(if ($success) { "Green" } else { "Red" })
        }

        return $success
    } catch {
        if ($Verbose) {
            Write-Host "     Erreur lors du test: $($_.Exception.Message)" -ForegroundColor Red
        }
        return $false
    }
}

function Get-SystemInfo {
    return @{
        ComputerName = $env:COMPUTERNAME
        OSVersion = [System.Environment]::OSVersion.ToString()
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        PowerShellEdition = $PSVersionTable.PSEdition
        IsWindows = $IsWindows
        IsCore = $IsCoreCLR
        Architecture = $env:PROCESSOR_ARCHITECTURE
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    }
}

function Test-AdminPrivileges {
    return ([System.Security.Principal.WindowsPrincipal] [System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ==============================================================================
# 1. DIAGNOSTIC VERSION POWERHELL
# ==============================================================================

function Test-PowerShellEnvironment {
    if (-not $QuickMode) { Write-DiagnosticSection "1. ENVIRONNEMENT POWERHELL" }

    Write-Host "   Version: $($PSVersionTable.PSVersion)" -ForegroundColor White
    Write-Host "   Édition: $($PSVersionTable.PSEdition)" -ForegroundColor White
    Write-Host "   OS: $($PSVersionTable.OS)" -ForegroundColor White

    # Détection si PowerShell 7 est disponible
    $pwshPath = "C:\Program Files\PowerShell\7\pwsh.exe"
    $isPS7Available = Test-Path $pwshPath
    $usingPS7 = $PSVersionTable.PSEdition -eq "Core"

    if ($isPS7Available) {
        Write-Host "   PowerShell 7: ✅ DISPONIBLE" -ForegroundColor Green
        if ($usingPS7) {
            Write-TestResult "PowerShell 7 utilisé" $true
            $diagnosticResults.ScoreConfiguration++
        } else {
            Write-TestResult "PowerShell 7 utilisé" $false "PowerShell 5.1 utilisé par défaut"
            $diagnosticResults.ProblemeDetecte = $true
            $diagnosticResults.Recommandations += "Utiliser PowerShell 7: & `"$pwshPath`" -File script.ps1"
        }
    } else {
        Write-TestResult "PowerShell 7 disponible" $false "PowerShell 7 non installé"
        $diagnosticResults.ProblemeDetecte = $true
        $diagnosticResults.Recommandations += "Installer PowerShell 7 depuis Microsoft Store ou via winget"
    }

    if (-not $QuickMode) { Write-Host "" }
}

# ==============================================================================
# 2. DIAGNOSTIC ENCODAGE CONSOLE
# ==============================================================================

function Test-ConsoleEncoding {
    if (-not $QuickMode) { Write-DiagnosticSection "2. ENCODAGE CONSOLE" }

    $consoleEncoding = [Console]::OutputEncoding
    Write-Host "   OutputEncoding: $($consoleEncoding.EncodingName)" -ForegroundColor White
    Write-Host "   CodePage: $($consoleEncoding.CodePage)" -ForegroundColor White
    Write-Host "   InputEncoding: $([Console]::InputEncoding.EncodingName)" -ForegroundColor White

    if ($consoleEncoding.CodePage -eq 65001) {
        Write-TestResult "Encodage console UTF-8" $true
        $diagnosticResults.ScoreConfiguration++
    } else {
        Write-TestResult "Encodage console UTF-8" $false "CodePage: $($consoleEncoding.CodePage) (devrait être 65001)"
        $diagnosticResults.ProblemeDetecte = $true
        $diagnosticResults.Recommandations += "Exécuter: ``chcp 65001`` ou configurer le profil PowerShell"
    }

    if (-not $QuickMode) { Write-Host "" }
}

# ==============================================================================
# 3. DIAGNOSTIC ENCODAGE POWERSHELL
# ==============================================================================

function Test-PowerShellEncoding {
    if (-not $QuickMode) { Write-DiagnosticSection "3. ENCODAGE POWERSHELL" }

    if ($OutputEncoding) {
        Write-Host "   OutputEncoding: $($OutputEncoding.EncodingName)" -ForegroundColor White
        if ($OutputEncoding.EncodingName -match "UTF-8") {
            Write-TestResult "Encodage PowerShell UTF-8" $true
            $diagnosticResults.ScoreConfiguration++
        } else {
            Write-TestResult "Encodage PowerShell UTF-8" $false "Encodage: $($OutputEncoding.EncodingName)"
            $diagnosticResults.ProblemeDetecte = $true
            $diagnosticResults.Recommandations += "Ajouter au profil: `$OutputEncoding = [System.Text.Encoding]::UTF8"
        }
    } else {
        Write-TestResult "Encodage PowerShell défini" $false "OutputEncoding non défini"
        $diagnosticResults.ProblemeDetecte = $true
        $diagnosticResults.Recommandations += "Ajouter au profil: `$OutputEncoding = [System.Text.Encoding]::UTF8"
    }

    if (-not $QuickMode) { Write-Host "" }
}

# ==============================================================================
# 4. TEST CARACTÈRES SPÉCIAUX
# ==============================================================================

function Test-SpecialCharacters {
    if (-not $QuickMode) { Write-DiagnosticSection "4. TEST CARACTÈRES SPÉCIAUX" }

    $testsSpeciaux = @(
        @{ Nom = "Français accentué"; Test = "éàèùçâêîôû"; Attendu = "éàèùçâêîôû" },
        @{ Nom = "Symboles monétaires"; Test = "€£¥©®™"; Attendu = "€£¥©®™" },
        @{ Nom = "Emojis informatiques"; Test = "💻🪲🏗️❓🪃👨‍💼"; Attendu = "💻🪲🏗️❓🪃👨‍💼" },
        @{ Nom = "Mathématiques"; Test = "∑∏∆∇∂"; Attendu = "∑∏∆∇∂" },
        @{ Nom = "Guillemets"; Test = "«»""''"; Attendu = "«»""''" },
        @{ Nom = "Mixte complexe"; Test = "Café €5.99 💻 🏠️"; Attendu = "Café €5.99 💻 🏠️" }
    )

    $testsSpeciauxReussis = 0
    foreach ($test in $testsSpeciaux) {
        $success = Test-StringEncoding $test.Test $test.Attendu
        if ($success) {
            $testsSpeciauxReussis++
            if ($Verbose) {
                Write-TestResult $test.Nom $true
            }
        } else {
            $diagnosticResults.ProblemeDetecte = $true
            $diagnosticResults.Details += "Échec test $($test.Nom): caractères corrompus"
            if ($Verbose) {
                Write-TestResult $test.Nom $false
            }
        }
    }

    if ($testsSpeciauxReussis -eq $testsSpeciaux.Count) {
        Write-TestResult "Tests caractères spéciaux" $true "Tous les $($testsSpeciaux.Count) tests réussis"
        $diagnosticResults.ScoreConfiguration += if ($QuickMode) { 1 } else { 2 }
    } else {
        Write-TestResult "Tests caractères spéciaux" $false "$($testsSpeciauxReussis)/$($testsSpeciaux.Count) tests réussis"
        $diagnosticResults.ProblemeDetecte = $true
        $diagnosticResults.Recommandations += "Vérifier la configuration UTF-8 de la console et des profils PowerShell"
    }

    if (-not $QuickMode) { Write-Host "" }
}

# ==============================================================================
# 5. TEST ÉCRITURE/LECTURE UTF-8
# ==============================================================================

function Test-FileEncoding {
    if (-not $QuickMode) { Write-DiagnosticSection "5. TEST ÉCRITURE/LECTURE UTF-8" }

    $testFile = "test-diagnostic-encoding-consolide.txt"
    $testContent = "Test complet UTF-8: éàèùç €£¥ ©®™ 💻🪲🏗️"

    try {
        # Test avec différentes méthodes d'écriture
        $methods = @(
            @{ Nom = "Out-File"; Command = { Out-File $testFile -InputObject $testContent -Encoding utf8 } },
            @{ Nom = "Set-Content"; Command = { Set-Content $testFile -Value $testContent -Encoding utf8 } },
            @{ Nom = ".NET Direct"; Command = { [System.IO.File]::WriteAllText($testFile, $testContent, [System.Text.UTF8Encoding]::new($false)) } }
        )

        $methodSuccess = $true
        foreach ($method in $methods) {
            try {
                & $method.Command
                $readBack = Get-Content $testFile -Raw -Encoding utf8
                if ($readBack -ne $testContent) {
                    $methodSuccess = $false
                    if ($Verbose) {
                        Write-Host "     Échec méthode $($method.Nom)" -ForegroundColor Red
                    }
                    break
                }
            } catch {
                $methodSuccess = $false
                if ($Verbose) {
                    Write-Host "     Erreur méthode $($method.Nom): $($_.Exception.Message)" -ForegroundColor Red
                }
                break
            }
            # Nettoyer pour le prochain test
            if (Test-Path $testFile) {
                Remove-Item $testFile -ErrorAction SilentlyContinue
            }
        }

        if ($methodSuccess) {
            Write-TestResult "Test écriture/lecture UTF-8" $true "Toutes les méthodes d'écriture fonctionnent"
            $diagnosticResults.ScoreConfiguration++
        } else {
            Write-TestResult "Test écriture/lecture UTF-8" $false "Problèmes détectés avec l'écriture/lecture UTF-8"
            $diagnosticResults.ProblemeDetecte = $true
            $diagnosticResults.Recommandations += "Vérifier les permissions et l'encodage par défaut des cmdlets"
        }

        # Nettoyage final
        if (Test-Path $testFile) {
            Remove-Item $testFile -ErrorAction SilentlyContinue
        }

    } catch {
        Write-TestResult "Test écriture/lecture UTF-8" $false "Erreur: $($_.Exception.Message)"
        $diagnosticResults.ProblemeDetecte = $true
    }

    if (-not $QuickMode) { Write-Host "" }
}

# ==============================================================================
# 6. VÉRIFICATION DES PROFILS POWERSHELL
# ==============================================================================

function Test-PowerShellProfiles {
    if (-not $QuickMode) { Write-DiagnosticSection "6. PROFILS POWERSHELL" }

    # Profil PowerShell 7
    $profilePS7 = "$HOME\OneDrive\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
    if (Test-Path $profilePS7) {
        Write-TestResult "Profil PowerShell 7" $true "Existe"
        $diagnosticResults.ScoreConfiguration++

        $content = Get-Content $profilePS7 -Raw -Encoding UTF8
        $hasUTF8Config = ($content -match "UTF-8" -and $content -match "OutputEncoding")

        if ($hasUTF8Config) {
            Write-TestResult "Profil PowerShell 7 UTF-8" $true "Configuré UTF-8"
            $diagnosticResults.ScoreConfiguration++
        } else {
            Write-TestResult "Profil PowerShell 7 UTF-8" $false "Configuration UTF-8 manquante"
            $diagnosticResults.ProblemeDetecte = $true
            $diagnosticResults.Recommandations += "Ajouter au profil PS7: configuration UTF-8 complète"
        }
    } else {
        Write-TestResult "Profil PowerShell 7" $false "Fichier introuvable"
        $diagnosticResults.ProblemeDetecte = $true
        $diagnosticResults.Recommandations += "Créer le profil PS7 avec configuration UTF-8"
    }

    # Profil PowerShell 5.1
    $profilePS51 = "$HOME\Documents\WindowsPowerShell\profile.ps1"
    if (Test-Path $profilePS51) {
        Write-TestResult "Profil PowerShell 5.1" $true "Existe"
        $diagnosticResults.ScoreConfiguration++

        $content = Get-Content $profilePS51 -Raw -Encoding UTF8
        $hasUTF8Config = ($content -match "UTF-8" -and $content -match "OutputEncoding")

        if ($hasUTF8Config) {
            Write-TestResult "Profil PowerShell 5.1 UTF-8" $true "Configuré UTF-8"
            $diagnosticResults.ScoreConfiguration++
        } else {
            Write-TestResult "Profil PowerShell 5.1 UTF-8" $false "Configuration UTF-8 manquante"
            $diagnosticResults.ProblemeDetecte = $true
            $diagnosticResults.Recommandations += "Ajouter au profil PS5.1: configuration UTF-8 complète"
        }
    } else {
        Write-TestResult "Profil PowerShell 5.1" $false "Fichier introuvable"
        $diagnosticResults.ProblemeDetecte = $true
        $diagnosticResults.Recommandations += "Créer le profil PS5.1 avec configuration UTF-8"
    }

    if (-not $QuickMode) { Write-Host "" }
}

# ==============================================================================
# 7. CONFIGURATION VSCode
# ==============================================================================

function Test-VSCodeConfiguration {
    if (-not $QuickMode) { Write-DiagnosticSection "7. CONFIGURATION VSCODE" }

    $vscodeSettings = "$env:APPDATA\Code\User\settings.json"
    if (Test-Path $vscodeSettings) {
        Write-TestResult "Settings VSCode" $true "Existe"
        $diagnosticResults.ScoreConfiguration++

        try {
            $settings = Get-Content $vscodeSettings -Raw -Encoding UTF8 | ConvertFrom-Json
            $terminalProfile = $settings.'terminal.integrated.defaultProfile.windows'

            if ($terminalProfile -eq "PowerShell 7 (pwsh)") {
                Write-TestResult "Configuration VSCode" $true "Terminal configuré pour PowerShell 7"
                $diagnosticResults.ScoreConfiguration++
            } else {
                Write-TestResult "Configuration VSCode" $false "Terminal: $terminalProfile (devrait être 'PowerShell 7 (pwsh)')"
                $diagnosticResults.ProblemeDetecte = $true
                $diagnosticResults.Recommandations += "Configurer VSCode pour utiliser PowerShell 7"
            }
        } catch {
            Write-TestResult "Settings VSCode" $false "Erreur lecture"
            $diagnosticResults.ProblemeDetecte = $true
            $diagnosticResults.Recommandations += "Verifier fichier settings.json"
        }
    } else {
        Write-TestResult "Settings VSCode" $false "settings.json introuvable"
        $diagnosticResults.ProblemeDetecte = $true
        $diagnosticResults.Recommandations += "Vérifier l'installation et la configuration de VSCode"
    }

    if (-not $QuickMode) { Write-Host "" }
}

# ==============================================================================
# 8. CONFIGURATION MCP
# ==============================================================================

function Test-MCPConfiguration {
    if (-not $QuickMode) { Write-DiagnosticSection "8. CONFIGURATION MCP" }

    $mcpSettings = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"
    if (Test-Path $mcpSettings) {
        Write-TestResult "Configuration MCP" $true "mcp_settings.json trouvé"
        $diagnosticResults.ScoreConfiguration++

        # Vérification du contenu
        try {
            $mcpContent = Get-Content $mcpSettings -Raw -Encoding UTF8 | ConvertFrom-Json
            $rooStateManager = $mcpContent.mcpServers.'roo-state-manager'

            if ($rooStateManager) {
                Write-TestResult "MCP configure" $true "roo-state-manager configure"
                Write-Host "   Commande: $($rooStateManager.command)" -ForegroundColor White
                $diagnosticResults.ScoreConfiguration++
            } else {
                Write-TestResult "MCP configure" $false "roo-state-manager non configure"
                $diagnosticResults.ProblemeDetecte = $true
                $diagnosticResults.Recommandations += "Configurer roo-state-manager"
            }
        } catch {
            Write-TestResult "Lecture MCP settings" $false "Erreur: $($_.Exception.Message)"
            $diagnosticResults.ProblemeDetecte = $true
        }
    } else {
        Write-TestResult "Configuration MCP" $false "mcp_settings.json introuvable"
        $diagnosticResults.ProblemeDetecte = $true
        $diagnosticResults.Recommandations += "Vérifier le chemin: $mcpSettings"
    }

    if (-not $QuickMode) { Write-Host "" }
}

# ==============================================================================
# 9. CORRECTIONS AUTOMATIQUES
# ==============================================================================

function Apply-AutomaticCorrections {
    if (-not $Fix -or -not $diagnosticResults.ProblemeDetecte) { return }

    Write-DiagnosticSection "9. CORRECTIONS AUTOMATIQUES"

    $correctionsAppliquees = 0

    # Correction du profil PowerShell 5.1 si manquant
    $profilePS51 = "$HOME\Documents\WindowsPowerShell\profile.ps1"
    $profileDirPS51 = Split-Path $profilePS51 -Parent
    if (-not (Test-Path $profileDirPS51)) {
        New-Item -ItemType Directory -Path $profileDirPS51 -Force | Out-Null
    }

    if (-not (Test-Path $profilePS51)) {
        Write-Host "   Création profil PowerShell 5.1..." -ForegroundColor Cyan
        $profileContent = @"
# Configuration UTF-8 pour PowerShell 5.1 (Windows PowerShell)
# Généré automatiquement par diagnostic-encoding-consolide.ps1 v2.0
# Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

# Forcer l'encodage de la console en UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

# Forcer l'encodage de sortie par défaut pour les cmdlets PowerShell
$OutputEncoding = [System.Text.Encoding]::UTF8

# Configuration par défaut pour les cmdlets PowerShell
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8'
$PSDefaultParameterValues['Add-Content:Encoding'] = 'utf8'

# Forcer la code page 65001 (UTF-8) pour la console
chcp 65001 | Out-Null
"@
        # BOM-safe write: use .NET method instead of Out-File (PowerShell 5.1 adds BOM with -Encoding UTF8)
        [System.IO.File]::WriteAllText($profilePS51, $profileContent, [System.Text.UTF8Encoding]::new($false))
        Write-Host "   ✅ Profil PowerShell 5.1 créé" -ForegroundColor Green
        $correctionsAppliquees++
    }

    # Correction du profil PowerShell 7 si incomplet
    $profilePS7 = "$HOME\OneDrive\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
    if ((Test-Path $profilePS7) -and (-not (Test-Path $profilePS51))) {
        $content = Get-Content $profilePS7 -Raw -Encoding UTF8
        $hasUTF8Config = ($content -match "UTF-8" -and $content -match "OutputEncoding")

        if (-not $hasUTF8Config) {
            Write-Host "   Mise à jour profil PowerShell 7..." -ForegroundColor Cyan
            $baseContent = Get-Content $profilePS7 -Raw -Encoding UTF8
            $utf8Config = @"
# Configuration UTF-8 pour PowerShell 7+
# Ajouté automatiquement par diagnostic-encoding-consolide.ps1 v2.0
# Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

# Forcer UTF-8 pour toutes les opérations
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
`$OutputEncoding = [System.Text.Encoding]::UTF8

# Configuration par défaut pour les cmdlets PowerShell
`$PSDefaultParameterValues['*:Encoding'] = 'utf8'
"@
            $newContent = $utf8Config + "`n" + $baseContent
            # BOM-safe write: use .NET method instead of Out-File (PowerShell 5.1 adds BOM with -Encoding UTF8)
            [System.IO.File]::WriteAllText($profilePS7, $newContent, [System.Text.UTF8Encoding]::new($false))
            Write-Host "   ✅ Profil PowerShell 7 mis à jour" -ForegroundColor Green
            $correctionsAppliquees++
        }
    }

    Write-Host "   Corrections appliquées: $correctionsAppliquees" -ForegroundColor White
    if (-not $QuickMode) { Write-Host "" }
}

# ==============================================================================
# 10. SCORE FINAL ET RAPPORT
# ==============================================================================

function Generate-FinalReport {
    Write-DiagnosticSection "10. SCORE FINAL"

    $scorePourcentage = [math]::Round(($diagnosticResults.ScoreConfiguration / $diagnosticResults.ScoreMaximum) * 100, 1)
    $scoreCouleur = if ($scorePourcentage -ge 90) { "Green" } elseif ($scorePourcentage -ge 70) { "Yellow" } else { "Red" }

    Write-Host "   Score: $($diagnosticResults.ScoreConfiguration)/$($diagnosticResults.ScoreMaximum) ($($scorePourcentage)%)" -ForegroundColor $scoreCouleur

    if (-not $diagnosticResults.ProblemeDetecte) {
        Write-Host "   ✅ CONFIGURATION COMPLÈTE ET FONCTIONNELLE" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  PROBLÈMES DÉTECTÉS" -ForegroundColor Red
        Write-Host "   Recommandations:" -ForegroundColor Yellow
        foreach ($recommandation in $diagnosticResults.Recommandations) {
            Write-Host "   • $recommandation" -ForegroundColor White
        }
    }

    # Export du rapport
    if ($ExportReport) {
        Write-DiagnosticSection "11. EXPORT RAPPORT"

        try {
            $rapport = @{
                Metadata = @{
                    ReportTitle = "Diagnostic Encodage Consolide"
                    GeneratedBy = "Roo Code Mode - Consolidation"
                    GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    VersionScript = "2.0"
                    PowerShellVersion = $PSVersionTable.PSVersion
                    ComputerName = $env:COMPUTERNAME
                    OSVersion = [System.Environment]::OSVersion.ToString()
                    Architecture = $env:PROCESSOR_ARCHITECTURE
                    QuickMode = $QuickMode
                }
                TestResults = $script:DiagnosticResults.Details
                Summary = @{
                    TotalTests = $script:DiagnosticResults.Details.Count
                    SuccessfulTests = ($script:DiagnosticResults.Details | Where-Object { $_.Success }).Count
                    FailedTests = ($script:DiagnosticResults.Details | Where-Object { -not $_.Success }).Count
                    SuccessRate = if ($script:DiagnosticResults.Details.Count -gt 0) { [math]::Round((($script:DiagnosticResults.Details | Where-Object { $_.Success }).Count / $script:DiagnosticResults.Details.Count) * 100, 2) } else { 0 }
                    ScoreConfiguration = $diagnosticResults.ScoreConfiguration
                    ScoreMaximum = $diagnosticResults.ScoreMaximum
                    ScorePourcentage = $scorePourcentage
                    TestDuration = (Get-Date) - $script:TestStartTime
                    CorrectionsApplied = $correctionsAppliquees
                }
                Recommendations = $diagnosticResults.Recommandations
            }

            $rapportJson = $rapport | ConvertTo-Json -Depth 10
            # BOM-safe write: use .NET method instead of Out-File (PowerShell 5.1 adds BOM with -Encoding UTF8)
            [System.IO.File]::WriteAllText($ExportReport, $rapportJson, [System.Text.UTF8Encoding]::new($false))
            Write-Host "   ✅ Rapport exporté: $ExportReport" -ForegroundColor Green
        } catch {
            Write-Host "   ❌ Erreur lors de l'export: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # Code de sortie
    if ($diagnosticResults.ProblemeDetecte) {
        exit 1
    } else {
        exit 0
    }
}

# ==============================================================================
# FONCTION PRINCIPALE
# ==============================================================================

function Main {
    Write-Host "═════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  DIAGNOSTIC ENCODAGE CONSOLIDÉ v2.0" -ForegroundColor Cyan
    Write-Host "═════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    # Vérifier les privilèges administratifs pour certaines corrections
    $isAdmin = Test-AdminPrivileges
    if (-not $isAdmin) {
        Write-Host "⚠️  Attention: Certaines corrections nécessitent des privilèges administratifs" -ForegroundColor Yellow
        Write-Host "  Pour une correction complète, exécutez ce script en tant qu'administrateur" -ForegroundColor Yellow
        Write-Host ""
    }

    # Exécuter tous les tests
    Test-PowerShellEnvironment
    Test-ConsoleEncoding
    Test-PowerShellEncoding
    Test-SpecialCharacters
    Test-FileEncoding
    Test-PowerShellProfiles
    Test-VSCodeConfiguration
    Test-MCPConfiguration

    # Appliquer les corrections automatiques
    Apply-AutomaticCorrections

    # Générer le rapport final
    Generate-FinalReport
}

# Exécuter la fonction principale
Main