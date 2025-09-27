#Requires -Version 5.1
<#
.SYNOPSIS
    Script consolidé de configuration UTF-8 pour l'environnement de développement Roo Extensions

.DESCRIPTION
    Ce script automatise la configuration complète d'un environnement de développement avec les bonnes pratiques d'encodage UTF-8.
    Il configure les paramètres d'encodage de PowerShell, Git, VSCode, et met en place des hooks Git pre-commit.
    
    Version consolidée qui remplace tous les scripts d'encodage redondants.

.PARAMETER Force
    Force la reconfiguration même si certains paramètres sont déjà configurés.

.PARAMETER SkipGitHooks
    Ignore la configuration des hooks Git.

.PARAMETER SkipVSCode
    Ignore la configuration de Visual Studio Code.

.PARAMETER BackupProfile
    Crée une sauvegarde du profil PowerShell existant.

.PARAMETER RestoreProfile
    Restaure le profil PowerShell depuis la sauvegarde la plus récente.

.PARAMETER SetupPowerShellProfile
    Configure uniquement le profil PowerShell.

.PARAMETER TestConfiguration
    Teste la configuration actuelle sans la modifier.

.PARAMETER Verbose
    Affichage détaillé des opérations.

.EXAMPLE
    .\setup.ps1
    Configuration complète avec paramètres par défaut

.EXAMPLE
    .\setup.ps1 -Force -Verbose
    Reconfiguration forcée avec sortie détaillée

.EXAMPLE
    .\setup.ps1 -TestConfiguration
    Test de la configuration existante

.NOTES
    Version: 3.0 Consolidée
    Date: 26/09/2025
    Auteur: Roo Extensions Team
    Remplace: 23 scripts redondants du répertoire scripts/encoding/
#>

param (
    [switch]$Force,
    [switch]$SkipGitHooks,
    [switch]$SkipVSCode,
    [switch]$BackupProfile,
    [switch]$RestoreProfile,
    [switch]$SetupPowerShellProfile,
    [switch]$TestConfiguration,
    [switch]$Verbose
)

# Variables globales
$Script:Colors = @{
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "Cyan"
    Header = "Magenta"
    Default = "White"
}

# =================================================================================================
# FONCTIONS UTILITAIRES
# =================================================================================================

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

function Write-VerboseOutput {
    param (
        [string]$Message,
        [string]$Type = "Info"
    )
    
    if ($Verbose) {
        $color = $Script:Colors[$Type]
        if (-not $color) { $color = $Script:Colors.Default }
        
        $timestamp = Get-Date -Format "HH:mm:ss"
        Write-Host "[$timestamp] $Message" -ForegroundColor $color
    }
}

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

