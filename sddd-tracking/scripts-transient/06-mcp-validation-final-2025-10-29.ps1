# Script de validation finale des MCPs - Étape 4 : Validation complète
# Date: 2025-10-29
# Objectif: Valider que tous les MCPs se connectent correctement après correction

Write-Host "=== VALIDATION FINALE DES MCPs ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date)" -ForegroundColor Gray
Write-Host ""

# Test des MCPs internes
Write-Host "=== VALIDATION DES MCPs INTERNES ===" -ForegroundColor Yellow

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

$validationResults = @()

foreach ($mcpName in $internalMCPs.Keys) {
    $mcp = $internalMCPs[$mcpName]
    Write-Host "=== Validation: $mcpName ===" -ForegroundColor Yellow
    
    $result = @{
        "name" = $mcpName
        "type" = $mcp.type
        "status" = "FAILED"
        "error" = $null
        "details" = @()
    }
    
    # Vérifier si le fichier existe
    if (Test-Path $mcp.path) {
        $result.details += "✅ Fichier trouvé: $($mcp.path)"
        
        # Test de démarrage
        try {
            if ($mcp.type -eq "stdio") {
                $process = Start-Process -FilePath $mcp.command -ArgumentList $mcp.path -PassThru -WindowStyle Hidden -RedirectStandardOutput "temp-$mcpName-output.txt" -RedirectStandardError "temp-$mcpName-error.txt"
                Start-Sleep -Seconds 3
                
                if (-not $process.HasExited) {
                    $result.status = "SUCCESS"
                    $result.details += "✅ Processus démarré avec succès (PID: $($process.Id))"
                    $process.Kill()
                } else {
                    $errorContent = Get-Content "temp-$mcpName-error.txt" -Raw -ErrorAction SilentlyContinue
                    if ($errorContent) {
                        $result.error = $errorContent
                        $result.details += "❌ Le processus s'est arrêté: $errorContent"
                    } else {
                        $result.details += "❌ Le processus s'est arrêté immédiatement"
                    }
                }
                
                # Nettoyage
                Remove-Item "temp-$mcpName-output.txt" -ErrorAction SilentlyContinue
                Remove-Item "temp-$mcpName-error.txt" -ErrorAction SilentlyContinue
            } elseif ($mcp.type -eq "http") {
                # Test HTTP
                try {
                    $response = Invoke-WebRequest -Uri "http://127.0.0.1:$($mcp.port)/health" -TimeoutSec 5 -ErrorAction Stop
                    $result.status = "SUCCESS"
                    $result.details += "✅ Serveur HTTP répond sur le port $($mcp.port)"
                } catch {
                    $result.error = $_.Exception.Message
                    $result.details += "❌ Serveur HTTP ne répond pas: $($_.Exception.Message)"
                }
            }
        } catch {
            $result.error = $_.Exception.Message
            $result.details += "❌ Erreur lors du test: $($_.Exception.Message)"
        }
    } else {
        $result.error = "Fichier non trouvé"
        $result.details += "❌ Fichier non trouvé: $($mcp.path)"
    }
    
    $validationResults += $result
    
    # Affichage du résultat
    if ($result.status -eq "SUCCESS") {
        Write-Host "✅ $mcpName : SUCCÈS" -ForegroundColor Green
    } else {
        Write-Host "❌ $mcpName : ÉCHEC" -ForegroundColor Red
        if ($result.error) {
            Write-Host "   Erreur: $($result.error)" -ForegroundColor Gray
        }
    }
    
    foreach ($detail in $result.details) {
        Write-Host "   $detail" -ForegroundColor Gray
    }
    Write-Host ""
}

# Test des MCPs externes
Write-Host "=== VALIDATION DES MCPs EXTERNES ===" -ForegroundColor Yellow

