# Script de deploiement automatique - Correction d'encodage UTF-8
# Version: 1.0 - Date: 26/05/2025

param(
    [switch]$Force,
    [switch]$SkipBackup,
    [switch]$Verbose
)

$profilePath = $PROFILE.CurrentUserAllHosts
$profileDir = Split-Path $profilePath -Parent
$backupPath = "$profileDir\Microsoft.PowerShell_profile_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').ps1"

function Write-Log {
    param($Message, $Color = "White")
    if ($Verbose) {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor $Color
    }
}

# Etape 1: Verification des prerequis
Write-Host "Etape 1: Verification des prerequis" -ForegroundColor Yellow
Write-Log "Verification de PowerShell..." "Cyan"

if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "PowerShell 5.0 ou superieur requis" -ForegroundColor Red
    exit 1
}
Write-Host "PowerShell $($PSVersionTable.PSVersion) detecte" -ForegroundColor Green

# Etape 2: Creation du repertoire de profil si necessaire
Write-Host "Etape 2: Preparation du repertoire de profil" -ForegroundColor Yellow
Write-Log "Repertoire de profil: $profileDir" "Cyan"

if (-not (Test-Path $profileDir)) {
    try {
        New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
        Write-Host "Repertoire de profil cree" -ForegroundColor Green
    } catch {
        Write-Host "Erreur lors de la creation du repertoire: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Repertoire de profil existant" -ForegroundColor Green
}

# Etape 3: Sauvegarde du profil existant
Write-Host "Etape 3: Sauvegarde du profil existant" -ForegroundColor Yellow

if (Test-Path $profilePath) {
    try {
        Copy-Item $profilePath $backupPath -Force
        Write-Host "Sauvegarde creee: $(Split-Path $backupPath -Leaf)" -ForegroundColor Green
    } catch {
        Write-Host "Erreur lors de la sauvegarde: $($_.Exception.Message)" -ForegroundColor Red
        if (-not $Force) {
            exit 1
        }
    }
} else {
    if ($SkipBackup) {
        Write-Host "Sauvegarde ignoree (parametre -SkipBackup)" -ForegroundColor Yellow
    } else {
        Write-Host "Aucun profil existant a sauvegarder" -ForegroundColor Cyan
    }
}

# Etape 4: Verification de la configuration existante
Write-Host "Etape 4: Verification de la configuration existante" -ForegroundColor Yellow

$hasUtf8Config = $false
if (Test-Path $profilePath) {
    $existingContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    if ($existingContent -and ($existingContent -match "OutputEncoding.*UTF8" -or $existingContent -match "InputEncoding.*UTF8")) {
        $hasUtf8Config = $true
        Write-Host "Configuration UTF-8 deja presente" -ForegroundColor Yellow

        if (-not $Force) {
            Write-Host "Utilisez -Force pour remplacer la configuration existante" -ForegroundColor Cyan
            Write-Host "Arret du script." -ForegroundColor Yellow
            exit 0
        } else {
            Write-Host "Remplacement force de la configuration..." -ForegroundColor Yellow
        }
    }
}

# Etape 5: Application de la configuration UTF-8
Write-Host "Etape 5: Application de la configuration UTF-8" -ForegroundColor Yellow

$utf8Config = @"
# Configuration automatique UTF-8 pour PowerShell
# Genere le $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')

# Configuration de l'encodage de sortie en UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Configuration de l'encodage d'entree en UTF-8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

# Configuration de la page de codes pour UTF-8
chcp 65001 | Out-Null

# Configuration des preferences PowerShell pour UTF-8
`$PSDefaultParameterValues['*:Encoding'] = 'utf8'

Write-Host "Configuration UTF-8 chargee automatiquement" -ForegroundColor Green
"@

try {
    $existingContent = ""
    if (Test-Path $profilePath) {
        $existingContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
        if (-not $existingContent) { $existingContent = "" }
    }
    
    $newContent = $utf8Config
    if ($existingContent -and -not $hasUtf8Config) {
        $newContent = $utf8Config + "`n`n# === Contenu existant du profil ===`n" + $existingContent
    }
    
    $newContent | Out-File -FilePath $profilePath -Encoding UTF8 -Force
    Write-Host "Configuration UTF-8 appliquee au profil PowerShell" -ForegroundColor Green

} catch {
    Write-Host "Erreur lors de l'application de la configuration: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Etape 6: Configuration VSCode
Write-Host "Etape 6: Configuration VSCode" -ForegroundColor Yellow

$vscodeDir = "$env:APPDATA\Code\User"
$vscodeSettings = "$vscodeDir\settings.json"

try {
    if (-not (Test-Path $vscodeDir)) {
        New-Item -Path $vscodeDir -ItemType Directory -Force | Out-Null
    }
    
    $vscodeConfig = @{
        "files.encoding" = "utf8"
        "files.autoGuessEncoding" = $false
        "terminal.integrated.defaultProfile.windows" = "PowerShell"
        "terminal.integrated.profiles.windows" = @{
            "PowerShell" = @{
                "source" = "PowerShell"
                "args" = @("-NoExit", "-Command", "chcp 65001")
            }
        }
    }
    
    if (Test-Path $vscodeSettings) {
        $existingConfig = Get-Content $vscodeSettings -Raw | ConvertFrom-Json
        foreach ($key in $vscodeConfig.Keys) {
            $existingConfig | Add-Member -MemberType NoteProperty -Name $key -Value $vscodeConfig[$key] -Force
        }
        $vscodeConfig = $existingConfig
    }
    
    $vscodeConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $vscodeSettings -Encoding UTF8 -Force
    Write-Host "Configuration VSCode appliquee" -ForegroundColor Green
} catch {
    Write-Host "Erreur lors de la configuration VSCode: $($_.Exception.Message)" -ForegroundColor Red
}

# Etape 7: Creation des fichiers de test
Write-Host "Etape 7: Creation des fichiers de test" -ForegroundColor Yellow

try {
    $testContent = @"
Test des caracteres francais:
- Accents: cafe, hotel, naif, cree
- Cedille: francais, garcon
- Ligatures: oeuf, coeur
- Symboles: euro (€), degre (°)
"@
    $testContent | Out-File -FilePath "test-caracteres-francais.txt" -Encoding UTF8 -Force
    Write-Host "Fichier de test cree" -ForegroundColor Green
} catch {
    Write-Host "Impossible de creer le fichier de test" -ForegroundColor Yellow
}

# Etape 8: Resume et instructions
Write-Host ""
Write-Host "=== Deploiement termine avec succes ===" -ForegroundColor Green
Write-Host ""
Write-Host "Resume des actions:" -ForegroundColor Cyan
Write-Host "  Profil PowerShell configure: $profilePath" -ForegroundColor White
if (-not $SkipBackup -and (Test-Path $backupPath)) {
    Write-Host "  Sauvegarde creee: $backupPath" -ForegroundColor White
}
Write-Host "  Configuration VSCode appliquee" -ForegroundColor White
Write-Host "  Fichier de test cree" -ForegroundColor White
Write-Host ""

Write-Host "Prochaines etapes:" -ForegroundColor Yellow
Write-Host "  1. Redemarrez PowerShell (fermer et rouvrir)" -ForegroundColor White
Write-Host "  2. Executez: .\validate-deployment.ps1" -ForegroundColor White
Write-Host "  3. Testez l'affichage des caracteres francais" -ForegroundColor White
Write-Host ""

Write-Host "Documentation:" -ForegroundColor Cyan
Write-Host "  - Consultez DEPLOYMENT-GUIDE.md pour plus d'informations" -ForegroundColor White
Write-Host "  - En cas de probleme: .\restore-profile.ps1" -ForegroundColor White
Write-Host ""

Write-Host "Configuration UTF-8 deployee avec succes!" -ForegroundColor Green