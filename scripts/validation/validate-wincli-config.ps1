# =================================================================================================
#
#   Validation win-cli MCP Configuration
#
#   Issue: #1666 Phase A3 (part of #1482 root cause)
#   Purpose: Detect when Roo mcp_settings.json has drifted away from the local fork
#            (mcps/external/win-cli/server/dist/index.js) toward the broken npm version.
#
#   Background: The upstream npm package @simonb97/server-win-cli@0.2.1 is broken
#   (hangs on common operators). The repo ships a local fork at v0.2.0 with patches
#   (windowsHide, timeout increase, blocked-operator fix). Agents have repeatedly
#   reverted mcp_settings.json to the broken npm version after config refactors,
#   causing cluster-wide command failures (#1482, #1583, #1188).
#
#   This script is read-only. Exit codes: 0=OK, 1=CRITICAL drift, 2=file not found
#
# =================================================================================================

[CmdletBinding()]
param(
    [switch]$Quiet,
    [string]$ConfigPath = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"
)

function Write-Result {
    param([string]$Message, [string]$Level = "INFO")
    if ($Quiet -and $Level -eq "INFO") { return }
    $color = switch ($Level) {
        "PASS"     { "Green" }
        "FAIL"     { "Red" }
        "WARN"     { "Yellow" }
        default    { "White" }
    }
    Write-Host "[$Level] $Message" -ForegroundColor $color
}

# ----- Load config -----

if (-not (Test-Path $ConfigPath)) {
    Write-Result "Roo MCP config not found: $ConfigPath" "FAIL"
    Write-Result "Expected location on Windows: %APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json" "INFO"
    exit 2
}

try {
    $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
}
catch {
    Write-Result "Failed to parse mcp_settings.json as JSON: $($_.Exception.Message)" "FAIL"
    exit 2
}

# ----- Locate win-cli entry -----

$winCli = $config.mcpServers.'win-cli'
if (-not $winCli) {
    Write-Result "No 'win-cli' entry in mcpServers — Roo will have no terminal access" "FAIL"
    Write-Result "Expected: 'win-cli' pointing to the local fork at mcps/external/win-cli/server/dist/index.js" "INFO"
    exit 1
}

# ----- Canonical config expected -----
# command: node
# args[0]: a path ending with mcps/external/win-cli/server/dist/index.js
# disabled: false
# transportType: stdio

$violations = @()

if ($winCli.command -ne "node") {
    $violations += "command should be 'node' but is '$($winCli.command)'. Suggests drift toward 'npx' (broken upstream)."
}

$firstArg = if ($winCli.args -and $winCli.args.Count -gt 0) { $winCli.args[0] } else { $null }
if (-not $firstArg) {
    $violations += "args[0] is empty — cannot validate target binary"
} elseif ($firstArg -notmatch "mcps[/\\]external[/\\]win-cli[/\\]server[/\\]dist[/\\]index\.js$") {
    $violations += "args[0] does not point to local fork. Got: '$firstArg'. Expected: '...\mcps\external\win-cli\server\dist\index.js'"
}

# Scan ALL args (not just [0]) for known-broken npm package patterns.
# Agents sometimes rewrite to `npx -y @simonb97/server-win-cli@0.2.1` where the
# package name is in args[1] or later.
if ($winCli.args) {
    foreach ($a in $winCli.args) {
        if ($a -match "@simonb97/server-win-cli|@anthropic/win-cli") {
            $violations += "DETECTED npm-package reference in args: '$a'. This is the known-broken upstream (#1482). Replace with local fork path."
            break
        }
    }
}

if ($winCli.disabled -eq $true) {
    $violations += "win-cli is disabled. Roo scheduler modes -simple depend on it for terminal access."
}

if ($winCli.transportType -and $winCli.transportType -ne "stdio") {
    $violations += "transportType '$($winCli.transportType)' unexpected (should be 'stdio' or absent)"
}

# ----- Verify the target binary actually exists -----

if ($firstArg -match "index\.js$") {
    # Convert relative or forward-slash paths to absolute Windows path
    $binPath = $firstArg -replace '/', '\'
    if ($binPath -notmatch "^[a-zA-Z]:") {
        # Try to resolve from repo root D:\roo-extensions
        $binPath = Join-Path "D:\roo-extensions" $binPath
    }

    if (-not (Test-Path $binPath)) {
        $violations += "Target binary does NOT exist on disk: $binPath. Fork may have been deleted or moved."
    }
    else {
        Write-Result "Fork binary found at: $binPath" "INFO"
    }
}

# ----- Check version string in fork package.json -----

$forkPkg = "D:\roo-extensions\mcps\external\win-cli\server\package.json"
if (Test-Path $forkPkg) {
    try {
        $pkg = Get-Content -Path $forkPkg -Raw | ConvertFrom-Json
        if ($pkg.version -ne "0.2.0") {
            Write-Result "Local fork version is '$($pkg.version)' — expected '0.2.0'. Version bump may indicate sync with broken upstream." "WARN"
        } else {
            Write-Result "Fork package.json version: 0.2.0 (expected)" "INFO"
        }
    }
    catch {
        Write-Result "Could not parse fork package.json: $($_.Exception.Message)" "WARN"
    }
}

# ----- Report -----

if ($violations.Count -eq 0) {
    Write-Result "win-cli config OK — points to local fork, not broken npm" "PASS"
    exit 0
}
else {
    Write-Result "win-cli config DRIFT detected ($($violations.Count) violation$(if ($violations.Count -gt 1){'s'}))" "FAIL"
    $violations | ForEach-Object { Write-Result "  • $_" "FAIL" }
    Write-Result "" "INFO"
    Write-Result "To fix: edit $ConfigPath, ensure the 'win-cli' entry reads:" "INFO"
    Write-Result '  "win-cli": {' "INFO"
    Write-Result '    "command": "node",' "INFO"
    Write-Result '    "args": ["d:/roo-extensions/mcps/external/win-cli/server/dist/index.js"],' "INFO"
    Write-Result '    "transportType": "stdio",' "INFO"
    Write-Result '    "disabled": false' "INFO"
    Write-Result '  }' "INFO"
    Write-Result "Restart VS Code after editing. Ref: #1482, #1666 Phase A3." "INFO"
    exit 1
}
