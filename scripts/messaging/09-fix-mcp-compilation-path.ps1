# Configuration UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

Write-Host "=== CORRECTION CHEMIN DE COMPILATION MCP ===" -ForegroundColor Cyan

$mcp_settings_path = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"

if (-not (Test-Path $mcp_settings_path)) {
    Write-Host "❌ Fichier de configuration MCP non trouvé: $mcp_settings_path" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Fichier de configuration MCP trouvé" -ForegroundColor Green

# Backup du fichier MCP
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupPath = "$mcp_settings_path.backup-$timestamp"
Copy-Item $mcp_settings_path $backupPath
Write-Host "✅ Backup créé: $backupPath" -ForegroundColor Green

try {
    # Lire la configuration actuelle
    $mcp_config = Get-Content $mcp_settings_path | ConvertFrom-Json
    
    if ($mcp_config.mcpServers.'roo-state-manager') {
        $currentPath = $mcp_config.mcpServers.'roo-state-manager'.args[1]
        Write-Host "`nChemin actuel dans la configuration MCP:" -ForegroundColor Yellow
        Write-Host "   $currentPath"
        
        # Vérifier si le chemin actuel est incorrect
        if ($currentPath -match "build\\src\\index\.js") {
            Write-Host "⚠️ Chemin incorrect détecté (build/src/index.js)" -ForegroundColor Yellow
            
            # Corriger le chemin vers dist/index.js
            $newPath = $currentPath -replace "build\\src\\index\.js", "dist\index.js"
            $mcp_config.mcpServers.'roo-state-manager'.args[1] = $newPath
            
            Write-Host "✅ Nouveau chemin corrigé:" -ForegroundColor Green
            Write-Host "   $newPath"
            
            # Sauvegarder la configuration corrigée
            $mcp_config | ConvertTo-Json -Depth 10 | Out-File -FilePath $mcp_settings_path -Encoding UTF8
            Write-Host "✅ Configuration MCP mise à jour" -ForegroundColor Green
            
        } elseif ($currentPath -match "dist\\index\.js") {
            Write-Host "✅ Le chemin est déjà correct (dist/index.js)" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Format de chemin non reconnu: $currentPath" -ForegroundColor Yellow
        }
        
        # Afficher la configuration complète
        Write-Host "`nConfiguration MCP roo-state-manager complète:" -ForegroundColor Yellow
        $rooConfig = $mcp_config.mcpServers.'roo-state-manager'
        Write-Host "   Commande: $($rooConfig.command)"
        Write-Host "   Arguments: $($rooConfig.args -join ' ')"
        
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
    }
    
} catch {
    Write-Host "❌ Erreur lors de la modification: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Restauration du backup..." -ForegroundColor Yellow
    Copy-Item $backupPath $mcp_settings_path
    exit 1
}

Write-Host "`n=== Vérification du fichier compilé ===" -ForegroundColor Yellow
$compiledPath = "mcps/internal/servers/roo-state-manager/dist/index.js"

if (Test-Path $compiledPath) {
    $fileInfo = Get-Item $compiledPath
    Write-Host "✅ Fichier compilé trouvé:" -ForegroundColor Green
    Write-Host "   Chemin: $compiledPath"
    Write-Host "   Taille: $($fileInfo.Length) bytes"
    Write-Host "   Modifié: $($fileInfo.LastWriteTime)"
    
    # Test de syntaxe
    try {
        $testResult = node --check $compiledPath 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Syntaxe JavaScript valide" -ForegroundColor Green
        } else {
            Write-Host "❌ Erreur de syntaxe: $testResult" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Erreur test syntaxe: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "❌ Fichier compilé introuvable: $compiledPath" -ForegroundColor Red
    Write-Host "Veuillez exécuter 'npm run build' dans le dossier roo-state-manager" -ForegroundColor Yellow
}

Write-Host "`n=== Instructions de redémarrage ===" -ForegroundColor Yellow
Write-Host "Pour appliquer les changements:"
Write-Host "1. Fermez complètement VS Code"
Write-Host "2. Rouvrez VS Code"
Write-Host "3. Vérifiez que roo-state-manager apparaît dans les outils MCP"
Write-Host "4. Testez un outil MCP pour confirmer le fonctionnement"

Write-Host "`n=== Correction terminée ===" -ForegroundColor Cyan