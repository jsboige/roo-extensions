# Demo test for Docker/WSL Watchdog

Write-Host "🧪 Demo test for Docker/WSL Watchdog" -ForegroundColor Cyan

# Create test log directory
$logDir = "C:\tmp\docker-watchdog-test"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Test log path
$testLogPath = Join-Path $logDir "test-monitor.log"
$watchdogLogPath = Join-Path $logDir "watchdog.log"

# Create test log with hang message
Write-Host "📄 Creating test log with Docker hang..." -ForegroundColor Yellow
$content = @"
2026-04-14 10:00:00 [main.enginedependencies] Docker engine started
2026-04-14 10:30:15 [main.enginedependencies] init control API initialized
2026-04-14 10:36:15 [main.enginedependencies] still waiting for init control API to respond after 0 h 6 m
"@

$content | Out-File -FilePath $testLogPath -Encoding UTF8
Write-Host "✅ Test log created: $testLogPath" -ForegroundColor Green

# Test regex detection
Write-Host "`n🔍 Testing regex detection..." -ForegroundColor Cyan
$logContent = Get-Content $testLogPath -ErrorAction SilentlyContinue

if ($logContent) {
    Write-Host "Log content:"
    $logContent | ForEach-Object { "[$_]" }

    $waitingLines = $logContent | Where-Object { $_ -match "still waiting for init control API to respond after" }
    Write-Host "`nFound $($waitingLines.Count) waiting lines"

    if ($waitingLines) {
        $lastLine = [string]$waitingLines[-1]
        Write-Host "Last line: '$lastLine'" -ForegroundColor Yellow

        if ($lastLine -match "still waiting for init control API to respond after (\d+)h(\d+)m") {
            $hours = [int]$matches[1]
            $minutes = [int]$matches[2]
            $totalSeconds = ($hours * 3600) + ($minutes * 60)

            Write-Host "✅ Parsed: $hours h $minutes m = $totalSeconds seconds" -ForegroundColor Green

            if ($totalSeconds -gt 300) {  # 5 minutes
                Write-Host "🚨 HANG DETECTED! (threshold: 300 seconds)" -ForegroundColor Red
            } else {
                Write-Host "✅ No hang detected" -ForegroundColor Green
            }
        } else {
            Write-Host "❌ Regex did not match!" -ForegroundColor Red
        }
    }
}

# Test watchdog with shorter threshold
Write-Host "`n🐛 Testing watchdog with 1-minute threshold..." -ForegroundColor Cyan
& "$PSScriptRoot\docker-wsl-watchdog.ps1" -LogPath $testLogPath -MaxWaitMinutes 1 -Verbose

# Cleanup
Remove-Item -Path $logDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "`n🧹 Cleanup completed" -ForegroundColor Gray