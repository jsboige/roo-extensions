<#
.SYNOPSIS
    Bounded tail scan over JSONL session traces.

.DESCRIPTION
    The executor pre-flight scans recent Claude Code JSONL traces for real OAuth
    expiry API errors (#3169). Reading those traces end to end is unbounded: on a
    seat carrying large CoursIA sessions the <48 h corpus reached 5.87 GiB
    (measured po-2028, 2026-11-23) and drove the whole pre-flight to ~35-40 min
    via a non-blocking advisory.

    The signal this scan looks for is a line-level marker, and the traces that
    carry it are the ones that were active recently, so reading the tail of each
    file is enough: a 2.6 GiB transcript does not need to be streamed end to end
    to find an error written in its last session. MaxBytes <= 0 forces the old
    whole-file scan (kept as an escape hatch, see EXECUTOR_PREFLIGHT_OAUTH_FULL_SCAN).

    A line cut at the tail boundary is dropped: half a line can lose one of the
    two fields a marker pattern requires, and a fragment is never evidence either
    way. Only the first (possibly partial) line is affected; JSONL lines past it
    are complete.
#>

function Test-JsonlTailForPattern {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Pattern,
        # 8 MiB by default: ~2 s over 47 traces, versus minutes on the full corpus.
        [int]$MaxBytes = 8388608
    )

    $file = Get-Item -LiteralPath $Path -ErrorAction Stop

    if ($MaxBytes -le 0 -or $file.Length -le $MaxBytes) {
        return [bool](Select-String -LiteralPath $file.FullName -Pattern $Pattern -List -ErrorAction SilentlyContinue)
    }

    # One byte more than the bound: it tells whether the window happens to land
    # on a line boundary, in which case no line must be dropped.
    $readBytes = $MaxBytes + 1

    $stream = [System.IO.File]::Open(
        $file.FullName,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::ReadWrite)
    try {
        [void]$stream.Seek(-$readBytes, [System.IO.SeekOrigin]::End)
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
        try {
            $tail = $reader.ReadToEnd()
        } finally {
            $reader.Dispose()
        }
    } finally {
        $stream.Dispose()
    }

    if ($tail.Length -gt 0 -and $tail[0] -eq "`n") {
        # The extra byte was the line feed that closes the previous line: the
        # window already starts on a line boundary, so nothing is partial.
        $tail = $tail.Substring(1)
    } else {
        # The window starts mid-line: that fragment is never evidence either way.
        $firstNewline = $tail.IndexOf("`n")
        if ($firstNewline -ge 0) {
            $tail = $tail.Substring($firstNewline + 1)
        } else {
            $tail = ''
        }
    }

    return [bool](Select-String -InputObject $tail -Pattern $Pattern -List -ErrorAction SilentlyContinue)
}
