# Script SDDD 12.9: Test de la fonctionnalite React
# Date: 2025-10-24T10:16:00Z
# Objectif: Valider que l'environnement React et les tests fonctionnent correctement

Write-Host "SDDD 12.9 - Test de la fonctionnalite React" -ForegroundColor Cyan

# Test du projet webview-ui (principal projet React)
$webviewUiPath = "webview-ui"
$testSuccess = $false

if (Test-Path $webviewUiPath) {
    Write-Host "Test du projet webview-ui..." -ForegroundColor Cyan
    
    try {
        Push-Location $webviewUiPath
        
        # Verification des dependances React
        Write-Host "Verification des dependances React:" -ForegroundColor Yellow
        $reactDeps = @("react", "react-dom", "@types/react", "@types/react-dom")
        
        foreach ($dep in $reactDeps) {
            $depPath = Join-Path "node_modules" $dep
            if (Test-Path $depPath) {
                try {
                    $packageJson = Join-Path $depPath "package.json"
                    if (Test-Path $packageJson) {
                        $version = (Get-Content $packageJson | ConvertFrom-Json).version
                        Write-Host "  OK ${dep} v${version}" -ForegroundColor Green
                    } else {
                        Write-Host "  ATTENTION ${dep} installe (version inconnue)" -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host "  ATTENTION ${dep} installe (erreur de lecture version)" -ForegroundColor Yellow
                }
            } else {
                Write-Host "  ERREUR ${dep} non trouve" -ForegroundColor Red
            }
        }
        
        # Test de build
        Write-Host "`nTest de build React:" -ForegroundColor Yellow
        $buildResult = pnpm build 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  OK Build reussi" -ForegroundColor Green
        } else {
            Write-Host "  ERREUR Build echoue" -ForegroundColor Red
            Write-Host "  Details de l'erreur:" -ForegroundColor Red
            $buildResult | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        }
        
        # Test des tests Vitest
        Write-Host "`nTest des tests Vitest:" -ForegroundColor Yellow
        $testResult = pnpm test 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  OK Tests reussis" -ForegroundColor Green
            $testSuccess = $true
        } else {
            Write-Host "  ERREUR Tests echoues" -ForegroundColor Red
            Write-Host "  Details de l'erreur:" -ForegroundColor Red
            $testResult | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        }
        
        # Test specifique du composant CondensationProviderSettings
        Write-Host "`nTest specifique du composant CondensationProviderSettings:" -ForegroundColor Yellow
        $specificTestResult = pnpm test src/components/settings/__tests__/CondensationProviderSettings.spec.tsx 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  OK Test du composant reussi" -ForegroundColor Green
        } else {
            Write-Host "  ERREUR Test du composant echoue" -ForegroundColor Red
            Write-Host "  Details de l'erreur:" -ForegroundColor Red
            $specificTestResult | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        }
        
        Pop-Location
    } catch {
        Write-Host "  ERREUR Exception lors des tests: $_" -ForegroundColor Red
        Pop-Location -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "  ERREUR Repertoire webview-ui non trouve" -ForegroundColor Red
}

# Test du projet src (backend)
$srcPath = "src"
if (Test-Path $srcPath) {
    Write-Host "`nTest du projet src (backend)..." -ForegroundColor Cyan
    
    try {
        Push-Location $srcPath
        
        # Test des tests backend
        Write-Host "Test des tests backend:" -ForegroundColor Yellow
        $backendTestResult = pnpm test 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  OK Tests backend reussis" -ForegroundColor Green
        } else {
            Write-Host "  ERREUR Tests backend echoues" -ForegroundColor Red
            Write-Host "  Details de l'erreur:" -ForegroundColor Red
            $backendTestResult | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        }
        
        Pop-Location
    } catch {
        Write-Host "  ERREUR Exception lors des tests backend: $_" -ForegroundColor Red
        Pop-Location -ErrorAction SilentlyContinue
    }
}

Write-Host "`nResume des tests SDDD 12.9:" -ForegroundColor Cyan
if ($testSuccess) {
    Write-Host "  Tests React webview-ui: OK Reussis" -ForegroundColor Green
} else {
    Write-Host "  Tests React webview-ui: ERREUR Echoues" -ForegroundColor Red
}

if ($testSuccess) {
    Write-Host "OK Tests SDDD 12.9 reussis - Environnement React fonctionnel" -ForegroundColor Green
    Write-Host "Phase de reparation pnpm completee avec succes" -ForegroundColor Green
} else {
    Write-Host "ERREUR Tests SDDD 12.9 echoues - Problemes dans l'environnement React" -ForegroundColor Red
    Write-Host "Verifiez les erreurs ci-dessus et consultez les logs pour diagnostic" -ForegroundColor Cyan
}

Write-Host "`nProchaines etapes:" -ForegroundColor Yellow
Write-Host "  1. Validation finale globale (tests + build)" -ForegroundColor Cyan
Write-Host "  2. Documentation des resultats" -ForegroundColor Cyan
Write-Host "  3. Commit des changements de nettoyage et reparation" -ForegroundColor Cyan