# Script de déploiement automatique - Correction d'encodage UTF-8
# Version: 1.0
# Date: 26/05/2025

param(
    [switch]$Force,
    [switch]$SkipBackup,
    [switch]$Verbose
)

Write-Host "=== Script de déploiement automatique - Correction d'encodage UTF-8 ===" -ForegroundColor Green
Write-Host "Version: 1.0 - Date: 26/05/2025" -ForegroundColor Cyan
Write-Host ""

# Configuration
$profilePath = "$env:USERPROFILE\OneDrive\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
$profileDir = Split-Path $profilePath -Parent
$backupPath = "$profilePath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# Configuration UTF-8 à ajouter
$utf8Config = @"
# Configuration d'encodage UTF-8 pour PowerShell
# Ajouté automatiquement le $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss') pour corriger les problèmes d'affichage des caractères français

# Forcer l'encodage de sortie en UTF-8
`$OutputEncoding = [System.Text.Encoding]::UTF8

# Configurer l'encodage de la console
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

# Définir la code page UTF-8 (65001)
try {
    chcp 65001 | Out-Null
} catch {
    Write-Warning "Impossible de définir la code page 65001"
}

"@

# Fonction de logging
function Write-Log {
    param($Message, $Color = "White")
    if ($Verbose) {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor $Color
    }
}

# Étape 1: Vérification des prérequis
Write-Host "Étape 1: Vérification des prérequis" -ForegroundColor Yellow
Write-Log "Vérification de PowerShell..." "Cyan"

if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "[ERREUR] PowerShell 5.0 ou supérieur requis" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] PowerShell $($PSVersionTable.PSVersion) détecté" -ForegroundColor Green

# Étape 2: Création du répertoire de profil si nécessaire
Write-Host "Étape 2: Préparation du répertoire de profil" -ForegroundColor Yellow
Write-Log "Répertoire de profil: $profileDir" "Cyan"

if (-not (Test-Path $profileDir)) {
    Write-Log "Création du répertoire de profil..." "Yellow"
    try {
        New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
        Write-Host "[OK] Répertoire de profil créé" -ForegroundColor Green
    } catch {
        Write-Host "[ERREUR] Erreur lors de la création du répertoire: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[OK] Répertoire de profil existant" -ForegroundColor Green
}

# Étape 3: Sauvegarde du profil existant
Write-Host "Étape 3: Sauvegarde du profil existant" -ForegroundColor Yellow

if ((Test-Path $profilePath) -and (-not $SkipBackup)) {
    Write-Log "Sauvegarde vers: $backupPath" "Cyan"
    try {
        Copy-Item $profilePath $backupPath -Force
        Write-Host "[OK] Sauvegarde créée: $(Split-Path $backupPath -Leaf)" -ForegroundColor Green
    } catch {
        Write-Host "[ERREUR] Erreur lors de la sauvegarde: $($_.Exception.Message)" -ForegroundColor Red
        if (-not $Force) {
            exit 1
        }
    }
} else {
    if ($SkipBackup) {
        Write-Host "[ATTENTION] Sauvegarde ignorée (paramètre -SkipBackup)" -ForegroundColor Yellow
    } else {
        Write-Host "[INFO] Aucun profil existant à sauvegarder" -ForegroundColor Cyan
    }
}

# Étape 4: Vérification de la configuration existante
Write-Host "Étape 4: Vérification de la configuration existante" -ForegroundColor Yellow

$existingContent = ""
$hasUtf8Config = $false

if (Test-Path $profilePath) {
    $existingContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    if ($existingContent -match "Configuration d'encodage UTF-8") {
        $hasUtf8Config = $true
        Write-Host "[ATTENTION] Configuration UTF-8 déjà présente" -ForegroundColor Yellow
        
        if (-not $Force) {
            Write-Host "Utilisez -Force pour remplacer la configuration existante" -ForegroundColor Cyan
            Write-Host "Arrêt du script." -ForegroundColor Yellow
            exit 0
        } else {
            Write-Host "Remplacement forcé de la configuration..." -ForegroundColor Yellow
        }
    }
}

# Étape 5: Application de la configuration UTF-8
Write-Host "Étape 5: Application de la configuration UTF-8" -ForegroundColor Yellow

try {
    if ($hasUtf8Config -and $Force) {
        # Supprimer l'ancienne configuration UTF-8
        $lines = $existingContent -split "`r?`n"
        $newLines = @()
        $skipLines = $false
        
        foreach ($line in $lines) {
            if ($line -match "# Configuration d'encodage UTF-8") {
                $skipLines = $true
                continue
            }
            if ($skipLines -and ($line.Trim() -eq "" -and $newLines[-1].Trim() -eq "")) {
                $skipLines = $false
            }
            if (-not $skipLines) {
                $newLines += $line
            }
        }
        $existingContent = $newLines -join "`r`n"
    }
    
    # Ajouter la nouvelle configuration
    $newContent = if ($existingContent) {
        $existingContent.TrimEnd() + "`r`n`r`n" + $utf8Config
    } else {
        $utf8Config
    }
    
    $newContent | Out-File -FilePath $profilePath -Encoding UTF8 -Force
    Write-Host "[OK] Configuration UTF-8 appliquée au profil PowerShell" -ForegroundColor Green
    
}
catch
{
    Write-Host "[ERREUR] Erreur lors de l'application de la configuration: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Étape 6: Configuration VSCode
Write-Host "Étape 6: Configuration VSCode" -ForegroundColor Yellow

$vscodeDir = ".\.vscode"
$vscodeSettings = "$vscodeDir\settings.json"

# Créer le répertoire .vscode si nécessaire
if (-not (Test-Path $vscodeDir)) {
    New-Item -Path $vscodeDir -ItemType Directory -Force | Out-Null
    Write-Log "Répertoire .vscode créé" "Green"
}

# Configuration VSCode pour UTF-8
$vscodeConfig = @{
    "files.encoding" = "utf8"
    "files.autoGuessEncoding" = $false
    "terminal.integrated.shellArgs.windows" = @("-NoExit", "-Command", "chcp 65001")
    "terminal.integrated.profiles.windows" = @{
        "PowerShell UTF-8" = @{
            "source" = "PowerShell"
            "args" = @("-NoExit", "-Command", "chcp 65001")
        }
    }
    "terminal.integrated.defaultProfile.windows" = "PowerShell UTF-8"
}

try {
    $vscodeConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $vscodeSettings -Encoding UTF8 -Force
    Write-Host "[OK] Configuration VSCode appliquée" -ForegroundColor Green
} catch {
    Write-Host "[ERREUR] Erreur lors de la configuration VSCode: $($_.Exception.Message)" -ForegroundColor Red
}

# Étape 7: Création des fichiers de test
Write-Host "Étape 7: Création des fichiers de test" -ForegroundColor Yellow

$testContent = @"
# Fichier de test UTF-8 - $(Get-Date)
Caractères français : àéèùç ÀÉÈÙÇ ôîâê
Caractères spéciaux : €£¥©®™§¶•…«»""''
Emojis : ---
Phrase : "L'été dernier, j'ai visité un château près de Montréal."
Mots avec accents : café, hôtel, naïf, coïncidence, être, créé, français
"@

try {
    $testContent | Out-File -FilePath "test-caracteres-francais.txt" -Encoding UTF8 -Force
    Write-Host "[OK] Fichier de test créé" -ForegroundColor Green
} catch {
    Write-Host "[ATTENTION] Impossible de créer le fichier de test" -ForegroundColor Yellow
}

# Étape 8: Résumé et instructions
Write-Host ""
Write-Host "=== Déploiement terminé avec succès ===" -ForegroundColor Green
Write-Host ""
Write-Host "[RESUME] Résumé des actions:" -ForegroundColor Cyan
Write-Host "  [OK] Profil PowerShell configuré: $profilePath" -ForegroundColor White
if (-not $SkipBackup -and (Test-Path $backupPath)) {
    Write-Host "  [OK] Sauvegarde créée: $backupPath" -ForegroundColor White
}
Write-Host "  [OK] Configuration VSCode appliquée" -ForegroundColor White
Write-Host "  [OK] Fichier de test créé" -ForegroundColor White
Write-Host ""

Write-Host "[ACTION] Prochaines étapes:" -ForegroundColor Yellow
Write-Host "  1. Redemarrez PowerShell (fermez et rouvrez)" -ForegroundColor White
Write-Host "  2. Exécutez: .\validate-deployment.ps1" -ForegroundColor White
Write-Host "  3. Testez l'affichage des caractères français" -ForegroundColor White
Write-Host ""

Write-Host "Documentation:" -ForegroundColor Cyan
Write-Host "  - Consultez DEPLOYMENT-GUIDE.md pour plus d'informations" -ForegroundColor White
Write-Host "  - En cas de probleme: .\restore-profile.ps1" -ForegroundColor White
Write-Host ""

Write-Host "Configuration UTF-8 deployee avec succes!" -ForegroundColor Green