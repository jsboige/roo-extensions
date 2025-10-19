# Configuration UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

Write-Host "=== CORRECTION FINALE CHEMIN MCP ===" -ForegroundColor Cyan

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
        $rooConfig = $mcp_config.mcpServers.'roo-state-manager'
        
        Write-Host "`nConfiguration actuelle:" -ForegroundColor Yellow
        Write-Host "   Commande: $($rooConfig.command)"
        Write-Host "   Arguments: $($rooConfig.args -join ' ')"
        
        # Rechercher le chemin incorrect dans les arguments
        $currentArgs = $rooConfig.args
        $pathFound = $false
        $correctedPath = $false
        
        for ($i = 0; $i -lt $currentArgs.Count; $i++) {
            $arg = $currentArgs[$i]
            if ($arg -match "build\\src\\index\.js") {
                Write-Host "⚠️ Chemin incorrect détecté dans l'argument $i : $arg" -ForegroundColor Yellow
                
                # Corriger le chemin
                $newArg = $arg -replace "build\\src\\index\.js", "dist\index.js"
                $currentArgs[$i] = $newArg
                
                Write-Host "✅ Chemin corrigé: $newArg" -ForegroundColor Green
                $pathFound = $true
                $correctedPath = $true
            } elseif ($arg -match "dist\\index\.js") {
                Write-Host "✅ Le chemin est déjà correct: $arg" -ForegroundColor Green
                $pathFound = $true
            }
        }
        
        if ($correctedPath) {
            # Mettre à jour la configuration
            $mcp_config.mcpServers.'roo-state-manager'.args = $currentArgs
            
            # Sauvegarder la configuration corrigée
            $mcp_config | ConvertTo-Json | Out-File -FilePath $mcp_settings_path -Encoding UTF8
            Write-Host "✅ Configuration MCP mise à jour" -ForegroundColor Green
            
            Write-Host "`nNouvelle configuration:" -ForegroundColor Yellow
            Write-Host "   Arguments: $($currentArgs -join ' ')"
        } elseif ($pathFound) {
            Write-Host "✅ Le chemin était déjà correct" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Aucun chemin index.js trouvé dans les arguments" -ForegroundColor Yellow
            Write-Host "Arguments actuels:"
            for ($i = 0; $i -lt $currentArgs.Count; $i++) {
                Write-Host "   [$i] $($currentArgs[$i])"
            }
        }
        
        # Afficher les variables d'environnement
        if ($rooConfig.env) {
            Write-Host "`nVariables d'environnement:" -ForegroundColor Yellow
            $rooConfig.env.PSObject.Properties | ForEach-Object {
                if ($_.Name -match "KEY|PASSWORD") {
                    Write-Host "   $($_.Name) = [MASKED]"
                } else {
                    Write-Host "   $($_.Name) = $($_.Value)"
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
    
    # Vérifier si on peut le compiler
    Write-Host "`nTentative de compilation..." -ForegroundColor Yellow
    Set-Location "mcps/internal/servers/roo-state-manager"
    
    try {
        $buildResult = npm run build 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Compilation réussie" -ForegroundColor Green
            
            if (Test-Path "dist/index.js") {
                $fileInfo = Get-Item "dist/index.js"
                Write-Host "   Fichier créé: $($fileInfo.Length) bytes"
            }
        } else {
            Write-Host "❌ Échec de compilation" -ForegroundColor Red
            Write-Host $buildResult
        }
    } catch {
        Write-Host "❌ Erreur compilation: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Set-Location "../../../.."
}

Write-Host "`n=== Test de configuration finale ===" -ForegroundColor Yellow
Write-Host "Pour vérifier que tout fonctionne:"
Write-Host "1. Redémarrez VS Code"
Write-Host "2. Ouvrez un chat Roo"
Write-Host "3. Vérifiez que les outils roo-state-manager apparaissent"
Write-Host "4. Testez un outil comme 'detect_roo_storage'"

Write-Host "`n=== Correction terminée ===" -ForegroundColor Cyan