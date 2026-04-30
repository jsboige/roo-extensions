#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Set fields (Status, Agent, Machine, Execution) for ALL items in Project #67.

.DESCRIPTION
    Reads all project items, fetches their issue details, and sets fields
    based on labels and title prefixes. Idempotent — safe to re-run.

.PARAMETER DryRun
    Show what would be changed without making changes.

.PARAMETER Execute
    Actually update the fields.
#>

[CmdletBinding()]
param(
    [switch]$DryRun = $false,
    [switch]$Execute = $false
)

$ErrorActionPreference = "Stop"

# --- Constants ---

$Owner = "jsboige"
$Repo = "roo-extensions"
$ProjectNumber = 67
$ProjectId = "PVT_kwHOADA1Xc4BLw3w"

$FieldIds = @{
    Status    = "PVTSSF_lAHOADA1Xc4BLw3wzg7PYHY"
    Agent     = "PVTSSF_lAHOADA1Xc4BLw3wzg9icmA"
    Machine   = "PVTSSF_lAHOADA1Xc4BLw3wzg9nHu8"
    Execution = "PVTSSF_lAHOADA1Xc4BLw3wzg-jMss"
}

$StatusOptions = @{
    Todo        = "f75ad846"
    InProgress  = "47fc9ee4"
    Done        = "98236657"
}

$AgentOptions = @{
    Roo         = "102d5164"
    ClaudeCode  = "cf1eae0a"
    Both        = "33d72521"
}

$MachineOptions = @{
    "myia-ai-01"   = "ae516a70"
    "myia-po-2023" = "2b4454e0"
    "myia-po-2024" = "91dd0acf"
    "myia-po-2025" = "4f388455"
    "myia-po-2026" = "bc8df25a"
    "myia-web1"    = "e3cd0cd0"
    "All"          = "175c5fe1"
    "Any"          = "4c242ac6"
}

$ExecutionOptions = @{
    Interactive = "7655267d"
    Scheduled   = "27c8f64e"
    Both        = "98b54b15"
}

$TitlePrefixToMachine = @{
    "[CLAUDE-AI-01]"   = "myia-ai-01"
    "[CLAUDE-PO-2023]" = "myia-po-2023"
    "[CLAUDE-PO-2024]" = "myia-po-2024"
    "[CLAUDE-PO-2025]" = "myia-po-2025"
    "[CLAUDE-PO-2026]" = "myia-po-2026"
    "[CLAUDE-WEB1]"    = "myia-web1"
    "[CLAUDE-ALL]"     = "All"
    "[CLAUDE-MACHINE]" = "Any"
}

# --- Helpers ---

function Write-Status($msg) {
    Write-Host "`n[msg] $msg" -ForegroundColor Cyan
}

function Write-Ok($msg) {
    Write-Host "  [OK] $msg" -ForegroundColor Green
}

function Write-Warn($msg) {
    Write-Host "  [WARN] $msg" -ForegroundColor Yellow
}

function Write-Err($msg) {
    Write-Host "  [ERR] $msg" -ForegroundColor Red
}

function Invoke-GhSafe($cmd) {
    try {
        $result = Invoke-Expression $cmd 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Err "Command failed (exit $LASTEXITCODE): $cmd"
            Write-Err $result
            return $null
        }
        if ($result) { return $result } else { return "__SUCCESS__" }
    }
    catch {
        Write-Err "Exception: $_"
        return $null
    }
}

# --- Phase 1: Collect project items ---

Write-Status "Phase 1: Collecting Project #$ProjectNumber items..."

$cmd = "gh project item-list $ProjectNumber --owner $Owner --format json --limit 500"
$result = Invoke-GhSafe $cmd
if (-not $result) {
    Write-Err "Failed to fetch project items"
    exit 1
}

$json = $result | ConvertFrom-Json
$projectItems = @($json.items ?? @())
Write-Host "  Fetched $($projectItems.Count) items"

# Filter to items with issue URLs
$issueItems = @()
foreach ($item in $projectItems) {
    $content = $item.content
    if ($content -and $content.url -and $content.url -match "/issues/(\d+)$") {
        $issueItems += @{
            itemId    = $item.id
            issueNum  = [int]$Matches[1]
            title     = $content.title ?? ""
        }
    }
}

Write-Ok "Found $($issueItems.Count) issue items in project"

# --- Phase 2: Fetch issue details ---

Write-Status "Phase 2: Fetching issue details..."

# Get all open issues
$cmd = "gh issue list --repo $Owner/$Repo --state open --limit 500 --json number,title,labels"
$result = Invoke-GhSafe $cmd
if (-not $result) {
    Write-Err "Failed to fetch issues"
    exit 1
}

$allIssues = @($result | ConvertFrom-Json)
$issueMap = @{}
foreach ($iss in $allIssues) {
    $issueMap[[int]$iss.number] = $iss
}

# Also get closed issues that might be in project
$cmd = "gh issue list --repo $Owner/$Repo --state closed --limit 500 --json number,title,labels"
$result = Invoke-GhSafe $cmd
if ($result) {
    $closedIssues = @($result | ConvertFrom-Json)
    foreach ($iss in $closedIssues) {
        if (-not $issueMap.ContainsKey([int]$iss.number)) {
            $issueMap[[int]$iss.number] = $iss
        }
    }
}

Write-Ok "Loaded $($issueMap.Count) issues (open + closed)"

# --- Phase 3: Set fields ---

$mode = if ($Execute) { "EXECUTE" } else { "DRY-RUN" }
Write-Status "Phase 3: Setting fields (mode: $mode)..."

