#Requires -Version 5.1
<#
.SYNOPSIS
    Script de diagnostic simplifié pour les problèmes d'encodage Unicode/UTF-8
.DESCRIPTION
    Version robuste qui évite les caractères problématiques dans le code source
#>

param(
    [switch]$Fix
)

# Fonction d'affichage
function Write-Diagnostic {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )
    
    $colors = @{
        "Success" = "Green"
        "Warning" = "Yellow" 
        "Error" = "Red"
        "Info" = "Cyan"
        "Header" = "Magenta"
    }
    
    $color = if ($colors.ContainsKey($Type)) { $colors[$Type] } else { "White" }
    Write-Host $Message -ForegroundColor $color
}

Write-Diagnostic "==========================================" -Type "Header"
Write-Diagnostic "   DIAGNOSTIC ENCODAGE UTF-8 SIMPLIFIE   " -Type "Header"
Write-Diagnostic "==========================================" -Type "Header"
Write-Host ""

$issues = @()
$fixes = @()

# 1. DIAGNOSTIC POWERSHELL
Write-Diagnostic "1. DIAGNOSTIC POWERSHELL" -Type "Header"
Write-Diagnostic "------------------------" -Type "Info"

$psVersion = $PSVersionTable.PSVersion
Write-Diagnostic "PowerShell Version: $($psVersion.Major).$($psVersion.Minor)" -Type "Info"

# Test OutputEncoding
try {
    $outEncoding = [Console]::OutputEncoding
    Write-Diagnostic "Console OutputEncoding: $($outEncoding.EncodingName) (CodePage: $($outEncoding.CodePage))" -Type "Info"
    
    if ($outEncoding.CodePage -eq 65001) {
        Write-Diagnostic "[OK] Console en UTF-8" -Type "Success"
    } else {
        Write-Diagnostic "[ERREUR] Console PAS en UTF-8 (CP$($outEncoding.CodePage))" -Type "Error"
        $issues += "Console non UTF-8"
        $fixes += "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8"
    }
} catch {
    Write-Diagnostic "[ERREUR] Impossible de lire OutputEncoding: $_" -Type "Error"
}

# Test InputEncoding
try {
    $inEncoding = [Console]::InputEncoding
    Write-Diagnostic "Console InputEncoding: $($inEncoding.EncodingName) (CodePage: $($inEncoding.CodePage))" -Type "Info"
    
    if ($inEncoding.CodePage -eq 65001) {
        Write-Diagnostic "[OK] Input en UTF-8" -Type "Success"
    } else {
        Write-Diagnostic "[ERREUR] Input PAS en UTF-8 (CP$($inEncoding.CodePage))" -Type "Error"
        $issues += "Input non UTF-8"
        $fixes += "[Console]::InputEncoding = [System.Text.Encoding]::UTF8"
    }
} catch {
    Write-Diagnostic "[ERREUR] Impossible de lire InputEncoding: $_" -Type "Error"
}

Write-Host ""

# 2. DIAGNOSTIC SYSTEME
Write-Diagnostic "2. DIAGNOSTIC SYSTEME WINDOWS" -Type "Header"
Write-Diagnostic "-----------------------------" -Type "Info"

# Page de code active
try {
    $chcpOutput = cmd /c chcp 2>&1
    if ($chcpOutput -match ":\s*(\d+)") {
        $currentCP = $matches[1]
        Write-Diagnostic "Page de code active: CP$currentCP" -Type "Info"
        
        if ($currentCP -eq "65001") {
            Write-Diagnostic "[OK] Page de code UTF-8" -Type "Success"
        } else {
            Write-Diagnostic "[ERREUR] Page de code non UTF-8" -Type "Error"
            $issues += "Page de code non UTF-8"
            $fixes += "chcp 65001"
        }
    }
} catch {
    Write-Diagnostic "[AVERTISSEMENT] Impossible de lire la page de code" -Type "Warning"
}

# Culture système
$culture = Get-Culture
Write-Diagnostic "Culture: $($culture.Name) - $($culture.DisplayName)" -Type "Info"

Write-Host ""

# 3. VARIABLES D'ENVIRONNEMENT
Write-Diagnostic "3. VARIABLES D'ENVIRONNEMENT" -Type "Header"
Write-Diagnostic "----------------------------" -Type "Info"

$envVars = @(
    "PYTHONIOENCODING",
    "PYTHONUTF8",
    "LANG",
    "LC_ALL"
)

