#####################################################################
# Script de conversion du fichier de configuration MCP de Roo
# 
# Ce script convertit le fichier mcp_settings.json de l'ancien format
# vers le nouveau format compatible avec la dernière version de Roo.
#
# Ancien format:
# "quickfiles": {
#     "args": ["/c", "node", "d:\\jsboige-mcp-servers\\servers\\quickfiles-server\\build\\index.js"],
#     "alwaysAllow": ["read_multiple_files", "list_directory_contents"],
#     "command": "cmd",
#     "transportType": "stdio",
#     "disabled": false
# }
#
# Nouveau format:
# {
#     "name": "quickfiles",
#     "type": "stdio",
#     "command": "cmd /c node d:\\jsboige-mcp-servers\\servers\\quickfiles-server\\build\\index.js",
#     "enabled": true,
#     "autoStart": true,
#     "description": "Serveur MCP pour manipuler rapidement plusieurs fichiers"
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
Write-ColorOutput "Ce script va convertir le fichier de configuration MCP de l'ancien format vers le nouveau format." -ForegroundColor "Cyan"
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
$newConfig = @{
    version = 1
    servers = @()
    settings = @{}
}

# Si le fichier contient déjà la nouvelle structure, l'utiliser comme base
if ($jsonContent.PSObject.Properties.Name -contains "version" -and 
    $jsonContent.PSObject.Properties.Name -contains "servers") {
    Write-ColorOutput "Structure de nouvelle version détectée, utilisation comme base..." -ForegroundColor "Yellow"
    $newConfig.version = $jsonContent.version
    $newConfig.servers = @()  # On va reconstruire la liste des serveurs
    
    if ($jsonContent.PSObject.Properties.Name -contains "settings") {
        $newConfig.settings = $jsonContent.settings
    }
}

# Fonction pour convertir un serveur de l'ancien format au nouveau format
function Convert-ServerFormat {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ServerName,
        
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$ServerConfig
    )
    
    # Déterminer si le serveur est déjà au nouveau format
    $isNewFormat = $ServerConfig.PSObject.Properties.Name -contains "name" -and 
                   $ServerConfig.PSObject.Properties.Name -contains "enabled"
    
    if ($isNewFormat) {
        Write-ColorOutput "Le serveur '$ServerName' est déjà au nouveau format." -ForegroundColor "Cyan"
        return $ServerConfig
    }
    
    Write-ColorOutput "Conversion du serveur '$ServerName' vers le nouveau format..." -ForegroundColor "Yellow"
    
    # Déterminer le type de transport
    $type = "stdio"
    if ($ServerConfig.PSObject.Properties.Name -contains "transportType") {
        $type = $ServerConfig.transportType
    }
    
    # Construire la commande complète
    $command = $ServerConfig.command
    if ($ServerConfig.PSObject.Properties.Name -contains "args" -and $ServerConfig.args -ne $null) {
        if ($command -eq "cmd") {
            # Pour cmd, on utilise /c et on ajoute les arguments
            $argsString = $ServerConfig.args -join " "
            $command = "cmd $argsString"
        } else {
            # Pour les autres commandes, on ajoute simplement les arguments
            $argsString = $ServerConfig.args -join " "
            $command = "$command $argsString"
        }
    }
    
    # Déterminer si le serveur est activé
    $enabled = $true
    if ($ServerConfig.PSObject.Properties.Name -contains "disabled") {
        $enabled = -not $ServerConfig.disabled
    }
    
    # Créer la nouvelle configuration du serveur
    $newServer = @{
        name = $ServerName
        type = $type
        command = $command
        enabled = $enabled
        autoStart = $enabled  # Par défaut, autoStart est identique à enabled
    }
    
    # Ajouter une description si possible
    $description = "Serveur MCP $ServerName"
    if ($ServerConfig.PSObject.Properties.Name -contains "description") {
        $description = $ServerConfig.description
    }
    $newServer.description = $description
    
    # Conserver les propriétés alwaysAllow si elles existent
    if ($ServerConfig.PSObject.Properties.Name -contains "alwaysAllow") {
        $newServer.alwaysAllow = $ServerConfig.alwaysAllow
    }
    
    # Conserver les propriétés env si elles existent
    if ($ServerConfig.PSObject.Properties.Name -contains "env") {
        $newServer.env = $ServerConfig.env
    }
    
    return [PSCustomObject]$newServer
}

