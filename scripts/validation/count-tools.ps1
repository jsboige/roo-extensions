<#
.SYNOPSIS
    Valide le decompte d'outils entre MCP server, wrapper Claude, et documentation.

.DESCRIPTION
    Analyse statiquement les fichiers source pour compter et comparer :
    1. ListTools dans registry.ts (outils exposes aux clients)
    2. ALLOWED_TOOLS dans mcp-wrapper.cjs (filtre Claude Code)
    3. CallTool cases dans registry.ts (handlers disponibles)
    4. roosyncTools dans roosync/index.ts (outils RooSync)
    5. CLAUDE.md (decomptes documentes)

    Signale les incoherences et les outils manquants.

.PARAMETER RepoRoot
    Racine du depot (auto-detecte si omis)

.PARAMETER Verbose
    Afficher les details de chaque outil

.PARAMETER Json
    Sortie en format JSON

.EXAMPLE
    .\count-tools.ps1
    .\count-tools.ps1 -Verbose
    .\count-tools.ps1 -Json
#>

param(
    [string]$RepoRoot = "",
    [switch]$Verbose,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot) {
    $RepoRoot = git rev-parse --show-toplevel 2>$null
    if (-not $RepoRoot) {
        Write-Error "Pas dans un depot Git."
        exit 1
    }
}

$mcpRoot = "$RepoRoot/mcps/internal/servers/roo-state-manager"

Write-Host "=== Tool Count Validator ===" -ForegroundColor Cyan
Write-Host "Repo: $RepoRoot"
Write-Host ""

$results = @{
    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    machine = $env:COMPUTERNAME
    errors = @()
    warnings = @()
}

# ============================================================
# 1. ALLOWED_TOOLS dans mcp-wrapper.cjs
# ============================================================

Write-Host "[1/5] Parsing mcp-wrapper.cjs (ALLOWED_TOOLS)..." -ForegroundColor Yellow

$wrapperPath = Join-Path $mcpRoot "mcp-wrapper.cjs"
if (-not (Test-Path $wrapperPath)) {
    Write-Error "mcp-wrapper.cjs introuvable: $wrapperPath"
    exit 1
}

$wrapperContent = Get-Content $wrapperPath -Raw
$allowedTools = @()

# Extraire les noms entre quotes dans le Set
$matches = [regex]::Matches($wrapperContent, "ALLOWED_TOOLS[\s\S]*?new Set\(\[([\s\S]*?)\]\)")
if ($matches.Count -gt 0) {
    $setContent = $matches[0].Groups[1].Value
    $toolMatches = [regex]::Matches($setContent, "'([^']+)'")
    foreach ($m in $toolMatches) {
        $allowedTools += $m.Groups[1].Value
    }
}

$results.wrapper = @{
    count = $allowedTools.Count
    tools = $allowedTools
}

Write-Host "  Wrapper Claude: $($allowedTools.Count) outils" -ForegroundColor $(if ($allowedTools.Count -eq 18) { "Green" } else { "Yellow" })
if ($Verbose) {
    foreach ($t in $allowedTools) { Write-Host "    - $t" }
}

# ============================================================
# 2. roosyncTools dans roosync/index.ts
# ============================================================

Write-Host "[2/5] Parsing roosync/index.ts (roosyncTools)..." -ForegroundColor Yellow

$indexPath = "$mcpRoot/src/tools/roosync/index.ts"
$roosyncToolNames = @()

if (Test-Path $indexPath) {
    $indexContent = Get-Content $indexPath -Raw

    # Compter les entries du tableau roosyncTools
    $rsMatches = [regex]::Matches($indexContent, "export const roosyncTools[\s\S]*?=\s*\[([\s\S]*?)\];")
    if ($rsMatches.Count -gt 0) {
        $arrayContent = $rsMatches[0].Groups[1].Value
        # Compter les lignes non-vide qui ne sont pas des commentaires
        $entries = $arrayContent -split "`n" | Where-Object {
            $_.Trim() -match '^\w' -and $_.Trim() -notmatch '^//' -and $_.Trim() -ne ''
        }
        $roosyncToolNames = $entries | ForEach-Object { $_.Trim().TrimEnd(',') }
    }
}

$results.roosyncTools = @{
    count = $roosyncToolNames.Count
    entries = $roosyncToolNames
}

