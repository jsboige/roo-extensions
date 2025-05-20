# Script de test pour le MCP GitHub Projects
# Ce script teste les fonctionnalités de base du MCP GitHub Projects

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

# Fonction pour créer une requête MCP en utilisant curl
function Invoke-MCPRequest {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ServerName,
        
        [Parameter(Mandatory=$true)]
        [string]$ToolName,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$Arguments
    )
    
    try {
        Write-Log "Envoi de la requête MCP: $ToolName" -Level "INFO"
        
        # Créer l'objet de requête
        $requestObj = @{
            server_name = $ServerName
            tool_name = $ToolName
            arguments = $Arguments
        }
        
        # Convertir en JSON
        $jsonRequest = ConvertTo-Json -InputObject $requestObj -Depth 10
        Write-Log "Requête JSON: $jsonRequest" -Level "INFO"
        
        # Créer un fichier temporaire pour la requête
        $tempRequestFile = [System.IO.Path]::GetTempFileName()
        $jsonRequest | Out-File -FilePath $tempRequestFile -Encoding utf8
        
        # Créer un fichier temporaire pour la réponse
        $tempResponseFile = [System.IO.Path]::GetTempFileName()
        
        # Utiliser curl pour envoyer la requête au serveur MCP
        $curlCommand = "curl -X POST -H 'Content-Type: application/json' -d '@$tempRequestFile' http://localhost:3000/api/mcp/invoke -o '$tempResponseFile'"
        Write-Log "Exécution de la commande: $curlCommand" -Level "INFO"
        
        # Exécuter la commande curl
        Invoke-Expression $curlCommand
        
        # Lire la réponse
        $response = Get-Content -Path $tempResponseFile -Raw
        
        # Nettoyer les fichiers temporaires
        Remove-Item -Path $tempRequestFile -Force
        Remove-Item -Path $tempResponseFile -Force
        
        # Tenter de convertir la réponse en objet JSON
        try {
            $parsedResponse = $response | ConvertFrom-Json
            Write-Log "Réponse MCP reçue avec succès" -Level "SUCCESS"
            return $parsedResponse
        } catch {
            Write-Log "Impossible de parser la réponse JSON: $_" -Level "ERROR"
            Write-Log "Réponse brute: $response" -Level "INFO"
            return $response
        }
    } catch {
        Write-Log "Erreur lors de l'invocation du MCP: $_" -Level "ERROR"
        throw $_
    }
}

# Méthode alternative utilisant directement PowerShell pour communiquer avec le MCP
function Invoke-MCPDirectRequest {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ServerName,
        
        [Parameter(Mandatory=$true)]
        [string]$ToolName,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$Arguments
    )
    
    try {
        Write-Log "Envoi de la requête MCP directe: $ToolName" -Level "INFO"
        
        # Créer le fichier de requête JSON
        $requestObj = @{
            server_name = $ServerName
            tool_name = $ToolName
            arguments = $Arguments
        }
        
        $tempDir = Join-Path $env:TEMP "mcp-tests"
        if (-not (Test-Path $tempDir)) {
            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        }
        
        $requestFile = Join-Path $tempDir "request.json"
        $responseFile = Join-Path $tempDir "response.json"
        
        # Écrire la requête dans un fichier
        $requestObj | ConvertTo-Json -Depth 10 | Out-File -FilePath $requestFile -Encoding utf8
        
        # Exécuter la commande PowerShell pour appeler le MCP
        $command = "powershell -c ""& { `$response = Invoke-RestMethod -Method Post -Uri 'http://localhost:3000/api/mcp/invoke' -Headers @{'Content-Type'='application/json'} -Body (Get-Content '$requestFile' -Raw); `$response | ConvertTo-Json -Depth 10 | Out-File -FilePath '$responseFile' -Encoding utf8 }"""
        
        Write-Log "Exécution de la commande: $command" -Level "INFO"
        Invoke-Expression $command
        
        # Lire la réponse
        if (Test-Path $responseFile) {
            $response = Get-Content -Path $responseFile -Raw
            try {
                $parsedResponse = $response | ConvertFrom-Json
                Write-Log "Réponse MCP reçue avec succès" -Level "SUCCESS"
                return $parsedResponse
            } catch {
                Write-Log "Impossible de parser la réponse JSON: $_" -Level "ERROR"
                Write-Log "Réponse brute: $response" -Level "INFO"
                return $response
            }
        } else {
            Write-Log "Aucun fichier de réponse généré" -Level "ERROR"
            return $null
        }
    } catch {
        Write-Log "Erreur lors de l'invocation directe du MCP: $_" -Level "ERROR"
        throw $_
    }
}

