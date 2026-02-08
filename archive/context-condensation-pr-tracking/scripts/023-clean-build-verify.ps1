# Clean Build and Component Verification Script
# Usage: .\023-clean-build-verify.ps1

$ErrorActionPreference = "Stop"

Write-Host "`n=== CLEAN BUILD + VERIFICATION ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Gray

# Step 1: Clean webview-ui build only
Write-Host "[1/4] Clean webview-ui build..." -ForegroundColor Yellow
Push-Location "C:\dev\roo-code\webview-ui"
Remove-Item -Path "build" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "dist" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "  OK Clean done`n" -ForegroundColor Green
Pop-Location

# Step 2: Build webview-ui
Write-Host "[2/4] Build webview-ui..." -ForegroundColor Yellow
Push-Location "C:\dev\roo-code\webview-ui"
pnpm run build
if ($LASTEXITCODE -ne 0) { throw "webview-ui build failed" }
Pop-Location

# Verify component in local build
Write-Host "`n  Checking component in local build..." -ForegroundColor Cyan
$buildPath = "C:\dev\roo-code\src\webview-ui\build\assets"
$indexJs = Get-ChildItem $buildPath -Filter "index*.js" -ErrorAction SilentlyContinue | Select-Object -First 1

if ($indexJs) {
    $content = Get-Content $indexJs.FullName -Raw
    $patterns = @("CondensationProviderSettings", "Context Condensation Provider")
    $localOK = $true
    
    foreach ($pattern in $patterns) {
        if ($content -match [regex]::Escape($pattern)) {
            Write-Host "    OK '$pattern' found" -ForegroundColor Green
        } else {
            Write-Host "    FAIL '$pattern' missing!" -ForegroundColor Red
            $localOK = $false
        }
    }
    
    if (-not $localOK) {
        Write-Host "`n  ERROR: Component missing from local build!" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "    FAIL index*.js not found!" -ForegroundColor Red
    exit 1
}

Write-Host "  OK Local build verified`n" -ForegroundColor Green

# Step 3: Build backend
Write-Host "[3/4] Build backend..." -ForegroundColor Yellow
Push-Location "C:\dev\roo-code\src"
npm run build
if ($LASTEXITCODE -ne 0) { throw "backend build failed" }
Write-Host "  OK Backend built`n" -ForegroundColor Green
Pop-Location

# Step 4: Deploy
Write-Host "[4/4] Deploy extension..." -ForegroundColor Yellow
Push-Location "C:\dev\roo-extensions\roo-code-customization"
pwsh -File .\deploy-standalone.ps1
if ($LASTEXITCODE -ne 0) { throw "deployment failed" }
Pop-Location

# Wait for files to be written
Start-Sleep -Seconds 2

# Verify component in deployed extension
Write-Host "`n  Checking component in deployed extension..." -ForegroundColor Cyan
$extPath = "C:\Users\jsboi\.vscode\extensions\rooveterinaryinc.roo-cline-3.28.16"
$deployedPath = "$extPath\dist\webview-ui\build\assets"
$deployedJs = Get-ChildItem $deployedPath -Filter "index*.js" -ErrorAction SilentlyContinue | Select-Object -First 1

if ($deployedJs) {
    $deployedContent = Get-Content $deployedJs.FullName -Raw
    $deployedOK = $true
    
    foreach ($pattern in $patterns) {
        if ($deployedContent -match [regex]::Escape($pattern)) {
            Write-Host "    OK '$pattern' found" -ForegroundColor Green
        } else {
            Write-Host "    FAIL '$pattern' missing!" -ForegroundColor Red
            $deployedOK = $false
        }
    }
    
    if ($deployedOK) {
        Write-Host "`n=== SUCCESS ===" -ForegroundColor Green
        Write-Host "OK Component present in local build" -ForegroundColor Green
        Write-Host "OK Component present in deployed extension" -ForegroundColor Green
        Write-Host "`nNEXT: Restart VSCode to test" -ForegroundColor Yellow
    } else {
        Write-Host "`n=== WARNING ===" -ForegroundColor Yellow
        Write-Host "OK Component in local build" -ForegroundColor Green
        Write-Host "FAIL Component missing from deployed extension" -ForegroundColor Red
        Write-Host "`nThe component is lost during deployment" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "    FAIL Deployed bundle not found!" -ForegroundColor Red
    exit 1
}