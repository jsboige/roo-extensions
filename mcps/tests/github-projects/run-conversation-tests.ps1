# Script PowerShell pour exécuter les scénarios de test de conversation pour le MCP GitHub Projects
# Ce script simule des conversations entre un utilisateur et Roo pour tester les fonctionnalités du MCP GitHub Projects

# Configuration
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Fonction pour afficher les messages de log
function Write-Log {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS", "TEST")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $colorMap = @{
        "INFO" = "White"
        "WARNING" = "Yellow"
        "ERROR" = "Red"
        "SUCCESS" = "Green"
        "TEST" = "Cyan"
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $colorMap[$Level]
}

# Fonction pour vérifier si le serveur MCP GitHub Projects est en cours d'exécution
function Test-MCPGitHubProjectsServer {
    Write-Log "Vérification du serveur MCP GitHub Projects" -Level "INFO"
    
    try {
        # Vérifier si le port 3002 est utilisé
        $connections = Get-NetTCPConnection -LocalPort 3002 -ErrorAction SilentlyContinue
        if ($connections) {
            $process = Get-Process -Id $connections[0].OwningProcess -ErrorAction SilentlyContinue
            if ($process) {
                Write-Log "Le serveur MCP GitHub Projects est en cours d'exécution sur le port 3002 (PID: $($process.Id), Processus: $($process.ProcessName))" -Level "SUCCESS"
                return $true
            }
        }
        
        Write-Log "Le serveur MCP GitHub Projects ne semble pas être en cours d'exécution sur le port 3002" -Level "WARNING"
        
        # Tenter de démarrer le serveur
        $startServerScript = Join-Path (Get-Location) "start-github-projects-mcp.ps1"
        if (Test-Path $startServerScript) {
            Write-Log "Tentative de démarrage du serveur MCP GitHub Projects..." -Level "INFO"
            
            # Démarrer le script dans une nouvelle fenêtre PowerShell
            Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$startServerScript`"" -WindowStyle Normal
            
            # Attendre que le serveur démarre
            Write-Log "Attente du démarrage du serveur (10 secondes)..." -Level "INFO"
            Start-Sleep -Seconds 10
            
            # Vérifier à nouveau si le serveur est en cours d'exécution
            $connections = Get-NetTCPConnection -LocalPort 3002 -ErrorAction SilentlyContinue
            if ($connections) {
                $process = Get-Process -Id $connections[0].OwningProcess -ErrorAction SilentlyContinue
                if ($process) {
                    Write-Log "Le serveur MCP GitHub Projects a été démarré avec succès (PID: $($process.Id), Processus: $($process.ProcessName))" -Level "SUCCESS"
                    return $true
                }
            }
            
            Write-Log "Échec du démarrage du serveur MCP GitHub Projects" -Level "ERROR"
            return $false
        } else {
            Write-Log "Script de démarrage non trouvé: $startServerScript" -Level "ERROR"
            return $false
        }
    } catch {
        Write-Log "Erreur lors de la vérification du serveur MCP GitHub Projects: $_" -Level "ERROR"
        return $false
    }
}

# Fonction pour envoyer une requête MCP
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
        
        # Créer un fichier temporaire pour la requête
        $tempRequestFile = [System.IO.Path]::GetTempFileName()
        $jsonRequest | Out-File -FilePath $tempRequestFile -Encoding utf8
        
        # Créer un fichier temporaire pour la réponse
        $tempResponseFile = [System.IO.Path]::GetTempFileName()
        
        # Utiliser curl pour envoyer la requête au serveur MCP
        $curlCommand = "curl -X POST -H 'Content-Type: application/json' -d '@$tempRequestFile' http://localhost:3002/mcp/invoke -o '$tempResponseFile'"
        
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

# Fonction pour exécuter un scénario de test
function Test-Scenario {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ScenarioName,
        
        [Parameter(Mandatory=$true)]
        [string]$UserRequest,
        
        [Parameter(Mandatory=$true)]
        [string]$ExpectedToolName,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$ExpectedToolArguments,
        
        [Parameter(Mandatory=$false)]
        [string]$ExpectedResponsePattern
    )
    
    Write-Log "Exécution du scénario: $ScenarioName" -Level "TEST"
    Write-Log "Requête utilisateur: $UserRequest" -Level "INFO"
    
    try {
        # Simuler l'appel à l'outil MCP
        $result = Invoke-MCPRequest -ServerName "github-projects" -ToolName $ExpectedToolName -Arguments $ExpectedToolArguments
        
        # Vérifier si la requête a réussi
        if ($result -ne $null) {
            Write-Log "Outil MCP appelé avec succès: $ExpectedToolName" -Level "SUCCESS"
            
            # Ajouter le résultat au rapport
            $global:TestResults += @{
                ScenarioName = $ScenarioName
                UserRequest = $UserRequest
                ToolName = $ExpectedToolName
                ToolArguments = $ExpectedToolArguments
                Success = $true
                Result = $result
                ErrorMessage = $null
            }
            
            return $true
        } else {
            Write-Log "Échec de l'appel à l'outil MCP: $ExpectedToolName" -Level "ERROR"
            
            # Ajouter le résultat au rapport
            $global:TestResults += @{
                ScenarioName = $ScenarioName
                UserRequest = $UserRequest
                ToolName = $ExpectedToolName
                ToolArguments = $ExpectedToolArguments
                Success = $false
                Result = $null
                ErrorMessage = "Aucune réponse reçue de l'outil MCP"
            }
            
            return $false
        }
    } catch {
        Write-Log "Erreur lors de l'exécution du scénario: $_" -Level "ERROR"
        
        # Ajouter le résultat au rapport
        $global:TestResults += @{
            ScenarioName = $ScenarioName
            UserRequest = $UserRequest
            ToolName = $ExpectedToolName
            ToolArguments = $ExpectedToolArguments
            Success = $false
            Result = $null
            ErrorMessage = $_.ToString()
        }
        
        return $false
    }
}

# Fonction pour générer le rapport de test
function Generate-TestReport {
    param (
        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )
    
    Write-Log "Génération du rapport de test: $OutputPath" -Level "INFO"
    
    $reportContent = @"
# Rapport de test des scénarios de conversation pour le MCP GitHub Projects

Date d'exécution: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Résumé

- Total des scénarios testés: $($global:TestResults.Count)
- Scénarios réussis: $($global:TestResults | Where-Object { $_.Success } | Measure-Object | Select-Object -ExpandProperty Count)
- Scénarios échoués: $($global:TestResults | Where-Object { -not $_.Success } | Measure-Object | Select-Object -ExpandProperty Count)

## Détails des tests

"@
    
    foreach ($result in $global:TestResults) {
        $reportContent += @"

### $($result.ScenarioName)

**Requête utilisateur:**
```
$($result.UserRequest)
```

**Outil MCP appelé:** `$($result.ToolName)`

**Arguments:**
```json
$($result.ToolArguments | ConvertTo-Json -Depth 5)
```

**Statut:** $(if ($result.Success) { "✅ Réussi" } else { "❌ Échoué" })

"@
        
        if ($result.Success) {
            $reportContent += @"
**Réponse:**
```json
$($result.Result | ConvertTo-Json -Depth 5)
```

"@
        } else {
            $reportContent += @"
**Erreur:**
```
$($result.ErrorMessage)
```

"@
        }
    }
    
    $reportContent += @"

## Recommandations

- Si certains tests ont échoué, vérifiez que le serveur MCP GitHub Projects est correctement configuré et en cours d'exécution
- Vérifiez que le token GitHub configuré dispose des permissions nécessaires
- Assurez-vous que les projets et les éléments référencés dans les tests existent dans votre compte GitHub

## Prochaines étapes

1. Corriger les problèmes identifiés dans les tests échoués
2. Ajouter des scénarios de test supplémentaires pour couvrir d'autres cas d'utilisation
3. Automatiser l'exécution régulière de ces tests pour assurer la stabilité du MCP GitHub Projects
"@
    
    # Écrire le rapport dans un fichier
    $reportContent | Out-File -FilePath $OutputPath -Encoding utf8
    
    Write-Log "Rapport de test généré avec succès: $OutputPath" -Level "SUCCESS"
}

# Initialiser la variable globale pour stocker les résultats des tests
$global:TestResults = @()

# Vérifier si le serveur MCP GitHub Projects est en cours d'exécution
$serverRunning = Test-MCPGitHubProjectsServer
if (-not $serverRunning) {
    Write-Log "Impossible de continuer les tests sans le serveur MCP GitHub Projects" -Level "ERROR"
    exit 1
}

# Paramètres de test - à modifier selon votre environnement
$owner = "myia-tech" # Remplacer par votre nom d'utilisateur ou organisation GitHub
$ownerType = "ORGANIZATION" # USER ou ORGANIZATION

Write-Log "Démarrage des tests de scénarios de conversation pour le MCP GitHub Projects" -Level "INFO"
Write-Log "Propriétaire GitHub: $owner ($ownerType)" -Level "INFO"

# Scénario 1.1: Filtrer les éléments ouverts d'un projet
Test-Scenario -ScenarioName "Filtrage des éléments ouverts d'un projet" `
              -UserRequest "Montre-moi toutes les issues ouvertes dans mon projet 'Développement API' sur GitHub." `
              -ExpectedToolName "get_project" `
              -ExpectedToolArguments @{
                  owner = $owner
                  project_number = 1
                  state = "OPEN"
              } `
              -ExpectedResponsePattern "issues ouvertes"

# Scénario 1.2: Filtrer les éléments fermés d'un projet
Test-Scenario -ScenarioName "Filtrage des éléments fermés d'un projet" `
              -UserRequest "Quelles sont les issues fermées dans mon projet 'Développement API' sur GitHub?" `
              -ExpectedToolName "get_project" `
              -ExpectedToolArguments @{
                  owner = $owner
                  project_number = 1
                  state = "CLOSED"
              } `
              -ExpectedResponsePattern "issues fermées"

# Scénario 2.1: Filtrer les éléments par priorité
Test-Scenario -ScenarioName "Filtrage des éléments par priorité" `
              -UserRequest "Montre-moi toutes les tâches de haute priorité dans mon projet 'Développement API'." `
              -ExpectedToolName "get_project" `
              -ExpectedToolArguments @{
                  owner = $owner
                  project_number = 1
                  filter_field_name = "Priority"
                  filter_field_value = "High"
              } `
              -ExpectedResponsePattern "haute priorité"

# Scénario 2.2: Filtrer les éléments par sprint
Test-Scenario -ScenarioName "Filtrage des éléments par sprint" `
              -UserRequest "Quelles sont les tâches prévues pour le Sprint 3 dans mon projet 'Développement API'?" `
              -ExpectedToolName "get_project" `
              -ExpectedToolArguments @{
                  owner = $owner
                  project_number = 1
                  filter_field_name = "Sprint"
                  filter_field_value = "Sprint 3"
              } `
              -ExpectedResponsePattern "Sprint 3"

# Scénario 3.1: Afficher la première page d'éléments
Test-Scenario -ScenarioName "Pagination - Première page d'éléments" `
              -UserRequest "Montre-moi les 5 premières tâches de mon projet 'Refonte du site web'." `
              -ExpectedToolName "get_project" `
              -ExpectedToolArguments @{
                  owner = $owner
                  project_number = 2
                  limit = 5
              } `
              -ExpectedResponsePattern "premières tâches"

# Scénario 3.2: Afficher la page suivante d'éléments
# Note: Le curseur est un exemple et devrait être remplacé par un curseur réel obtenu de la réponse précédente
Test-Scenario -ScenarioName "Pagination - Page suivante d'éléments" `
              -UserRequest "Oui, montre-moi les 5 tâches suivantes." `
              -ExpectedToolName "get_project" `
              -ExpectedToolArguments @{
                  owner = $owner
                  project_number = 2
                  limit = 5
                  cursor = "Y3Vyc29yOnYyOpK5MjAyNS0wNS0xOVQwODozMDowMCswMjowMM4Aw1Ft"
              } `
              -ExpectedResponsePattern "tâches suivantes"

# Scénario 4.1: Lister tous les champs d'un projet
Test-Scenario -ScenarioName "Listage des champs d'un projet" `
              -UserRequest "Quels sont les champs disponibles dans mon projet 'Développement API'?" `
              -ExpectedToolName "get_project_fields" `
              -ExpectedToolArguments @{
                  owner = $owner
                  project_number = 1
              } `
              -ExpectedResponsePattern "champs disponibles"

# Scénario 5.1: Supprimer un élément d'un projet
# Note: L'item_id est un exemple et devrait être remplacé par un ID réel
Test-Scenario -ScenarioName "Suppression d'un élément d'un projet" `
              -UserRequest "Supprime la tâche #64 'Implémenter le formulaire de contact' de mon projet 'Refonte du site web'." `
              -ExpectedToolName "delete_project_item" `
              -ExpectedToolArguments @{
                  owner = $owner
                  project_number = 2
                  item_id = "PVTI_lADOBlfb84AZc0wgzgB1Mg"
              } `
              -ExpectedResponsePattern "supprimée avec succès"

# Scénario 6.1: Mettre à jour le champ d'itération d'un élément
# Note: Les IDs sont des exemples et devraient être remplacés par des IDs réels
Test-Scenario -ScenarioName "Support des champs de type itération" `
              -UserRequest "Déplace la tâche #51 'Corriger la faille de sécurité XSS' du Sprint 3 au Sprint 2 dans mon projet 'Développement API'." `
              -ExpectedToolName "update_project_item_field" `
              -ExpectedToolArguments @{
                  project_id = "PVT_kwDOBlfb84AZc0"
                  item_id = "PVTI_lADOBlfb84AZc0wgzgB2Nz"
                  field_id = "PVTF_lADOBlfb84AZc0zADOBlfb"
                  field_type = "iteration"
                  value = "47592c89"
              } `
              -ExpectedResponsePattern "déplacée avec succès"

# Scénario 7.1: Créer une issue et l'ajouter à un projet
Test-Scenario -ScenarioName "Création d'une issue et ajout direct à un projet" `
              -UserRequest "Crée une nouvelle issue intitulée 'Ajouter la fonctionnalité de recherche avancée' dans mon dépôt 'api-backend' et ajoute-la à mon projet 'Développement API'." `
              -ExpectedToolName "create_issue_and_add_to_project" `
              -ExpectedToolArguments @{
                  owner = $owner
                  repo = "api-backend"
                  title = "Ajouter la fonctionnalité de recherche avancée"
                  body = "Implémenter une fonctionnalité de recherche avancée permettant aux utilisateurs de filtrer les résultats par date, catégorie et mots-clés."
                  project_owner = $owner
                  project_number = 1
              } `
              -ExpectedResponsePattern "créée avec succès"

# Scénario 8.1: Mettre à jour le titre et la description d'un projet
Test-Scenario -ScenarioName "Mise à jour du titre et de la description d'un projet" `
              -UserRequest "Modifie le titre de mon projet 'Refonte du site web' en 'Refonte du site web corporate' et ajoute la description 'Projet de modernisation du site web de l'entreprise avec focus sur l'expérience utilisateur et les performances'." `
              -ExpectedToolName "update_project_settings" `
              -ExpectedToolArguments @{
                  owner = $owner
                  project_number = 2
                  title = "Refonte du site web corporate"
                  description = "Projet de modernisation du site web de l'entreprise avec focus sur l'expérience utilisateur et les performances"
              } `
              -ExpectedResponsePattern "mis à jour avec succès"

# Scénario 8.2: Modifier la visibilité d'un projet
Test-Scenario -ScenarioName "Modification de la visibilité d'un projet" `
              -UserRequest "Rends mon projet 'Développement API' public pour que toute l'équipe puisse y accéder." `
              -ExpectedToolName "update_project_settings" `
              -ExpectedToolArguments @{
                  owner = $owner
                  project_number = 1
                  public = $true
              } `
              -ExpectedResponsePattern "visibilité"

# Générer le rapport de test
$reportPath = Join-Path (Get-Location) "test-results.md"
Generate-TestReport -OutputPath $reportPath

Write-Log "Tests terminés. Rapport généré: $reportPath" -Level "SUCCESS"