# Méthode utilisant le MCP CLI directement via un fichier temporaire
function Invoke-MCPCliRequest {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ServerName,
        
        [Parameter(Mandatory=$true)]
        [string]$ToolName,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$Arguments
    )
    
    try {
        Write-Log "Envoi de la requête MCP CLI: $ToolName" -Level "INFO"
        
        # Créer le fichier de requête JSON
        $requestObj = @{
            server_name = $ServerName
            tool_name = $ToolName
            arguments = $Arguments
        }
        
        $tempDir = Join-Path $env:TEMP "mcp-tests"
        if (-not (Test-Path $tempDir)) {
            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        }
        
        $requestFile = Join-Path $tempDir "request.json"
        $responseFile = Join-Path $tempDir "response.json"
        
        # Écrire la requête dans un fichier
        $requestObj | ConvertTo-Json -Depth 10 | Out-File -FilePath $requestFile -Encoding utf8
        
        # Chemin vers l'exécutable MCP CLI
        $mcpCliPath = 'C:\Users\MYIA\AppData\Local\Programs\Roo\resources\app\out\mcp-cli\mcp-cli.exe'
        
        # Vérifier si le fichier existe
        if (-not (Test-Path $mcpCliPath)) {
            Write-Log "MCP CLI non trouvé à l'emplacement: $mcpCliPath" -Level "ERROR"
            throw "MCP CLI non trouvé"
        }
        
        # Exécuter la commande MCP CLI
        $command = "& '$mcpCliPath' invoke-file '$requestFile' > '$responseFile'"
        Write-Log "Exécution de la commande: $command" -Level "INFO"
        
        Invoke-Expression $command
        
        # Lire la réponse
        if (Test-Path $responseFile) {
            $response = Get-Content -Path $responseFile -Raw
            try {
                $parsedResponse = $response | ConvertFrom-Json
                Write-Log "Réponse MCP CLI reçue avec succès" -Level "SUCCESS"
                return $parsedResponse
            } catch {
                Write-Log "Impossible de parser la réponse JSON: $_" -Level "ERROR"
                Write-Log "Réponse brute: $response" -Level "INFO"
                return $response
            }
        } else {
            Write-Log "Aucun fichier de réponse généré" -Level "ERROR"
            return $null
        }
    } catch {
        Write-Log "Erreur lors de l'invocation du MCP CLI: $_" -Level "ERROR"
        throw $_
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
        $arguments = @{
            owner = $Owner
            owner_type = $OwnerType
        }
        
        # Tester avec les trois méthodes
        Write-Log "Tentative avec Invoke-MCPRequest..." -Level "INFO"
        try {
            $result = Invoke-MCPRequest -ServerName "github-projects" -ToolName "list_projects" -Arguments $arguments
        } catch {
            Write-Log "Échec avec Invoke-MCPRequest, tentative avec Invoke-MCPDirectRequest..." -Level "WARNING"
            try {
                $result = Invoke-MCPDirectRequest -ServerName "github-projects" -ToolName "list_projects" -Arguments $arguments
            } catch {
                Write-Log "Échec avec Invoke-MCPDirectRequest, tentative avec Invoke-MCPCliRequest..." -Level "WARNING"
                $result = Invoke-MCPCliRequest -ServerName "github-projects" -ToolName "list_projects" -Arguments $arguments
            }
        }
        
        # Vérifier si la réponse contient des projets
        if ($result.projects -and $result.projects.Count -gt 0) {
            Write-Log "Succès: $($result.projects.Count) projets trouvés pour $Owner" -Level "SUCCESS"
            
            # Afficher les projets
            Write-Log "Liste des projets:" -Level "INFO"
            $result.projects | ForEach-Object {
                Write-Host "- ID: $($_.id), Nom: $($_.title), Numéro: $($_.number)"
            }
            
            # Retourner le premier projet pour les tests suivants
            return $result.projects[0]
        } else {
            Write-Log "Aucun projet trouvé pour $Owner" -Level "WARNING"
            return $null
        }
    } catch {
        Write-Log "Échec du test 'list_projects': $_" -Level "ERROR"
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
        $arguments = @{
            owner = $Owner
            project_number = $ProjectNumber
        }
        
        # Tester avec les trois méthodes
        Write-Log "Tentative avec Invoke-MCPRequest..." -Level "INFO"
        try {
            $result = Invoke-MCPRequest -ServerName "github-projects" -ToolName "get_project" -Arguments $arguments
        } catch {
            Write-Log "Échec avec Invoke-MCPRequest, tentative avec Invoke-MCPDirectRequest..." -Level "WARNING"
            try {
                $result = Invoke-MCPDirectRequest -ServerName "github-projects" -ToolName "get_project" -Arguments $arguments
            } catch {
                Write-Log "Échec avec Invoke-MCPDirectRequest, tentative avec Invoke-MCPCliRequest..." -Level "WARNING"
                $result = Invoke-MCPCliRequest -ServerName "github-projects" -ToolName "get_project" -Arguments $arguments
            }
        }
        
        # Vérifier si la réponse contient les détails du projet
        if ($result.id -and $result.title) {
            Write-Log "Succès: Détails du projet #$ProjectNumber récupérés" -Level "SUCCESS"
            
            # Afficher les détails du projet
            Write-Log "Détails du projet:" -Level "INFO"
            Write-Host "- ID: $($result.id)"
            Write-Host "- Titre: $($result.title)"
            Write-Host "- Description: $($result.description)"
            Write-Host "- Créé le: $($result.created_at)"
            Write-Host "- Mis à jour le: $($result.updated_at)"
            
            # Afficher les champs du projet
            if ($result.fields -and $result.fields.Count -gt 0) {
                Write-Log "Champs du projet:" -Level "INFO"
                $result.fields | ForEach-Object {
                    Write-Host "- Nom: $($_.name), Type: $($_.type)"
                }
            }
            
            return $result
        } else {
            Write-Log "Échec de la récupération des détails du projet #$ProjectNumber" -Level "WARNING"
            return $null
        }
    } catch {
        Write-Log "Échec du test 'get_project': $_" -Level "ERROR"
        return $null
    }
}

