# Script de test simplifié pour le MCP GitHub Projects
# Ce script utilise directement PowerShell pour tester les fonctionnalités du MCP GitHub Projects

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

# Fonction pour vérifier la configuration du MCP GitHub Projects
function Test-MCPGitHubProjectsConfig {
    Write-Log "Vérification de la configuration du MCP GitHub Projects" -Level "INFO"
    
    $configPath = "C:\Users\MYIA\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"
    
    if (Test-Path $configPath) {
        $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
        
        if ($config.mcpServers.'github-projects') {
            $serverConfig = $config.mcpServers.'github-projects'
            
            Write-Log "Configuration du MCP GitHub Projects trouvée" -Level "SUCCESS"
            Write-Log "Commande: $($serverConfig.command) $($serverConfig.args -join ' ')" -Level "INFO"
            
            if ($serverConfig.disabled) {
                Write-Log "Le serveur MCP GitHub Projects est désactivé dans la configuration" -Level "ERROR"
                return $false
            }
            
            if ($serverConfig.env.GITHUB_TOKEN) {
                Write-Log "Token GitHub configuré: $($serverConfig.env.GITHUB_TOKEN.Substring(0, 5))..." -Level "SUCCESS"
            } else {
                Write-Log "Aucun token GitHub configuré" -Level "WARNING"
            }
            
            Write-Log "Fonctionnalités autorisées: $($serverConfig.alwaysAllow -join ', ')" -Level "INFO"
            
            return $true
        } else {
            Write-Log "Configuration du MCP GitHub Projects non trouvée dans le fichier" -Level "ERROR"
            return $false
        }
    } else {
        Write-Log "Fichier de configuration non trouvé: $configPath" -Level "ERROR"
        return $false
    }
}

# Fonction pour vérifier si le serveur MCP GitHub Projects est en cours d'exécution
function Test-MCPGitHubProjectsServer {
    Write-Log "Vérification du serveur MCP GitHub Projects" -Level "INFO"
    
    # Vérifier si le processus est en cours d'exécution
    $processes = Get-Process | Where-Object { $_.ProcessName -like "*github*" -or $_.ProcessName -like "*mcp*" }
    
    if ($processes) {
        Write-Log "Processus potentiellement liés au MCP GitHub Projects:" -Level "INFO"
        $processes | ForEach-Object {
            Write-Log "- $($_.ProcessName) (PID: $($_.Id))" -Level "INFO"
        }
    } else {
        Write-Log "Aucun processus lié au MCP GitHub Projects trouvé" -Level "WARNING"
    }
    
    # Vérifier si le port est en écoute
    $netstat = netstat -ano | Select-String -Pattern "LISTENING" | Select-String -Pattern "3002"
    
    if ($netstat) {
        Write-Log "Port 3002 en écoute:" -Level "SUCCESS"
        $netstat | ForEach-Object {
            Write-Log "- $_" -Level "INFO"
        }
        return $true
    } else {
        Write-Log "Port 3002 non trouvé en écoute" -Level "WARNING"
        return $false
    }
}

# Fonction pour tester la commande MCP CLI
function Test-MCPCli {
    Write-Log "Test de la commande MCP CLI" -Level "INFO"
    
    $mcpCliPath = 'C:\Users\MYIA\AppData\Local\Programs\Roo\resources\app\out\mcp-cli\mcp-cli.exe'
    
    if (Test-Path $mcpCliPath) {
        Write-Log "MCP CLI trouvé: $mcpCliPath" -Level "SUCCESS"
        
        try {
            $output = & $mcpCliPath --version
            Write-Log "Version du MCP CLI: $output" -Level "INFO"
            
            $output = & $mcpCliPath list-servers
            Write-Log "Serveurs MCP disponibles:" -Level "INFO"
            $output | ForEach-Object {
                Write-Log "- $_" -Level "INFO"
            }
            
            return $true
        } catch {
            Write-Log "Erreur lors de l'exécution du MCP CLI: $_" -Level "ERROR"
            return $false
        }
    } else {
        Write-Log "MCP CLI non trouvé: $mcpCliPath" -Level "ERROR"
        
        # Rechercher le MCP CLI dans d'autres emplacements
        $possiblePaths = @(
            "C:\Program Files\Roo\resources\app\out\mcp-cli\mcp-cli.exe",
            "C:\Program Files (x86)\Roo\resources\app\out\mcp-cli\mcp-cli.exe",
            "$env:LOCALAPPDATA\Roo\app-*\resources\app\out\mcp-cli\mcp-cli.exe"
        )
        
        foreach ($path in $possiblePaths) {
            $resolvedPaths = Resolve-Path -Path $path -ErrorAction SilentlyContinue
            
            if ($resolvedPaths) {
                foreach ($resolvedPath in $resolvedPaths) {
                    Write-Log "MCP CLI trouvé dans un emplacement alternatif: $($resolvedPath.Path)" -Level "SUCCESS"
                    return $true
                }
            }
        }
        
        return $false
    }
}

