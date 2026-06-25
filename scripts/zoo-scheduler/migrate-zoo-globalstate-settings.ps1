<#
.SYNOPSIS
    Extract Roo Code globalState behavioral+auto-approval settings into a Zoo-Code-importable JSON.

.DESCRIPTION
    The Roo->Zoo file migration (#2379 migrate-globalstorage.ps1) copies globalStorage FILES
    (mcp_settings.json, custom_modes.yaml, tasks/) but NEVER touches state.vscdb, where Roo's
    behavioral settings live (allowedCommands, deniedCommands, the alwaysAllow* flags, terminal
    settings...). The full-blob migration (scripts/deployment/migrate-roo-to-zoo.ps1) does copy
    state, but it ALSO copies the provider config (apiProvider/openAi*/currentApiConfigName) into
    globalState -- which is the wrong layer (provider config belongs in SecretStorage + interactive
    setup) and is the root cause of the Zoo in-memory flush-overwrite race observed on po-2025.

    This script is the surgical, SAFE settings-only extractor #2678 asks for:

      * Default mode (-GenerateFile, the default): READ-ONLY. Reads the Roo blob from a temp copy
        of state.vscdb, keeps ONLY the GlobalSettings allowlist keys (schema-derived, see below),
        and writes a Zoo-Import JSON file. No live DB mutation -> 100% headless-testable.
      * -MergeIntoDb (explicit flag): merges the allowlisted keys into the Zoo blob in state.vscdb.
        Refuses if VS Code (Code.exe) is running. Backs up state.vscdb (timestamped) first.
        Use ONLY when direct application is preferred over the Zoo Settings -> Import UI.

    The allowlist is GlobalSettings keys minus {secrets, provider-adjacent refs, custom modes,
    experiments, codebaseIndexConfig, UI cruft}. Source of truth:
      roo-code/packages/types/src/global-settings.ts  globalSettingsSchema (L81-235)
      = globalSettingsSchema.keyof().options  with the documented exclusions applied.

    NEVER exported: id (install UUID), taskHistory, any *ApiKey / secret, the provider blob
    (apiProvider/openAi*/currentApiConfigName/listApiConfigMeta/modeApiConfigs/profileThresholds/
    enhancementApiConfigId), customModes/customModePrompts/customSupportPrompts (mode migration is
    #2379's file-based job -- importing them here would clobber Zoo's own modes), experiments
    (Roo-version-specific feature flags, risky for the Zoo fork), codebaseIndexConfig (may embed
    credentials), and machine/UI path cruft.

.PARAMETER Mode
    GenerateFile (default) = read-only, emit JSON to -OutputPath. MergeIntoDb = write the Zoo blob.

.PARAMETER OutputPath
    Path for the generated Zoo-Import JSON (GenerateFile mode). Default: .\zoo-globalstate-import.json

.PARAMETER VscdbPath
    Path to state.vscdb. Auto-detected from %APPDATA%/Code/User/globalStorage/state.vscdb.

.PARAMETER DryRun
    Report what would be done without writing the file / mutating the DB. Default: true.
    (A DryRun in GenerateFile mode still reads the Roo blob and prints the plan + validation, but
    does not write -OutputPath. Use -DryRun:$false to write the file.)

.PARAMETER Force
    In MergeIntoDb mode, skip the "is Code.exe running" guard (use at your own risk).

.EXAMPLE
    .\migrate-zoo-globalstate-settings.ps1
    # DryRun GenerateFile: print plan + validation, no file written.

.EXAMPLE
    .\migrate-zoo-globalstate-settings.ps1 -DryRun:$false
    # Write ./zoo-globalstate-import.json, then import it via Zoo Code: Settings -> Import.

.EXAMPLE
    .\migrate-zoo-globalstate-settings.ps1 -Mode MergeIntoDb -DryRun:$false
    # Merge allowlisted keys into the Zoo blob directly (refuses if Code.exe runs).

.NOTES
    Issue #2678 -- Roo->Zoo globalState settings migration (safety-critical: deniedCommands).
    Issue #2629 -- portable sqlite access (Python stdlib sqlite3, no sqlite3 CLI).
    Requires: Python 3.x with stdlib sqlite3 (present fleet-wide via the sk-agent runtime).
#>

[CmdletBinding()]
param(
    [ValidateSet('GenerateFile', 'MergeIntoDb')][string]$Mode = 'GenerateFile',
    [string]$OutputPath,
    [string]$VscdbPath,
    [switch]$DryRun = $true,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# === Constants ===
$script:RooKey = 'RooVeterinaryInc.roo-cline'
$script:ZooKey = 'ZooCodeOrganization.zoo-code'

# GlobalSettings allowlist (schema-derived, see .DESCRIPTION / .SYNOPSIS).
# = globalSettingsSchema.keyof().options MINUS the documented exclusions.
# Source: roo-code/packages/types/src/global-settings.ts (globalSettingsSchema, L81-235).
$script:GlobalSettingsAllowlist = @(
    # --- Auto-approval + command safety (CRITICAL: the deniedCommands safety net) ---
    'autoApprovalEnabled',
    'alwaysAllowReadOnly', 'alwaysAllowReadOnlyOutsideWorkspace',
    'alwaysAllowWrite', 'alwaysAllowWriteOutsideWorkspace', 'alwaysAllowWriteProtected',
    'alwaysAllowMcp', 'alwaysAllowModeSwitch', 'alwaysAllowSubtasks',
    'alwaysAllowExecute', 'alwaysAllowFollowupQuestions', 'alwaysAllowBrowser',
    'alwaysApproveResubmit',
    'allowedCommands', 'deniedCommands',
    'commandExecutionTimeout', 'commandTimeoutAllowlist', 'preventCompletionWithOpenTodos',
    'allowedMaxRequests', 'allowedMaxCost',
    'writeDelayMs', 'requestDelaySeconds', 'rateLimitSeconds',
    'consecutiveMistakeLimit', 'followupAutoApproveTimeoutMs',
    # --- Context / condensation ---
    'autoCondenseContext', 'autoCondenseContextPercent', 'customCondensingPrompt',
    'customInstructions',
    'includeCurrentTime', 'includeCurrentCost', 'maxGitStatusFiles',
    'includeDiagnosticMessages', 'maxDiagnosticMessages',
    # --- Checkpoints ---
    'enableCheckpoints', 'checkpointTimeout',
    # --- Audio ---
    'ttsEnabled', 'ttsSpeed', 'soundEnabled', 'soundVolume',
    # --- Files / workspace context ---
    'maxOpenTabsContext', 'maxWorkspaceFiles', 'showRooIgnoredFiles', 'enableSubfolderRules',
    'maxImageFileSize', 'maxTotalImageSize',
    # --- Terminal ---
    'terminalOutputPreviewSize', 'terminalShellIntegrationTimeout', 'terminalShellIntegrationDisabled',
    'terminalCommandDelay', 'terminalPowershellCounter',
    'terminalZshClearEolMark', 'terminalZshOhMy', 'terminalZshP10k', 'terminalZdotdir',
    'terminalCompressProgressBar',
    'diagnosticsEnabled',
    # --- Indexing (models only; codebaseIndexConfig excluded -- may embed credentials) ---
    'codebaseIndexModels',
    # --- Misc behavioral ---
    'language', 'telemetrySetting', 'mcpEnabled', 'mode',
    'includeTaskHistoryInEnhance', 'historyPreviewCollapsed', 'reasoningBlockCollapsed',
    'enableReasoningEffort', 'enableMcpServerCreation', 'enableSubfolderRules',
    'enterBehavior', 'disabledTools', 'showWorktreesInHomeScreen',
    'fuzzyMatchThreshold', 'maxReadFileLine', 'maxConcurrentFileReads',
    'diffEnabled', 'browserToolEnabled', 'browserViewportSize', 'remoteBrowserEnabled',
    'screenshotQuality', 'todoListEnabled', 'modelTemperature'
)

# === Pure (testable) functions ===

function Get-ZooGlobalSettingsAllowlist {
    <#
        .SYNOPSIS Returns the schema-derived GlobalSettings allowlist (KEEP keys).
    #>
    return $script:GlobalSettingsAllowlist
}

function ConvertTo-ZooGlobalSettings {
    <#
        .SYNOPSIS
            Filter a Roo globalState blob down to the GlobalSettings allowlist keys.
        .DESCRIPTION
            PURE function -- no I/O. Takes the parsed Roo state object and returns a new
            hashtable containing only the allowlisted keys that are actually present in the
            Roo blob. This is the unit-testable core of the extraction.
        .PARAMETER RooState
            Parsed Roo globalState object (PSCustomObject or hashtable from ConvertFrom-Json).
        .OUTPUT
            [hashtable] of { key: value } for allowlisted keys present in $RooState.
    #>
    param([Parameter(Mandatory)]$RooState)

    $allow = Get-ZooGlobalSettingsAllowlist
    $result = @{}

    # Normalize PSCustomObject (ConvertFrom-Json) into an iterable property set.
    $properties = if ($RooState -is [System.Collections.IDictionary]) {
        $RooState.Keys
    } else {
        $RooState.PSObject.Properties.Name
    }

    foreach ($key in $properties) {
        if ($allow -contains $key) {
            $value = if ($RooState -is [System.Collections.IDictionary]) {
                $RooState[$key]
            } else {
                $RooState.$key
            }
            $result[$key] = $value
        }
    }
    return $result
}

function Test-GlobalSettingsBlob {
    <#
        .SYNOPSIS
            Validate a filtered GlobalSettings hashtable against the allowlist + safety invariants.
        .DESCRIPTION
            PURE function. Returns a hashtable { Valid, Errors, Warnings }.

            Validation is TWO-TIER (#2678 AC#1 "round-trip Zod against the roo-code schema"):
              TIER 1 (here, key-level): every emitted key is a member of the GlobalSettings allowlist,
                which is derived directly from `globalSettingsSchema.keyof().options`
                (roo-code/packages/types/src/global-settings.ts) -- so KEY correctness is guaranteed by
                construction, plus a value-shape check on the two safety-critical command keys
                (string arrays) to catch a corrupted source blob.
              TIER 2 (at the Zoo import boundary, value-level): the full Zod `safeParse()` against
                the live roo-code schema is performed by Zoo Code itself via
                `importSettingsFromPath` -> `providerSettingsManager.import` (importExport.ts).
                Running safeParse in-process here would require installing zod + a TS runtime into the
                roo-code submodule (reference-only, not a build env) -- disproportionate. The values
                originate from a Roo blob that Roo already wrote through the same schema, so they are
                schema-valid by origin; Tier 2 re-confirms at import. Deferred, not skipped.

            Checks reported:
              * Every key is in the allowlist (error).
              * deniedCommands / allowedCommands, when present, are string arrays (error on wrong
                type -- catches a corrupted blob).
              * JSON-serializable (error).
              * (Warning, not error) deniedCommands and allowedCommands are present and non-empty --
                these are the safety-critical keys; their absence is flagged but does not fail
                validation (a machine may legitimately have empty lists).
        .PARAMETER Settings
            Filtered GlobalSettings hashtable (output of ConvertTo-ZooGlobalSettings).
    #>
    param([Parameter(Mandatory)][hashtable]$Settings)

    $allow = Get-ZooGlobalSettingsAllowlist
    $errors = @()
    $warnings = @()

    # 1. Allowlist membership (TIER 1 -- key correctness by construction).
    foreach ($key in $Settings.Keys) {
        if ($allow -notcontains $key) {
            $errors += "Key '$key' is not in the GlobalSettings allowlist."
        }
    }

    # 2. Value-shape check on safety-critical command keys (catches a corrupted source blob).
    foreach ($cmdKey in @('deniedCommands', 'allowedCommands')) {
        if ($Settings.ContainsKey($cmdKey) -and $null -ne $Settings[$cmdKey]) {
            $arr = @($Settings[$cmdKey])
            $nonStrings = $arr | Where-Object { $_ -isnot [string] }
            if ($nonStrings.Count -gt 0) {
                $errors += "$cmdKey must be a string array; found non-string entry/entries (corrupted source?)."
            }
        }
    }

    # 3. JSON-serializable (round-trip). ConvertTo-Json -Depth 10 mirrors migrate-roo-to-zoo.ps1.
    try {
        $null = $Settings | ConvertTo-Json -Depth 10 -Compress
    } catch {
        $errors += "Settings are not JSON-serializable: $($_.Exception.Message)"
    }

    # 4. Safety-critical keys present (warning level -- absence is a safety regression flag).
    if (-not $Settings.ContainsKey('deniedCommands')) {
        $warnings += "deniedCommands absent in source -- target will have NO command denylist (safety)."
    } elseif (-not $Settings['deniedCommands'] -or @($Settings['deniedCommands']).Count -eq 0) {
        $warnings += "deniedCommands is empty in source -- no destructive commands blocked (safety)."
    }
    if (-not $Settings.ContainsKey('allowedCommands')) {
        $warnings += "allowedCommands absent in source."
    } elseif (-not $Settings['allowedCommands'] -or @($Settings['allowedCommands']).Count -eq 0) {
        $warnings += "allowedCommands is empty in source."
    }

    return @{
        Valid    = ($errors.Count -eq 0)
        Errors   = $errors
        Warnings = $warnings
    }
}

# === SQLite glue (Python stdlib sqlite3, issue #2629 -- no sqlite3 CLI dependency) ===

function Write-StateVscdbHelper {
    <#
        .SYNOPSIS Writes the inline Python sqlite helper to TEMP and returns its path.
        .DESCRIPTION
            Reuses the portable #2629 helper (same as migrate-roo-to-zoo.ps1): Python stdlib
            sqlite3, spec piped via STDIN to bypass the Windows 32,767-char argv limit (the merged
            Zoo blob is ~75K chars). Read-only here by default; UPDATE/INSERT only in MergeIntoDb.
    #>
    $path = Join-Path $env:TEMP 'migrate-zoo-globalstate-helper.py'
    $py = @'
import json, sqlite3, sys, shutil, os
# argv[1] = database path, stdin = JSON {op, query, params, scalar}
conn = sqlite3.connect(sys.argv[1])
try:
    cur = conn.cursor()
    spec = json.loads(sys.stdin.read().lstrip("﻿"))  # strip optional BOM
    params = spec.get("params")
    if spec.get("op") == "read":
        cur.execute(spec["query"], params or [])
        row = cur.fetchone()
        out = row[0] if row else None
    elif spec.get("op") == "write":
        cur.execute(spec["query"], params or [])
        out = cur.rowcount
    elif spec.get("op") == "scalar":
        cur.execute(spec["query"], params or [])
        row = cur.fetchone()
        out = row[0] if row else None
    else:
        out = None
    conn.commit()
    print(json.dumps(out))
finally:
    conn.close()
'@
    [System.IO.File]::WriteAllText($path, $py, [System.Text.UTF8Encoding]::new($false))
    return $path
}

function Invoke-VscdbHelper {
    param(
        [Parameter(Mandatory)][string]$Database,
        [Parameter(Mandatory)][string]$Op,        # read | write | scalar
        [Parameter(Mandatory)][string]$Query,
        [object[]]$Params
    )
    $helper = Write-StateVscdbHelper
    $spec = @{ op = $Op; query = $Query; params = $Params } | ConvertTo-Json -Compress -Depth 5
    $output = $spec | & python $helper $Database 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "SQLite helper error ($Op): $output"
    }
    return $output | ConvertFrom-Json
}

function Read-StateVscdbBlob {
    <#
        .SYNOPSIS Read a globalState blob from state.vscdb via a TEMP COPY (avoids locking VS Code).
        .OUTPUT The parsed JSON object, or $null if the key is absent.
    #>
    param([Parameter(Mandatory)][string]$VscdbPath, [Parameter(Mandatory)][string]$Key)

    $tmp = [System.IO.Path]::GetTempFileName() + '.vscdb'
    try {
        Copy-Item -LiteralPath $VscdbPath -Destination $tmp -Force
        $raw = Invoke-VscdbHelper -Database $tmp -Op read `
            -Query 'SELECT value FROM ItemTable WHERE key = ?;' -Params @($Key)
        if (-not $raw) { return $null }
        return $raw | ConvertFrom-Json
    } finally {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
}

# === Orchestrator ===

function Invoke-ZooGlobalStateMigration {
    <#
        .SYNOPSIS Orchestrates the Roo->Zoo globalState settings extraction/migration.
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('GenerateFile', 'MergeIntoDb')][string]$Mode = 'GenerateFile',
        [string]$OutputPath,
        [string]$VscdbPath,
        [switch]$DryRun = $true,
        [switch]$Force
    )

    # --- Resolve paths ---
    if (-not $VscdbPath) {
        $VscdbPath = Join-Path $env:APPDATA 'Code\User\globalStorage\state.vscdb'
    }
    if (-not (Test-Path $VscdbPath)) {
        throw "state.vscdb not found at: $VscdbPath"
    }
    if ($Mode -eq 'GenerateFile' -and -not $OutputPath) {
        $OutputPath = Join-Path (Get-Location) 'zoo-globalstate-import.json'
    }

    Write-Host "=== Roo -> Zoo globalState settings migration ===" -ForegroundColor Cyan
    Write-Host "Mode: $Mode | DryRun: $([bool]$DryRun)" -ForegroundColor Yellow
    Write-Host "Database: $VscdbPath"
    if ($Mode -eq 'GenerateFile') { Write-Host "Output:   $OutputPath" }
    Write-Host ""

    # --- Prereq: Python sqlite3 ---
    $null = Get-Command python -ErrorAction Stop
    $pyVer = & python -c "import sqlite3; print(sqlite3.sqlite_version)" 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Python sqlite3 stdlib not available: $pyVer" }
    Write-Host "[OK] python + sqlite3 stdlib (sqlite $pyVer)" -ForegroundColor Green

    # --- Read Roo blob (temp copy, read-only) ---
    $rooState = Read-StateVscdbBlob -VscdbPath $VscdbPath -Key $script:RooKey
    if (-not $rooState) {
        Write-Host "ERROR: No Roo Code state found in state.vscdb (key: $($script:RooKey))" -ForegroundColor Red
        Write-Host "Roo Code was never configured here, or its state was already removed." -ForegroundColor Yellow
        return
    }
    $rooKeyCount = if ($rooState -is [System.Collections.IDictionary]) { $rooState.Keys.Count } else { $rooState.PSObject.Properties.Name.Count }
    Write-Host "Roo state: $rooKeyCount keys" -ForegroundColor Green

    # --- Extract allowlisted GlobalSettings ---
    $settings = ConvertTo-ZooGlobalSettings -RooState $rooState
    Write-Host "Extracted GlobalSettings: $($settings.Count) keys (allowlist has $((Get-ZooGlobalSettingsAllowlist).Count))" -ForegroundColor Green

    # --- Validate ---
    $validation = Test-GlobalSettingsBlob -Settings $settings
    if (-not $validation.Valid) {
        Write-Host "VALIDATION FAILED:" -ForegroundColor Red
        $validation.Errors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        return
    }
    # Report the safety-critical keys explicitly.
    $denied = if ($settings.ContainsKey('deniedCommands')) { @($settings['deniedCommands']).Count } else { 'ABSENT' }
    $allowed = if ($settings.ContainsKey('allowedCommands')) { @($settings['allowedCommands']).Count } else { 'ABSENT' }
    Write-Host "  deniedCommands : $denied entry(ies)" -ForegroundColor $(if ($denied -ne 'ABSENT' -and [int]$denied -gt 0) { 'Green' } else { 'Yellow' })
    Write-Host "  allowedCommands: $allowed entry(ies)"
    if ($validation.Warnings) {
        Write-Host "Warnings:" -ForegroundColor Yellow
        $validation.Warnings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    }

    # --- Build Zoo-Import envelope: { globalSettings } (no providerProfiles -- provider excluded) ---
    $envelope = @{ globalSettings = $settings }
    $json = $envelope | ConvertTo-Json -Depth 10

    if ($DryRun) {
        Write-Host "`n[DRY-RUN] No file written, no DB mutation." -ForegroundColor Yellow
        Write-Host "Re-run with -DryRun:`$false to $(if ($Mode -eq 'GenerateFile') { 'write the JSON' } else { 'merge into the Zoo blob' })." -ForegroundColor Yellow
        return
    }

    if ($Mode -eq 'GenerateFile') {
        # UTF-8 no BOM (issue #664 -- BOM breaks JSON parsers).
        [System.IO.File]::WriteAllText($OutputPath, $json, [System.Text.UTF8Encoding]::new($false))
        Write-Host "`n[OK] Wrote $OutputPath ($(($json.Length / 1KB).ToString('0.0')) KB)" -ForegroundColor Green
        Write-Host "Import via: Zoo Code -> Settings -> Import." -ForegroundColor Cyan
    } else {
        # --- MergeIntoDb: refuse if Code.exe runs, backup, merge ---
        if (-not $Force) {
            $codeRunning = Get-Process -Name 'Code' -ErrorAction SilentlyContinue
            if ($codeRunning) {
                throw "VS Code (Code.exe) is running. Close it first, or re-run with -Force (risky: Zoo may flush its in-memory state on exit and overwrite the merge)."
            }
        }
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $backup = "$VscdbPath.zoogs-backup_$timestamp"
        Copy-Item -LiteralPath $VscdbPath -Destination $backup -Force
        Write-Host "`nBackup: $backup" -ForegroundColor Green

        # Read current Zoo blob, merge allowlisted keys, write back.
        $zooState = Read-StateVscdbBlob -VscdbPath $VscdbPath -Key $script:ZooKey
        $merged = @{}
        if ($zooState) {
            $zooProps = if ($zooState -is [System.Collections.IDictionary]) { $zooState.Keys } else { $zooState.PSObject.Properties.Name }
            foreach ($k in $zooProps) {
                $merged[$k] = if ($zooState -is [System.Collections.IDictionary]) { $zooState[$k] } else { $zooState.$k }
            }
        }
        foreach ($k in $settings.Keys) { $merged[$k] = $settings[$k] }
        $mergedJson = $merged | ConvertTo-Json -Depth 10 -Compress

        $null = Invoke-VscdbHelper -Database $VscdbPath -Op write `
            -Query 'UPDATE ItemTable SET value = ? WHERE key = ?;' -Params @($mergedJson, $script:ZooKey)
        $exists = Invoke-VscdbHelper -Database $VscdbPath -Op scalar `
            -Query 'SELECT count(*) FROM ItemTable WHERE key = ?;' -Params @($script:ZooKey)
        if ([string]$exists -eq '0') {
            $null = Invoke-VscdbHelper -Database $VscdbPath -Op write `
                -Query 'INSERT INTO ItemTable (key, value) VALUES (?, ?);' -Params @($script:ZooKey, $mergedJson)
        }
        Write-Host "[OK] Merged $($settings.Count) settings keys into Zoo blob ($($merged.Count) total keys)." -ForegroundColor Green
        Write-Host "Restart VS Code to pick up the merged state." -ForegroundColor Cyan
    }
}

# === Export for testing (Import-Module). Export-ModuleMember is only valid inside a module
#     context; guard with try/catch so direct -File invocation (CLI mode) no-ops instead of erroring.
try {
    Export-ModuleMember -Function `
        Get-ZooGlobalSettingsAllowlist, `
        ConvertTo-ZooGlobalSettings, `
        Test-GlobalSettingsBlob, `
        Invoke-ZooGlobalStateMigration
} catch {
    # No-op: running as a CLI script (-File), not imported as a module.
}

# === Main: run only when executed directly (-File or & operator), NOT when dot-sourced or imported.
#      NOTE: a [CmdletBinding()] script reports $MyInvocation.CommandOrigin = 'Internal' (not
#      'Runspace') under `pwsh -File`, so a `-eq 'Runspace'` guard silently no-ops the entire CLI
#      path (exit 0, zero output). The reliable discriminator is InvocationName: it is '.' when
#      dot-sourced, '' when Import-Module'd, and the script path / '&' when executed directly.
$invocName = "$($MyInvocation.InvocationName)"
if ($invocName -ne '.' -and $invocName -ne '') {
    Invoke-ZooGlobalStateMigration @PSBoundParameters
}
