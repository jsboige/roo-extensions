#!/usr/bin/env pwsh
# Validation finale avant PR

Write-Host "🎯 Final Validation Check" -ForegroundColor Cyan

$errors = 0

# 1. Tests Backend
Write-Host "`n📋 Backend Tests..." -ForegroundColor Yellow
cd C:/dev/roo-code/src
$result = npx vitest run --reporter=verbose 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Backend tests failing" -ForegroundColor Red
    $errors++
} else {
    Write-Host "✅ Backend tests: 100%" -ForegroundColor Green
}

# 2. Tests UI
Write-Host "`n🎨 UI Tests..." -ForegroundColor Yellow
cd C:/dev/roo-code/webview-ui
$result = npx vitest run --reporter=verbose 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ UI tests failing" -ForegroundColor Red
    $errors++
} else {
    Write-Host "✅ UI tests: 100%" -ForegroundColor Green
}

# 3. ESLint
Write-Host "`n🔍 ESLint..." -ForegroundColor Yellow
cd C:/dev/roo-code
$result = npx eslint src/core/condense webview-ui/src/components/settings --max-warnings 0 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ ESLint warnings found" -ForegroundColor Red
    $errors++
} else {
    Write-Host "✅ ESLint: Clean" -ForegroundColor Green
}

# 4. Git status
Write-Host "`n📦 Git Status..." -ForegroundColor Yellow
cd C:/dev/roo-code
$status = git status --porcelain
if ($status) {
    Write-Host "❌ Uncommitted changes found" -ForegroundColor Red
    $errors++
} else {
    Write-Host "✅ Working tree clean" -ForegroundColor Green
}

# 5. Docs validation
Write-Host "`n📚 Documentation..." -ForegroundColor Yellow
$docs = @(
    "C:/dev/roo-code/src/core/condense/README.md",
    "C:/dev/roo-code/src/core/condense/docs/ARCHITECTURE.md",
    "C:/dev/roo-code/src/core/condense/providers/smart/README.md",
    "C:/dev/roo-code/.changeset/context-condensation-providers.md"
)

foreach ($doc in $docs) {
    if (!(Test-Path $doc)) {
        Write-Host "❌ Missing doc: $doc" -ForegroundColor Red
        $errors++
    }
}

if ($errors -eq 0) {
    Write-Host "`n✅ All docs present" -ForegroundColor Green
}

# Final result
Write-Host "`n" + "="*50
if ($errors -eq 0) {
    Write-Host "🎉 ALL VALIDATIONS PASSED - READY FOR PR!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ $errors validation(s) failed" -ForegroundColor Red
    exit 1
}