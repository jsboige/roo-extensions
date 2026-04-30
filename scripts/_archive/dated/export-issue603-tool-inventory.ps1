param(
	[string]$RepoRoot = "",
	[string]$OutputPath = ""
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
	$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\")).Path
}

$registryPath = Join-Path $RepoRoot "mcps/internal/servers/roo-state-manager/src/tools/registry.ts"
$roosyncIndexPath = Join-Path $RepoRoot "mcps/internal/servers/roo-state-manager/src/tools/roosync/index.ts"
$auditTestPath = Join-Path $RepoRoot "mcps/internal/servers/roo-state-manager/src/tools/__tests__/mcp-tools-audit.test.ts"

foreach ($p in @($registryPath, $roosyncIndexPath, $auditTestPath)) {
	if (-not (Test-Path $p)) {
		throw "Fichier introuvable: $p"
	}
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
	$OutputPath = Join-Path $RepoRoot "docs/audit/issue-603-tool-inventory-2026-03-29.md"
}

$registryContent = Get-Content -Path $registryPath -Raw
$roosyncIndexContent = Get-Content -Path $roosyncIndexPath -Raw
$auditContent = Get-Content -Path $auditTestPath -Raw

# 1) CallTool handlers roosync + export_config
$registryMatches = [regex]::Matches($registryContent, "case\s+'(roosync_[a-z0-9_]+|export_config)'")
$registryTools = @($registryMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)

# 2) Tools exposes via roosyncTools metadata list
$exposedMatches = [regex]::Matches($roosyncIndexContent, "\n\s*([a-zA-Z0-9_]+ToolMetadata)\s*,")
$exposedMetadata = @($exposedMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)

# 3) Tools listed in ALL_MCP_TOOLS test block
$allToolsMatch = [regex]::Match($auditContent, "const ALL_MCP_TOOLS = \[(?<block>.*?)\]\.sort\(\);", [System.Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $allToolsMatch.Success) {
	throw "Bloc ALL_MCP_TOOLS introuvable dans mcp-tools-audit.test.ts"
}

$testMatches = [regex]::Matches($allToolsMatch.Groups['block'].Value, "'([a-z0-9_]+)'")
$testTools = @($testMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)

$registrySet = [System.Collections.Generic.HashSet[string]]::new([string[]]$registryTools)
$testSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$testTools)

$registryNotInTests = @($registryTools | Where-Object { -not $testSet.Contains($_) })
$testNotInRegistry = @($testTools | Where-Object { $_ -like 'roosync_*' -and -not $registrySet.Contains($_) })

$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$md = @()
$md += "# Issue #603 - Tool Inventory Report"
$md += ""
$md += "Generated: $now"
$md += ""
$md += "## Scope"
$md += ""
$md += '- Registry handlers (`case ''roosync_*''` + `export_config`)'
$md += '- RooSync metadata list (`roosyncTools` in `roosync/index.ts`)'
$md += '- Audit test inventory (`ALL_MCP_TOOLS` in `mcp-tools-audit.test.ts`)'
$md += ""
$md += "## Summary"
$md += ""
$md += "- Registry roosync/export handlers: $($registryTools.Count)"
$md += "- Exposed roosync metadata entries: $($exposedMetadata.Count)"
$md += "- ALL_MCP_TOOLS entries: $($testTools.Count)"
$md += "- Registry handlers missing in ALL_MCP_TOOLS: $($registryNotInTests.Count)"
$md += "- Test roosync entries missing in registry handlers: $($testNotInRegistry.Count)"
$md += ""
$md += "## Registry Handlers"
$md += ""
foreach ($t in $registryTools) {
	$md += "- $t"
}

$md += ""
$md += "## Exposed RooSync Metadata Entries"
$md += ""
foreach ($m in $exposedMetadata) {
	$md += "- $m"
}

$md += ""
$md += "## Registry Handlers Missing In ALL_MCP_TOOLS"
$md += ""
if ($registryNotInTests.Count -eq 0) {
	$md += "- None"
} else {
	foreach ($t in $registryNotInTests) {
		$md += "- $t"
	}
}

$md += ""
$md += "## Test RooSync Entries Missing In Registry"
$md += ""
if ($testNotInRegistry.Count -eq 0) {
	$md += "- None"
} else {
	foreach ($t in $testNotInRegistry) {
		$md += "- $t"
	}
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllLines($OutputPath, $md, $utf8NoBom)

Write-Output "Report generated: $OutputPath"
Write-Output "Registry handlers: $($registryTools.Count)"
Write-Output "Exposed metadata entries: $($exposedMetadata.Count)"
Write-Output "ALL_MCP_TOOLS entries: $($testTools.Count)"
