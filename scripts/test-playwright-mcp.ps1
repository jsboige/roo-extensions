# Script de test pour le MCP Playwright
# Test la connexion et les fonctionnalités de base

Write-Host "🎭 Test du MCP Playwright - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan

try {
    Write-Host "📋 Test 1: Vérification de la version..." -ForegroundColor Yellow
    $version = & npx -y @playwright/mcp --browser chromium --version 2>$null
    if ($version -match "Version 0.0.45") {
        Write-Host "✅ Version correcte: $version" -ForegroundColor Green
    } else {
        Write-Host "❌ Version incorrecte: $version" -ForegroundColor Red
    }

    Write-Host "📋 Test 2: Test de démarrage simple..." -ForegroundColor Yellow
    # Test avec un timeout court pour éviter le blocage
    $process = Start-Process -FilePath "npx" -ArgumentList "-y","@playwright/mcp","--browser","chromium","--headless","--timeout-action","1000" -PassThru -WindowStyle Hidden
    
    Start-Sleep -Seconds 2
    
    if (!$process.HasExited) {
        Write-Host "✅ MCP démarré avec succès (PID: $($process.Id))" -ForegroundColor Green
        $process.Kill()
        Write-Host "✅ Test de démarrage réussi" -ForegroundColor Green
    } else {
        Write-Host "❌ Échec du démarrage" -ForegroundColor Red
    }

} catch {
    Write-Host "❌ Erreur lors du test: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "🏁 Test terminé - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan