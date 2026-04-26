# =================================================================================================
#
#   Cross-Machine MCP Configuration Validation
#
#   Issue: #1656 Phase A3 (sub-issue of #1648)
#   Purpose: Validate MCP configs for BOTH Claude Code and Roo on this machine.
#            Detect drift vs canonical repo sources, missing critical MCPs,
#            presence of retired MCPs, and win-cli fork integrity.
#
#   Exit codes: 0=OK, 1=CRITICAL drift, 2=config not found
#
# =================================================================================================

[CmdletBinding()]
param(
    [switch]$Quiet,
    [switch]$JsonOutput,

    # Config paths (default to standard locations)
    [string]$ClaudeConfigPath = "$env:USERPROFILE\.claude.json",
    [string]$RooConfigPath = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json",

    # Repo root for canonical references
    [string]$RepoRoot = "D:\Dev\roo-extensions"
)

# =================================================================================================
#   RETIRED MCPs — must NOT be present in any config
# =================================================================================================

$script:RetiredMcpNames = @(
    "desktop-commander",
    "github-projects-mcp",
    "quickfiles"
)

# =================================================================================================
#   CRITICAL MCPs per agent
# =================================================================================================

$script:ClaudeCriticalMcps = @("roo-state-manager")
$script:RooCriticalMcps = @("win-cli", "roo-state-manager")

# =================================================================================================
#   WIN-CLI CANONICAL CONFIG (from tool-availability.md, #1666 Phase A3)
# =================================================================================================

$script:WinCliCanonical = @{
    Command        = "node"
    ArgsPattern    = "mcps[/\\]external[/\\]win-cli[/\\]server[/\\]dist[/\\]index\.js$"
    TransportType  = "stdio"
    Disabled       = $false
}

# =================================================================================================
#   UTILITY FUNCTIONS
# =================================================================================================

function Write-Result {
    param([string]$Message, [string]$Level = "INFO")
    if ($Quiet -and $Level -eq "INFO") { return }
    $color = switch ($Level) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
        default { "White" }
    }
    Write-Host "[$Level] $Message" -ForegroundColor $color
}

function Read-JsonConfig {
    param([string]$Path, [string]$Label)

    if (-not (Test-Path $Path)) {
        Write-Result "$Label config not found: $Path" "FAIL"
        return $null
    }

    try {
        $content = [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false))

        # Try standard ConvertFrom-Json first (works for most configs)
        try {
            return $content | ConvertFrom-Json
        }
        catch {
            # Fallback: extract just the mcpServers section via regex
            # Handles duplicate-key JSON (e.g. ~/.claude.json with D:/ vs d:/ paths)
            Write-Result "$Label full JSON parse failed (duplicate keys?), extracting mcpServers section" "WARN"
            return Extract-McpServers $content $Label
        }
    }
    catch {
        Write-Result "$Label config read error: $($_.Exception.Message)" "FAIL"
        return $null
    }
}

function Extract-McpServers {
    param([string]$Content, [string]$Label)

    # Find "mcpServers": { ... } using balanced-brace matching
    $match = [regex]::Match($Content, '"mcpServers"\s*:\s*\{')
    if (-not $match.Success) {
        Write-Result "$Label no mcpServers section found" "WARN"
        return $null
    }

    $startIdx = $match.Index + $match.Length - 1  # index of opening {
    $depth = 0
    $endIdx = $startIdx
    for ($i = $startIdx; $i -lt $Content.Length; $i++) {
        if ($Content[$i] -eq '{') { $depth++ }
        elseif ($Content[$i] -eq '}') {
            $depth--
            if ($depth -eq 0) { $endIdx = $i; break }
        }
    }

    $mcpJson = $content.Substring($startIdx, $endIdx - $startIdx + 1)
    try {
        $servers = $mcpJson | ConvertFrom-Json
        # Wrap in a synthetic object with just mcpServers
        return [PSCustomObject]@{ mcpServers = $servers }
    }
    catch {
        Write-Result "$Label mcpServers section parse error: $($_.Exception.Message)" "FAIL"
        return $null
    }
}

