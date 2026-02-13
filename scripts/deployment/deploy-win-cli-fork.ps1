# Deploy Win-CLI Fork - Switch from npm package to local fork with unbridled operators
# Issue: #468 - Migration win-cli vers DesktopCommanderMCP (Phase 1)
#
# Problem: The npm package @simonb97/server-win-cli blocks shell operators (;, |, &, `)
#          by default, which prevents the Roo scheduler from running composed commands.
# Solution: Use the local fork at mcps/external/win-cli/server/ with blockedOperators: []
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/deployment/deploy-win-cli-fork.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/deployment/deploy-win-cli-fork.ps1 -DryRun
#   powershell -ExecutionPolicy Bypass -File scripts/deployment/deploy-win-cli-fork.ps1 -RooRoot "D:/projects/roo-extensions"

param(
    [Parameter(Mandatory=$false)]
    [string]$RooMcpSettingsPath = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json",

    [Parameter(Mandatory=$false)]
    [string]$RooRoot = "C:/dev/roo-extensions",

    [Parameter(Mandatory=$false)]
    [switch]$Backup = $true,

    [Parameter(Mandatory=$false)]
    [switch]$DryRun = $false
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   Deploy Win-CLI Fork (Issue #468 Phase 1)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# Normalize RooRoot path (forward slashes for JSON)
$RooRoot = $RooRoot -replace '\\', '/'
$RooRoot = $RooRoot.TrimEnd('/')

Write-Host "MCP Settings: $RooMcpSettingsPath" -ForegroundColor Yellow
Write-Host "Roo Root:     $RooRoot" -ForegroundColor Yellow
Write-Host "Dry Run:      $DryRun" -ForegroundColor Yellow
Write-Host ""

# Step 1: Verify fork exists
Write-Host "[1/5] Verifying fork installation..." -ForegroundColor Cyan

$forkDistPath = "$RooRoot/mcps/external/win-cli/server/dist/index.js" -replace '/', '\'
$forkConfigPath = "$RooRoot/mcps/external/win-cli/config/win_cli_config.json" -replace '/', '\'
$forkNodeModules = "$RooRoot/mcps/external/win-cli/server/node_modules" -replace '/', '\'

$errors = @()

if (-not (Test-Path $forkDistPath)) {
    $errors += "Fork dist/index.js not found: $forkDistPath"
}
if (-not (Test-Path $forkConfigPath)) {
    $errors += "Fork config not found: $forkConfigPath"
}
if (-not (Test-Path $forkNodeModules)) {
    $errors += "Fork node_modules not found: $forkNodeModules (run 'npm install' in mcps/external/win-cli/server/)"
}

if ($errors.Count -gt 0) {
    Write-Host "ERRORS:" -ForegroundColor Red
    foreach ($err in $errors) {
        Write-Host "  - $err" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Fix: Ensure the submodule mcps/external/win-cli/server/ is initialized:" -ForegroundColor Yellow
    Write-Host "  git submodule update --init mcps/external/win-cli/server" -ForegroundColor Yellow
    Write-Host "  cd mcps/external/win-cli/server && npm install" -ForegroundColor Yellow
    exit 1
}

Write-Host "  dist/index.js  : OK" -ForegroundColor Green
Write-Host "  config.json    : OK" -ForegroundColor Green
Write-Host "  node_modules   : OK" -ForegroundColor Green

# Step 2: Verify config has unbridled operators
Write-Host ""
Write-Host "[2/5] Verifying fork config (blockedOperators)..." -ForegroundColor Cyan

try {
    $configContent = Get-Content $forkConfigPath -Raw -Encoding UTF8
    $config = ConvertFrom-Json $configContent

    $shells = @("powershell", "cmd", "gitbash")
    foreach ($shell in $shells) {
        $shellConfig = $config.shells.$shell
        if ($null -eq $shellConfig) {
            Write-Host "  WARNING: Shell '$shell' not found in config" -ForegroundColor Yellow
            continue
        }
        $blocked = $shellConfig.blockedOperators
        if ($null -eq $blocked -or $blocked.Count -eq 0) {
            Write-Host "  $shell : blockedOperators = [] (unbridled)" -ForegroundColor Green
        } else {
            Write-Host "  WARNING: $shell has blockedOperators: $($blocked -join ', ')" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "  WARNING: Could not parse config: $_" -ForegroundColor Yellow
}

# Step 3: Read MCP settings
Write-Host ""
Write-Host "[3/5] Reading MCP settings..." -ForegroundColor Cyan

if (-not (Test-Path $RooMcpSettingsPath)) {
    Write-Host "ERROR: MCP settings file not found: $RooMcpSettingsPath" -ForegroundColor Red
    exit 1
}

try {
    $jsonContent = Get-Content $RooMcpSettingsPath -Raw -Encoding UTF8
    $mcpSettings = ConvertFrom-Json $jsonContent
} catch {
    Write-Host "ERROR: Could not parse MCP settings: $_" -ForegroundColor Red
    exit 1
}

# Check current win-cli config
$currentWinCli = $mcpSettings.mcpServers.'win-cli'
if ($null -eq $currentWinCli) {
    Write-Host "  win-cli MCP not found in settings - will create" -ForegroundColor Yellow
} else {
    $currentCommand = $currentWinCli.command
    $currentArgs = if ($currentWinCli.args) { $currentWinCli.args -join " " } else { "(none)" }
    Write-Host "  Current command: $currentCommand" -ForegroundColor Gray
    Write-Host "  Current args:    $currentArgs" -ForegroundColor Gray

    # Check if already using fork
    if ($currentCommand -eq "node" -and $currentArgs -like "*win-cli/server/dist/index.js*") {
        Write-Host ""
        Write-Host "  Already using fork! No changes needed." -ForegroundColor Green
        Write-Host "==========================================================" -ForegroundColor Cyan
        exit 0
    }
}

# Step 4: Backup
if ($Backup -and -not $DryRun) {
    Write-Host ""
    Write-Host "[4/5] Creating backup..." -ForegroundColor Cyan
    $backupPath = "$RooMcpSettingsPath.backup-wincli-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $RooMcpSettingsPath $backupPath -Force
    Write-Host "  Backup: $backupPath" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "[4/5] Backup skipped (DryRun=$DryRun)" -ForegroundColor Gray
}

# Step 5: Update win-cli config
Write-Host ""
Write-Host "[5/5] Updating win-cli MCP config..." -ForegroundColor Cyan

$forkDistJsonPath = "$RooRoot/mcps/external/win-cli/server/dist/index.js"
$forkConfigJsonPath = "$RooRoot/mcps/external/win-cli/config/win_cli_config.json"
$forkCwdJsonPath = "$RooRoot/mcps/external/win-cli/server/"

# Build new config using raw JSON manipulation to avoid PowerShell's case-insensitive issues
$newWinCliJson = @"
{
  "command": "node",
  "args": [
    "$forkDistJsonPath",
    "--config",
    "$forkConfigJsonPath"
  ],
  "options": {
    "cwd": "$forkCwdJsonPath"
  },
  "alwaysAllow": [
    "execute_command",
    "get_command_history",
    "get_current_directory"
  ]
}
"@

Write-Host "  New config:" -ForegroundColor Green
Write-Host "    command: node" -ForegroundColor White
Write-Host "    args[0]: $forkDistJsonPath" -ForegroundColor White
Write-Host "    args[1]: --config" -ForegroundColor White
Write-Host "    args[2]: $forkConfigJsonPath" -ForegroundColor White
Write-Host "    cwd:     $forkCwdJsonPath" -ForegroundColor White
Write-Host "    alwaysAllow: execute_command, get_command_history, get_current_directory" -ForegroundColor White

if ($DryRun) {
    Write-Host ""
    Write-Host "  DRY RUN - No changes written." -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Cyan
    exit 0
}

# Use Node.js for reliable JSON manipulation (avoids PowerShell case-sensitivity issues)
$nodeScript = @"
const fs = require('fs');
const settingsPath = process.argv[2];
const newConfigJson = process.argv[3];

let content = fs.readFileSync(settingsPath, 'utf-8');
if (content.charCodeAt(0) === 0xFEFF) content = content.substring(1);

const settings = JSON.parse(content);
const newConfig = JSON.parse(newConfigJson);

if (!settings.mcpServers) settings.mcpServers = {};
settings.mcpServers['win-cli'] = newConfig;

fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2), 'utf-8');
console.log('OK');
"@

$tempScript = [System.IO.Path]::GetTempFileName() + ".js"
[System.IO.File]::WriteAllText($tempScript, $nodeScript, [System.Text.UTF8Encoding]::new($false))

try {
    $result = & node $tempScript $RooMcpSettingsPath ($newWinCliJson.Trim()) 2>&1
    if ($result -eq "OK") {
        Write-Host ""
        Write-Host "  Config updated successfully!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "  ERROR: $result" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "  ERROR: $_" -ForegroundColor Red
    exit 1
} finally {
    Remove-Item $tempScript -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Win-CLI fork deployed successfully!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "IMPORTANT: Restart Visual Studio Code to apply changes." -ForegroundColor Yellow
Write-Host ""
Write-Host "To verify after restart:" -ForegroundColor Gray
Write-Host "  - Roo scheduler should run gh commands without operator errors" -ForegroundColor Gray
Write-Host "  - Check: gh issue list --repo jsboige/roo-extensions --state open" -ForegroundColor Gray
Write-Host ""