# Parcourir tous les serveurs dans le fichier JSON
$serverCount = 0
$convertedCount = 0

# Traiter d'abord les serveurs dans la section "servers" si elle existe
if ($jsonContent.PSObject.Properties.Name -contains "servers" -and $jsonContent.servers -ne $null) {
    foreach ($server in $jsonContent.servers) {
        $serverCount++
        if ($server.PSObject.Properties.Name -contains "name") {
            $newConfig.servers += $server
            Write-ColorOutput "Serveur '$($server.name)' déjà au nouveau format, ajouté sans modification." -ForegroundColor "Cyan"
        }
    }
}

# Traiter ensuite les serveurs dans la structure "mcpServers" si elle existe
if ($jsonContent.PSObject.Properties.Name -contains "mcpServers" -and $jsonContent.mcpServers -ne $null) {
    Write-ColorOutput "Structure 'mcpServers' détectée, conversion des serveurs..." -ForegroundColor "Yellow"
    $jsonContent.mcpServers.PSObject.Properties | ForEach-Object {
        $serverName = $_.Name
        $serverConfig = $_.Value
        
        $serverCount++
        $convertedServer = Convert-ServerFormat -ServerName $serverName -ServerConfig $serverConfig
        $newConfig.servers += $convertedServer
        $convertedCount++
        Write-ColorOutput "Serveur '$serverName' converti avec succès." -ForegroundColor "Green"
    }
}

# Traiter ensuite les serveurs dans le format ancien (clés au premier niveau)
$jsonContent.PSObject.Properties | ForEach-Object {
    $propertyName = $_.Name
    $propertyValue = $_.Value
    
    # Ignorer les propriétés qui ne sont pas des serveurs
    if ($propertyName -in @("version", "servers", "settings", "mcpServers")) {
        return
    }
    
    # Vérifier si c'est un objet qui ressemble à un serveur
    if ($propertyValue -is [PSCustomObject] -and 
        ($propertyValue.PSObject.Properties.Name -contains "command" -or 
         $propertyValue.PSObject.Properties.Name -contains "transportType")) {
        
        $serverCount++
        $convertedServer = Convert-ServerFormat -ServerName $propertyName -ServerConfig $propertyValue
        $newConfig.servers += $convertedServer
        $convertedCount++
        Write-ColorOutput "Serveur '$propertyName' converti avec succès." -ForegroundColor "Green"
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
    $newJsonContent | Out-File -FilePath $ConfigPath -Force
    Write-ColorOutput "Fichier de configuration mis à jour avec succès." -ForegroundColor "Green"
} catch {
    Write-ColorOutput "Erreur lors de l'écriture du fichier: $_" -ForegroundColor "Red"
    Write-ColorOutput "La sauvegarde est disponible à: $BackupPath" -ForegroundColor "Yellow"
    exit 1
}

# Afficher un résumé
Write-ColorOutput "`nRésumé de la conversion:" -ForegroundColor "Magenta"
Write-ColorOutput "- Nombre total de serveurs traités: $serverCount" -ForegroundColor "White"
Write-ColorOutput "- Nombre de serveurs convertis: $convertedCount" -ForegroundColor "White"
Write-ColorOutput "- Sauvegarde créée: $BackupPath" -ForegroundColor "White"
Write-ColorOutput "- Fichier mis à jour: $ConfigPath" -ForegroundColor "White"

Write-ColorOutput "`nLa conversion est terminée. Redémarrez VS Code pour appliquer les changements." -ForegroundColor "Green"