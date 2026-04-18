# Script pour configurer la surveillance de TurboQuant via Task Scheduler

param(
    [bool]$Remove = $false,
    [string]$Schedule = "Monthly",
    [string]$Time = "10:00"
)

$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$PowerShellScript = Join-Path $ScriptPath "monitor-turboquant.ps1"
$TaskName = "TurboQuantMonitor"
$TaskDescription = "Monthly monitoring of TurboQuant availability in Qdrant"

Write-Host "Configuring TurboQuant Monitor Task..." -ForegroundColor Cyan

if ($Remove) {
    # Supprimer la tâche existante
    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
        Write-Host "Task '$TaskName' removed successfully" -ForegroundColor Green
    } catch {
        Write-Host "Task '$TaskName' not found or error removing it" -ForegroundColor Yellow
    }
    exit
}

# Vérifier si PowerShell 5.1 est disponible
if (-not (Get-Command "powershell.exe" -ErrorAction SilentlyContinue)) {
    Write-Host "PowerShell 5.1 is required" -ForegroundColor Red
    exit 1
}

# Paramètres pour la tâche planifiée
$taskParams = @{
    TaskName = $TaskName
    Description = $TaskDescription
    Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$PowerShellScript`""
    Trigger = switch ($Schedule) {
        "Monthly" { New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek Sunday -At $Time }
        "Weekly" { New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek Sunday -At $Time }
        "Daily" { New-ScheduledTaskTrigger -Daily -At $Time }
        default { New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek Sunday -At $Time }
    }
    Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd -ExecutionTimeLimit (New-TimeSpan -Hours 2)
}

# Créer la tâche
try {
    Register-ScheduledTask @taskParams -Force
    Write-Host "Task '$TaskName' created successfully" -ForegroundColor Green

    # Afficher les détails de la tâche
    $task = Get-ScheduledTask -TaskName $TaskName
    Write-Host "`nTask Details:" -ForegroundColor Cyan
    Write-Host "Name: $($task.TaskName)"
    Write-Host "Description: $($task.Description)"
    Write-Host "Schedule: $($task.Triggers[0].WeeklyInterval) weeks on $($task.Triggers[0].DaysOfWeek) at $($task.Triggers[0].At)"
    Write-Host "Next Run: $($task.Triggers[0].NextRunTime)"

    Write-Host "`nMonitoring will run every $($task.Triggers[0].WeeklyInterval) week(s) on $($task.Triggers[0].DaysOfWeek) at $Time" -ForegroundColor Cyan
    Write-Host "You can check the logs in: reports/turboquant-monitor.log" -ForegroundColor Cyan

} catch {
    Write-Host "Error creating task: $_" -ForegroundColor Red
    exit 1
}