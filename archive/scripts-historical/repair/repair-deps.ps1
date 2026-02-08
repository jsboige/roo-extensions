$servers = "jupyter-mcp-server", "github-projects-mcp", "roo-state-manager", "jinavigator-server", "quickfiles-server"
foreach ($server in $servers) {
    $serverPath = "mcps/internal/servers/$server"
    if (Test-Path $serverPath) {
        Write-Host "--- Installation des dépendances pour $server ---"
        Push-Location $serverPath
        npm install
        Pop-Location
    } else {
        Write-Warning "Le répertoire pour $server est introuvable à l'emplacement $serverPath"
    }
}
Write-Host "--- Réparation des dépendances terminée ---"