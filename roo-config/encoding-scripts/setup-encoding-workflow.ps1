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
    [switch]$SkipVSCode
)

# Fonction pour afficher les messages avec couleur
function Write-ColorOutput {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$ForegroundColor = "White"
    )
    
    Write-Host $Message -ForegroundColor $ForegroundColor
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

# Bannière
Write-ColorOutput "=========================================================" -ForegroundColor "Cyan"
Write-ColorOutput "  Configuration de l'environnement d'encodage pour Roo Extensions" -ForegroundColor "Cyan"
Write-ColorOutput "=========================================================" -ForegroundColor "Cyan"
Write-ColorOutput ""

#region Configuration de PowerShell
Write-ColorOutput "1. Configuration des paramètres d'encodage de PowerShell..." -ForegroundColor "Green"

# Vérifier si le profil PowerShell existe
$profilePath = $PROFILE
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

Write-ColorOutput ""
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

Write-ColorOutput ""
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
#!/bin/sh
#
# Hook pre-commit pour vérifier l'encodage des fichiers
# Créé par setup-encoding-workflow.ps1

# Vérifier les fichiers modifiés pour les problèmes d'encodage
echo "Vérification de l'encodage des fichiers..."

# Liste des fichiers à vérifier
files=\$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(json|md|ps1|js|ts|html|css|txt)$')

if [ -z "\$files" ]; then
    echo "Aucun fichier texte à vérifier."
    exit 0
fi

# Vérifier l'encodage des fichiers
has_error=0
for file in \$files; do
    # Vérifier si le fichier contient un BOM UTF-8
    if [ -f "\$file" ]; then
        # Vérifier le BOM UTF-8 (EF BB BF)
        bom=\$(hexdump -n 3 -e '3/1 "%02X"' "\$file")
        if [ "\$bom" = "EFBBBF" ]; then
            echo "ERREUR: \$file contient un BOM UTF-8. Veuillez le supprimer."
            has_error=1
        fi
        
        # Vérifier les fins de ligne CRLF
        if grep -q $'\r' "\$file"; then
            echo "AVERTISSEMENT: \$file contient des fins de ligne CRLF. Considérez utiliser LF."
        fi
    fi
done

if [ \$has_error -eq 1 ]; then
    echo "Des problèmes d'encodage ont été détectés. Commit annulé."
    echo "Utilisez 'fix-encoding-final.ps1' pour corriger les problèmes d'encodage."
    exit 1
fi

echo "Vérification d'encodage terminée avec succès."
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

    Write-ColorOutput ""
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

        # Créer ou mettre à jour le fichier settings.json
        $settingsPath = Join-Path -Path $vscodeDir -ChildPath "settings.json"
        $settingsContent = @{}

        if (Test-Path -Path $settingsPath) {
            $settingsContent = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
        }

        # Ajouter ou mettre à jour les paramètres d'encodage
        $settingsContent."files.encoding" = "utf8"
        $settingsContent."files.autoGuessEncoding" = $true
        $settingsContent."files.eol" = "\n"

        # Écrire le fichier settings.json
        $settingsJson = ConvertTo-Json $settingsContent -Depth 10
        Set-Content -Path $settingsPath -Value $settingsJson -Encoding UTF8

        Write-ColorOutput "   Configuration VSCode terminée avec succès." -ForegroundColor "Green"
    } catch {
        Write-ColorOutput "   Erreur lors de la configuration VSCode: $_" -ForegroundColor "Red"
    }

    Write-ColorOutput ""
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
            }
        }
    }
} catch {
    Write-ColorOutput "   Erreur lors de la vérification de l'encodage: $_" -ForegroundColor "Red"
}

Write-ColorOutput ""
#endregion

#region Résumé
Write-ColorOutput "=========================================================" -ForegroundColor "Cyan"
Write-ColorOutput "  Configuration de l'environnement d'encodage terminée" -ForegroundColor "Cyan"
Write-ColorOutput "=========================================================" -ForegroundColor "Cyan"
Write-ColorOutput ""
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
Write-ColorOutput ""
Write-ColorOutput "Pour corriger les problèmes d'encodage détectés, utilisez:" -ForegroundColor "White"
Write-ColorOutput ".\roo-config\encoding-scripts\fix-encoding-final.ps1" -ForegroundColor "Yellow"
Write-ColorOutput ""
Write-ColorOutput "Pour plus d'informations, consultez:" -ForegroundColor "White"
Write-ColorOutput "docs\GUIDE-ENCODAGE.md" -ForegroundColor "Yellow"
Write-ColorOutput ""