# Test simple du serveur win-cli
Write-Host "Test de la configuration win-cli" -ForegroundColor Cyan

# Test 1: Verification du fichier de configuration
$configPath = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"
Write-Host "1. Verification de la configuration..." -ForegroundColor Yellow

if (Test-Path $configPath) {
    Write-Host "   Configuration trouvee" -ForegroundColor Green
    
    $content = Get-Content $configPath -Raw -Encoding UTF8
    $config = $content | ConvertFrom-Json
    
    if ($config.security.allowedPaths -contains "d:\roo-extensions") {
        Write-Host "   Chemin d:\roo-extensions autorise" -ForegroundColor Green
    } else {
        Write-Host "   Chemin d:\roo-extensions manquant" -ForegroundColor Red
    }
} else {
    Write-Host "   Configuration non trouvee" -ForegroundColor Red
}

# Test 2: Test d'acces au repertoire
Write-Host "2. Test d'acces au repertoire..." -ForegroundColor Yellow
if (Test-Path "d:\roo-extensions") {
    Write-Host "   Repertoire accessible" -ForegroundColor Green
} else {
    Write-Host "   Repertoire non accessible" -ForegroundColor Red
}

# Test 3: Test du script de gestion
Write-Host "3. Test du script de gestion..." -ForegroundColor Yellow
$result = powershell.exe -File "d:\roo-extensions\mcps\mcp-manager.ps1" status
if ($LASTEXITCODE -eq 0) {
    Write-Host "   Script fonctionne correctement" -ForegroundColor Green
} else {
    Write-Host "   Erreur dans le script" -ForegroundColor Red
}

Write-Host "`nTest termine. Redemarrez VS Code pour appliquer les changements." -ForegroundColor Cyan