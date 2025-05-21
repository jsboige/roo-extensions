#####################################################################
# Script de conversion du fichier de configuration MCP de Roo
# 
# Ce script convertit le fichier mcp_settings.json en conservant
# la structure "mcpServers" mais en effectuant les conversions
# nécessaires pour les serveurs individuels.
#
# Ancien format (conservé):
# "mcpServers": {
#   "quickfiles": {
#     "args": ["/c", "node", "d:\\jsboige-mcp-servers\\servers\\quickfiles-server\\build\\index.js"],
#     "alwaysAllow": ["read_multiple_files", "list_directory_contents"],
#     "command": "cmd",
#     "transportType": "stdio",
#     "disabled": false
#   }
# }
#####################################################################

# Paramètres du script
param (
    [string]$ConfigPath = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json",
    [string]$BackupSuffix = (Get-Date -Format "yyyyMMdd-HHmmss")
)

# Fonction pour afficher des messages colorés
function Write-ColorOutput {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$ForegroundColor = "White"
    )
    
    Write-Host $Message -ForegroundColor $ForegroundColor
}

# Afficher un message de bienvenue
Write-ColorOutput "`n=== Conversion du fichier de configuration MCP de Roo ===" -ForegroundColor "Magenta"
Write-ColorOutput "Ce script va convertir le fichier de configuration MCP en conservant la structure 'mcpServers'." -ForegroundColor "Cyan"
Write-ColorOutput "Fichier à convertir: $ConfigPath`n" -ForegroundColor "Cyan"

# Vérifier si le fichier de configuration existe
if (-not (Test-Path $ConfigPath)) {
    Write-ColorOutput "Erreur: Le fichier de configuration n'existe pas à l'emplacement: $ConfigPath" -ForegroundColor "Red"
    Write-ColorOutput "Vérifiez le chemin et réessayez." -ForegroundColor "Red"
    exit 1
}

# Créer une sauvegarde du fichier original
$BackupPath = "$ConfigPath.backup-$BackupSuffix"
try {
    Copy-Item -Path $ConfigPath -Destination $BackupPath -Force
    Write-ColorOutput "Sauvegarde créée: $BackupPath" -ForegroundColor "Green"
} catch {
    Write-ColorOutput "Erreur lors de la création de la sauvegarde: $_" -ForegroundColor "Red"
    exit 1
}

# Lire le contenu du fichier JSON
try {
    $jsonContent = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    Write-ColorOutput "Fichier de configuration chargé avec succès." -ForegroundColor "Green"
} catch {
    Write-ColorOutput "Erreur lors de la lecture du fichier JSON: $_" -ForegroundColor "Red"
    exit 1
}

# Créer une nouvelle structure pour le fichier JSON
$newConfig = @{}

# Si le fichier contient déjà la structure "mcpServers", l'utiliser comme base
if ($jsonContent.PSObject.Properties.Name -contains "mcpServers") {
    Write-ColorOutput "Structure 'mcpServers' détectée, utilisation comme base..." -ForegroundColor "Yellow"
    $newConfig.mcpServers = @{}
} else {
    # Si le fichier est au nouveau format, créer une structure "mcpServers" vide
    Write-ColorOutput "Structure 'mcpServers' non détectée, création d'une nouvelle structure..." -ForegroundColor "Yellow"
    $newConfig.mcpServers = @{}
}

# Fonction pour convertir un serveur si nécessaire
function Convert-ServerFormat {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ServerName,
        
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$ServerConfig
    )
    
    # Si le serveur est déjà au format attendu, le retourner tel quel
    if ($ServerConfig.PSObject.Properties.Name -contains "command" -and 
        $ServerConfig.PSObject.Properties.Name -contains "transportType") {
        Write-ColorOutput "Le serveur '$ServerName' est déjà au format attendu." -ForegroundColor "Cyan"
        return $ServerConfig
    }
    
    Write-ColorOutput "Conversion du serveur '$ServerName'..." -ForegroundColor "Yellow"
    
    # Créer une nouvelle configuration pour le serveur
    $newServer = @{}
    
    # Copier les propriétés existantes
    $ServerConfig.PSObject.Properties | ForEach-Object {
        $propertyName = $_.Name
        $propertyValue = $_.Value
        
        # Convertir les propriétés spécifiques
        if ($propertyName -eq "enabled") {
            $newServer.disabled = -not $propertyValue
        } elseif ($propertyName -eq "type") {
            $newServer.transportType = $propertyValue
        } elseif ($propertyName -eq "command" -and $ServerConfig.PSObject.Properties.Name -contains "type" -and $ServerConfig.type -eq "stdio") {
            # Décomposer la commande en command et args
            if ($propertyValue -match "^cmd /c (.+)$") {
                $newServer.command = "cmd"
                $newServer.args = @("/c") + ($Matches[1] -split " ")
            } else {
                $newServer.command = $propertyValue
            }
        } else {
            $newServer.$propertyName = $propertyValue
        }
    }
    
    return [PSCustomObject]$newServer
}

# Traiter les serveurs dans la structure "mcpServers" si elle existe
if ($jsonContent.PSObject.Properties.Name -contains "mcpServers") {
    $jsonContent.mcpServers.PSObject.Properties | ForEach-Object {
        $serverName = $_.Name
        $serverConfig = $_.Value
        
        $newConfig.mcpServers.$serverName = $serverConfig
        Write-ColorOutput "Serveur '$serverName' ajouté à la configuration." -ForegroundColor "Green"
    }
}

# Traiter les serveurs dans la structure "servers" si elle existe
if ($jsonContent.PSObject.Properties.Name -contains "servers") {
    foreach ($server in $jsonContent.servers) {
        if ($server.PSObject.Properties.Name -contains "name") {
            $serverName = $server.name
            $convertedServer = Convert-ServerFormat -ServerName $serverName -ServerConfig $server
            $newConfig.mcpServers.$serverName = $convertedServer
            Write-ColorOutput "Serveur '$serverName' converti et ajouté à la configuration." -ForegroundColor "Green"
        }
    }
}

# Convertir la nouvelle configuration en JSON
try {
    $newJsonContent = $newConfig | ConvertTo-Json -Depth 10
    Write-ColorOutput "Nouvelle configuration générée avec succès." -ForegroundColor "Green"
} catch {
    Write-ColorOutput "Erreur lors de la conversion en JSON: $_" -ForegroundColor "Red"
    exit 1
}

# Écrire la nouvelle configuration dans le fichier
try {
    [System.IO.File]::WriteAllText($ConfigPath, $newJsonContent, [System.Text.Encoding]::UTF8)
    Write-ColorOutput "Fichier de configuration mis à jour avec succès." -ForegroundColor "Green"
} catch {
    Write-ColorOutput "Erreur lors de l'écriture du fichier: $_" -ForegroundColor "Red"
    Write-ColorOutput "La sauvegarde est disponible à: $BackupPath" -ForegroundColor "Yellow"
    exit 1
}

# Afficher un résumé
Write-ColorOutput "`nRésumé de la conversion:" -ForegroundColor "Magenta"
Write-ColorOutput "- Sauvegarde créée: $BackupPath" -ForegroundColor "White"
Write-ColorOutput "- Fichier mis à jour: $ConfigPath" -ForegroundColor "White"

Write-ColorOutput "`nLa conversion est terminée. Redémarrez VS Code pour appliquer les changements." -ForegroundColor "Green"