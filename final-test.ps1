$content = "still waiting for init control API to respond after 0 h 6 m"

Write-Host "Content: '$content'"

# Try with more specific pattern
if ($content -match "after (\d+)h(\d+)m") {
    Write-Host "Match 1 - Hours: $($matches[1]), Minutes: $($matches[2])" -ForegroundColor Green
} else {
    Write-Host "No match 1" -ForegroundColor Red
}

# Try with literal string
$literal = "after 0 h 6 m"
Write-Host "`nLiteral: '$literal'"
if ($content -match [regex]::Escape($literal)) {
    Write-Host "Match literal!" -ForegroundColor Green
}

# Extract numbers manually
$numbers = $content | Select-String -Pattern "(\d+)" -AllMatches
Write-Host "`nNumbers found:"
$numbers.Matches | ForEach-Object { Write-Host "  $_" }

# Try splitting
$parts = $content.Split(" ")
Write-Host "`nParts:"
$parts | ForEach-Object { "  '$_'" }

# Find the part with "after"
$afterPart = $parts | Where-Object { $_ -like "after*" }
Write-Host "`nAfter part: '$afterPart'"

if ($afterPart) {
    $afterParts = $afterPart.Split(" ")
    Write-Host "After split: $($afterParts.Count) parts"
    if ($afterParts.Count -ge 3) {
        $hours = $afterParts[1]
        $minutes = $afterParts[2]
        Write-Host "Hours: $hours, Minutes: $minutes" -ForegroundColor Yellow
    }
}