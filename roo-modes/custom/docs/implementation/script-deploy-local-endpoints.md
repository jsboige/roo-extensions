# Script de déploiement pour les endpoints locaux

Ce document contient le script PowerShell pour déployer les modes personnalisés Roo sur une machine avec des endpoints locaux "micro", "mini" et "medium".

## Instructions d'utilisation

1. Copiez le contenu du script ci-dessous
2. Créez un fichier `deploy-local-endpoints.ps1` dans le répertoire `roo-modes/custom/scripts/`
3. Collez le contenu dans ce fichier
4. Exécutez le script depuis PowerShell

## Script PowerShell

```powershell
# Script de déploiement des modes personnalisés Roo pour endpoints locaux
# Ce script adapte le fichier .roomodes pour utiliser des endpoints locaux
# "micro", "mini" et "medium", puis le déploie.

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

# Fonction pour vérifier si un chemin existe et le créer si nécessaire
function Ensure-PathExists {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    if (-not (Test-Path -Path $Path)) {
        try {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
            Write-ColorOutput "Répertoire créé: $Path" "Green"
        }
        catch {
            Write-ColorOutput "Erreur lors de la création du répertoire: $Path" "Red"
            Write-ColorOutput $_.Exception.Message "Red"
            exit 1
        }
    }
}

# Bannière
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Déploiement des modes personnalisés Roo pour endpoints locaux" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"

# Vérifier que le fichier .roomodes-local existe
$sourceFile = Join-Path -Path $PSScriptRoot -ChildPath "..\..\..\.roomodes-local"
$sourceFile = Resolve-Path $sourceFile -ErrorAction SilentlyContinue

if (-not $sourceFile) {
    Write-ColorOutput "Fichier .roomodes-local non trouvé. Création à partir du fichier .roomodes..." "Yellow"
    
    $originalFile = Join-Path -Path $PSScriptRoot -ChildPath "..\..\..\.roomodes"
    $originalFile = Resolve-Path $originalFile -ErrorAction SilentlyContinue
    
    if (-not $originalFile) {
        Write-ColorOutput "Erreur: Le fichier .roomodes n'a pas été trouvé." "Red"
        Write-ColorOutput "Assurez-vous d'exécuter ce script depuis le répertoire du projet." "Red"
        exit 1
    }
    
    # Lire le contenu du fichier .roomodes
    $content = Get-Content $originalFile -Raw | ConvertFrom-Json
    
    # Modifier les modèles pour utiliser les endpoints locaux
    foreach ($mode in $content.customModes) {
        if ($mode.slug -like "*-simple") {
            if ($mode.slug -like "orchestrator-*" -or $mode.slug -like "architect-*") {
                $mode.model = "local/mini"
            } else {
                $mode.model = "local/micro"
            }
        } else {
            $mode.model = "local/medium"
        }
    }
    
    # Écrire le contenu modifié dans le fichier .roomodes-local
    $content | ConvertTo-Json -Depth 10 | Set-Content (Join-Path -Path (Split-Path $originalFile) -ChildPath ".roomodes-local")
    $sourceFile = Join-Path -Path (Split-Path $originalFile) -ChildPath ".roomodes-local"
    
    Write-ColorOutput "Fichier .roomodes-local créé avec succès." "Green"
}

# Déterminer le chemin du fichier de destination
$destinationDir = Join-Path -Path $env:APPDATA -ChildPath "Code\User\globalStorage\rooveterinaryinc.roo-cline\settings"
$destinationFile = Join-Path -Path $destinationDir -ChildPath "custom_modes.json"

# Vérifier que le répertoire de destination existe
Ensure-PathExists -Path $destinationDir

Write-ColorOutput "`n[1/3] Copie du fichier .roomodes-local vers $destinationFile" "Yellow"

# Copier le fichier
try {
    Copy-Item -Path $sourceFile -Destination $destinationFile -Force
    Write-ColorOutput "Copie réussie!" "Green"
}
catch {
    Write-ColorOutput "Erreur lors de la copie du fichier:" "Red"
    Write-ColorOutput $_.Exception.Message "Red"
    exit 1
}

