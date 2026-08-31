<#
.SYNOPSIS
    Valide la configuration des terminaux (Windows Terminal et VSCode) pour le support UTF-8.
.DESCRIPTION
    Ce script vérifie :
    - La configuration de Windows Terminal (settings.json)
    - La configuration de VSCode (settings.json)
    - Le rendu effectif des caractères spéciaux dans la console actuelle
.EXAMPLE
    .\Test-TerminalConfiguration.ps1
.NOTES
    Auteur: Roo Architect
    Date: 2025-11-26
    ID Tâche: SDDD-T001-J5-5
#>

[CmdletBinding()]
param()

# Configuration
$LogFile = "logs\Test-TerminalConfiguration-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Fonctions de logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(switch ($Level) { "ERROR" { "Red" } "WARN" { "Yellow" } "SUCCESS" { "Green" } default { "Cyan" } })
    if (!(Test-Path "logs")) { New-Item -ItemType Directory -Path "logs" -Force | Out-Null }
    Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
}

function Test-WindowsTerminalConfig {
    Write-Log "Test de la configuration Windows Terminal..." "INFO"
    
    $packagesPath = "$env:LOCALAPPDATA\Packages"
    $wtPackage = Get-ChildItem -Path $packagesPath -Filter "Microsoft.WindowsTerminal*" | Select-Object -First 1
    
    if (-not $wtPackage) {
        Write-Log "Windows Terminal non installé." "WARN"
        return $false
    }
    
    $settingsPath = Join-Path $wtPackage.FullName "LocalState\settings.json"
    if (-not (Test-Path $settingsPath)) {
        Write-Log "Fichier settings.json de Windows Terminal introuvable." "WARN"
        return $false
    }
    
    try {
        $jsonContent = Get-Content -Path $settingsPath -Raw -Encoding UTF8
        $settings = $jsonContent | ConvertFrom-Json
        
        $issues = @()
        
        # Vérification police par défaut
        if ($settings.profiles.defaults.font.face -ne "Cascadia Code" -and $settings.profiles.defaults.font.face -ne "Cascadia Mono") {
            $issues += "Police par défaut non configurée sur Cascadia Code/Mono"
        }
        
        # Vérification AtlasEngine
        if ($settings.profiles.defaults.useAtlasEngine -ne $true) {
            $issues += "AtlasEngine non activé par défaut"
        }
        
        if ($issues.Count -eq 0) {
            Write-Log "Configuration Windows Terminal : OK" "SUCCESS"
            return $true
        } else {
            Write-Log "Problèmes détectés dans Windows Terminal : $($issues -join ', ')" "WARN"
            return $false
        }
        
    } catch {
        Write-Log "Erreur lors de la lecture de la configuration Windows Terminal: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Test-VSCodeConfig {
    Write-Log "Test de la configuration VSCode..." "INFO"
    
    $settingsPath = "$env:APPDATA\Code\User\settings.json"
    if (-not (Test-Path $settingsPath)) {
        Write-Log "Fichier settings.json de VSCode introuvable." "WARN"
        return $false
    }
    
    try {
        $jsonContent = Get-Content -Path $settingsPath -Raw -Encoding UTF8
        $jsonClean = $jsonContent -replace "(?m)^\s*//.*$","" # Nettoyage commentaires
        $settings = $jsonClean | ConvertFrom-Json
        
        $issues = @()
        
        # Vérification profil par défaut
        if ($settings.'terminal.integrated.defaultProfile.windows' -ne "PowerShell") {
            $issues += "Profil par défaut non défini sur PowerShell"
        }
        
        # Vérification arguments UTF-8
        $psProfile = $settings.'terminal.integrated.profiles.windows'.PowerShell
        if ($psProfile -eq $null) {
            $issues += "Profil PowerShell non configuré"
        } elseif ($psProfile.args -notcontains "chcp 65001") {
            $issues += "Arguments UTF-8 (chcp 65001) manquants dans le profil PowerShell"
        }
        
        # Vérification police
        if ($settings.'terminal.integrated.fontFamily' -notlike "*Cascadia Code*") {
            $issues += "Police non configurée sur Cascadia Code"
        }
        
        if ($issues.Count -eq 0) {
            Write-Log "Configuration VSCode : OK" "SUCCESS"
            return $true
        } else {
            Write-Log "Problèmes détectés dans VSCode : $($issues -join ', ')" "WARN"
            return $false
        }
        
    } catch {
        Write-Log "Erreur lors de la lecture de la configuration VSCode: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Test-ConsoleRendering {
    Write-Log "Test du rendu console..." "INFO"
    
    # Test d'affichage de caractères spéciaux
    $testChars = "é è à ù ç œ æ â ê î ô û 🚀 ✅ ❌"
    Write-Host "Test caractères : $testChars"
    
    # Vérification de l'encodage de sortie
    $consoleEncoding = [Console]::OutputEncoding.CodePage
    Write-Log "CodePage Console actuel : $consoleEncoding" "INFO"
    
    if ($consoleEncoding -eq 65001) {
        Write-Log "Encodage console : UTF-8 (OK)" "SUCCESS"
        return $true
    } else {
        Write-Log "Encodage console : Non UTF-8 (ATTENTION)" "WARN"
        return $false
    }
}

# Main
Write-Log "Début des tests de configuration terminal..." "INFO"

$wtResult = Test-WindowsTerminalConfig
$vscodeResult = Test-VSCodeConfig
$renderResult = Test-ConsoleRendering

$summary = @{
    WindowsTerminal = $wtResult
    VSCode = $vscodeResult
    ConsoleRendering = $renderResult
}

Write-Log "Résumé des tests :" "INFO"
Write-Log "  - Windows Terminal : $(if ($wtResult) { 'PASS' } else { 'FAIL/WARN' })" "INFO"
Write-Log "  - VSCode : $(if ($vscodeResult) { 'PASS' } else { 'FAIL/WARN' })" "INFO"
Write-Log "  - Rendu Console : $(if ($renderResult) { 'PASS' } else { 'FAIL/WARN' })" "INFO"

if ($wtResult -and $vscodeResult -and $renderResult) {
    exit 0
} else {
    exit 1
}