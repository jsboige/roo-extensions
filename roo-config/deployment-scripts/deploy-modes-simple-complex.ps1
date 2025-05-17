# Script de déploiement des modes simples/complex pour Roo (Version améliorée)
# Ce script permet de déployer rapidement les modes simples et complexes soit globalement, soit localement
# Avec gestion améliorée de l'encodage pour les caractères accentués

param (
    [Parameter(Mandatory = $false)]
    [ValidateSet("global", "local")]
    [string]$DeploymentType = "global",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$TestAfterDeploy,
    
    [Parameter(Mandatory = $false)]
    [switch]$DebugMode
)

# Fonction pour afficher des messages colorés
function Write-ColorOutput {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$ForegroundColor = "White"
    )
    
    $originalColor = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    Write-Output $Message
    $host.UI.RawUI.ForegroundColor = $originalColor
}

# Bannière
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Déploiement des modes simples/complex pour Roo" "Cyan"
Write-ColorOutput "   (Version améliorée avec correction d'encodage)" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"

# Vérifier que le fichier de configuration existe
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configFilePath = Join-Path -Path $scriptDir -ChildPath "..\roo-modes\configs\standard-modes.json"

if (-not (Test-Path -Path $configFilePath)) {
    Write-ColorOutput "Erreur: Le fichier de configuration 'standard-modes.json' n'existe pas." "Red"
    Write-ColorOutput "Assurez-vous que le fichier existe dans le répertoire 'roo-modes/configs/'." "Red"
    exit 1
}

# Déterminer le chemin du fichier de destination
if ($DeploymentType -eq "global") {
    $destinationDir = Join-Path -Path $env:APPDATA -ChildPath "Code\User\globalStorage\rooveterinaryinc.roo-cline\settings"
    $destinationFile = Join-Path -Path $destinationDir -ChildPath "custom_modes.json"
    
    # Vérifier que le répertoire de destination existe
    if (-not (Test-Path -Path $destinationDir)) {
        try {
            New-Item -Path $destinationDir -ItemType Directory -Force | Out-Null
            Write-ColorOutput "Répertoire créé: $destinationDir" "Green"
        }
        catch {
            Write-ColorOutput "Erreur lors de la création du répertoire: $destinationDir" "Red"
            Write-ColorOutput $_.Exception.Message "Red"
            exit 1
        }
    }
} else {
    # Déploiement local (dans le répertoire du projet)
    # Pour un déploiement local, le projectRoot doit être le répertoire racine du projet
    $projectRoot = Split-Path -Parent $scriptDir
    $destinationFile = Join-Path -Path $projectRoot -ChildPath ".roomodes"
}

Write-ColorOutput "`nDéploiement des modes simples/complex en mode $DeploymentType..." "Yellow"
Write-ColorOutput "Destination: $destinationFile" "Yellow"

# Vérifier si le fichier de destination existe déjà
if (Test-Path -Path $destinationFile) {
    if (-not $Force) {
        $confirmation = Read-Host "Le fichier de destination existe déjà. Voulez-vous le remplacer? (O/N)"
        if ($confirmation -ne "O" -and $confirmation -ne "o") {
            Write-ColorOutput "Opération annulée." "Yellow"
            exit 0
        }
    }
}

