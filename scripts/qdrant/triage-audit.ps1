<#
.SYNOPSIS
    Qdrant semantic index triage audit for #1987 Phase 1.

.DESCRIPTION
    Scrolls through all points in roo_tasks_semantic_index, builds a per-task_id
    profile (point count, date range, source, workspace), applies scoring heuristics,
    and outputs a CSV for human review.

    Designed to run on ai-01 where Qdrant is localhost:6333.

.PARAMETER QdrantUrl
    Qdrant API URL. Default: http://localhost:6333

.PARAMETER ApiKey
    Qdrant API key. If not provided, reads from .env or environment.

.PARAMETER Collection
    Collection name. Default: roo_tasks_semantic_index

.PARAMETER OutputDir
    Directory for output CSV and report. Default: ./outputs/qdrant-triage

.PARAMETER ScrollBatchSize
    Number of points per scroll request. Default: 1000 (balance speed vs memory)

.PARAMETER SampleOnly
    Only process first N batches (for testing). Default: 0 (all)

.EXAMPLE
    .\triage-audit.ps1
    .\triage-audit.ps1 -SampleOnly 10  # First 10K points only (testing)

.NOTES
    Issue: https://github.com/jsboige/roo-extensions/issues/1987
    Part of Phase 1 — Audit. Does NOT modify any data.
#>

param(
    [string]$QdrantUrl = "http://localhost:6333",
    [string]$ApiKey = "",
    [string]$Collection = "roo_tasks_semantic_index",
    [string]$OutputDir = "./outputs/qdrant-triage",
    [int]$ScrollBatchSize = 1000,
    [int]$SampleOnly = 0
)

$ErrorActionPreference = "Continue"

# ========== RUNTIME NOTE ==========

if ($QdrantUrl -notmatch "localhost|127\.0\.0\.1") {
    Write-Host "WARNING: Running against remote Qdrant ($QdrantUrl). Scroll may timeout if optimizer is active." -ForegroundColor Yellow
    Write-Host "  For best results, run on ai-01 with -QdrantUrl http://localhost:6333" -ForegroundColor Yellow
    Write-Host ""
}

# ========== API KEY RESOLUTION ==========

if ([string]::IsNullOrEmpty($ApiKey)) {
    # Try env var
    $ApiKey = $env:QDRANT_API_KEY
    if ([string]::IsNullOrEmpty($ApiKey)) {
        # Try .env file in submodule
        $envFile = Join-Path $PSScriptRoot "../../mcps/internal/servers/roo-state-manager/.env"
        if (Test-Path $envFile) {
            $ApiKey = (Get-Content $envFile | Where-Object { $_ -match "^QDRANT_API_KEY=" }) -replace "^QDRANT_API_KEY=", ""
        }
    }
    if ([string]::IsNullOrEmpty($ApiKey)) {
        Write-Host "ERROR: No Qdrant API key found. Set QDRANT_API_KEY env var or pass -ApiKey." -ForegroundColor Red
        exit 1
    }
}

$headers = @{
    "api-key" = $ApiKey
    "Content-Type" = "application/json"
}

$baseUrl = "$QdrantUrl/collections/$Collection"

# ========== OUTPUT DIR ==========

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$dateStamp = Get-Date -Format "yyyyMMdd-HHmm"
$csvFile = Join-Path $OutputDir "triage-audit-$dateStamp.csv"
$reportFile = Join-Path $OutputDir "triage-report-$dateStamp.md"

# ========== COLLECTION INFO ==========

Write-Host "Fetching collection info..." -ForegroundColor Cyan

try {
    $infoResp = Invoke-RestMethod -Uri "$baseUrl" -Headers $headers -Method Get -TimeoutSec 30
    $info = $infoResp.result
    Write-Host "  Status: $($info.status) | Optimizer: $($info.optimizer_status)"
    Write-Host "  Points: $($info.points_count) | Segments: $($info.segments_count)"
    Write-Host "  Indexed vectors: $($info.indexed_vectors_count)"

    if ($info.status -ne "green") {
        Write-Host ""
        Write-Host "WARNING: Collection status is '$($info.status)', not 'green'." -ForegroundColor Yellow
        Write-Host "  Scroll operations may timeout during optimizer convergence." -ForegroundColor Yellow
        Write-Host "  Consider waiting for status=green before running full audit." -ForegroundColor Yellow
        Write-Host ""
    }
} catch {
    Write-Host "ERROR: Cannot reach Qdrant at $QdrantUrl : $_" -ForegroundColor Red
    exit 1
}

