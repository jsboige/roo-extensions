#!/usr/bin/env pwsh
# Comprehensive analysis of Claude Code harness token footprint
# Issue #1026 - Reduce harness footprint

$ErrorActionPreference = "Stop"

Write-Host "=== COMPREHENSIVE HARNESS TOKEN ANALYSIS ===" -ForegroundColor Cyan
Write-Host ""

# Read actual files
$globalClaude = "$env:USERPROFILE\.claude\CLAUDE.md"
$projectClaude = "C:\dev\roo-extensions\CLAUDE.md"
$worktreeClaude = "C:\dev\roo-extensions\.claude\worktrees\wt-worker-myia-po-2026-20260402-091632\CLAUDE.md"
$rulesDir = "C:\dev\roo-extensions\.claude\rules"
$docsDir = "C:\dev\roo-extensions\.claude\docs"
$settingsFile = "C:\dev\roo-extensions\.claude\settings.json"

# Function to count tokens (rough estimate: 1 token ≈ 4 characters for mixed content)
function Get-TokenCount {
    param([string]$Content)
    if ([string]::IsNullOrEmpty($Content)) { return 0 }
    # Count actual tokens more accurately: split by common delimiters
    $words = $Content -split '\s+'
    $codeBlocks = $Content | Select-String -Pattern '```[\s\S]*?```' -AllMatches
    $codeChars = ($codeBlocks.Matches | ForEach-Object { $_.Value.Length }) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    $textChars = $Content.Length - $codeChars

    # Code: ~3 chars/token, Text: ~4 chars/token
    $codeTokens = [math]::Round($codeChars / 3)
    $textTokens = [math]::Round($textChars / 4)

    return $codeTokens + $textTokens
}

# Analyze components
$components = @()

# Global CLAUDE.md
if (Test-Path $globalClaude) {
    $content = Get-Content $globalClaude -Raw
    $components += @{
        Name = "Global CLAUDE.md"
        Path = $globalClaude
        Chars = $content.Length
        Tokens = Get-TokenCount $content
    }
}

# Project CLAUDE.md
if (Test-Path $projectClaude) {
    $content = Get-Content $projectClaude -Raw
    $components += @{
        Name = "Project CLAUDE.md"
        Path = $projectClaude
        Chars = $content.Length
        Tokens = Get-TokenCount $content
    }
}

# Worktree CLAUDE.md (if different from project)
if (Test-Path $worktreeClaude) {
    $content = Get-Content $worktreeClaude -Raw
    $components += @{
        Name = "Worktree CLAUDE.md"
        Path = $worktreeClaude
        Chars = $content.Length
        Tokens = Get-TokenCount $content
    }
}

# Auto-loaded rules
if (Test-Path $rulesDir) {
    $totalChars = 0
    $totalTokens = 0
    $fileCount = 0
    Get-ChildItem $rulesDir -Filter "*.md" | ForEach-Object {
        $content = Get-Content $_.FullName -Raw
        $totalChars += $content.Length
        $totalTokens += (Get-TokenCount $content)
        $fileCount++
    }
    $components += @{
        Name = "Auto-loaded rules ($fileCount files)"
        Path = $rulesDir
        Chars = $totalChars
        Tokens = $totalTokens
    }
}

# On-demand docs (for comparison)
if (Test-Path $docsDir) {
    $totalChars = 0
    $totalTokens = 0
    $fileCount = 0
    Get-ChildItem $docsDir -Filter "*.md" | ForEach-Object {
        $content = Get-Content $_.FullName -Raw
        $totalChars += $content.Length
        $totalTokens += (Get-TokenCount $content)
        $fileCount++
    }
    $components += @{
        Name = "On-demand docs ($fileCount files)"
        Path = $docsDir
        Chars = $totalChars
        Tokens = $totalTokens
    }
}

# Claude Code settings (if present)
if (Test-Path $settingsFile) {
    $content = Get-Content $settingsFile -Raw
    $components += @{
        Name = "Claude Code settings.json"
        Path = $settingsFile
        Chars = $content.Length
        Tokens = Get-TokenCount $content
    }
}

# Display breakdown
Write-Host "HARNESS COMPONENT BREAKDOWN:" -ForegroundColor Yellow
Write-Host ""

$totalChars = 0
$totalTokens = 0

foreach ($comp in $components) {
    Write-Host "$($comp.Name)" -ForegroundColor White
    Write-Host ("  Chars: {0:N0} | Tokens: {1:N0}" -f $comp.Chars, $comp.Tokens) -ForegroundColor Gray
    Write-Host ""
    $totalChars += $comp.Chars
    $totalTokens += $comp.Tokens
}

Write-Host "=== SUBTOTAL (documentation + settings) ===" -ForegroundColor Cyan
Write-Host ("Total Chars: {0:N0}" -f $totalChars) -ForegroundColor White
Write-Host ("Total Tokens: {0:N0}" -f $totalTokens) -ForegroundColor White
Write-Host ""

# MCP Tool Schemas (estimate based on actual tool counts)
Write-Host "MCP TOOL SCHEMAS:" -ForegroundColor Yellow
Write-Host ""

