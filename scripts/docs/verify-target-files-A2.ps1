# Vérification des fichiers cibles - Action A.2 Étape 2a/4
# Date: 2025-10-13
# But: Vérifier l'existence des fichiers cibles avant correction des liens

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host "=== VERIFICATION DES FICHIERS CIBLES - Action A.2 ===" -ForegroundColor Cyan
Write-Host "Timestamp: $timestamp`n" -ForegroundColor Gray

# Liste des fichiers cibles à vérifier
$targetFiles = @(
    "mcps/internal/docs/quickfiles-guide.md",
    "mcps/internal/docs/quickfiles-use-cases.md",
    "mcps/internal/docs/quickfiles-integration.md",
    "mcps/internal/docs/jinavigator-use-cases.md",
    "mcps/internal/docs/jupyter-mcp-use-cases.md",
    "mcps/internal/docs/jupyter-mcp-troubleshooting.md",
    "mcps/internal/docs/jupyter-mcp-offline-mode.md",
    "mcps/internal/docs/jupyter-mcp-connection-test.md",
    "mcps/internal/docs/architecture.md",
    "mcps/internal/docs/getting-started.md",
    "mcps/internal/docs/troubleshooting.md",
    "mcps/internal/CONTRIBUTING.md",
    "mcps/INSTALLATION.md",
    "mcps/TROUBLESHOOTING.md",
    "mcps/MANUAL_START.md",
    "mcps/OPTIMIZATIONS.md",
    "docs/missions/2025-01-13-synthese-reparations-mcp-sddd.md",
    "docs/configuration/configuration-mcp-roo.md"
)

$found = 0
$missing = @()

Write-Host "Vérification de $($targetFiles.Count) fichiers cibles..." -ForegroundColor Yellow

foreach ($file in $targetFiles) {
    $fullPath = Join-Path $PSScriptRoot "..\..\$file"
    if (Test-Path $fullPath) {
        Write-Host "  [OK] $file" -ForegroundColor Green
        $found++
    } else {
        Write-Host "  [MANQUANT] $file" -ForegroundColor Red
        $missing += $file
    }
}

Write-Host "`n=== RÉSUMÉ ===" -ForegroundColor Cyan
Write-Host "Fichiers trouvés: $found / $($targetFiles.Count)" -ForegroundColor $(if ($missing.Count -eq 0) { "Green" } else { "Yellow" })

if ($missing.Count -gt 0) {
    Write-Host "`nFichiers manquants ($($missing.Count)):" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host "`nATTENTION: Certains liens corrigés pointeront vers des fichiers inexistants!" -ForegroundColor Yellow
} else {
    Write-Host "`nTous les fichiers cibles existent. Prêt pour la correction." -ForegroundColor Green
}

Write-Host "`nTimestamp fin: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray