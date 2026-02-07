<#
.SYNOPSIS
    Valide que les consolidations sont correctement implementees.

.DESCRIPTION
    Apres une consolidation (CONS-X), ce script verifie :
    1. Les outils deprecated ne sont plus dans ListTools
    2. Les CallTool handlers existent pour tous les outils ListTools
    3. Les tests couvrent les outils consolides
    4. Le build TypeScript passe
    5. Tous les tests passent

.PARAMETER RepoRoot
    Racine du depot (auto-detecte)

.PARAMETER SkipBuild
    Ne pas lancer le build TypeScript

.PARAMETER SkipTests
    Ne pas lancer les tests

.EXAMPLE
    .\validate-cons.ps1
    .\validate-cons.ps1 -SkipTests
#>

param(
    [string]$RepoRoot = "",
    [switch]$SkipBuild,
    [switch]$SkipTests
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

Write-Host "=== Consolidation Validator ===" -ForegroundColor Cyan
Write-Host ""

$errors = @()
$warnings = @()

# ============================================================
# 1. Verifier les outils deprecated
# ============================================================

Write-Host "[1/5] Verification outils deprecated..." -ForegroundColor Yellow

$registryPath = "$mcpRoot/src/tools/registry.ts"
$registryContent = Get-Content $registryPath -Raw

# Extraire la section ListTools
$listToolsMatch = [regex]::Match($registryContent, "tools:\s*\[([\s\S]*?)\]\s*as\s*any\[\]")

if ($listToolsMatch.Success) {
    $listToolsSection = $listToolsMatch.Groups[1].Value

    # Les noms d'outils qui ne devraient PLUS etre dans ListTools
    $deprecatedTools = @(
        'detect_storage', 'get_storage_stats', 'list_conversations',
        'build_skeleton_cache',
        'search_tasks_by_content', 'debug_analyze',
        'index_task_semantic', 'reset_qdrant_collection', 'rebuild_task_index_fixed',
        'diagnose_conversation_bom', 'repair_conversation_bom',
        'export_conversation_json', 'export_conversation_csv',
        'export_tasks_xml', 'export_conversation_xml', 'export_project_xml',
        'configure_xml_export',
        'generate_trace_summary', 'generate_cluster_summary', 'get_conversation_synthesis',
        'export_task_tree_markdown'
    )

    $exposedDeprecated = @()
    foreach ($tool in $deprecatedTools) {
        # Verifier si le nom apparait comme definition d'outil (pas en commentaire)
        $lines = $listToolsSection -split "`n"
        foreach ($line in $lines) {
            $trimmed = $line.Trim()
            if ($trimmed -match "^//" ) { continue }  # Ignorer commentaires
            if ($trimmed -match "'$tool'" -or $trimmed -match """$tool""" -or
                $trimmed -match "\.$tool\b" -and $trimmed -notmatch "//") {
                $exposedDeprecated += $tool
                break
            }
        }
    }

    if ($exposedDeprecated.Count -gt 0) {
        Write-Host "  ERREUR: Outils deprecated encore dans ListTools:" -ForegroundColor Red
        foreach ($t in $exposedDeprecated) { Write-Host "    - $t" -ForegroundColor Red }
        $errors += "Deprecated in ListTools: $($exposedDeprecated -join ', ')"
    } else {
        Write-Host "  OK: Aucun outil deprecated dans ListTools" -ForegroundColor Green
    }
}

# ============================================================
# 2. Coherence ListTools vs CallTool (approche hybride)
# ============================================================

Write-Host "[2/5] Coherence ListTools vs CallTool..." -ForegroundColor Yellow

# 2a. Compter les outils ListTools (meme approche que count-tools.ps1)
$inlineToolCount = 0
$hasRoosyncSpread = $false
$roosyncSpreadCount = 0

if ($listToolsMatch.Success) {
    $toolsArrayContent = $listToolsMatch.Groups[1].Value
    $lines = $toolsArrayContent -split "`n"

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^//' -or $trimmed -eq '' -or $trimmed -eq ',') { continue }

        if ($trimmed -match '\.\.\.toolExports\.roosyncTools') {
            $hasRoosyncSpread = $true
            continue
        }

        if ($trimmed -match '^\{$' -or $trimmed -match "^\{[^}]" -or $trimmed -match '^toolExports\.') {
            $inlineToolCount++
        }
    }

    # Compter roosyncTools entries
    if ($hasRoosyncSpread) {
        $roosyncIndexPath = "$mcpRoot/src/tools/roosync/index.ts"
        if (Test-Path $roosyncIndexPath) {
            $roosyncContent = Get-Content $roosyncIndexPath -Raw
            $rsMatch = [regex]::Match($roosyncContent, "export const roosyncTools[\s\S]*?=\s*\[([\s\S]*?)\];")
            if ($rsMatch.Success) {
                $entries = $rsMatch.Groups[1].Value -split "`n" | Where-Object {
                    $_.Trim() -match '^\w' -and $_.Trim() -notmatch '^//' -and $_.Trim() -ne ''
                }
                $roosyncSpreadCount = $entries.Count
            }
        }
    }

    $totalListTools = $inlineToolCount + $roosyncSpreadCount
    $expectedListTools = 39

    Write-Host "  ListTools: $totalListTools outils ($inlineToolCount inline + $roosyncSpreadCount roosync spread)" -ForegroundColor $(if ($totalListTools -eq $expectedListTools) { "Green" } else { "Yellow" })
    if ($totalListTools -ne $expectedListTools) {
        $warnings += "ListTools count $totalListTools != expected $expectedListTools"
    }
}

