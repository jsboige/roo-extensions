# Script de collecte de tous les stashs du workspace
# Date: 2025-10-16

$ErrorActionPreference = "Continue"

# Définir la racine du workspace
$workspaceRoot = "d:/roo-extensions"

# Liste des dépôts à scanner
$repositories = @(
    @{ Path = "."; Name = "d:/roo-extensions (principal)" },
    @{ Path = "mcps/internal"; Name = "mcps/internal" },
    @{ Path = "mcps/external/Office-PowerPoint-MCP-Server"; Name = "Office-PowerPoint-MCP-Server" },
    @{ Path = "mcps/external/markitdown/source"; Name = "markitdown" },
    @{ Path = "mcps/external/mcp-server-ftp"; Name = "mcp-server-ftp" },
    @{ Path = "mcps/external/playwright/source"; Name = "playwright" },
    @{ Path = "mcps/external/win-cli/server"; Name = "win-cli/server" },
    @{ Path = "mcps/forked/modelcontextprotocol-servers"; Name = "modelcontextprotocol-servers (fork)" },
    @{ Path = "roo-code"; Name = "roo-code" }
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "COLLECTE STASHS WORKSPACE" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$totalStashs = 0
$reposWithStashs = 0
$results = @()

foreach ($repo in $repositories) {
    $repoPath = Join-Path $workspaceRoot $repo.Path
    $repoName = $repo.Name
    
    Write-Host "Analyse: $repoName" -ForegroundColor Yellow
    
    if (Test-Path $repoPath) {
        Push-Location $repoPath
        
        try {
            $stashList = git stash list --date=iso 2>&1
            
            if ($LASTEXITCODE -eq 0 -and $stashList) {
                $stashCount = ($stashList | Measure-Object).Count
                
                if ($stashCount -gt 0) {
                    Write-Host "  ✓ $stashCount stash(s) trouvé(s)" -ForegroundColor Green
                    $totalStashs += $stashCount
                    $reposWithStashs++
                    
                    $results += @{
                        Name = $repoName
                        Path = $repo.Path
                        StashCount = $stashCount
                        Stashs = $stashList
                    }
                } else {
                    Write-Host "  ○ Aucun stash" -ForegroundColor Gray
                }
            } else {
                Write-Host "  ○ Aucun stash" -ForegroundColor Gray
            }
        }
        catch {
            Write-Host "  ✗ Erreur: $($_.Exception.Message)" -ForegroundColor Red
        }
        finally {
            Pop-Location
        }
    } else {
        Write-Host "  ✗ Dépôt non trouvé: $repoPath" -ForegroundColor Red
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "RÉSUMÉ" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total stashs trouvés: $totalStashs" -ForegroundColor Green
Write-Host "Dépôts avec stashs: $reposWithStashs / $($repositories.Count)" -ForegroundColor Green
Write-Host ""

if ($results.Count -gt 0) {
    Write-Host "DÉTAILS PAR DÉPÔT:" -ForegroundColor Cyan
    foreach ($result in $results) {
        Write-Host "`n  $($result.Name) [$($result.StashCount) stash(s)]" -ForegroundColor Yellow
        Write-Host "  Chemin: $($result.Path)" -ForegroundColor Gray
    }
}

# Exporter les résultats
$outputPath = Join-Path $workspaceRoot "docs/git/stash-collection-raw-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
$output = @"
========================================
COLLECTE STASHS - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
========================================

RÉSUMÉ:
- Total stashs: $totalStashs
- Dépôts avec stashs: $reposWithStashs / $($repositories.Count)

"@

foreach ($result in $results) {
    $output += @"

========================================
DÉPÔT: $($result.Name)
========================================
Chemin: $($result.Path)
Stashs: $($result.StashCount)

$($result.Stashs -join "`n")

"@
}

$output | Out-File -FilePath $outputPath -Encoding UTF8
Write-Host "`nRésultats exportés vers: $outputPath" -ForegroundColor Green

return @{
    TotalStashs = $totalStashs
    ReposWithStashs = $reposWithStashs
    Results = $results
}