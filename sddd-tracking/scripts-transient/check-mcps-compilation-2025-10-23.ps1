# Script de vérification de la compilation des MCPs internes
# Date: 2025-10-23
# Objectif: Vérifier que tous les MCPs internes ont été compilés

Write-Host "=== VÉRIFICATION DE LA COMPILATION DES MCPs INTERNES ===" -ForegroundColor Green
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow
Write-Host ""

# Liste des serveurs MCP à vérifier
$servers = @(
    "quickfiles-server",
    "jinavigator-server", 
    "jupyter-mcp-server",
    "jupyter-papermill-mcp-server",
    "github-projects-mcp",
    "roo-state-manager"
)

$baseDir = "mcps/internal/servers"
$allCompiled = $true

foreach ($server in $servers) {
    $serverPath = Join-Path $baseDir $server
    $buildPath = Join-Path $serverPath "build"
    
    Write-Host "=== $server ===" -ForegroundColor Cyan
    
    if (Test-Path $serverPath) {
        Write-Host "Répertoire source: OK" -ForegroundColor Green
        
        if (Test-Path $buildPath) {
            $jsFiles = Get-ChildItem -Path $buildPath -Filter "*.js" -Recurse
            $count = $jsFiles.Count
            
            if ($count -gt 0) {
                Write-Host "Compilation: OK ($count fichiers JS)" -ForegroundColor Green
                # Afficher le fichier principal si c'est index.js
                $mainFile = Join-Path $buildPath "index.js"
                if (Test-Path $mainFile) {
                    Write-Host "Fichier principal: index.js" -ForegroundColor Gray
                }
            } else {
                Write-Host "Compilation: ÉCHEC (aucun fichier JS trouvé)" -ForegroundColor Red
                $allCompiled = $false
            }
        } else {
            Write-Host "Compilation: ÉCHEC (répertoire build inexistant)" -ForegroundColor Red
            $allCompiled = $false
        }
    } else {
        Write-Host "Répertoire source: INEXISTANT" -ForegroundColor Red
        $allCompiled = $false
    }
    
    Write-Host ""
}

# Résumé
Write-Host "=== RÉSUMÉ ===" -ForegroundColor Magenta
if ($allCompiled) {
    Write-Host "✅ Tous les MCPs internes ont été compilés avec succès" -ForegroundColor Green
} else {
    Write-Host "❌ Certains MCPs internes n'ont pas été compilés correctement" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== DÉTAIL DES CHEMINS DES FICHIERS COMPILÉS ===" -ForegroundColor Yellow
Get-ChildItem -Path "$baseDir/*/build" -Recurse -Filter "*.js" | Select-Object Name, @{Name="Path"; Expression={$_.FullName.Replace((Get-Location).Path, ".")}} | Format-Table -AutoSize