function Find-RetiredMcps {
    param([hashtable]$Servers, [string]$Label)

    $found = @()
    foreach ($retired in $script:RetiredMcpNames) {
        if ($Servers.ContainsKey($retired)) {
            $found += $retired
            Write-Result "$Label contains RETIRED MCP: '$retired' — must be removed" "FAIL"
        }
    }
    return $found
}

function Test-CriticalMcps {
    param([hashtable]$Servers, [string[]]$Required, [string]$Label)

    $missing = @()
    foreach ($mcp in $Required) {
        if (-not $Servers.ContainsKey($mcp)) {
            $missing += $mcp
            Write-Result "$Label missing CRITICAL MCP: '$mcp'" "FAIL"
        }
        elseif ($Servers[$mcp].disabled -eq $true) {
            $missing += "$mcp (disabled)"
            Write-Result "$Label has CRITICAL MCP '$mcp' but it is DISABLED" "FAIL"
        }
        else {
            Write-Result "$Label has critical MCP '$mcp' — OK" "PASS"
        }
    }
    return $missing
}

function Test-WinCliConfig {
    param($WinCliEntry)

    $violations = @()

    if (-not $WinCliEntry) {
        Write-Result "Roo config has no 'win-cli' entry — Roo scheduler has no terminal" "FAIL"
        return @("win-cli missing from Roo mcpServers")
    }

    if ($WinCliEntry.command -ne $script:WinCliCanonical.Command) {
        $violations += "command='$($WinCliEntry.command)' (expected 'node')"
    }

    $firstArg = if ($WinCliEntry.args -and $WinCliEntry.args.Count -gt 0) { $WinCliEntry.args[0] } else { "" }
    if ($firstArg -notmatch $script:WinCliCanonical.ArgsPattern) {
        $violations += "args[0] does not point to local fork: '$firstArg'"
    }

    foreach ($a in @($WinCliEntry.args)) {
        if ($a -match "@simonb97/server-win-cli|@anthropic/win-cli") {
            $violations += "BROKEN npm reference in args: '$a' (#1482)"
        }
    }

    if ($WinCliEntry.disabled -eq $true) {
        $violations += "win-cli is disabled"
    }

    if ($firstArg -match "index\.js$") {
        $binPath = $firstArg -replace '/', '\'
        if ($binPath -notmatch "^[a-zA-Z]:") {
            $binPath = Join-Path $RepoRoot $binPath
        }
        if (-not (Test-Path $binPath)) {
            $violations += "Target binary missing on disk: $binPath"
        }
    }

    if ($violations.Count -eq 0) {
        Write-Result "Roo win-cli config — OK (local fork)" "PASS"
    }
    else {
        foreach ($v in $violations) {
            Write-Result "Roo win-cli drift: $v" "FAIL"
        }
    }

    return $violations
}

function Test-SkAgentLocation {
    param([bool]$InGlobal, [bool]$InProject, [string]$Label)

    if ($InProject) {
        Write-Result "$Label sk-agent found in .mcp.json project — MUST be global only (#1557)" "FAIL"
        return @("sk-agent in project .mcp.json")
    }

    if ($InGlobal) {
        Write-Result "$Label sk-agent in global config — OK" "PASS"
        return @()
    }

    Write-Result "$Label sk-agent not found in global config — may be missing" "WARN"
    return @()
}

# =================================================================================================
#   MAIN VALIDATION
# =================================================================================================

$script:Violations = @()

Write-Host ""
Write-Host "=== MCP Config Cross-Machine Validation ===" -ForegroundColor Cyan
Write-Host "Machine: $env:COMPUTERNAME | Repo: $RepoRoot"
Write-Host ""

# -------------------------------------------------------------------------------------------------
# 1. Claude Code config (~/.claude.json)
# -------------------------------------------------------------------------------------------------

Write-Host "--- Claude Code MCP Config ---" -ForegroundColor Cyan

