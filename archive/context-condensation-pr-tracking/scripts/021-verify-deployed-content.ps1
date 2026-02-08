# Vérification Précise du Contenu Déployé
# Date: 2025-10-07
# Objectif: Vérifier exactement ce qui est dans le bundle déployé

$ErrorActionPreference = "Stop"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "VÉRIFICATION CONTENU DÉPLOYÉ" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Trouver l'extension
$extensionPath = Get-ChildItem "$env:USERPROFILE\.vscode\extensions" -Filter "rooveterinaryinc.roo-cline-*" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $extensionPath) {
    Write-Host "❌ Extension non trouvée" -ForegroundColor Red
    exit 1
}

$indexPath = Join-Path $extensionPath.FullName "dist\webview-ui\assets\index.js"

if (-not (Test-Path $indexPath)) {
    Write-Host "❌ Fichier index.js non trouvé" -ForegroundColor Red
    exit 1
}

Write-Host "Extension: $($extensionPath.Name)" -ForegroundColor Gray
Write-Host "Fichier: $indexPath`n" -ForegroundColor Gray

# Lire le contenu
$content = Get-Content $indexPath -Raw

# Recherches précises
$patterns = @{
    "Show.*Advanced.*Config" = "Pattern 'Show...Advanced...Config'"
    "Hide.*Advanced.*Config" = "Pattern 'Hide...Advanced...Config'"
    "Advanced Config" = "Texte exact 'Advanced Config'"
    'defaultProviderId.*native' = "defaultProviderId avec 'native'"
    'presetConfigJson' = "Utilisation de presetConfigJson"
}

Write-Host "RÉSULTATS DE RECHERCHE:" -ForegroundColor Yellow
Write-Host "----------------------`n" -ForegroundColor Yellow

$found = 0
$notFound = 0

foreach ($pattern in $patterns.Keys) {
    $description = $patterns[$pattern]
    
    if ($content -match $pattern) {
        Write-Host "✅ $description" -ForegroundColor Green
        
        # Extraire et afficher un extrait du match
        $match = $matches[0]
        $index = $content.IndexOf($match)
        $start = [Math]::Max(0, $index - 50)
        $length = [Math]::Min(150, $content.Length - $start)
        $excerpt = $content.Substring($start, $length).Replace("`n", " ").Replace("`r", "")
        
        Write-Host "   Extrait: $excerpt" -ForegroundColor Gray
        Write-Host ""
        $found++
    } else {
        Write-Host "❌ $description" -ForegroundColor Red
        $notFound++
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "RÉSUMÉ: $found trouvé(s), $notFound non trouvé(s)" -ForegroundColor $(if ($notFound -eq 0) { "Green" } else { "Red" })
Write-Host "========================================`n" -ForegroundColor Cyan

if ($notFound -eq 0) {
    Write-Host "✅ Toutes les modifications sont présentes dans le bundle déployé" -ForegroundColor Green
    Write-Host "Si l'UI n'est toujours pas à jour, le problème est ailleurs (cache VSCode, webview non rechargée, etc.)" -ForegroundColor Yellow
} else {
    Write-Host "❌ Le bundle déployé ne contient pas toutes les modifications" -ForegroundColor Red
    Write-Host "Action: Rebuilder et redéployer" -ForegroundColor Yellow
}