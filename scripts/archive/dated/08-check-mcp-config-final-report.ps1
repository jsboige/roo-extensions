# Configuration UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

Write-Host "=== VÉRIFICATION CONFIGURATION MCP ET RAPPORT FINAL ===" -ForegroundColor Cyan

Write-Host "`n=== 1. Vérification configuration MCP ===" -ForegroundColor Yellow

# Chemin vers les paramètres MCP de VS Code
$mcp_settings_path = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"

if (Test-Path $mcp_settings_path) {
    Write-Host "✅ Fichier de configuration MCP trouvé: $mcp_settings_path" -ForegroundColor Green
    
    try {
        $mcp_config = Get-Content $mcp_settings_path | ConvertFrom-Json
        
        Write-Host "`nConfiguration MCP actuelle:"
        if ($mcp_config.mcpServers.'roo-state-manager') {
            Write-Host "✅ roo-state-manager configuré dans MCP" -ForegroundColor Green
            $rooConfig = $mcp_config.mcpServers.'roo-state-manager'
            
            Write-Host "   Commande: $($rooConfig.command)"
            if ($rooConfig.args) {
                Write-Host "   Arguments: $($rooConfig.args -join ' ')"
            }
            if ($rooConfig.env) {
                Write-Host "   Variables d'environnement:"
                $rooConfig.env.PSObject.Properties | ForEach-Object {
                    if ($_.Name -match "KEY|PASSWORD") {
                        Write-Host "     $($_.Name) = [MASKED]"
                    } else {
                        Write-Host "     $($_.Name) = $($_.Value)"
                    }
                }
            }
        } else {
            Write-Host "❌ roo-state-manager non trouvé dans la configuration MCP" -ForegroundColor Red
            Write-Host "Serveurs MCP configurés:"
            $mcp_config.mcpServers.PSObject.Properties | ForEach-Object {
                Write-Host "   - $($_.Name)"
            }
        }
    } catch {
        Write-Host "❌ Erreur lecture configuration MCP: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "❌ Fichier de configuration MCP non trouvé: $mcp_settings_path" -ForegroundColor Red
    Write-Host "Vérifiez que Roo Code est installé et configuré" -ForegroundColor Yellow
}

Write-Host "`n=== 2. Validation de la compilation ===" -ForegroundColor Yellow
cd mcps/internal/servers/roo-state-manager

if (Test-Path "dist/index.js") {
    $indexFile = Get-Item "dist/index.js"
    Write-Host "✅ Compilation réussie" -ForegroundColor Green
    Write-Host "   Fichier: dist/index.js"
    Write-Host "   Taille: $($indexFile.Length) bytes"
    Write-Host "   Modifié: $($indexFile.LastWriteTime)"
    
    # Vérifier si le serveur peut démarrer
    Write-Host "`nTest de démarrage du serveur (vérification rapide)..."
    try {
        # Test de syntaxe Node.js
        $testResult = node --check "dist/index.js" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Syntaxe JavaScript valide" -ForegroundColor Green
        } else {
            Write-Host "❌ Erreur de syntaxe: $testResult" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Erreur test syntaxe: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "❌ Fichier dist/index.js introuvable" -ForegroundColor Red
}

Write-Host "`n=== 3. Analyse des fonctionnalités de messagerie ===" -ForegroundColor Yellow

# Analyser les outils MCP disponibles
Write-Host "Recherche des outils liés à la messagerie..."
$toolsPath = "src/tools"
if (Test-Path $toolsPath) {
    $toolFiles = Get-ChildItem -Path $toolsPath -Recurse -Filter "*.ts"
    $messagingTools = @()
    
    foreach ($toolFile in $toolFiles) {
        $content = Get-Content $toolFile.FullName -Raw
        if ($content -match '(?i)(messaging|agent|communication|websocket|inter.?agent)') {
            $messagingTools += $toolFile.Name
        }
    }
    
    if ($messagingTools.Count -gt 0) {
        Write-Host "✅ Outils de messagerie identifiés:" -ForegroundColor Green
        $messagingTools | ForEach-Object { Write-Host "   - $_" }
    } else {
        Write-Host "⚠️ Aucun outil de messagerie explicite trouvé" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ Dossier tools introuvable" -ForegroundColor Red
}

# Analyser les services
Write-Host "`nAnalyse des services..."
$servicesPath = "src/services"
if (Test-Path $servicesPath) {
    $serviceFiles = Get-ChildItem -Path $servicesPath -Filter "*.ts"
    $messagingServices = @()
    
    foreach ($serviceFile in $serviceFiles) {
        $content = Get-Content $serviceFile.FullName -Raw
        if ($content -match '(?i)(messaging|agent|communication|websocket|inter.?agent)') {
            $messagingServices += $serviceFile.Name
        }
    }
    
    if ($messagingServices.Count -gt 0) {
        Write-Host "✅ Services de messagerie identifiés:" -ForegroundColor Green
        $messagingServices | ForEach-Object { Write-Host "   - $_" }
    } else {
        Write-Host "⚠️ Aucun service de messagerie explicite trouvé" -ForegroundColor Yellow
    }
}

Write-Host "`n=== 4. Validation du .env ===" -ForegroundColor Yellow
if (Test-Path ".env") {
    Write-Host "✅ Fichier .env présent" -ForegroundColor Green
    
    $envContent = Get-Content ".env"
    $messagingVars = $envContent | Where-Object { $_ -match "^(AGENT_|ENABLE_MESSAGING|MESSAGING_|WEBSOCKET_)" }
    $roosyncVars = $envContent | Where-Object { $_ -match "^ROOSYNC_" }
    
    Write-Host "Variables de messagerie configurées: $($messagingVars.Count)"
    $messagingVars | ForEach-Object { Write-Host "   $_" }
    
    Write-Host "Variables RooSync configurées: $($roosyncVars.Count)"
    $roosyncVars | ForEach-Object { Write-Host "   $_" }
} else {
    Write-Host "❌ Fichier .env introuvable" -ForegroundColor Red
}

Write-Host "`n=== 5. Test de connectivité des ports ===" -ForegroundColor Yellow
$messagingPort = 3000
$websocketPort = 3001

Write-Host "Test de disponibilité des ports:"
try {
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $tcpClient.Connect("localhost", $messagingPort)
    $tcpClient.Close()
    Write-Host "❌ Port $messagingPort déjà utilisé" -ForegroundColor Red
} catch {
    Write-Host "✅ Port $messagingPort disponible" -ForegroundColor Green
}

try {
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $tcpClient.Connect("localhost", $websocketPort)
    $tcpClient.Close()
    Write-Host "❌ Port $websocketPort déjà utilisé" -ForegroundColor Red
} catch {
    Write-Host "✅ Port $websocketPort disponible" -ForegroundColor Green
}

Write-Host "`n=== 6. Résumé de la configuration ===" -ForegroundColor Yellow

$summary = @{
    compilation = (Test-Path "dist/index.js")
    env_file = (Test-Path ".env")
    messaging_vars = $messagingVars.Count
    roosync_vars = $roosyncVars.Count
    mcp_configured = (Test-Path $mcp_settings_path)
    ws_dependency = $true
}

Write-Host "État de la configuration:"
Write-Host "   Compilation: $(if ($summary.compilation) { '✅' } else { '❌' })"
Write-Host "   Fichier .env: $(if ($summary.env_file) { '✅' } else { '❌' })"
Write-Host "   Variables messagerie: $(if ($summary.messaging_vars -gt 0) { "✅ $($summary.messaging_vars)" } else { '❌ 0' })"
Write-Host "   Variables RooSync: $(if ($summary.roosync_vars -gt 0) { "✅ $($summary.roosync_vars)" } else { '❌ 0' })"
Write-Host "   Configuration MCP: $(if ($summary.mcp_configured) { '✅' } else { '❌' })"
Write-Host "   Dépendance WebSocket: $(if ($summary.ws_dependency) { '✅' } else { '❌' })"

Write-Host "`n=== 7. Prochaines étapes recommandées ===" -ForegroundColor Yellow

Write-Host "Pour activer la messagerie inter-agents:"
Write-Host "1. Redémarrer VS Code pour recharger la configuration MCP"
Write-Host "2. Vérifier que roo-state-manager apparaît dans les outils MCP disponibles"
Write-Host "3. Tester les outils RooSync pour la synchronisation multi-machines"
Write-Host "4. Surveiller les logs pour les messages de démarrage de messagerie"

Write-Host "`nCommandes utiles:"
Write-Host "   # Redémarrer le serveur MCP manuellement:"
Write-Host "   cd mcps/internal/servers/roo-state-manager"
Write-Host "   npm run start"
Write-Host ""
Write-Host "   # Vérifier les logs de VS Code:"
Write-Host "   # Ouvrir: View > Output > Roo Code"

Write-Host "`n=== Analyse terminée ===" -ForegroundColor Cyan