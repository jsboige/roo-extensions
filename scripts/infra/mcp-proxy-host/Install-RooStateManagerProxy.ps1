#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs the host-side mcp-proxy as a Windows service exposing roo-state-manager via Streamable HTTP.

.DESCRIPTION
    Downloads tbxark/mcp-proxy Windows binary to D:\Tools\mcp-proxy-rsm\, generates a Bearer token
    if none is provided, writes config.json, and registers the binary as a Windows service via NSSM.

    After install: the service listens on 127.0.0.1:9091 and exposes /roo-state-manager/mcp.
    The Docker mcp-proxy container reaches it via host.docker.internal:9091.

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

.PARAMETER ServiceName
    Windows service name (default: MCP-Proxy-RSM).

.EXAMPLE
    .\Install-RooStateManagerProxy.ps1
    Installs with defaults and random token.

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
    [string]$ServiceName = "MCP-Proxy-RSM"
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "    WARN: $msg" -ForegroundColor Yellow }

Write-Step "Checking prerequisites"

# Node.js
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) { throw "Node.js not found in PATH. Install Node.js 20+ first." }
Write-Ok "Node.js: $($node.Source)"

# roo-state-manager wrapper
if (-not (Test-Path $RooStateManagerPath)) { throw "Wrapper not found: $RooStateManagerPath" }
Write-Ok "roo-state-manager wrapper: $RooStateManagerPath"

# NSSM
$nssm = Get-Command nssm -ErrorAction SilentlyContinue
if (-not $nssm) {
    Write-Warn "NSSM not found - installing via chocolatey"
    $choco = Get-Command choco -ErrorAction SilentlyContinue
    if (-not $choco) { throw "Neither NSSM nor Chocolatey found. Install NSSM manually: https://nssm.cc/download" }
    choco install nssm -y --no-progress
    $nssm = Get-Command nssm -ErrorAction Stop
}
Write-Ok "NSSM: $($nssm.Source)"

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

Write-Step "Installing Windows service via NSSM"
$existing = & nssm status $ServiceName 2>$null
if ($existing -match "SERVICE_") {
    Write-Warn "Service $ServiceName already exists - stopping and reconfiguring"
    & nssm stop $ServiceName confirm 2>&1 | Out-Null
    & nssm remove $ServiceName confirm 2>&1 | Out-Null
}

& nssm install $ServiceName $binary "-config" $configPath
& nssm set $ServiceName AppDirectory $InstallPath
& nssm set $ServiceName AppStdout (Join-Path $InstallPath "service.log")
& nssm set $ServiceName AppStderr (Join-Path $InstallPath "service.err.log")
& nssm set $ServiceName AppRotateFiles 1
& nssm set $ServiceName AppRotateBytes 10485760
& nssm set $ServiceName Start SERVICE_AUTO_START
& nssm set $ServiceName AppRestartDelay 5000
& nssm set $ServiceName Description "tbxark/mcp-proxy exposing roo-state-manager via Streamable HTTP on $BindAddress`:$Port"
Write-Ok "Service configured"

Write-Step "Starting service"
& nssm start $ServiceName
Start-Sleep -Seconds 2
$status = & nssm status $ServiceName
if ($status -notmatch "SERVICE_RUNNING") { throw "Service failed to start: $status" }
Write-Ok "Service running"

Write-Step "Verifying HTTP endpoint"
try {
    $headers = @{ "Authorization" = "Bearer $Token"; "Accept" = "application/json, text/event-stream" }
    $body = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"install-check","version":"1.0"}}}'
    $resp = Invoke-WebRequest -Uri "http://${BindAddress}:${Port}/roo-state-manager/mcp" -Method POST -Headers $headers -ContentType "application/json" -Body $body -UseBasicParsing -TimeoutSec 10
    if ($resp.StatusCode -eq 200) { Write-Ok "Endpoint responded 200 OK" }
    else { Write-Warn "Unexpected status: $($resp.StatusCode)" }
} catch {
    Write-Warn "Verification failed: $($_.Exception.Message) - check $InstallPath\service.err.log"
}

Write-Host ""
Write-Host "=========================================================" -ForegroundColor Green
Write-Host "  Installation complete" -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green
Write-Host "  Service name : $ServiceName"
Write-Host "  Endpoint     : http://${BindAddress}:${Port}/roo-state-manager/mcp"
Write-Host "  Bearer token : $Token"
Write-Host "  Config       : $configPath"
Write-Host "  Logs         : $InstallPath\service.log"
Write-Host ""
Write-Host "  Save the token securely - it is required in Authorization header:" -ForegroundColor Yellow
Write-Host "    Authorization: Bearer $Token" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Next step: register in Docker mcp-proxy config" -ForegroundColor Cyan
Write-Host "  See: docs/harness/reference/mcp-proxy-host.md" -ForegroundColor Cyan
