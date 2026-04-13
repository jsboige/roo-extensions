#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Uninstalls the MCP-Proxy-RSM Scheduled Task.

.PARAMETER TaskName
    Task name (default: MCP-Proxy-RSM).

.PARAMETER RemoveFiles
    Also delete install directory and binary.

.PARAMETER InstallPath
    Install directory to remove when -RemoveFiles is set (default: D:\Tools\mcp-proxy-rsm).
#>
[CmdletBinding()]
param(
    [string]$TaskName = "MCP-Proxy-RSM",
    [switch]$RemoveFiles,
    [string]$InstallPath = "D:\Tools\mcp-proxy-rsm"
)

$ErrorActionPreference = "Stop"

# Stop any running mcp-proxy process tied to this task
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($task) {
    Write-Host "Stopping $TaskName..."
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Get-Process mcp-proxy -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

    Write-Host "Unregistering scheduled task..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Task removed" -ForegroundColor Green
} else {
    Write-Host "Scheduled task $TaskName not found" -ForegroundColor Yellow
}

if ($RemoveFiles -and (Test-Path $InstallPath)) {
    Write-Host "Removing $InstallPath..."
    Remove-Item -Recurse -Force $InstallPath
    Write-Host "Files removed" -ForegroundColor Green
}
