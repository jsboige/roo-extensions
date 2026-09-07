<#
.SYNOPSIS
    Detects duplicate tool_use blocks in Claude Code JSONL transcripts.

.DESCRIPTION
    Issue #3276 documented a fork transcript / re-emission bug where the same
    assistant message (same message.id) and the same tool_use block (same
    tool_use.id) appeared as two distinct transcript nodes sharing a parent/child
    relationship. Both nodes were executed by the runtime, producing duplicate
    side effects (e.g. two `gh issue create` calls for one intended publication).

    This script parses a Claude Code JSONL transcript, groups assistant messages
    by message.id, and reports any message.id that appears more than once with at
    least one matching tool_use.id in both copies. For each duplicate cluster it
    emits:
      - the duplicate message.id
      - the shared tool_use.id(s)
      - the tool_use name (Read, Bash, PowerShell, etc.)
      - timestamps of each occurrence
      - parentUuid chain (to confirm fork signature)
      - whether each node was executed (followed by a tool_result with the same
        tool_use.id)

    Detection is purely structural — no side effects, no mutations. The script is
    a forensic tool: it surfaces a fingerprint that lets an investigator
    confirm or refute the #3276 hypothesis on any given transcript.

.PARAMETER Path
    Path to a JSONL transcript file. Accepts a single file or an array of files.

.PARAMETER SessionId
    Optional sessionId filter — only messages matching the given session are
    analysed. Useful when a JSONL file accumulates multiple sessions.

.PARAMETER Cwd
    Optional cwd filter — only messages matching the given working directory are
    analysed. Useful when a JSONL file accumulates multiple workspaces.

.PARAMETER OutputFormat
    Output format. 'Object' returns PSCustomObjects (pipeline-friendly).
    'Json' emits a single JSON document. 'Summary' prints a human-readable
    summary table. Default: Object.

.PARAMETER IncludeExecutedOnly
    When set, only report duplicate clusters where every occurrence was actually
    executed (followed by a tool_result with the same tool_use.id). This is the
    "executed twice" fingerprint described in #3276. Default: true.

.PARAMETER PassThru
    When set with -OutputFormat Object, return the raw duplicate cluster objects
    without printing them to the host. Useful for piping to ConvertTo-Json.

.EXAMPLE
    pwsh -File scripts/transcript/Find-DuplicateToolUse.ps1 -Path transcripts/session.jsonl

    Scans the transcript and prints a summary table of any duplicate tool_use
    blocks.

.EXAMPLE
    pwsh -File scripts/transcript/Find-DuplicateToolUse.ps1 -Path transcripts/session.jsonl -OutputFormat Json | Out-File dup-report.json

    Writes the duplicate cluster report as JSON.

