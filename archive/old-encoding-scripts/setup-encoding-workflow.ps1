<#
.SYNOPSIS
    Configure un environnement de développement avec les bonnes pratiques d'encodage pour le projet roo-extensions.

.DESCRIPTION
    Ce script automatise la configuration d'un environnement de développement avec les bonnes pratiques d'encodage.
    Il configure les paramètres d'encodage de PowerShell, Git, les éditeurs courants (VSCode),
    et met en place des hooks Git pre-commit pour vérifier l'encodage des fichiers.

.PARAMETER Force
    Force la reconfiguration même si certains paramètres sont déjà configurés.

.PARAMETER SkipGitHooks
    Ignore la configuration des hooks Git.

.PARAMETER SkipVSCode
    Ignore la configuration de Visual Studio Code.

.EXAMPLE
    .\setup-encoding-workflow.ps1

.EXAMPLE
    .\setup-encoding-workflow.ps1 -Force

.NOTES
    Auteur: Roo Extensions Team
    Date: 27/05/2025
#>

param (
    [switch]$Force,
    [switch]$SkipGitHooks,
    [switch]$SkipVSCode,
    [switch]$BackupProfile,
    [switch]$RestoreProfile,
    [switch]$SetupPowerShellProfile
)

# =================================================================================================
# =================================================================================================

# Fonction pour afficher les messages avec couleur
function Write-ColorOutput {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$ForegroundColor = "White"
    )
    
    if ([string]::IsNullOrEmpty($Message)) {
        Write-Host ""
    } else {
        Write-Host $Message -ForegroundColor $ForegroundColor
    }
}

# Fonction pour vérifier si un chemin existe
function Test-PathExists {
    param (
        [string]$Path
    )
    
    if (-not (Test-Path -Path $Path)) {
        Write-ColorOutput "Le chemin '$Path' n'existe pas." -ForegroundColor "Yellow"
        return $false
    }
    
    return $true
}

function Invoke-ProfileBackup {
    param([string]$ProfilePath)
    $BackupSuffix = ".backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $BackupPath = $ProfilePath + $BackupSuffix
    Write-ColorOutput "`n--- Sauvegarde du profil PowerShell ---" "Magenta"
    if (-not (Test-Path $ProfilePath)) {
        Write-ColorOutput "Le profil PowerShell n'existe pas. Aucune sauvegarde n'est nécessaire." "Yellow"
        return
    }
    try {
        Copy-Item -Path $ProfilePath -Destination $BackupPath -Force
        Write-ColorOutput "Sauvegarde du profil créée avec succès: $BackupPath" "Green"
    } catch {
        Write-ColorOutput "ERREUR lors de la sauvegarde du profil: $($_.Exception.Message)" "Red"
    }
}

function Invoke-ProfileRestore {
    param([string]$ProfilePath)
    Write-ColorOutput "`n--- Restauration du profil PowerShell ---" "Magenta"
    $ProfileDir = Split-Path $ProfilePath -Parent
    $ProfileName = Split-Path $ProfilePath -Leaf
    $BackupFiles = Get-ChildItem -Path $ProfileDir -Filter "$ProfileName.backup-*" | Sort-Object LastWriteTime -Descending
    
    if ($BackupFiles.Count -eq 0) {
        Write-ColorOutput "Aucune sauvegarde de profil trouvée." "Red"
        return
    }
    
    $latestBackup = $BackupFiles[0].FullName
    Write-ColorOutput "Sauvegarde la plus récente trouvée: $latestBackup" "Yellow"
    $confirmation = Read-Host "Voulez-vous restaurer cette sauvegarde? (O/N)"
    if ($confirmation -notmatch '^[OoYy]') {
        Write-ColorOutput "Restauration annulée." "Yellow"
        return
    }

    try {
        Copy-Item -Path $latestBackup -Destination $ProfilePath -Force
        Write-ColorOutput "Profil restauré avec succès. Veuillez redémarrer votre session PowerShell." "Green"
    } catch {
        Write-ColorOutput "ERREUR lors de la restauration du profil: $($_.Exception.Message)" "Red"
    }
}