# Fonction pour vérifier l'encodage d'un fichier
function Test-FileEncoding {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        $encoding = "Unknown"
        
        # Vérifier le BOM (Byte Order Mark)
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            $encoding = "UTF-8 with BOM"
        } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
            $encoding = "UTF-16 BE"
        } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
            $encoding = "UTF-16 LE"
        } else {
            # Essayer de détecter UTF-8 sans BOM
            $isUtf8 = $true
            $i = 0
            while ($i -lt $bytes.Length) {
                if ($bytes[$i] -ge 0x80) {
                    # Vérifier la séquence UTF-8
                    if ($bytes[$i] -ge 0xC0 -and $bytes[$i] -le 0xDF -and $i + 1 -lt $bytes.Length -and $bytes[$i + 1] -ge 0x80 -and $bytes[$i + 1] -le 0xBF) {
                        $i += 2
                    } elseif ($bytes[$i] -ge 0xE0 -and $bytes[$i] -le 0xEF -and $i + 2 -lt $bytes.Length -and $bytes[$i + 1] -ge 0x80 -and $bytes[$i + 1] -le 0xBF -and $bytes[$i + 2] -ge 0x80 -and $bytes[$i + 2] -le 0xBF) {
                        $i += 3
                    } elseif ($bytes[$i] -ge 0xF0 -and $bytes[$i] -le 0xF7 -and $i + 3 -lt $bytes.Length -and $bytes[$i + 1] -ge 0x80 -and $bytes[$i + 1] -le 0xBF -and $bytes[$i + 2] -ge 0x80 -and $bytes[$i + 2] -le 0xBF -and $bytes[$i + 3] -ge 0x80 -and $bytes[$i + 3] -le 0xBF) {
                        $i += 4
                    } else {
                        $isUtf8 = $false
                        break
                    }
                } else {
                    $i++
                }
            }
            
            if ($isUtf8) {
                $encoding = "UTF-8 without BOM"
            } else {
                $encoding = "ANSI/Windows-1252 or other"
            }
        }
        
        return $encoding
    } catch {
        return "Error: $($_.Exception.Message)"
    }
}

# Fonction pour valider le JSON
function Test-JsonContent {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Json
    )
    
    try {
        $null = ConvertFrom-Json $Json
        return $true
    } catch {
        return $false
    }
}

# Créer une sauvegarde du fichier source
$backupFilePath = "$configFilePath.backup"
if (-not (Test-Path -Path $backupFilePath)) {
    try {
        Copy-Item -Path $configFilePath -Destination $backupFilePath -Force
        Write-ColorOutput "Sauvegarde du fichier source créée: $backupFilePath" "Green"
    } catch {
        Write-ColorOutput "Avertissement: Impossible de créer une sauvegarde du fichier source." "Yellow"
        Write-ColorOutput $_.Exception.Message "Yellow"
    }
}

# Copier le fichier avec encodage UTF-8 explicite
try {
    # Vérifier l'encodage du fichier source
    $sourceEncoding = Test-FileEncoding -Path $configFilePath
    Write-ColorOutput "Encodage du fichier source: $sourceEncoding" "Cyan"
    
    # Lire le contenu du fichier JSON avec encodage UTF-8
    $jsonContent = [System.IO.File]::ReadAllText($configFilePath, [System.Text.Encoding]::UTF8)
    
    if ($DebugMode) {
        Write-ColorOutput "Contenu brut du fichier source (premiers 500 caractères):" "Yellow"
        Write-ColorOutput $jsonContent.Substring(0, [Math]::Min(500, $jsonContent.Length)) "Yellow"
    }
    
    # Vérifier que le JSON est valide
    if (-not (Test-JsonContent -Json $jsonContent)) {
        Write-ColorOutput "Erreur: Le fichier JSON source n'est pas valide." "Red"
        Write-ColorOutput "Vérifiez le format du fichier et réessayez." "Red"
        exit 1
    }
    
    # Convertir le JSON en objet PowerShell
    $jsonObject = ConvertFrom-Json $jsonContent
    
    # Convertir l'objet PowerShell en JSON avec encodage UTF-8 et formatage préservé
    $jsonString = ConvertTo-Json $jsonObject -Depth 100 -Compress:$false
    
    # Écrire le contenu en UTF-8 sans BOM pour une meilleure compatibilité
    $utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($destinationFile, $jsonString, $utf8NoBomEncoding)
    
    Write-ColorOutput "Déploiement réussi!" "Green"
    
    # Vérifier l'encodage du fichier de destination
    $destEncoding = Test-FileEncoding -Path $destinationFile
    Write-ColorOutput "Encodage du fichier de destination: $destEncoding" "Cyan"
    
    # Vérifier que le JSON de destination est valide
    $destContent = [System.IO.File]::ReadAllText($destinationFile, [System.Text.Encoding]::UTF8)
    if (Test-JsonContent -Json $destContent) {
        Write-ColorOutput "Validation JSON: Le fichier de destination contient du JSON valide." "Green"
    } else {
        Write-ColorOutput "Avertissement: Le fichier de destination ne contient pas du JSON valide." "Red"
        Write-ColorOutput "Le déploiement a été effectué mais le fichier pourrait ne pas fonctionner correctement." "Red"
    }
} catch {
    Write-ColorOutput "Erreur lors du déploiement:" "Red"
    Write-ColorOutput $_.Exception.Message "Red"
    exit 1
}

