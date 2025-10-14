Write-Host "=== VÉRIFICATION EXTENSION DÉPLOYÉE ===" -ForegroundColor Cyan

# Trouver l'extension active
$extPath = Get-ChildItem "$env:USERPROFILE\.vscode\extensions\rooveterinaryinc.roo-cline-*" | Sort-Object Name -Descending | Select-Object -First 1

if (-not $extPath) {
    Write-Host "❌ ERREUR: Aucune extension Roo-Cline trouvée" -ForegroundColor Red
    exit 1
}

Write-Host "Extension: $($extPath.Name)" -ForegroundColor Yellow
Write-Host "Chemin: $($extPath.FullName)" -ForegroundColor Gray

# Test 1: Structure correcte?
$webviewPath = Join-Path $extPath.FullName "dist\webview-ui\build\assets"
$hasCorrectStructure = Test-Path $webviewPath
Write-Host "`n1. Structure webview-ui\build\assets: $hasCorrectStructure" -ForegroundColor $(if($hasCorrectStructure){'Green'}else{'Red'})

# Test 2: Date compilation
$extJsPath = Join-Path $extPath.FullName "dist\extension.js"
if (Test-Path $extJsPath) {
    $extDate = (Get-Item $extJsPath).LastWriteTime
    Write-Host "2. Date compilation: $extDate" -ForegroundColor Cyan
    $hoursOld = ((Get-Date) - $extDate).TotalHours
    Write-Host "   Âge: $([math]::Round($hoursOld, 1)) heures" -ForegroundColor Gray
} else {
    Write-Host "2. ❌ extension.js introuvable" -ForegroundColor Red
}

# Test 3: CSP correcte (pas de 'strict-dynamic')
$hasStrictDynamic = Select-String -Path $extJsPath -Pattern "strict-dynamic" -Quiet
Write-Host "3. CSP contient 'strict-dynamic': $hasStrictDynamic" -ForegroundColor $(if(!$hasStrictDynamic){'Green'}else{'Red'})

# Test 4: Composant UI présent
$indexJsPath = Get-ChildItem "$webviewPath\index*.js" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($indexJsPath) {
    $hasComponent = Select-String -Path $indexJsPath.FullName -Pattern "Context Condensation Provider" -Quiet
    Write-Host "4. Composant 'Context Condensation Provider' présent: $hasComponent" -ForegroundColor $(if($hasComponent){'Green'}else{'Red'})
} else {
    Write-Host "4. ❌ index.js introuvable dans webview-ui" -ForegroundColor Red
}

# VERDICT
Write-Host "`n=== VERDICT ===" -ForegroundColor Yellow
$needsRedeploy = (-not $hasCorrectStructure) -or $hasStrictDynamic -or (-not $hasComponent)

if ($needsRedeploy) {
    Write-Host "❌ Extension OBSOLÈTE - Re-déploiement nécessaire" -ForegroundColor Red
    exit 1
} else {
    Write-Host "✅ Extension semble correcte" -ForegroundColor Green
    exit 0
}