# ========== SCROLL ALL POINTS — BUILD TASK PROFILES ==========

Write-Host ""
Write-Host "Starting scroll audit (batch=$ScrollBatchSize)..." -ForegroundColor Cyan

$taskProfiles = @{}
$offset = $null
$batchNum = 0
$totalScrolled = 0
$startTime = Get-Date

while ($true) {
    $body = @{
        limit = $ScrollBatchSize
        with_payload = $true
        with_vector = $false
    }
    if ($null -ne $offset) {
        $body["offset"] = $offset
    }

    try {
        $resp = Invoke-RestMethod -Uri "$baseUrl/points/scroll" -Headers $headers -Method Post -Body ($body | ConvertTo-Json -Depth 5) -TimeoutSec 120
    } catch {
        Write-Host "  WARN: Scroll request failed at batch $batchNum : $_" -ForegroundColor Yellow
        Start-Sleep -Seconds 5
        continue  # Retry same offset
    }

    $points = $resp.result.points
    if ($points.Count -eq 0) {
        Write-Host "  No more points. Scroll complete." -ForegroundColor Green
        break
    }

    foreach ($pt in $points) {
        $pl = $pt.payload
        $taskId = if ($pl.task_id) { $pl.task_id } else { "UNKNOWN" }
        $source = if ($pl.source) { $pl.source } else { "unknown" }
        $ws = if ($pl.workspace_name) { $pl.workspace_name } elseif ($pl.workspace) { $pl.workspace } else { "" }
        $ts = if ($pl.timestamp) { $pl.timestamp } else { "" }
        $chunkType = if ($pl.chunk_type) { $pl.chunk_type } else { "" }

        if (-not $taskProfiles.ContainsKey($taskId)) {
            $taskProfiles[$taskId] = @{
                task_id = $taskId
                point_count = 0
                source = $source
                workspace = $ws
                first_ts = $ts
                last_ts = $ts
                chunk_types = @($chunkType)
            }
        }

        $prof = $taskProfiles[$taskId]
        $prof.point_count++

        # Track date range
        if (-not [string]::IsNullOrEmpty($ts)) {
            if ([string]::IsNullOrEmpty($prof.first_ts) -or ($ts -lt $prof.first_ts)) {
                $prof.first_ts = $ts
            }
            if ([string]::IsNullOrEmpty($prof.last_ts) -or ($ts -gt $prof.last_ts)) {
                $prof.last_ts = $ts
            }
        }
    }

    $totalScrolled += $points.Count
    $batchNum++

    # Progress every 10 batches
    if ($batchNum % 10 -eq 0) {
        $elapsed = ((Get-Date) - $startTime).TotalMinutes
        $rate = [math]::Round($totalScrolled / $elapsed, 0)
        Write-Host "  Batch $batchNum | $totalScrolled points | $($taskProfiles.Count) unique tasks | ${rate} pts/min"
    }

    # Next page offset
    $offset = $resp.result.next_page_offset
    if ($null -eq $offset) {
        Write-Host "  End of collection reached." -ForegroundColor Green
        break
    }

    # Sample mode
    if ($SampleOnly -gt 0 -and $batchNum -ge $SampleOnly) {
        Write-Host "  SampleOnly=$SampleOnly reached. Stopping." -ForegroundColor Yellow
        break
    }
}

$scrollDuration = ((Get-Date) - $startTime).TotalMinutes
Write-Host ""
Write-Host "Scroll complete: $totalScrolled points in $([math]::Round($scrollDuration, 1)) min ($($taskProfiles.Count) unique tasks)" -ForegroundColor Green

# ========== SCORING HEURISTICS ==========

Write-Host "Applying scoring heuristics..." -ForegroundColor Cyan

