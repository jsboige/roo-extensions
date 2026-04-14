# Simple test

$line = "2026-04-14 10:36:15 [main.enginedependencies] still waiting for init control API to respond after 0 h 6 m"
Write-Host "Line: $line"

if ($line -match "still waiting for init control API to respond after (\d+)h(\d+)m") {
    Write-Host "Match found!" -ForegroundColor Green
    Write-Host "Hours: $($matches[1])"
    Write-Host "Minutes: $($matches[2])"
} else {
    Write-Host "No match!" -ForegroundColor Red
}

# Test with different line
$line2 = "1	2026-04-14 10:36:15 [main.enginedependencies] still waiting for init control API to respond after 0 h 6 m"
Write-Host "`nWith line number: $line2"

if ($line2 -match "still waiting for init control API to respond after (\d+)h(\d+)m") {
    Write-Host "Match found!" -ForegroundColor Green
    Write-Host "Hours: $($matches[1])"
    Write-Host "Minutes: $($matches[2])"
} else {
    Write-Host "No match!" -ForegroundColor Red
}