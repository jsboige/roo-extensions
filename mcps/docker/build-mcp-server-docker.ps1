# Script de construction locale de l'image Docker MCP Server
# Ce script automatise le processus de construction locale de l'image Docker pour le MCP Server de ckreiling
# Il clone le dépôt, construit l'image, vérifie sa construction et met à jour la configuration MCP

# Fonction pour afficher les messages avec formatage
function Write-ColorOutput {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [string]$ForegroundColor = "White"
    )
    
    Write-Host $Message -ForegroundColor $ForegroundColor
}

# Fonction pour vérifier si une commande existe
function Test-CommandExists {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Command
    )
    
    $exists = $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
    return $exists
}

# Fonction pour vérifier les prérequis
function Test-Prerequisites {
    Write-ColorOutput "Vérification des prérequis..." "Cyan"
    
    # Vérifier si Docker est installé
    if (-not (Test-CommandExists "docker")) {
        Write-ColorOutput "Docker n'est pas installé ou n'est pas dans le PATH. Veuillez installer Docker avant de continuer." "Red"
        return $false
    }
    
    # Vérifier si Docker est en cours d'exécution
    try {
        $dockerInfo = docker info 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "Docker est installé mais ne semble pas être en cours d'exécution. Veuillez démarrer Docker avant de continuer." "Red"
            return $false
        }
    }
    catch {
        Write-ColorOutput "Erreur lors de la vérification de l'état de Docker: $_" "Red"
        return $false
    }
    
    # Vérifier si Git est installé
    if (-not (Test-CommandExists "git")) {
        Write-ColorOutput "Git n'est pas installé ou n'est pas dans le PATH. Veuillez installer Git avant de continuer." "Red"
        return $false
    }
    
    Write-ColorOutput "Tous les prérequis sont satisfaits." "Green"
    return $true
}

# Fonction pour cloner le dépôt GitHub
function Clone-Repository {
    param (
        [Parameter(Mandatory=$true)]
        [string]$RepoUrl,
        
        [Parameter(Mandatory=$true)]
        [string]$DestinationPath
    )
    
    Write-ColorOutput "Clonage du dépôt $RepoUrl vers $DestinationPath..." "Cyan"
    
    # Vérifier si le répertoire existe déjà
    if (Test-Path $DestinationPath) {
        Write-ColorOutput "Le répertoire $DestinationPath existe déjà." "Yellow"
        
        # Vérifier si c'est un dépôt Git
        if (Test-Path (Join-Path $DestinationPath ".git")) {
            Write-ColorOutput "Le répertoire est déjà un dépôt Git. Mise à jour..." "Yellow"
            
            # Se déplacer dans le répertoire et faire un pull
            Push-Location $DestinationPath
            git pull
            if ($LASTEXITCODE -ne 0) {
                Write-ColorOutput "Erreur lors de la mise à jour du dépôt." "Red"
                Pop-Location
                return $false
            }
            Pop-Location
            
            Write-ColorOutput "Dépôt mis à jour avec succès." "Green"
            return $true
        }
        else {
            Write-ColorOutput "Le répertoire existe mais n'est pas un dépôt Git. Suppression..." "Yellow"
            Remove-Item -Path $DestinationPath -Recurse -Force
        }
    }
    
    # Cloner le dépôt
    git clone $RepoUrl $DestinationPath
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "Erreur lors du clonage du dépôt." "Red"
        return $false
    }
    
    Write-ColorOutput "Dépôt cloné avec succès." "Green"
    return $true
}

# Fonction pour construire l'image Docker
function Build-DockerImage {
    param (
        [Parameter(Mandatory=$true)]
        [string]$DockerfilePath,
        
        [Parameter(Mandatory=$true)]
        [string]$ImageName,
        
        [Parameter(Mandatory=$true)]
        [string]$ImageTag
    )
    
    Write-ColorOutput "Construction de l'image Docker ${ImageName}:${ImageTag}..." "Cyan"
    
    # Se déplacer dans le répertoire contenant le Dockerfile
    Push-Location (Split-Path -Parent $DockerfilePath)
    
    # Construire l'image Docker
    docker build -t "${ImageName}:${ImageTag}" -f (Split-Path -Leaf $DockerfilePath) .
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "Erreur lors de la construction de l'image Docker." "Red"
        Pop-Location
        return $false
    }
    
    Pop-Location
    
    Write-ColorOutput "Image Docker construite avec succès." "Green"
    return $true
}

