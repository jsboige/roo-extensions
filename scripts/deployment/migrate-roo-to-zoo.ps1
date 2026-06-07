<#
.SYNOPSIS
    Migrate settings from Roo Code to Zoo Code (state.vscdb + mcp_settings.json + secrets).

.DESCRIPTION
    Roo Code is shutdown (2026-05-15). Zoo Code (fork) has the ripgrep fix (#2455 PR #248)
    but is NOT configured. This script migrates all settings from Roo → Zoo:

    1. State migration: Copy provider/model/condensation/auto-approval settings from
       Roo state blob to Zoo state blob in VS Code's state.vscdb SQLite database.
    2. Secret migration: Duplicate API key secrets from Roo extensionId to Zoo extensionId.
    3. MCP settings: Copy mcp_settings.json from Roo globalStorage to Zoo globalStorage,
       or regenerate via install-mcps.ps1 if Roo settings missing.
    4. Modes: Verify .roomodes exists (already shared between Roo and Zoo).

    Both Roo and Zoo store their state in the same state.vscdb file under different keys:
    - Roo: "RooVeterinaryInc.roo-cline"
    - Zoo: "ZooCodeOrganization.zoo-code"

    The state format is identical (Zoo is a fork of Roo).

.PARAMETER DryRun
    Report what would be done without making changes. Default: true.

.PARAMETER VscdbPath
    Path to state.vscdb. Auto-detected from %APPDATA%/Code/User/globalStorage/state.vscdb.

.PARAMETER SkipSecrets
    Skip secret migration (API keys). Use if secrets are already configured.

.PARAMETER SkipMcpSettings
    Skip mcp_settings.json migration. Use if MCPs are already configured.

.EXAMPLE
    ./migrate-roo-to-zoo.ps1
    # Dry run — report what would be migrated

.EXAMPLE
    ./migrate-roo-to-zoo.ps1 -DryRun:$false
    # Apply migration

.NOTES
    Issue #2455 — codebase_search vide fleet-wide
    Requires: sqlite3 in PATH (for state.vscdb access)
#>

[CmdletBinding()]
param(
    [switch]$DryRun = $true,
    [string]$VscdbPath,
    [switch]$SkipSecrets,
    [switch]$SkipMcpSettings
)

$ErrorActionPreference = 'Stop'

# === Constants ===
$RooKey = "RooVeterinaryInc.roo-cline"
$ZooKey = "ZooCodeOrganization.zoo-code"
$RooExtensionId = "rooveterinaryinc.roo-cline"
$ZooExtensionId = "ZooCodeOrganization.zoo-code"

# Keys to EXCLUDE from state migration (machine-specific, UI state, auth, large data)
$ExcludedKeys = @(
    'id',                        # Machine-specific UUID
    'taskHistory',               # Large, machine-specific
    'taskHistoryMigratedToFiles', # Internal migration flag
    'mcpHubInstanceId',          # Transient
    'clerk-auth-state',          # Auth token
    'lastShownAnnouncementId',   # UI state
    'hasOpenedModeSelector',     # UI state
    'dismissedUpsells',          # UI state
    'organization-settings',     # Account-specific
    'user-settings'              # Account-specific
)

# Keys to PRESERVE in Zoo state (do not overwrite with Roo values)
$PreserveZooKeys = @(
    'mcpHubInstanceId',          # Zoo has its own instance ID
    'defaultCommandsMigrationCompleted', # Already done in Zoo
    'taskHistoryMigratedToFiles' # Already done in Zoo
)

# Secret key names to migrate
$SecretKeys = @(
    'openAiApiKey',
    'openRouterApiKey',
    'openRouterImageApiKey',
    'geminiApiKey',
    'roo_cline_config_api_config',
    'codeIndexOpenAiKey',
    'codeIndexQdrantApiKey',
    'codebaseIndexGeminiApiKey',
    'codebaseIndexMistralApiKey',
    'codebaseIndexOpenAiCompatibleApiKey',
    'codebaseIndexOpenRouterApiKey',
    'codebaseIndexVercelAiGatewayApiKey'
)

# === Helper Functions ===

function Write-Status {
    param([string]$Msg, [string]$Color = 'White')
    Write-Host $Msg -ForegroundColor $Color
}

function Invoke-SqliteQuery {
    param([string]$Database, [string]$Query, [switch]$Scalar)
    $result = & sqlite3 $Database $Query 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "SQLite error: $result"
    }
    return $result
}

