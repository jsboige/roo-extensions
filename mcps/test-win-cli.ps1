# Script de test pour le serveur win-cli
# Teste si les restrictions de chemin ont été levées

Write-Host "Test du serveur win-cli - Verification des restrictions de chemin" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

# Test 1: Commande simple dans le répertoire autorisé
Write-Host "`n1. Test commande simple dans d:\roo-extensions..." -ForegroundColor Yellow
try {
    $result = powershell.exe -File d:\roo-extensions\mcps\mcp-manager.ps1 status
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Succès - Script exécuté sans erreur" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Échec - Code de sortie: $LASTEXITCODE" -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ Erreur: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Vérification de l'accès au répertoire
Write-Host "`n2. Test accès au répertoire d:\roo-extensions..." -ForegroundColor Yellow
if (Test-Path "d:\roo-extensions") {
    Write-Host "   ✅ Répertoire accessible" -ForegroundColor Green
    $items = Get-ChildItem "d:\roo-extensions" | Measure-Object
    Write-Host "   📁 Nombre d'éléments: $($items.Count)" -ForegroundColor White
} else {
    Write-Host "   ❌ Répertoire non accessible" -ForegroundColor Red
}

# Test 3: Vérification des sauvegardes
Write-Host "`n3. Test accès aux sauvegardes..." -ForegroundColor Yellow
$backupDir = "d:\roo-extensions\mcps\backups"
if (Test-Path $backupDir) {
    $backups = Get-ChildItem $backupDir -Filter "*.json" | Measure-Object
    Write-Host "   ✅ Répertoire de sauvegarde accessible" -ForegroundColor Green
    Write-Host "   💾 Nombre de sauvegardes: $($backups.Count)" -ForegroundColor White
} else {
    Write-Host "   ❌ Répertoire de sauvegarde non accessible" -ForegroundColor Red
}

# Test 4: Validation de la configuration MCP
Write-Host "`n4. Test validation configuration MCP..." -ForegroundColor Yellow
. "$PSScriptRoot\..\scripts\common\extension-paths.ps1"
$configPath = Get-McpSettingsPath -Extension RooCode
if (Test-Path $configPath) {
    try {
        $content = Get-Content $configPath -Raw -Encoding UTF8
        $config = $content | ConvertFrom-Json
        
        if ($config.security -and $config.security.allowedPaths) {
            $allowedPaths = $config.security.allowedPaths
            if ($allowedPaths -contains "d:\roo-extensions") {
                Write-Host "   ✅ Chemin d:\roo-extensions présent dans allowedPaths" -ForegroundColor Green
            } else {
                Write-Host "   ❌ Chemin d:\roo-extensions manquant dans allowedPaths" -ForegroundColor Red
            }
            
            Write-Host "   📋 Chemins autorisés:" -ForegroundColor White
            foreach ($path in $allowedPaths) {
                Write-Host "      - $path" -ForegroundColor Gray
            }
        } else {
            Write-Host "   ⚠️  Section security.allowedPaths non trouvée" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "   ❌ Erreur de validation JSON: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "   ❌ Fichier de configuration non trouvé" -ForegroundColor Red
}

Write-Host "`n" -NoNewline
Write-Host "Test terminé - " -ForegroundColor Cyan -NoNewline
Write-Host "Le serveur win-cli devrait maintenant accepter les commandes dans d:\roo-extensions" -ForegroundColor Green
Write-Host "Redémarrez VS Code pour que les modifications prennent effet." -ForegroundColor Yellow