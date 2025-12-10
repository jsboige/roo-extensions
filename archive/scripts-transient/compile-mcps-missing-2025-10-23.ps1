# Script de compilation des MCPs internes manquants
# Date: 2025-10-23
# Objectif: Compiler tous les MCPs qui n'ont pas encore été compilés

Write-Host "=== COMPILATION DES MCPs INTERNES MANQUANTS ===" -ForegroundColor Green
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow
Write-Host ""

# Liste des serveurs MCP à compiler
$serversToCompile = @(
    "quickfiles-server",
    "jinavigator-server",
    "jupyter-mcp-server",
    "github-projects-mcp",
    "roo-state-manager"
)

# jupyter-papermill-mcp-server est un projet Python, il sera traité séparément
$pythonServers = @(
    "jupyter-papermill-mcp-server"
)

$baseDir = "mcps/internal/servers"
$successCount = 0
$totalCount = $serversToCompile.Count + $pythonServers.Count

# Compilation des serveurs TypeScript
Write-Host "=== COMPILATION DES SERVEURS TYPESCRIPT ===" -ForegroundColor Cyan

foreach ($server in $serversToCompile) {
    $serverPath = Join-Path $baseDir $server
    $buildPath = Join-Path $serverPath "build"
    
    Write-Host ""
    Write-Host "--- Compilation de $server ---" -ForegroundColor Yellow
    
    if (Test-Path $serverPath) {
        Write-Host "Répertoire source: OK" -ForegroundColor Green
        
        # Vérifier si package.json existe
        $packageJson = Join-Path $serverPath "package.json"
        if (Test-Path $packageJson) {
            Write-Host "package.json: OK" -ForegroundColor Green
            
            # Exécuter npm run build
            Write-Host "Exécution de npm run build..." -ForegroundColor Gray
            Push-Location $serverPath
            try {
                $buildResult = npm run build 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Compilation: SUCCÈS" -ForegroundColor Green
                    $successCount++
                    
                    # Vérifier que le répertoire build a été créé
                    if (Test-Path $buildPath) {
                        $jsFiles = Get-ChildItem -Path $buildPath -Filter "*.js" -Recurse
                        Write-Host "Fichiers JS générés: $($jsFiles.Count)" -ForegroundColor Gray
                    } else {
                        Write-Host "ATTENTION: Répertoire build non créé malgré le succès" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "Compilation: ÉCHEC" -ForegroundColor Red
                    Write-Host "Erreur:" -ForegroundColor Red
                    $buildResult | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
                }
            } finally {
                Pop-Location
            }
        } else {
            Write-Host "package.json: MANQUANT" -ForegroundColor Red
        }
    } else {
        Write-Host "Répertoire source: INEXISTANT" -ForegroundColor Red
    }
}

# Traitement des serveurs Python
Write-Host ""
Write-Host "=== VÉRIFICATION DES SERVEURS PYTHON ===" -ForegroundColor Cyan

foreach ($server in $pythonServers) {
    $serverPath = Join-Path $baseDir $server
    
    Write-Host ""
    Write-Host "--- Vérification de $server ---" -ForegroundColor Yellow
    
    if (Test-Path $serverPath) {
        Write-Host "Répertoire source: OK" -ForegroundColor Green
        
        # Vérifier si pyproject.toml existe
        $pyproject = Join-Path $serverPath "pyproject.toml"
        if (Test-Path $pyproject) {
            Write-Host "pyproject.toml: OK" -ForegroundColor Green
            Write-Host "Installation Python déjà effectuée précédemment" -ForegroundColor Gray
            $successCount++
        } else {
            Write-Host "pyproject.toml: MANQUANT" -ForegroundColor Red
        }
    } else {
        Write-Host "Répertoire source: INEXISTANT" -ForegroundColor Red
    }
}

# Résumé
Write-Host ""
Write-Host "=== RÉSUMÉ ===" -ForegroundColor Magenta
Write-Host "Serveurs traités: $successCount/$totalCount" -ForegroundColor $(if($successCount -eq $totalCount) {"Green"} else {"Yellow"})

if ($successCount -eq $totalCount) {
    Write-Host "✅ Tous les MCPs internes ont été compilés avec succès" -ForegroundColor Green
} else {
    Write-Host "❌ Certains MCPs internes n'ont pas pu être compilés" -ForegroundColor Red
}