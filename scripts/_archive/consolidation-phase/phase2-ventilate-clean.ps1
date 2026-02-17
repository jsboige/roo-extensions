# Phase 2: Ventilation des scripts racine - Version simplifiee
$ErrorActionPreference = "Stop"

Write-Host "=== Phase 2: Ventilation ===" -ForegroundColor Cyan

# Creer sous-repertoires manquants
New-Item -Path "scripts/diagnostic/hierarchy" -ItemType Directory -Force | Out-Null
New-Item -Path "scripts/setup" -ItemType Directory -Force | Out-Null

# Deplacer les fichiers par categorie
$categories = @{
    "encoding" = @("diagnostic-encodage-complet.ps1", "diagnostic-encoding-consolide.ps1", "test-encodage-utf8.ps1", "test-diagnostic-encoding.ps1", "test-emoji-encoding-reproduction.ps1", "test-emoji-fix-validation.ps1", "fix-emoji-encoding-issues.ps1", "check-bom-in-file.js", "test-bom-fix-validation.js", "test-bom-fix-validation.ps1")
    "git-workflow" = @("git-commit-phase.ps1", "git-commit-submodule.ps1", "git-safe-operations.ps1", "git-safety-check.ps1", "return-to-main-phase2-submodule.ps1", "return-to-main-submodule-simple.ps1", "cleanup-rollbacks.ps1")
    "diagnostic/hierarchy" = @("analyze-task-matching.js", "analyze-task-matching.ps1", "debug-hierarchy-matching.js", "debug-hierarchy-matching.mjs", "diagnose-parent-file.ps1", "extract-child-parent-snippets.ps1", "extract-new-task-tags-safe.ps1", "extract-parent-tail.ps1", "generate-hierarchy-tree.ps1")
    "testing" = @("test-jupyter-mcp-e2e.ps1", "test-playwright-mcp.ps1", "test-roo-state-manager-build.ps1", "roo-tests.ps1", "run-unit-tests-tools.ps1")
    "setup" = @("configure-vscode-pwsh.ps1", "setup-workspace.ps1", "setup-git-hooks.js", "pre-commit-hook.js")
    "mcp" = @("mcp-monitor.ps1", "validate-mcp-implementations.js")
    "roosync" = @("migrate-roosync-storage.ps1", "validate-roosync-identity-protection.ps1")
    "analysis" = @("analyze-commits.ps1", "analyze-complexity.js", "analyze-stashs.ps1", "backup-all-stashs.ps1", "extract-ui-snippets.ps1")
    "messaging" = @("ventilation-rapports.ps1", "ventilation-rapports-complement.ps1", "send-urgent-broadcast.ps1")
}

$totalMoved = 0
foreach ($cat in $categories.Keys) {
    $moved = 0
    foreach ($file in $categories[$cat]) {
        $src = "scripts/$file"
        if (Test-Path $src) {
            Move-Item -Path $src -Destination "scripts/$cat/$file" -Force
            $moved++
            $totalMoved++
        }
    }
    Write-Host "$cat : $moved deplaces" -ForegroundColor Cyan
}

Write-Host "Total deplaces : $totalMoved" -ForegroundColor Green
Write-Host "Phase 2 terminee" -ForegroundColor Green
