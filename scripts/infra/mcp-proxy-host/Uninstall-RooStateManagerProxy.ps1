#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Uninstalls the MCP-Proxy-RSM Windows service.

.PARAMETER ServiceName
    Service name (default: MCP-Proxy-RSM).

.PARAMETER RemoveFiles
    Also delete install directory and binary.

.PARAMETER InstallPath
    Install directory to remove when -RemoveFiles is set (default: D:\Tools\mcp-proxy-rsm).
#>
[CmdletBinding()]
param(
    [string]$ServiceName = "MCP-Proxy-RSM",
    [switch]$RemoveFiles,
    [string]$InstallPath = "D:\Tools\mcp-proxy-rsm"
)

$ErrorActionPreference = "Stop"

$nssm = Get-Command nssm -ErrorAction SilentlyContinue
if (-not $nssm) { throw "NSSM not found. Install it first or remove the service manually." }

$status = & nssm status $ServiceName 2>$null
if ($status -match "SERVICE_") {
    Write-Host "Stopping $ServiceName..."
    & nssm stop $ServiceName confirm 2>&1 | Out-Null
    Write-Host "Removing service..."
    & nssm remove $ServiceName confirm 2>&1 | Out-Null
    Write-Host "Service removed" -ForegroundColor Green
} else {
    Write-Host "Service $ServiceName not installed" -ForegroundColor Yellow
}

if ($RemoveFiles -and (Test-Path $InstallPath)) {
    Write-Host "Removing $InstallPath..."
    Remove-Item -Recurse -Force $InstallPath
    Write-Host "Files removed" -ForegroundColor Green
}
