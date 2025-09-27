#Requires -Version 5.1
<#
.SYNOPSIS
    Script de diagnostic complet pour les problèmes d'encodage Unicode/UTF-8
.DESCRIPTION
    Effectue un diagnostic approfondi de la configuration d'encodage du système
.NOTES
    Version: 1.0
    Date: 2025-09-26
#>

param(
    [switch]$Verbose,
    [switch]$AddLogs
)

# Configuration des couleurs pour l'affichage
$Script:Colors = @{
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "Cyan"
    Header = "Magenta"
    Default = "White"
}

function Write-DiagnosticLog {
    param(
        [string]$Message,
        [string]$Type = "Info",
        [switch]$NoNewline
    )
    
    $color = $Script:Colors[$Type]
    if (-not $color) { $color = $Script:Colors.Default }
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $prefix = "[$timestamp]"
    
    if ($Script:LogContent) {
        $Script:LogContent += "$prefix $Message`n"
    }
    
    if ($NoNewline) {
        Write-Host "$prefix $Message" -ForegroundColor $color -NoNewline
    } else {
        Write-Host "$prefix $Message" -ForegroundColor $color
    }
}

# Initialisation du rapport
$Script:LogContent = ""
$Script:Issues = @()
$Script:Recommendations = @()

Write-DiagnosticLog "==================================================" -Type "Header"
Write-DiagnosticLog "     DIAGNOSTIC COMPLET ENCODAGE UNICODE/UTF-8    " -Type "Header"
Write-DiagnosticLog "==================================================" -Type "Header"
Write-Host ""

# 1. DIAGNOSTIC POWERSHELL
Write-DiagnosticLog "▶ 1. DIAGNOSTIC POWERSHELL" -Type "Header"
Write-DiagnosticLog "─────────────────────────" -Type "Default"

# Version PowerShell
$psVersion = $PSVersionTable.PSVersion
Write-DiagnosticLog "PowerShell Version: $($psVersion.Major).$($psVersion.Minor).$($psVersion.Build)" -Type "Info"

# Encodages PowerShell
Write-DiagnosticLog "OutputEncoding: $([System.Text.Encoding]::Default.EncodingName) (CP$([System.Text.Encoding]::Default.CodePage))" -Type "Info"
Write-DiagnosticLog "Console.OutputEncoding: $([Console]::OutputEncoding.EncodingName) (CP$([Console]::OutputEncoding.CodePage))" -Type "Info"
Write-DiagnosticLog "Console.InputEncoding: $([Console]::InputEncoding.EncodingName) (CP$([Console]::InputEncoding.CodePage))" -Type "Info"

# Vérifier si UTF-8
$isUTF8 = $false
if ([Console]::OutputEncoding.CodePage -eq 65001) {
    Write-DiagnosticLog "✓ Console configurée en UTF-8" -Type "Success"
    $isUTF8 = $true
} else {
    Write-DiagnosticLog "✗ Console NON configurée en UTF-8 (actuellement CP$([Console]::OutputEncoding.CodePage))" -Type "Error"
    $Script:Issues += "Console non configurée en UTF-8"
}

Write-Host ""

# 2. DIAGNOSTIC SYSTÈME WINDOWS
Write-DiagnosticLog "▶ 2. DIAGNOSTIC SYSTÈME WINDOWS" -Type "Header"
Write-DiagnosticLog "──────────────────────────────" -Type "Default"

# Page de code active
$activeCodePage = (chcp.com)[0] -match '(\d+)' | Out-Null
$currentCP = $Matches[1]
Write-DiagnosticLog "Page de code active: CP$currentCP" -Type "Info"

if ($currentCP -eq "65001") {
    Write-DiagnosticLog "✓ Page de code système en UTF-8" -Type "Success"
} else {
    Write-DiagnosticLog "✗ Page de code système NON en UTF-8" -Type "Error"
    $Script:Issues += "Page de code système non UTF-8"
}

# Paramètres régionaux
$culture = Get-Culture
Write-DiagnosticLog "Culture système: $($culture.Name) ($($culture.DisplayName))" -Type "Info"

# Vérifier les paramètres régionaux Windows
try {
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage"
    $acp = (Get-ItemProperty -Path $regPath -Name "ACP").ACP
    $oemcp = (Get-ItemProperty -Path $regPath -Name "OEMCP").OEMCP
    Write-DiagnosticLog "ACP (ANSI Code Page): $acp" -Type "Info"
    Write-DiagnosticLog "OEMCP (OEM Code Page): $oemcp" -Type "Info"
    
    if ($acp -ne "65001" -or $oemcp -ne "65001") {
        Write-DiagnosticLog "⚠ Pages de code système non UTF-8 par défaut" -Type "Warning"
        $Script:Recommendations += "Considérer l'activation de 'Beta: Use Unicode UTF-8' dans les paramètres Windows"
    }
} catch {
    Write-DiagnosticLog "Impossible de lire les paramètres du registre" -Type "Warning"
}

