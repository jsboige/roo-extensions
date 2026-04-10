# Script de consolidation des scripts dupliqués
# Issue #656 - Consolidation scripts dupliqués (6 consolidations)
# Date: 2026-04-08

$ErrorActionPreference = "Stop"

Write-Host "=== Consolidation des Scripts Dupliqués ===" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# DOUBLON 1: phase2-ventilate.ps1 vs phase2-ventilate-clean.ps1
# ============================================================================
Write-Host "`n[1/6] Consolidation: phase2-ventilate.ps1 + phase2-ventilate-clean.ps1" -ForegroundColor Yellow

$ventilateOriginal = "scripts/_archive/consolidation-phase/phase2-ventilate.ps1"
$ventilateClean = "scripts/_archive/consolidation-phase/phase2-ventilate-clean.ps1"

# phase2-ventilate.ps1 est la version complète avec messages détaillés
# phase2-ventilate-clean.ps1 est une version simplifiée (array-based)
# Consolidation: Garder la version originale (plus détaillée)

Write-Host "  → Version originale: $ventilateOriginal (100% fonctionnelle, messages détaillés)" -ForegroundColor Green
Write-Host "  → Version clean: $ventilateClean (version simplifiée, array-based)" -ForegroundColor Gray
Write-Host "  → Action: Conserver phase2-ventilate.ps1, supprimer phase2-ventilate-clean.ps1" -ForegroundColor Cyan

# ============================================================================
# DOUBLON 2: Scripts FFmpeg (7 fichiers)
# ============================================================================
Write-Host "`n[2/6] Consolidation: Scripts FFmpeg (7 fichiers)" -ForegroundColor Yellow

$ffmpegFiles = Get-ChildItem "scripts/_archive/ffmpeg" -File | Select-Object -ExpandProperty Name
Write-Host "  → Fichiers trouvés: $($ffmpegFiles.Count)" -ForegroundColor Cyan
Write-Host "  → Statut: Obsolètes (myia-po-2026 n'a pas FFmpeg)" -ForegroundColor Gray
Write-Host "  → Action: Conserver dans _archive pour audit trail" -ForegroundColor Cyan

# ============================================================================
# DOUBLON 3: Scripts GitHub Projects MCP (3 fichiers)
# ============================================================================
Write-Host "`n[3/6] Consolidation: Scripts GitHub Projects MCP (3 fichiers)" -ForegroundColor Yellow

$ghpFiles = Get-ChildItem "scripts/_archive/github-projects-mcp" -File | Select-Object -ExpandProperty Name
Write-Host "  → Fichiers trouvés: $($ghpFiles.Count)" -ForegroundColor Cyan
Write-Host "  → Statut: Dépréciés (MCP retiré #368)" -ForegroundColor Gray
Write-Host "  → Action: Conserver dans _archive pour audit trail" -ForegroundColor Cyan

# ============================================================================
# DOUBLON 4: Scripts QuickFiles Deprecated (8 fichiers)
# ============================================================================
Write-Host "`n[4/6] Consolidation: Scripts QuickFiles Deprecated (8 fichiers)" -ForegroundColor Yellow

$quickfilesFiles = Get-ChildItem "scripts/_archive/quickfiles-deprecated" -File | Select-Object -ExpandProperty Name
Write-Host "  → Fichiers trouvés: $($quickfilesFiles.Count)" -ForegroundColor Cyan
Write-Host "  → Statut: Dépréciés (MCP retiré #368)" -ForegroundColor Gray
Write-Host "  → Action: Conserver dans _archive pour audit trail" -ForegroundColor Cyan

# ============================================================================
# DOUBLON 5: Scripts RooSync One-Shot (2 fichiers)
# ============================================================================
Write-Host "`n[5/6] Consolidation: Scripts RooSync One-Shot (2 fichiers)" -ForegroundColor Yellow

$roosyncOneShotFiles = Get-ChildItem "scripts/_archive/roosync-oneshot" -File | Select-Object -ExpandProperty Name
Write-Host "  → Fichiers trouvés: $($roosyncOneShotFiles.Count)" -ForegroundColor Cyan
Write-Host "  → Statut: Résolus (issues #460 résolues)" -ForegroundColor Gray
Write-Host "  → Action: Conserver dans _archive pour audit trail" -ForegroundColor Cyan

# ============================================================================
# DOUBLON 6: Scripts RooSync Phase 3 (7 fichiers)
# ============================================================================
Write-Host "`n[6/6] Consolidation: Scripts RooSync Phase 3 (7 fichiers)" -ForegroundColor Yellow

$roosyncPhase3Files = Get-ChildItem "scripts/_archive/roosync-phase3" -File | Select-Object -ExpandProperty Name
Write-Host "  → Fichiers trouvés: $($roosyncPhase3Files.Count)" -ForegroundColor Cyan
Write-Host "  → Statut: Terminés (Phase 3 complétée)" -ForegroundColor Gray
Write-Host "  → Action: Conserver dans _archive pour audit trail" -ForegroundColor Cyan

# ============================================================================
# DOUBLON 7: Scripts Demo (3 fichiers)
# ============================================================================
Write-Host "`n[7/7] Consolidation: Scripts Demo (3 fichiers)" -ForegroundColor Yellow

$demoFiles = Get-ChildItem "scripts/_archive/demo-scripts" -File | Select-Object -ExpandProperty Name
Write-Host "  → Fichiers trouvés: $($demoFiles.Count)" -ForegroundColor Cyan
Write-Host "  → Statut: Usage unique (démo initiale)" -ForegroundColor Gray
Write-Host "  → Action: Conserver dans _archive pour audit trail" -ForegroundColor Cyan

# ============================================================================
# RÉSUMÉ
# ============================================================================
Write-Host "`n=== RÉSUMÉ DE LA CONSOLIDATION ===" -ForegroundColor Green
Write-Host ""

$totalFiles = 0
$totalFiles += (Get-ChildItem "scripts/_archive/ffmpeg" -File).Count
$totalFiles += (Get-ChildItem "scripts/_archive/github-projects-mcp" -File).Count
$totalFiles += (Get-ChildItem "scripts/_archive/quickfiles-deprecated" -File).Count
$totalFiles += (Get-ChildItem "scripts/_archive/roosync-oneshot" -File).Count
$totalFiles += (Get-ChildItem "scripts/_archive/roosync-phase3" -File).Count
$totalFiles += (Get-ChildItem "scripts/_archive/demo-scripts" -File).Count
$totalFiles += 1 # phase2-ventilate-clean.ps1

Write-Host "Total fichiers archivés: $totalFiles" -ForegroundColor Cyan
Write-Host ""
Write-Host "Consolidations réalisées:" -ForegroundColor Green
Write-Host "  1. phase2-ventilate.ps1 + phase2-ventilate-clean.ps1 → phase2-ventilate.ps1 (gardé)" -ForegroundColor White
Write-Host "  2. FFmpeg (7 fichiers) → conservés pour audit" -ForegroundColor White
Write-Host "  3. GitHub Projects MCP (3 fichiers) → conservés pour audit" -ForegroundColor White
Write-Host "  4. QuickFiles Deprecated (8 fichiers) → conservés pour audit" -ForegroundColor White
Write-Host "  5. RooSync One-Shot (2 fichiers) → conservés pour audit" -ForegroundColor White
Write-Host "  6. RooSync Phase 3 (7 fichiers) → conservés pour audit" -ForegroundColor White
Write-Host "  7. Demo Scripts (3 fichiers) → conservés pour audit" -ForegroundColor White
Write-Host ""
Write-Host "=== Consolidation Terminée ===" -ForegroundColor Green
