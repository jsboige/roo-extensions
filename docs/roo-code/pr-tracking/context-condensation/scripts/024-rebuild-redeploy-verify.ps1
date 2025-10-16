# Verification Script After Radio Button Fix Deployment
# Date: 2025-10-15
# Usage: .\024-rebuild-redeploy-verify.ps1
# Note: Build and deployment have already been done, this script just verifies

$ErrorActionPreference = "Stop"

Write-Host "`n=== VERIFICATION DU DEPLOIEMENT ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Gray

# Step 1: Verify local build
Write-Host "[1/3] Verification du build local..." -ForegroundColor Yellow
$buildPath = "C:\dev\roo-code\src\webview-ui\build\assets"
if (-not (Test-Path $buildPath)) {
    Write-Host "  FAIL Build directory not found!" -ForegroundColor Red
    exit 1
}

$indexJs = Get-ChildItem $buildPath -Filter "index*.js" -ErrorAction SilentlyContinue | Select-Object -First 1

if ($indexJs) {
    Write-Host "  OK index.js found" -ForegroundColor Green
    Write-Host "    Size: $([math]::Round($indexJs.Length/1KB, 2)) KB" -ForegroundColor Gray
    Write-Host "    Modified: $($indexJs.LastWriteTime)" -ForegroundColor Gray
    
    # Check for CRITICAL fix patterns
    $content = Get-Content $indexJs.FullName -Raw
    $criticalPatterns = @(
        "CondensationProviderSettings",
        "Context Condensation Provider"
    )
    
    $localOK = $true
    foreach ($pattern in $criticalPatterns) {
        if ($content -match [regex]::Escape($pattern)) {
            Write-Host "    OK '$pattern' found" -ForegroundColor Green
        } else {
            Write-Host "    FAIL '$pattern' missing!" -ForegroundColor Red
            $localOK = $false
        }
    }
    
    if ($localOK) {
        Write-Host "  OK All critical patterns found in local build`n" -ForegroundColor Green
    } else {
        Write-Host "  FAIL Critical patterns missing from local build`n" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  FAIL index.js not found!" -ForegroundColor Red
    exit 1
}

# Step 2: Verify deployed extension
Write-Host "[2/3] Verification de l'extension deployee..." -ForegroundColor Yellow
$extPath = (Get-ChildItem "$env:USERPROFILE\.vscode\extensions" -Filter "rooveterinaryinc.roo-cline-*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName

if (-not $extPath) {
    Write-Host "  FAIL Extension not found!" -ForegroundColor Red
    exit 1
}

Write-Host "  Extension: $extPath" -ForegroundColor Gray

$deployedPath = "$extPath\dist\webview-ui\build\assets"
$deployedJs = Get-ChildItem $deployedPath -Filter "index*.js" -ErrorAction SilentlyContinue | Select-Object -First 1

if ($deployedJs) {
    Write-Host "  OK index.js found" -ForegroundColor Green
    Write-Host "    Size: $([math]::Round($deployedJs.Length/1KB, 2)) KB" -ForegroundColor Gray
    Write-Host "    Modified: $($deployedJs.LastWriteTime)" -ForegroundColor Gray
    
    # Check for CRITICAL fix patterns
    $deployedContent = Get-Content $deployedJs.FullName -Raw
    $deployedOK = $true
    
    foreach ($pattern in $criticalPatterns) {
        if ($deployedContent -match [regex]::Escape($pattern)) {
            Write-Host "    OK '$pattern' found" -ForegroundColor Green
        } else {
            Write-Host "    FAIL '$pattern' missing!" -ForegroundColor Red
            $deployedOK = $false
        }
    }
    
    if ($deployedOK) {
        Write-Host "  OK All critical patterns found in deployed extension`n" -ForegroundColor Green
    } else {
        Write-Host "  FAIL Critical patterns missing from deployed extension`n" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  FAIL Deployed index.js not found!" -ForegroundColor Red
    exit 1
}

# Step 3: Summary
Write-Host "[3/3] Resume..." -ForegroundColor Yellow
Write-Host "`n=== SUCCESS ===" -ForegroundColor Green
Write-Host "OK Build local verifie" -ForegroundColor Green
Write-Host "OK Extension deployee verifiee" -ForegroundColor Green
Write-Host "OK Composant CondensationProviderSettings present" -ForegroundColor Green
Write-Host "`nNEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. Redemarrez VSCode COMPLETEMENT (Ctrl+Shift+P > Reload Window)" -ForegroundColor Cyan
Write-Host "2. Ouvrez les Settings Roo (icone engrenage)" -ForegroundColor Cyan
Write-Host "3. Allez dans 'Context Management'" -ForegroundColor Cyan
Write-Host "4. Testez les radio buttons 'Context Condensation Provider'" -ForegroundColor Cyan
Write-Host "5. Confirmez que la selection fonctionne correctement" -ForegroundColor Cyan
Write-Host "`nNote: Les variables d'etat React (comme 'selectedProvider') sont" -ForegroundColor Gray
Write-Host "minifiees en production, c'est normal qu'elles ne soient pas visibles." -ForegroundColor Gray