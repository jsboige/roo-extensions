<#
.SYNOPSIS
    Vérifie l'intégrité de la configuration d'encodage.
.DESCRIPTION
    Ce script effectue une validation approfondie de la configuration système et utilisateur
    liée à l'encodage UTF-8. Il retourne un code de sortie non nul en cas d'erreur critique.
.EXAMPLE
    .\Maintenance-VerifyConfig.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$CriticalError = $false

Write-Host "=== Vérification de l'Intégrité de la Configuration Encodage ===" -ForegroundColor Cyan

# --- 1. Vérification du Registre ---
Write-Host "`n[Registre]" -ForegroundColor Yellow
$RegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage"
try {
    $ACP = (Get-ItemProperty -Path $RegPath -Name "ACP" -ErrorAction Stop).ACP
    if ($ACP -eq "65001") {
        Write-Host "  [OK] ACP est configuré sur 65001 (UTF-8)" -ForegroundColor Green
    } else {
        Write-Host "  [ERREUR] ACP est configuré sur '$ACP' (Attendu: 65001)" -ForegroundColor Red
        $CriticalError = $true
    }
} catch {
    Write-Host "  [ERREUR] Impossible de lire la clé de registre ACP: $_" -ForegroundColor Red
    $CriticalError = $true
}

# --- 2. Vérification des Profils PowerShell ---
Write-Host "`n[Profils PowerShell]" -ForegroundColor Yellow
$Profiles = @(
    @{ Name = "PowerShell Core"; Path = $PROFILE.CurrentUserAllHosts },
    @{ Name = "Windows PowerShell"; Path = $PROFILE.CurrentUserCurrentHost } # Approximation
)

foreach ($Prof in $Profiles) {
    if (Test-Path $Prof.Path) {
        # Vérification basique de l'encodage (BOM ou contenu)
        try {
            $bytes = Get-Content -Path $Prof.Path -Encoding Byte -TotalCount 3 -ErrorAction Stop
            if ($bytes -and $bytes.Count -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
                Write-Host "  [OK] $($Prof.Name): Fichier présent et UTF-8 BOM détecté." -ForegroundColor Green
            } else {
                Write-Host "  [AVERTISSEMENT] $($Prof.Name): Fichier présent mais pas de BOM UTF-8 détecté." -ForegroundColor Yellow
                # Pas une erreur critique, mais à surveiller
            }
        } catch {
            Write-Host "  [ERREUR] $($Prof.Name): Impossible de lire le fichier." -ForegroundColor Red
        }
    } else {
        Write-Host "  [INFO] $($Prof.Name): Profil non existant." -ForegroundColor Gray
    }
}

# --- 3. Vérification des Variables d'Environnement ---
Write-Host "`n[Variables d'Environnement]" -ForegroundColor Yellow
$EnvVars = @{
    "PYTHONIOENCODING" = "utf-8"
    "LANG" = "UTF-8" # Vérification partielle
}

foreach ($Key in $EnvVars.Keys) {
    $Val = (Get-Item "Env:\$Key" -ErrorAction SilentlyContinue).Value
    $Expected = $EnvVars[$Key]

    if ($null -ne $Val) {
        if ($Val -like "*$Expected*") {
            Write-Host "  [OK] ${Key}: $Val" -ForegroundColor Green
        } else {
            Write-Host "  [ERREUR] ${Key}: '$Val' ne correspond pas à l'attendu '*$Expected*'" -ForegroundColor Red
            $CriticalError = $true
        }
    } else {
        Write-Host "  [ERREUR] ${Key}: Variable manquante." -ForegroundColor Red
        $CriticalError = $true
    }
}

# --- Conclusion ---
Write-Host "`n=== Résultat ===" -ForegroundColor Cyan
if ($CriticalError) {
    Write-Host "Des erreurs critiques ont été détectées." -ForegroundColor Red
    exit 1
} else {
    Write-Host "Configuration intègre." -ForegroundColor Green
    exit 0
}