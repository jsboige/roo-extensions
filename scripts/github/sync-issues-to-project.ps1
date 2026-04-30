#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Sync open GitHub issues to Project #67 (RooSync Multi-Agent Tasks).

.DESCRIPTION
    Reconciles open issues in jsboige/roo-extensions with GitHub Project #67.
    Adds missing issues and sets fields (Agent, Machine, Status) based on labels.

.PARAMETER DryRun
    If set, shows what would be done without making changes. Default: true.

.PARAMETER Execute
    If set, actually adds issues and updates fields.

.PARAMETER ProjectNumber
    GitHub Project number. Default: 67.

.PARAMETER Owner
    GitHub repository/project owner. Default: jsboige.

.PARAMETER Repo
    GitHub repository name. Default: roo-extensions.

.PARAMETER SetFields
    Also set Agent/Machine/Status fields based on labels. Default: true.

.EXAMPLE
    ./sync-issues-to-project.ps1 -DryRun
    # Shows missing issues without adding them.

.EXAMPLE
    ./sync-issues-to-project.ps1 -Execute
    # Adds all missing issues and sets fields.

.EXAMPLE
    ./sync-issues-to-project.ps1 -Execute -SetFields:$false
    # Adds missing issues without setting fields.
#>

[CmdletBinding()]
param(
    [switch]$DryRun = $false,
    [switch]$Execute = $false,
    [int]$ProjectNumber = 67,
    [string]$Owner = "jsboige",
    [string]$Repo = "roo-extensions",
    [bool]$SetFields = $true
)

$ErrorActionPreference = "Stop"

# --- Constants ---

$ProjectId = "PVT_kwHOADA1Xc4BLw3w"

# Field IDs
$FieldIds = @{
    Status    = "PVTSSF_lAHOADA1Xc4BLw3wzg7PYHY"
    Agent     = "PVTSSF_lAHOADA1Xc4BLw3wzg9icmA"
    Machine   = "PVTSSF_lAHOADA1Xc4BLw3wzg9nHu8"
    Model     = "PVTSSF_lAHOADA1Xc4BLw3wzg-jMsU"
    Execution = "PVTSSF_lAHOADA1Xc4BLw3wzg-jMss"
    Deadline  = "PVTF_lAHOADA1Xc4BLw3wzg-jMsw"
}

# Option IDs
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
    "myia-ai-01"  = "ae516a70"
    "myia-po-2023" = "2b4454e0"
    "myia-po-2024" = "91dd0acf"
    "myia-po-2025" = "4f388455"
    "myia-po-2026" = "bc8df25a"
    "myia-web1"   = "e3cd0cd0"
    "All"         = "175c5fe1"
    "Any"         = "4c242ac6"
}

$ExecutionOptions = @{
    Interactive = "7655267d"
    Scheduled   = "27c8f64e"
    Both        = "98b54b15"
}

# Title prefix → Machine mappings
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
        # Return output (may be empty for commands like item-edit)
        if ($result) { return $result } else { return "__SUCCESS__" }
    }
    catch {
        Write-Err "Exception: $_"
        return $null
    }
}

# --- Phase 1: Collect project items ---

Write-Status "Phase 1: Collecting Project #$ProjectNumber items..."

$projectItems = @()
Write-Host "  Fetching all project items (single call)..."

$cmd = "gh project item-list $ProjectNumber --owner $Owner --format json --limit 500"
$result = Invoke-GhSafe $cmd
if (-not $result) {
    Write-Err "Failed to fetch project items"
    exit 1
}

$json = $result | ConvertFrom-Json
$projectItems = @($json.items ?? @())
$totalCount = $json.totalCount ?? 0

Write-Host "  Fetched $($projectItems.Count) items (total: ${totalCount})"

# Extract issue numbers already in project
$issuesInProject = @{}
foreach ($item in $projectItems) {
    $content = $item.content
    if ($content -and $content.url) {
        $url = $content.url
        if ($url -match "/issues/(\d+)$") {
            $issueNum = [int]$Matches[1]
            $issuesInProject[$issueNum] = $item.id
        }
    }
}

Write-Ok "Found $($issuesInProject.Count) issues already in Project #$ProjectNumber"

# --- Phase 2: Collect open issues ---

Write-Status "Phase 2: Collecting open issues from $Owner/$Repo..."

$allIssues = @()

Write-Host "  Fetching all open issues (single call)..."

$cmd = "gh issue list --repo $Owner/$Repo --state open --limit 500 --json number,title,labels,url"
$result = Invoke-GhSafe $cmd
if (-not $result) {
    Write-Err "Failed to fetch open issues"
    exit 1
}

$allIssues = @($result | ConvertFrom-Json)
Write-Host "  Fetched $($allIssues.Count) issues"

Write-Ok "Found $($allIssues.Count) open issues"

# --- Phase 3: Find gap ---

Write-Status "Phase 3: Finding issues missing from project..."

$missingIssues = $allIssues | Where-Object {
    -not $issuesInProject.ContainsKey([int]$_.number)
} | Sort-Object -Property number -Descending

Write-Host "  Missing from project: $($missingIssues.Count) issues"

if ($missingIssues.Count -eq 0) {
    Write-Ok "All open issues are already in Project #$ProjectNumber. Nothing to do."
    exit 0
}

# --- Phase 4: Add missing issues ---

