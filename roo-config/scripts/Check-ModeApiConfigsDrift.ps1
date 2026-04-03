#Requires -Version 5.1

<#
.SYNOPSIS
    Check modeApiConfigs drift between model-configs.json and VS Code state

.DESCRIPTION
    Compares the modeApiConfigs mapping in model-configs.json (source of truth)
    with the modeApiConfigs stored in VS Code's state.vscdb. Reports any drift
    where VS Code has a different profile assigned to a mode than what's defined
    in model-configs.json.

    This drift typically occurs when a user customizes a profile via the Roo UI,
    which updates modeApiConfigs in state.vscdb without updating model-configs.json.

.PARAMETER ModelConfigsPath
    Path to model-configs.json (default: roo-config/model-configs.json)

.PARAMETER MachineName
    Machine name for reporting (default: env:COMPUTERNAME)

.EXAMPLE
    .\Check-ModeApiConfigsDrift.ps1
    Check modeApiConfigs drift on local machine

.EXAMPLE
    .\Check-ModeApiConfigsDrift.ps1 -ModelConfigsPath "C:\dev\roo-extensions\roo-config\model-configs.json"
    Check with custom model-configs.json path

.OUTPUTS
    PSObject with drift status and details
#>

param(
    [string]$ModelConfigsPath = "",
    [string]$MachineName = ""
)

$ErrorActionPreference = "Stop"

# Resolve paths
$repoRoot = (Get-Item "$PSScriptRoot\..\.." -ErrorAction SilentlyContinue).FullName
if (-not $ModelConfigsPath) {
    $ModelConfigsPath = Join-Path $repoRoot "roo-config\model-configs.json"
}

if (-not $MachineName) {
    $MachineName = $env:COMPUTERNAME
}

if (-not (Test-Path $ModelConfigsPath)) {
    Write-Host "ERROR: model-configs.json not found at: $ModelConfigsPath" -ForegroundColor Red
    exit 1
}

# Read model-configs.json
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$modelConfigsContent = [System.IO.File]::ReadAllText($ModelConfigsPath, $utf8NoBom)
$modelConfigs = $modelConfigsContent | ConvertFrom-Json

# Get source of truth modeApiConfigs from model-configs.json
$sourceModeApiConfigs = $modelConfigs.modeApiConfigs

if (-not $sourceModeApiConfigs) {
    Write-Host "ERROR: No modeApiConfigs found in model-configs.json" -ForegroundColor Red
    exit 1
}

# Read VS Code state.vscdb
$stateDbPath = Join-Path $env:APPDATA "Code\User\globalStorage\state.vscdb"

if (-not (Test-Path $stateDbPath)) {
    Write-Host "WARNING: state.vscdb not found at: $stateDbPath" -ForegroundColor Yellow
    Write-Host "This is expected if Roo extension is not installed on this machine." -ForegroundColor Gray

    # Return result indicating no drift check possible
    @{
        Machine = $MachineName
        Status = "SKIPPED"
        Reason = "Roo extension not installed (state.vscdb not found)"
        SourceOfTruth = $sourceModeApiConfigs
        VsCodeState = $null
        Drift = $null
    } | ConvertTo-Json -Depth 10
    exit 0
}

# Read modeApiConfigs from VS Code state
# Using sqlite3 via SQLite assembly (Add-Type)
$tempDbPath = Join-Path $env:TEMP "state-vscdb-$([Guid]::NewGuid()).db"
try {
    Copy-Item $stateDbPath $tempDbPath -Force

    # Load SQLite assembly
    $assemblyPath = Join-Path $PSScriptRoot "..\..\mcps\internal\node_modules\sqlite3\lib\binding\napi-v6-win32-unknown-x64\node_sqlite3.node"
    if (-not (Test-Path $assemblyPath)) {
        # Fallback: try to use System.Data.SQLite if available
        Add-Type -Path "C:\Windows\Microsoft.NET\assembly\GAC_MSIL\System.Data.SQLite\v4.0_*.dll" -ErrorAction SilentlyContinue
        if ($?) {
            Write-Host "Using System.Data.SQLite" -ForegroundColor Gray
            $connection = New-Object System.Data.SQLite.SQLiteConnection ("Data Source=$tempDbPath")
            $connection.Open()
            $command = $connection.CreateCommand()
            $command.CommandText = "SELECT value FROM ItemTable WHERE key = 'RooVeterinaryInc.roo-cline'"
            $reader = $command.ExecuteReader()
            if ($reader.Read()) {
                $value = $reader.GetString(0)
                $vsCodeSettings = $value | ConvertFrom-Json
            } else {
                throw "Key 'RooVeterinaryInc.roo-cline' not found in state.vscdb"
            }
            $connection.Close()
        } else {
            throw "SQLite library not available"
        }
    } else {
        # Use better-sqlite3 if available via node
        $nodeScript = @"
const sqlite = require('better-sqlite3');
const db = new SQLite('$tempDbPath', { readonly: true });
const row = db.prepare('SELECT value FROM ItemTable WHERE key = ?').get('RooVeterinaryInc.roo-cline');
console.log(JSON.stringify(row ? row.value : null));
db.close();
"@
        $result = node -e $nodeScript 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to read state.vscdb: $result"
        }
        $vsCodeSettings = $result | ConvertFrom-Json
    }
} finally {
    if (Test-Path $tempDbPath) {
        Remove-Item $tempDbPath -Force -ErrorAction SilentlyContinue
    }
}

