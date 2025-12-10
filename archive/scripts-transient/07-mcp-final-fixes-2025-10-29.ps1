# Script de corrections finales pour les MCPs restants
# Date: 2025-10-29
# Objectif: Corriger les 2 MCPs qui échouent encore

Write-Host "=== CORRECTIONS FINALES DES MCPs RESTANTS ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date)" -ForegroundColor Gray
Write-Host ""

# Correction 1: github-projects-mcp - Serveur HTTP non démarré
Write-Host "=== CORRECTION 1: github-projects-mcp ===" -ForegroundColor Yellow

$githubMcpPath = "mcps/internal/servers/github-projects-mcp"
Set-Location $githubMcpPath

Write-Host "Vérification de l'état du serveur..." -ForegroundColor Gray

# Arrêter les processus existants sur le port 3001
try {
    $processes = Get-NetTCPConnection -LocalPort 3001 -ErrorAction SilentlyContinue
    if ($processes) {
        foreach ($proc in $processes) {
            if ($proc.OwningProcess) {
                Write-Host "Arrêt du processus $($proc.OwningProcess) sur le port 3001..." -ForegroundColor Yellow
                Stop-Process -Id $proc.OwningProcess -Force -ErrorAction SilentlyContinue
            }
        }
    }
} catch {
    Write-Host "Aucun processus trouvé sur le port 3001" -ForegroundColor Gray
}

# Démarrer le serveur avec des logs détaillés
Write-Host "Démarrage du serveur github-projects-mcp..." -ForegroundColor Yellow

try {
    # Vérifier si le package.json a un script start
    $packageJson = Get-Content "package.json" | ConvertFrom-Json
    
    if ($packageJson.scripts.start) {
        Write-Host "Démarrage via npm start..." -ForegroundColor Gray
        $process = Start-Process -FilePath "npm" -ArgumentList "start" -PassThru -WindowStyle Normal
    } else {
        Write-Host "Démarrage direct avec node..." -ForegroundColor Gray
        $process = Start-Process -FilePath "node" -ArgumentList "dist/index.js" -PassThru -WindowStyle Normal
    }
    
    Write-Host "Serveur démarré avec PID: $($process.Id)" -ForegroundColor Green
    
    # Attendre que le serveur soit prêt
    Write-Host "Attente du démarrage du serveur..." -ForegroundColor Gray
    Start-Sleep -Seconds 5
    
    # Test de connexion
    try {
        $response = Invoke-WebRequest -Uri "http://127.0.0.1:3001/health" -TimeoutSec 10
        Write-Host "✅ Serveur HTTP répond correctement" -ForegroundColor Green
        Write-Host "Status: $($response.StatusCode)" -ForegroundColor Gray
    } catch {
        Write-Host "❌ Le serveur ne répond pas encore: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Vérification des logs du processus..." -ForegroundColor Yellow
        
        # Le processus est démarré en mode normal pour voir les logs
        Write-Host "Le serveur est démarré en mode normal. Vérifiez la fenêtre pour les logs." -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ Erreur lors du démarrage du serveur: $($_.Exception.Message)" -ForegroundColor Red
}

Set-Location "C:/dev/roo-extensions"

Write-Host ""

# Correction 2: playwright - Problème d'exécution NPM
Write-Host "=== CORRECTION 2: playwright ===" -ForegroundColor Yellow

Write-Host "Réinstallation complète de playwright..." -ForegroundColor Yellow

try {
    # Nettoyage complet
    Write-Host "Nettoyage des installations précédentes..." -ForegroundColor Gray
    npm uninstall -g @playwright/mcp
    npm cache clean --force
    
    # Réinstallation
    Write-Host "Réinstallation de @playwright/mcp..." -ForegroundColor Yellow
    npm install -g @playwright/mcp
    
    # Installation des navigateurs
    Write-Host "Installation des navigateurs..." -ForegroundColor Yellow
    npx playwright install chromium
    
    # Test direct
    Write-Host "Test direct de playwright..." -ForegroundColor Yellow
    
    # Essayer avec différentes méthodes
    $testMethods = @(
        @{ "cmd" = "npx"; "args" = @("-y", "@playwright/mcp", "--browser", "chromium") },
        @{ "cmd" = "npx"; "args" = @("@playwright/mcp", "--browser", "chromium") },
        @{ "cmd" = "node"; "args" = @("node_modules/@playwright/mcp/index.js", "--browser", "chromium") }
    )
    
    $success = $false
    foreach ($method in $testMethods) {
        Write-Host "Test avec: $($method.cmd) $($method.args -join ' ')" -ForegroundColor Gray
        
        try {
            $process = Start-Process -FilePath $method.cmd -ArgumentList $method.args -PassThru -WindowStyle Hidden -RedirectStandardOutput "temp-playwright-output.txt" -RedirectStandardError "temp-playwright-error.txt"
            Start-Sleep -Seconds 3
            
            if (-not $process.HasExited) {
                Write-Host "✅ Playwright démarré avec succès" -ForegroundColor Green
                $process.Kill()
                $success = $true
                break
            } else {
                $errorContent = Get-Content "temp-playwright-error.txt" -Raw -ErrorAction SilentlyContinue
                if ($errorContent) {
                    Write-Host "❌ Erreur: $errorContent" -ForegroundColor Red
                } else {
                    Write-Host "❌ Le processus s'est arrêté immédiatement" -ForegroundColor Red
                }
            }
            
            # Nettoyage
            Remove-Item "temp-playwright-output.txt" -ErrorAction SilentlyContinue
            Remove-Item "temp-playwright-error.txt" -ErrorAction SilentlyContinue
            
        } catch {
            Write-Host "❌ Erreur lors du test: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    if (-not $success) {
        Write-Host "⚠️  Playwright ne fonctionne pas avec les méthodes standards" -ForegroundColor Yellow
        Write-Host "Tentative d'installation alternative..." -ForegroundColor Yellow
        
        # Installation alternative
        try {
            npm install -g playwright
            npm install -g @playwright/test
            Write-Host "✅ Packages Playwright installés" -ForegroundColor Green
        } catch {
            Write-Host "❌ Erreur lors de l'installation alternative: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
} catch {
    Write-Host "❌ Erreur générale lors de la correction de Playwright: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test rapide des corrections
Write-Host "=== TEST RAPIDE DES CORRECTIONS ===" -ForegroundColor Yellow

# Test github-projects-mcp
Write-Host "Test de github-projects-mcp..." -ForegroundColor Gray
try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:3001/health" -TimeoutSec 5 -ErrorAction Stop
    Write-Host "✅ github-projects-mcp : SUCCÈS" -ForegroundColor Green
} catch {
    Write-Host "❌ github-projects-mcp : ÉCHEC - $($_.Exception.Message)" -ForegroundColor Red
}

# Test playwright
Write-Host "Test de playwright..." -ForegroundColor Gray
try {
    $process = Start-Process -FilePath "npx" -ArgumentList @("-y", "@playwright/mcp", "--browser", "chromium") -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 2
    
    if (-not $process.HasExited) {
        Write-Host "✅ playwright : SUCCÈS" -ForegroundColor Green
        $process.Kill()
    } else {
        Write-Host "❌ playwright : ÉCHEC - Le processus s'est arrêté" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ playwright : ÉCHEC - $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== CORRECTIONS TERMINÉES ===" -ForegroundColor Cyan
Write-Host "Redémarrez VS Code pour appliquer toutes les modifications." -ForegroundColor Yellow