# Verification de l'etat de compilation de roo-state-manager
Set-Location "mcps/internal/servers/roo-state-manager"

Write-Host "=== VERIFICATION ETAT COMPILATION ===" -ForegroundColor Cyan

# Verifier si dist existe
if (Test-Path "dist") {
    Write-Host "✅ Dossier dist existe" -ForegroundColor Green
    $distFiles = Get-ChildItem dist -Recurse
    Write-Host "Nombre de fichiers dans dist: $($distFiles.Count)" -ForegroundColor Yellow
    
    # Verifier si index.js principal existe
    if (Test-Path "dist/index.js") {
        Write-Host "✅ dist/index.js trouve" -ForegroundColor Green
    } else {
        Write-Host "❌ dist/index.js manquant" -ForegroundColor Red
    }
} else {
    Write-Host "⚠️ Dossier dist n'existe pas" -ForegroundColor Yellow
}

# Verifier node_modules
if (Test-Path "node_modules") {
    Write-Host "✅ node_modules existe" -ForegroundColor Green
} else {
    Write-Host "⚠️ node_modules manquant - installation necessaire" -ForegroundColor Yellow
}

# Verifier package.json scripts
if (Test-Path "package.json") {
    Write-Host "`n=== SCRIPTS DISPONIBLES ===" -ForegroundColor Cyan
    $pkg = Get-Content "package.json" | ConvertFrom-Json
    $pkg.scripts | Format-List
}

Write-Host "`n=== FIN VERIFICATION ===" -ForegroundColor Green