# 2b. Extraire les case handlers de CallTool (2 patterns)
$callToolCases = @()
# Pattern A: case 'tool_name': (string literal)
$caseMatches = [regex]::Matches($registryContent, "case\s+'([^']+)':")
foreach ($m in $caseMatches) {
    $callToolCases += $m.Groups[1].Value
}
# Pattern B: case toolExports.xxx.name: (dynamic reference)
# On resout le nom reel a partir du wrapper ALLOWED_TOOLS qui est la source de verite
$dynamicCaseMatches = [regex]::Matches($registryContent, "case\s+toolExports\.(\w+)\.name:")
$dynamicCaseCount = $dynamicCaseMatches.Count

# Mapper les references dynamiques vers les noms reels d'outils
$dynamicNameMap = @{
    'viewConversationTree' = 'view_conversation_tree'
    'readVscodeLogs' = 'read_vscode_logs'
    'manageMcpSettings' = 'manage_mcp_settings'
    'rebuildAndRestart' = 'rebuild_and_restart'
    'getMcpBestPractices' = 'get_mcp_best_practices'
    'rebuildTaskIndexFixed' = 'rebuild_task_index_fixed'
    'exportDataTool' = 'export_data'
    'exportConfigTool' = 'export_config'
    'roosyncSummarizeTool' = 'roosync_summarize'
    'exportConversationJsonTool' = 'export_conversation_json'
    'exportConversationCsvTool' = 'export_conversation_csv'
    'exportTasksXmlTool' = 'export_tasks_xml'
    'exportConversationXmlTool' = 'export_conversation_xml'
    'exportProjectXmlTool' = 'export_project_xml'
    'configureXmlExportTool' = 'configure_xml_export'
    'analyze_roosync_problems' = 'analyze_roosync_problems'
    'diagnose_env' = 'diagnose_env'
}
foreach ($m in $dynamicCaseMatches) {
    $ref = $m.Groups[1].Value
    if ($dynamicNameMap.ContainsKey($ref)) {
        $resolved = $dynamicNameMap[$ref]
        if ($resolved -notin $callToolCases) { $callToolCases += $resolved }
    } else {
        Write-Host "    WARN: Dynamic case non mappe: toolExports.$ref.name" -ForegroundColor Yellow
    }
}
Write-Host "  CallTool: $($callToolCases.Count) handlers ($($caseMatches.Count) literal + $dynamicCaseCount dynamic)" -ForegroundColor Cyan

# 2c. Extraire les ALLOWED_TOOLS du wrapper Claude (noms exacts)
$wrapperPath = "$mcpRoot/mcp-wrapper.cjs"
$wrapperTools = @()
if (Test-Path $wrapperPath) {
    $wrapperContent = Get-Content $wrapperPath -Raw
    $wMatches = [regex]::Matches($wrapperContent, "ALLOWED_TOOLS[\s\S]*?new Set\(\[([\s\S]*?)\]\)")
    if ($wMatches.Count -gt 0) {
        $setContent = $wMatches[0].Groups[1].Value
        $toolMatches = [regex]::Matches($setContent, "'([^']+)'")
        foreach ($m in $toolMatches) { $wrapperTools += $m.Groups[1].Value }
    }
}
Write-Host "  Wrapper Claude: $($wrapperTools.Count) outils" -ForegroundColor Cyan

# 2d. Verifier que TOUS les outils wrapper ont un CallTool handler
$missingHandlers = @()
foreach ($tool in $wrapperTools) {
    if ($tool -notin $callToolCases) {
        $missingHandlers += $tool
    }
}

if ($missingHandlers.Count -gt 0) {
    Write-Host "  ERREUR: Outils wrapper sans CallTool handler:" -ForegroundColor Red
    foreach ($t in $missingHandlers) { Write-Host "    - $t" -ForegroundColor Red }
    $errors += "Missing CallTool: $($missingHandlers -join ', ')"
} else {
    Write-Host "  OK: Tous les $($wrapperTools.Count) outils wrapper ont un handler CallTool" -ForegroundColor Green
}

# ============================================================
# 3. Couverture tests des outils consolides
# ============================================================

Write-Host "[3/5] Couverture tests outils consolides..." -ForegroundColor Yellow

