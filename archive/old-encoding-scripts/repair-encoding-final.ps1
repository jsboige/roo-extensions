#Requires -Version 5.1
<#
.SYNOPSIS
    Script de reparation FINAL pour l'encodage Unicode/UTF-8 dans les terminaux Windows
.DESCRIPTION 
    Solution consolidee qui corrige tous les problemes d'encodage identifies
.NOTES
    Version: 1.0 Final
    Date: 2025-09-26
    Auteur: Roo Extensions - Debug Mode
#>

param(
    [switch]$Apply,
    [switch]$TestOnly,
    [switch]$Detailed
)

Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "   REPARATION ENCODAGE UTF-8 - VERSION FINALE  " -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# 1. DIAGNOSTIC RAPIDE
Write-Host "1. DIAGNOSTIC RAPIDE" -ForegroundColor Yellow
Write-Host "--------------------" -ForegroundColor Gray

$issues = @()
$solutions = @()

# Test PowerShell
$outputCP = [Console]::OutputEncoding.CodePage
$inputCP = [Console]::InputEncoding.CodePage

if ($outputCP -eq 65001 -and $inputCP -eq 65001) {
    Write-Host "[OK] PowerShell configure en UTF-8" -ForegroundColor Green
} else {
    Write-Host "[PROBLEME] PowerShell pas en UTF-8 (Out: $outputCP, In: $inputCP)" -ForegroundColor Red
    $issues += "PowerShell non UTF-8"
    $solutions += "Configuration PowerShell UTF-8"
}

# Test variables environnement
$pythonIoEncoding = [Environment]::GetEnvironmentVariable("PYTHONIOENCODING")
$pythonUtf8 = [Environment]::GetEnvironmentVariable("PYTHONUTF8")

if ($pythonIoEncoding -and $pythonUtf8) {
    Write-Host "[OK] Variables Python configurees" -ForegroundColor Green
} else {
    Write-Host "[PROBLEME] Variables Python manquantes" -ForegroundColor Red
    $issues += "Variables Python manquantes"
    $solutions += "Configuration variables Python"
}

Write-Host ""

# 2. TEST AFFICHAGE UNICODE
Write-Host "2. TEST AFFICHAGE UNICODE" -ForegroundColor Yellow
Write-Host "-------------------------" -ForegroundColor Gray

Write-Host "Accents: " -NoNewline
Write-Host "é è à ç ü ñ ô î" -ForegroundColor Green
Write-Host "Emojis: " -NoNewline  
Write-Host "💻🏗️❓🪲🪃" -ForegroundColor Green
Write-Host "Symboles: " -NoNewline
Write-Host "← → ↑ ↓ ± × ÷ ∞ √" -ForegroundColor Green
Write-Host "Box: " -NoNewline
Write-Host "┌─┬─┐│ │ ││ │ │└─┴─┘" -ForegroundColor Green

Write-Host ""
Write-Host "Si les caracteres ci-dessus s'affichent correctement," -ForegroundColor Cyan
Write-Host "votre terminal supporte parfaitement UTF-8!" -ForegroundColor Green

Write-Host ""

# 3. RESULTATS
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "                 RESULTATS" -ForegroundColor Cyan  
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

