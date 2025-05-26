#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Script de deploiement pour le MCP Roo State Manager

.DESCRIPTION
    Ce script automatise l'installation, la compilation et les tests du MCP Roo State Manager.

.PARAMETER Install
    Installe les dependances npm

.PARAMETER Build
    Compile le projet TypeScript

.PARAMETER Test
    Lance les tests de validation

.PARAMETER Deploy
    Effectue une installation complete (install + build + test)

.EXAMPLE
    .\deploy-simple.ps1 -Deploy
    Effectue une installation complete

.EXAMPLE
    .\deploy-simple.ps1 -Test
    Lance uniquement les tests
#>

param(
    [switch]$Install,
    [switch]$Build,
    [switch]$Test,
    [switch]$Deploy,
    [switch]$Help
)

function Write-Success($message) {
    Write-Host "[OK] $message" -ForegroundColor Green
}

function Write-Error($message) {
    Write-Host "[ERREUR] $message" -ForegroundColor Red
}

function Write-Warning($message) {
    Write-Host "[ATTENTION] $message" -ForegroundColor Yellow
}

function Write-Info($message) {
    Write-Host "[INFO] $message" -ForegroundColor Blue
}

function Show-Help {
    Write-Host "Script de deploiement MCP Roo State Manager" -ForegroundColor Blue
    Write-Host ""
    Write-Host "UTILISATION:" -ForegroundColor Yellow
    Write-Host "    .\deploy-simple.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "OPTIONS:" -ForegroundColor Yellow
    Write-Host "    -Install        Installe les dependances npm"
    Write-Host "    -Build          Compile le projet TypeScript"
    Write-Host "    -Test           Lance les tests de validation"
    Write-Host "    -Deploy         Installation complete (install + build + test)"
    Write-Host "    -Help           Affiche cette aide"
    Write-Host ""
    Write-Host "EXEMPLES:" -ForegroundColor Yellow
    Write-Host "    .\deploy-simple.ps1 -Deploy"
    Write-Host "    .\deploy-simple.ps1 -Test"
}

function Test-Prerequisites {
    Write-Info "Verification des prerequis..."
    
    # Verification de Node.js
    try {
        $nodeVersion = node --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Node.js detecte: $nodeVersion"
        } else {
            Write-Error "Node.js n'est pas installe ou non disponible dans le PATH"
            return $false
        }
    } catch {
        Write-Error "Node.js n'est pas installe ou non disponible dans le PATH"
        return $false
    }
    
    # Verification de npm
    try {
        $npmVersion = npm --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "npm detecte: $npmVersion"
        } else {
            Write-Error "npm n'est pas installe ou non disponible dans le PATH"
            return $false
        }
    } catch {
        Write-Error "npm n'est pas installe ou non disponible dans le PATH"
        return $false
    }
    
    return $true
}

function Install-Dependencies {
    Write-Info "Installation des dependances npm..."
    
    try {
        npm install
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Dependances installees avec succes"
            return $true
        } else {
            Write-Error "Erreur lors de l'installation des dependances"
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
            Write-Success "Compilation reussie"
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
            Write-Success "Tests reussis"
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

function Main {
    Write-Host "Deploiement MCP Roo State Manager" -ForegroundColor Blue
    Write-Host ""
    
    if ($Help) {
        Show-Help
        return
    }
    
    # Verification des prerequis
    if (-not (Test-Prerequisites)) {
        Write-Error "Prerequis non satisfaits. Arret du deploiement."
        exit 1
    }
    
    $success = $true
    
    # Mode deploiement complet
    if ($Deploy) {
        $Install = $true
        $Build = $true
        $Test = $true
    }
    
    # Si aucune option specifiee, afficher l'aide
    if (-not ($Install -or $Build -or $Test)) {
        Show-Help
        return
    }
    
    # Installation des dependances
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
    
    # Resume final
    Write-Host ""
    Write-Host "RESUME DU DEPLOIEMENT" -ForegroundColor Blue
    if ($success) {
        Write-Success "Deploiement termine avec succes!"
        Write-Info "Le serveur MCP Roo State Manager est pret a etre utilise."
        Write-Info "Chemin du serveur: $(Get-Location)\build\index.js"
    } else {
        Write-Error "Le deploiement a echoue. Verifiez les erreurs ci-dessus."
        exit 1
    }
}

# Point d'entree
Main