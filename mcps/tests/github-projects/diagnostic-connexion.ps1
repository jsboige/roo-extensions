# Script de diagnostic pour les problèmes de connexion du MCP GitHub Projects
# Ce script vérifie la disponibilité du serveur, la validité du token GitHub, 
# la connectivité avec l'API GitHub et les ports utilisés

# Configuration
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Fonction pour afficher les messages de log
function Write-Log {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $colorMap = @{
        "INFO" = "White"
        "WARNING" = "Yellow"
        "ERROR" = "Red"
        "SUCCESS" = "Green"
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $colorMap[$Level]
}

# Fonction pour vérifier si un port est utilisé
function Test-PortInUse {
    param (
        [Parameter(Mandatory=$true)]
        [int]$Port
    )
    
    try {
        $connections = netstat -ano | Select-String ":$Port "
        if ($connections) {
            $processId = ($connections -split ' ')[-1]
            try {
                $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
                return @{
                    InUse = $true
                    ProcessId = $processId
                    ProcessName = if ($process) { $process.ProcessName } else { "Inconnu" }
                }
            } catch {
                return @{
                    InUse = $true
                    ProcessId = $processId
                    ProcessName = "Inconnu"
                }
            }
        } else {
            return @{
                InUse = $false
            }
        }
    } catch {
        Write-Log "Erreur lors de la vérification du port ${Port}: $_" -Level "ERROR"
        return @{
            InUse = $false
            Error = $_
        }
    }
}

# Fonction pour vérifier la validité du token GitHub
function Test-GitHubToken {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Token
    )
    
    try {
        $headers = @{
            "Authorization" = "token $Token"
            "Accept" = "application/vnd.github.v3+json"
        }
        
        $response = Invoke-RestMethod -Uri "https://api.github.com/user" -Headers $headers -Method Get
        
        return @{
            Valid = $true
            Username = $response.login
            Name = $response.name
        }
    } catch {
        return @{
            Valid = $false
            Error = $_
        }
    }
}

# Fonction pour vérifier la connectivité avec l'API GitHub
function Test-GitHubConnectivity {
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/zen" -Method Get
        
        return @{
            Connected = $true
            Message = $response
        }
    } catch {
        return @{
            Connected = $false
            Error = $_
        }
    }
}

# Fonction pour vérifier si le serveur MCP est en cours d'exécution
function Test-MCPServerRunning {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ServerPath,
        
        [Parameter(Mandatory=$true)]
        [int]$Port
    )
    
    # Vérifier si le répertoire du serveur existe
    if (-not (Test-Path $ServerPath)) {
        return @{
            Running = $false
            Error = "Le répertoire du serveur n'existe pas: $ServerPath"
        }
    }
    
    # Vérifier si le port est utilisé
    $portStatus = Test-PortInUse -Port $Port
    if ($portStatus.InUse) {
        # Vérifier si c'est un processus Node.js
        $process = Get-Process -Id $portStatus.ProcessId -ErrorAction SilentlyContinue
        if ($process -and $process.ProcessName -eq "node") {
            return @{
                Running = $true
                ProcessId = $portStatus.ProcessId
                ProcessName = $process.ProcessName
            }
        } else {
            return @{
                Running = $false
                Error = "Le port ${Port} est utilisé par un autre processus: $($portStatus.ProcessName) (PID: $($portStatus.ProcessId))"
            }
        }
    } else {
        return @{
            Running = $false
            Error = "Aucun processus n'écoute sur le port ${Port}"
        }
    }
}

# Fonction pour tester la connexion au serveur MCP
function Test-MCPServerConnection {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ServerHost,
        
        [Parameter(Mandatory=$true)]
        [int]$Port
    )
    
    try {
        $response = Invoke-RestMethod -Uri "http://${ServerHost}:${Port}/api/mcp/status" -Method Get -TimeoutSec 5
        
        return @{
            Connected = $true
            Status = $response.status
            Name = $response.name
            Version = $response.version
            Tools = $response.tools
            Resources = $response.resources
        }
    } catch {
        return @{
            Connected = $false
            Error = $_
        }
    }
}

