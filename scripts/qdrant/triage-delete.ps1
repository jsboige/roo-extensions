<#
.SYNOPSIS
    Phase 3 — Execute Qdrant point deletion for triage audit (#1987).

.DESCRIPTION
    Reads the CSV from Phase 1 audit, deletes points for DROP-decision tasks.
    Default mode is DRY-RUN (no actual deletion).

.PARAMETER CsvFile
    Path to triage CSV from Phase 1. Required.

.PARAMETER QdrantUrl
    Qdrant API URL. Default: http://localhost:6333

.PARAMETER ApiKey
    Qdrant API key. Resolved from env/.env if not provided.

.PARAMETER Collection
    Collection name. Default: roo_tasks_semantic_index

.PARAMETER Decision
    Which decisions to process: DROP, REVIEW, or BOTH. Default: DROP

.PARAMETER DryRun
    If set (default), only simulate deletions. Remove flag to actually delete.

.PARAMETER BatchSize
    Number of task_ids per delete request. Default: 10

.PARAMETER MaxDeletions
    Safety cap. Stop after N task_ids processed. Default: 500.

.EXAMPLE
    .\triage-delete.ps1 -CsvFile ./outputs/qdrant-triage/triage-audit-20260508.csv
    .\triage-delete.ps1 -CsvFile ./outputs/qdrant-triage/triage-audit-20260508.csv -DryRun:$false

.NOTES
    REQUIRES HUMAN APPROVAL before running without -DryRun.
    Issue: https://github.com/jsboige/roo-extensions/issues/1987
    Phase 3 — Execute. MODIFIES data. Always run dry-run first.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$CsvFile,
    [string]$QdrantUrl = "http://localhost:6333",
    [string]$ApiKey = "",
    [string]$Collection = "roo_tasks_semantic_index",
    [ValidateSet("DROP","REVIEW","BOTH")]
    [string]$Decision = "DROP",
    [switch]$DryRun = $true,
    [int]$BatchSize = 10,
    [int]$MaxDeletions = 500
)

$ErrorActionPreference = "Stop"

# ========== API KEY ==========

if ([string]::IsNullOrEmpty($ApiKey)) {
    $ApiKey = $env:QDRANT_API_KEY
    if ([string]::IsNullOrEmpty($ApiKey)) {
        $envFile = Join-Path $PSScriptRoot "../../mcps/internal/servers/roo-state-manager/.env"
        if (Test-Path $envFile) {
            $ApiKey = (Get-Content $envFile | Where-Object { $_ -match "^QDRANT_API_KEY=" }) -replace "^QDRANT_API_KEY=", ""
        }
    }
}

$headers = @{
    "api-key" = $ApiKey
    "Content-Type" = "application/json"
}
$baseUrl = "$QdrantUrl/collections/$Collection"

# ========== LOAD CSV ==========

if (-not (Test-Path $CsvFile)) {
    Write-Host "ERROR: CSV not found: $CsvFile" -ForegroundColor Red
    exit 1
}

$rows = Import-Csv $CsvFile -Encoding UTF8
Write-Host "Loaded $($rows.Count) tasks from $CsvFile" -ForegroundColor Cyan

# Filter by decision
$targets = switch ($Decision) {
    "DROP"   { $rows | Where-Object { $_.decision -eq "DROP" } }
    "REVIEW" { $rows | Where-Object { $_.decision -eq "REVIEW" } }
    "BOTH"   { $rows | Where-Object { $_.decision -in @("DROP", "REVIEW") } }
}

Write-Host "  Filtered: $($targets.Count) tasks with decision=$Decision" -ForegroundColor Cyan

if ($targets.Count -eq 0) {
    Write-Host "No tasks to process. Exiting." -ForegroundColor Yellow
    exit 0
}

$totalPoints = ($targets | Measure-Object -Property points -Sum).Sum
$gbEstimate = [math]::Round($totalPoints * (611 / 53.3) / 1024, 1)
Write-Host "  Total points to delete: $totalPoints (~$gbEstimate GB estimated)" -ForegroundColor Cyan

# ========== SAFETY CONFIRMATION ==========

if (-not $DryRun) {
    Write-Host ""
    Write-Host "!!! LIVE MODE — WILL DELETE DATA !!!" -ForegroundColor Red
    Write-Host "  About to delete $totalPoints points ($($targets.Count) tasks, ~$gbEstimate GB)" -ForegroundColor Red
    Write-Host "  Press Ctrl+C within 10 seconds to cancel..." -ForegroundColor Red
    Start-Sleep -Seconds 10
}

# ========== EXECUTE DELETIONS ==========

$deleted = 0
$deletedPoints = 0
$failed = 0
$batch = @()
$batchPoints = 0

foreach ($task in $targets) {
    if ($deleted -ge $MaxDeletions) {
        Write-Host "  MaxDeletions cap ($MaxDeletions) reached. Stopping." -ForegroundColor Yellow
        break
    }

    $batch += $task.task_id
    $batchPoints += [int]$task.points

    if ($batch.Count -ge $BatchSize -or $deleted + $batch.Count -ge $targets.Count) {
        # Build filter: match any of the task_ids in this batch
        $shouldConditions = @()
        foreach ($tid in $batch) {
            $shouldConditions += @{ match = @{ key = "task_id"; value = $tid } }
        }

        $deleteBody = @{
            filter = @{
                should = $shouldConditions
            }
        } | ConvertTo-Json -Depth 5

        if ($DryRun) {
            Write-Host "  [DRYRUN] Would delete $($batch.Count) tasks ($batchPoints points): $($batch[0])..."
        } else {
            try {
                $resp = Invoke-RestMethod -Uri "$baseUrl/points/delete" -Headers $headers -Method Post -Body $deleteBody -TimeoutSec 120
                $ops = $resp.result.operation_id
                Write-Host "  [LIVE] Deleted $($batch.Count) tasks ($batchPoints points) op=$ops" -ForegroundColor Green
            } catch {
                Write-Host "  [ERROR] Failed to delete batch: $_" -ForegroundColor Red
                $failed += $batch.Count
            }
        }

        $deleted += $batch.Count
        $deletedPoints += $batchPoints
        $batch = @()
        $batchPoints = 0

        # Rate limit: pause between batches
        if (-not $DryRun) {
            Start-Sleep -Milliseconds 500
        }
    }
}

# ========== SUMMARY ==========

Write-Host ""
Write-Host "===== DELETION SUMMARY =====" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "  Mode: DRY-RUN (no data modified)"
} else {
    Write-Host "  Mode: LIVE" -ForegroundColor Red
}
Write-Host "  Tasks processed: $deleted"
Write-Host "  Points affected: $deletedPoints (~$([math]::Round($deletedPoints * (611 / 53.3) / 1024, 1)) GB)"
if ($failed -gt 0) {
    Write-Host "  Failed: $failed" -ForegroundColor Red
}

if (-not $DryRun -and $deleted -gt 0) {
    Write-Host ""
    Write-Host "  IMPORTANT: Force optimizer rebuild to reclaim disk:" -ForegroundColor Yellow
    Write-Host "  curl -X POST $baseUrl/indexes -H 'api-key: ...' -d '{\"wait\":true}'" -ForegroundColor Yellow
}