# =================================================================================================
# =================================================================================================

# Bannière
Write-ColorOutput "=========================================================" -ForegroundColor "Cyan"
Write-ColorOutput "  Configuration de l'environnement d'encodage pour Roo Extensions" -ForegroundColor "Cyan"
Write-ColorOutput "=========================================================" -ForegroundColor "Cyan"
Write-Host ""

# Déterminer le chemin du profil PowerShell
$profilePath = $PROFILE

# --- Actions de Sauvegarde/Restauration ---
if ($BackupProfile) {
    Invoke-ProfileBackup -ProfilePath $profilePath
    exit 0
}

if ($RestoreProfile) {
    Invoke-ProfileRestore -ProfilePath $profilePath
    exit 0
}

#region Configuration de PowerShell
Write-ColorOutput "1. Configuration des paramètres d'encodage de PowerShell..." -ForegroundColor "Green"

# Vérifier si le profil PowerShell existe
$profileExists = Test-Path -Path $profilePath
$profileContent = ""

if ($profileExists) {
    $profileContent = Get-Content -Path $profilePath -Raw
}

# Paramètres d'encodage à ajouter au profil
$encodingSettings = @"

# Configuration d'encodage pour roo-extensions
# Ajouté par setup-encoding-workflow.ps1
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
`$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8NoBOM'
`$PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8NoBOM'
# Fin de la configuration d'encodage
"@

# Vérifier si les paramètres sont déjà configurés
if ($profileExists -and $profileContent -match "\[Console\]::OutputEncoding = \[System\.Text\.UTF8Encoding\]::new\(\)") {
    if ($Force) {
        Write-ColorOutput "   Les paramètres d'encodage PowerShell sont déjà configurés. Reconfiguration forcée..." -ForegroundColor "Yellow"
    } else {
        Write-ColorOutput "   Les paramètres d'encodage PowerShell sont déjà configurés." -ForegroundColor "Yellow"
        Write-ColorOutput "   Utilisez -Force pour reconfigurer." -ForegroundColor "Yellow"
        Write-ColorOutput "   Configuration PowerShell ignorée." -ForegroundColor "Yellow"
        $skipPowerShell = $true
    }
}

