#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs the host-side mcp-proxy as a Windows Scheduled Task exposing roo-state-manager via Streamable HTTP.

.DESCRIPTION
    Downloads tbxark/mcp-proxy Windows binary to D:\Tools\mcp-proxy-rsm\, generates a Bearer token
    if none is provided, writes config.json, and registers the binary as a Scheduled Task that runs
    in the user's interactive session (LogonType Interactive) at logon.

    The Task Scheduler approach is required instead of a Windows Service (NSSM) because:
    - Google Drive File Stream (G:\) is mounted per user session and is NOT accessible
      to LocalSystem or services running outside an interactive session.
    - The roo-state-manager subprocess (node mcp-wrapper.cjs) reads RooSync state from G:\,
      so it must run as the logged-on user with their GDrive mount.

    After install: the task runs on user logon, the proxy listens on 127.0.0.1:9091 and
    exposes /roo-state-manager/mcp. Docker mcp-proxy container reaches it via host.docker.internal:9091.

.PARAMETER InstallPath
    Install directory (default: D:\Tools\mcp-proxy-rsm).

.PARAMETER Port
    TCP port to bind (default: 9091).

.PARAMETER BindAddress
    Bind address (default: 127.0.0.1 - localhost only). Use 0.0.0.0 to expose on LAN.

.PARAMETER Token
    Bearer token. If omitted, a random 64-char hex token is generated.

.PARAMETER RooStateManagerPath
    Path to roo-state-manager mcp-wrapper.cjs (default: D:\roo-extensions\mcps\internal\servers\roo-state-manager\mcp-wrapper.cjs).

.PARAMETER TaskName
    Scheduled task name (default: MCP-Proxy-RSM).

.PARAMETER RunAsUser
    User to run the task as (default: current interactive user, format DOMAIN\user).
    This user must own the Google Drive File Stream mount used by roo-state-manager.

.EXAMPLE
    .\Install-RooStateManagerProxy.ps1
    Installs with defaults and random token, runs as the current user at logon.

.EXAMPLE
    .\Install-RooStateManagerProxy.ps1 -Token "existing-token-here" -BindAddress "0.0.0.0"
    Installs with specific token exposed on LAN.
#>
[CmdletBinding()]
param(
    [string]$InstallPath = "D:\Tools\mcp-proxy-rsm",
    [int]$Port = 9091,
    [string]$BindAddress = "127.0.0.1",
    [string]$Token = "",
    [string]$RooStateManagerPath = "D:\roo-extensions\mcps\internal\servers\roo-state-manager\mcp-wrapper.cjs",
    [string]$TaskName = "MCP-Proxy-RSM",
    [string]$RunAsUser = "$env:COMPUTERNAME\$env:USERNAME"
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "    WARN: $msg" -ForegroundColor Yellow }

Write-Step "Checking prerequisites"

# Node.js (must be in PATH of the user who will run the task)
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) { throw "Node.js not found in PATH. Install Node.js 20+ first." }
Write-Ok "Node.js: $($node.Source)"

# roo-state-manager wrapper
if (-not (Test-Path $RooStateManagerPath)) { throw "Wrapper not found: $RooStateManagerPath" }
Write-Ok "roo-state-manager wrapper: $RooStateManagerPath"

Write-Step "Preparing install directory"
New-Item -ItemType Directory -Force -Path $InstallPath | Out-Null
Write-Ok "Install path: $InstallPath"

Write-Step "Downloading mcp-proxy binary (tbxark v0.43.2)"
$binary = Join-Path $InstallPath "mcp-proxy.exe"
if (Test-Path $binary) {
    Write-Ok "Binary already present - skipping download"
} else {
    $url = "https://github.com/tbxark/mcp-proxy/releases/download/v0.43.2/mcp-proxy_0.43.2_windows_amd64.tar.gz"
    $tarball = Join-Path $InstallPath "mcp-proxy.tar.gz"
    Invoke-WebRequest -Uri $url -OutFile $tarball -UseBasicParsing
    tar -xzf $tarball -C $InstallPath
    Remove-Item $tarball
    if (-not (Test-Path $binary)) { throw "Extraction failed: $binary not found" }
    Write-Ok "Downloaded and extracted"
}

