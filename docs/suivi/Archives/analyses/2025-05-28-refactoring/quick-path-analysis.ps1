# Analyse rapide des chemins codés en dur
# Version: 1.0 - Approche directe

Write-Host "=== ANALYSE RAPIDE DES CHEMINS CODÉS EN DUR ===" -ForegroundColor Green

# Recherche directe avec Select-String
$patterns = @("d:/roo-extensions", "c:/dev/roo-extensions")
$results = @()

foreach ($pattern in $patterns) {
    Write-Host "`nRecherche de '$pattern'..." -ForegroundColor Yellow
    
    try {
        $matches = Select-String -Path ".\*" -Pattern ([regex]::Escape($pattern)) -Recurse -List 2>$null
        foreach ($match in $matches) {
            $relativePath = $match.Filename.Replace((Get-Location).Path + "\", "")
            $results += [PSCustomObject]@{
                File = $relativePath
                Pattern = $pattern
                Type = [System.IO.Path]::GetExtension($match.Filename)
            }
            Write-Host "  ⚠️  $relativePath" -ForegroundColor Red
        }
    } catch {
        Write-Host "  Erreur: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Résumé
Write-Host "`n=== RÉSUMÉ ===" -ForegroundColor Green
Write-Host "Total fichiers avec problèmes: $($results.Count)" -ForegroundColor Yellow

if ($results.Count -gt 0) {
    # Grouper par type
    $byType = $results | Group-Object Type
    Write-Host "`nRépartition par type:" -ForegroundColor Cyan
    foreach ($type in $byType) {
        Write-Host "  $($type.Name): $($type.Count) fichiers" -ForegroundColor White
    }
    
    # Fichiers critiques
    $critical = $results | Where-Object { $_.File -match "sync_roo_environment\.ps1|config\.json|servers\.json" }
    if ($critical) {
        Write-Host "`nFichiers critiques:" -ForegroundColor Red
        foreach ($c in $critical) {
            Write-Host "  🚨 $($c.File)" -ForegroundColor Red
        }
    }
    
    Write-Host "`n=== RECOMMANDATION ===" -ForegroundColor Yellow
    Write-Host "Ces chemins absolus rendent le système non-portable." -ForegroundColor White
    Write-Host "Solution: Refactoriser pour utiliser des chemins relatifs." -ForegroundColor White
} else {
    Write-Host "✅ Aucun chemin problématique détecté!" -ForegroundColor Green
}

Write-Host "`n=== FIN ===" -ForegroundColor Green