Write-Host ""

# 3. DIAGNOSTIC VARIABLES D'ENVIRONNEMENT
Write-DiagnosticLog "▶ 3. VARIABLES D'ENVIRONNEMENT" -Type "Header"
Write-DiagnosticLog "──────────────────────────────" -Type "Default"

$envVars = @{
    "PYTHONIOENCODING" = $env:PYTHONIOENCODING
    "PYTHONUTF8" = $env:PYTHONUTF8
    "LANG" = $env:LANG
    "LC_ALL" = $env:LC_ALL
    "LC_CTYPE" = $env:LC_CTYPE
}

$missingVars = @()
foreach ($var in $envVars.GetEnumerator()) {
    if ($var.Value) {
        Write-DiagnosticLog "$($var.Key): $($var.Value)" -Type "Success"
    } else {
        Write-DiagnosticLog "$($var.Key): NON DÉFINI" -Type "Warning"
        $missingVars += $var.Key
    }
}

if ($missingVars.Count -gt 0) {
    $Script:Issues += "Variables d'environnement manquantes: $($missingVars -join ', ')"
}

Write-Host ""

# 4. TEST D'AFFICHAGE UNICODE
Write-DiagnosticLog "▶ 4. TEST D'AFFICHAGE UNICODE" -Type "Header"
Write-DiagnosticLog "─────────────────────────────" -Type "Default"

# Caractères de test
$testChars = @{
    "Lettres accentuées" = "àâäéèêëïîôùûüÿç"
    "Majuscules accentuées" = "ÀÂÄÉÈÊËÏÎÔÙÛÜŸÇ"
    "Symboles mathématiques" = "∑∏∫√∞≈≠±×÷"
    "Flèches" = "←→↑↓↔↕⇐⇒⇑⇓"
    "Emojis simples" = "😀😁😂🤣😃😄😅"
    "Emojis modes Roo" = "💻🏗️❓🪲🪃👨‍💼"
    "Caractères box drawing" = "╔═╗║╚═╝├─┤"
    "Caractères chinois" = "中文字符测试"
    "Caractères japonais" = "日本語のテスト"
    "Caractères arabes" = "اختبار العربية"
}

Write-DiagnosticLog "Tests d'affichage (vérifiez visuellement):" -Type "Info"
foreach ($test in $testChars.GetEnumerator()) {
    Write-Host "  $($test.Key): " -NoNewline
    Write-Host $test.Value -ForegroundColor Yellow
}

Write-Host ""

# 5. DIAGNOSTIC GIT
Write-DiagnosticLog "▶ 5. CONFIGURATION GIT" -Type "Header"
Write-DiagnosticLog "──────────────────────" -Type "Default"

try {
    $gitVersion = git --version 2>$null
    if ($gitVersion) {
        Write-DiagnosticLog "Git installé: $gitVersion" -Type "Success"
        
        # Vérifier les paramètres d'encodage Git
        $gitConfigs = @{
            "core.autocrlf" = git config --global core.autocrlf
            "i18n.commitencoding" = git config --global i18n.commitencoding
            "i18n.logoutputencoding" = git config --global i18n.logoutputencoding
            "core.quotepath" = git config --global core.quotepath
        }
        
        foreach ($config in $gitConfigs.GetEnumerator()) {
            if ($config.Value) {
                Write-DiagnosticLog "$($config.Key): $($config.Value)" -Type "Info"
            } else {
                Write-DiagnosticLog "$($config.Key): NON DÉFINI" -Type "Warning"
            }
        }
    }
} catch {
    Write-DiagnosticLog "Git non installé ou non accessible" -Type "Warning"
}

Write-Host ""

# 6. DIAGNOSTIC VS CODE
Write-DiagnosticLog "▶ 6. CONFIGURATION VS CODE" -Type "Header"
Write-DiagnosticLog "────────────────────────────" -Type "Default"