# Fonction pour tester le serveur MCP GitHub Projects directement
function Test-MCPGitHubProjectsServerDirect {
    Write-Log "Test direct du serveur MCP GitHub Projects" -Level "INFO"
    
    try {
        $response = Invoke-RestMethod -Method Get -Uri "http://localhost:3002/api/mcp/status" -ErrorAction SilentlyContinue
        
        if ($response) {
            Write-Log "Serveur MCP en cours d'exécution sur http://localhost:3002" -Level "SUCCESS"
            Write-Log "Réponse du serveur: $($response | ConvertTo-Json -Depth 1)" -Level "INFO"
            return $true
        } else {
            Write-Log "Aucune réponse du serveur MCP" -Level "WARNING"
            return $false
        }
    } catch {
        Write-Log "Erreur lors de la connexion au serveur MCP: $_" -Level "ERROR"
        return $false
    }
}

# Fonction pour tester la liste des projets
function Test-ListProjects {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Owner,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("USER", "ORGANIZATION")]
        [string]$OwnerType = "USER"
    )
    
    Write-Log "Test de la fonctionnalité 'list_projects' pour $OwnerType '$Owner'" -Level "INFO"
    
    try {
        # Créer un fichier temporaire pour la requête
        $tempDir = Join-Path $env:TEMP "mcp-tests"
        if (-not (Test-Path $tempDir)) {
            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        }
        
        $requestFile = Join-Path $tempDir "list-projects-request.json"
        
        # Créer la requête JSON
        $request = @{
            server_name = "github-projects"
            tool_name = "list_projects"
            arguments = @{
                owner = $Owner
                owner_type = $OwnerType
            }
        }
        
        $request | ConvertTo-Json -Depth 10 | Out-File -FilePath $requestFile -Encoding utf8
        
        Write-Log "Requête JSON créée: $requestFile" -Level "INFO"
        Get-Content -Path $requestFile | ForEach-Object { Write-Log "- $_" -Level "INFO" }
        
        # Tester avec curl
        Write-Log "Test avec curl..." -Level "INFO"
        
        try {
            $curlCommand = "curl -s -X POST -H 'Content-Type: application/json' -d '@$requestFile' http://localhost:3002/api/mcp/invoke"
            Write-Log "Commande curl: $curlCommand" -Level "INFO"
            
            $response = Invoke-Expression $curlCommand
            
            if ($response) {
                Write-Log "Réponse reçue via curl" -Level "SUCCESS"
                Write-Log "Réponse: $response" -Level "INFO"
                
                try {
                    $parsedResponse = $response | ConvertFrom-Json
                    
                    if ($parsedResponse.projects -and $parsedResponse.projects.Count -gt 0) {
                        Write-Log "Projets trouvés: $($parsedResponse.projects.Count)" -Level "SUCCESS"
                        $parsedResponse.projects | ForEach-Object {
                            Write-Log "- Projet: $($_.title) (#$($_.number))" -Level "INFO"
                        }
                        
                        return $parsedResponse.projects[0]
                    } else {
                        Write-Log "Aucun projet trouvé" -Level "WARNING"
                        return $null
                    }
                } catch {
                    Write-Log "Erreur lors du parsing de la réponse JSON: $_" -Level "ERROR"
                    Write-Log "Réponse brute: $response" -Level "INFO"
                    return $null
                }
            } else {
                Write-Log "Aucune réponse reçue via curl" -Level "WARNING"
            }
        } catch {
            Write-Log "Erreur lors de l'exécution de curl: $_" -Level "ERROR"
        }
        
        # Tester avec Invoke-RestMethod
        Write-Log "Test avec Invoke-RestMethod..." -Level "INFO"
        
        try {
            $requestBody = Get-Content -Path $requestFile -Raw
            $response = Invoke-RestMethod -Method Post -Uri "http://localhost:3002/api/mcp/invoke" -Headers @{"Content-Type" = "application/json"} -Body $requestBody
            
            if ($response) {
                Write-Log "Réponse reçue via Invoke-RestMethod" -Level "SUCCESS"
                Write-Log "Réponse: $($response | ConvertTo-Json -Depth 3)" -Level "INFO"
                
                if ($response.projects -and $response.projects.Count -gt 0) {
                    Write-Log "Projets trouvés: $($response.projects.Count)" -Level "SUCCESS"
                    $response.projects | ForEach-Object {
                        Write-Log "- Projet: $($_.title) (#$($_.number))" -Level "INFO"
                    }
                    
                    return $response.projects[0]
                } else {
                    Write-Log "Aucun projet trouvé" -Level "WARNING"
                    return $null
                }
            } else {
                Write-Log "Aucune réponse reçue via Invoke-RestMethod" -Level "WARNING"
                return $null
            }
        } catch {
            Write-Log "Erreur lors de l'exécution de Invoke-RestMethod: $_" -Level "ERROR"
            return $null
        }
    } catch {
        Write-Log "Erreur lors du test de list_projects: $_" -Level "ERROR"
        return $null
    }
}