# Fonction pour démarrer le serveur MCP
function Start-MCPServer {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ServerPath
    )
    
    try {
        # Vérifier si le répertoire du serveur existe
        if (-not (Test-Path $ServerPath)) {
            Write-Log "Le répertoire du serveur n'existe pas: $ServerPath" -Level "ERROR"
            return $false
        }
        
        # Vérifier si le fichier start-server.js existe
        $startServerPath = Join-Path $ServerPath "start-server.js"
        if (-not (Test-Path $startServerPath)) {
            Write-Log "Le fichier start-server.js n'existe pas: $startServerPath" -Level "ERROR"
            return $false
        }
        
        # Démarrer le serveur en arrière-plan
        Write-Log "Démarrage du serveur MCP GitHub Projects..." -Level "INFO"
        Start-Process -FilePath "node" -ArgumentList $startServerPath -WorkingDirectory $ServerPath -NoNewWindow
        
        # Attendre que le serveur démarre
        Write-Log "Attente du démarrage du serveur..." -Level "INFO"
        Start-Sleep -Seconds 5
        
        return $true
    } catch {
        Write-Log "Erreur lors du démarrage du serveur: $_" -Level "ERROR"
        return $false
    }
}

# Fonction pour corriger les problèmes courants
function Repair-MCPServer {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ServerPath,
        
        [Parameter(Mandatory=$true)]
        [int]$Port
    )
    
    $repaired = $false
    
    # Vérifier si le répertoire du serveur existe
    if (-not (Test-Path $ServerPath)) {
        Write-Log "Le répertoire du serveur n'existe pas: $ServerPath" -Level "ERROR"
        return $false
    }
    
    # Vérifier si le fichier .env existe et est correctement formaté
    $envPath = Join-Path $ServerPath ".env"
    if (-not (Test-Path $envPath)) {
        Write-Log "Le fichier .env n'existe pas. Création du fichier..." -Level "INFO"
        
        try {
            @"
# Configuration du serveur MCP GitHub Projects
MCP_PORT=${Port}
MCP_HOST=localhost
GITHUB_TOKEN=PLACEHOLDER_GITHUB_TOKEN
"@ | Out-File -FilePath $envPath -Encoding utf8
            
            $repaired = $true
            Write-Log "Fichier .env créé avec succès." -Level "SUCCESS"
        } catch {
            Write-Log "Impossible de créer le fichier .env: $_" -Level "ERROR"
        }
    } else {
        Write-Log "Vérification du contenu du fichier .env..." -Level "INFO"
        
        $envContent = Get-Content -Path $envPath -Raw
        $needsUpdate = $false
        
        # Vérifier si le port est correctement configuré
        if (-not ($envContent -match "MCP_PORT=${Port}")) {
            Write-Log "Le port n'est pas correctement configuré dans le fichier .env. Mise à jour..." -Level "INFO"
            $envContent = $envContent -replace "MCP_PORT=\d+", "MCP_PORT=${Port}"
            if (-not ($envContent -match "MCP_PORT=")) {
                $envContent += "`nMCP_PORT=${Port}"
            }
            $needsUpdate = $true
        }
        
        # Vérifier si le token GitHub est sur une seule ligne
        if ($envContent -match "GITHUB_TOKEN=.*\r?\n.*") {
            Write-Log "Le token GitHub est mal formaté dans le fichier .env. Correction..." -Level "INFO"
            $envContent = $envContent -replace "GITHUB_TOKEN=.*\r?\n.*", "GITHUB_TOKEN=PLACEHOLDER_GITHUB_TOKEN"
            $needsUpdate = $true
        }
        
        if ($needsUpdate) {
            try {
                $envContent | Out-File -FilePath $envPath -Encoding utf8
                $repaired = $true
                Write-Log "Fichier .env mis à jour avec succès." -Level "SUCCESS"
            } catch {
                Write-Log "Impossible de mettre à jour le fichier .env: $_" -Level "ERROR"
            }
        } else {
            Write-Log "Le fichier .env est correctement configuré." -Level "SUCCESS"
        }
    }
    
    # Vérifier si le fichier server.js est correctement configuré
    $serverJsPath = Join-Path $ServerPath "dist\server.js"
    if (Test-Path $serverJsPath) {
        $serverJsContent = Get-Content -Path $serverJsPath -Raw
        
        # Vérifier si la classe MCPServer convertit correctement les tableaux en objets
        if (-not ($serverJsContent -match "this\.tools\s*=\s*\{\}")) {
            Write-Log "Le fichier server.js n'est pas correctement configuré. Correction..." -Level "INFO"
            
            try {
                $updatedServerJs = $serverJsContent -replace "constructor\(options\)\s*\{[^}]*this\.tools\s*=\s*options\.tools;[^}]*this\.resources\s*=\s*options\.resources;[^}]*\}", @'
constructor(options) {
        this.name = options.name;
        this.description = options.description;
        this.version = options.version;
        
        // Convertir les tableaux d'outils et de ressources en objets indexés par leur nom
        this.tools = {};
        if (Array.isArray(options.tools)) {
            options.tools.forEach(tool => {
                this.tools[tool.name] = tool;
            });
        } else {
            this.tools = options.tools || {};
        }
        
        this.resources = {};
        if (Array.isArray(options.resources)) {
            options.resources.forEach(resource => {
                this.resources[resource.name] = resource;
            });
        } else {
            this.resources = options.resources || {};
        }
        
        this.app = (0, express_1.default)();
        this.setupMiddleware();
        this.setupRoutes();
    }
'@
                
                $updatedServerJs | Out-File -FilePath $serverJsPath -Encoding utf8
                $repaired = $true
                Write-Log "Fichier server.js mis à jour avec succès." -Level "SUCCESS"
            } catch {
                Write-Log "Impossible de mettre à jour le fichier server.js: $_" -Level "ERROR"
            }
        }
    }
    
    # Vérifier si le port est utilisé par un autre processus
    $portStatus = Test-PortInUse -Port $Port
    if ($portStatus.InUse) {
        Write-Log "Le port ${Port} est déjà utilisé par le processus $($portStatus.ProcessName) (PID: $($portStatus.ProcessId))" -Level "WARNING"
        
        $confirmation = Read-Host "Voulez-vous arrêter ce processus pour libérer le port ${Port}? (O/N)"
        if ($confirmation -eq "O" -or $confirmation -eq "o") {
            try {
                Stop-Process -Id $portStatus.ProcessId -Force
                Start-Sleep -Seconds 2
                Write-Log "Processus arrêté." -Level "SUCCESS"
                $repaired = $true
            } catch {
                Write-Log "Impossible d'arrêter le processus: $_" -Level "ERROR"
            }
        }
    }
    
    return $repaired
}

