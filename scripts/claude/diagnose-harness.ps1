#!/usr/bin/env pwsh
# Diagnostic script for Claude Code harness token footprint
# Issue #1026 - Reduce harness footprint from ~114K to <60K tokens

$ErrorActionPreference = "Stop"

$repoRoot = "C:\dev\roo-extensions"
$globalClaude = "$env:USERPROFILE\.claude\CLAUDE.md"
$projectClaude = "$repoRoot\CLAUDE.md"
$worktreeClaude = "$repoRoot\.claude\worktrees\wt-worker-myia-po-2026-20260402-091632\CLAUDE.md"
$rulesDir = "$repoRoot\.claude\rules"
$docsDir = "$repoRoot\.claude\docs"

Write-Host "=== Claude Code Harness Token Footprint Diagnostic ===" -ForegroundColor Cyan
Write-Host ""

# Function to estimate tokens from character count
# Rough estimate: ~4 chars per token for English text, ~5 for French/code
function Estimate-Tokens {
    param([int]$CharCount)
    # Use 4.5 as average (mix of English, French, code, markdown)
    return [math]::Round($CharCount / 4.5)
}

# Function to analyze a file or directory
function Analyze-Path {
    param(
        [string]$Path,
        [string]$Label,
        [switch]$IsDirectory
    )

    if (-not (Test-Path $Path)) {
        return @{Label = $Label; Chars = 0; Tokens = 0; Lines = 0 }
    }

    if ($IsDirectory) {
        $files = Get-ChildItem -Path $Path -Filter "*.md" -File
        $totalChars = 0
        $totalLines = 0
        foreach ($file in $files) {
            $content = Get-Content $file.FullName -Raw
            $totalChars += $content.Length
            $totalLines += (Get-Content $file.FullName).Count
        }
        $fileCount = $files.Count
    } else {
        $content = Get-Content $Path -Raw -ErrorAction SilentlyContinue
        if ($null -eq $content) { $content = "" }
        $totalChars = $content.Length
        $totalLines = (Get-Content $Path).Count
        $fileCount = 1
    }

    return @{
        Label = $Label
        Chars = $totalChars
        Tokens = Estimate-Tokens $totalChars
        Lines = $totalLines
        Files = $fileCount
    }
}

# Analyze components
$results = @()

# Global CLAUDE.md
$results += Analyze-Path $globalClaude "Global CLAUDE.md (~/.claude/)"

# Project CLAUDE.md (repo root)
$results += Analyze-Path $projectClaude "Project CLAUDE.md (repo root)"

# Worktree CLAUDE.md (if different)
if (Test-Path $worktreeClaude) {
    $results += Analyze-Path $worktreeClaude "Worktree CLAUDE.md"
}

# Auto-loaded rules
$results += Analyze-Path $rulesDir "Auto-loaded rules (.claude/rules/)" -IsDirectory

# On-demand docs
$results += Analyze-Path $docsDir "On-demand docs (.claude/docs/)" -IsDirectory

# Display results
Write-Host "Component Breakdown:" -ForegroundColor Yellow
Write-Host ""

$totalTokens = 0
$totalChars = 0

foreach ($result in $results) {
    $fileInfo = if ($result.Files -gt 1) { "($($result.Files) files)" } else { "" }
    Write-Host "$($result.Label) $fileInfo" -ForegroundColor White
    Write-Host ("  Lines: {0:N0} | Chars: {1:N0} | Est. Tokens: {2:N0}" -f $result.Lines, $result.Chars, $result.Tokens) -ForegroundColor Gray
    Write-Host ""
    $totalTokens += $result.Tokens
    $totalChars += $result.Chars
}

Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
Write-Host ("Total Characters: {0:N0}" -f $totalChars) -ForegroundColor White
Write-Host ("Estimated Tokens (text content): {0:N0}" -f $totalTokens) -ForegroundColor White
Write-Host ""

# MCP tool schemas estimation
Write-Host "MCP Tool Schemas (estimated):" -ForegroundColor Yellow
Write-Host "  roo-state-manager: 34 tools x ~200 chars/tool = ~6.8K chars (~1.5K tokens)" -ForegroundColor Gray
Write-Host "  playwright: 22 tools x ~300 chars/tool = ~6.6K chars (~1.5K tokens)" -ForegroundColor Gray
Write-Host "  sk-agent: 7 tools x ~250 chars/tool = ~1.75K chars (~400 tokens)" -ForegroundColor Gray
Write-Host "  markitdown: 1 tool x ~150 chars = ~150 chars (~35 tokens)" -ForegroundColor Gray
Write-Host "  MCP schemas subtotal: ~15K chars (~3.5K tokens)" -ForegroundColor Gray
Write-Host ""

$grandTotalTokens = $totalTokens + 3500
Write-Host ("ESTIMATED TOTAL HARNESS: ~{0:N0} tokens" -f $grandTotalTokens) -ForegroundColor $(if ($grandTotalTokens -lt 60000) { "Green" } elseif ($grandTotalTokens -lt 100000) { "Yellow" } else { "Red" })
Write-Host ""

# Target analysis
$targetTokens = 60000
$reductionNeeded = $grandTotalTokens - $targetTokens
$pctReduction = [math]::Round(($reductionNeeded / $grandTotalTokens) * 100)

Write-Host "Target: <$targetTokens tokens" -ForegroundColor Cyan
if ($grandTotalTokens -gt $targetTokens) {
    Write-Host ("Reduction needed: ~{0:N0} tokens ({1}%)" -f $reductionNeeded, $pctReduction) -ForegroundColor Red
} else {
    Write-Host "Target met!" -ForegroundColor Green
}
Write-Host ""

# Reduction opportunities
Write-Host "REDUCTION OPPORTUNITIES:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Merge global CLAUDE.md into project CLAUDE.md" -ForegroundColor White
Write-Host "   - Remove duplication (~340 lines)" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Move non-critical rules to on-demand:" -ForegroundColor White
Write-Host "   - delegation.md (219 lines) - only needed for complex tasks" -ForegroundColor Gray
Write-Host "   - github-cli.md (166 lines) - only needed for gh operations" -ForegroundColor Gray
Write-Host "   - sddd-conversational-grounding.md (344 lines) - only for research" -ForegroundColor Gray
Write-Host "   - test-success-rates.md (120 lines) - only for testing" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Create scheduler-specific minimal profile:" -ForegroundColor White
Write-Host "   - Exclude playwright, markitdown MCP schemas (~3K tokens)" -ForegroundColor Gray
Write-Host "   - Use condensed CLAUDE.md (~50% reduction)" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Compress rule content:" -ForegroundColor White
Write-Host "   - Remove redundant examples" -ForegroundColor Gray
Write-Host "   - Use shorter descriptions" -ForegroundColor Gray
Write-Host "   - Consolidate related rules" -ForegroundColor Gray
