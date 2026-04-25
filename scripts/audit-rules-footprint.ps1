# =================================================================================================
#
#   Audit .claude/rules/ footprint
#
#   Issue: #1606 Phase 1 (EPIC #1666)
#   Purpose: measure total byte/line/estimated-token cost of auto-loaded rules,
#            so consolidation decisions can be grounded in before/after numbers.
#
#   Output:
#     - Always: human-readable table on stdout
#     - If -OutFile supplied: markdown snapshot written to that path (for
#       docs/harness/reference/rules-footprint.md updates)
#
#   This script is read-only on the rules directory. Exit 0 always.
#
# =================================================================================================

[CmdletBinding()]
param(
    [string]$RulesDir = ".claude/rules",
    [string]$OutFile = "",
    [switch]$Quiet
)

function Write-Info {
    param([string]$Message)
    if (-not $Quiet) { Write-Host $Message }
}

if (-not (Test-Path $RulesDir)) {
    Write-Error "Rules dir not found: $RulesDir. Run from repo root."
    exit 2
}

# Force invariant culture so decimal output is "10.8" not "10,8" regardless of host locale.
$culture = [System.Globalization.CultureInfo]::InvariantCulture
function FmtKb([double]$bytes) { return [math]::Round($bytes / 1024, 2).ToString($culture) }

$files = Get-ChildItem -Path $RulesDir -Filter "*.md" -File | Sort-Object Name

$rows = @()
$totalBytes = 0
$totalLines = 0

foreach ($f in $files) {
    $raw = Get-Content -Path $f.FullName -Raw
    # UTF-8 byte count (source of truth for on-disk size)
    $bytes = [System.Text.Encoding]::UTF8.GetByteCount($raw)
    # Line count (don't count trailing empty line)
    $lines = ($raw -split "`n").Count
    # Rough token estimate: ~4 chars/token average for English/French mix
    $tokens = [math]::Ceiling($raw.Length / 4)

    $rows += [PSCustomObject]@{
        Name       = $f.Name
        Bytes      = $bytes
        KB         = FmtKb $bytes
        Lines      = $lines
        EstTokens  = $tokens
    }

    $totalBytes += $bytes
    $totalLines += $lines
}

$totalTokens = [math]::Ceiling($totalBytes / 4)
$rows = $rows | Sort-Object -Property Bytes -Descending

# ----- Print to stdout -----

Write-Info ""
Write-Info "# Rules Footprint Audit"
Write-Info ""
Write-Info ("Directory: {0}" -f (Resolve-Path $RulesDir).Path)
Write-Info ("Date: {0}" -f (Get-Date -Format "yyyy-MM-ddTHH:mmZ"))
Write-Info ""
Write-Info ("Total files : {0}" -f $files.Count)
Write-Info ("Total size  : {0} bytes ({1} KB)" -f $totalBytes, (FmtKb $totalBytes))
Write-Info ("Total lines : {0}" -f $totalLines)
Write-Info ("Est. tokens : ~{0}" -f $totalTokens)
Write-Info ""
Write-Info "Files (largest first):"
Write-Info ""
$rows | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Info $_.TrimEnd() }

# ----- Optional: write markdown snapshot -----

if ($OutFile) {
    $tableLines = @("| File | KB | Lines | Est. tokens |", "|------|---:|------:|------------:|")
    foreach ($r in $rows) {
        $tableLines += ("| {0} | {1} | {2} | {3} |" -f $r.Name, $r.KB, $r.Lines, $r.EstTokens)
    }

    $md = @"
# .claude/rules/ Footprint Snapshot

**Generated:** $(Get-Date -Format "yyyy-MM-ddTHH:mmZ")
**Script:** ``scripts/audit-rules-footprint.ps1``
**Issue:** #1606

## Totals

| Metric | Value |
|---|---|
| Files | $($files.Count) |
| Bytes | $totalBytes ($(FmtKb $totalBytes) KB) |
| Lines | $totalLines |
| Estimated tokens | ~$totalTokens |

## Per-file breakdown (largest first)

$($tableLines -join "`n")

## Notes

- Token estimate assumes ~4 chars/token (rough English/French mix). Real counts vary by tokenizer (GPT ≠ Claude ≠ GLM).
- This snapshot is a baseline for #1606 consolidation work. Re-run after every rule addition/merge to keep the footprint log current.
- Rules are auto-loaded on every Claude Code conversation start — every KB here is paid as context on every agent spawn.
"@

    # Resolve to absolute path if file exists, else treat as relative-to-cwd and let .NET handle it
    $resolvedOut = if (Test-Path $OutFile) {
        (Resolve-Path $OutFile).Path
    } else {
        [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $OutFile))
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($resolvedOut, $md, $utf8NoBom)
    Write-Info ""
    Write-Info ("Snapshot written to: {0}" -f $resolvedOut)
}

exit 0