# Exécution des tests de diagnostic
Write-Log "Démarrage du diagnostic des problèmes de connexion du MCP GitHub Projects" -Level "INFO"
Write-Log "============================================================" -Level "INFO"

# Configuration
$serverPath = "D:\roo-extensions\mcps\mcp-servers\servers\github-projects-mcp"
$port = 3002
$serverHost = "localhost"

# Vérifier si le répertoire du serveur existe
Write-Log "Vérification du répertoire du serveur..." -Level "INFO"
if (Test-Path $serverPath) {
    Write-Log "Le répertoire du serveur existe: $serverPath" -Level "SUCCESS"
} else {
    Write-Log "Le répertoire du serveur n'existe pas: $serverPath" -Level "ERROR"
}

# Vérifier si le fichier .env existe
$envPath = Join-Path $serverPath ".env"
Write-Log "Vérification du fichier .env..." -Level "INFO"
if (Test-Path $envPath) {
    Write-Log "Le fichier .env existe: $envPath" -Level "SUCCESS"
    
    # Lire le contenu du fichier .env
    $envContent = Get-Content -Path $envPath -Raw
    
    # Extraire le token GitHub
    $tokenMatch = $envContent | Select-String -Pattern "GITHUB_TOKEN=([^\r\n]+)"
    if ($tokenMatch) {
        $token = $tokenMatch.Matches[0].Groups[1].Value
        Write-Log "Token GitHub trouvé dans le fichier .env" -Level "SUCCESS"
        
        # Vérifier la validité du token GitHub
        Write-Log "Vérification de la validité du token GitHub..." -Level "INFO"
        $tokenStatus = Test-GitHubToken -Token $token
        if ($tokenStatus.Valid) {
            Write-Log "Le token GitHub est valide. Utilisateur: $($tokenStatus.Username)" -Level "SUCCESS"
        } else {
            Write-Log "Le token GitHub n'est pas valide: $($tokenStatus.Error)" -Level "ERROR"
        }
    } else {
        Write-Log "Token GitHub non trouvé dans le fichier .env" -Level "ERROR"
    }
    
    # Extraire le port configuré
    $portMatch = $envContent | Select-String -Pattern "MCP_PORT=(\d+)"
    if ($portMatch) {
        $configuredPort = [int]$portMatch.Matches[0].Groups[1].Value
        Write-Log "Port configuré dans le fichier .env: $configuredPort" -Level "INFO"
        
        if ($configuredPort -ne $port) {
            Write-Log "Le port configuré ($configuredPort) ne correspond pas au port attendu ($port)" -Level "WARNING"
            $port = $configuredPort
        }
    } else {
        Write-Log "Port non configuré dans le fichier .env" -Level "WARNING"
    }
} else {
    Write-Log "Le fichier .env n'existe pas: $envPath" -Level "ERROR"
}

