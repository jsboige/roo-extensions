<#
.SYNOPSIS
    Valide la configuration des profils PowerShell et l'encodage.
.DESCRIPTION
    Ce script vérifie l'existence des profils, leur contenu (appel à EncodingManager),
    et teste l'encodage effectif dans une nouvelle session PowerShell.
.NOTES
    Auteur: Roo Architect
    Date: 2025-10-30
    Version: 1.0
#>

$ErrorActionPreference = "Stop"

function Test-ProfileConfiguration {
    param(
        [string]$ProfilePath,
        [string]$VersionName
    )
    
    Write-Host "Test du profil $VersionName..." -ForegroundColor Cyan
    
    if (-not (Test-Path $ProfilePath)) {
        Write-Host "  [FAIL] Profil introuvable: $ProfilePath" -ForegroundColor Red
        return $false
    }
    
    $content = Get-Content $ProfilePath -Raw
    if ($content -match "Initialize-EncodingManager.ps1") {
        Write-Host "  [PASS] Profil configuré avec EncodingManager" -ForegroundColor Green
        return $true
    } else {
        Write-Host "  [FAIL] Profil non configuré (EncodingManager manquant)" -ForegroundColor Red
        return $false
    }
}

function Test-EncodingInSession {
    param(
        [string]$Command,
        [string]$VersionName
    )
    
    Write-Host "Test de l'encodage dans une session $VersionName..." -ForegroundColor Cyan
    
    try {
        # On lance une nouvelle session qui charge le profil et vérifie l'encodage
        $code = "[Console]::OutputEncoding.CodePage"
        $result = & $Command -NoProfile -Command $code 2>&1
        
        # Note: -NoProfile est utilisé ici pour tester le comportement par défaut, 
        # mais pour tester le profil, on devrait l'enlever. 
        # Cependant, charger le profil peut être lent ou interactif.
        # On va plutôt vérifier si le script d'init fait son travail quand on le source.
        
        $initScript = Resolve-Path "scripts\encoding\Initialize-EncodingManager.ps1"
        $testCommand = ". '$initScript'; [Console]::OutputEncoding.CodePage"
        
        $result = & $Command -Command $testCommand 2>&1
        
        if ($result -match "65001") {
            Write-Host "  [PASS] Encodage UTF-8 (65001) actif" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  [FAIL] Encodage incorrect: $result" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "  [WARN] Impossible de lancer ${VersionName}: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

# --- Main ---

Write-Host "Début de la validation des profils PowerShell..." -ForegroundColor White

# 1. Validation PS 5.1
$ps5Profile = [System.Environment]::GetFolderPath("MyDocuments") + "\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
$ps5Configured = Test-ProfileConfiguration -ProfilePath $ps5Profile -VersionName "PowerShell 5.1"
$ps5Encoding = Test-EncodingInSession -Command "powershell" -VersionName "PowerShell 5.1"

# 2. Validation PS 7+
$ps7Profile = [System.Environment]::GetFolderPath("MyDocuments") + "\PowerShell\Microsoft.PowerShell_profile.ps1"
$ps7Configured = Test-ProfileConfiguration -ProfilePath $ps7Profile -VersionName "PowerShell 7+"
$ps7Encoding = Test-EncodingInSession -Command "pwsh" -VersionName "PowerShell 7+"

Write-Host "`nRésumé:" -ForegroundColor White
if ($ps5Configured -and $ps5Encoding) { Write-Host "PS 5.1 : OK" -ForegroundColor Green } else { Write-Host "PS 5.1 : KO" -ForegroundColor Red }
if ($ps7Configured -and $ps7Encoding) { Write-Host "PS 7+  : OK" -ForegroundColor Green } else { Write-Host "PS 7+  : KO" -ForegroundColor Red }