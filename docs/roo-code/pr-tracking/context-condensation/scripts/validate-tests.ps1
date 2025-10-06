#!/usr/bin/env powershell
# Validation complète des tests avant PR - Context Condensation System
# Phase 6: Pré-PR Validation

Write-Host "🧪 Validation Tests - Context Condensation System" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Stop"
$overallSuccess = $true

# Backend tests
Write-Host "📦 Backend Tests..." -ForegroundColor Yellow
Set-Location "C:/dev/roo-code/src"

try {
    $backendOutput = npx vitest run core/condense/__tests__/ --reporter=verbose 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Backend tests failed" -ForegroundColor Red
        Write-Host $backendOutput
        $overallSuccess = $false
    } else {
        Write-Host "✅ Backend tests passed" -ForegroundColor Green
        
        # Extract test count
        $backendOutput -match "Tests\s+(\d+)\s+passed" | Out-Null
        if ($matches) {
            Write-Host "   → $($matches[1]) tests passed" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "❌ Backend tests failed with exception: $_" -ForegroundColor Red
    $overallSuccess = $false
}

Write-Host ""

# UI tests
Write-Host "🎨 UI Tests (CondensationProviderSettings)..." -ForegroundColor Yellow
Set-Location "C:/dev/roo-code/webview-ui"

try {
    $uiOutput = npx vitest run src/components/settings/__tests__/CondensationProviderSettings.spec.tsx --reporter=verbose 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ UI tests failed" -ForegroundColor Red
        Write-Host $uiOutput
        $overallSuccess = $false
    } else {
        Write-Host "✅ UI tests passed" -ForegroundColor Green
        
        # Extract test count
        $uiOutput -match "Tests\s+(\d+)\s+passed" | Out-Null
        if ($matches) {
            Write-Host "   → $($matches[1]) tests passed" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "❌ UI tests failed with exception: $_" -ForegroundColor Red
    $overallSuccess = $false
}

Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan

if ($overallSuccess) {
    Write-Host "🎉 All tests passed! Ready for PR" -ForegroundColor Green
    exit 0
} else {
    Write-Host "💥 Some tests failed. Please fix before PR." -ForegroundColor Red
    exit 1
}