# Exécuter les tests si demandé
if ($TestAfterDeploy) {
    Write-ColorOutput "`nExécution des tests après déploiement..." "Magenta"
    
    # Test du mécanisme d'escalade interne
    if (Test-Path -Path "$projectRoot/test-escalade-code.js") {
        Write-ColorOutput "Test du mécanisme d'escalade interne..." "Magenta"
        try {
            node "$projectRoot/test-escalade-code.js"
            Write-ColorOutput "Test d'escalade interne réussi!" "Green"
        } catch {
            Write-ColorOutput "Erreur lors du test d'escalade interne:" "Red"
            Write-ColorOutput $_.Exception.Message "Red"
        }
    } else {
        Write-ColorOutput "Fichier de test d'escalade interne non trouvé." "Yellow"
    }
    
    # Test du mécanisme de désescalade
    if (Test-Path -Path "$projectRoot/test-desescalade-code.js") {
        Write-ColorOutput "Test du mécanisme de désescalade..." "Magenta"
        try {
            node "$projectRoot/test-desescalade-code.js"
            Write-ColorOutput "Test de désescalade réussi!" "Green"
        } catch {
            Write-ColorOutput "Erreur lors du test de désescalade:" "Red"
            Write-ColorOutput $_.Exception.Message "Red"
        }
    } else {
        Write-ColorOutput "Fichier de test de désescalade non trouvé." "Yellow"
    }
}

# Résumé
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Déploiement des modes simples/complex terminé avec succès!" "Green"
Write-ColorOutput "=========================================================" "Cyan"

if ($DeploymentType -eq "global") {
    Write-ColorOutput "`nLes modes simples/complex ont été déployés globalement et seront disponibles dans toutes les instances de VS Code." "White"
} else {
    Write-ColorOutput "`nLes modes simples/complex ont été déployés localement et seront disponibles uniquement dans ce projet." "White"
}

Write-ColorOutput "`nPour activer les modes simples/complex:" "White"
Write-ColorOutput "1. Redémarrez Visual Studio Code" "White"
Write-ColorOutput "2. Ouvrez la palette de commandes (Ctrl+Shift+P)" "White"
Write-ColorOutput "3. Tapez 'Roo: Switch Mode' et sélectionnez un des modes suivants:" "White"
Write-ColorOutput "   - 💻 Code Simple" "White"
Write-ColorOutput "   - 💻 Code Complex" "White"
Write-ColorOutput "   - 🪲 Debug Simple" "White"
Write-ColorOutput "   - 🪲 Debug Complex" "White"
Write-ColorOutput "   - 🏗️ Architect Simple" "White"
Write-ColorOutput "   - 🏗️ Architect Complex" "White"
Write-ColorOutput "   - ❓ Ask Simple" "White"
Write-ColorOutput "   - ❓ Ask Complex" "White"
Write-ColorOutput "   - 🪃 Orchestrator Simple" "White"
Write-ColorOutput "   - 🪃 Orchestrator Complex" "White"
Write-ColorOutput "   - 👨‍💼 Manager" "White"
Write-ColorOutput "`n" "White"