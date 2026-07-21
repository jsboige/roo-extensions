# Script: scan-broken-links.ps1
# Description: Scan exhaustif des liens morts inter-docs (W1 #2878, audit read-only)
# Date: 2026-07-21
# Output: JSON structure to stdout for report generation
# Scope: tracked .md files in parent repo + mcps/internal submodule
# Note: uses .Replace()/.Split() (string methods) to avoid regex backslash-escaping issues

param(
    [string]$RepoRoot = ".",
    [switch]$Quiet = $false
)

$ErrorActionPreference = "Stop"

function Convert-Slashes([string]$p) { return $p.Replace('\','/') }

# 1. Collect tracked .md files (parent + submodule)
$parentMd = git -C $RepoRoot ls-files "*.md" 2>$null | Where-Object { $_ -notlike "roo-code/*" }
$submodMd = git -C "$RepoRoot/mcps/internal" ls-files "*.md" 2>$null | ForEach-Object { "mcps/internal/$_" }
$allMd = @($parentMd) + @($submodMd) | Sort-Object -Unique

if (-not $Quiet) {
    Write-Host "=== BROKEN-LINKS SCAN (W1 #2878, read-only) ===" -ForegroundColor Cyan
    Write-Host "Tracked .md files: parent=$($parentMd.Count) submodule=$($submodMd.Count) total=$($allMd.Count)" -ForegroundColor Gray
}

# Markdown link regex: [text](target)
$linkRegex = '\[([^\]]*)\]\(([^)\s]+)(?:\s+"[^"]*")?\)'

$results = [System.Collections.ArrayList]::new()
$stats = [ordered]@{
    totalFiles      = $allMd.Count
    totalLinks      = 0
    externalLinks   = 0
    internalLinks   = 0
    okLinks         = 0
    brokenPath      = 0
    brokenAnchor    = 0
    nonMd           = 0
    filesWithBroken = 0
}

foreach ($mdFile in $allMd) {
    $mdFileNorm = Convert-Slashes $mdFile
    $fullPath = Join-Path $RepoRoot ($mdFile.Replace('/','\'))
    if (-not (Test-Path $fullPath -PathType Leaf)) { continue }
    $content = Get-Content $fullPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $content) { continue }

    $fileDir = Split-Path $mdFileNorm -Parent
    $matches = [regex]::Matches($content, $linkRegex)
    foreach ($m in $matches) {
        $linkText = $m.Groups[1].Value
        $target = $m.Groups[2].Value.Trim()
        $stats.totalLinks++

        if ([string]::IsNullOrWhiteSpace($target)) { continue }

        # External links
        if ($target -match '^(https?|mailto|ftp|ftps|git|ssh):') {
            $stats.externalLinks++
            continue
        }

        # Anchor-only (#section)
        if ($target.StartsWith('#')) {
            $stats.internalLinks++
            continue
        }

        # Placeholder / illustrative-example exclusion (forward note W1 #2878 c.114/c.115)
        # Skip known documentation placeholder patterns that are not real links:
        #   - "path/to/...", "file.md#..." literal examples in methodology prose
        #   - the literal token "target" as a link destination
        # These are false-positives in audit/rule/skill docs, not broken navigation.
        # NOTE: do NOT exclude text==target cases — those can be REAL broken links
        # (e.g. [.clinerules](.clinerules) in upstream READMEs where the file is missing).
        if ($target -match '^(path/to/|file\.md#)') { continue }
        if ($target -eq 'target') { continue }

        # Separate path and anchor
        $anchor = $null
        $pathPart = $target
        if ($target.Contains('#')) {
            $idx = $target.IndexOf('#')
            $pathPart = $target.Substring(0, $idx)
            $anchor = $target.Substring($idx + 1)
        }
        if ($pathPart -eq '') {
            $stats.internalLinks++
            continue
        }

        $stats.internalLinks++

        $ext = [System.IO.Path]::GetExtension($pathPart).ToLower()
        if ($ext -ne '' -and $ext -ne '.md' -and $ext -ne '.markdown') {
            # non-md asset — verify existence
            $resolved = if ($fileDir) { "$fileDir/$pathPart" } else { $pathPart }
            $parts = (Convert-Slashes $resolved).Split('/')
            $stack = [System.Collections.ArrayList]::new()
            foreach ($p in $parts) {
                if ($p -eq '.' -or $p -eq '') { continue }
                if ($p -eq '..') { if ($stack.Count -gt 0) { $stack.RemoveAt($stack.Count - 1) }; continue }
                [void]$stack.Add($p)
            }
            $normalized = ($stack -join '/')
            $full = Join-Path $RepoRoot $normalized.Replace('/','\')
            if (-not (Test-Path $full)) {
                $stats.nonMd++
                [void]$results.Add([ordered]@{
                    file = $mdFileNorm
                    text = $linkText
                    target = $target
                    classification = 'BROKEN-ASSET'
                    resolved = $normalized
                })
            }
            continue
        }

        # .md target — resolve relative
        $resolved = if ($fileDir) { "$fileDir/$pathPart" } else { $pathPart }
        $parts = (Convert-Slashes $resolved).Split('/')
        $stack = [System.Collections.ArrayList]::new()
        foreach ($p in $parts) {
            if ($p -eq '.' -or $p -eq '') { continue }
            if ($p -eq '..') { if ($stack.Count -gt 0) { $stack.RemoveAt($stack.Count - 1) }; continue }
            [void]$stack.Add($p)
        }
        $normalized = ($stack -join '/')

        $fullCheck = Join-Path $RepoRoot $normalized.Replace('/','\')
        $exists = Test-Path $fullCheck
        if (-not $exists) {
            $stats.brokenPath++
            [void]$results.Add([ordered]@{
                file = $mdFileNorm
                text = $linkText
                target = $target
                classification = 'BROKEN-PATH'
                resolved = $normalized
            })
        } else {
            $stats.okLinks++
        }
    }
}

$stats.filesWithBroken = ($results | Group-Object file).Count

$output = [ordered]@{
    scanDate = "2026-07-21"
    scope = "parent repo + mcps/internal submodule, tracked .md only (git ls-files)"
    stats = $stats
    brokenLinks = $results
}

$json = $output | ConvertTo-Json -Depth 6
Write-Output $json

if (-not $Quiet) {
    Write-Host ""
    Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
    Write-Host "Files scanned       : $($stats.totalFiles)" -ForegroundColor Gray
    Write-Host "Total links         : $($stats.totalLinks)" -ForegroundColor Gray
    Write-Host "  External (skip)   : $($stats.externalLinks)" -ForegroundColor Gray
    Write-Host "  Internal          : $($stats.internalLinks)" -ForegroundColor Gray
    Write-Host "  OK                : $($stats.okLinks)" -ForegroundColor Gray
    Write-Host "  BROKEN-PATH       : $($stats.brokenPath)" -ForegroundColor $(if ($stats.brokenPath -gt 0) {'Red'} else {'Green'})
    Write-Host "  BROKEN-ASSET      : $($stats.nonMd)" -ForegroundColor $(if ($stats.nonMd -gt 0) {'Yellow'} else {'Green'})
    Write-Host "Files with broken   : $($stats.filesWithBroken)" -ForegroundColor Gray
}
