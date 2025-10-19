# Script PowerShell pour tester les fonctionnalités prioritaires du MCP GitHub Projects

# Définir les variables d'environnement pour les tests
$env:GITHUB_TEST_OWNER = "votre-nom-utilisateur" # À remplacer par votre nom d'utilisateur GitHub
$env:GITHUB_TEST_REPO = "votre-repo-test" # À remplacer par un repo de test

# Vérifier si le serveur MCP est en cours d'exécution
$serverRunning = $false
try {
    $response = Invoke-WebRequest -Uri "http://localhost:3002/api/mcp/status" -Method GET -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200) {
        $serverRunning = $true
        Write-Host "Le serveur MCP est en cours d'exécution." -ForegroundColor Green
    }
} catch {
    Write-Host "Le serveur MCP n'est pas en cours d'exécution." -ForegroundColor Yellow
}

# Si le serveur n'est pas en cours d'exécution, proposer de le démarrer
if (-not $serverRunning) {
    $startServer = Read-Host "Voulez-vous démarrer le serveur MCP? (O/N)"
    if ($startServer -eq "O" -or $startServer -eq "o") {
        Write-Host "Démarrage du serveur MCP..." -ForegroundColor Cyan
        Start-Process -FilePath "powershell" -ArgumentList "-c cd 'D:\roo-extensions\mcps\internal\servers\github-projects-mcp'; node dist/index.js" -NoNewWindow
        
        # Attendre que le serveur démarre
        Write-Host "Attente du démarrage du serveur..." -ForegroundColor Cyan
        Start-Sleep -Seconds 5
    } else {
        Write-Host "Les tests ne peuvent pas être exécutés sans le serveur MCP." -ForegroundColor Red
        exit 1
    }
}

# Exécuter les tests
Write-Host "Exécution des tests des fonctionnalités prioritaires..." -ForegroundColor Cyan
node "$PSScriptRoot\test-fonctionnalites-prioritaires.js"

# Vérifier le résultat des tests
if ($LASTEXITCODE -eq 0) {
    Write-Host "Les tests ont réussi!" -ForegroundColor Green
} else {
    Write-Host "Les tests ont échoué." -ForegroundColor Red
}