#!/usr/bin/env pwsh
# Phase 2: Ventilation des scripts racine vers sous-répertoires
# #481 Consolidation scripts/

$ErrorActionPreference = "Stop"

Write-Host "=== Phase 2: Ventilation Scripts ===" -ForegroundColor Cyan

# Créer les sous-répertoires manquants
$subdirs = @(
    "diagnostic/hierarchy",
    "setup"
)
foreach ($subdir in $subdirs) {
    $path = "scripts/$subdir"
    if (-not (Test-Path $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
        Write-Host "✅ Créé: $path" -ForegroundColor Green
    }
}

# 2.1 Encoding/UTF8 → scripts/encoding/
Write-Host "`n### 2.1 Encoding/UTF8 → scripts/encoding/`" -ForegroundColor Yellow
$encodingFiles = @(
    "diagnostic-encodage-complet.ps1",
    "diagnostic-encoding-consolide.ps1",
    "test-encodage-utf8.ps1",
    "test-diagnostic-encoding.ps1",
    "test-emoji-encoding-reproduction.ps1",
    "test-emoji-fix-validation.ps1",
    "fix-emoji-encoding-issues.ps1",
    "check-bom-in-file.js",
    "test-bom-fix-validation.js",
    "test-bom-fix-validation.ps1"
)
$movedCount = 0
foreach ($file in $encodingFiles) {
    $sourcePath = "scripts/$file"
    if (Test-Path $sourcePath) {
        Move-Item -Path $sourcePath -Destination "scripts/encoding/$file" -Force
        Write-Host "  ✓ $file" -ForegroundColor Green
        $movedCount++
    }
}
Write-Host "  → $movedCount / 10 fichiers déplacés" -ForegroundColor Cyan

# 2.2 Git Workflow → scripts/git-workflow/
Write-Host "`n### 2.2 Git Workflow → scripts/git-workflow/`" -ForegroundColor Yellow
$gitWorkflowFiles = @(
    "git-commit-phase.ps1",
    "git-commit-submodule.ps1",
    "git-safe-operations.ps1",
    "git-safety-check.ps1",
    "return-to-main-phase2-submodule.ps1",
    "return-to-main-submodule-simple.ps1",
    "cleanup-rollbacks.ps1"
)
$movedCount = 0
foreach ($file in $gitWorkflowFiles) {
    $sourcePath = "scripts/$file"
    if (Test-Path $sourcePath) {
        Move-Item -Path $sourcePath -Destination "scripts/git-workflow/$file" -Force
        Write-Host "  ✓ $file" -ForegroundColor Green
        $movedCount++
    }
}
Write-Host "  → $movedCount / 7 fichiers déplacés" -ForegroundColor Cyan

# 2.3 Hierarchy/Task Debug → scripts/diagnostic/hierarchy/
Write-Host "`n### 2.3 Hierarchy Debug → scripts/diagnostic/hierarchy/`" -ForegroundColor Yellow
$hierarchyFiles = @(
    "analyze-task-matching.js",
    "analyze-task-matching.ps1",
    "debug-hierarchy-matching.js",
    "debug-hierarchy-matching.mjs",
    "diagnose-parent-file.ps1",
    "extract-child-parent-snippets.ps1",
    "extract-new-task-tags-safe.ps1",
    "extract-parent-tail.ps1",
    "generate-hierarchy-tree.ps1"
)
$movedCount = 0
foreach ($file in $hierarchyFiles) {
    $sourcePath = "scripts/$file"
    if (Test-Path $sourcePath) {
        Move-Item -Path $sourcePath -Destination "scripts/diagnostic/hierarchy/$file" -Force
        Write-Host "  ✓ $file" -ForegroundColor Green
        $movedCount++
    }
}
Write-Host "  → $movedCount / 9 fichiers déplacés" -ForegroundColor Cyan

# 2.4 Tests → scripts/testing/
Write-Host "`n### 2.4 Tests → scripts/testing/`" -ForegroundColor Yellow
$testFiles = @(
    "test-jupyter-mcp-e2e.ps1",
    "test-playwright-mcp.ps1",
    "test-roo-state-manager-build.ps1",
    "roo-tests.ps1",
    "run-unit-tests-tools.ps1"
)
$movedCount = 0
foreach ($file in $testFiles) {
    $sourcePath = "scripts/$file"
    if (Test-Path $sourcePath) {
        Move-Item -Path $sourcePath -Destination "scripts/testing/$file" -Force
        Write-Host "  ✓ $file" -ForegroundColor Green
        $movedCount++
    }
}
Write-Host "  → $movedCount / 5 fichiers déplacés" -ForegroundColor Cyan

# 2.5 Setup/Config → scripts/setup/
Write-Host "`n### 2.5 Setup/Config → scripts/setup/`" -ForegroundColor Yellow
$setupFiles = @(
    "configure-vscode-pwsh.ps1",
    "setup-workspace.ps1",
    "setup-git-hooks.js",
    "pre-commit-hook.js"
)
$movedCount = 0
foreach ($file in $setupFiles) {
    $sourcePath = "scripts/$file"
    if (Test-Path $sourcePath) {
        Move-Item -Path $sourcePath -Destination "scripts/setup/$file" -Force
        Write-Host "  ✓ $file" -ForegroundColor Green
        $movedCount++
    }
}
Write-Host "  → $movedCount / 4 fichiers déplacés" -ForegroundColor Cyan

# 2.6 MCP → scripts/mcp/
Write-Host "`n### 2.6 MCP → scripts/mcp/`" -ForegroundColor Yellow
$mcpFiles = @(
    "mcp-monitor.ps1",
    "validate-mcp-implementations.js"
)
$movedCount = 0
foreach ($file in $mcpFiles) {
    $sourcePath = "scripts/$file"
    if (Test-Path $sourcePath) {
        Move-Item -Path $sourcePath -Destination "scripts/mcp/$file" -Force
        Write-Host "  ✓ $file" -ForegroundColor Green
        $movedCount++
    }
}
Write-Host "  → $movedCount / 2 fichiers déplacés" -ForegroundColor Cyan

# 2.7 RooSync → scripts/roosync/
Write-Host "`n### 2.7 RooSync → scripts/roosync/`" -ForegroundColor Yellow
$roosyncFiles = @(
    "migrate-roosync-storage.ps1",
    "validate-roosync-identity-protection.ps1"
)
$movedCount = 0
foreach ($file in $roosyncFiles) {
    $sourcePath = "scripts/$file"
    if (Test-Path $sourcePath) {
        Move-Item -Path $sourcePath -Destination "scripts/roosync/$file" -Force
        Write-Host "  ✓ $file" -ForegroundColor Green
        $movedCount++
    }
}
Write-Host "  → $movedCount / 2 fichiers déplacés" -ForegroundColor Cyan

# 2.8 Analysis → scripts/analysis/
Write-Host "`n### 2.8 Analysis → scripts/analysis/`" -ForegroundColor Yellow
$analysisFiles = @(
    "analyze-commits.ps1",
    "analyze-complexity.js",
    "analyze-stashs.ps1",
    "backup-all-stashs.ps1",
    "extract-ui-snippets.ps1"
)
$movedCount = 0
foreach ($file in $analysisFiles) {
    $sourcePath = "scripts/$file"
    if (Test-Path $sourcePath) {
        Move-Item -Path $sourcePath -Destination "scripts/analysis/$file" -Force
        Write-Host "  ✓ $file" -ForegroundColor Green
        $movedCount++
    }
}
Write-Host "  → $movedCount / 5 fichiers déplacés" -ForegroundColor Cyan

# 2.9 Ventilation → scripts/messaging/
Write-Host "`n### 2.9 Ventilation → scripts/messaging/`" -ForegroundColor Yellow
$messagingFiles = @(
    "ventilation-rapports.ps1",
    "ventilation-rapports-complement.ps1",
    "send-urgent-broadcast.ps1"
)
$movedCount = 0
foreach ($file in $messagingFiles) {
    $sourcePath = "scripts/$file"
    if (Test-Path $sourcePath) {
        Move-Item -Path $sourcePath -Destination "scripts/messaging/$file" -Force
        Write-Host "  ✓ $file" -ForegroundColor Green
        $movedCount++
    }
}
Write-Host "  → $movedCount / 3 fichiers déplacés" -ForegroundColor Cyan

# Compter les fichiers restants
$remainingFiles = Get-ChildItem -Path "scripts" -File -Filter "*.ps1" |
                     Where-Object { $_.Name -notin @("phase1-archive-obsolete.ps1", "phase1-cleanup.ps1") } |
                     Measure-Object |
                     Select-Object -ExpandProperty Count

Write-Host "`n=== Phase 2 Terminée ===" -ForegroundColor Green
Write-Host "Fichiers racine restants: $remainingFiles" -ForegroundColor Cyan
Write-Host "Fichiers racine restants attendus: 3 (phase1-*.ps1)" -ForegroundColor Cyan
Write-Host "Phase 2 terminee" -ForegroundColor Green