# === Resolve paths ===
if (-not $VscdbPath) {
    $VscdbPath = Join-Path $env:APPDATA "Code\User\globalStorage\state.vscdb"
}

if (-not (Test-Path $VscdbPath)) {
    Write-Status "ERROR: state.vscdb not found at: $VscdbPath" 'Red'
    exit 1
}

Write-Status "=== Roo → Zoo Code Migration ===" 'Cyan'
Write-Status "Mode: $(if ($DryRun) { 'DRY-RUN' } else { 'EXECUTE' })" 'Yellow'
Write-Status "Database: $VscdbPath"
Write-Status ""

# === Step 0: Check prerequisites ===
$null = Get-Command sqlite3 -ErrorAction Stop
Write-Status "[OK] sqlite3 found" 'Green'

# === Step 1: State migration ===
Write-Status "`n--- Step 1: State Migration ---" 'Cyan'

# Read Roo state
$rooJson = Invoke-SqliteQuery $VscdbPath "SELECT value FROM ItemTable WHERE key='$RooKey';"
if (-not $rooJson) {
    Write-Status "ERROR: No Roo Code state found in state.vscdb (key: $RooKey)" 'Red'
    Write-Status "Roo Code may not have been configured on this machine." 'Yellow'
    exit 1
}

$rooState = $rooJson | ConvertFrom-Json
$rooKeyCount = $rooState.PSObject.Properties.Name.Count
Write-Status "Roo state: $rooKeyCount keys" 'Green'

# Read Zoo state
$zooJson = Invoke-SqliteQuery $VscdbPath "SELECT value FROM ItemTable WHERE key='$ZooKey';"
if ($zooJson) {
    $zooState = $zooJson | ConvertFrom-Json
    $zooKeyCount = $zooState.PSObject.Properties.Name.Count
    Write-Status "Zoo state: $zooKeyCount keys" 'Green'
} else {
    Write-Status "Zoo state: NOT FOUND (will create)" 'Yellow'
    $zooState = [PSCustomObject]@{}
}

# Build merged state
$migratedKeys = @()
$skippedKeys = @()
$preservedKeys = @()

foreach ($prop in $rooState.PSObject.Properties) {
    $key = $prop.Name

    # Skip excluded keys
    if ($ExcludedKeys -contains $key) {
        $skippedKeys += $key
        continue
    }

    # Skip keys that Zoo already has and we want to preserve
    if ($PreserveZooKeys -contains $key -and $zooState.PSObject.Properties.Name -contains $key) {
        $preservedKeys += $key
        continue
    }

    $migratedKeys += $key
}

Write-Status "`nMigration plan:" 'White'
Write-Status "  Keys to migrate: $($migratedKeys.Count)" 'Green'
Write-Status "  Keys to skip (excluded): $($skippedKeys.Count)" 'DarkGray'
Write-Status "  Keys to preserve (Zoo): $($preservedKeys.Count)" 'DarkGray'

# Show critical keys being migrated
$criticalKeys = @('apiProvider', 'currentApiConfigName', 'openAiModelId', 'openAiBaseUrl',
    'autoCondenseContext', 'autoCondenseContextPercent', 'mode',
    'alwaysAllowReadOnly', 'alwaysAllowWrite', 'alwaysAllowMcp', 'codebaseIndexConfig')
foreach ($ck in $criticalKeys) {
    if ($migratedKeys -contains $ck) {
        $val = $rooState.$ck
        if ($val -is [string] -and $val.Length -gt 50) { $val = $val.Substring(0, 50) + '...' }
        Write-Status "  $ck = $val" 'White'
    }
}