$now = Get-Date
$results = @()

foreach ($entry in $taskProfiles.GetEnumerator()) {
    $p = $entry.Value
    $score = 100  # Start at 100, subtract for risk factors
    $reasons = @()

    # Source-based scoring
    $src = $p.source

    # Point count — high count suggests potential bloat
    if ($p.point_count -gt 10000) {
        $score -= 30
        $reasons += "high_points($($p.point_count))"
    } elseif ($p.point_count -gt 5000) {
        $score -= 15
        $reasons += "many_points($($p.point_count))"
    }

    # Age — older tasks less valuable for active search
    if (-not [string]::IsNullOrEmpty($p.last_ts)) {
        try {
            $lastDate = [DateTime]::Parse($p.last_ts.Substring(0, [Math]::Min(19, $p.last_ts.Length)))
            $ageDays = ($now - $lastDate).TotalDays

            if ($ageDays -gt 180) {
                $score -= 25
                $reasons += "old($([math]::Round($ageDays))d)"
            } elseif ($ageDays -gt 90) {
                $score -= 10
                $reasons += "aging($([math]::Round($ageDays))d)"
            }
        } catch { }
    }

    # Workspace patterns — scheduled/worker tasks
    $wsLower = $p.workspace.ToLowerInvariant()
    $taskIdLower = $p.task_id.ToLowerInvariant()

    if ($taskIdLower -match "worker-|scheduled-|cron-|watcher-") {
        $score -= 20
        $reasons += "scheduled_pattern"
    }

    if ($taskIdLower -match "^claude-" -and $taskIdLower -match "worktree") {
        $score -= 10
        $reasons += "worktree_session"
    }

    # Claude Code duplicate pattern (same prefix, different UUID)
    if ($src -eq "claude-code" -or $taskIdLower -match "^claude-") {
        # These are often duplicated under multiple task_ids
        $score -= 5
        $reasons += "claude_code"
    }

    # Unknown workspace
    if ([string]::IsNullOrEmpty($p.workspace) -or $p.workspace -eq "UNKNOWN") {
        $score -= 15
        $reasons += "unknown_workspace"
    }

    # Decision
    $decision = if ($score -ge 70) { "KEEP" } elseif ($score -ge 40) { "REVIEW" } else { "DROP" }

    $results += [pscustomobject]@{
        task_id = $p.task_id
        points = $p.point_count
        source = $p.source
        workspace = $p.workspace
        first_ts = if ($p.first_ts -ne $null) { $p.first_ts.Substring(0, [Math]::Min(19, $p.first_ts.Length)) } else { "" }
        last_ts = if ($p.last_ts -ne $null) { $p.last_ts.Substring(0, [Math]::Min(19, $p.last_ts.Length)) } else { "" }
        score = $score
        decision = $decision
        reasons = ($reasons -join ";")
    }
}

# Sort by score (lowest first = biggest drop candidates)
$results = $results | Sort-Object score

# ========== CSV OUTPUT ==========

$results | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
Write-Host "CSV written: $csvFile ($($results.Count) tasks)" -ForegroundColor Green

# ========== REPORT ==========

$keepCount = ($results | Where-Object { $_.decision -eq "KEEP" }).Count
$reviewCount = ($results | Where-Object { $_.decision -eq "REVIEW" }).Count
$dropCount = ($results | Where-Object { $_.decision -eq "DROP" }).Count

$dropPoints = ($results | Where-Object { $_.decision -eq "DROP" } | Measure-Object -Property points -Sum).Sum
$reviewPoints = ($results | Where-Object { $_.decision -eq "REVIEW" } | Measure-Object -Property points -Sum).Sum
$totalPoints = ($results | Measure-Object -Property points -Sum).Sum

$dropPct = if ($totalPoints -gt 0) { [math]::Round($dropPoints / $totalPoints * 100, 1) } else { 0 }
$reviewPct = if ($totalPoints -gt 0) { [math]::Round($reviewPoints / $totalPoints * 100, 1) } else { 0 }

