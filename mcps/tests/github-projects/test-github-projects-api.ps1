# Script PowerShell pour tester directement l'API GitHub Projects
# Ce script utilise l'API GraphQL de GitHub pour interagir avec les projets GitHub

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

# Fonction pour obtenir le token GitHub
function Get-GitHubToken {
    # Essayer de lire le token depuis le fichier mcp_settings.json
    $settingsPath = "C:\Users\MYIA\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"
    
    if (Test-Path $settingsPath) {
        $settings = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
        
        if ($settings.mcpServers.'github-projects'.env.GITHUB_TOKEN) {
            return $settings.mcpServers.'github-projects'.env.GITHUB_TOKEN
        }
    }
    
    # Si le token n'est pas trouvé dans le fichier de configuration, demander à l'utilisateur
    $token = Read-Host -Prompt "Veuillez entrer votre token GitHub"
    return $token
}

# Fonction pour exécuter une requête GraphQL
function Invoke-GitHubGraphQL {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Query,
        
        [Parameter(Mandatory=$false)]
        [hashtable]$Variables = @{},
        
        [Parameter(Mandatory=$false)]
        [string]$Token = $null
    )
    
    if (-not $Token) {
        $Token = Get-GitHubToken
    }
    
    $headers = @{
        "Authorization" = "Bearer $Token"
        "Content-Type" = "application/json"
        "Accept" = "application/vnd.github.v4+json"
    }
    
    $body = @{
        query = $Query
        variables = $Variables
    } | ConvertTo-Json -Depth 10
    
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/graphql" -Method Post -Headers $headers -Body $body
        return $response.data
    } catch {
        Write-Log "Erreur lors de l'exécution de la requête GraphQL: $_" -Level "ERROR"
        
        if ($_.ErrorDetails.Message) {
            $errorDetails = $_.ErrorDetails.Message | ConvertFrom-Json
            Write-Log "Détails de l'erreur: $($errorDetails.message)" -Level "ERROR"
            
            if ($errorDetails.errors) {
                foreach ($error in $errorDetails.errors) {
                    Write-Log "- $($error.message)" -Level "ERROR"
                }
            }
        }
        
        throw $_
    }
}

# Fonction pour lister les projets d'un utilisateur ou d'une organisation
function Get-GitHubProjects {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Owner,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("user", "organization")]
        [string]$Type = "user",
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("open", "closed", "all")]
        [string]$State = "open",
        
        [Parameter(Mandatory=$false)]
        [string]$Token = $null
    )
    
    Write-Log "Récupération des projets pour $Type '$Owner' (état: $State)" -Level "INFO"
    
    $query = @"
