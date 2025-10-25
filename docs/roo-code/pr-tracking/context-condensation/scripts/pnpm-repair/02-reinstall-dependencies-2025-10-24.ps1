# Script SDDD 12.7: Reinstallation des dependances
# Date: 2025-10-24T10:16:00Z
# Objectif: Reinstaller toutes les dependances pnpm

Write-Host "SDDD 12.7 - Reinstallation des dependances" -ForegroundColor Cyan

# Verification prealable
Write-Host "Verification prealable:" -ForegroundColor Yellow
$projects = @(".", "webview-ui", "src")
$successCount = 0

foreach ($project in $projects) {
    $packageJsonPath = Join-Path $project "package.json"
    if (Test-Path $packageJsonPath) {
        Write-Host "  OK package.json trouve dans $project" -ForegroundColor Green
    } else {
        Write-Host "  ERREUR package.json manquant dans $project" -ForegroundColor Red
    }
}

# Installation dans chaque projet
foreach ($project in $projects) {
    $packageJsonPath = Join-Path $project "package.json"
    $projectName = if ($project -eq ".") { "racine" } else { $project }
    
    Write-Host "`nInstallation dans $projectName ..." -ForegroundColor Cyan
    
    if (Test-Path $packageJsonPath) {
        try {
            Push-Location $project
            
            Write-Host "  Execution de pnpm install..." -ForegroundColor Yellow
            $installResult = pnpm install --frozen-lockfile 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  Installation reussie dans $projectName" -ForegroundColor Green
                $successCount++
            } else {
                Write-Host "  Erreur lors de linstallation dans $projectName" -ForegroundColor Red
                Write-Host "  Details de lerreur:" -ForegroundColor Red
                $installResult | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
            }
            
            Pop-Location
        } catch {
            Write-Host "  Exception lors de linstallation dans $projectName : $_" -ForegroundColor Red
            Pop-Location -ErrorAction SilentlyContinue
        }
    } else {
        Write-Host "  package.json non trouve dans $projectName, skipping" -ForegroundColor Yellow
    }
}

Write-Host "`nResume de linstallation SDDD 12.7:" -ForegroundColor Cyan
Write-Host "  Installations reussies: $successCount/$($projects.Count)" -ForegroundColor Green

if ($successCount -eq $projects.Count) {
    Write-Host "Reinstallation SDDD 12.7 completee avec succes" -ForegroundColor Green
} else {
    Write-Host "Certaines installations ont echoue" -ForegroundColor Yellow
    Write-Host "Verifiez les erreurs ci-dessus et reessayez si necessaire" -ForegroundColor Yellow
}

# Verification post-installation
Write-Host "`nVerification post-installation:" -ForegroundColor Yellow
foreach ($project in $projects) {
    $projectName = if ($project -eq ".") { "racine" } else { $project }
    $nodeModulesPath = Join-Path $project "node_modules"
    
    if (Test-Path $nodeModulesPath) {
        Write-Host "  OK node_modules present dans $projectName" -ForegroundColor Green
    } else {
        Write-Host "  ERREUR node_modules manquant dans $projectName" -ForegroundColor Red
    }
}

Write-Host "`nProchaine etape: Validation de l'environnement (script 03)" -ForegroundColor Cyan