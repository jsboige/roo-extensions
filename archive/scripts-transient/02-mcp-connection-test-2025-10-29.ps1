# Script de test de connexion des MCPs - Étape 2 : Test de connexion
# Date: 2025-10-29
# Objectif: Tester la connexion des MCPs et identifier les problèmes spécifiques

Write-Host "=== TEST DE CONNEXION DES MCPs ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date)" -ForegroundColor Gray
Write-Host ""

# Test des MCPs internes
Write-Host "=== TEST DES MCPs INTERNES ===" -ForegroundColor Yellow

$internalMCPs = @{
    "quickfiles" = @{
        "path" = "C:/dev/roo-extensions/mcps/internal/servers/quickfiles-server/build/index.js"
        "type" = "stdio"
        "command" = "node"
    }
    "jinavigator" = @{
        "path" = "C:/dev/roo-extensions/mcps/internal/servers/jinavigator-server/dist/index.js"
        "type" = "stdio"
        "command" = "node"
    }
    "github-projects-mcp" = @{
        "path" = "C:/dev/roo-extensions/mcps/internal/servers/github-projects-mcp/dist/index.js"
        "type" = "http"
        "command" = "node"
        "port" = 3001
    }
    "roo-state-manager" = @{
        "path" = "C:/dev/roo-extensions/mcps/internal/servers/roo-state-manager/build/index.js"
        "type" = "stdio"
        "command" = "node"
    }
}

foreach ($mcpName in $internalMCPs.Keys) {
    $mcp = $internalMCPs[$mcpName]
    Write-Host "=== Test: $mcpName ===" -ForegroundColor Yellow
    
    # Vérifier si le fichier existe
    if (Test-Path $mcp.path) {
        Write-Host "✅ Fichier trouvé: $($mcp.path)" -ForegroundColor Green
        
        # Test de démarrage rapide (timeout de 5 secondes)
        try {
            if ($mcp.type -eq "stdio") {
                $process = Start-Process -FilePath $mcp.command -ArgumentList $mcp.path -PassThru -WindowStyle Hidden
                Start-Sleep -Seconds 2
                if (-not $process.HasExited) {
                    Write-Host "✅ Processus démarré avec succès (PID: $($process.Id))" -ForegroundColor Green
                    $process.Kill()
                } else {
                    Write-Host "❌ Le processus s'est arrêté immédiatement" -ForegroundColor Red
                }
            } elseif ($mcp.type -eq "http") {
                # Test HTTP
                try {
                    $response = Invoke-WebRequest -Uri "http://127.0.0.1:$($mcp.port)/health" -TimeoutSec 3 -ErrorAction Stop
                    Write-Host "✅ Serveur HTTP répond sur le port $($mcp.port)" -ForegroundColor Green
                } catch {
                    Write-Host "❌ Serveur HTTP ne répond pas sur le port $($mcp.port)" -ForegroundColor Red
                    Write-Host "   Erreur: $($_.Exception.Message)" -ForegroundColor Gray
                }
            }
        } catch {
            Write-Host "❌ Erreur lors du test: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ Fichier non trouvé: $($mcp.path)" -ForegroundColor Red
    }
    Write-Host ""
}

# Test des MCPs externes
Write-Host "=== TEST DES MCPs EXTERNES ===" -ForegroundColor Yellow

$externalMCPs = @{
    "markitdown" = @{
        "command" = "C:\\Users\\jsboi\\AppData\\Local\\Programs\\Python\\Python310\\python.exe"
        "args" = @("-m", "markitdown_mcp")
        "type" = "python"
    }
    "playwright" = @{
        "command" = "npx"
        "args" = @("-y", "@playwright/mcp", "--browser", "chromium")
        "type" = "npm"
    }
}

foreach ($mcpName in $externalMCPs.Keys) {
    $mcp = $externalMCPs[$mcpName]
    Write-Host "=== Test: $mcpName ===" -ForegroundColor Yellow
    
    try {
        if ($mcp.type -eq "python") {
            # Test Python
            if (Test-Path $mcp.command) {
                Write-Host "✅ Python trouvé: $($mcp.command)" -ForegroundColor Green
                
                # Test du module
                $process = Start-Process -FilePath $mcp.command -ArgumentList $mcp.args -PassThru -WindowStyle Hidden -RedirectStandardOutput "temp-$mcpName-output.txt" -RedirectStandardError "temp-$mcpName-error.txt"
                Start-Sleep -Seconds 3
                
                if (-not $process.HasExited) {
                    Write-Host "✅ Module Python démarré avec succès" -ForegroundColor Green
                    $process.Kill()
                } else {
                    $errorContent = Get-Content "temp-$mcpName-error.txt" -Raw -ErrorAction SilentlyContinue
                    if ($errorContent) {
                        Write-Host "❌ Erreur module Python: $errorContent" -ForegroundColor Red
                    } else {
                        Write-Host "❌ Le processus Python s'est arrêté immédiatement" -ForegroundColor Red
                    }
                }
                
                # Nettoyage
                Remove-Item "temp-$mcpName-output.txt" -ErrorAction SilentlyContinue
                Remove-Item "temp-$mcpName-error.txt" -ErrorAction SilentlyContinue
            } else {
                Write-Host "❌ Python non trouvé: $($mcp.command)" -ForegroundColor Red
            }
        } elseif ($mcp.type -eq "npm") {
            # Test NPM
            Write-Host "Test du package NPM: $($mcp.args[1])" -ForegroundColor Gray
            
            $process = Start-Process -FilePath $mcp.command -ArgumentList $mcp.args -PassThru -WindowStyle Hidden -RedirectStandardOutput "temp-$mcpName-output.txt" -RedirectStandardError "temp-$mcpName-error.txt"
            Start-Sleep -Seconds 5
            
            if (-not $process.HasExited) {
                Write-Host "✅ Package NPM démarré avec succès" -ForegroundColor Green
                $process.Kill()
            } else {
                $errorContent = Get-Content "temp-$mcpName-error.txt" -Raw -ErrorAction SilentlyContinue
                if ($errorContent) {
                    Write-Host "❌ Erreur package NPM: $errorContent" -ForegroundColor Red
                } else {
                    Write-Host "❌ Le processus NPM s'est arrêté immédiatement" -ForegroundColor Red
                }
            }
            
            # Nettoyage
            Remove-Item "temp-$mcpName-output.txt" -ErrorAction SilentlyContinue
            Remove-Item "temp-$mcpName-error.txt" -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Host "❌ Erreur lors du test: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "=== FIN DES TESTS ===" -ForegroundColor Cyan