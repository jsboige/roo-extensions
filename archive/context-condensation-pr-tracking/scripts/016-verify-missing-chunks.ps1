# Script de diagnostic: Verification des fichiers manquants
# Date: 2025-01-13
# Objectif: Comparer les fichiers JS entre build source et extension deployee

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "DIAGNOSTIC: Verification des chunks JS manquants" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

# Chemins
$sourcePath = "C:\dev\roo-code\src\webview-ui\build\assets"
$extPath = (Get-ChildItem "$env:USERPROFILE\.vscode\extensions" -Filter "rooveterinaryinc.roo-cline-*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
$deployedPath = "$extPath\dist\webview-ui\build\assets"

Write-Host "Chemins utilises:" -ForegroundColor Yellow
Write-Host "   Source: $sourcePath" -ForegroundColor Gray
Write-Host "   Deploye: $deployedPath" -ForegroundColor Gray
Write-Host ""

# Verifier que les chemins existent
if (-not (Test-Path $sourcePath)) {
    Write-Host "ERREUR: Le chemin source n'existe pas: $sourcePath" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $deployedPath)) {
    Write-Host "ERREUR: Le chemin deploye n'existe pas: $deployedPath" -ForegroundColor Red
    exit 1
}

# Lister les fichiers source
Write-Host "Collecte des fichiers source..." -ForegroundColor Yellow
$sourceFiles = Get-ChildItem "$sourcePath\*.js" | Select-Object Name, Length
$sourceFileNames = $sourceFiles.Name | Sort-Object

Write-Host "   OK: $($sourceFiles.Count) fichiers JS trouves dans le build source" -ForegroundColor Green
Write-Host ""

# Lister les fichiers deployes
Write-Host "Collecte des fichiers deployes..." -ForegroundColor Yellow
$deployedFiles = Get-ChildItem "$deployedPath\*.js" | Select-Object Name, Length
$deployedFileNames = $deployedFiles.Name | Sort-Object

Write-Host "   OK: $($deployedFiles.Count) fichiers JS trouves dans l'extension" -ForegroundColor Green
Write-Host ""

# Trouver les fichiers manquants
Write-Host "Analyse des differences..." -ForegroundColor Yellow
$missingFiles = $sourceFileNames | Where-Object { $_ -notin $deployedFileNames }

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "RESULTATS" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

if ($missingFiles.Count -eq 0) {
    Write-Host "OK: AUCUN fichier manquant - Tous les fichiers sont deployes!" -ForegroundColor Green
} else {
    Write-Host "ATTENTION: $($missingFiles.Count) FICHIERS MANQUANTS dans l'extension:" -ForegroundColor Red
    Write-Host ""
    
    # Verifier si chunk-BYCUR9qn.js et mermaid-bundle.js sont manquants
    $criticalMissing = @()
    if ($missingFiles -contains "chunk-BYCUR9qn.js") {
        $criticalMissing += "chunk-BYCUR9qn.js"
    }
    if ($missingFiles -contains "mermaid-bundle.js") {
        $criticalMissing += "mermaid-bundle.js"
    }
    
    if ($criticalMissing.Count -gt 0) {
        Write-Host "CRITIQUE: FICHIERS CRITIQUES MANQUANTS (mentionnes dans les logs 403):" -ForegroundColor Red
        foreach ($file in $criticalMissing) {
            $sourceFile = $sourceFiles | Where-Object { $_.Name -eq $file }
            $fileSizeKB = [math]::Round($sourceFile.Length / 1KB, 2)
            Write-Host "   X $file ($fileSizeKB KB)" -ForegroundColor Red
        }
        Write-Host ""
    }
    
    Write-Host "Liste complete des fichiers manquants:" -ForegroundColor Yellow
    foreach ($file in $missingFiles | Sort-Object) {
        $sourceFile = $sourceFiles | Where-Object { $_.Name -eq $file }
        $fileSizeKB = [math]::Round($sourceFile.Length / 1KB, 2)
        Write-Host "   - $file ($fileSizeKB KB)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "STATISTIQUES" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "   Source:  $($sourceFiles.Count) fichiers JS" -ForegroundColor White
Write-Host "   Deploye: $($deployedFiles.Count) fichiers JS" -ForegroundColor White
if ($missingFiles.Count -gt 0) {
    Write-Host "   Manquants: $($missingFiles.Count) fichiers" -ForegroundColor Red
} else {
    Write-Host "   Manquants: $($missingFiles.Count) fichiers" -ForegroundColor Green
}
Write-Host ""

# Calculer les tailles totales
$sourceTotalSize = ($sourceFiles | Measure-Object -Property Length -Sum).Sum
$deployedTotalSize = ($deployedFiles | Measure-Object -Property Length -Sum).Sum

Write-Host "   Taille source:  $([math]::Round($sourceTotalSize / 1MB, 2)) MB" -ForegroundColor White
Write-Host "   Taille deployee: $([math]::Round($deployedTotalSize / 1MB, 2)) MB" -ForegroundColor White
Write-Host ""

if ($missingFiles.Count -gt 0) {
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "PROCHAINE ETAPE" -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Le script de deploiement doit etre examine pour comprendre" -ForegroundColor Yellow
    Write-Host "pourquoi ces fichiers ne sont pas copies." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Fichier a examiner:" -ForegroundColor White
    $deployScript = "C:\dev\roo-extensions\roo-code-customization\deploy-standalone.ps1"
    Write-Host "   $deployScript" -ForegroundColor Cyan
    Write-Host ""
}