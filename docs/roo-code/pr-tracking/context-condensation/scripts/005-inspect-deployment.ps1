# Script d'inspection de la structure déployée
# Date: 2025-10-08

Write-Host "`n=== INSPECTION STRUCTURE DEPLOYEE ===" -ForegroundColor Cyan

$extPath = "C:\Users\jsboi\.vscode\extensions\rooveterinaryinc.roo-cline-3.28.15"

# Structure dist/
Write-Host "`n1. Contenu de dist/:" -ForegroundColor Yellow
Get-ChildItem "$extPath\dist" -Directory | Select-Object -First 10 Name | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Gray }

# Chercher webview-ui
Write-Host "`n2. Recherche 'webview-ui' dans dist/:" -ForegroundColor Yellow
$webviewPaths = Get-ChildItem "$extPath\dist" -Recurse -Directory -Filter "*webview*" -ErrorAction SilentlyContinue
if ($webviewPaths) {
    $webviewPaths | ForEach-Object { Write-Host "  Trouve: $($_.FullName)" -ForegroundColor Green }
} else {
    Write-Host "  [AUCUN] Pas de webview-ui trouve!" -ForegroundColor Red
}

# Structure attendue vs réelle
Write-Host "`n3. Verification chemins cles:" -ForegroundColor Yellow
$paths = @(
    "dist\webview-ui\assets\index.js",
    "dist\webview-ui\build\assets\index.js",
    "webview-ui\assets\index.js",
    "webview-ui\build\assets\index.js"
)

foreach ($p in $paths) {
    $fullPath = Join-Path $extPath $p
    $exists = Test-Path $fullPath
    $color = if ($exists) { "Green" } else { "Red" }
    $status = if ($exists) { "[OK]" } else { "[NON]" }
    Write-Host "  $status $p" -ForegroundColor $color
}

Write-Host "`n=== FIN INSPECTION ===" -ForegroundColor Cyan