# Fonction pour tester l'obtention des détails d'un projet
function Test-GetProject {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Owner,
        
        [Parameter(Mandatory=$true)]
        [int]$ProjectNumber
    )
    
    Write-Log "Test de la fonctionnalité 'get_project' pour le projet #$ProjectNumber de $Owner" -Level "INFO"
    
    try {
        # Créer un fichier temporaire pour la requête
        $tempDir = Join-Path $env:TEMP "mcp-tests"
        if (-not (Test-Path $tempDir)) {
            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        }
        
        $requestFile = Join-Path $tempDir "get-project-request.json"
        
        # Créer la requête JSON
        $request = @{
            server_name = "github-projects"
            tool_name = "get_project"
            arguments = @{
                owner = $Owner
                project_number = $ProjectNumber
            }
        }
        
        $request | ConvertTo-Json -Depth 10 | Out-File -FilePath $requestFile -Encoding utf8
        
        Write-Log "Requête JSON créée: $requestFile" -Level "INFO"
        Get-Content -Path $requestFile | ForEach-Object { Write-Log "- $_" -Level "INFO" }
        
        # Tester avec curl
        Write-Log "Test avec curl..." -Level "INFO"
        
        try {
            $curlCommand = "curl -s -X POST -H 'Content-Type: application/json' -d '@$requestFile' http://localhost:3002/api/mcp/invoke"
            Write-Log "Commande curl: $curlCommand" -Level "INFO"
            
            $response = Invoke-Expression $curlCommand
            
            if ($response) {
                Write-Log "Réponse reçue via curl" -Level "SUCCESS"
                Write-Log "Réponse: $response" -Level "INFO"
                
                try {
                    $parsedResponse = $response | ConvertFrom-Json
                    
                    if ($parsedResponse.id -and $parsedResponse.title) {
                        Write-Log "Détails du projet récupérés avec succès" -Level "SUCCESS"
                        Write-Log "- ID: $($parsedResponse.id)" -Level "INFO"
                        Write-Log "- Titre: $($parsedResponse.title)" -Level "INFO"
                        Write-Log "- Description: $($parsedResponse.description)" -Level "INFO"
                        
                        return $parsedResponse
                    } else {
                        Write-Log "Détails du projet incomplets ou non trouvés" -Level "WARNING"
                        return $null
                    }
                } catch {
                    Write-Log "Erreur lors du parsing de la réponse JSON: $_" -Level "ERROR"
                    Write-Log "Réponse brute: $response" -Level "INFO"
                    return $null
                }
            } else {
                Write-Log "Aucune réponse reçue via curl" -Level "WARNING"
            }
        } catch {
            Write-Log "Erreur lors de l'exécution de curl: $_" -Level "ERROR"
        }
        
        # Tester avec Invoke-RestMethod
        Write-Log "Test avec Invoke-RestMethod..." -Level "INFO"
        
        try {
            $requestBody = Get-Content -Path $requestFile -Raw
            $response = Invoke-RestMethod -Method Post -Uri "http://localhost:3002/api/mcp/invoke" -Headers @{"Content-Type" = "application/json"} -Body $requestBody
            
            if ($response) {
                Write-Log "Réponse reçue via Invoke-RestMethod" -Level "SUCCESS"
                Write-Log "Réponse: $($response | ConvertTo-Json -Depth 3)" -Level "INFO"
                
                if ($response.id -and $response.title) {
                    Write-Log "Détails du projet récupérés avec succès" -Level "SUCCESS"
                    Write-Log "- ID: $($response.id)" -Level "INFO"
                    Write-Log "- Titre: $($response.title)" -Level "INFO"
                    Write-Log "- Description: $($response.description)" -Level "INFO"
                    
                    return $response
                } else {
                    Write-Log "Détails du projet incomplets ou non trouvés" -Level "WARNING"
                    return $null
                }
            } else {
                Write-Log "Aucune réponse reçue via Invoke-RestMethod" -Level "WARNING"
                return $null
            }
        } catch {
            Write-Log "Erreur lors de l'exécution de Invoke-RestMethod: $_" -Level "ERROR"
            return $null
        }
    } catch {
        Write-Log "Erreur lors du test de get_project: $_" -Level "ERROR"
        return $null
    }
}