function Test-CurrentConfiguration {
    Write-ColorOutput "`n=== TEST DE LA CONFIGURATION ACTUELLE ===" -ForegroundColor "Magenta"
    
    $results = @{
        PowerShellUTF8 = ($([Console]::OutputEncoding.CodePage) -eq 65001)
        SystemCodePage = (cmd /c chcp 2>&1) -match "65001"
        ProfileExists = (Test-Path $PROFILE)
        ProfileConfigured = $false
        GitConfigured = $false
        VSCodeConfigured = $false
    }
    
    # Vérifier la configuration du profil
    if ($results.ProfileExists) {
        $profileContent = Get-Content -Path $PROFILE -Raw -ErrorAction SilentlyContinue
        $results.ProfileConfigured = $profileContent -match "Configuration d'encodage pour roo-extensions"
    }
    
    # Vérifier la configuration Git
    try {
        $gitEncoding = git config --global i18n.commitencoding 2>$null
        $results.GitConfigured = ($gitEncoding -eq "utf-8")
    } catch {
        $results.GitConfigured = $false
    }
    
    # Vérifier la configuration VSCode
    $vscodeSettingsPath = Join-Path -Path (Get-Location) -ChildPath ".vscode\settings.json"
    if (Test-Path $vscodeSettingsPath) {
        try {
            $vscodeContent = Get-Content -Path $vscodeSettingsPath -Raw
            $results.VSCodeConfigured = $vscodeContent -match '"files.encoding".*"utf8"'
        } catch {
            $results.VSCodeConfigured = $false
        }
    }
    
    # Afficher les résultats
    Write-ColorOutput "`nRésultats du diagnostic :" -ForegroundColor "Cyan"
    Write-ColorOutput "+ PowerShell UTF-8: $(if($results.PowerShellUTF8) { "OUI" } else { "NON" })" -ForegroundColor $(if($results.PowerShellUTF8) { "Green" } else { "Red" })
    Write-ColorOutput "+ Code Page Système: $(if($results.SystemCodePage) { "65001 (UTF-8)" } else { "PAS UTF-8" })" -ForegroundColor $(if($results.SystemCodePage) { "Green" } else { "Red" })
    Write-ColorOutput "+ Profil PowerShell: $(if($results.ProfileConfigured) { "CONFIGURÉ" } else { "NON CONFIGURÉ" })" -ForegroundColor $(if($results.ProfileConfigured) { "Green" } else { "Red" })
    Write-ColorOutput "+ Configuration Git: $(if($results.GitConfigured) { "CONFIGURÉE" } else { "NON CONFIGURÉE" })" -ForegroundColor $(if($results.GitConfigured) { "Green" } else { "Red" })
    Write-ColorOutput "+ Configuration VSCode: $(if($results.VSCodeConfigured) { "CONFIGURÉE" } else { "NON CONFIGURÉE" })" -ForegroundColor $(if($results.VSCodeConfigured) { "Green" } else { "Red" })
    
    $allConfigured = $results.PowerShellUTF8 -and $results.ProfileConfigured -and $results.GitConfigured
    Write-ColorOutput "`nÉtat général: $(if($allConfigured) { "[OK] TOUT EST CONFIGURÉ" } else { "[FAIL] CONFIGURATION INCOMPLÈTE" })" -ForegroundColor $(if($allConfigured) { "Green" } else { "Yellow" })
    
    return $results
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
        Write-VerboseOutput "Profil sauvegardé vers: $BackupPath" "Success"
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
# CONFIGURATION PRINCIPALE
# =================================================================================================

function Set-PowerShellEncoding {
    Write-ColorOutput "1. Configuration des paramètres d'encodage de PowerShell..." -ForegroundColor "Green"
    Write-VerboseOutput "Début de la configuration PowerShell" "Info"

    # Déterminer le chemin du profil PowerShell
    $profilePath = $PROFILE
    $profileExists = Test-Path -Path $profilePath
    $profileContent = ""

    if ($profileExists) {
        $profileContent = Get-Content -Path $profilePath -Raw
        Write-VerboseOutput "Profil existant détecté: $profilePath" "Info"
    }

    # Configuration d'encodage complète (fusion des meilleures pratiques)
    $encodingSettings = @"

# Configuration d'encodage pour roo-extensions - Version Consolidée
# Ajouté par scripts/utf8/setup.ps1
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new()
`$OutputEncoding = [System.Text.UTF8Encoding]::new()
`$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8NoBOM'
`$PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8NoBOM'
try { chcp 65001 | Out-Null } catch { Write-Warning "Impossible de définir la code page 65001" }
# Fin de la configuration d'encodage
"@

    # Vérifier si les paramètres sont déjà configurés
    if ($profileExists -and $profileContent -match "\[Console\]::OutputEncoding = \[System\.Text\.UTF8Encoding\]::new\(\)") {
        if ($Force) {
            Write-ColorOutput "   Les paramètres d'encodage PowerShell sont déjà configurés. Reconfiguration forcée..." -ForegroundColor "Yellow"
            Write-VerboseOutput "Reconfiguration forcée demandée" "Warning"
        } else {
            Write-ColorOutput "   Les paramètres d'encodage PowerShell sont déjà configurés." -ForegroundColor "Yellow"
            Write-ColorOutput "   Utilisez -Force pour reconfigurer." -ForegroundColor "Yellow"
            Write-ColorOutput "   Configuration PowerShell ignorée." -ForegroundColor "Yellow"
            return $true
        }
    }

    try {
        # Créer le répertoire du profil s'il n'existe pas
        $profileDir = Split-Path -Path $profilePath -Parent
        if (-not (Test-Path -Path $profileDir)) {
            New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
            Write-VerboseOutput "Répertoire de profil créé: $profileDir" "Success"
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
        [Console]::InputEncoding = [System.Text.UTF8Encoding]::new()
        $OutputEncoding = [System.Text.UTF8Encoding]::new()
        $PSDefaultParameterValues['Out-File:Encoding'] = 'utf8NoBOM'
        $PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8NoBOM'
        try { chcp 65001 | Out-Null } catch { }

        Write-ColorOutput "   Configuration PowerShell terminée avec succès." -ForegroundColor "Green"
        Write-VerboseOutput "Configuration PowerShell appliquée avec succès" "Success"
        return $true
    } catch {
        Write-ColorOutput "   Erreur lors de la configuration PowerShell: $_" -ForegroundColor "Red"
        Write-VerboseOutput "Erreur PowerShell: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Set-GitConfiguration {
    Write-ColorOutput "2. Configuration des paramètres Git pour l'encodage..." -ForegroundColor "Green"
    Write-VerboseOutput "Début de la configuration Git" "Info"

    try {
        # Vérifier si Git est installé
        $gitVersion = git --version 2>$null
        if (-not $?) {
            Write-ColorOutput "   Git n'est pas installé ou n'est pas dans le PATH. Configuration Git ignorée." -ForegroundColor "Yellow"
            Write-VerboseOutput "Git non trouvé dans le PATH" "Warning"
            return $false
        }

        Write-VerboseOutput "Version Git détectée: $gitVersion" "Info"

        # Configurer Git pour l'encodage
        git config --global core.autocrlf input
        git config --global core.safecrlf warn
        git config --global i18n.commitencoding utf-8
        git config --global i18n.logoutputencoding utf-8
        git config --global core.quotepath false
        git config --global gui.encoding utf-8

        Write-ColorOutput "   Configuration Git terminée avec succès." -ForegroundColor "Green"
        
        # Afficher la configuration actuelle si verbose
        if ($Verbose) {
            Write-ColorOutput "   Configuration Git actuelle:" -ForegroundColor "Cyan"
            Write-ColorOutput "   - core.autocrlf: $(git config --global core.autocrlf)" -ForegroundColor "Cyan"
            Write-ColorOutput "   - core.safecrlf: $(git config --global core.safecrlf)" -ForegroundColor "Cyan"
            Write-ColorOutput "   - i18n.commitencoding: $(git config --global i18n.commitencoding)" -ForegroundColor "Cyan"
            Write-ColorOutput "   - i18n.logoutputencoding: $(git config --global i18n.logoutputencoding)" -ForegroundColor "Cyan"
            Write-ColorOutput "   - core.quotepath: $(git config --global core.quotepath)" -ForegroundColor "Cyan"
            Write-ColorOutput "   - gui.encoding: $(git config --global gui.encoding)" -ForegroundColor "Cyan"
        }
        return $true
    } catch {
        Write-ColorOutput "   Erreur lors de la configuration Git: $_" -ForegroundColor "Red"
        Write-VerboseOutput "Erreur Git: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Set-GitHooks {
    if ($SkipGitHooks) {
        Write-VerboseOutput "Configuration des hooks Git ignorée (SkipGitHooks)" "Info"
        return $true
    }

    Write-ColorOutput "3. Configuration des hooks Git pre-commit..." -ForegroundColor "Green"
    Write-VerboseOutput "Début de la configuration des hooks Git" "Info"

    try {
        # Vérifier si le répertoire .git existe
        $gitDir = Join-Path -Path (Get-Location) -ChildPath ".git"
        if (-not (Test-Path -Path $gitDir)) {
            Write-ColorOutput "   Le répertoire .git n'existe pas. Configuration des hooks Git ignorée." -ForegroundColor "Yellow"
            Write-VerboseOutput "Répertoire .git non trouvé" "Warning"
            return $false
        }

        # Créer le répertoire hooks s'il n'existe pas
        $hooksDir = Join-Path -Path $gitDir -ChildPath "hooks"
        if (-not (Test-Path -Path $hooksDir)) {
            New-Item -Path $hooksDir -ItemType Directory -Force | Out-Null
            Write-VerboseOutput "Répertoire hooks créé: $hooksDir" "Success"
        }

        # Créer le hook pre-commit
        $preCommitPath = Join-Path -Path $hooksDir -ChildPath "pre-commit"
        $preCommitContent = @"
#!/usr/bin/env pwsh
#
# Hook pre-commit PowerShell pour vérifier l'encodage des fichiers
# Créé par scripts/utf8/setup.ps1 - Version consolidée

# Obtenir le répertoire racine de Git
`$gitRoot = git rev-parse --show-toplevel
if (`$LASTEXITCODE -ne 0) {
    Write-Host "Erreur: Impossible de trouver le répertoire racine de Git."
    exit 1
}

# Vérifier les fichiers modifiés pour les problèmes d'encodage
Write-Host "Vérification de l'encodage des fichiers..."

# Liste des fichiers à vérifier
`$files = git diff --cached --name-only --diff-filter=ACM | Select-String -Pattern '\.(json|md|ps1|js|ts|html|css|txt)$' -ErrorAction SilentlyContinue

if (-not `$files) {
    Write-Host "Aucun fichier texte à vérifier."
    exit 0
}

# Vérifier l'encodage des fichiers
`$has_error = 0
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
        `$content = Get-Content -Path `$filePath -Raw -ErrorAction SilentlyContinue
        if (`$content -match "\r\n") {
            Write-Host "AVERTISSEMENT: `$filePath contient des fins de ligne CRLF. Considérez utiliser LF."
        }
    }
}

if (`$has_error -eq 1) {
    Write-Host "Des problèmes d'encodage ont été détectés. Commit annulé."
    Write-Host "Utilisez 'scripts/utf8/repair.ps1' pour corriger les problèmes d'encodage."
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
        Write-VerboseOutput "Hook pre-commit installé: $preCommitPath" "Success"
        return $true
    } catch {
        Write-ColorOutput "   Erreur lors de la configuration des hooks Git: $_" -ForegroundColor "Red"
        Write-VerboseOutput "Erreur hooks Git: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Set-VSCodeConfiguration {
    if ($SkipVSCode) {
        Write-VerboseOutput "Configuration VSCode ignorée (SkipVSCode)" "Info"
        return $true
    }

    Write-ColorOutput "4. Configuration de Visual Studio Code..." -ForegroundColor "Green"
    Write-VerboseOutput "Début de la configuration VSCode" "Info"

    try {
        # Vérifier si le répertoire .vscode existe
        $vscodeDir = Join-Path -Path (Get-Location) -ChildPath ".vscode"
        if (-not (Test-Path -Path $vscodeDir)) {
            New-Item -Path $vscodeDir -ItemType Directory -Force | Out-Null
            Write-ColorOutput "   Répertoire .vscode créé." -ForegroundColor "Green"
            Write-VerboseOutput "Répertoire .vscode créé: $vscodeDir" "Success"
        }

        # Configuration VSCode optimisée (fusion des meilleures pratiques)
        $vscodeConfig = @{
            'files.encoding' = 'utf8'
            'files.autoGuessEncoding' = $false
            'files.eol' = "`n"
            'terminal.integrated.defaultProfile.windows' = 'PowerShell UTF-8'
            'terminal.integrated.profiles.windows' = @{
                'PowerShell UTF-8' = @{
                    'source' = 'PowerShell'
                    'args' = @('-NoExit', '-Command', 'chcp 65001')
                }
            }
            'terminal.integrated.inheritEnv' = $true
            'terminal.integrated.shellIntegration.enabled' = $true
        }

        # Créer ou mettre à jour le fichier settings.json
        $settingsPath = Join-Path -Path $vscodeDir -ChildPath "settings.json"
        $settingsContent = [ordered]@{}

        if (Test-Path -Path $settingsPath) {
            $content = Get-Content -Path $settingsPath -Raw
            # Supprimer les commentaires pour éviter les erreurs de parsing JSON
            $contentWithoutComments = $content -replace '(?s)/\*.*?\*/' -replace '//.*'
            
            if (-not [string]::IsNullOrWhiteSpace($contentWithoutComments)) {
                try {
                    $settingsContent = $contentWithoutComments | ConvertFrom-Json -ErrorAction Stop
                    Write-VerboseOutput "Settings.json existant chargé" "Info"
                } catch {
                    Write-ColorOutput "   AVERTISSEMENT: Le fichier settings.json contient du JSON invalide et sera écrasé." -ForegroundColor "Yellow"
                    Write-VerboseOutput "JSON invalide détecté, création d'un nouveau fichier" "Warning"
                    $settingsContent = [ordered]@{}
                }
            }
        }

        # Ajouter ou mettre à jour les paramètres d'encodage
        foreach ($key in $vscodeConfig.Keys) {
            if ($settingsContent.PSObject.Properties[$key]) {
                $settingsContent.$key = $vscodeConfig[$key]
            } else {
                Add-Member -InputObject $settingsContent -MemberType NoteProperty -Name $key -Value $vscodeConfig[$key]
            }
            Write-VerboseOutput "Configuration VSCode ajoutée: $key" "Info"
        }

        # Écrire le fichier settings.json
        $settingsJson = ConvertTo-Json $settingsContent -Depth 10 -Compress
        Set-Content -Path $settingsPath -Value $settingsJson -Encoding UTF8

        Write-ColorOutput "   Configuration VSCode terminée avec succès." -ForegroundColor "Green"
        Write-VerboseOutput "VSCode settings.json configuré: $settingsPath" "Success"
        return $true
    } catch {
        Write-ColorOutput "   Erreur lors de la configuration VSCode: $_" -ForegroundColor "Red"
        Write-VerboseOutput "Erreur VSCode: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Test-ExistingFiles {
    Write-ColorOutput "5. Vérification de l'encodage des fichiers existants..." -ForegroundColor "Green"
    Write-VerboseOutput "Début de la vérification des fichiers existants" "Info"

    try {
        # Rechercher les fichiers JSON dans le répertoire courant
        $jsonFiles = Get-ChildItem -Path (Get-Location) -Filter "*.json" -Recurse -ErrorAction SilentlyContinue
        $totalFiles = $jsonFiles.Count
        Write-ColorOutput "   Trouvé $totalFiles fichiers JSON." -ForegroundColor "Cyan"
        Write-VerboseOutput "Fichiers JSON trouvés: $totalFiles" "Info"
        
        if ($totalFiles -eq 0) {
            Write-ColorOutput "   Aucun fichier JSON trouvé pour la vérification." -ForegroundColor "Yellow"
            return $true
        }

        # Vérifier un échantillon de fichiers JSON (max 10)
        $filesToCheck = $jsonFiles | Select-Object -First 10
        $problemFiles = @()
        
        foreach ($file in $filesToCheck) {
            Write-VerboseOutput "Vérification de: $($file.FullName)" "Info"
            
            # Vérifier si le fichier contient un BOM UTF-8
            $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
            $hasBOM = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
            
            # Vérifier si le JSON est valide
            $isValidJSON = $true
            try {
                $content = Get-Content -Path $file.FullName -Raw
                $null = $content | ConvertFrom-Json
            } catch {
                $isValidJSON = $false
                $problemFiles += $file.FullName
                Write-VerboseOutput "JSON invalide: $($file.FullName)" "Error"
            }
            
            if ($Verbose) {
                Write-ColorOutput "   - $($file.Name): BOM=$(if($hasBOM) { "OUI" } else { "NON" }), JSON_OK=$(if($isValidJSON) { "OUI" } else { "NON" })" -ForegroundColor $(if($isValidJSON -and -not $hasBOM) { "Green" } else { "Yellow" })
            }
        }

        if ($problemFiles.Count -gt 0) {
            Write-ColorOutput "   [WARNING] Fichiers problématiques détectés: $($problemFiles.Count)" -ForegroundColor "Yellow"
            Write-ColorOutput "   Utilisez 'scripts/utf8/repair.ps1' pour les corriger." -ForegroundColor "Yellow"
        } else {
            Write-ColorOutput "   [OK] Tous les fichiers vérifiés sont corrects." -ForegroundColor "Green"
        }
        
        return $true
    } catch {
        Write-ColorOutput "   Erreur lors de la vérification de l'encodage: $_" -ForegroundColor "Red"
        Write-VerboseOutput "Erreur vérification fichiers: $($_.Exception.Message)" "Error"
        return $false
    }
}

# =================================================================================================
# PROGRAMME PRINCIPAL
# =================================================================================================

# Bannière
Write-ColorOutput "=========================================================" -ForegroundColor "Cyan"
Write-ColorOutput "  CONFIGURATION UTF-8 CONSOLIDÉE - ROO EXTENSIONS" -ForegroundColor "Cyan"
Write-ColorOutput "  Version 3.0 - Remplace 23 scripts redondants" -ForegroundColor "Cyan"
Write-ColorOutput "=========================================================" -ForegroundColor "Cyan"
Write-Host ""

# Déterminer le chemin du profil PowerShell
$profilePath = $PROFILE

# --- Actions spéciales ---
if ($BackupProfile) {
    Invoke-ProfileBackup -ProfilePath $profilePath
    exit 0
}

if ($RestoreProfile) {
    Invoke-ProfileRestore -ProfilePath $profilePath
    exit 0
}

if ($TestConfiguration) {
    Test-CurrentConfiguration
    exit 0
}

# --- Configuration principale ---
Write-VerboseOutput "Début de la configuration complète" "Info"
$results = @{
    PowerShell = $false
    Git = $false
    GitHooks = $false
    VSCode = $false
    FileCheck = $false
}

# Configuration PowerShell
if ($SetupPowerShellProfile -or -not $SetupPowerShellProfile) {
    $results.PowerShell = Set-PowerShellEncoding
    Write-Host ""
}

# Configuration Git
$results.Git = Set-GitConfiguration
Write-Host ""

# Configuration des hooks Git
$results.GitHooks = Set-GitHooks
if (-not $SkipGitHooks) { Write-Host "" }

# Configuration VSCode
$results.VSCode = Set-VSCodeConfiguration
if (-not $SkipVSCode) { Write-Host "" }

# Vérification des fichiers existants
$results.FileCheck = Test-ExistingFiles
Write-Host ""

# Résumé final
Write-ColorOutput "=========================================================" -ForegroundColor "Cyan"
Write-ColorOutput "  CONFIGURATION TERMINÉE" -ForegroundColor "Cyan"
Write-ColorOutput "=========================================================" -ForegroundColor "Cyan"
Write-Host ""

Write-ColorOutput "Résumé des actions effectuées:" -ForegroundColor "White"
Write-ColorOutput "+ Configuration PowerShell: $(if($results.PowerShell) { "SUCCÈS" } else { "ÉCHEC" })" -ForegroundColor $(if($results.PowerShell) { "Green" } else { "Red" })
Write-ColorOutput "+ Configuration Git: $(if($results.Git) { "SUCCÈS" } else { "ÉCHEC" })" -ForegroundColor $(if($results.Git) { "Green" } else { "Red" })
if (-not $SkipGitHooks) {
    Write-ColorOutput "+ Hooks Git pre-commit: $(if($results.GitHooks) { "SUCCÈS" } else { "ÉCHEC" })" -ForegroundColor $(if($results.GitHooks) { "Green" } else { "Red" })
}
if (-not $SkipVSCode) {
    Write-ColorOutput "+ Configuration VSCode: $(if($results.VSCode) { "SUCCÈS" } else { "ÉCHEC" })" -ForegroundColor $(if($results.VSCode) { "Green" } else { "Red" })
}
Write-ColorOutput "+ Vérification fichiers: $(if($results.FileCheck) { "SUCCÈS" } else { "ÉCHEC" })" -ForegroundColor $(if($results.FileCheck) { "Green" } else { "Red" })

Write-Host ""
$allSuccess = $results.PowerShell -and $results.Git -and ($SkipGitHooks -or $results.GitHooks) -and ($SkipVSCode -or $results.VSCode) -and $results.FileCheck
Write-ColorOutput "[TARGET] Statut global: $(if($allSuccess) { "[OK] CONFIGURATION RÉUSSIE" } else { "[WARNING] PROBLÈMES DÉTECTÉS" })" -ForegroundColor $(if($allSuccess) { "Green" } else { "Yellow" })

if ($allSuccess) {
    Write-ColorOutput "`n[REFRESH] Redémarrez votre session PowerShell pour appliquer tous les changements." -ForegroundColor "Cyan"
} else {
    Write-ColorOutput "`n[TOOL] Utilisez les scripts de diagnostic et réparation:" -ForegroundColor "White"
    Write-ColorOutput "   - scripts/utf8/diagnostic.ps1  # Diagnostic approfondi" -ForegroundColor "Yellow"
    Write-ColorOutput "   - scripts/utf8/repair.ps1      # Réparation des fichiers" -ForegroundColor "Yellow"
}

Write-Host ""
Write-VerboseOutput "Configuration terminée" "Success"

# Code de sortie
exit $(if($allSuccess) { 0 } else { 1 })