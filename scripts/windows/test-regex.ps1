# Test the regex detection directly

$logPath = "$env:TEMP\test-docker-monitor.log"

# Create test log with hang message
$content = @"
2026-04-14 10:00:00 [main.enginedependencies] Docker engine started
2026-04-14 10:30:15 [main.enginedependencies] init control API initialized
2026-04-14 10:36:15 [main.enginedependencies] still waiting for init control API to respond after 0 h 6 m
"@

$content | Out-File -FilePath $logPath -Encoding UTF8

# Test the regex
$lastLine = $null
$logContent = Get-Content $logPath -ErrorAction SilentlyContinue

if ($logContent) {
    $waitingLines = $logContent | Where-Object { $_ -match "still waiting for init control API to respond after" }
    if ($waitingLines) {
        $lastLine = $waitingLines[-1]
        Write-Host "Last waiting line: $lastLine" -ForegroundColor Yellow

        if ($lastLine -match "still waiting for init control API to respond after (\d+)h(\d+)m") {
            $hours = [int]$matches[1]
            $minutes = [int]$matches[2]
            $totalSeconds = ($hours * 3600) + ($minutes * 60)

            Write-Host "Detected: $hours h $minutes m = $totalSeconds seconds" -ForegroundColor Cyan

            if ($totalSeconds -gt 300) {  # 5 minutes
                Write-Host "HANG DETECTED!" -ForegroundColor Red
            } else {
                Write-Host "No hang detected" -ForegroundColor Green
            }
        }
    }
}

# Cleanup
Remove-Item $logPath -Force