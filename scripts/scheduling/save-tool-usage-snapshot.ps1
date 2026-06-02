# save-tool-usage-snapshot.ps1
# #2336 D4: Weekly tool_usage_stats snapshot via MCP save_snapshot action
# Invoked by scheduled task "roo-save-tool-usage-snapshot"

$ErrorActionPreference = "Stop"
$RepoRoot = "C:\dev\roo-extensions"
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$LogFile = Join-Path $RepoRoot "outputs\scheduling\logs\snapshot-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Ensure log directory exists
$logDir = Split-Path $LogFile -Parent
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Write-SnapLog($msg, $level = "INFO") {
    $entry = "[$Timestamp] [$level] $msg"
    Write-Host $entry
    Add-Content -Path $LogFile -Value $entry -ErrorAction SilentlyContinue
}

Write-SnapLog "=== Weekly Tool Usage Snapshot START ==="

# Write prompt to temp file for stdin pipe
$PromptFile = Join-Path $env:TEMP "snapshot-prompt-$(Get-Random).txt"
$promptContent = @"
Run this single MCP tool call and report the result:
roosync_indexing(action: "save_snapshot")

After the result, report:
1. Number of tools in the snapshot
2. File path where the snapshot was saved
3. Whether the operation succeeded or failed

This is a scheduled automated task. Do not modify any files.

=== AGENT STATUS ===
STATUS: success
REASON: [snapshot saved + tool count + file path]
===================
"@

[System.IO.File]::WriteAllText($PromptFile, $promptContent, [System.Text.UTF8Encoding]::new($false))

try {
    Push-Location $RepoRoot

    # Pipe prompt file to claude -p via stdin
    $output = Get-Content $PromptFile -Raw | & claude --dangerously-skip-permissions --model haiku --max-budget-usd 0.15 -p - --output-format stream-json --verbose 2>&1

    Pop-Location

    # Log output (stream-json lines)
    $output | ForEach-Object {
        $line = $_.ToString()
        Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue
    }

    Write-SnapLog "=== Weekly Tool Usage Snapshot END ==="
} catch {
    Pop-Location -ErrorAction SilentlyContinue
    Write-SnapLog "FATAL: $_" "ERROR"
    exit 1
} finally {
    Remove-Item $PromptFile -ErrorAction SilentlyContinue
}