# Fonction pour tester directement le serveur MCP GitHub Projects
function Test-MCPGitHubProjectsServer {
    Write-Log "Test direct du serveur MCP GitHub Projects" -Level "INFO"
    
    try {
        # Vérifier si le serveur est en cours d'exécution
        $processName = "github-projects-mcp"
        $process = Get-Process -Name $processName -ErrorAction SilentlyContinue
        
        if ($process) {
            Write-Log "Le serveur MCP GitHub Projects est en cours d'exécution (PID: $($process.Id))" -Level "SUCCESS"
        } else {
            Write-Log "Le serveur MCP GitHub Projects ne semble pas être en cours d'exécution" -Level "WARNING"
            
            # Tenter de démarrer le serveur
            Write-Log "Tentative de démarrage du serveur MCP GitHub Projects..." -Level "INFO"
            
            $serverPath = "D:\roo-extensions\mcps\mcp-servers\servers\github-projects-mcp"
            $batchFile = Join-Path $serverPath "run-github-projects.bat"
            
            if (Test-Path $batchFile) {
                Write-Log "Exécution du fichier batch: $batchFile" -Level "INFO"
                Start-Process -FilePath $batchFile -WorkingDirectory $serverPath -NoNewWindow
                
                # Attendre que le serveur démarre
                Start-Sleep -Seconds 5
                
                $process = Get-Process -Name $processName -ErrorAction SilentlyContinue
                if ($process) {
                    Write-Log "Le serveur MCP GitHub Projects a été démarré avec succès (PID: $($process.Id))" -Level "SUCCESS"
                } else {
                    Write-Log "Impossible de démarrer le serveur MCP GitHub Projects" -Level "ERROR"
                }
            } else {
                Write-Log "Fichier batch non trouvé: $batchFile" -Level "ERROR"
            }
        }
    } catch {
        Write-Log "Erreur lors du test du serveur MCP GitHub Projects: $_" -Level "ERROR"
    }
}

# Exécution des tests
try {
    Write-Log "Démarrage des tests du MCP GitHub Projects" -Level "INFO"
    
    # Test du serveur MCP GitHub Projects
    Test-MCPGitHubProjectsServer
    
    # Paramètres de test - à modifier selon votre environnement
    $owner = "myia-tech" # Remplacer par votre nom d'utilisateur ou organisation GitHub
    $ownerType = "ORGANIZATION" # USER ou ORGANIZATION
    
    # Test 1: Lister les projets
    $project = Test-ListProjects -Owner $owner -OwnerType $ownerType
    
    # Test 2: Obtenir les détails d'un projet spécifique
    if ($project) {
        Test-GetProject -Owner $owner -ProjectNumber $project.number
    } else {
        Write-Log "Impossible de tester 'get_project' car aucun projet n'a été trouvé" -Level "WARNING"
        
        # Tester avec un numéro de projet fixe si aucun projet n'a été trouvé
        Write-Log "Tentative avec un numéro de projet fixe (1)..." -Level "INFO"
        Test-GetProject -Owner $owner -ProjectNumber 1
    }
    
    Write-Log "Tests terminés" -Level "INFO"
} catch {
    Write-Log "Erreur lors de l'exécution des tests: $_" -Level "ERROR"
}

# Générer un rapport de test
$reportPath = Join-Path (Get-Location) "results.md"
$reportContent = @"
# Rapport de test du MCP GitHub Projects

Date d'exécution: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Configuration testée

- Propriétaire: $owner
- Type de propriétaire: $ownerType
- Serveur MCP: github-projects

## Résultats des tests

Les résultats détaillés des tests sont disponibles dans la sortie de la console.

## Problèmes identifiés

Si des problèmes ont été identifiés lors des tests, ils sont listés ci-dessous:

- Vérifiez que le serveur MCP GitHub Projects est en cours d'exécution
- Vérifiez que le token GitHub est valide et dispose des permissions nécessaires
- Vérifiez que le propriétaire (utilisateur ou organisation) spécifié dans le script existe et possède des projets

## Recommandations

- Si le serveur MCP GitHub Projects n'est pas en cours d'exécution, démarrez-le manuellement
- Si le token GitHub n'est pas valide, générez-en un nouveau et mettez à jour la configuration
- Si aucun projet n'est trouvé, créez un projet de test ou spécifiez un propriétaire différent
"@

$reportContent | Out-File -FilePath $reportPath -Encoding utf8
Write-Log "Rapport de test généré: $reportPath" -Level "SUCCESS"