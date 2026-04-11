# Docker Auto-Boot Fix Script
# Issue #1171 - Configure Docker to start at boot

param(
    [switch]$WhatIf
)

Write-Host "=== Docker Auto-Boot Fix ===" -ForegroundColor Cyan
if ($WhatIf) {
    Write-Host "WHATIF MODE: No changes will be made" -ForegroundColor Yellow
}

# 1. Create scheduled task for Docker startup at boot
Write-Host "`n=== Creating Scheduled Task for Docker ===" -ForegroundColor Cyan

$taskName = "Docker Desktop Auto-Start"
$dockerPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
$taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($taskExists) {
    Write-Host "Scheduled task '$taskName' already exists" -ForegroundColor Yellow
    if (-not $WhatIf) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host "Removed existing task" -ForegroundColor Green
    }
}

$action = New-ScheduledTaskAction -Execute $dockerPath
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Write-Host "Creating scheduled task:" -ForegroundColor White
Write-Host "  Name: $taskName" -ForegroundColor White
Write-Host "  Trigger: At Startup" -ForegroundColor White
Write-Host "  Principal: SYSTEM" -ForegroundColor White
Write-Host "  Action: $dockerPath" -ForegroundColor White

if (-not $WhatIf) {
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    Write-Host "✓ Scheduled task created" -ForegroundColor Green

    # Verify
    $task = Get-ScheduledTask -TaskName $taskName
    Write-Host "  State: $($task.State)" -ForegroundColor Green
} else {
    Write-Host "[WHATIF] Would create scheduled task" -ForegroundColor Yellow
}

# 2. Set Docker service to Automatic
Write-Host "`n=== Configuring Docker Service ===" -ForegroundColor Cyan

$serviceName = "com.docker.service"
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if ($service) {
    Write-Host "Current service state:" -ForegroundColor White
    Write-Host "  Name: $($service.Name)" -ForegroundColor White
    Write-Host "  Status: $($service.Status)" -ForegroundColor White
    Write-Host "  StartType: $($service.StartType)" -ForegroundColor White

    if (-not $WhatIf) {
        Set-Service -Name $serviceName -StartupType Automatic
        Write-Host "✓ Service start type set to Automatic" -ForegroundColor Green

        # Start the service if not running
        if ($service.Status -ne "Running") {
            Write-Host "Starting service..." -ForegroundColor White
            Start-Service -Name $serviceName
            Start-Sleep -Seconds 2
            $service.Refresh()
            Write-Host "  Status: $($service.Status)" -ForegroundColor $(if ($service.Status -eq "Running") { "Green" } else { "Yellow" })
        }
    } else {
        Write-Host "[WHATIF] Would set service to Automatic" -ForegroundColor Yellow
    }
} else {
    Write-Host "✗ Docker service not found" -ForegroundColor Yellow
}

Write-Host "`n=== Fix Complete ===" -ForegroundColor Cyan
Write-Host "Docker should now start automatically at boot." -ForegroundColor Green
Write-Host "To test immediately: Restart-Computer -Force" -ForegroundColor Yellow
