# 019-remove-bad-extension.ps1
# Script pour supprimer l'extension v3.25.6 et verifier v3.28.16

Write-Host "RESOLUTION DE L'ANGLE MORT - Suppression Extension v3.25.6" -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Gray
Write-Host ""

# Etape 1: Supprimer l'extension problematique v3.25.6
Write-Host "Etape 1: Suppression de l'extension v3.25.6" -ForegroundColor Yellow
Write-Host ("-" * 70) -ForegroundColor Gray

$badExtension = "C:\Users\jsboi\.vscode\extensions\rooveterinaryinc.roo-cline-3.25.6"

if (Test-Path $badExtension) {
    Write-Host "Extension v3.25.6 trouvee, suppression en cours..." -ForegroundColor Yellow
    try {
        Remove-Item $badExtension -Recurse -Force -ErrorAction Stop
        Write-Host "Extension v3.25.6 supprimee avec succes" -ForegroundColor Green
    } catch {
        Write-Host "ERREUR lors de la suppression: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Extension v3.25.6 deja absente (OK)" -ForegroundColor Cyan
}

Write-Host ""

# Etape 2: Verifier l'integrite de l'extension v3.28.16
Write-Host "Etape 2: Verification de l'extension v3.28.16" -ForegroundColor Yellow
Write-Host ("-" * 70) -ForegroundColor Gray

$goodExtension = "C:\Users\jsboi\.vscode\extensions\rooveterinaryinc.roo-cline-3.28.16"

if (-not (Test-Path $goodExtension)) {
    Write-Host "CRITIQUE: L'extension v3.28.16 n'existe pas!" -ForegroundColor Red
    Write-Host "Chemin attendu: $goodExtension" -ForegroundColor Red
    exit 1
}

Write-Host "Extension v3.28.16 trouvee" -ForegroundColor Green

# Verifier la structure de l'extension
Write-Host ""
Write-Host "Verification de la structure:" -ForegroundColor Cyan

$allGood = $true

# Verifier dist
$distPath = "$goodExtension\dist"
$distExists = Test-Path $distPath
if ($distExists) {
    Write-Host "  [OK] dist" -ForegroundColor Green
} else {
    Write-Host "  [KO] dist" -ForegroundColor Red
    $allGood = $false
}

# Verifier webview-ui/build
$webviewBuildPath = "$goodExtension\dist\webview-ui\build"
$webviewBuildExists = Test-Path $webviewBuildPath
if ($webviewBuildExists) {
    Write-Host "  [OK] webview-ui/build" -ForegroundColor Green
} else {
    Write-Host "  [KO] webview-ui/build" -ForegroundColor Red
    $allGood = $false
}

# Verifier index.html
$indexHtmlPath = "$goodExtension\dist\webview-ui\build\index.html"
$indexHtmlExists = Test-Path $indexHtmlPath
if ($indexHtmlExists) {
    Write-Host "  [OK] index.html" -ForegroundColor Green
} else {
    Write-Host "  [KO] index.html" -ForegroundColor Red
    $allGood = $false
}

# Verifier assets/index.js
$assetsJsPath = "$goodExtension\dist\webview-ui\build\assets\index.js"
$assetsJsExists = Test-Path $assetsJsPath
if ($assetsJsExists) {
    Write-Host "  [OK] assets/index.js" -ForegroundColor Green
} else {
    Write-Host "  [KO] assets/index.js" -ForegroundColor Red
    $allGood = $false
}

# Verifier package.json
$packageJsonPath = "$goodExtension\package.json"
$packageJsonExists = Test-Path $packageJsonPath
if ($packageJsonExists) {
    Write-Host "  [OK] package.json" -ForegroundColor Green
} else {
    Write-Host "  [KO] package.json" -ForegroundColor Red
    $allGood = $false
}

Write-Host ""

if (-not $allGood) {
    Write-Host "L'extension v3.28.16 n'est pas complete!" -ForegroundColor Yellow
    Write-Host "Redeploiement necessaire via deploy-standalone.ps1" -ForegroundColor Yellow
} else {
    Write-Host "Extension v3.28.16 complete et prete" -ForegroundColor Green
}

Write-Host ""

# Etape 3: Verification finale
Write-Host "Etape 3: Verification finale" -ForegroundColor Yellow
Write-Host ("-" * 70) -ForegroundColor Gray

Write-Host ""
Write-Host "Extensions Roo-Cline installees:" -ForegroundColor Cyan
$extensions = Get-ChildItem "$env:USERPROFILE\.vscode\extensions" -Filter "rooveterinaryinc.roo-cline-*" -Directory

if ($extensions.Count -eq 0) {
    Write-Host "  Aucune extension trouvee!" -ForegroundColor Red
} else {
    foreach ($ext in $extensions) {
        $date = $ext.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
        Write-Host "  - $($ext.Name)" -ForegroundColor Yellow
        Write-Host "    Modifie: $date" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Gray
Write-Host "Script termine" -ForegroundColor Green
Write-Host ""

$extensionCount = (Get-ChildItem "$env:USERPROFILE\.vscode\extensions" -Filter "rooveterinaryinc.roo-cline-*" -Directory).Count

if ($allGood -and $extensionCount -eq 1) {
    Write-Host "RESULTAT: Situation normalisee!" -ForegroundColor Green
    Write-Host "  - v3.25.6 supprimee" -ForegroundColor Green
    Write-Host "  - v3.28.16 complete" -ForegroundColor Green
    Write-Host ""
    Write-Host "PROCHAINES ETAPES:" -ForegroundColor Cyan
    Write-Host "  1. Fermer COMPLETEMENT VSCode (toutes les fenetres)" -ForegroundColor Yellow
    Write-Host "  2. Redemarrer VSCode" -ForegroundColor Yellow
    Write-Host "  3. Verifier Settings -> Context pour l'UI" -ForegroundColor Yellow
} else {
    Write-Host "ATTENTION: Des problemes subsistent" -ForegroundColor Yellow
    if (-not $allGood) {
        Write-Host "  - Extension v3.28.16 incomplete" -ForegroundColor Red
    }
    if ($extensionCount -ne 1) {
        Write-Host "  - Nombre d'extensions incorrect: $extensionCount" -ForegroundColor Red
    }
}

Write-Host ""