$content = "still waiting for init control API to respond after 0 h 6 m"

Write-Host "Content: $content"
Write-Host "Length: $($content.Length)"

# Test various patterns
$patterns = @(
    "after 0 h 6 m",
    "after ([0-9]+)h([0-9]+)m",
    "after (\d+)h(\d+)m",
    "after.*?(\d+)h(\d+)m"
)

foreach ($pattern in $patterns) {
    Write-Host "`nPattern: $pattern"
    if ($content -match $pattern) {
        Write-Host "MATCH! Hours: $($matches[1]), Minutes: $($matches[2])" -ForegroundColor Green
    } else {
        Write-Host "NO MATCH!" -ForegroundColor Red
    }
}