# Get VS Code modeApiConfigs
$vsCodeModeApiConfigs = $vsCodeSettings.modeApiConfigs

if (-not $vsCodeModeApiConfigs) {
    Write-Host "WARNING: No modeApiConfigs found in VS Code state" -ForegroundColor Yellow
    Write-Host "This might indicate a fresh Roo installation." -ForegroundColor Gray

    @{
        Machine = $MachineName
        Status = "NO_VSCONFIGS"
        Reason = "modeApiConfigs not found in VS Code state (fresh installation?)"
        SourceOfTruth = $sourceModeApiConfigs
        VsCodeState = $null
        Drift = $null
    } | ConvertTo-Json -Depth 10
    exit 0
}

# Compare modeApiConfigs
$drift = @{}
$allModes = (@($sourceModeApiConfigs.PSObject.Properties.Name) + @($vsCodeModeApiConfigs.PSObject.Properties.Name) | Select-Object -Unique) | Sort-Object

foreach ($mode in $allModes) {
    $sourceProfile = if ($sourceModeApiConfigs.$mode) { $sourceModeApiConfigs.$mode } else { "NOT_DEFINED" }
    $vsCodeProfile = if ($vsCodeModeApiConfigs.$mode) { $vsCodeModeApiConfigs.$mode } else { "NOT_DEFINED" }

    if ($sourceProfile -ne $vsCodeProfile) {
        $drift[$mode] = @{
            SourceOfTruth = $sourceProfile
            VsCode = $vsCodeProfile
            DriftType = if ($sourceProfile -eq "NOT_DEFINED") { "EXTRA_IN_VSCODE" }
                       elseif ($vsCodeProfile -eq "NOT_DEFINED") { "MISSING_IN_VSCODE" }
                       else { "MISMATCH" }
        }
    }
}

# Build result
$result = @{
    Machine = $MachineName
    Status = if ($drift.Count -gt 0) { "DRIFT_DETECTED" } else { "OK" }
    SourceOfTruth = $sourceModeApiConfigs
    VsCodeState = $vsCodeModeApiConfigs
    Drift = if ($drift.Count -gt 0) { $drift } else { $null }
    DriftCount = $drift.Count
    Timestamp = (Get-Date).ToUniversalTime().ToString("o")
}

# Output result
Write-Host "`nmodeApiConfigs Drift Check for $MachineName" -ForegroundColor Cyan
Write-Host "Source of truth: $ModelConfigsPath" -ForegroundColor Gray
Write-Host "VS Code state: $stateDbPath" -ForegroundColor Gray

if ($result.Status -eq "OK") {
    Write-Host "`nStatus: OK - No drift detected" -ForegroundColor Green
    Write-Host "All modes match the source of truth." -ForegroundColor Green
} else {
    Write-Host "`nStatus: DRIFT_DETECTED - $($result.DriftCount) mode(s) affected" -ForegroundColor Red
    Write-Host "`nDrift details:" -ForegroundColor Yellow

    foreach ($mode in $drift.Keys | Sort-Object) {
        $driftInfo = $drift[$mode]
        Write-Host "  [$mode]" -ForegroundColor White
        Write-Host "    Source of truth: $($driftInfo.SourceOfTruth)" -ForegroundColor Green
        Write-Host "    VS Code state:    $($driftInfo.VsCode)" -ForegroundColor Red
        Write-Host "    Drift type:       $($driftInfo.DriftType)" -ForegroundColor Gray
    }

    Write-Host "`nRecommended action:" -ForegroundColor Yellow
    Write-Host "  1. Review the drift above" -ForegroundColor White
    Write-Host "  2. If drift is unintended, reset modeApiConfigs in VS Code" -ForegroundColor White
    Write-Host "  3. Or update model-configs.json if the drift is intentional" -ForegroundColor White
}

# Output as JSON for programmatic consumption
Write-Host "`n" -NoNewline
$result | ConvertTo-Json -Depth 10

# Exit code based on drift status
exit if ($result.Status -eq "OK") { 0 } else { 1 }