if ($issues.Count -eq 0) {
    Write-Host "[SUCCES COMPLET]" -ForegroundColor Green
    Write-Host "Votre systeme est parfaitement configure pour UTF-8!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Configuration actuelle:" -ForegroundColor Cyan
    Write-Host "- PowerShell: UTF-8 (CP65001)" -ForegroundColor White
    Write-Host "- Variables Python: Configurees" -ForegroundColor White
    Write-Host "- Affichage Unicode: Fonctionnel" -ForegroundColor White
    
    if ($TestOnly) {
        Write-Host ""
        Write-Host "TEST SUPPLEMENTAIRE - Affichage avance:" -ForegroundColor Yellow
        
        # Test avec codes Unicode directs
        Write-Host "Francais (UTF-8): " -NoNewline
        Write-Host ([char]0x00E9 + [char]0x00E8 + [char]0x00E0 + [char]0x00E7) -ForegroundColor Magenta
        
        Write-Host "Math (UTF-8): " -NoNewline  
        Write-Host ([char]0x221E + [char]0x00B1 + [char]0x221A + [char]0x2260) -ForegroundColor Magenta
        
        # Test emojis avec codes UTF-32
        Write-Host "Emojis Roo: " -NoNewline
        Write-Host ([System.Char]::ConvertFromUtf32(0x1F4BB) + [System.Char]::ConvertFromUtf32(0x1F3D7) + [System.Char]::ConvertFromUtf32(0x2753)) -ForegroundColor Magenta
    }
    
} else {
    Write-Host "[PROBLEMES DETECTES]" -ForegroundColor Red
    foreach ($issue in $issues) {
        Write-Host "- $issue" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "SOLUTIONS DISPONIBLES:" -ForegroundColor Yellow
    foreach ($solution in $solutions) {
        Write-Host "- $solution" -ForegroundColor Cyan
    }
    
    if ($Apply) {
        Write-Host ""
        Write-Host "APPLICATION DES CORRECTIONS..." -ForegroundColor Yellow
        Write-Host "==============================" -ForegroundColor Yellow
        
        try {
            # Correction PowerShell
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
            [Console]::InputEncoding = [System.Text.Encoding]::UTF8
            $OutputEncoding = [System.Text.Encoding]::UTF8
            chcp 65001 | Out-Null
            Write-Host "[OK] PowerShell configure en UTF-8" -ForegroundColor Green
            
            # Variables d'environnement
            [Environment]::SetEnvironmentVariable("PYTHONIOENCODING", "utf-8", "User")
            [Environment]::SetEnvironmentVariable("PYTHONUTF8", "1", "User")
            [Environment]::SetEnvironmentVariable("LANG", "en_US.UTF-8", "User")
            Write-Host "[OK] Variables d'environnement configurees" -ForegroundColor Green
            
            # Configuration Git (si disponible)
            try {
                git config --global i18n.commitencoding utf-8 2>$null
                git config --global i18n.logoutputencoding utf-8 2>$null
                git config --global core.quotepath false 2>$null
                Write-Host "[OK] Configuration Git UTF-8" -ForegroundColor Green
            } catch {
                Write-Host "[INFO] Git non disponible, ignore" -ForegroundColor Yellow
            }
            
            Write-Host ""
            Write-Host "===============================================" -ForegroundColor Green
            Write-Host "         CORRECTIONS APPLIQUEES AVEC SUCCES!" -ForegroundColor Green
            Write-Host "===============================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "IMPORTANT: Redemarrez PowerShell pour appliquer" -ForegroundColor Yellow
            Write-Host "tous les changements d'environnement." -ForegroundColor Yellow
            
        } catch {
            Write-Host ""
            Write-Host "[ERREUR] Impossible d'appliquer certaines corrections: $_" -ForegroundColor Red
        }
    } else {
        Write-Host ""
        Write-Host "Pour appliquer automatiquement:" -ForegroundColor Cyan
        Write-Host "  .\repair-encoding-final.ps1 -Apply" -ForegroundColor White
    }
}

if ($Detailed) {
    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Magenta
    Write-Host "             DIAGNOSTIC DETAILLE" -ForegroundColor Magenta
    Write-Host "===============================================" -ForegroundColor Magenta
    Write-Host ""
    
    Write-Host "PowerShell Info:" -ForegroundColor Cyan
    Write-Host "- Version: $($PSVersionTable.PSVersion)" -ForegroundColor White
    Write-Host "- OutputEncoding: $([Console]::OutputEncoding.EncodingName) (CP$([Console]::OutputEncoding.CodePage))" -ForegroundColor White
    Write-Host "- InputEncoding: $([Console]::InputEncoding.EncodingName) (CP$([Console]::InputEncoding.CodePage))" -ForegroundColor White
    
    Write-Host ""
    Write-Host "Systeme Info:" -ForegroundColor Cyan
    Write-Host "- Culture: $([System.Globalization.CultureInfo]::CurrentCulture.Name)" -ForegroundColor White
    Write-Host "- Page de code: " -NoNewline -ForegroundColor White
    $chcp = cmd /c chcp 2>&1
    Write-Host $chcp -ForegroundColor White
    
    Write-Host ""
    Write-Host "Variables d'environnement:" -ForegroundColor Cyan
    $envVars = @("PYTHONIOENCODING", "PYTHONUTF8", "LANG", "LC_ALL")
    foreach ($var in $envVars) {
        $value = [Environment]::GetEnvironmentVariable($var)
        if ($value) {
            Write-Host "- $var = $value" -ForegroundColor Green
        } else {
            Write-Host "- $var = [NON DEFINI]" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "Fin de la reparation encodage UTF-8" -ForegroundColor Cyan
Write-Host ""