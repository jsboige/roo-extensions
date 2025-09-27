#Requires -Version 5.1
<#
.SYNOPSIS
    Script de configuration DEFINITIVE pour l'encodage UTF-8 et l'integration VSCode/PowerShell
.DESCRIPTION
    Solution consolidee qui integre les bonnes pratiques du depot roo-extensions
    pour un support UTF-8 perenne avec l'integration shell VSCode optimale
.NOTES
    Version: 2.0 Final - Integration VSCode
    Date: 2025-09-26
    Auteur: Roo Extensions - Debug Mode
    Base sur: roo-config/documentation-archive/encoding-fix/
#>

param(
    [switch]$Apply,
    [switch]$ConfigureVSCode,
    [switch]$TestOnly,
    [switch]$ShowConfiguration
)

Write-Host ""
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "   CONFIGURATION UTF-8 + INTEGRATION VSCODE - FINALE   " -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""

# Configuration recommandee (basee sur roo-config/documentation-archive)
$VSCodeConfig = @{
    "files.encoding" = "utf8"
    "files.autoGuessEncoding" = $false
    "terminal.integrated.defaultProfile.windows" = "PowerShell UTF-8"
    "terminal.integrated.profiles.windows" = @{
        "PowerShell UTF-8" = @{
            "source" = "PowerShell"
            "args" = @("-NoExit", "-Command", "chcp 65001")
        }
    }
    # Configuration pour Roo Code integration
    "terminal.integrated.inheritEnv" = $true
    "terminal.integrated.shellIntegration.enabled" = $true
}

# 1. DIAGNOSTIC ACTUEL
Write-Host "1. DIAGNOSTIC DE L'ETAT ACTUEL" -ForegroundColor Yellow
Write-Host "-------------------------------" -ForegroundColor Gray

$currentState = @{
    PowerShellUTF8 = ($([Console]::OutputEncoding.CodePage) -eq 65001)
    SystemCodePage = (cmd /c chcp 2>&1) -match "65001"
    PythonEnvVars = $env:PYTHONIOENCODING -and $env:PYTHONUTF8
    VSCodeSettings = Test-Path ".vscode/settings.json"
}

foreach ($check in $currentState.GetEnumerator()) {
    $status = if ($check.Value) { "[OK]" } else { "[MANQUANT]" }
    $color = if ($check.Value) { "Green" } else { "Red" }
    Write-Host "$status $($check.Key)" -ForegroundColor $color
}

Write-Host ""

# 2. TEST AFFICHAGE UNICODE
Write-Host "2. TEST AFFICHAGE UNICODE" -ForegroundColor Yellow
Write-Host "-------------------------" -ForegroundColor Gray

Write-Host "Caracteres accentes: " -NoNewline
Write-Host "é è à ç ü ñ ô î" -ForegroundColor Green

Write-Host "Emojis Roo Modes: " -NoNewline  
Write-Host "💻🏗️❓🪲🪃👨‍💼" -ForegroundColor Green

Write-Host "Symboles techniques: " -NoNewline
Write-Host "← → ↑ ↓ ± × ÷ ∞ √ ≠ ≈" -ForegroundColor Green

Write-Host "Box drawing: " -NoNewline
Write-Host "┌─┬─┐│ │ │├─┼─┤│ │ │└─┴─┘" -ForegroundColor Green

Write-Host ""

# 3. CONFIGURATION AVANCEE
if ($ShowConfiguration) {
    Write-Host "3. CONFIGURATION VSCODE RECOMMANDEE" -ForegroundColor Yellow
    Write-Host "------------------------------------" -ForegroundColor Gray
    
    $configJson = $VSCodeConfig | ConvertTo-Json -Depth 4
    Write-Host $configJson -ForegroundColor Cyan
    Write-Host ""
}