# Vérifier que les fichiers sont identiques
Write-ColorOutput "`n[2/3] Vérification de l'installation..." "Yellow"

try {
    $diff = Compare-Object -ReferenceObject (Get-Content $sourceFile) -DifferenceObject (Get-Content $destinationFile)
    
    if ($null -eq $diff) {
        Write-ColorOutput "Vérification réussie: Les fichiers sont identiques." "Green"
    }
    else {
        Write-ColorOutput "Avertissement: Les fichiers ne sont pas identiques." "Yellow"
        Write-ColorOutput "Différences trouvées:" "Yellow"
        $diff | Format-Table -AutoSize
        exit 1
    }
}
catch {
    Write-ColorOutput "Erreur lors de la vérification des fichiers:" "Red"
    Write-ColorOutput $_.Exception.Message "Red"
    exit 1
}

# Vérifier que le fichier JSON est valide
Write-ColorOutput "`n[3/3] Validation du format JSON..." "Yellow"

try {
    $json = Get-Content $destinationFile -Raw | ConvertFrom-Json
    $modesCount = $json.customModes.Count
    
    Write-ColorOutput "Validation réussie: Le fichier JSON est valide." "Green"
    Write-ColorOutput "Nombre de modes personnalisés trouvés: $modesCount" "Green"
    
    # Afficher les modes trouvés et leurs modèles associés
    Write-ColorOutput "`nModes personnalisés installés:" "Cyan"
    foreach ($mode in $json.customModes) {
        Write-ColorOutput "- $($mode.name) ($($mode.slug)) -> $($mode.model)" "White"
    }
}
catch {
    Write-ColorOutput "Erreur: Le fichier JSON n'est pas valide." "Red"
    Write-ColorOutput $_.Exception.Message "Red"
    exit 1
}

# Vérifier si les endpoints sont accessibles
Write-ColorOutput "`nVérification de l'accessibilité des endpoints..." "Yellow"

$endpoints = @(
    "http://localhost:8001/v1/health",
    "http://localhost:8002/v1/health",
    "http://localhost:8003/v1/health"
)

foreach ($endpoint in $endpoints) {
    try {
        $response = Invoke-RestMethod -Uri $endpoint -Method Get -TimeoutSec 5 -ErrorAction SilentlyContinue
        Write-ColorOutput "Endpoint $endpoint est accessible." "Green"
    }
    catch {
        Write-ColorOutput "Avertissement: Endpoint $endpoint n'est pas accessible." "Yellow"
        Write-ColorOutput "Assurez-vous que les serveurs des modèles locaux sont en cours d'exécution." "Yellow"
    }
}

# Résumé
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Installation terminée avec succès!" "Green"
Write-ColorOutput "=========================================================" "Cyan"
Write-ColorOutput "`nPour activer les modes personnalisés:" "White"
Write-ColorOutput "1. Redémarrez Visual Studio Code" "White"
Write-ColorOutput "2. Ouvrez la palette de commandes (Ctrl+Shift+P)" "White"
Write-ColorOutput "3. Tapez 'Roo: Switch Mode' et sélectionnez un mode personnalisé" "White"
Write-ColorOutput "`nPour plus d'informations, consultez:" "White"
Write-ColorOutput "roo-modes/custom/docs/implementation/deploiement-autres-machines.md" "White"
Write-ColorOutput "`n" "White"
```

## Extraction du script

Pour extraire ce script et le sauvegarder dans un fichier PowerShell, vous pouvez utiliser la commande suivante :

```powershell
$scriptContent = Get-Content -Path "roo-modes/custom/docs/implementation/script-deploy-local-endpoints.md" -Raw
$scriptContent -match '```powershell([\s\S]*?)```' | Out-Null
$script = $matches[1].Trim()
Set-Content -Path "roo-modes/custom/scripts/deploy-local-endpoints.ps1" -Value $script
```

Cette commande extrait le contenu du script PowerShell de ce document Markdown et le sauvegarde dans le fichier `deploy-local-endpoints.ps1`.