Write-Host "  roosyncTools array: $($roosyncToolNames.Count) entries" -ForegroundColor $(if ($roosyncToolNames.Count -eq 19) { "Green" } else { "Yellow" })

# ============================================================
# 3. ListTools dans registry.ts
# ============================================================

Write-Host "[3/5] Parsing registry.ts (ListTools)..." -ForegroundColor Yellow

$registryPath = "$mcpRoot/src/tools/registry.ts"
$registryContent = Get-Content $registryPath -Raw

# Compter les entrees dans le tableau tools de ListTools
# On cherche entre "tools: [" et "] as any[]"
$listToolsMatch = [regex]::Match($registryContent, "tools:\s*\[([\s\S]*?)\]\s*as\s*any\[\]")
$inlineToolCount = 0
$hasRoosyncSpread = $false

if ($listToolsMatch.Success) {
    $toolsArrayContent = $listToolsMatch.Groups[1].Value
    $lines = $toolsArrayContent -split "`n"

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        # Ignorer commentaires et lignes vides
        if ($trimmed -match '^//' -or $trimmed -eq '' -or $trimmed -eq ',') { continue }

        # Detecter le spread roosyncTools
        if ($trimmed -match '\.\.\.toolExports\.roosyncTools') {
            $hasRoosyncSpread = $true
            continue
        }

        # Detecter les definitions d'outils (objet { name: ... } ou toolExports.xxx)
        if ($trimmed -match '^\{' -or $trimmed -match '^toolExports\.' -or $trimmed -match '^name:') {
            # C'est le debut d'un objet outil OU une reference directe
            # On verifie que c'est un outil et pas un champ d'un outil
            if ($trimmed -match '^\{$' -or $trimmed -match "^\{[^}]" -or $trimmed -match '^toolExports\.') {
                $inlineToolCount++
            }
        }
    }
}

$totalListTools = $inlineToolCount + $(if ($hasRoosyncSpread) { $roosyncToolNames.Count } else { 0 })

$results.listTools = @{
    inline = $inlineToolCount
    roosyncSpread = $hasRoosyncSpread
    roosyncCount = $roosyncToolNames.Count
    total = $totalListTools
}

Write-Host "  ListTools: $inlineToolCount inline + $($roosyncToolNames.Count) roosyncTools = $totalListTools total" -ForegroundColor $(if ($totalListTools -le 42) { "Green" } else { "Yellow" })

# ============================================================
# 4. CallTool cases dans registry.ts
# ============================================================

Write-Host "[4/5] Parsing registry.ts (CallTool cases)..." -ForegroundColor Yellow

$callToolCases = @()
# Capture case 'tool_name': (string literals)
$caseMatches = [regex]::Matches($registryContent, "case\s+'([^']+)':")
foreach ($m in $caseMatches) {
    $callToolCases += $m.Groups[1].Value
}
# Capture case toolExports.xxx.name: (dynamic names)
$dynCaseMatches = [regex]::Matches($registryContent, "case\s+toolExports\.(\w+)\.(?:name|definition\.name):")
foreach ($m in $dynCaseMatches) {
    $varName = $m.Groups[1].Value
    # Map variable names to known tool names
    $toolNameMap = @{
        'analyze_roosync_problems' = 'analyze_roosync_problems'
        'diagnose_env' = 'diagnose_env'
        'roosyncSummarizeTool' = 'roosync_summarize'
        'viewConversationTree' = 'view_conversation_tree'
        'readVscodeLogs' = 'read_vscode_logs'
        'manageMcpSettings' = 'manage_mcp_settings'
        'rebuildAndRestart' = 'rebuild_and_restart'
        'getMcpBestPractices' = 'get_mcp_best_practices'
        'viewTaskDetailsTool' = 'view_task_details'
        'getRawConversationTool' = 'get_raw_conversation'
        'exportConversationJsonTool' = 'export_conversation_json'
        'exportConversationCsvTool' = 'export_conversation_csv'
        'exportTasksXmlTool' = 'export_tasks_xml'
        'exportProjectXmlTool' = 'export_project_xml'
        'configureXmlExportTool' = 'configure_xml_export'
        'searchTasksByContentTool' = 'search_tasks_by_content'
        'exportDataTool' = 'export_data'
        'exportConfigTool' = 'export_config'
        'detectStorageTool' = 'detect_storage'
        'getStorageStatsTool' = 'get_storage_stats'
        'listConversationsTool' = 'list_conversations'
    }
    if ($toolNameMap.ContainsKey($varName)) {
        $callToolCases += $toolNameMap[$varName]
    } else {
        $callToolCases += $varName  # Fallback: use variable name as-is
    }
}