# Fonction pour vérifier que l'image Docker existe
function Test-DockerImage {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ImageName,
        
        [Parameter(Mandatory=$true)]
        [string]$ImageTag
    )
    
    Write-ColorOutput "Vérification de l'existence de l'image Docker ${ImageName}:${ImageTag}..." "Cyan"
    
    $image = docker images --format "{{.Repository}}:{{.Tag}}" | Where-Object { $_ -eq "${ImageName}:${ImageTag}" }
    
    if ($image) {
        Write-ColorOutput "L'image Docker ${ImageName}:${ImageTag} existe." "Green"
        return $true
    }
    else {
        Write-ColorOutput "L'image Docker ${ImageName}:${ImageTag} n'existe pas." "Red"
        return $false
    }
}

# Fonction pour mettre à jour la configuration MCP
function Update-McpConfig {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ConfigPath,
        
        [Parameter(Mandatory=$true)]
        [string]$ServerName,
        
        [Parameter(Mandatory=$true)]
        [string]$ImageName,
        
        [Parameter(Mandatory=$true)]
        [string]$ImageTag
    )
    
    Write-ColorOutput "Mise à jour de la configuration MCP dans $ConfigPath..." "Cyan"
    
    # Vérifier si le fichier de configuration existe
    if (-not (Test-Path $ConfigPath)) {
        Write-ColorOutput "Le fichier de configuration $ConfigPath n'existe pas." "Red"
        return $false
    }
    
    try {
        # Charger le fichier de configuration
        $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
        
        # Vérifier si la structure du fichier est correcte pour Roo (mcpServers au lieu de servers)
        if (-not $config.mcpServers) {
            $config | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue @() -Force
        }
        
        # Vérifier si le serveur existe déjà
        $serverExists = $false
        foreach ($server in $config.mcpServers) {
            if ($server.name -eq $ServerName) {
                $serverExists = $true
                
                # Mettre à jour la configuration du serveur
                $server.type = "stdio"
                $server.command = "docker"
                $server.args = @(
                    "run",
                    "-i",
                    "--rm",
                    "-v",
                    "/var/run/docker.sock:/var/run/docker.sock",
                    "${ImageName}:${ImageTag}"
                )
                $server.enabled = $true
                $server.autoStart = $true
                $server.description = "Serveur MCP local construit à partir de ${ImageName}:${ImageTag}"
                
                Write-ColorOutput "Configuration du serveur $ServerName mise à jour." "Green"
                break
            }
        }
        
        # Si le serveur n'existe pas, l'ajouter
        if (-not $serverExists) {
            $newServer = [PSCustomObject]@{
                name = $ServerName
                type = "stdio"
                command = "docker"
                args = @(
                    "run",
                    "-i",
                    "--rm",
                    "-v",
                    "/var/run/docker.sock:/var/run/docker.sock",
                    "${ImageName}:${ImageTag}"
                )
                enabled = $true
                autoStart = $true
                description = "Serveur MCP local construit à partir de ${ImageName}:${ImageTag}"
            }
            
            # Convertir le tableau JSON en ArrayList .NET
            $mcpServersList = [System.Collections.ArrayList]::new()
            if ($config.mcpServers) {
                foreach ($server in $config.mcpServers) {
                    [void]$mcpServersList.Add($server)
                }
            }
            [void]$mcpServersList.Add($newServer)
            $config.mcpServers = $mcpServersList
            Write-ColorOutput "Serveur $ServerName ajouté à la configuration." "Green"
        }
        
        # Sauvegarder la configuration
        $config | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath
        
        Write-ColorOutput "Configuration MCP mise à jour avec succès." "Green"
        return $true
    }
    catch {
        Write-ColorOutput "Erreur lors de la mise à jour de la configuration MCP: $_" "Red"
        return $false
    }
}