foreach ($varName in $envVars) {
    $value = [Environment]::GetEnvironmentVariable($varName)
    if ($value) {
        Write-Diagnostic "$varName = $value" -Type "Success"
    } else {
        Write-Diagnostic "$varName = [NON DEFINI]" -Type "Warning"
        if ($varName -eq "PYTHONIOENCODING") {
            $issues += "PYTHONIOENCODING manquant"
            $fixes += '[Environment]::SetEnvironmentVariable("PYTHONIOENCODING", "utf-8", "User")'
        }
        if ($varName -eq "PYTHONUTF8") {
            $issues += "PYTHONUTF8 manquant"
            $fixes += '[Environment]::SetEnvironmentVariable("PYTHONUTF8", "1", "User")'
        }
    }
}

Write-Host ""

# 4. TEST AFFICHAGE
Write-Diagnostic "4. TEST AFFICHAGE CARACTERES" -Type "Header"
Write-Diagnostic "----------------------------" -Type "Info"
Write-Host ""

Write-Host "Lettres accentuees: " -NoNewline
Write-Host "a e e e i o u c" -ForegroundColor Yellow

Write-Host "Symboles maths: " -NoNewline
Write-Host "± × ÷ ≠ ∞ √" -ForegroundColor Yellow

Write-Host "Fleches: " -NoNewline
Write-Host "← → ↑ ↓" -ForegroundColor Yellow

Write-Host "Box drawing: " -NoNewline
Write-Host "┌─┐│└─┘" -ForegroundColor Yellow

Write-Host ""
Write-Diagnostic "Verifiez que les caracteres ci-dessus s'affichent correctement" -Type "Info"

Write-Host ""

# 5. CONFIGURATION GIT
Write-Diagnostic "5. CONFIGURATION GIT" -Type "Header"  
Write-Diagnostic "--------------------" -Type "Info"

try {
    $gitVersion = git --version 2>$null
    if ($gitVersion) {
        Write-Diagnostic "Git installe: $gitVersion" -Type "Success"
        
        # Verifier les configs importantes
        $configs = @(
            "i18n.commitencoding",
            "i18n.logoutputencoding",
            "core.quotepath"
        )
        
        foreach ($config in $configs) {
            $value = git config --global $config 2>$null
            if ($value) {
                Write-Diagnostic "  $config = $value" -Type "Info"
            } else {
                Write-Diagnostic "  $config = [NON DEFINI]" -Type "Warning"
                if ($config -eq "i18n.commitencoding") {
                    $fixes += "git config --global i18n.commitencoding utf-8"
                }
            }
        }
    } else {
        Write-Diagnostic "Git non installe" -Type "Warning"
    }
} catch {
    Write-Diagnostic "Erreur lors de la verification Git" -Type "Warning"
}

Write-Host ""

# 6. RESUME
Write-Diagnostic "==========================================" -Type "Header"
Write-Diagnostic "                 RESUME                   " -Type "Header"
Write-Diagnostic "==========================================" -Type "Header"
Write-Host ""

if ($issues.Count -eq 0) {
    Write-Diagnostic "[SUCCES] Aucun probleme detecte!" -Type "Success"
} else {
    Write-Diagnostic "[PROBLEMES DETECTES]:" -Type "Error"
    foreach ($issue in $issues) {
        Write-Diagnostic "  - $issue" -Type "Error"
    }
    
    Write-Host ""
    Write-Diagnostic "[CORRECTIONS DISPONIBLES]:" -Type "Warning"
    foreach ($fix in $fixes) {
        Write-Diagnostic "  $fix" -Type "Info"
    }
}

# Proposition de correction automatique
if ($issues.Count -gt 0) {
    Write-Host ""
    
    if ($Fix) {
        Write-Diagnostic "Application des corrections..." -Type "Info"
        
        # Appliquer les corrections PowerShell
        try {
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
            [Console]::InputEncoding = [System.Text.Encoding]::UTF8
            chcp 65001 | Out-Null
            Write-Diagnostic "[OK] Encodage PowerShell configure" -Type "Success"
        } catch {
            Write-Diagnostic "[ERREUR] Impossible de configurer PowerShell: $_" -Type "Error"
        }
        
        # Variables d'environnement
        try {
            [Environment]::SetEnvironmentVariable("PYTHONIOENCODING", "utf-8", "User")
            [Environment]::SetEnvironmentVariable("PYTHONUTF8", "1", "User")
            Write-Diagnostic "[OK] Variables environnement configurees" -Type "Success"
        } catch {
            Write-Diagnostic "[ERREUR] Impossible de configurer les variables: $_" -Type "Error"
        }
        
        Write-Host ""
        Write-Diagnostic "Corrections appliquees. Redemarrez PowerShell pour appliquer tous les changements." -Type "Success"
    } else {
        Write-Diagnostic "Pour appliquer les corrections automatiquement, executez:" -Type "Info"
        Write-Diagnostic "  .\diagnose-encoding-simple.ps1 -Fix" -Type "Warning"
    }
}

Write-Host ""
Write-Diagnostic "Fin du diagnostic" -Type "Info"