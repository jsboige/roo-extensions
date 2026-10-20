<#
.SYNOPSIS
    Installs the user-level scheduled task that runs the approval-stall detector (#4243 item 3).

.DESCRIPTION
    Registers 'Claude-ApprovalStallDetector': every 2 h at :37, a hidden VBS runs
    run-approval-stall-detector.ps1 from THIS checkout with -BotEnvFile. User task,
    RunLevel Limited: no elevation anywhere. The VBS lives under %LOCALAPPDATA% (a file
    pre-created under C:\ProgramData from an elevated shell is read-only for a user task).

    The bearer is never passed to the task: the launcher reads MCP_PROXY_BEARER (and
    MCP_PROXY_BASE_URL) from -BotEnvFile at run time. This installer only checks that the
    key is present in that file; it never prints the value.

    -DryRun builds and validates the task object (New-ScheduledTask) and prints it with the
    VBS text, writing nothing. Re-running without -DryRun replaces an existing task.

.PARAMETER BotEnvFile
    File holding MCP_PROXY_BEARER / MCP_PROXY_BASE_URL. Default: %USERPROFILE%\.roo-state-manager\stall-detector.env
    (outside every repository). ai-01 uses D:\nanoclaw\.env.

.PARAMETER Python
    Interpreter the launcher runs the detector with. Empty (default) = the launcher's own
    default, 'python' from PATH. Set it on a seat whose 'python' is only the WindowsApps stub
    (e.g. a uv-managed interpreter): the stub exits non-zero and the task would fail every tick.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\diagnostic\install-approval-stall-detector-task.ps1 -DryRun
    powershell -ExecutionPolicy Bypass -File scripts\diagnostic\install-approval-stall-detector-task.ps1

.NOTES
    Rollback: Unregister-ScheduledTask -TaskName Claude-ApprovalStallDetector -Confirm:$false,
    then delete the VBS printed by the installer.
#>
param(
    [string]$BotEnvFile = (Join-Path $env:USERPROFILE '.roo-state-manager\stall-detector.env'),
    [string]$TaskName = 'Claude-ApprovalStallDetector',
    [string]$Python = '',
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'

$launcher = Join-Path $PSScriptRoot 'run-approval-stall-detector.ps1'
$launcherDir = Join-Path $env:LOCALAPPDATA 'claude-hidden-launchers'
$vbsPath = Join-Path $launcherDir "$TaskName.vbs"

$hasBearer = $false
if (Test-Path -LiteralPath $BotEnvFile) {
    $hasBearer = [bool](Select-String -LiteralPath $BotEnvFile -Pattern '^\s*MCP_PROXY_BEARER\s*=\s*\S' -Quiet)
}

# VBS string literal: embedded quotes are doubled. Absent when -Python is not given, so the
# generated VBS stays byte-identical to the previous one on seats that rely on PATH.
$pythonArg = ''
if ($Python) { $pythonArg = ' -Python ""' + $Python + '""' }

$vbs = @"
' Task     : $TaskName (#4243 item 3)
' Purpose   : run the approval-stall detector without showing a console.
' Mechanism : Run(cmd, 0, True) = SW_HIDE.
' Rollback  : Unregister-ScheduledTask -TaskName $TaskName ; delete this file.
Option Explicit
Dim sh, rc
Set sh = CreateObject("WScript.Shell")
rc = sh.Run("""powershell.exe"" -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File ""$launcher"" -BotEnvFile ""$BotEnvFile""$pythonArg", 0, True)
WScript.Quit rc
"@

# First tick at the next :37 at least 5 min ahead, then every 2 h, indefinitely.
$now = Get-Date
$start = $now.Date.AddHours($now.Hour).AddMinutes(37)
if ($start -lt $now.AddMinutes(5)) { $start = $start.AddHours(1) }
$action = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "//B //Nologo `"$vbsPath`""
$trigger = New-ScheduledTaskTrigger -Once -At $start -RepetitionInterval (New-TimeSpan -Hours 2)
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -MultipleInstances IgnoreNew -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
$task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'Approval-stall detector (#4243 item 3): WARN note on workspace-roo-extensions when a session waits on an approval >= 15 min.'

"task      : $TaskName"
"action    : $($action.Execute) $($action.Arguments)"
"trigger   : once $($start.ToString('yyyy-MM-dd HH:mm')) local, repeat $($trigger.Repetition.Interval)"
"principal : $($principal.UserId) logon $($principal.LogonType) runlevel $($principal.RunLevel)"
"env file  : $BotEnvFile (MCP_PROXY_BEARER present: $hasBearer)"
"exists    : task=$([bool](Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)) vbs=$(Test-Path -LiteralPath $vbsPath) launcher=$(Test-Path -LiteralPath $launcher)"
"--- vbs ---"
$vbs

if ($DryRun) { 'DRY-RUN: nothing written'; return }
if (-not (Test-Path -LiteralPath $launcher)) { throw "launcher not found: $launcher" }
if (-not $hasBearer) { throw "MCP_PROXY_BEARER missing from $BotEnvFile -- the detector would run without its dashboard signal" }
if (-not (Test-Path -LiteralPath $launcherDir)) { New-Item -ItemType Directory -Path $launcherDir | Out-Null }
[System.IO.File]::WriteAllText($vbsPath, $vbs, (New-Object System.Text.UTF8Encoding($false)))
Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force | Out-Null
"REGISTERED: state=$((Get-ScheduledTask -TaskName $TaskName).State) next=$((Get-ScheduledTaskInfo -TaskName $TaskName).NextRunTime)"