if (-not $skipPowerShell) {
    try {
        # Créer le répertoire du profil s'il n'existe pas
        $profileDir = Split-Path -Path $profilePath -Parent
        if (-not (Test-Path -Path $profileDir)) {
            New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
        }

        # Ajouter les paramètres au profil
        if ($profileExists) {
            # Supprimer les anciennes configurations d'encodage si elles existent
            $profileContent = $profileContent -replace "# Configuration d'encodage pour roo-extensions[\s\S]*?# Fin de la configuration d'encodage", ""
            $profileContent += $encodingSettings
            Set-Content -Path $profilePath -Value $profileContent -Encoding UTF8
        } else {
            Set-Content -Path $profilePath -Value $encodingSettings -Encoding UTF8
        }

        # Appliquer les paramètres à la session actuelle
        [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
        $PSDefaultParameterValues['Out-File:Encoding'] = 'utf8NoBOM'
        $PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8NoBOM'

        Write-ColorOutput "   Configuration PowerShell terminée avec succès." -ForegroundColor "Green"
    } catch {
        Write-ColorOutput "   Erreur lors de la configuration PowerShell: $_" -ForegroundColor "Red"
    }
}

Write-Host ""
#endregion

#region Configuration de Git
Write-ColorOutput "2. Configuration des paramètres Git pour l'encodage..." -ForegroundColor "Green"

try {
    # Vérifier si Git est installé
    $gitVersion = git --version
    if (-not $?) {
        Write-ColorOutput "   Git n'est pas installé ou n'est pas dans le PATH. Configuration Git ignorée." -ForegroundColor "Yellow"
    } else {
        # Configurer Git pour l'encodage
        git config --global core.autocrlf input
        git config --global core.safecrlf warn
        git config --global i18n.commitencoding utf-8
        git config --global i18n.logoutputencoding utf-8
        git config --global core.quotepath false
        git config --global gui.encoding utf-8

        Write-ColorOutput "   Configuration Git terminée avec succès." -ForegroundColor "Green"
        
        # Afficher la configuration actuelle
        Write-ColorOutput "   Configuration Git actuelle:" -ForegroundColor "Cyan"
        Write-ColorOutput "   - core.autocrlf: $(git config --global core.autocrlf)" -ForegroundColor "Cyan"
        Write-ColorOutput "   - core.safecrlf: $(git config --global core.safecrlf)" -ForegroundColor "Cyan"
        Write-ColorOutput "   - i18n.commitencoding: $(git config --global i18n.commitencoding)" -ForegroundColor "Cyan"
        Write-ColorOutput "   - i18n.logoutputencoding: $(git config --global i18n.logoutputencoding)" -ForegroundColor "Cyan"
        Write-ColorOutput "   - core.quotepath: $(git config --global core.quotepath)" -ForegroundColor "Cyan"
        Write-ColorOutput "   - gui.encoding: $(git config --global gui.encoding)" -ForegroundColor "Cyan"
    }
} catch {
    Write-ColorOutput "   Erreur lors de la configuration Git: $_" -ForegroundColor "Red"
}

Write-Host ""
#endregion

#region Configuration des hooks Git
if (-not $SkipGitHooks) {
    Write-ColorOutput "3. Configuration des hooks Git pre-commit..." -ForegroundColor "Green"

    try {
        # Vérifier si le répertoire .git existe
        $gitDir = Join-Path -Path (Get-Location) -ChildPath ".git"
        if (-not (Test-Path -Path $gitDir)) {
            Write-ColorOutput "   Le répertoire .git n'existe pas. Configuration des hooks Git ignorée." -ForegroundColor "Yellow"
        } else {
            # Créer le répertoire hooks s'il n'existe pas
            $hooksDir = Join-Path -Path $gitDir -ChildPath "hooks"
            if (-not (Test-Path -Path $hooksDir)) {
                New-Item -Path $hooksDir -ItemType Directory -Force | Out-Null
            }

            # Créer le hook pre-commit
            $preCommitPath = Join-Path -Path $hooksDir -ChildPath "pre-commit"
            $preCommitContent = @"
#!/usr/bin/env pwsh
#
# Hook pre-commit PowerShell pour vérifier l'encodage des fichiers
# Créé par setup-encoding-workflow.ps1

# Obtenir le répertoire racine de Git
`$gitRoot = git rev-parse --show-toplevel`
if (`$LASTEXITCODE -ne 0) {
    Write-Host "Erreur: Impossible de trouver le répertoire racine de Git."
    exit 1
}

# Vérifier les fichiers modifiés pour les problèmes d'encodage
Write-Host "Vérification de l'encodage des fichiers..."

# Liste des fichiers à vérifier
`$files = git diff --cached --name-only --diff-filter=ACM | Select-String -Pattern '\.(json|md|ps1|js|ts|html|css|txt)$' -ErrorAction SilentlyContinue`

if (-not `$files) {
    Write-Host "Aucun fichier texte à vérifier."
    exit 0
}

# Vérifier l'encodage des fichiers
`$has_error = 0`
foreach (`$file in `$files) {
    `$filePath = Join-Path -Path `$gitRoot -ChildPath `$file.Line

    # Vérifier si le fichier contient un BOM UTF-8
    if (Test-Path `$filePath) {
        `$bytes = [System.IO.File]::ReadAllBytes(`$filePath)
        if (`$bytes.Length -ge 3 -and `$bytes[0] -eq 0xEF -and `$bytes[1] -eq 0xBB -and `$bytes[2] -eq 0xBF) {
            Write-Host "ERREUR: `$filePath contient un BOM UTF-8. Veuillez le supprimer."
            `$has_error = 1
        }
        
        # Vérifier les fins de ligne CRLF
        `$content = Get-Content -Path `$filePath -Raw -ErrorAction SilentlyContinue`
        if (`$content -match "\r\n") {
            Write-Host "AVERTISSEMENT: `$filePath contient des fins de ligne CRLF. Considérez utiliser LF."
        }
    }
}

if (`$has_error -eq 1) {
    Write-Host "Des problèmes d'encodage ont été détectés. Commit annulé."
    Write-Host "Utilisez 'fix-encoding-final.ps1' pour corriger les problèmes d'encodage."
    exit 1
}

Write-Host "Vérification d'encodage terminée avec succès."
exit 0
"@

            # Écrire le hook pre-commit
            Set-Content -Path $preCommitPath -Value $preCommitContent -Encoding UTF8
            
            # Rendre le hook exécutable (sous Unix/Linux/macOS)
            if ($IsLinux -or $IsMacOS) {
                chmod +x $preCommitPath
            }

            Write-ColorOutput "   Hook pre-commit configuré avec succès." -ForegroundColor "Green"
        }
    } catch {
        Write-ColorOutput "   Erreur lors de la configuration des hooks Git: $_" -ForegroundColor "Red"
    }

    Write-Host ""
}
#endregion

#region Configuration de VSCode
if (-not $SkipVSCode) {
    Write-ColorOutput "4. Configuration de Visual Studio Code..." -ForegroundColor "Green"

    try {
        # Vérifier si le répertoire .vscode existe
        $vscodeDir = Join-Path -Path (Get-Location) -ChildPath ".vscode"
        if (-not (Test-Path -Path $vscodeDir)) {
            New-Item -Path $vscodeDir -ItemType Directory -Force | Out-Null
            Write-ColorOutput "   Répertoire .vscode créé." -ForegroundColor "Green"
        }

        # Créer ou mettre à jour le fichier settings.json (Compatible PowerShell 5.1)
        $settingsPath = Join-Path -Path $vscodeDir -ChildPath "settings.json"
        $settingsContent = [ordered]@{}

        if (Test-Path -Path $settingsPath) {
            $content = Get-Content -Path $settingsPath -Raw
            # Supprimer les commentaires pour éviter les erreurs de parsing JSON
            $contentWithoutComments = $content -replace '(?s)/\*.*?\*/' -replace '//.*'
            
            if (-not [string]::IsNullOrWhiteSpace($contentWithoutComments)) {
                try {
                    $settingsContent = $contentWithoutComments | ConvertFrom-Json -ErrorAction Stop
                } catch {
                    Write-ColorOutput "   AVERTISSEMENT: Le fichier settings.json contient du JSON invalide (après suppression des commentaires) et sera écrasé." -ForegroundColor "Yellow"
                    $settingsContent = [ordered]@{}
                }
            }
        }

        # Ajouter ou mettre à jour les paramètres d'encodage
        $settingsToAdd = @{
            'files.encoding' = "utf8"
            'files.autoGuessEncoding' = $true
            'files.eol' = "`n"
        }

        foreach ($key in $settingsToAdd.Keys) {
            if ($settingsContent.PSObject.Properties[$key]) {
                $settingsContent.$key = $settingsToAdd[$key]
            } else {
                Add-Member -InputObject $settingsContent -MemberType NoteProperty -Name $key -Value $settingsToAdd[$key]
            }
        }

        # Écrire le fichier settings.json
        $settingsJson = ConvertTo-Json $settingsContent -Depth 10 -Compress
        Set-Content -Path $settingsPath -Value $settingsJson -Encoding UTF8

        Write-ColorOutput "   Configuration VSCode terminée avec succès." -ForegroundColor "Green"
    } catch {
        Write-ColorOutput "   Erreur lors de la configuration VSCode: $_" -ForegroundColor "Red"
    }

    Write-Host ""
}
#endregion

#region Vérification de l'encodage des fichiers existants
Write-ColorOutput "5. Vérification de l'encodage des fichiers existants..." -ForegroundColor "Green"

try {
    # Vérifier si le script de diagnostic existe
    $diagnosticScript = Join-Path -Path (Get-Location) -ChildPath "roo-config\diagnostic-scripts\encoding-diagnostic.ps1"
    if (Test-Path -Path $diagnosticScript) {
        Write-ColorOutput "   Exécution du script de diagnostic d'encodage..." -ForegroundColor "Cyan"
        & $diagnosticScript
    } else {
        Write-ColorOutput "   Le script de diagnostic d'encodage n'existe pas." -ForegroundColor "Yellow"
        Write-ColorOutput "   Vérification manuelle des fichiers JSON..." -ForegroundColor "Cyan"
        
        # Rechercher les fichiers JSON
        $jsonFiles = Get-ChildItem -Path (Get-Location) -Filter "*.json" -Recurse
        Write-ColorOutput "   Trouvé $($jsonFiles.Count) fichiers JSON." -ForegroundColor "Cyan"
        
        # Vérifier les 5 premiers fichiers JSON
        $filesToCheck = $jsonFiles | Select-Object -First 5
        foreach ($file in $filesToCheck) {
            Write-ColorOutput "   Vérification de $($file.FullName)..." -ForegroundColor "Cyan"
            
            # Vérifier si le fichier contient un BOM UTF-8
            $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
            if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
                Write-ColorOutput "     - Contient un BOM UTF-8" -ForegroundColor "Yellow"
            } else {
                Write-ColorOutput "     - Sans BOM UTF-8" -ForegroundColor "Green"
            }
            
            # Vérifier si le JSON est valide
            try {
                $content = Get-Content -Path $file.FullName -Raw
                $null = $content | ConvertFrom-Json
                Write-ColorOutput "     - JSON valide" -ForegroundColor "Green"
            } catch {
                Write-ColorOutput "     - JSON invalide: $_" -ForegroundColor "Red"
                
                # Si c'est package-lock.json, le supprimer
                if ($file.Name -eq "package-lock.json") {
                    Write-ColorOutput "     - Le fichier package-lock.json est invalide et sera supprimé." -ForegroundColor "Yellow"
                    try {
                        Remove-Item -Path $file.FullName -Force
                        Write-ColorOutput "     - package-lock.json a été supprimé. Il sera régénéré au prochain 'npm install'." -ForegroundColor "Green"
                    } catch {
                        Write-ColorOutput "     - ERREUR lors de la suppression de package-lock.json: $_" -ForegroundColor "Red"
                    }
                }
            }
        }
    }
} catch {
    Write-ColorOutput "   Erreur lors de la vérification de l'encodage: $_" -ForegroundColor "Red"
}