# Check for actual MCP schema files
$mcpSchemasPath = "C:\dev\roo-extensions\mcps\internal\servers\roo-state-manager\dist\mcp-schemas.json"
if (Test-Path $mcpSchemasPath) {
    $schemasContent = Get-Content $mcpSchemasPath -Raw
    $schemasTokens = Get-TokenCount $schemasContent
    Write-Host ("roo-state-manager schemas: {0:N0} chars, ~{1:N0} tokens" -f $schemasContent.Length, $schemasTokens) -ForegroundColor Gray
    $totalTokens += $schemasTokens
    $totalChars += $schemasContent.Length
} else {
    # Estimate based on tool descriptions
    $estimatedMcpTokens = 3500
    Write-Host "Estimated MCP schemas (roo-state-manager, playwright, sk-agent, etc.): ~$estimatedMcpTokens tokens" -ForegroundColor Gray
    $totalTokens += $estimatedMcpTokens
}

Write-Host ""

# System prompt (Claude Code native - cannot be measured)
Write-Host "NATIVE SYSTEM PROMPT:" -ForegroundColor Yellow
Write-Host "  Claude Code native system prompt: ~5-10K tokens (estimated, not measurable)" -ForegroundColor Gray
Write-Host ""

# Grand total
$nativePromptEstimate = 7500
$grandTotal = $totalTokens + $nativePromptEstimate

Write-Host "=== ESTIMATED GRAND TOTAL ===" -ForegroundColor Cyan
Write-Host ("Documentation + Settings + MCP Schemas: {0:N0} tokens" -f $totalTokens) -ForegroundColor White
Write-Host ("+ Native System Prompt (estimated): ~{0:N0} tokens" -f $nativePromptEstimate) -ForegroundColor Gray
Write-Host ("= ESTIMATED TOTAL: ~{0:N0} tokens" -f $grandTotal) -ForegroundColor $(if ($grandTotal -lt 30000) { "Green" } elseif ($grandTotal -lt 60000) { "Yellow" } else { "Red" })
Write-Host ""

# Analysis
Write-Host "ANALYSIS:" -ForegroundColor Yellow
Write-Host ""

if ($grandTotal -gt 60000) {
    Write-Host "Current harness EXCEEDS 60K token target." -ForegroundColor Red
    $reductionNeeded = $grandTotal - 60000
    Write-Host ("Reduction required: ~{0:N0} tokens ({1}%)" -f $reductionNeeded, ([math]::Round(($reductionNeeded / $grandTotal) * 100))) -ForegroundColor Red
} else {
    Write-Host "Current harness is UNDER 60K token target." -ForegroundColor Green
    Write-Host ("Margin: ~{0:N0} tokens" -f (60000 - $grandTotal)) -ForegroundColor Green
}
Write-Host ""

# Further optimization opportunities
Write-Host "FURTHER OPTIMIZATION OPPORTUNITIES (to reach <30K):" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Create scheduler-specific minimal harness:" -ForegroundColor White
Write-Host "   - Remove research-related rules (sddd, delegation, etc.)" -ForegroundColor Gray
Write-Host "   - Remove github-cli.md (not needed for build/test)" -ForegroundColor Gray
Write-Host "   - Remove test-success-rates.md (scheduler runs tests anyway)" -ForegroundColor Gray
Write-Host "   - Estimated savings: ~8K tokens" -ForegroundColor Gray
Write-Host ""

Write-Host "2. Condense CLAUDE.md:" -ForegroundColor White
Write-Host "   - Merge global + project, remove duplication" -ForegroundColor Gray
Write-Host "   - Remove verbose examples, keep only critical info" -ForegroundColor Gray
Write-Host "   - Estimated savings: ~5K tokens" -ForegroundColor Gray
Write-Host ""

Write-Host "3. Move non-critical rules to on-demand:" -ForegroundColor White
Write-Host "   - Keep only: tool-availability, validation, pr-mandatory, ci-guardrails" -ForegroundColor Gray
Write-Host "   - Move to docs: intercom-protocol, skepticism, sddd, worktree-cleanup" -ForegroundColor Gray
Write-Host "   - Estimated savings: ~10K tokens" -ForegroundColor Gray
Write-Host ""

Write-Host "4. Reduce MCP tool descriptions:" -ForegroundColor White
Write-Host "   - Shorten tool descriptions in schemas" -ForegroundColor Gray
Write-Host "   - Disable non-essential MCPs for schedulers (playwright, markitdown)" -ForegroundColor Gray
Write-Host "   - Estimated savings: ~2K tokens" -ForegroundColor Gray
Write-Host ""

$potentialSavings = 8000 + 5000 + 10000 + 2000
Write-Host ("POTENTIAL TOTAL SAVINGS: ~{0:N0} tokens" -f $potentialSavings) -ForegroundColor Green
Write-Host ("This would bring the harness to: ~{0:N0} tokens" -f ($grandTotal - $potentialSavings)) -ForegroundColor Green
