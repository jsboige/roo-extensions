# Script de test complet pour github-projects-mcp
# Diagnostic approfondi des problèmes de connexion

Write-Host "🔍 TEST COMPLET DU MCP GITHUB-PROJECTS-MCP" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# 1. Test de démarrage du serveur
Write-Host "🚀 Démarrage du serveur en mode debug..." -ForegroundColor Yellow

Set-Location mcps/internal/servers/github-projects-mcp
$env:MCP_DEBUG_LOGGING=true
$env:GITHUB_TOKEN=ghp_test_token_for_debugging

# Démarrer le serveur en arrière-plan
Start-Process -FilePath "node" -ArgumentList "dist/index.js" -WorkingDirectory $PWD -WindowStyle Hidden

# Attendre 3 secondes pour le démarrage
Start-Sleep -Seconds 3

# 2. Test de connectivité HTTP
Write-Host "🌐 Test de connectivité HTTP..." -ForegroundColor Yellow

try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:3001/health" -TimeoutSec 10 -UseBasicParsing $false
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ Serveur HTTP répond (Status: $($response.StatusCode))" -ForegroundColor Green
        
        # Test avec un endpoint simple
        $testResponse = Invoke-WebRequest -Uri "http://127.0.0.1:3001/test" -TimeoutSec 5 -UseBasicParsing $false
        Write-Host "📡 Test endpoint /test : Status $($testResponse.StatusCode)" -ForegroundColor White
    } else {
        Write-Host "❌ Serveur HTTP ne répond pas (Status: $($response.StatusCode))" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Erreur de connexion HTTP: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. Vérification des logs
Write-Host "📁 Vérification des logs..." -ForegroundColor Yellow

if (Test-Path "logs\github-projects-mcp-error.log") {
    Write-Host "✅ Fichier de log d'erreurs créé" -ForegroundColor Green
    $errorLog = Get-Content "logs\github-projects-mcp-error.log"
    Write-Host "📄 Contenu du log d'erreurs :" -ForegroundColor White
    Write-Host $errorLog
} else {
    Write-Host "❌ Fichier de log d'erreurs non trouvé" -ForegroundColor Red
}

if (Test-Path "logs\github-projects-mcp-combined.log") {
    Write-Host "✅ Fichier de log combiné créé" -ForegroundColor Green
    $combinedLog = Get-Content "logs\github-projects-mcp-combined.log"
    Write-Host "📄 Contenu du log combiné :" -ForegroundColor White
    Write-Host $combinedLog
} else {
    Write-Host "❌ Fichier de log combiné non trouvé" -ForegroundColor Red
}

# 4. Test de l'outil MCP
Write-Host "🔧 Test de l'outil list_projects..." -ForegroundColor Yellow

try {
    $testBody = @{
        owner = "jsboige"
    } | ConvertTo-Json -Compress
    
    $mcpResponse = Invoke-WebRequest -Uri "http://127.0.0.1:3001/mcp" -Method POST -ContentType "application/json" -Body $testBody -TimeoutSec 10 -UseBasicParsing $false
    
    if ($mcpResponse.StatusCode -eq 200) {
        $responseData = $mcpResponse.Content | ConvertFrom-Json
        Write-Host "✅ Réponse MCP reçue (Status: $($mcpResponse.StatusCode))" -ForegroundColor Green
        Write-Host "📄 Réponse :" -ForegroundColor White
        Write-Host $responseData
    } else {
        Write-Host "❌ Erreur appel MCP (Status: $($mcpResponse.StatusCode))" -ForegroundColor Red
        Write-Host "📄 Réponse d'erreur :" -ForegroundColor White
        Write-Host $mcpResponse.Content
    }
} catch {
    Write-Host "❌ Erreur lors du test MCP: $($_.Exception.Message)" -ForegroundColor Red
}

# 5. Diagnostic des variables d'environnement
Write-Host "🔍 Diagnostic des variables d'environnement..." -ForegroundColor Yellow

Write-Host "📋 Variables MCP_DEBUG_LOGGING :" -ForegroundColor Cyan
Write-Host "  Actuel: $env:MCP_DEBUG_LOGGING" -ForegroundColor White

Write-Host "📋 Variables GITHUB_TOKEN :" -ForegroundColor Cyan
Write-Host "  Actuel: $env:GITHUB_TOKEN" -ForegroundColor White
Write-Host "  Longueur: $($env:GITHUB_TOKEN.Length)" -ForegroundColor White

Write-Host "📋 Variables GITHUB_ACCOUNTS_JSON :" -ForegroundColor Cyan
Write-Host "  Actuel: $env:GITHUB_ACCOUNTS_JSON" -ForegroundColor White

Write-Host "📋 Variables NODE_ENV :" -ForegroundColor Cyan
Write-Host "  Actuel: $env:NODE_ENV" -ForegroundColor White

# 6. Test de résolution de token
Write-Host "🔧 Test de résolution de token..." -ForegroundColor Yellow

$testToken = "ghp_test_token_for_debugging"
$env:GITHUB_TOKEN_RESOLVED = $testToken

# Test avec le token résolu
$testBodyResolved = @{
    owner = "jsboige"
} | ConvertTo-Json -Compress

try {
    $mcpResponseResolved = Invoke-WebRequest -Uri "http://127.0.0.1:3001/mcp" -Method POST -ContentType "application/json" -Body $testBodyResolved -TimeoutSec 10 -UseBasicParsing $false
    
    if ($mcpResponseResolved.StatusCode -eq 200) {
        $responseDataResolved = $mcpResponseResolved.Content | ConvertFrom-Json
        Write-Host "✅ Test avec token résolu réussi" -ForegroundColor Green
        Write-Host "📄 Réponse :" -ForegroundColor White
        Write-Host $responseDataResolved
    } else {
        Write-Host "❌ Test avec token résolu échoué" -ForegroundColor Red
        Write-Host "📄 Réponse d'erreur :" -ForegroundColor White
        Write-Host $mcpResponseResolved.Content
    }
} catch {
    Write-Host "❌ Erreur lors du test de résolution: $($_.Exception.Message)" -ForegroundColor Red
}

# Nettoyage
Stop-Process -Name "node" -ErrorAction SilentlyContinue

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "📊 RÉSUMÉ DU DIAGNOSTIC" -ForegroundColor Green
Write-Host "Le script va maintenant nettoyer les processus et quitter." -ForegroundColor Yellow
Write-Host "Appuyez sur une touche pour terminer..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoKey,IncludeKeyDown")