.EXAMPLE
    Get-ChildItem ~/.claude/projects/*/*.jsonl | ForEach-Object {
        & pwsh -File scripts/transcript/Find-DuplicateToolUse.ps1 -Path $_.FullName -OutputFormat Summary
    } | Tee-Object -FilePath duplicate-tool-use-report.txt

    Walks every JSONL transcript under every project directory and emits a single
    audit report.

.NOTES
    Issue #3276
    Requires PowerShell 5.1+ (no external dependencies).
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Path,

    [Parameter(Mandatory = $false)]
    [string]$SessionId,

    [Parameter(Mandatory = $false)]
    [string]$Cwd,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Object', 'Json', 'Summary')]
    [string]$OutputFormat = 'Object',

    [Parameter(Mandatory = $false)]
    [switch]$IncludeExecutedOnly = $true,

    [Parameter(Mandatory = $false)]
    [switch]$PassThru
)

# StrictMode is intentionally NOT enabled: this script operates on user-supplied
# JSONL transcripts where fields may be missing, null, or of unexpected shape.
# Defensive null/array checks throughout the body keep the audit reliable on
# real-world transcripts without the brittle failures StrictMode v3 introduces.
$ErrorActionPreference = 'Stop'

function Get-TranscriptLines {
    param ([string]$FilePath)

    if (-not (Test-Path -LiteralPath $FilePath)) {
        Write-Warning "Transcript file not found: $FilePath"
        return @()
    }

    $lines = @()
    Get-Content -LiteralPath $FilePath -Encoding UTF8 -ErrorAction Stop | ForEach-Object {
        $line = $_.Trim()
        if ([string]::IsNullOrWhiteSpace($line)) { return }
        try {
            $obj = $line | ConvertFrom-Json -ErrorAction Stop
            $lines += [PSCustomObject]@{
                LineNumber = $lines.Count + 1
                Raw = $obj
            }
        }
        catch {
            # Skip malformed JSONL lines silently — Claude Code transcripts are
            # well-formed but the script must not fail the entire audit on a
            # single corrupt line.
        }
    }
    return $lines
}

function Test-MessageMatchesFilter {
    param ($Message, [string]$SessionId, [string]$Cwd)

    if ($SessionId -and $Message.Raw.sessionId -ne $SessionId) { return $false }
    if ($Cwd -and $Message.Raw.cwd -ne $Cwd) { return $false }
    return $true
}

function Get-ToolUseBlocks {
    param ($Message)

    if ($Message.Raw.type -ne 'assistant') { return @() }
    if (-not $Message.Raw.message) { return @() }
    if ($null -eq $Message.Raw.message.content) { return @() }

    $local = @()
    foreach ($block in @($Message.Raw.message.content)) {
        if ($block.type -eq 'tool_use') {
            $local += [PSCustomObject]@{
                ToolUseId = $block.id
                ToolName = $block.name
                Input = $block.input
            }
        }
    }
    return @($local)
}

function Get-ToolResultBlocks {
    param ($Message)

    if ($Message.Raw.type -ne 'user') { return @() }
    if (-not $Message.Raw.message) { return @() }
    if ($null -eq $Message.Raw.message.content) { return @() }

    $local = @()
    foreach ($block in @($Message.Raw.message.content)) {
        if ($block.type -eq 'tool_result') {
            $local += [PSCustomObject]@{
                ToolUseId = $block.tool_use_id
                Content = $block.content
                IsError = $block.is_error
            }
        }
    }
    return @($local)
}

function Find-DuplicateClusters {
    param (
        [object[]]$Messages,
        [bool]$IncludeExecutedOnly
    )

    # Build index of tool_results by tool_use_id so we can detect "executed".
    $toolResults = @{}
    foreach ($msg in $Messages) {
        foreach ($tr in (Get-ToolResultBlocks -Message $msg)) {
            if (-not $toolResults.ContainsKey($tr.ToolUseId)) {
                $toolResults[$tr.ToolUseId] = @()
            }
            $toolResults[$tr.ToolUseId] += [PSCustomObject]@{
                LineNumber = $msg.LineNumber
                Timestamp = $msg.Raw.timestamp
                Uuid = $msg.Raw.uuid
                IsError = $tr.IsError
            }
        }
    }

    # Group assistant messages by message.id.
    $byMessageId = @{}
    foreach ($msg in $Messages) {
        $toolUseBlocks = Get-ToolUseBlocks -Message $msg
        if ($toolUseBlocks.Count -eq 0) { continue }

        $messageId = $msg.Raw.message.id
        if (-not $messageId) { continue }

        if (-not $byMessageId.ContainsKey($messageId)) {
            $byMessageId[$messageId] = @()
        }
        $byMessageId[$messageId] += [PSCustomObject]@{
            LineNumber = $msg.LineNumber
            Timestamp = $msg.Raw.timestamp
            Uuid = $msg.Raw.uuid
            ParentUuid = $msg.Raw.parentUuid
            ToolUseBlocks = $toolUseBlocks
            SessionId = $msg.Raw.sessionId
            Cwd = $msg.Raw.cwd
        }
    }

    $clusters = @()
    foreach ($kv in $byMessageId.GetEnumerator()) {
        if ($kv.Value.Count -le 1) { continue }

        # Same message.id appearing more than once — this is the #3276
        # fingerprint. Cross-check that at least one tool_use.id is shared
        # between copies.
        $allToolUseIds = @{}
        foreach ($copy in $kv.Value) {
            foreach ($block in $copy.ToolUseBlocks) {
                $allToolUseIds[$block.ToolUseId] = $true
            }
        }

        # For each tool_use block in the first copy, check whether the same id
        # appears in another copy.
        $sharedToolUses = @()
        $firstCopy = $kv.Value[0]
        foreach ($block in $firstCopy.ToolUseBlocks) {
            $occurrences = @()
            foreach ($copy in $kv.Value) {
                $match = $copy.ToolUseBlocks | Where-Object { $_.ToolUseId -eq $block.ToolUseId }
                if ($match) {
                    $occurrences += [PSCustomObject]@{
                        CopyIndex = [array]::IndexOf($kv.Value, $copy)
                        LineNumber = $copy.LineNumber
                        Timestamp = $copy.Timestamp
                        Uuid = $copy.Uuid
                        ParentUuid = $copy.ParentUuid
                        Executed = $toolResults.ContainsKey($block.ToolUseId)
                        ExecutionCount = if ($toolResults.ContainsKey($block.ToolUseId)) {
                            $toolResults[$block.ToolUseId].Count
                        } else { 0 }
                    }
                }
            }
            if ($occurrences.Count -gt 1) {
                $allExecuted = -not $IncludeExecutedOnly
                if ($IncludeExecutedOnly) {
                    $allExecuted = $true
                    foreach ($occ in $occurrences) {
                        if (-not $occ.Executed) { $allExecuted = $false; break }
                    }
                }
                if ($allExecuted) {
                    $sharedToolUses += [PSCustomObject]@{
                        ToolUseId = $block.ToolUseId
                        ToolName = $block.ToolName
                        Input = $block.Input
                        Occurrences = $occurrences
                    }
                }
            }
        }

        if ($sharedToolUses.Count -eq 0) { continue }

        $clusters += [PSCustomObject]@{
            MessageId = $kv.Key
            CopyCount = $kv.Value.Count
            SharedToolUses = $sharedToolUses
            FirstTimestamp = ($kv.Value | Sort-Object Timestamp | Select-Object -First 1).Timestamp
            LastTimestamp = ($kv.Value | Sort-Object Timestamp | Select-Object -Last 1).Timestamp
            SessionId = $firstCopy.SessionId
            Cwd = $firstCopy.Cwd
        }
    }

    return $clusters
}

# --- main ---

$allClusters = @()
foreach ($filePath in $Path) {
    $messages = Get-TranscriptLines -FilePath $filePath
    $filtered = @()
    foreach ($m in $messages) {
        if (Test-MessageMatchesFilter -Message $m -SessionId $SessionId -Cwd $Cwd) {
            $filtered += $m
        }
    }
    $fileClusters = Find-DuplicateClusters -Messages $filtered -IncludeExecutedOnly:$IncludeExecutedOnly
    foreach ($c in $fileClusters) {
        $allClusters += [PSCustomObject]@{
            SourceFile = $filePath
            MessageId = $c.MessageId
            CopyCount = $c.CopyCount
            SharedToolUses = $c.SharedToolUses
            FirstTimestamp = $c.FirstTimestamp
            LastTimestamp = $c.LastTimestamp
            SessionId = $c.SessionId
            Cwd = $c.Cwd
        }
    }
}

switch ($OutputFormat) {
    'Object' {
        if ($PassThru) {
            return $allClusters
        }
        $allClusters | Format-List
    }
    'Json' {
        $json = $allClusters | ConvertTo-Json -Depth 10
        if ($PassThru) {
            return $json
        }
        $json
    }
    'Summary' {
        if ($allClusters.Count -eq 0) {
            Write-Host "No duplicate tool_use clusters detected." -ForegroundColor Green
            if ($PassThru) { return @() }
            return
        }
        Write-Host "=== Duplicate tool_use clusters (#3276 fingerprint) ===" -ForegroundColor Yellow
        Write-Host ""
        foreach ($cluster in $allClusters) {
            Write-Host "SourceFile: $($cluster.SourceFile)" -ForegroundColor Cyan
            Write-Host "MessageId:  $($cluster.MessageId)"
            Write-Host "CopyCount:  $($cluster.CopyCount)"
            Write-Host "FirstTs:    $($cluster.FirstTimestamp)"
            Write-Host "LastTs:     $($cluster.LastTimestamp)"
            Write-Host "SessionId:  $($cluster.SessionId)"
            Write-Host "Cwd:        $($cluster.Cwd)"
            foreach ($stu in $cluster.SharedToolUses) {
                Write-Host "  ToolUseId: $($stu.ToolUseId)  Name: $($stu.ToolName)" -ForegroundColor Magenta
                foreach ($occ in $stu.Occurrences) {
                    Write-Host "    [$($occ.CopyIndex)] line=$($occ.LineNumber) ts=$($occ.Timestamp) executed=$($occ.Executed) executions=$($occ.ExecutionCount)"
                }
            }
            Write-Host ""
        }
        if ($PassThru) { return $allClusters }
    }
}