# Vérifier la connectivité avec l'API GitHub
Write-Log "Vérification de la connectivité avec l'API GitHub..." -Level "INFO"
$githubStatus = Test-GitHubConnectivity
if ($githubStatus.Connected) {
    Write-Log "Connexion à l'API GitHub établie avec succès" -Level "SUCCESS"
} else {
    Write-Log "Impossible de se connecter à l'API GitHub: $($githubStatus.Error)" -Level "ERROR"
}

# Vérifier si le serveur MCP est en cours d'exécution
Write-Log "Vérification si le serveur MCP est en cours d'exécution..." -Level "INFO"
$serverStatus = Test-MCPServerRunning -ServerPath $serverPath -Port $port
if ($serverStatus.Running) {
    Write-Log "Le serveur MCP est en cours d'exécution (PID: $($serverStatus.ProcessId))" -Level "SUCCESS"
} else {
    Write-Log "Le serveur MCP n'est pas en cours d'exécution: $($serverStatus.Error)" -Level "WARNING"
    
    # Tenter de démarrer le serveur
    $confirmation = Read-Host "Voulez-vous tenter de démarrer le serveur? (O/N)"
    if ($confirmation -eq "O" -or $confirmation -eq "o") {
        if (Start-MCPServer -ServerPath $serverPath) {
            Write-Log "Le serveur a été démarré avec succès" -Level "SUCCESS"
            
            # Vérifier à nouveau si le serveur est en cours d'exécution
            Start-Sleep -Seconds 2
            $serverStatus = Test-MCPServerRunning -ServerPath $serverPath -Port $port
            if ($serverStatus.Running) {
                Write-Log "Le serveur MCP est maintenant en cours d'exécution (PID: $($serverStatus.ProcessId))" -Level "SUCCESS"
            } else {
                Write-Log "Le serveur MCP n'a pas pu être démarré: $($serverStatus.Error)" -Level "ERROR"
            }
        } else {
            Write-Log "Impossible de démarrer le serveur" -Level "ERROR"
        }
    }
}

