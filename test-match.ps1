$content = Get-Content "regex-test.txt" -First 1
Write-Host "Content: $content"
if ($content -match "after ([0-9]+)h([0-9]+)m") {
    Write-Host "MATCH! Hours: $($matches[1]), Minutes: $($matches[2])" -ForegroundColor Green
} else {
    Write-Host "NO MATCH!" -ForegroundColor Red
}