$claudeConfig = Read-JsonConfig -Path $ClaudeConfigPath -Label "Claude Code"
$claudeServers = @{}
$claudeHasSkAgent = $false

if ($claudeConfig -and $claudeConfig.mcpServers) {
    $ms = $claudeConfig.mcpServers
    if ($ms -is [System.Collections.IDictionary]) {
        foreach ($key in @($ms.Keys)) { $claudeServers[$key] = $ms[$key] }
    }
    else {
        $ms.PSObject.Properties | ForEach-Object { $claudeServers[$_.Name] = $_.Value }
    }
    $claudeHasSkAgent = $claudeServers.ContainsKey("sk-agent")

    Write-Result "Claude Code has $($claudeServers.Count) MCP servers configured" "INFO"

    # Check retired
    $script:Violations += (Find-RetiredMcps -Servers $claudeServers -Label "Claude Code")

    # Check critical
    $script:Violations += (Test-CriticalMcps -Servers $claudeServers -Required $script:ClaudeCriticalMcps -Label "Claude Code")
}
else {
    Write-Result "Claude Code config has no mcpServers section" "WARN"
}

# Check sk-agent project-level contamination
$projectMcpPath = Join-Path $RepoRoot ".mcp.json"
$projectHasSkAgent = $false
if (Test-Path $projectMcpPath) {
    try {
        $projCfg = [System.IO.File]::ReadAllText($projectMcpPath, [System.Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
        if ($projCfg.mcpServers -and $projCfg.mcpServers."sk-agent") {
            $projectHasSkAgent = $true
        }
    }
    catch { }
}
$script:Violations += (Test-SkAgentLocation -InGlobal $claudeHasSkAgent -InProject $projectHasSkAgent -Label "Claude Code")

# -------------------------------------------------------------------------------------------------
# 2. Roo config (%APPDATA%\...\mcp_settings.json)
# -------------------------------------------------------------------------------------------------

Write-Host ""
Write-Host "--- Roo MCP Config ---" -ForegroundColor Cyan

$rooConfig = Read-JsonConfig -Path $RooConfigPath -Label "Roo"
$rooServers = @{}

if ($rooConfig -and $rooConfig.mcpServers) {
    $ms = $rooConfig.mcpServers
    if ($ms -is [System.Collections.IDictionary]) {
        foreach ($key in @($ms.Keys)) { $rooServers[$key] = $ms[$key] }
    }
    else {
        $ms.PSObject.Properties | ForEach-Object { $rooServers[$_.Name] = $_.Value }
    }

    Write-Result "Roo has $($rooServers.Count) MCP servers configured" "INFO"

    # Check retired
    $script:Violations += (Find-RetiredMcps -Servers $rooServers -Label "Roo")

    # Check critical
    $script:Violations += (Test-CriticalMcps -Servers $rooServers -Required $script:RooCriticalMcps -Label "Roo")

    # Win-cli fork check
    $script:Violations += (Test-WinCliConfig -WinCliEntry $rooServers["win-cli"])
}
else {
    Write-Result "Roo config has no mcpServers section or file not found" "WARN"
}

# -------------------------------------------------------------------------------------------------
# 3. Summary
# -------------------------------------------------------------------------------------------------

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan

$allViolations = $script:Violations | Where-Object { $_ -ne "" }
$vCount = @($allViolations).Count

if ($JsonOutput) {
    $summary = @{
        machine    = $env:COMPUTERNAME
        timestamp  = (Get-Date -Format "o")
        violations = @($allViolations)
        violationCount = $vCount
        claudeServers  = $claudeServers.Count
        rooServers     = $rooServers.Count
        status     = if ($vCount -eq 0) { "OK" } else { "DRIFT" }
    } | ConvertTo-Json -Compress
    Write-Output $summary
}

if ($vCount -eq 0) {
    Write-Result "All MCP config checks PASSED — no drift detected" "PASS"
    exit 0
}
else {
    Write-Result "$vCount violation$(if ($vCount -gt 1) { 's' }) detected" "FAIL"
    exit 1
}