$vscodePath = Join-Path $PSScriptRoot "../../.vscode/settings.json"
if (Test-Path $vscodePath) {
    try {
        $vscodeSettings = Get-Content $vscodePath -Raw | ConvertFrom-Json
        if ($vscodeSettings."files.encoding") {
            Write-DiagnosticLog "files.encoding: $($vscodeSettings.'files.encoding')" -Type "Info"
        }
        if ($vscodeSettings."files.autoGuessEncoding") {
            Write-DiagnosticLog "files.autoGuessEncoding: $($vscodeSettings.'files.autoGuessEncoding')" -Type "Info"
        }
        Write-DiagnosticLog "✓ Configuration VS Code trouvée" -Type "Success"
    } catch {
        Write-DiagnosticLog "Erreur lors de la lecture des paramètres VS Code" -Type "Warning"
    }
} else {
    Write-DiagnosticLog "Fichier .vscode/settings.json non trouvé" -Type "Warning"
    $Script:Recommendations += "Créer un fichier .vscode/settings.json avec 'files.encoding': 'utf8'"
}

Write-Host ""

# 7. TEST DE FICHIERS
Write-DiagnosticLog "▶ 7. ANALYSE DES FICHIERS DU PROJET" -Type "Header"
Write-DiagnosticLog "────────────────────────────────────" -Type "Default"

# Analyser quelques fichiers clés
$filesToCheck = @(
    "../../docs/GUIDE-ENCODAGE.md",
    "../../roo-config/standard-modes.json",
    "../../.vscode/settings.json"
)

foreach ($file in $filesToCheck) {
    $fullPath = Join-Path $PSScriptRoot $file
    if (Test-Path $fullPath) {
        $bytes = [System.IO.File]::ReadAllBytes($fullPath) | Select-Object -First 3
        $hasBOM = ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        
        $fileName = Split-Path $fullPath -Leaf
        if ($hasBOM) {
            Write-DiagnosticLog "$fileName : UTF-8 avec BOM" -Type "Warning"
        } else {
            Write-DiagnosticLog "$fileName : UTF-8 sans BOM (recommandé)" -Type "Success"
        }
    }
}

Write-Host ""

# 8. RÉSUMÉ ET RECOMMANDATIONS
Write-DiagnosticLog "▶ 8. RÉSUMÉ DU DIAGNOSTIC" -Type "Header"
Write-DiagnosticLog "─────────────────────────" -Type "Default"

if ($Script:Issues.Count -eq 0) {
    Write-DiagnosticLog "✓ AUCUN PROBLÈME DÉTECTÉ - Configuration optimale!" -Type "Success"
} else {
    Write-DiagnosticLog "⚠ PROBLÈMES DÉTECTÉS:" -Type "Error"
    foreach ($issue in $Script:Issues) {
        Write-DiagnosticLog "  • $issue" -Type "Error"
    }
}

if ($Script:Recommendations.Count -gt 0) {
    Write-Host ""
    Write-DiagnosticLog "📌 RECOMMANDATIONS:" -Type "Warning"
    foreach ($rec in $Script:Recommendations) {
        Write-DiagnosticLog "  • $rec" -Type "Info"
    }
}

Write-Host ""
Write-DiagnosticLog "==================================================" -Type "Header"

# Proposer les corrections
if ($Script:Issues.Count -gt 0) {
    Write-Host ""
    Write-DiagnosticLog "Voulez-vous appliquer les corrections automatiquement? (O/N): " -Type "Warning" -NoNewline
    $response = Read-Host
    
    if ($response -match '^[OoYy]') {
        Write-Host ""
        Write-DiagnosticLog "Application des corrections..." -Type "Info"
        
        # Appliquer les corrections
        if (-not $isUTF8) {
            Write-DiagnosticLog "Configuration de PowerShell pour UTF-8..." -Type "Info"
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
            [Console]::InputEncoding = [System.Text.Encoding]::UTF8
            $OutputEncoding = [System.Text.Encoding]::UTF8
            chcp 65001 | Out-Null
            Write-DiagnosticLog "✓ PowerShell configuré en UTF-8" -Type "Success"
        }
        
        if ($missingVars.Count -gt 0) {
            Write-DiagnosticLog "Configuration des variables d'environnement..." -Type "Info"
            [System.Environment]::SetEnvironmentVariable("PYTHONIOENCODING", "utf-8", "User")
            [System.Environment]::SetEnvironmentVariable("PYTHONUTF8", "1", "User")
            Write-DiagnosticLog "✓ Variables d'environnement configurées" -Type "Success"
        }
        
        Write-Host ""
        Write-DiagnosticLog "✓ Corrections appliquées. Redémarrez PowerShell pour appliquer tous les changements." -Type "Success"
    }
}

# Sauvegarder le rapport si demandé
if ($AddLogs) {
    $logPath = Join-Path $PSScriptRoot "diagnostic-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    $Script:LogContent | Out-File -FilePath $logPath -Encoding UTF8
    Write-DiagnosticLog "Rapport sauvegardé: $logPath" -Type "Info"
}