# Exécution des tests
try {
    Write-Log "Démarrage des tests du MCP GitHub Projects" -Level "INFO"
    
    # Test 1: Vérifier la configuration
    $configOk = Test-MCPGitHubProjectsConfig
    
    # Test 2: Vérifier le serveur
    $serverOk = Test-MCPGitHubProjectsServer
    
    # Test 3: Vérifier le MCP CLI
    $cliOk = Test-MCPCli
    
    # Test 4: Vérifier le serveur directement
    $serverDirectOk = Test-MCPGitHubProjectsServerDirect
    
    # Si les tests de base sont réussis, tester les fonctionnalités
    if ($configOk -or $serverOk -or $serverDirectOk) {
        # Paramètres de test
        $owner = "myia-tech" # Remplacer par votre nom d'utilisateur ou organisation GitHub
        $ownerType = "ORGANIZATION" # USER ou ORGANIZATION
        
        # Test 5: Lister les projets
        $project = Test-ListProjects -Owner $owner -OwnerType $ownerType
        
        # Test 6: Obtenir les détails d'un projet
        if ($project) {
            Test-GetProject -Owner $owner -ProjectNumber $project.number
        } else {
            Write-Log "Impossible de tester get_project car aucun projet n'a été trouvé" -Level "WARNING"
            
            # Tester avec un numéro de projet fixe
            Write-Log "Test avec un numéro de projet fixe (1)" -Level "INFO"
            Test-GetProject -Owner $owner -ProjectNumber 1
        }
    } else {
        Write-Log "Les tests de base ont échoué, impossible de tester les fonctionnalités" -Level "ERROR"
    }
    
    Write-Log "Tests terminés" -Level "INFO"
} catch {
    Write-Log "Erreur lors de l'exécution des tests: $_" -Level "ERROR"
}

# Générer un rapport de test
$reportPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "results.md"
$reportContent = @"
# Rapport de test du MCP GitHub Projects

Date d'exécution: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Configuration testée

- Fichier de configuration: C:\Users\MYIA\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json
- Configuration valide: $configOk
- Serveur en cours d'exécution: $serverOk
- MCP CLI disponible: $cliOk
- Serveur accessible directement: $serverDirectOk

## Résultats des tests

Les résultats détaillés des tests sont disponibles dans la sortie de la console.

## Problèmes identifiés

Si des problèmes ont été identifiés lors des tests, ils sont listés ci-dessous:

- Configuration du MCP GitHub Projects: $(if ($configOk) { "OK" } else { "NOK" })
- Serveur MCP GitHub Projects en cours d'exécution: $(if ($serverOk) { "OK" } else { "NOK" })
- MCP CLI disponible: $(if ($cliOk) { "OK" } else { "NOK" })
- Serveur accessible directement: $(if ($serverDirectOk) { "OK" } else { "NOK" })

## Recommandations

- Si la configuration n'est pas valide, vérifiez le fichier de configuration
- Si le serveur n'est pas en cours d'exécution, démarrez-le manuellement
- Si le MCP CLI n'est pas disponible, vérifiez l'installation de Roo
- Si le serveur n'est pas accessible directement, vérifiez que le port 3002 est ouvert et que le serveur est en cours d'exécution
"@

$reportContent | Out-File -FilePath $reportPath -Encoding utf8
Write-Log "Rapport de test généré: $reportPath" -Level "SUCCESS"