# Paramètres du script
$repoUrl = "https://github.com/ckreiling/mcp-server-docker.git"
$repoPath = Join-Path $env:TEMP "mcp-server-docker"
$imageName = "mcp-server"
$imageTag = "local"
$serverName = "mcp-server-local"

# Chemin vers le fichier de configuration MCP
# Modifier ce chemin selon votre installation de Roo
$mcpConfigPath = Join-Path $env:APPDATA "Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"

# Fonction principale
function Main {
    Write-ColorOutput "=== Construction locale de l'image Docker MCP Server ===" "Magenta"
    
    # Vérifier les prérequis
    if (-not (Test-Prerequisites)) {
        Write-ColorOutput "Les prérequis ne sont pas satisfaits. Arrêt du script." "Red"
        return
    }
    
    # Cloner le dépôt
    if (-not (Clone-Repository -RepoUrl $repoUrl -DestinationPath $repoPath)) {
        Write-ColorOutput "Échec du clonage du dépôt. Arrêt du script." "Red"
        return
    }
    
    # Trouver le Dockerfile
    $dockerfilePath = Join-Path $repoPath "Dockerfile"
    if (-not (Test-Path $dockerfilePath)) {
        Write-ColorOutput "Le Dockerfile n'a pas été trouvé dans le dépôt. Arrêt du script." "Red"
        return
    }
    
    # Construire l'image Docker
    if (-not (Build-DockerImage -DockerfilePath $dockerfilePath -ImageName $imageName -ImageTag $imageTag)) {
        Write-ColorOutput "Échec de la construction de l'image Docker. Arrêt du script." "Red"
        return
    }
    
    # Vérifier que l'image Docker existe
    if (-not (Test-DockerImage -ImageName $imageName -ImageTag $imageTag)) {
        Write-ColorOutput "L'image Docker n'a pas été trouvée après la construction. Arrêt du script." "Red"
        return
    }
    
    # Demander à l'utilisateur s'il souhaite mettre à jour la configuration MCP
    $updateConfig = Read-Host "Voulez-vous mettre à jour la configuration MCP pour utiliser cette image locale? (O/N)"
    if ($updateConfig -eq "O" -or $updateConfig -eq "o") {
        # Vérifier si le fichier de configuration existe
        if (-not (Test-Path $mcpConfigPath)) {
            # Demander à l'utilisateur de spécifier le chemin du fichier de configuration
            $mcpConfigPath = Read-Host "Le fichier de configuration MCP n'a pas été trouvé à l'emplacement par défaut. Veuillez spécifier le chemin complet du fichier servers.json"
            
            if (-not (Test-Path $mcpConfigPath)) {
                Write-ColorOutput "Le fichier de configuration spécifié n'existe pas. La configuration MCP ne sera pas mise à jour." "Red"
                return
            }
        }
        
        # Mettre à jour la configuration MCP
        if (-not (Update-McpConfig -ConfigPath $mcpConfigPath -ServerName $serverName -ImageName $imageName -ImageTag $imageTag)) {
            Write-ColorOutput "Échec de la mise à jour de la configuration MCP." "Red"
            return
        }
    }
    else {
        Write-ColorOutput "La configuration MCP n'a pas été mise à jour." "Yellow"
    }
    
    Write-ColorOutput "=== Construction locale de l'image Docker MCP Server terminée ===" "Magenta"
    Write-ColorOutput "Image Docker construite: ${imageName}:${imageTag}" "Green"
    Write-ColorOutput "Pour utiliser cette image manuellement, exécutez: docker run -i --rm -v /var/run/docker.sock:/var/run/docker.sock ${imageName}:${imageTag}" "Green"
}

# Exécuter la fonction principale
Main