Write-Host ""
#endregion

#region Résumé
Write-ColorOutput "=========================================================" -ForegroundColor "Cyan"
Write-ColorOutput "  Configuration de l'environnement d'encodage terminée" -ForegroundColor "Cyan"
Write-ColorOutput "=========================================================" -ForegroundColor "Cyan"
Write-Host ""
Write-ColorOutput "Résumé des actions effectuées:" -ForegroundColor "White"
Write-ColorOutput "1. Configuration des paramètres d'encodage de PowerShell" -ForegroundColor "White"
Write-ColorOutput "2. Configuration des paramètres Git pour l'encodage" -ForegroundColor "White"
if (-not $SkipGitHooks) {
    Write-ColorOutput "3. Configuration des hooks Git pre-commit" -ForegroundColor "White"
}
if (-not $SkipVSCode) {
    Write-ColorOutput "4. Configuration de Visual Studio Code" -ForegroundColor "White"
}
Write-ColorOutput "5. Vérification de l'encodage des fichiers existants" -ForegroundColor "White"
Write-Host ""
Write-ColorOutput "Pour corriger les problèmes d'encodage détectés, utilisez:" -ForegroundColor "White"
Write-ColorOutput ".\roo-config\encoding-scripts\fix-encoding-final.ps1" -ForegroundColor "Yellow"
Write-Host ""
Write-ColorOutput "Pour plus d'informations, consultez:" -ForegroundColor "White"
Write-ColorOutput "docs\GUIDE-ENCODAGE.md" -ForegroundColor "Yellow"
Write-Host ""
