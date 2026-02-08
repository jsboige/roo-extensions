# Script SDDD 12.8: Validation de l'environnement pnpm
# Date: 2025-10-24T10:16:00Z
# Objectif: Valider que l'environnement pnpm est fonctionnel après réinstallation

Write-Host "SDDD 12.8 - Validation de l'environnement pnpm" -ForegroundColor Cyan

# Verification de pnpm
Write-Host "Verification de pnpm:" -ForegroundColor Yellow
try {
    $pnpmVersion = pnpm --version
    Write-Host "  OK pnpm version: $pnpmVersion" -ForegroundColor Green
} catch {
    Write-Host "  ERREUR pnpm non accessible" -ForegroundColor Red
    exit 1
}

# Verification des projets
$projectsToValidate = @(".", "webview-ui", "src")
$validProjects = 0

foreach ($project in $projectsToValidate) {
    $projectPath = $project
    if ($project -eq ".") {
        $projectName = "racine"
    } else {
        $projectName = $project
        $projectPath = $project
    }
    
    Write-Host "`nValidation du projet: $projectName" -ForegroundColor Cyan
    
    # Verification de package.json
    $packageJsonPath = Join-Path $projectPath "package.json"
    if (Test-Path $packageJsonPath) {
        Write-Host "  OK package.json present" -ForegroundColor Green
    } else {
        Write-Host "  ERREUR package.json manquant" -ForegroundColor Red
        continue
    }
    
    # Verification de node_modules
    $nodeModulesPath = Join-Path $projectPath "node_modules"
    if (Test-Path $nodeModulesPath) {
        Write-Host "  OK node_modules present" -ForegroundColor Green
        
        # Verification de quelques dependances critiques
        try {
            Push-Location $projectPath
            
            # Verifier si les dependances principales sont installees
            if (Test-Path "package.json") {
                $packageJson = Get-Content "package.json" | ConvertFrom-Json
                $criticalDeps = @("react", "vitest", "@types/react")
                
                foreach ($dep in $criticalDeps) {
                    $depPath = Join-Path "node_modules" $dep
                    if (Test-Path $depPath) {
                        Write-Host "    OK $dep installe" -ForegroundColor Green
                    } else {
                        Write-Host "    ATTENTION $dep non trouve dans node_modules" -ForegroundColor Yellow
                    }
                }
            }
            
            Pop-Location
        } catch {
            Write-Host "  ATTENTION Erreur lors de la verification des dependances: $_" -ForegroundColor Yellow
            Pop-Location -ErrorAction SilentlyContinue
        }
    } else {
        Write-Host "  ERREUR node_modules manquant" -ForegroundColor Red
        continue
    }
    
    # Test de commande pnpm simple
    try {
        Push-Location $projectPath
        $listResult = pnpm list --depth=0 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  OK pnpm list fonctionne" -ForegroundColor Green
            $validProjects++
        } else {
            Write-Host "  ERREUR pnpm list echoue" -ForegroundColor Red
        }
        Pop-Location
    } catch {
        Write-Host "  ERREUR Erreur lors de pnpm list: $_" -ForegroundColor Red
        Pop-Location -ErrorAction SilentlyContinue
    }
}

Write-Host "`nResume de la validation SDDD 12.8:" -ForegroundColor Cyan
Write-Host "  Projets valides: $validProjects/$($projectsToValidate.Count)" -ForegroundColor $(if($validProjects -eq $projectsToValidate.Count) {"Green"} else {"Yellow"})

# Verification des scripts disponibles
Write-Host "`nScripts disponibles dans les projets:" -ForegroundColor Yellow
foreach ($project in $projectsToValidate) {
    $projectPath = $project
    if ($project -eq ".") {
        $projectName = "racine"
    } else {
        $projectName = $project
        $projectPath = $project
    }
    
    $packageJsonPath = Join-Path $projectPath "package.json"
    if (Test-Path $packageJsonPath) {
        try {
            $packageJson = Get-Content $packageJsonPath | ConvertFrom-Json
            if ($packageJson.scripts) {
                Write-Host "  ${projectName}:" -ForegroundColor Cyan
                $packageJson.scripts.PSObject.Properties | ForEach-Object {
                    Write-Host "    - $($_.Name)" -ForegroundColor Gray
                }
            }
        } catch {
            Write-Host "  ATTENTION Impossible de lire les scripts de $projectName" -ForegroundColor Yellow
        }
    }
}

if ($validProjects -eq $projectsToValidate.Count) {
    Write-Host "`nValidation SDDD 12.8 reussie - Environnement pnpm fonctionnel" -ForegroundColor Green
    Write-Host "Prochaine etape: Test de la fonctionnalite React (script 04)" -ForegroundColor Cyan
} else {
    Write-Host "`nValidation SDDD 12.8 echouee - Problemes dans l'environnement" -ForegroundColor Red
    Write-Host "Verifiez les erreurs ci-dessus avant de continuer" -ForegroundColor Cyan
}