$consolidatedTools = @(
    @{ Name = 'roosync_search'; TestPattern = '*search*test*' },
    @{ Name = 'roosync_indexing'; TestPattern = '*indexing*test*' },
    @{ Name = 'roosync_summarize'; TestPattern = '*summarize*test*' },
    @{ Name = 'task_browse'; TestPattern = '*browse*test*' },
    @{ Name = 'task_export'; TestPattern = '*export*test*' },
    @{ Name = 'storage_info'; TestPattern = '*storage*test*' },
    @{ Name = 'maintenance'; TestPattern = '*maintenance*test*' },
    @{ Name = 'export_data'; TestPattern = '*export*test*' },
    @{ Name = 'export_config'; TestPattern = '*export*test*' }
)

$testsDir = Join-Path $mcpRoot "tests"
$srcTestsDir = Join-Path $mcpRoot "src"

$missingTests = @()
$foundTests = @()

foreach ($tool in $consolidatedTools) {
    $testFiles = Get-ChildItem -Path $mcpRoot -Recurse -Filter "*.test.ts" |
        Where-Object { $_.Name -match $tool.Name -or $_.Name -match ($tool.Name -replace '_', '-') }

    if ($testFiles.Count -eq 0) {
        # Chercher plus largement
        $searchTerm = ($tool.Name -split '_')[-1]
        $testFiles = Get-ChildItem -Path $mcpRoot -Recurse -Filter "*$searchTerm*test*.ts"
    }

    if ($testFiles.Count -gt 0) {
        $foundTests += @{ Tool = $tool.Name; Files = $testFiles.Name -join ', ' }
    } else {
        $missingTests += $tool.Name
    }
}

if ($missingTests.Count -gt 0) {
    Write-Host "  WARN: Outils consolides sans tests trouves:" -ForegroundColor Yellow
    foreach ($t in $missingTests) { Write-Host "    - $t" -ForegroundColor Yellow }
    $warnings += "Missing tests: $($missingTests -join ', ')"
} else {
    Write-Host "  OK: Tous les outils consolides ont des tests" -ForegroundColor Green
}

if ($Verbose) {
    foreach ($t in $foundTests) {
        Write-Host "    $($t.Tool): $($t.Files)" -ForegroundColor DarkGray
    }
}

# ============================================================
# 4. Build TypeScript
# ============================================================

if (-not $SkipBuild) {
    Write-Host "[4/5] Build TypeScript..." -ForegroundColor Yellow
    Push-Location $mcpRoot
    try {
        $buildOutput = npx tsc --noEmit 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ERREUR: Build echoue" -ForegroundColor Red
            Write-Host $buildOutput -ForegroundColor Red
            $errors += "TypeScript build failed"
        } else {
            Write-Host "  OK: Build passe (0 erreurs)" -ForegroundColor Green
        }
    } finally {
        Pop-Location
    }
} else {
    Write-Host "[4/5] Build TypeScript... SKIP" -ForegroundColor DarkGray
}

# ============================================================
# 5. Tests unitaires
# ============================================================

if (-not $SkipTests) {
    Write-Host "[5/5] Tests unitaires..." -ForegroundColor Yellow
    Push-Location $mcpRoot
    try {
        $testOutput = npx vitest run --reporter=dot 2>&1
        $lastLine = ($testOutput | Select-Object -Last 5) -join " "

        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ERREUR: Tests echoues" -ForegroundColor Red
            $errors += "Tests failed"
        } else {
            # Extraire le nombre de tests passes
            $passMatch = [regex]::Match($lastLine, "(\d+)\s+passed")
            $failMatch = [regex]::Match($lastLine, "(\d+)\s+failed")
            $passed = if ($passMatch.Success) { $passMatch.Groups[1].Value } else { "?" }
            $failed = if ($failMatch.Success) { $failMatch.Groups[1].Value } else { "0" }
            Write-Host "  OK: $passed tests passes, $failed echoues" -ForegroundColor Green
        }
    } finally {
        Pop-Location
    }
} else {
    Write-Host "[5/5] Tests unitaires... SKIP" -ForegroundColor DarkGray
}

# ============================================================
# Resume final
# ============================================================

Write-Host ""
Write-Host "=== Resume ===" -ForegroundColor Cyan
Write-Host ""

if ($errors.Count -gt 0) {
    Write-Host "  ERREURS ($($errors.Count)):" -ForegroundColor Red
    foreach ($e in $errors) { Write-Host "    - $e" -ForegroundColor Red }
}

if ($warnings.Count -gt 0) {
    Write-Host "  WARNINGS ($($warnings.Count)):" -ForegroundColor Yellow
    foreach ($w in $warnings) { Write-Host "    - $w" -ForegroundColor Yellow }
}

if ($errors.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host "  TOUT EST OK" -ForegroundColor Green
}

Write-Host ""
exit $(if ($errors.Count -gt 0) { 1 } else { 0 })