# Estimate GB freed (assuming ~12KB per point average based on 611GB / 53M points)
$gbPerPoint = 611 / 53.3  # ~11.5 KB per point
$dropGB = [math]::Round($dropPoints * $gbPerPoint / 1024, 1)
$reviewGB = [math]::Round($reviewPoints * $gbPerPoint / 1024, 1)

$report = @"
# Qdrant Triage Audit Report — #1987 Phase 1

**Date:** $(Get-Date -Format "yyyy-MM-dd HH:mm")
**Machine:** $env:COMPUTERNAME
**Collection:** $Collection
**Points scanned:** $totalScrolled / $($info.points_count)
**Unique tasks:** $($results.Count)
**Scroll duration:** $([math]::Round($scrollDuration, 1)) min

## Collection Status

| Metric | Value |
|--------|-------|
| Status | $($info.status) |
| Points | $($info.points_count) |
| Segments | $($info.segments_count) |
| Indexed vectors | $($info.indexed_vectors_count) |

## Triage Summary

| Decision | Tasks | Points | Est. GB | % of Total |
|----------|-------|--------|---------|------------|
| KEEP | $keepCount | $(($results | Where-Object { $_.decision -eq "KEEP" } | Measure-Object -Property points -Sum).Sum) | - | - |
| REVIEW | $reviewCount | $reviewPoints | ${reviewGB} GB | ${reviewPct}% |
| DROP | $dropCount | $dropPoints | ${dropGB} GB | ${dropPct}% |
| **Total** | **$($results.Count)** | **$totalPoints** | - | - |

## Top 20 DROP Candidates (by point count)

$(($results | Where-Object { $_.decision -eq "DROP" } | Sort-Object points -Descending | Select-Object -First 20 | Format-Table task_id, points, source, workspace, score, reasons -AutoSize | Out-String).Trim())

## Top 20 REVIEW Candidates (by point count)

$(($results | Where-Object { $_.decision -eq "REVIEW" } | Sort-Object points -Descending | Select-Object -First 20 | Format-Table task_id, points, source, workspace, score, reasons -AutoSize | Out-String).Trim())

## Source Distribution

$((($results | Group-Object source | Sort-Object Count -Descending | ForEach-Object { "| $($_.Name) | $($_.Count) | $(($_.Group | Measure-Object -Property points -Sum).Sum) |" }) -join "`n"))

| Source | Tasks | Points |
|--------|-------|--------|
$((($results | Group-Object source | Sort-Object Count -Descending | ForEach-Object { "| $($_.Name) | $($_.Count) | $(($_.Group | Measure-Object -Property points -Sum).Sum) |" }) -join "`n"))

## Scoring Heuristics Applied

| Factor | Penalty | Applied To |
|--------|---------|------------|
| >10K points per task | -30 | High volume tasks |
| >5K points per task | -15 | Moderate volume |
| >180 days old | -25 | Cold data |
| >90 days old | -10 | Aging data |
| Scheduled/worker pattern | -20 | cron/worker/watcher IDs |
| Worktree session | -10 | Ephemeral sessions |
| Claude Code source | -5 | Known duplicates (#1985) |
| Unknown workspace | -15 | Unattributed data |

**Decision thresholds:** KEEP (>=70), REVIEW (40-69), DROP (<40)

## Next Steps

1. Human review of this report (Phase 2 — ~15 min)
2. Validate DROP candidates
3. Execute deindexing (Phase 3) after approval
4. Force optimizer rebuild after deletion

---
Generated by triage-audit.ps1 (#1987 Phase 1)
"@

[System.IO.File]::WriteAllText($reportFile, $report, [System.Text.UTF8Encoding]::new($false))
Write-Host "Report written: $reportFile" -ForegroundColor Green
Write-Host ""
Write-Host "===== SUMMARY =====" -ForegroundColor Cyan
Write-Host "  KEEP:   $keepCount tasks"
Write-Host "  REVIEW: $reviewCount tasks ($reviewGB GB est.)"
Write-Host "  DROP:   $dropCount tasks ($dropGB GB est.)"
Write-Host "  Potential savings: $($dropGB) GB (DROP) + $($reviewGB) GB (REVIEW after validation)"
Write-Host "  CSV: $csvFile"
Write-Host "  Report: $reportFile"
