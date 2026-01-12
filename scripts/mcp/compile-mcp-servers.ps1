# Script PowerShell pour compiler les serveurs MCP
# Auteur: Roo
# Date: 21/05/2025

# CORRECTION SDDD v1.3: Ajout Set-StrictMode pour la robustesse PowerShell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Fonction pour compiler un serveur MCP
function Compile-MCPServer {
    param (
        [string]$serverName,
        [string]$outputDir
    )
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Compilation du serveur: $serverName" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    $serverPath = "mcps/internal/servers/$serverName"
    
    # Vérifier si le répertoire existe
    if (-not (Test-Path $serverPath)) {
        Write-Host "Erreur: Le répertoire $serverPath n'existe pas." -ForegroundColor Red
        return $false
    }
    
    # Se rendre dans le répertoire du serveur
    Push-Location $serverPath
    
    try {
        # CORRECTION SDDD v1.3: Ajout de timeouts sur les opérations npm
        # Installer les dépendances avec timeout (5 minutes)
        Write-Host "Installation des dépendances pour $serverName..." -ForegroundColor Yellow
        $installJob = Start-Job -ScriptBlock { npm install }
        $installJob | Wait-Job -Timeout 300 | Out-Null
        if ($installJob.State -ne 'Completed') {
            Write-Host "Erreur: Timeout lors de l'installation des dépendances pour $serverName (5min)." -ForegroundColor Red
            Remove-Job -Job $installJob -Force -ErrorAction SilentlyContinue
            return $false
        }
        $installOutput = Receive-Job -Job $installJob
        Remove-Job -Job $installJob -Force -ErrorAction SilentlyContinue
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Erreur lors de l'installation des dépendances pour $serverName." -ForegroundColor Red
            return $false
        }
        
        # Compiler le serveur avec timeout (5 minutes)
        Write-Host "Compilation de $serverName..." -ForegroundColor Yellow
        $buildJob = Start-Job -ScriptBlock { npm run build }
        $buildJob | Wait-Job -Timeout 300 | Out-Null
        if ($buildJob.State -ne 'Completed') {
            Write-Host "Erreur: Timeout lors de la compilation de $serverName (5min)." -ForegroundColor Red
            Remove-Job -Job $buildJob -Force -ErrorAction SilentlyContinue
            return $false
        }
        $buildOutput = Receive-Job -Job $buildJob
        Remove-Job -Job $buildJob -Force -ErrorAction SilentlyContinue
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Erreur lors de la compilation de $serverName." -ForegroundColor Red
            return $false
        }
        
        # Vérifier que les fichiers compilés sont bien créés
        if (-not (Test-Path $outputDir)) {
            Write-Host "Erreur: Le répertoire de sortie $outputDir n'a pas été créé." -ForegroundColor Red
            return $false
        }
        
        Write-Host "Compilation de $serverName terminée avec succès." -ForegroundColor Green
        return $true
    }
    finally {
        # Revenir au répertoire précédent
        Pop-Location
    }
}

# Fonction pour tester le démarrage d'un serveur MCP
function Test-MCPServer {
    param (
        [string]$serverName
    )
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Test du serveur: $serverName" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    $serverPath = "mcps/internal/servers/$serverName"
    
    # Se rendre dans le répertoire du serveur
    Push-Location $serverPath
    
    try {
        # Démarrer le serveur avec un timeout
        Write-Host "Démarrage de $serverName..." -ForegroundColor Yellow
        
        # Démarrer le serveur en arrière-plan
        $job = Start-Job -ScriptBlock {
            param($path)
            Set-Location $path
            npm start
        } -ArgumentList $PWD.Path
        
        # Attendre 5 secondes
        Start-Sleep -Seconds 5
        
        # Arrêter le job
        Stop-Job -Job $job
        
        # Récupérer la sortie
        $output = Receive-Job -Job $job
        Remove-Job -Job $job -Force
        
        # Vérifier si le serveur a démarré correctement
        if ($output -match "error|exception|failed" -and $output -notmatch "listening|started|ready") {
            Write-Host "Erreur lors du démarrage de $serverName." -ForegroundColor Red
            Write-Host "Sortie du serveur:" -ForegroundColor Red
            Write-Host $output
            return $false
        }
        
        Write-Host "Le serveur $serverName semble démarrer correctement." -ForegroundColor Green
        return $true
    }
    finally {
        # Revenir au répertoire précédent
        Pop-Location
    }
}

# Fonction principale
function Main {
    $startTime = Get-Date
    
    Write-Host "Début de la compilation des serveurs MCP: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Magenta
    
    # Liste des serveurs à compiler avec leur répertoire de sortie
    $servers = @(
        @{Name = "quickfiles-server"; OutputDir = "build"},
        @{Name = "jinavigator-server"; OutputDir = "dist"},
        @{Name = "jupyter-mcp-server"; OutputDir = "dist"},
        @{Name = "github-projects-mcp"; OutputDir = "dist"}
    )
    
    $results = @()
    
    # Compiler chaque serveur
    foreach ($server in $servers) {
        $success = Compile-MCPServer -serverName $server.Name -outputDir $server.OutputDir
        
        $results += [PSCustomObject]@{
            Server = $server.Name
            CompilationSuccess = $success
            TestSuccess = $null
        }
    }
    
    Write-Host "`nCompilation terminée. Démarrage des tests..." -ForegroundColor Magenta
    
    # Tester chaque serveur
    for ($i = 0; $i -lt $servers.Count; $i++) {
        if ($results[$i].CompilationSuccess) {
            $testSuccess = Test-MCPServer -serverName $servers[$i].Name
            $results[$i].TestSuccess = $testSuccess
        }
    }
    
    # Afficher le rapport
    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host "Rapport de compilation et de test" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    
    foreach ($result in $results) {
        Write-Host "Serveur: $($result.Server)" -ForegroundColor Cyan
        Write-Host "  Compilation: $(if ($result.CompilationSuccess) { 'Réussie' } else { 'Échouée' })" -ForegroundColor $(if ($result.CompilationSuccess) { 'Green' } else { 'Red' })
        
        if ($result.CompilationSuccess) {
            Write-Host "  Test de démarrage: $(if ($result.TestSuccess) { 'Réussi' } else { 'Échoué' })" -ForegroundColor $(if ($result.TestSuccess) { 'Green' } else { 'Red' })
        }
        
        Write-Host ""
    }
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-Host "Durée totale: $($duration.Minutes) minutes et $($duration.Seconds) secondes" -ForegroundColor Magenta
}

# Exécuter la fonction principale
Main