# 4. APPLICATION DES CORRECTIONS
if ($Apply) {
    Write-Host "4. APPLICATION DES CORRECTIONS" -ForegroundColor Yellow
    Write-Host "-------------------------------" -ForegroundColor Gray
    
    try {
        # A. Configuration PowerShell UTF-8 PERENNE
        Write-Host "Configuration PowerShell UTF-8..." -ForegroundColor Cyan
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        [Console]::InputEncoding = [System.Text.Encoding]::UTF8
        $OutputEncoding = [System.Text.Encoding]::UTF8
        chcp 65001 | Out-Null
        Write-Host "[OK] PowerShell UTF-8 configure" -ForegroundColor Green
        
        # B. Variables d'environnement (niveau utilisateur)
        Write-Host "Configuration variables environnement..." -ForegroundColor Cyan
        [Environment]::SetEnvironmentVariable("PYTHONIOENCODING", "utf-8", "User")
        [Environment]::SetEnvironmentVariable("PYTHONUTF8", "1", "User")
        [Environment]::SetEnvironmentVariable("LANG", "en_US.UTF-8", "User")
        Write-Host "[OK] Variables environnement configurees" -ForegroundColor Green
        
        # C. Configuration Git UTF-8
        try {
            Write-Host "Configuration Git UTF-8..." -ForegroundColor Cyan
            git config --global i18n.commitencoding utf-8 2>$null
            git config --global i18n.logoutputencoding utf-8 2>$null
            git config --global core.quotepath false 2>$null
            Write-Host "[OK] Git UTF-8 configure" -ForegroundColor Green
        } catch {
            Write-Host "[INFO] Git non disponible" -ForegroundColor Yellow
        }
        
        # D. Configuration VSCode (si demande)
        if ($ConfigureVSCode) {
            Write-Host "Configuration VSCode..." -ForegroundColor Cyan
            
            $vscodeDir = ".vscode"
            $settingsFile = Join-Path $vscodeDir "settings.json"
            
            if (-not (Test-Path $vscodeDir)) {
                New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null
            }
            
            # Lire config existante si elle existe
            $existingConfig = @{}
            if (Test-Path $settingsFile) {
                try {
                    $existingConfig = Get-Content $settingsFile -Raw | ConvertFrom-Json -AsHashtable
                } catch {
                    Write-Host "[WARN] Config VSCode existante corrompue, recreation" -ForegroundColor Yellow
                    $existingConfig = @{}
                }
            }
            
            # Fusionner avec nouvelle config
            foreach ($key in $VSCodeConfig.Keys) {
                $existingConfig[$key] = $VSCodeConfig[$key]
            }
            
            # Sauvegarder config VSCode
            $jsonConfig = $existingConfig | ConvertTo-Json -Depth 4
            $jsonConfig | Out-File $settingsFile -Encoding UTF8
            
            Write-Host "[OK] VSCode configure avec profil PowerShell UTF-8" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "=======================================================" -ForegroundColor Green
        Write-Host "         CONFIGURATION APPLIQUEE AVEC SUCCES!" -ForegroundColor Green
        Write-Host "=======================================================" -ForegroundColor Green
        
    } catch {
        Write-Host ""
        Write-Host "[ERREUR] $($_.Exception.Message)" -ForegroundColor Red
    }
    
} elseif ($TestOnly) {
    Write-Host "4. TEST AVANCE UNICODE" -ForegroundColor Yellow
    Write-Host "----------------------" -ForegroundColor Gray
    
    # Test avec codes Unicode directs
    $testChars = @{
        "Francais" = [char]0x00E9 + [char]0x00E8 + [char]0x00E0 + [char]0x00E7  # éèàç
        "Mathematiques" = [char]0x221E + [char]0x00B1 + [char]0x221A + [char]0x2260  # ∞±√≠
        "Fleches" = [char]0x2190 + [char]0x2192 + [char]0x2191 + [char]0x2193  # ←→↑↓
    }
    
    foreach ($test in $testChars.GetEnumerator()) {
        Write-Host "$($test.Key): " -NoNewline
        Write-Host $test.Value -ForegroundColor Magenta
    }
    
    # Test emojis avec codes UTF-32 (si supporte)
    try {
        $emojiTest = [System.Char]::ConvertFromUtf32(0x1F4BB) + [System.Char]::ConvertFromUtf32(0x1F3D7) + [System.Char]::ConvertFromUtf32(0x2753)
        Write-Host "Emojis UTF-32: " -NoNewline
        Write-Host $emojiTest -ForegroundColor Magenta
    } catch {
        Write-Host "Emojis UTF-32: [NON SUPPORTE]" -ForegroundColor Yellow
    }
    
} else {
    Write-Host "4. ACTIONS DISPONIBLES" -ForegroundColor Yellow
    Write-Host "-----------------------" -ForegroundColor Gray
    Write-Host "Pour appliquer les corrections:" -ForegroundColor Cyan
    Write-Host "  .\setup-utf8-integration-final.ps1 -Apply" -ForegroundColor White
    Write-Host ""
    Write-Host "Pour configurer aussi VSCode:" -ForegroundColor Cyan
    Write-Host "  .\setup-utf8-integration-final.ps1 -Apply -ConfigureVSCode" -ForegroundColor White
    Write-Host ""
    Write-Host "Pour tester seulement:" -ForegroundColor Cyan
    Write-Host "  .\setup-utf8-integration-final.ps1 -TestOnly" -ForegroundColor White
}

# 5. RECOMMANDATIONS FINALES
Write-Host ""
Write-Host "=======================================================" -ForegroundColor Magenta
Write-Host "             RECOMMANDATIONS FINALES" -ForegroundColor Magenta
Write-Host "=======================================================" -ForegroundColor Magenta
Write-Host ""

Write-Host "Pour une integration VSCode optimale:" -ForegroundColor Yellow
Write-Host "1. Utiliser le profil 'PowerShell UTF-8' configure" -ForegroundColor White
Write-Host "2. Garder 'Shell Integration' ACTIVE dans Roo Code" -ForegroundColor White
Write-Host "3. Verifier que 'terminal.integrated.inheritEnv' = true" -ForegroundColor White
Write-Host ""

Write-Host "Configuration perenne appliquee:" -ForegroundColor Green
Write-Host "- PowerShell force UTF-8 au demarrage" -ForegroundColor White
Write-Host "- Variables environnement utilisateur" -ForegroundColor White
Write-Host "- Git configure pour UTF-8" -ForegroundColor White
Write-Host "- VSCode avec profil PowerShell UTF-8" -ForegroundColor White

Write-Host ""
Write-Host "IMPORTANT: Redemarrez PowerShell/VSCode pour finaliser." -ForegroundColor Yellow
Write-Host ""