Write-Step "Writing config.json"
if (-not $Token) {
    $bytes = New-Object byte[] 32
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $Token = ($bytes | ForEach-Object { $_.ToString("x2") }) -join ""
    Write-Ok "Generated random Bearer token"
}

$configPath = Join-Path $InstallPath "config.json"
$wrapperEscaped = $RooStateManagerPath.Replace("\", "\\")
$config = @"
{
  "mcpProxy": {
    "baseURL": "http://${BindAddress}:${Port}",
    "addr": "${BindAddress}:${Port}",
    "name": "RooStateManager Host Proxy",
    "version": "1.0.0",
    "type": "streamable-http",
    "options": {
      "panicIfInvalid": false,
      "logEnabled": true,
      "authTokens": ["$Token"]
    }
  },
  "mcpServers": {
    "roo-state-manager": {
      "command": "node",
      "args": ["$wrapperEscaped"],
      "env": {
        "WORKSPACE_PATH": "D:\\roo-extensions"
      }
    }
  }
}
"@
[System.IO.File]::WriteAllText($configPath, $config, [System.Text.UTF8Encoding]::new($false))
Write-Ok "Config written: $configPath"

Write-Step "Registering Scheduled Task (interactive user session)"

# Remove existing task if present
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

$action    = New-ScheduledTaskAction -Execute $binary -Argument "-config `"$configPath`"" -WorkingDirectory $InstallPath
$trigger   = New-ScheduledTaskTrigger -AtLogOn -User $RunAsUser
$principal = New-ScheduledTaskPrincipal -UserId $RunAsUser -LogonType Interactive -RunLevel Limited
$settings  = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -RestartCount 5 `
    -StartWhenAvailable

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description "tbxark/mcp-proxy exposing roo-state-manager via Streamable HTTP on ${BindAddress}:${Port}" `
    -Force | Out-Null

Write-Ok "Task registered - runs as $RunAsUser at logon"

Write-Step "Starting task"
Start-ScheduledTask -TaskName $TaskName
Start-Sleep -Seconds 5

$task = Get-ScheduledTask -TaskName $TaskName
$info = Get-ScheduledTaskInfo -TaskName $TaskName
Write-Ok "Task state: $($task.State), LastTaskResult: $($info.LastTaskResult)"

$proc = Get-Process mcp-proxy -ErrorAction SilentlyContinue
if ($proc) { Write-Ok "mcp-proxy process: PID=$($proc.Id)" }
else { Write-Warn "mcp-proxy process not detected yet - may still be starting" }

Write-Step "Verifying HTTP endpoint"
Start-Sleep -Seconds 2
try {
    $headers = @{ "Authorization" = "Bearer $Token"; "Accept" = "application/json, text/event-stream" }
    $body = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"install-check","version":"1.0"}}}'
    $resp = Invoke-WebRequest -Uri "http://${BindAddress}:${Port}/roo-state-manager/mcp" -Method POST -Headers $headers -ContentType "application/json" -Body $body -UseBasicParsing -TimeoutSec 15
    if ($resp.StatusCode -eq 200) { Write-Ok "Endpoint responded 200 OK" }
    else { Write-Warn "Unexpected status: $($resp.StatusCode)" }
} catch {
    Write-Warn "Verification failed: $($_.Exception.Message)"
    Write-Warn "Task may still be starting. Check: Get-ScheduledTaskInfo -TaskName $TaskName"
}

Write-Host ""
Write-Host "=========================================================" -ForegroundColor Green
Write-Host "  Installation complete" -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green
Write-Host "  Task name    : $TaskName"
Write-Host "  Runs as      : $RunAsUser (interactive, at logon)"
Write-Host "  Endpoint     : http://${BindAddress}:${Port}/roo-state-manager/mcp"
Write-Host "  Bearer token : $Token"
Write-Host "  Config       : $configPath"
Write-Host ""
Write-Host "  Save the token securely - it is required in Authorization header:" -ForegroundColor Yellow
Write-Host "    Authorization: Bearer $Token" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Next step: register in Docker mcp-proxy config" -ForegroundColor Cyan
Write-Host "  See: docs/harness/reference/mcp-proxy-host.md" -ForegroundColor Cyan