query(`$owner: String!, `$type: String!) {
  ${Type}(login: `$owner) {
    projectsV2(first: 20, states: ${if ($State -eq "all") { "[OPEN, CLOSED]" } elseif ($State -eq "closed") { "[CLOSED]" } else { "[OPEN]" }}) {
      nodes {
        id
        title
        number
        shortDescription
        url
        closed
        createdAt
        updatedAt
      }
    }
  }
}
"@
    
    try {
        $response = Invoke-GitHubGraphQL -Query $query -Variables @{
            owner = $Owner
            type = $Type
        } -Token $Token
        
        $projects = if ($Type -eq "user") { $response.user.projectsV2.nodes } else { $response.organization.projectsV2.nodes }
        
        if ($projects -and $projects.Count -gt 0) {
            Write-Log "Projets trouvés: $($projects.Count)" -Level "SUCCESS"
            
            foreach ($project in $projects) {
                Write-Host "- Projet #$($project.number): $($project.title)"
                Write-Host "  Description: $($project.shortDescription)"
                Write-Host "  URL: $($project.url)"
                Write-Host "  État: $(if ($project.closed) { 'Fermé' } else { 'Ouvert' })"
                Write-Host "  Créé le: $($project.createdAt)"
                Write-Host "  Mis à jour le: $($project.updatedAt)"
                Write-Host ""
            }
            
            return $projects
        } else {
            Write-Log "Aucun projet trouvé pour $Owner" -Level "WARNING"
            return $null
        }
    } catch {
        Write-Log "Échec de la récupération des projets: $_" -Level "ERROR"
        return $null
    }
}

# Fonction pour obtenir les détails d'un projet
function Get-GitHubProject {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Owner,
        
        [Parameter(Mandatory=$true)]
        [int]$ProjectNumber,
        
        [Parameter(Mandatory=$false)]
        [string]$Token = $null
    )
    
    Write-Log "Récupération des détails du projet #$ProjectNumber de $Owner" -Level "INFO"
    
    $query = @"
query(`$owner: String!, `$number: Int!) {
  user(login: `$owner) {
    projectV2(number: `$number) {
      id
      title
      number
      shortDescription
      url
      closed
      createdAt
      updatedAt
      items(first: 100) {
        nodes {
          id
          type
          content {
            ... on Issue {
              title
              number
              state
              url
            }
            ... on PullRequest {
              title
              number
              state
              url
            }
            ... on DraftIssue {
              title
              body
            }
          }
          fieldValues(first: 20) {
            nodes {
              ... on ProjectV2ItemFieldTextValue {
                text
                field {
                  ... on ProjectV2FieldCommon {
                    name
                  }
                }
              }
              ... on ProjectV2ItemFieldDateValue {
                date
                field {
                  ... on ProjectV2FieldCommon {
                    name
                  }
                }
              }
              ... on ProjectV2ItemFieldSingleSelectValue {
                name
                field {
                  ... on ProjectV2FieldCommon {
                    name
                  }
                }
              }
            }
          }
        }
      }
      fields(first: 20) {
        nodes {
          ... on ProjectV2FieldCommon {
            id
            name
          }
          ... on ProjectV2SingleSelectField {
            id
            name
            options {
              id
              name
              color
            }
          }
        }
      }
    }
  }
}
"@
    
    try {
        $response = Invoke-GitHubGraphQL -Query $query -Variables @{
            owner = $Owner
            number = $ProjectNumber
        } -Token $Token
        
        $project = $response.user.projectV2
        
        if ($project) {
            Write-Log "Détails du projet récupérés avec succès" -Level "SUCCESS"
            
            Write-Host "Projet #$($project.number): $($project.title)"
            Write-Host "Description: $($project.shortDescription)"
            Write-Host "URL: $($project.url)"
            Write-Host "État: $(if ($project.closed) { 'Fermé' } else { 'Ouvert' })"
            Write-Host "Créé le: $($project.createdAt)"
            Write-Host "Mis à jour le: $($project.updatedAt)"
            Write-Host ""
            
            Write-Host "Champs du projet:"
            foreach ($field in $project.fields.nodes) {
                Write-Host "- $($field.name) (ID: $($field.id))"
                
                if ($field.options) {
                    Write-Host "  Options:"
                    foreach ($option in $field.options) {
                        Write-Host "  - $($option.name) (ID: $($option.id), Couleur: $($option.color))"
                    }
                }
            }
            Write-Host ""
            
            Write-Host "Éléments du projet:"
            foreach ($item in $project.items.nodes) {
                Write-Host "- ID: $($item.id), Type: $($item.type)"
                
                if ($item.content) {
                    Write-Host "  Titre: $($item.content.title)"
                    
                    if ($item.content.number) {
                        Write-Host "  Numéro: $($item.content.number)"
                    }
                    
                    if ($item.content.state) {
                        Write-Host "  État: $($item.content.state)"
                    }
                    
                    if ($item.content.url) {
                        Write-Host "  URL: $($item.content.url)"
                    }
                    
                    if ($item.content.body) {
                        Write-Host "  Corps: $($item.content.body)"
                    }
                }
                
                if ($item.fieldValues -and $item.fieldValues.nodes) {
                    Write-Host "  Valeurs des champs:"
                    foreach ($fieldValue in $item.fieldValues.nodes) {
                        if ($fieldValue.field -and $fieldValue.field.name) {
                            $value = if ($fieldValue.text) { $fieldValue.text } elseif ($fieldValue.date) { $fieldValue.date } else { $fieldValue.name }
                            Write-Host "  - $($fieldValue.field.name): $value"
                        }
                    }
                }
                
                Write-Host ""
            }
            
            return $project
        } else {
            Write-Log "Projet non trouvé" -Level "WARNING"
            return $null
        }
    } catch {
        Write-Log "Échec de la récupération des détails du projet: $_" -Level "ERROR"
        return $null
    }
}

# Menu principal
function Show-Menu {
    Clear-Host
    Write-Host "=== Test de l'API GitHub Projects ==="
    Write-Host "1. Lister les projets d'un utilisateur"
    Write-Host "2. Lister les projets d'une organisation"
    Write-Host "3. Obtenir les détails d'un projet"
    Write-Host "0. Quitter"
    Write-Host ""
    
    $choice = Read-Host "Choisissez une option"
    
    switch ($choice) {
        "1" {
            $owner = Read-Host "Nom d'utilisateur"
            $state = Read-Host "État des projets (open, closed, all) [open]"
            if (-not $state) { $state = "open" }
            
            Get-GitHubProjects -Owner $owner -Type "user" -State $state
            
            Write-Host ""
            Read-Host "Appuyez sur Entrée pour continuer"
            Show-Menu
        }
        "2" {
            $owner = Read-Host "Nom de l'organisation"
            $state = Read-Host "État des projets (open, closed, all) [open]"
            if (-not $state) { $state = "open" }
            
            Get-GitHubProjects -Owner $owner -Type "organization" -State $state
            
            Write-Host ""
            Read-Host "Appuyez sur Entrée pour continuer"
            Show-Menu
        }
        "3" {
            $owner = Read-Host "Nom d'utilisateur ou d'organisation"
            $projectNumber = Read-Host "Numéro du projet"
            
            Get-GitHubProject -Owner $owner -ProjectNumber $projectNumber
            
            Write-Host ""
            Read-Host "Appuyez sur Entrée pour continuer"
            Show-Menu
        }
        "0" {
            return
        }
        default {
            Write-Host "Option non valide. Veuillez réessayer."
            Start-Sleep -Seconds 2
            Show-Menu
        }
    }
}

# Exécution du script
try {
    # Vérifier si le token GitHub est disponible
    $token = Get-GitHubToken
    
    if (-not $token) {
        Write-Log "Aucun token GitHub trouvé. Certaines fonctionnalités peuvent être limitées." -Level "WARNING"
    } else {
        Write-Log "Token GitHub trouvé." -Level "SUCCESS"
    }
    
    # Afficher le menu
    Show-Menu
} catch {
    Write-Log "Erreur lors de l'exécution du script: $_" -Level "ERROR"
}