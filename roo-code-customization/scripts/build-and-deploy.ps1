# Build et déploiement avec build optionnel
param(
    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild,
    
    [Parameter(Mandatory=$false)]
    [switch]$DeployOnly
)

$ErrorActionPreference = "Stop"

if ($DeployOnly) {
    $SkipBuild = $true
}

Write-Host "`n=== BUILD & DEPLOY ===" -ForegroundColor Cyan

if (-not $SkipBuild) {
    # 1. Build webview-ui
    Write-Host "`n[1/3] Building webview-ui..." -ForegroundColor Yellow
    Set-Location "C:\dev\roo-code\webview-ui"
    npm run build
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Webview build failed!" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Webview built" -ForegroundColor Green

    # 2. Build extension
    Write-Host "`n[2/3] Building extension..." -ForegroundColor Yellow
    Set-Location "C:\dev\roo-code\src"
    pnpm run bundle
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Extension build failed!" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Extension built" -ForegroundColor Green
} else {
    Write-Host "`n⏭️  Skipping build (using existing build)" -ForegroundColor Yellow
}

# 3. Deploy
$stepNum = if ($SkipBuild) { "1/1" } else { "3/3" }
Write-Host "`n[$stepNum] Deploying..." -ForegroundColor Yellow
Set-Location "C:\dev\roo-extensions\roo-code-customization"
.\deploy-standalone.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Deployment failed!" -ForegroundColor Red
    exit 1
}

Write-Host "`n✅ BUILD & DEPLOY COMPLETE!" -ForegroundColor Green
Write-Host "⚠️  Restart VSCode to see changes" -ForegroundColor Yellow
Write-Host "`nUsage:" -ForegroundColor Cyan
Write-Host "  .\build-and-deploy.ps1             # Build + Deploy" -ForegroundColor Gray
Write-Host "  .\build-and-deploy.ps1 -SkipBuild  # Deploy only" -ForegroundColor Gray
Write-Host "  .\build-and-deploy.ps1 -DeployOnly # Deploy only (alias)" -ForegroundColor Gray