# Vérifier la connexion au serveur MCP
Write-Log "Vérification de la connexion au serveur MCP..." -Level "INFO"
$connectionStatus = Test-MCPServerConnection -ServerHost $serverHost -Port $port
if ($connectionStatus.Connected) {
    Write-Log "Connexion au serveur MCP établie avec succès" -Level "SUCCESS"
    Write-Log "Statut du serveur: $($connectionStatus.Status)" -Level "INFO"
    Write-Log "Nom du serveur: $($connectionStatus.Name)" -Level "INFO"
    Write-Log "Version du serveur: $($connectionStatus.Version)" -Level "INFO"
    
    if ($connectionStatus.Tools) {
        Write-Log "Outils disponibles:" -Level "INFO"
        $connectionStatus.Tools | ForEach-Object {
            Write-Host "- $_"
        }
    }
    
    if ($connectionStatus.Resources) {
        Write-Log "Ressources disponibles:" -Level "INFO"
        $connectionStatus.Resources | ForEach-Object {
            Write-Host "- $_"
        }
    }
} else {
    Write-Log "Impossible de se connecter au serveur MCP: $($connectionStatus.Error)" -Level "ERROR"
    
    # Tenter de réparer les problèmes courants
    $confirmation = Read-Host "Voulez-vous tenter de réparer les problèmes courants? (O/N)"
    if ($confirmation -eq "O" -or $confirmation -eq "o") {
        if (Repair-MCPServer -ServerPath $serverPath -Port $port) {
            Write-Log "Des problèmes ont été réparés. Tentative de redémarrage du serveur..." -Level "INFO"
            
            if (Start-MCPServer -ServerPath $serverPath) {
                Write-Log "Le serveur a été redémarré avec succès" -Level "SUCCESS"
                
                # Vérifier à nouveau la connexion
                Start-Sleep -Seconds 5
                $connectionStatus = Test-MCPServerConnection -ServerHost $serverHost -Port $port
                if ($connectionStatus.Connected) {
                    Write-Log "Connexion au serveur MCP établie avec succès après réparation" -Level "SUCCESS"
                } else {
                    Write-Log "Impossible de se connecter au serveur MCP après réparation: $($connectionStatus.Error)" -Level "ERROR"
                }
            } else {
                Write-Log "Impossible de redémarrer le serveur après réparation" -Level "ERROR"
            }
        } else {
            Write-Log "Aucun problème n'a pu être réparé" -Level "WARNING"
        }
    }
}

# Vérifier les ports utilisés
Write-Log "Vérification des ports utilisés..." -Level "INFO"
$portsToCheck = @(3000, 3001, 3002, 3003, 3004, 3005)
foreach ($p in $portsToCheck) {
    $portStatus = Test-PortInUse -Port $p
    if ($portStatus.InUse) {
        Write-Log "Port ${p}: Utilisé par $($portStatus.ProcessName) (PID: $($portStatus.ProcessId))" -Level "INFO"
    } else {
        Write-Log "Port ${p}: Disponible" -Level "INFO"
    }
}

# Générer un rapport de diagnostic
$reportPath = Join-Path (Get-Location) "resultats-correction-connexion.md"
$reportContent = @"
# Rapport de diagnostic des problèmes de connexion du MCP GitHub Projects

Date d'exécution: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Configuration testée

- Répertoire du serveur: $serverPath
- Port: $port
- Hôte: $serverHost

## Résultats du diagnostic

### Vérification du répertoire du serveur
- Répertoire du serveur: $(if (Test-Path $serverPath) { "Existe" } else { "N'existe pas" })

### Vérification du fichier .env
- Fichier .env: $(if (Test-Path $envPath) { "Existe" } else { "N'existe pas" })
$(if (Test-Path $envPath) {
    $envContent = Get-Content -Path $envPath -Raw
    $tokenMatch = $envContent | Select-String -Pattern "GITHUB_TOKEN=([^\r\n]+)"
    $portMatch = $envContent | Select-String -Pattern "MCP_PORT=(\d+)"
    
    $result = ""
    if ($tokenMatch) {
        $token = $tokenMatch.Matches[0].Groups[1].Value
        $tokenStatus = Test-GitHubToken -Token $token
        $result += "- Token GitHub: " + $(if ($tokenStatus.Valid) { "Valide (Utilisateur: $($tokenStatus.Username))" } else { "Non valide" })
    } else {
        $result += "- Token GitHub: Non trouvé"
    }
    
    $result += "`n"
    
    if ($portMatch) {
        $configuredPort = [int]$portMatch.Matches[0].Groups[1].Value
        $result += "- Port configuré: $configuredPort"
    } else {
        $result += "- Port configuré: Non trouvé"
    }
    
    $result
})