$results.callTool = @{
    count = $callToolCases.Count
    cases = $callToolCases
}

Write-Host "  CallTool: $($callToolCases.Count) case handlers" -ForegroundColor Cyan
if ($Verbose) {
    foreach ($c in $callToolCases) { Write-Host "    - $c" }
}

# ============================================================
# 5. CLAUDE.md documented counts
# ============================================================

Write-Host "[5/5] Parsing CLAUDE.md (documented counts)..." -ForegroundColor Yellow

$claudeMdPath = Join-Path $RepoRoot "CLAUDE.md"
$documentedWrapper = 0
if (Test-Path $claudeMdPath) {
    $claudeContent = Get-Content $claudeMdPath -Raw
    # Chercher "18 outils" ou "18 tools"
    $wrapperCountMatch = [regex]::Match($claudeContent, "(\d+)\s+outils?\s+RooSync")
    if ($wrapperCountMatch.Success) {
        $documentedWrapper = [int]$wrapperCountMatch.Groups[1].Value
    }
}

$results.documented = @{
    wrapper = $documentedWrapper
}

Write-Host "  CLAUDE.md: $documentedWrapper outils documentes" -ForegroundColor $(if ($documentedWrapper -eq $allowedTools.Count) { "Green" } else { "Yellow" })

# ============================================================
# Validation croisee
# ============================================================

Write-Host ""
Write-Host "=== Validation Croisee ===" -ForegroundColor Cyan

$hasErrors = $false

# Check 1: Tous les outils du wrapper sont dans ListTools
$wrapperNotInListTools = @()
foreach ($tool in $allowedTools) {
    $found = $false
    foreach ($c in $callToolCases) {
        if ($c -eq $tool) { $found = $true; break }
    }
    if (-not $found) {
        $wrapperNotInListTools += $tool
    }
}
if ($wrapperNotInListTools.Count -gt 0) {
    Write-Host "  ERREUR: Outils dans wrapper sans CallTool handler:" -ForegroundColor Red
    foreach ($t in $wrapperNotInListTools) { Write-Host "    - $t" -ForegroundColor Red }
    $results.errors += "Wrapper tools without CallTool: $($wrapperNotInListTools -join ', ')"
    $hasErrors = $true
} else {
    Write-Host "  OK: Tous les outils wrapper ont un CallTool handler" -ForegroundColor Green
}

# Check 2: Documentation coherente
if ($documentedWrapper -ne $allowedTools.Count -and $documentedWrapper -gt 0) {
    Write-Host "  WARN: CLAUDE.md dit $documentedWrapper outils, wrapper en a $($allowedTools.Count)" -ForegroundColor Yellow
    $results.warnings += "CLAUDE.md mismatch: documented=$documentedWrapper actual=$($allowedTools.Count)"
} elseif ($documentedWrapper -eq $allowedTools.Count) {
    Write-Host "  OK: CLAUDE.md coherent avec wrapper ($documentedWrapper)" -ForegroundColor Green
}

# Check 3: Outils deprecated encore dans ListTools
# (On ne peut pas facilement detecter ca statiquement sans executer le serveur)

# Resume
Write-Host ""
Write-Host "=== Resume ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "  MCP ListTools:       $totalListTools outils ($inlineToolCount inline + $($roosyncToolNames.Count) roosync)"
Write-Host "  Claude Wrapper:      $($allowedTools.Count) outils (filtre de $totalListTools)"
Write-Host "  CallTool handlers:   $($callToolCases.Count) cases (inclut backward compat)"
Write-Host "  roosyncTools array:  $($roosyncToolNames.Count) entries"
Write-Host "  CLAUDE.md documente: $documentedWrapper outils"
Write-Host ""

if ($hasErrors) {
    Write-Host "  STATUS: MISMATCH" -ForegroundColor Red
} else {
    Write-Host "  STATUS: OK" -ForegroundColor Green
}

# Sortie JSON si demande
if ($Json) {
    Write-Host ""
    Write-Host "=== JSON Output ===" -ForegroundColor DarkGray
    $results | ConvertTo-Json -Depth 5
}

exit $(if ($hasErrors) { 1 } else { 0 })
