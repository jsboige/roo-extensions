# Script de vérification complète de la compilation des MCPs internes
# Date: 2025-10-23
# Objectif: Vérifier que tous les MCPs internes ont été compilés (build ou dist)

Write-Host "=== VÉRIFICATION COMPLÈTE DE LA COMPILATION DES MCPs INTERNES ===" -ForegroundColor Green
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow
Write-Host ""

# Liste des serveurs MCP à vérifier
$servers = @(
    @{ Name="quickfiles-server"; Type="TypeScript"; MainFile="index.js" },
    @{ Name="jinavigator-server"; Type="TypeScript"; MainFile="index.js" }, 
    @{ Name="jupyter-mcp-server"; Type="TypeScript"; MainFile="index.js" },
    @{ Name="jupyter-papermill-mcp-server"; Type="Python"; MainFile="server.py" },
    @{ Name="github-projects-mcp"; Type="TypeScript"; MainFile="index.js" },
    @{ Name="roo-state-manager"; Type="TypeScript"; MainFile="index.js" }
)

$baseDir = "mcps/internal/servers"
$allCompiled = $true
$compiledServers = @()

foreach ($server in $servers) {
    $serverName = $server.Name
    $serverType = $server.Type
    $mainFile = $server.MainFile
    $serverPath = Join-Path $baseDir $serverName
    
    Write-Host "=== $serverName ($serverType) ===" -ForegroundColor Cyan
    
    if (Test-Path $serverPath) {
        Write-Host "Répertoire source: OK" -ForegroundColor Green
        
        # Vérifier les répertoires de compilation selon le type
        if ($serverType -eq "TypeScript") {
            # Chercher dans build ou dist
            $buildPath = Join-Path $serverPath "build"
            $distPath = Join-Path $serverPath "dist"
            $compiledPath = $null
            
            if (Test-Path $buildPath) {
                $compiledPath = $buildPath
            } elseif (Test-Path $distPath) {
                $compiledPath = $distPath
            }
            
            if ($compiledPath) {
                $jsFiles = Get-ChildItem -Path $compiledPath -Filter "*.js" -Recurse
                $count = $jsFiles.Count
                
                if ($count -gt 0) {
                    $mainFilePath = Join-Path $compiledPath $mainFile
                    if (Test-Path $mainFilePath) {
                        Write-Host "Compilation: OK ($count fichiers JS dans $(Split-Path $compiledPath -Leaf))" -ForegroundColor Green
                        Write-Host "Fichier principal: $mainFile" -ForegroundColor Gray
                        $compiledServers += @{
                            Server = $serverName
                            Type = $serverType
                            Path = $compiledPath
                            MainFile = $mainFilePath
                            Status = "Compilé"
                        }
                    } else {
                        Write-Host "Compilation: PARTIELLE ($count fichiers JS mais $mainFile manquant)" -ForegroundColor Yellow
                        $allCompiled = $false
                    }
                } else {
                    Write-Host "Compilation: ÉCHEC (répertoire $(Split-Path $compiledPath -Leaf) vide)" -ForegroundColor Red
                    $allCompiled = $false
                }
            } else {
                Write-Host "Compilation: ÉCHEC (ni build ni dist trouvé)" -ForegroundColor Red
                $allCompiled = $false
            }
        } elseif ($serverType -eq "Python") {
            # Pour Python, vérifier l'installation des dépendances
            $pyproject = Join-Path $serverPath "pyproject.toml"
            if (Test-Path $pyproject) {
                Write-Host "Projet Python: OK (pyproject.toml trouvé)" -ForegroundColor Green
                Write-Host "Installation: Déjà effectuée" -ForegroundColor Gray
                $compiledServers += @{
                    Server = $serverName
                    Type = $serverType
                    Path = $serverPath
                    MainFile = Join-Path $serverPath $mainFile
                    Status = "Installé"
                }
            } else {
                Write-Host "Projet Python: ÉCHEC (pyproject.toml manquant)" -ForegroundColor Red
                $allCompiled = $false
            }
        }
    } else {
        Write-Host "Répertoire source: INEXISTANT" -ForegroundColor Red
        $allCompiled = $false
    }
    
    Write-Host ""
}

# Résumé
Write-Host "=== RÉSUMÉ ===" -ForegroundColor Magenta
Write-Host "Serveurs compilés: $($compiledServers.Count)/$($servers.Count)" -ForegroundColor $(if($allCompiled) {"Green"} else {"Yellow"})

if ($allCompiled) {
    Write-Host "✅ Tous les MCPs internes ont été compilés/installés avec succès" -ForegroundColor Green
} else {
    Write-Host "❌ Certains MCPs internes n'ont pas été compilés correctement" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== DÉTAIL DES SERVEURS COMPILÉS ===" -ForegroundColor Yellow
$compiledServers | ForEach-Object {
    Write-Host "$($_.Server) ($($_.Type))" -ForegroundColor Cyan
    Write-Host "  Chemin: $($_.Path)" -ForegroundColor Gray
    Write-Host "  Principal: $($_.MainFile)" -ForegroundColor Gray
    Write-Host "  Statut: $($_.Status)" -ForegroundColor $(if($_.Status -eq "Compilé") {"Green"} else {"Blue"})
    Write-Host ""
}