$externalMCPs = @{
    "markitdown" = @{
        "command" = "C:\Users\jsboi\AppData\Local\Programs\Python\Python311\python.exe"
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
    Write-Host "=== Validation: $mcpName ===" -ForegroundColor Yellow
    
    $result = @{
        "name" = $mcpName
        "type" = $mcp.type
        "status" = "FAILED"
        "error" = $null
        "details" = @()
    }
    
    try {
        if ($mcp.type -eq "python") {
            # Test Python
            if (Test-Path $mcp.command) {
                $result.details += "✅ Python trouvé: $($mcp.command)"
                
                # Test du module
                $process = Start-Process -FilePath $mcp.command -ArgumentList $mcp.args -PassThru -WindowStyle Hidden -RedirectStandardOutput "temp-$mcpName-output.txt" -RedirectStandardError "temp-$mcpName-error.txt"
                Start-Sleep -Seconds 3
                
                if (-not $process.HasExited) {
                    $result.status = "SUCCESS"
                    $result.details += "✅ Module Python démarré avec succès"
                    $process.Kill()
                } else {
                    $errorContent = Get-Content "temp-$mcpName-error.txt" -Raw -ErrorAction SilentlyContinue
                    if ($errorContent) {
                        $result.error = $errorContent
                        $result.details += "❌ Erreur module Python: $errorContent"
                    } else {
                        $result.details += "❌ Le processus Python s'est arrêté immédiatement"
                    }
                }
                
                # Nettoyage
                Remove-Item "temp-$mcpName-output.txt" -ErrorAction SilentlyContinue
                Remove-Item "temp-$mcpName-error.txt" -ErrorAction SilentlyContinue
            } else {
                $result.error = "Python non trouvé"
                $result.details += "❌ Python non trouvé: $($mcp.command)"
            }
        } elseif ($mcp.type -eq "npm") {
            # Test NPM
            $result.details += "Test du package NPM: $($mcp.args[1])"
            
            $process = Start-Process -FilePath $mcp.command -ArgumentList $mcp.args -PassThru -WindowStyle Hidden -RedirectStandardOutput "temp-$mcpName-output.txt" -RedirectStandardError "temp-$mcpName-error.txt"
            Start-Sleep -Seconds 5
            
            if (-not $process.HasExited) {
                $result.status = "SUCCESS"
                $result.details += "✅ Package NPM démarré avec succès"
                $process.Kill()
            } else {
                $errorContent = Get-Content "temp-$mcpName-error.txt" -Raw -ErrorAction SilentlyContinue
                if ($errorContent) {
                    $result.error = $errorContent
                    $result.details += "❌ Erreur package NPM: $errorContent"
                } else {
                    $result.details += "❌ Le processus NPM s'est arrêté immédiatement"
                }
            }
            
            # Nettoyage
            Remove-Item "temp-$mcpName-output.txt" -ErrorAction SilentlyContinue
            Remove-Item "temp-$mcpName-error.txt" -ErrorAction SilentlyContinue
        }
    } catch {
        $result.error = $_.Exception.Message
        $result.details += "❌ Erreur lors du test: $($_.Exception.Message)"
    }
    
    $validationResults += $result
    
    # Affichage du résultat
    if ($result.status -eq "SUCCESS") {
        Write-Host "✅ $mcpName : SUCCÈS" -ForegroundColor Green
    } else {
        Write-Host "❌ $mcpName : ÉCHEC" -ForegroundColor Red
        if ($result.error) {
            Write-Host "   Erreur: $($result.error)" -ForegroundColor Gray
        }
    }
    
    foreach ($detail in $result.details) {
        Write-Host "   $detail" -ForegroundColor Gray
    }
    Write-Host ""
}

# Résumé final
Write-Host "=== RÉSUMÉ FINAL DE LA VALIDATION ===" -ForegroundColor Cyan
Write-Host ""

$successCount = 0
$failureCount = 0

foreach ($result in $validationResults) {
    if ($result.status -eq "SUCCESS") {
        $successCount++
        Write-Host "✅ $($result.name) : SUCCÈS" -ForegroundColor Green
    } else {
        $failureCount++
        Write-Host "❌ $($result.name) : ÉCHEC" -ForegroundColor Red
        if ($result.error) {
            Write-Host "   Erreur: $($result.error)" -ForegroundColor Gray
        }
    }
}

Write-Host ""
Write-Host "=== STATISTIQUES ===" -ForegroundColor Cyan
Write-Host "Total des MCPs testés: $($validationResults.Count)" -ForegroundColor White
Write-Host "Succès: $successCount" -ForegroundColor Green
Write-Host "Échecs: $failureCount" -ForegroundColor Red

if ($failureCount -eq 0) {
    Write-Host ""
    Write-Host "🎉 TOUS LES MCPs FONCTIONNENT CORRECTEMENT !" -ForegroundColor Green
    Write-Host "L'environnement est maintenant stable et opérationnel." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "⚠️  $failureCount MCP(s) ont encore des problèmes" -ForegroundColor Yellow
    Write-Host "Des investigations supplémentaires sont nécessaires." -ForegroundColor Yellow
}

# Export du rapport de validation
$reportPath = "scripts/mcp-validation-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$validationResults | ConvertTo-Json -Depth 3 | Out-File -FilePath $reportPath
Write-Host ""
Write-Host "Rapport de validation exporté vers: $reportPath" -ForegroundColor Cyan

Write-Host ""
Write-Host "=== FIN DE LA VALIDATION ===" -ForegroundColor Cyan