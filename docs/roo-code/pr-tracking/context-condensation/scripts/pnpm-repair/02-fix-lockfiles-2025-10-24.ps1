# Script SDDD 12.7b: Regeneration des lockfiles
# Date: 2025-10-24T10:16:00Z
# Objectif: Regenerer les lockfiles pnpm corrompus

Write-Host "SDDD 12.7b - Regeneration des lockfiles pnpm" -ForegroundColor Cyan

# Verification de la version Node
$nodeVersion = node --version
Write-Host "Version Node actuelle: $nodeVersion" -ForegroundColor Yellow
Write-Host "Version requise: v20.19.2" -ForegroundColor Yellow

# Installation sans frozen-lockfile pour regenerer
Write-Host "`nRegeneration des lockfiles..." -ForegroundColor Yellow
$projects = @(".", "webview-ui", "src")
$successCount = 0

foreach ($project in $projects) {
    $packageJsonPath = Join-Path $project "package.json"
    $projectName = if ($project -eq ".") { "racine" } else { $project }
    
    Write-Host "`nRegeneration dans $projectName ..." -ForegroundColor Cyan
    
    if (Test-Path $packageJsonPath) {
        try {
            Push-Location $project
            
            Write-Host "  Execution de pnpm install --no-frozen-lockfile..." -ForegroundColor Yellow
            $installResult = pnpm install --no-frozen-lockfile 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  Regeneration reussie dans $projectName" -ForegroundColor Green
                $successCount++
                
                # Verification du lockfile
                $lockfilePath = Join-Path $project "pnpm-lock.yaml"
                if (Test-Path $lockfilePath) {
                    Write-Host "  Lockfile genere: $lockfilePath" -ForegroundColor Green
                }
            } else {
                Write-Host "  Erreur lors de la regeneration dans $projectName" -ForegroundColor Red
                Write-Host "  Details de lerreur:" -ForegroundColor Red
                $installResult | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
            }
            
            Pop-Location
        } catch {
            Write-Host "  Exception lors de la regeneration dans $projectName : $_" -ForegroundColor Red
            Pop-Location -ErrorAction SilentlyContinue
        }
    } else {
        Write-Host "  package.json non trouve dans $projectName, skipping" -ForegroundColor Yellow
    }
}

Write-Host "`nResume de la regeneration SDDD 12.7b:" -ForegroundColor Cyan
Write-Host "  Regenerations reussies: $successCount/$($projects.Count)" -ForegroundColor Green

if ($successCount -eq $projects.Count) {
    Write-Host "Regeneration SDDD 12.7b completee avec succes" -ForegroundColor Green
    Write-Host "Prochaine etape: Validation de l'environnement (script 03)" -ForegroundColor Cyan
} else {
    Write-Host "Certaines regenerations ont echoue" -ForegroundColor Yellow
    Write-Host "Verifiez les erreurs ci-dessus" -ForegroundColor Yellow
}