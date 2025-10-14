# 022-devtools-investigation.ps1
# Investigation DevTools - Diagnostic Bundle et Instructions
# =================================================================

$ErrorActionPreference = "Continue"

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host 'INVESTIGATION DEVTOOLS APPROFONDIE' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

# =================================================================
# VERIFICATION DU BUNDLE DEPLOYE
# =================================================================
Write-Host '[1/2] Verification du bundle deploye' -ForegroundColor Yellow
Write-Host ('=' * 70) -ForegroundColor Gray

$extPath = 'C:\Users\jsboi\.vscode\extensions\rooveterinaryinc.roo-cline-3.28.16'
$assetsPath = Join-Path $extPath 'dist\webview-ui\build\assets'

if (-not (Test-Path $assetsPath)) {
    Write-Host 'CRITIQUE: Repertoire assets introuvable!' -ForegroundColor Red
    Write-Host "Chemin: $assetsPath" -ForegroundColor Red
    exit 1
}

$indexJs = Get-ChildItem $assetsPath -Filter 'index-*.js' | Select-Object -First 1

if (-not $indexJs) {
    Write-Host 'CRITIQUE: Fichier index.js introuvable!' -ForegroundColor Red
    exit 1
}

Write-Host "Bundle trouve: $($indexJs.Name)" -ForegroundColor Green
Write-Host "Taille: $([math]::Round($indexJs.Length / 1KB, 2)) KB" -ForegroundColor Gray
Write-Host "Modifie: $($indexJs.LastWriteTime)" -ForegroundColor Gray

# Recherche du composant
Write-Host ''
Write-Host 'Recherche du composant dans le bundle...' -ForegroundColor Cyan
$content = Get-Content $indexJs.FullName -Raw

$searchTerms = @(
    'CondensationProviderSettings',
    'Context Condensation Provider',
    'condensationProvider'
)

$found = 0
foreach ($term in $searchTerms) {
    if ($content -match [regex]::Escape($term)) {
        Write-Host "  [OK] Trouve: $term" -ForegroundColor Green
        $found++
    } else {
        Write-Host "  [ ] Absent: $term" -ForegroundColor Yellow
    }
}

Write-Host ''
if ($found -eq 0) {
    Write-Host 'CRITIQUE: Composant ABSENT du bundle!' -ForegroundColor Red
    $bundleStatus = 'ABSENT'
} elseif ($found -lt $searchTerms.Count) {
    Write-Host "ATTENTION: Seulement $found/$($searchTerms.Count) termes trouves" -ForegroundColor Yellow
    $bundleStatus = 'PARTIEL'
} else {
    Write-Host "EXCELLENT: Tous les termes trouves ($found/$($searchTerms.Count))" -ForegroundColor Green
    $bundleStatus = 'COMPLET'
}

# =================================================================
# VERIFICATION DU SOURCE CODE
# =================================================================
Write-Host ''
Write-Host '[2/2] Verification du source code' -ForegroundColor Yellow
Write-Host ('=' * 70) -ForegroundColor Gray

$settingsViewPath = 'C:\dev\roo-code\webview-ui\src\components\settings\SettingsView.tsx'

if (-not (Test-Path $settingsViewPath)) {
    Write-Host 'CRITIQUE: SettingsView.tsx introuvable!' -ForegroundColor Red
    exit 1
}

$sourceContent = Get-Content $settingsViewPath -Raw

if ($sourceContent -match 'import.*CondensationProviderSettings') {
    Write-Host '[OK] Import present' -ForegroundColor Green
} else {
    Write-Host '[KO] Import ABSENT' -ForegroundColor Red
}

if ($sourceContent -match '<CondensationProviderSettings') {
    Write-Host '[OK] Composant rendu dans JSX' -ForegroundColor Green
    $sourceStatus = 'OK'
} else {
    Write-Host '[KO] Composant NON rendu' -ForegroundColor Red
    $sourceStatus = 'MISSING'
}

# =================================================================
# SYNTHESE
# =================================================================
Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host 'SYNTHESE' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''
Write-Host "Bundle: $bundleStatus" -ForegroundColor White
Write-Host "Source: $sourceStatus" -ForegroundColor White
Write-Host ''

if ($bundleStatus -eq 'COMPLET' -and $sourceStatus -eq 'OK') {
    Write-Host 'DIAGNOSTIC: Composant dans code ET bundle mais ne s affiche PAS' -ForegroundColor Yellow
    Write-Host 'CONCLUSION: Probleme au RUNTIME (chargement/rendu)' -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'Il faut maintenant utiliser DevTools pour investiguer:' -ForegroundColor White
    
    # Instructions DevTools
    Write-Host ''
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host 'INSTRUCTIONS DEVTOOLS' -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host ''
    
    Write-Host 'ETAPE 1: Ouvrir DevTools' -ForegroundColor Yellow
    Write-Host '  1. Ouvre Roo Settings (icone engrenage)' -ForegroundColor Gray
    Write-Host '  2. Va dans onglet Context' -ForegroundColor Gray
    Write-Host '  3. Cmd+Shift+P puis Developer: Toggle Developer Tools' -ForegroundColor Gray
    Write-Host ''
    
    Write-Host 'ETAPE 2: Console Tab' -ForegroundColor Yellow
    Write-Host '  - Copie TOUS les messages (erreurs, warnings, info)' -ForegroundColor Gray
    Write-Host '  - Note les erreurs 404 ou echecs de chargement' -ForegroundColor Gray
    Write-Host ''
    
    Write-Host 'ETAPE 3: Network Tab' -ForegroundColor Yellow
    Write-Host '  - Rafraichis la page (F5)' -ForegroundColor Gray
    Write-Host '  - Cherche index-*.js' -ForegroundColor Gray
    Write-Host '  - Verifie le code statut (200 ou 404?)' -ForegroundColor Gray
    Write-Host '  - Note le chemin exact du fichier' -ForegroundColor Gray
    Write-Host ''
    
    Write-Host 'ETAPE 4: Sources Tab' -ForegroundColor Yellow
    Write-Host '  - Utilise la recherche (Ctrl+Shift+F)' -ForegroundColor Gray
    Write-Host '  - Cherche: CondensationProviderSettings' -ForegroundColor Gray
    Write-Host '  - Note si trouve ou pas' -ForegroundColor Gray
    Write-Host ''
    
    Write-Host 'A ME FOURNIR:' -ForegroundColor White
    Write-Host '  1. Messages Console (copier-coller)' -ForegroundColor Gray
    Write-Host '  2. Fichiers Network (noms + codes statut)' -ForegroundColor Gray
    Write-Host '  3. Resultat recherche Sources' -ForegroundColor Gray
    
} elseif ($bundleStatus -eq 'ABSENT') {
    Write-Host 'DIAGNOSTIC: Composant ABSENT du bundle' -ForegroundColor Red
    Write-Host 'ACTION: Rebuild et redeploy necessaires' -ForegroundColor Yellow
} else {
    Write-Host 'DIAGNOSTIC: Statut mixte' -ForegroundColor Yellow
    Write-Host 'ACTION: Investigation approfondie requise' -ForegroundColor Yellow
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''