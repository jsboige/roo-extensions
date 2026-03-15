# Compilation et recherche des fonctionnalités de messagerie
Set-Location "mcps/internal/servers/roo-state-manager"

Write-Host "=== COMPILATION ET RECHERCHE MESSAGING ===" -ForegroundColor Cyan

# Etape 1: Compilation
Write-Host "`n=== ETAPE 1: COMPILATION ===" -ForegroundColor Yellow
if (-not (Test-Path "dist")) {
    Write-Host "Compilation en cours..." -ForegroundColor Green
    npm run build
    
    if (Test-Path "dist/index.js") {
        Write-Host "✅ Compilation réussie" -ForegroundColor Green
    } else {
        Write-Host "❌ Échec de compilation" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "✅ Déjà compilé" -ForegroundColor Green
}

# Etape 2: Recherche des fonctionnalités de messagerie
Write-Host "`n=== ETAPE 2: RECHERCHE MESSAGING ===" -ForegroundColor Yellow

# Chercher dans les fichiers source
Write-Host "Recherche dans les fichiers source TypeScript..." -ForegroundColor Green
$messagingFiles = Get-ChildItem -Path "src" -Recurse -Filter "*.ts" -ErrorAction SilentlyContinue | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    if ($content -match 'messaging|inter.agent|communication|agent') {
        Write-Host "📄 Fichier trouvé: $($_.Name)" -ForegroundColor Cyan
        $_.FullName
    }
}

# Chercher les variables d'environnement liées à la messagerie
Write-Host "`nRecherche des variables d'environnement..." -ForegroundColor Green
$envVars = @()
Get-ChildItem -Path "src" -Recurse -Filter "*.ts" -ErrorAction SilentlyContinue | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    if ($content -match 'process\.env\.(\w+)') {
        $envVars += $matches[1]
    }
}
$envVars = $envVars | Sort-Object -Unique
Write-Host "Variables d'environnement trouvées:" -ForegroundColor Yellow
$envVars | ForEach-Object { Write-Host "  - $_" }

# Chercher dans les outils MCP
Write-Host "`nRecherche dans les outils MCP..." -ForegroundColor Green
if (Test-Path "src/index.ts") {
    $indexContent = Get-Content "src/index.ts" -Raw
    if ($indexContent -match 'messaging|inter.agent|communication') {
        Write-Host "✅ Fonctionnalités de messagerie trouvées dans index.ts" -ForegroundColor Green
    }
}

Write-Host "`n=== FIN COMPILATION ET RECHERCHE ===" -ForegroundColor Green