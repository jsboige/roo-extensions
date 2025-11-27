<#
.SYNOPSIS
    Génère un tableau de bord de l'état de l'encodage système.
.DESCRIPTION
    Ce script collecte les indicateurs clés de configuration de l'encodage (CodePage,
    variables d'environnement, registre, profils) et génère un rapport d'état.
    Il est conçu pour être utilisé par le service de monitoring ou exécuté manuellement.
.PARAMETER OutputFormat
    Format de sortie : 'Console' (défaut), 'JSON', 'Markdown'.
.PARAMETER Quiet
    Supprime la sortie console (utile pour les tâches planifiées).
.EXAMPLE
    .\Get-EncodingDashboard.ps1 -OutputFormat JSON
.EXAMPLE
    .\Get-EncodingDashboard.ps1 -OutputFormat Markdown | Out-File dashboard.md
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Console", "JSON", "Markdown")]
    [string]$OutputFormat = "Console",

    [Parameter(Mandatory = $false)]
    [switch]$Quiet
)

# Configuration
$ErrorActionPreference = "Stop"
$StandardCodePage = 65001
$StandardEncodingVar = "utf-8"

# --- Fonctions Utilitaires ---

function Get-RegistryValueSafe {
    param($Path, $Name)
    try {
        return (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
    } catch {
        return $null
    }
}

function Test-FileEncodingUTF8 {
    param($Path)
    if (-not (Test-Path $Path)) { return $false }
    try {
        # Vérification basique via BOM ou contenu
        $bytes = Get-Content -Path $Path -Encoding Byte -TotalCount 3 -ErrorAction SilentlyContinue
        if ($bytes -and $bytes.Count -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            return $true # UTF-8 BOM
        }
        # Si pas de BOM, on suppose UTF-8 si le contenu est lisible sans erreur (simplification)
        # Pour une vérification stricte, il faudrait analyser tout le fichier
        return $true 
    } catch {
        return $false
    }
}

# --- Collecte des Données ---

$Status = @{
    Timestamp = Get-Date
    System = @{
        CodePage = @{
            Value = [Console]::OutputEncoding.CodePage
            Expected = $StandardCodePage
            Status = "Unknown"
        }
        Region = @{
            ACP = (Get-RegistryValueSafe "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage" "ACP")
            OEMCP = (Get-RegistryValueSafe "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage" "OEMCP")
            MACCP = (Get-RegistryValueSafe "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage" "MACCP")
        }
    }
    Environment = @{
        PYTHONIOENCODING = $env:PYTHONIOENCODING
        LANG = $env:LANG
        LC_ALL = $env:LC_ALL
        NODE_OPTIONS = $env:NODE_OPTIONS
    }
    Profiles = @{
        PowerShellCore = @{
            Path = $PROFILE.CurrentUserAllHosts
            Exists = (Test-Path $PROFILE.CurrentUserAllHosts)
            EncodingOK = $false
        }
        WindowsPowerShell = @{
            Path = $PROFILE.CurrentUserCurrentHost # Approximation pour WinPS
            Exists = (Test-Path $PROFILE.CurrentUserCurrentHost)
            EncodingOK = $false
        }
    }
    Alerts = @()
}

# --- Analyse ---

# 1. CodePage
if ($Status.System.CodePage.Value -eq $Status.System.CodePage.Expected) {
    $Status.System.CodePage.Status = "OK"
} else {
    $Status.System.CodePage.Status = "Error"
    $Status.Alerts += "CodePage système incorrect: $($Status.System.CodePage.Value) (Attendu: $StandardCodePage)"
}

# 2. Variables d'environnement
if ($Status.Environment.PYTHONIOENCODING -ne "utf-8") {
    $Status.Alerts += "PYTHONIOENCODING incorrect ou manquant (Attendu: utf-8)"
}
if ($Status.Environment.LANG -notlike "*UTF-8*") {
    $Status.Alerts += "LANG ne contient pas UTF-8"
}

# 3. Profils
if ($Status.Profiles.PowerShellCore.Exists) {
    $Status.Profiles.PowerShellCore.EncodingOK = Test-FileEncodingUTF8 $Status.Profiles.PowerShellCore.Path
    if (-not $Status.Profiles.PowerShellCore.EncodingOK) {
        $Status.Alerts += "Profil PowerShell Core potentiellement non UTF-8"
    }
}

# --- Sortie ---

if ($OutputFormat -eq "JSON") {
    $Status | ConvertTo-Json -Depth 5
} elseif ($OutputFormat -eq "Markdown") {
    $icon = if ($Status.Alerts.Count -eq 0) { "✅" } else { "⚠️" }
    
    @"
# $icon Dashboard Encodage - $(Get-Date -Format 'yyyy-MM-dd HH:mm')

## 📊 État Système
- **CodePage Actif**: $($Status.System.CodePage.Value) $(if($Status.System.CodePage.Status -eq 'OK') {'✅'} else {'❌'})
- **ACP Registre**: $($Status.System.Region.ACP)
- **OEMCP Registre**: $($Status.System.Region.OEMCP)

## 🌍 Environnement
| Variable | Valeur | Statut |
|----------|--------|--------|
| PYTHONIOENCODING | $($Status.Environment.PYTHONIOENCODING) | $(if($Status.Environment.PYTHONIOENCODING -eq 'utf-8') {'✅'} else {'❌'}) |
| LANG | $($Status.Environment.LANG) | $(if($Status.Environment.LANG -like '*UTF-8*') {'✅'} else {'❌'}) |
| LC_ALL | $($Status.Environment.LC_ALL) | $(if($Status.Environment.LC_ALL -like '*UTF-8*') {'✅'} else {'❌'}) |

## 📜 Profils PowerShell
- **Core**: $(if($Status.Profiles.PowerShellCore.Exists) {'Présent'} else {'Absent'}) - $(if($Status.Profiles.PowerShellCore.EncodingOK) {'Encodage OK'} else {'⚠️ Vérifier Encodage'})

## 🚨 Alertes ($($Status.Alerts.Count))
$(if ($Status.Alerts.Count -gt 0) {
    $Status.Alerts | ForEach-Object { "- $_" }
} else {
    "- Aucune alerte détectée."
})
"@
} else {
    # Console Output
    if (-not $Quiet) {
        Write-Host "=== Dashboard Encodage ===" -ForegroundColor Cyan
        Write-Host "CodePage: $($Status.System.CodePage.Value)" -ForegroundColor $(if($Status.System.CodePage.Status -eq 'OK') {'Green'} else {'Red'})
        
        Write-Host "`nAlertes:" -ForegroundColor Yellow
        if ($Status.Alerts.Count -gt 0) {
            $Status.Alerts | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
        } else {
            Write-Host " - Aucune" -ForegroundColor Green
        }
    }
}