if (-not $DryRun) {
    # Apply migration
    # Build new Zoo state by merging
    $newZooState = @{}
    foreach ($prop in $zooState.PSObject.Properties) {
        $newZooState[$prop.Name] = $prop.Value
    }
    foreach ($key in $migratedKeys) {
        $newZooState[$key] = $rooState.$key
    }

    # Convert back to JSON
    $newZooJson = $newZooState | ConvertTo-Json -Depth 10 -Compress

    # Backup
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupPath = "$VscdbPath.backup_$timestamp"
    Copy-Item $VscdbPath $backupPath -Force
    Write-Status "`n  Backup: $backupPath" 'Green'

    # Write to temp file to avoid quoting issues
    $tempJsonPath = Join-Path $env:TEMP "zoo-state-migration.json"
    [System.IO.File]::WriteAllText($tempJsonPath, $newZooJson, [System.Text.UTF8Encoding]::new($false))

    # Update via sqlite3
    $null = Invoke-SqliteQuery $VscdbPath "UPDATE ItemTable SET value = readfile('$tempJsonPath') WHERE key='$ZooKey';"
    # If Zoo key doesn't exist yet, INSERT instead
    $check = Invoke-SqliteQuery $VscdbPath "SELECT count(*) FROM ItemTable WHERE key='$ZooKey';"
    if ($check.Trim() -eq '0') {
        $null = Invoke-SqliteQuery $VscdbPath "INSERT INTO ItemTable (key, value) VALUES ('$ZooKey', readfile('$tempJsonPath'));"
    }

    Remove-Item $tempJsonPath -Force -ErrorAction SilentlyContinue

    Write-Status "  State migrated: $($migratedKeys.Count) keys written to Zoo state" 'Green'
} else {
    Write-Status "`n  [DRY-RUN] Would migrate $($migratedKeys.Count) keys" 'Yellow'
}

# === Step 2: Secret migration ===
Write-Status "`n--- Step 2: Secret Migration ---" 'Cyan'

if ($SkipSecrets) {
    Write-Status "  Skipped (-SkipSecrets)" 'Yellow'
} else {
    $migratedSecrets = 0
    $missingSecrets = 0

    foreach ($secretName in $SecretKeys) {
        $rooSecretKey = "secret://{""extensionId"":""$RooExtensionId"",""key"":""$secretName""}"
        $zooSecretKey = "secret://{""extensionId"":""$ZooExtensionId"",""key"":""$secretName""}"

        # Check if Roo secret exists
        $rooValue = Invoke-SqliteQuery $VscdbPath "SELECT value FROM ItemTable WHERE key='$rooSecretKey';" -ErrorAction SilentlyContinue
        if ($rooValue -and $rooValue.Trim()) {
            # Check if Zoo secret already exists
            $zooExists = Invoke-SqliteQuery $VscdbPath "SELECT count(*) FROM ItemTable WHERE key='$zooSecretKey';"
            if ($zooExists.Trim() -eq '0') {
                Write-Status "  $secretName : FOUND in Roo → $(if ($DryRun) { 'WOULD COPY' } else { 'COPYING' })" 'White'
                if (-not $DryRun) {
                    # Write secret to temp file then insert
                    $tempSecretPath = Join-Path $env:TEMP "zoo-secret-$secretName.txt"
                    [System.IO.File]::WriteAllText($tempSecretPath, $rooValue, [System.Text.UTF8Encoding]::new($false))
                    $null = Invoke-SqliteQuery $VscdbPath "INSERT INTO ItemTable (key, value) VALUES ('$zooSecretKey', readfile('$tempSecretPath'));"
                    Remove-Item $tempSecretPath -Force -ErrorAction SilentlyContinue
                }
                $migratedSecrets++
            } else {
                Write-Status "  $secretName : already exists in Zoo (skip)" 'DarkGray'
            }
        } else {
            $missingSecrets++
            Write-Status "  $secretName : NOT FOUND in Roo" 'DarkGray'
        }
    }

    Write-Status "`n  Secrets migrated: $migratedSecrets | Missing: $missingSecrets" 'White'
}

# === Step 3: MCP settings migration ===
Write-Status "`n--- Step 3: MCP Settings Migration ---" 'Cyan'

