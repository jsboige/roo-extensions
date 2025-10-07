# Nettoyage Rapide - Version Minimaliste
# Suppression ciblée fichiers temporaires évidents

Write-Host "NETTOYAGE RAPIDE MULTI-COMPOSANTS" -ForegroundColor Yellow

Set-Location "d:/dev/roo-extensions"

# Suppression fichiers temporaires courants niveau racine seulement
$tempFiles = @("*.tmp", "*.log", "*.bak", ".DS_Store", "Thumbs.db")

$cleaned = 0
foreach ($pattern in $tempFiles) {
    $files = Get-ChildItem -Path "." -Name $pattern -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        try {
            Remove-Item $file -Force
            Write-Host "Supprime: $file" -ForegroundColor Gray
            $cleaned++
        } catch {
            # Ignore les erreurs
        }
    }
}

Write-Host "Fichiers temporaires supprimes: $cleaned" -ForegroundColor Green

# Vérification état Git rapide
$status = git status --porcelain
Write-Host "`nEtat Git apres nettoyage:" -ForegroundColor Cyan
if ($status) {
    $status | ForEach-Object { Write-Host "  $_" }
    Write-Host "Changements: $($status.Count)" -ForegroundColor Yellow
} else {
    Write-Host "  Aucun changement" -ForegroundColor Green
}

Write-Host "`nNETTOYAGE RAPIDE TERMINE" -ForegroundColor Green