$fieldsSetCount = 0
$skippedCount = 0

foreach ($item in $issueItems) {
    $num = $item.issueNum
    $itemId = $item.itemId
    $title = $item.title

    # Get issue from map (use title from issue if available)
    $issue = $issueMap[$num]
    if (-not $issue) {
        Write-Warn "#$num`: Not found in issue list, using title from project"
        $labelNames = @()
    }
    else {
        $title = $issue.title
        $labelNames = @()
        if ($issue.labels) {
            $labelNames = @($issue.labels | ForEach-Object { $_.name })
        }
    }

    # Determine Agent from labels
    $agentOption = $null
    $hasClaudeOnly = $labelNames -contains "claude-only"
    $hasRooSchedulable = $labelNames -contains "roo-schedulable"

    if ($hasClaudeOnly -and $hasRooSchedulable) {
        $agentOption = $AgentOptions["Both"]
    }
    elseif ($hasClaudeOnly) {
        $agentOption = $AgentOptions["ClaudeCode"]
    }
    elseif ($hasRooSchedulable) {
        $agentOption = $AgentOptions["Roo"]
    }

    # Determine Machine from title prefix
    $machineOption = $null
    foreach ($prefix in $TitlePrefixToMachine.Keys) {
        if ($title.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            $machineName = $TitlePrefixToMachine[$prefix]
            $machineOption = $MachineOptions[$machineName]
            break
        }
    }

    # Also check labels for machine
    if (-not $machineOption) {
        foreach ($label in $labelNames) {
            switch -Wildcard ($label) {
                "myia-ai-01" { $machineOption = $MachineOptions["myia-ai-01"]; break }
                "myia-po-2023" { $machineOption = $MachineOptions["myia-po-2023"]; break }
                "myia-po-2024" { $machineOption = $MachineOptions["myia-po-2024"]; break }
                "myia-po-2025" { $machineOption = $MachineOptions["myia-po-2025"]; break }
                "myia-po-2026" { $machineOption = $MachineOptions["myia-po-2026"]; break }
                "myia-web1" { $machineOption = $MachineOptions["myia-web1"]; break }
            }
            if ($machineOption) { break }
        }
    }

    # Determine Execution from labels
    $executionOption = $null
    if ($hasClaudeOnly -and $hasRooSchedulable) {
        $executionOption = $ExecutionOptions["Both"]
    }
    elseif ($hasClaudeOnly) {
        $executionOption = $ExecutionOptions["Interactive"]
    }
    elseif ($hasRooSchedulable) {
        $executionOption = $ExecutionOptions["Scheduled"]
    }

    # Status → Todo (for items without a status)
    $statusOption = $StatusOptions["Todo"]

    # Build fields to set
    $fieldsApplied = @()

    if ($DryRun) {
        if ($statusOption) { $fieldsApplied += "Status=Todo" }
        if ($agentOption) { $fieldsApplied += "Agent=<detected>" }
        if ($machineOption) { $fieldsApplied += "Machine=<detected>" }
        if ($executionOption) { $fieldsApplied += "Execution=<detected>" }
    }
    else {
        # Status → Todo
        $cmd = "gh project item-edit --id `"$itemId`" --project-id `"$ProjectId`" --field-id `"$($FieldIds.Status)`" --single-select-option-id `"$statusOption`""
        $result = Invoke-GhSafe $cmd
        if ($null -ne $result) { $fieldsApplied += "Status=Todo" }

        # Agent
        if ($agentOption) {
            $cmd = "gh project item-edit --id `"$itemId`" --project-id `"$ProjectId`" --field-id `"$($FieldIds.Agent)`" --single-select-option-id `"$agentOption`""
            $result = Invoke-GhSafe $cmd
            if ($null -ne $result) {
                $agentName = $AgentOptions.GetEnumerator() | Where-Object { $_.Value -eq $agentOption } | Select-Object -First 1
                $fieldsApplied += "Agent=$($agentName.Key)"
            }
        }

        # Machine
        if ($machineOption) {
            $cmd = "gh project item-edit --id `"$itemId`" --project-id `"$ProjectId`" --field-id `"$($FieldIds.Machine)`" --single-select-option-id `"$machineOption`""
            $result = Invoke-GhSafe $cmd
            if ($null -ne $result) {
                $machineName = $MachineOptions.GetEnumerator() | Where-Object { $_.Value -eq $machineOption } | Select-Object -First 1
                $fieldsApplied += "Machine=$($machineName.Key)"
            }
        }

        # Execution
        if ($executionOption) {
            $cmd = "gh project item-edit --id `"$itemId`" --project-id `"$ProjectId`" --field-id `"$($FieldIds.Execution)`" --single-select-option-id `"$executionOption`""
            $result = Invoke-GhSafe $cmd
            if ($null -ne $result) {
                $execName = $ExecutionOptions.GetEnumerator() | Where-Object { $_.Value -eq $executionOption } | Select-Object -First 1
                $fieldsApplied += "Execution=$($execName.Key)"
            }
        }
    }

    if ($fieldsApplied.Count -gt 0) {
        Write-Host "  #$num`: $($fieldsApplied -join ', ')" -ForegroundColor DarkGray
        $fieldsSetCount++
    }
    else {
        $skippedCount++
    }
}

# --- Final report ---

Write-Status "DONE"
Write-Host @"
  Mode:         $mode
  Total items:  $($issueItems.Count)
  Fields set:   $fieldsSetCount
  Skipped:      $skippedCount
"@
