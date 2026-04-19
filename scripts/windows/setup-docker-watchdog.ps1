<#
.SYNOPSIS
    Setup script for Docker/WSL Watchdog scheduled task
.DESCRIPTION
    Creates a scheduled task that runs the Docker/WSL watchdog every 5 minutes.
    Designed for ai-01 (myia-ai-01) only initially.
#>

param(
    [string]$TaskName = "Docker-WSL-Watchdog",
    [string]$ScriptPath = "$PSScriptRoot\docker-wsl-watchdog.ps1",
    [int]$IntervalMinutes = 5,
    [switch]$Force = $false
)

# Configuration
$TaskDescription = "Monitors Docker logs for init control API hangs and WSL switch health. Auto-restarts services if issues detected. Issue #1380."
$TaskUser = "SYSTEM"  # Run as SYSTEM for maximum privileges
$LogPath = "$PSScriptRoot\..\..\..\claude\logs\docker-watchdog.log"

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin -and -not $Force) {
    Write-Error "This script must be run as an administrator. Use -Force to skip this check."
    exit 1
}

# Verify watchdog script exists
if (-not (Test-Path $ScriptPath)) {
    Write-Error "Watchdog script not found: $ScriptPath"
    exit 1
}

# Create log directory if it doesn't exist
$logDir = Split-Path $LogPath -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Convert interval to format for schtasks
$Interval = "$($IntervalMinutes)Minutes"

# Check if task already exists
$existingTask = schtasks /query /tn $TaskName /fo list 2>$null
if ($existingTask -and -not $Force) {
    Write-Warning "Task '$TaskName' already exists. Use -Force to overwrite."
    exit 0
}

# Create the scheduled task action
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
                                  -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""

# Create the trigger
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
                                   -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) `
                                   -RepetitionDuration (New-TimeSpan -Days (365 * 10))  # 10 years

# Set task settings
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                                        -StartWhenAvailable -DontStopOnIdleEnd `
                                        -ExecutionTimeLimit (New-TimeSpan -Hours 2) `
                                        -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

# Create task principal
$principal = New-ScheduledTaskPrincipal -UserId $TaskUser -LogonType ServiceAccount -RunLevel Highest

# Create the task
$task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Principal $principal `
                          -Description $TaskDescription

# Register the task
try {
    Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force:$Force | Out-Null

    Write-Host "✅ Task '$TaskName' created successfully" -ForegroundColor Green
    Write-Host "   • Script: $ScriptPath" -ForegroundColor Gray
    Write-Host "   • User: $TaskUser" -ForegroundColor Gray
    Write-Host "   • Interval: Every $IntervalMinutes minutes" -ForegroundColor Gray
    Write-Host "   • Log: $LogPath" -ForegroundColor Gray
    Write-Host "   • Next run: $(Get-Date (Get-ScheduledTaskNextRunTime -TaskName $TaskName) -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

    # Test the task immediately
    Write-Host "🔍 Running test check..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2  # Brief delay
    & $ScriptPath -Verbose

    Write-Host "`n✅ Setup completed!" -ForegroundColor Green
    Write-Host "The watchdog will run automatically every $IntervalMinutes minutes." -ForegroundColor Gray
    Write-Host "To view logs: tail -f $LogPath" -ForegroundColor Gray

} catch {
    Write-Error "Failed to create scheduled task: $_"
    exit 1
}

# Create uninstall script
$uninstallScript = @"
# Uninstall Docker/WSL Watchdog
Write-Host "Uninstalling Docker/WSL Watchdog..." -ForegroundColor Yellow

# Stop and delete the task
\$taskExists = schtasks /query /tn "$TaskName" /fo list 2>`$null
if (\$taskExists) {
    schtasks /delete /tn "$TaskName" /f | Out-Null
    Write-Host "✅ Task '$TaskName' deleted" -ForegroundColor Green
} else {
    Write-Host "ℹ️ Task '$TaskName' not found" -ForegroundColor Gray
}

# Keep logs for manual review
Write-Host "📁 Logs preserved at: $LogPath" -ForegroundColor Gray
Write-Host "To remove logs manually: Remove-Item '$LogPath'" -ForegroundColor Gray
"@

$uninstallPath = Join-Path (Split-Path $ScriptPath -Parent) "uninstall-docker-watchdog.ps1"
$uninstallScript | Out-File -FilePath $uninstallPath -Encoding UTF8NoBOM

Write-Host "`n📝 Uninstall script created: $uninstallPath" -ForegroundColor Gray