$mode = if ($Execute) { "EXECUTE" } else { "DRY-RUN" }
Write-Status "Phase 4: Adding missing issues (mode: $mode)..."

$addedCount = 0
$failedCount = 0
$skippedCount = 0
$addedItems = @()

foreach ($issue in $missingIssues) {
    $num = $issue.number
    $title = $issue.title
    $url = $issue.url
    $labelNames = ($issue.labels | ForEach-Object { $_.name }) -join ", "

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Would add #$num - $title" -ForegroundColor Yellow
        $addedItems += @{ number = $num; itemId = "dry-run"; title = $title; labels = $issue.labels }
        $addedCount++
        continue
    }

    # Add to project
    $cmd = "gh project item-add $ProjectNumber --owner $Owner --url `"$url`" --format json"
    $result = Invoke-GhSafe $cmd

    if (-not $result) {
        Write-Err "Failed to add #$num"
        $failedCount++
        continue
    }

    try {
        $itemData = $result | ConvertFrom-Json
        $itemId = $itemData.id

        if (-not $itemId) {
            Write-Warn "No item ID returned for #$num"
            $failedCount++
            continue
        }

        Write-Ok "Added #$num - $title (item: $itemId)"
        $addedItems += @{ number = $num; itemId = $itemId; title = $title; labels = $issue.labels }
        $addedCount++
    }
    catch {
        Write-Err "Failed to parse response for #${num}: $_"
        $failedCount++
    }
}

Write-Host "`n  Summary: Added=$addedCount, Failed=$failedCount, Skipped=$skippedCount"

# --- Phase 5: Set fields ---

if (-not $SetFields -or $addedItems.Count -eq 0) {
    if ($addedItems.Count -gt 0) {
        Write-Status "Phase 5: SKIPPED (SetFields=$SetFields)"
    }
    Write-Status "DONE"
    Write-Host "  Added: $addedCount | Failed: $failedCount | Missing: $($missingIssues.Count)"
    exit 0
}

Write-Status "Phase 5: Setting fields for $($addedItems.Count) new items..."

$fieldsSetCount = 0

foreach ($item in $addedItems) {
    if ($item.itemId -eq "dry-run") {
        continue
    }

    $num = $item.number
    $itemId = $item.itemId
    $title = $item.title
    $labels = $item.labels
    $labelNames = @()
    if ($labels) {
        $labelNames = @($labels | ForEach-Object { $_.name })
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

    # Also check labels for machine hints
    if (-not $machineOption) {
        # Check for machine-specific patterns in labels
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
    if ($labelNames -contains "claude-only") {
        $executionOption = $ExecutionOptions["Interactive"]
    }
    elseif ($labelNames -contains "roo-schedulable") {
        $executionOption = $ExecutionOptions["Scheduled"]
    }
    if ($hasClaudeOnly -and $hasRooSchedulable) {
        $executionOption = $ExecutionOptions["Both"]
    }

    # Set Status to Todo for new items
    $statusOption = $StatusOptions["Todo"]

    # Apply field updates
    $fieldsApplied = @()

    # Status → Todo
    if ($DryRun) {
        $fieldsApplied += "Status=Todo"
    }
    else {
        $cmd = "gh project item-edit --id `"$itemId`" --project-id `"$ProjectId`" --field-id `"$($FieldIds.Status)`" --single-select-option-id `"$statusOption`""
        $result = Invoke-GhSafe $cmd
        if ($null -ne $result) {
            $fieldsApplied += "Status=Todo"
        }
    }

    # Agent
    if ($agentOption) {
        if ($DryRun) {
            $fieldsApplied += "Agent=<detected>"
        }
        else {
            $cmd = "gh project item-edit --id `"$itemId`" --project-id `"$ProjectId`" --field-id `"$($FieldIds.Agent)`" --single-select-option-id `"$agentOption`""
            $result = Invoke-GhSafe $cmd
            if ($null -ne $result) {
                $agentName = $AgentOptions.GetEnumerator() | Where-Object { $_.Value -eq $agentOption } | Select-Object -First 1
                $fieldsApplied += "Agent=$($agentName.Key)"
            }
        }
    }

    # Machine
    if ($machineOption) {
        if ($DryRun) {
            $fieldsApplied += "Machine=<detected>"
        }
        else {
            $cmd = "gh project item-edit --id `"$itemId`" --project-id `"$ProjectId`" --field-id `"$($FieldIds.Machine)`" --single-select-option-id `"$machineOption`""
            $result = Invoke-GhSafe $cmd
            if ($null -ne $result) {
                $machineName = $MachineOptions.GetEnumerator() | Where-Object { $_.Value -eq $machineOption } | Select-Object -First 1
                $fieldsApplied += "Machine=$($machineName.Key)"
            }
        }
    }

    # Execution
    if ($executionOption) {
        if ($DryRun) {
            $fieldsApplied += "Execution=<detected>"
        }
        else {
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
}

Write-Host "`n  Fields set for $fieldsSetCount items"

# --- Final report ---

Write-Status "DONE"
Write-Host @"
  Mode:         $mode
  Issues in project before: $($issuesInProject.Count)
  Open issues total:        $($allIssues.Count)
  Missing (gap):            $($missingIssues.Count)
  Added:                    $addedCount
  Failed:                   $failedCount
  Fields set:               $fieldsSetCount
  Issues in project after:  $($issuesInProject.Count + $addedCount)
"@
