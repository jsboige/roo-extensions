#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Script de déploiement pour le MCP Roo State Manager

.DESCRIPTION
    Ce script automatise l'installation, la compilation et les tests du MCP Roo State Manager.
    Il peut également configurer le serveur dans la configuration MCP globale.

.PARAMETER Install
    Installe les dépendances npm

.PARAMETER Build
    Compile le projet TypeScript

.PARAMETER Test
    Lance les tests de validation

.PARAMETER Deploy
    Effectue une installation complète (install + build + test)

.PARAMETER ConfigureMCP
    Ajoute le serveur à la configuration MCP (nécessite des privilèges)

.EXAMPLE
    .\deploy.ps1 -Deploy
    Effectue une installation complète

.EXAMPLE
    .\deploy.ps1 -Install -Build -Test
    Installe, compile et teste séparément
#>

param(
    [switch]$Install,
    [switch]$Build,
    [switch]$Test,
    [switch]$Deploy,
    [switch]$ConfigureMCP,
    [switch]$Help
)

# Couleurs pour l'affichage
$Green = "`e[32m"
$Red = "`e[31m"
$Yellow = "`e[33m"
$Blue = "`e[34m"
$Reset = "`e[0m"

function Write-Success($message) {
    Write-Host "${Green}✅ $message${Reset}"
}

function Write-Error($message) {
    Write-Host "${Red}❌ $message${Reset}"
}

function Write-Warning($message) {
    Write-Host "${Yellow}⚠️  $message${Reset}"
}

function Write-Info($message) {
    Write-Host "${Blue}ℹ️  $message${Reset}"
}

function Show-Help {
    Write-Host @"
${Blue}🚀 Script de déploiement MCP Roo State Manager${Reset}

${Yellow}UTILISATION:${Reset}
    .\deploy.ps1 [OPTIONS]

${Yellow}OPTIONS:${Reset}
    -Install        Installe les dépendances npm
    -Build          Compile le projet TypeScript
    -Test           Lance les tests de validation
    -Deploy         Installation complète (install + build + test)
    -ConfigureMCP   Configure le serveur dans MCP (expérimental)
    -Help           Affiche cette aide

${Yellow}EXEMPLES:${Reset}
    .\deploy.ps1 -Deploy                    # Installation complète
    .\deploy.ps1 -Install -Build -Test      # Étapes séparées
    .\deploy.ps1 -Test                      # Tests uniquement

${Yellow}PRÉREQUIS:${Reset}
    - Node.js 18+ installé
    - npm disponible dans le PATH
    - PowerShell 5.1+ ou PowerShell Core 7+
"@
}

function Test-Prerequisites {
    Write-Info "Vérification des prérequis..."
    
    # Vérification de Node.js
    try {
        $nodeVersion = node --version
        Write-Success "Node.js détecté: $nodeVersion"
    } catch {
        Write-Error "Node.js n'est pas installé ou non disponible dans le PATH"
        return $false
    }
    
    # Vérification de npm
    try {
        $npmVersion = npm --version
        Write-Success "npm détecté: $npmVersion"
    } catch {
        Write-Error "npm n'est pas installé ou non disponible dans le PATH"
        return $false
    }
    
    return $true
}

function Install-Dependencies {
    Write-Info "Installation des dépendances npm..."
    
    try {
        npm install
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Dépendances installées avec succès"
            return $true
        } else {
            Write-Error "Erreur lors de l'installation des dépendances"
            return $false
        }
    } catch {
        Write-Error "Erreur lors de l'installation: $($_.Exception.Message)"
        return $false
    }
}

function Build-Project {
    Write-Info "Compilation du projet TypeScript..."
    
    try {
        npm run build
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Compilation réussie"
            return $true
        } else {
            Write-Error "Erreur lors de la compilation"
            return $false
        }
    } catch {
        Write-Error "Erreur lors de la compilation: $($_.Exception.Message)"
        return $false
    }
}

function Test-Project {
    Write-Info "Lancement des tests de validation..."
    
    try {
        npm run test:detector
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Tests réussis"
            return $true
        } else {
            Write-Error "Erreur lors des tests"
            return $false
        }
    } catch {
        Write-Error "Erreur lors des tests: $($_.Exception.Message)"
        return $false
    }
}

function Configure-MCP {
    Write-Warning "Configuration MCP automatique non encore implémentée"
    Write-Info "Pour configurer manuellement, ajoutez ceci à votre configuration MCP:"
    Write-Host @"
${Yellow}{
  "mcpServers": {
    "roo-state-manager": {
      "command": "node",
      "args": ["$(Get-Location)\build\index.js"]
    }
  }
}${Reset}
"@
}

function Main {
    Write-Host "${Blue}🚀 Déploiement MCP Roo State Manager${Reset}`n"
    
    if ($Help) {
        Show-Help
        return
    }
    
    # Vérification des prérequis
    if (-not (Test-Prerequisites)) {
        Write-Error "Prérequis non satisfaits. Arrêt du déploiement."
        exit 1
    }
    
    $success = $true
    
    # Mode déploiement complet
    if ($Deploy) {
        $Install = $true
        $Build = $true
        $Test = $true
    }
    
    # Si aucune option spécifiée, afficher l'aide
    if (-not ($Install -or $Build -or $Test -or $ConfigureMCP)) {
        Show-Help
        return
    }
    
    # Installation des dépendances
    if ($Install) {
        if (-not (Install-Dependencies)) {
            $success = $false
        }
    }
    
    # Compilation
    if ($Build -and $success) {
        if (-not (Build-Project)) {
            $success = $false
        }
    }
    
    # Tests
    if ($Test -and $success) {
        if (-not (Test-Project)) {
            $success = $false
        }
    }
    
    # Configuration MCP
    if ($ConfigureMCP) {
        Configure-MCP
    }
    
    # Résumé final
    Write-Host "`n${Blue}📋 RÉSUMÉ DU DÉPLOIEMENT${Reset}"
    if ($success) {
        Write-Success "Déploiement terminé avec succès!"
        Write-Info "Le serveur MCP Roo State Manager est prêt à être utilisé."
        Write-Info "Chemin du serveur: $(Get-Location)\build\index.js"
    } else {
        Write-Error "Le déploiement a échoué. Vérifiez les erreurs ci-dessus."
        exit 1
    }
}

# Point d'entrée
Main