### Vérification de la connectivité avec l'API GitHub
- Connectivité avec l'API GitHub: $(if ($githubStatus.Connected) { "Établie" } else { "Non établie" })

### Vérification du serveur MCP
- Serveur MCP en cours d'exécution: $(if ($serverStatus.Running) { "Oui (PID: $($serverStatus.ProcessId))" } else { "Non" })
- Connexion au serveur MCP: $(if ($connectionStatus.Connected) { "Établie" } else { "Non établie" })
$(if ($connectionStatus.Connected) {
    "- Statut du serveur: $($connectionStatus.Status)
- Nom du serveur: $($connectionStatus.Name)
- Version du serveur: $($connectionStatus.Version)"
})

### Vérification des ports
$(foreach ($p in $portsToCheck) {
    $portStatus = Test-PortInUse -Port $p
    if ($portStatus.InUse) {
        "- Port ${p}: Utilisé par $($portStatus.ProcessName) (PID: $($portStatus.ProcessId))"
    } else {
        "- Port ${p}: Disponible"
    }
})

## Problèmes identifiés

$(if (-not (Test-Path $serverPath)) {
    "- Le répertoire du serveur n'existe pas"
})
$(if (-not (Test-Path $envPath)) {
    "- Le fichier .env n'existe pas"
})
$(if ((Test-Path $envPath) -and -not ($envContent -match "GITHUB_TOKEN=")) {
    "- Token GitHub non trouvé dans le fichier .env"
})
$(if ((Test-Path $envPath) -and ($tokenMatch) -and -not ($tokenStatus.Valid)) {
    "- Le token GitHub n'est pas valide"
})
$(if (-not ($githubStatus.Connected)) {
    "- Impossible de se connecter à l'API GitHub"
})
$(if (-not ($serverStatus.Running)) {
    "- Le serveur MCP n'est pas en cours d'exécution"
})
$(if (-not ($connectionStatus.Connected)) {
    "- Impossible de se connecter au serveur MCP"
})
$(if ($portStatus.InUse -and $portStatus.ProcessName -ne "node") {
    "- Le port $port est utilisé par un autre processus ($($portStatus.ProcessName))"
})

## Recommandations

$(if (-not (Test-Path $serverPath)) {
    "- Créer le répertoire du serveur: $serverPath"
})
$(if (-not (Test-Path $envPath)) {
    "- Créer le fichier .env avec la configuration appropriée"
})
$(if ((Test-Path $envPath) -and -not ($envContent -match "GITHUB_TOKEN=")) {
    "- Ajouter un token GitHub valide dans le fichier .env"
})
$(if ((Test-Path $envPath) -and ($tokenMatch) -and -not ($tokenStatus.Valid)) {
    "- Générer un nouveau token GitHub et le mettre à jour dans le fichier .env"
})
$(if (-not ($githubStatus.Connected)) {
    "- Vérifier la connexion Internet et les paramètres de proxy"
})
$(if (-not ($serverStatus.Running)) {
    "- Démarrer le serveur MCP avec la commande: node start-server.js"
})
$(if (-not ($connectionStatus.Connected)) {
    "- Vérifier que le serveur MCP est correctement configuré et en cours d'exécution"
})
$(if ($portStatus.InUse -and $portStatus.ProcessName -ne "node") {
    "- Libérer le port $port en arrêtant le processus $($portStatus.ProcessName) (PID: $($portStatus.ProcessId))"
})

## Conclusion

Ce rapport de diagnostic a identifié les problèmes de connexion du MCP GitHub Projects et propose des recommandations pour les résoudre. Suivez les recommandations ci-dessus pour rétablir la connexion au serveur MCP.
"@

$reportContent | Out-File -FilePath $reportPath -Encoding utf8
Write-Log "Rapport de diagnostic généré: $reportPath" -Level "SUCCESS"

Write-Log "============================================================" -Level "INFO"
Write-Log "Diagnostic terminé" -Level "INFO"