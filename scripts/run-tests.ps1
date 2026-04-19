cd d:/Dev/roo-extensions/mcps/internal/servers/roo-state-manager
$outputFile = "test-output.log"
$resultFile = "test-results.json"

Write-Host "Starting tests at $(Get-Date)" -ForegroundColor Green

$npxResult = npx vitest run --config vitest.config.ci.ts 2>&1 | Tee-Object -FilePath $outputFile

Write-Host "Tests completed at $(Get-Date)" -ForegroundColor Green

if (Test-Path $resultFile) {
    $jsonContent = Get-Content $resultFile -Raw
    $jsonObj = $jsonContent | ConvertFrom-Json
    $total = $jsonObj.tests.Count
    $passed = ($jsonObj.tests | Where-Object { $_.result.status -eq "pass" }).Count
    $failed = ($jsonObj.tests | Where-Object { $_.result.status -eq "fail" }).Count
    $skipped = ($jsonObj.tests | Where-Object { $_.mode -eq "skip" }).Count
    
    $report = @"
=== TEST SUMMARY ===
Total: $total
Passed: $passed
Failed: $failed
Skipped: $skipped
"@
    $report | Out-File -FilePath "test-summary.txt" -Encoding utf8
    Write-Host $report -ForegroundColor Cyan
} else {
    Write-Host "No JSON results file found" -ForegroundColor Yellow
    Write-Host "Last 30 lines of output:" -ForegroundColor Yellow
    Get-Content $outputFile | Select-Object -Last 30
}