if ($SkipMcpSettings) {
    Write-Status "  Skipped (-SkipMcpSettings)" 'Yellow'
} else {
    # Dot-source extension-paths.ps1 for Get-McpSettingsPath
    $extPathsScript = Join-Path $PSScriptRoot "..\common\extension-paths.ps1"
    if (Test-Path $extPathsScript) {
        . $extPathsScript
    } else {
        Write-Status "WARN: extension-paths.ps1 not found, using hardcoded paths" 'Yellow'
        function Get-GlobalStoragePath {
            param([string]$Extension = "ZooCode")
            $id = if ($Extension -eq "ZooCode") { "ZooCodeOrganization.zoo-code" } else { "rooveterinaryinc.roo-cline" }
            Join-Path $env:APPDATA "Code\User\globalStorage\$id"
        }
    }

    $rooMcpPath = Join-Path (Get-GlobalStoragePath -Extension RooCode) "settings\mcp_settings.json"
    $zooMcpPath = Join-Path (Get-GlobalStoragePath -Extension ZooCode) "settings\mcp_settings.json"
    $zooSettingsDir = Split-Path $zooMcpPath

    $rooMcpExists = Test-Path $rooMcpPath
    $zooMcpExists = Test-Path $zooMcpPath

    Write-Status "  Roo MCP settings: $(if ($rooMcpExists) { 'FOUND' } else { 'NOT FOUND' })" 'White'
    Write-Status "  Zoo MCP settings: $(if ($zooMcpExists) { 'FOUND' } else { 'EMPTY' })" 'White'

    if ($rooMcpExists -and -not $zooMcpExists) {
        if (-not $DryRun) {
            if (-not (Test-Path $zooSettingsDir)) {
                New-Item -ItemType Directory -Path $zooSettingsDir -Force | Out-Null
            }
            Copy-Item $rooMcpPath $zooMcpPath -Force
            Write-Status "  COPIED: Roo mcp_settings.json → Zoo" 'Green'
        } else {
            Write-Status "  [DRY-RUN] Would copy Roo mcp_settings.json → Zoo" 'Yellow'
        }
    } elseif ($rooMcpExists -and $zooMcpExists) {
        # Check if Zoo is empty
        $zooContent = Get-Content $zooMcpPath -Raw | ConvertFrom-Json
        $serverCount = ($zooContent.mcpServers.PSObject.Properties | Measure-Object).Count
        if ($serverCount -eq 0) {
            if (-not $DryRun) {
                Copy-Item $rooMcpPath $zooMcpPath -Force
                Write-Status "  COPIED: Roo mcp_settings.json → Zoo (was empty)" 'Green'
            } else {
                Write-Status "  [DRY-RUN] Would copy Roo mcp_settings.json → Zoo (currently empty)" 'Yellow'
            }
        } else {
            Write-Status "  Zoo MCP settings already configured ($serverCount servers) — skip" 'DarkGray'
        }
    } elseif (-not $rooMcpExists) {
        Write-Status "  Roo MCP settings not found — run install-mcps.ps1 -Extension ZooCode instead" 'Yellow'
        Write-Status "  Command: pwsh -File scripts/deployment/install-mcps.ps1" 'White'
    }
}

# === Step 4: Modes verification ===
Write-Status "`n--- Step 4: Modes Verification ---" 'Cyan'
$repoRoot = (git rev-parse --show-toplevel 2>$null).Trim()
if ($repoRoot) {
    $roomodesPath = Join-Path $repoRoot '.roomodes'
    if (Test-Path $roomodesPath) {
        $modesSize = (Get-Item $roomodesPath).Length
        Write-Status "  .roomodes: $([math]::Round($modesSize/1KB)) KB (OK)" 'Green'
    } else {
        Write-Status "  .roomodes: NOT FOUND — run generate-modes.js --deploy" 'Yellow'
    }
} else {
    Write-Status "  Not in a git repo — skipping modes check" 'DarkGray'
}

# === Summary ===
Write-Status "`n=== Summary ===" 'Cyan'
if ($DryRun) {
    Write-Status "DRY-RUN — no changes made. Re-run with -DryRun:`$false to apply." 'Yellow'
} else {
    Write-Status "Migration applied. Restart VS Code to pick up changes." 'Green'
}
Write-Status "=== Done ==="
