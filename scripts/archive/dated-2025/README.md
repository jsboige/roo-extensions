# Scripts Datés - Archive 2025

**Date d'archivage:** 2026-03-14
**Archivé par:** myia-po-2024 (Claude Code executor)

## Scripts Archivés

Ce dossier contient des scripts PowerShell datés (octobre-novembre 2025) qui ont été déplacés hors du dossier `scripts/` principal pour éviter la confusion et réduire le bruit.

### Liste des scripts (17 fichiers)

| Script | Date | Purpose |
|--------|------|---------|
| `22B-execute-mcp-cleanup-20251024.ps1` | 2025-10-24 | MCP cleanup execution |
| `22B-inventory-mcp-cleanup-20251024.ps1` | 2025-10-24 | MCP cleanup inventory |
| `capture-phase3-logs-20251022.ps1` | 2025-10-22 | Phase 3 logs capture |
| `check-skeleton-file-20251024.ps1` | 2025-10-24 | Skeleton file verification |
| `debug-mcp-exports-20251016-v2.ps1` | 2025-10-16 | MCP exports debug (v2) |
| `debug-mcp-exports-20251016.ps1` | 2025-10-16 | MCP exports debug |
| `debug-phase3-comprehensive-20251023.ps1` | 2025-10-23 | Phase 3 comprehensive debug |
| `fix-and-retest-20251022.ps1` | 2025-10-22 | Fix and retest |
| `force-recompile-and-verify-20251022.ps1` | 2025-10-22 | Force recompilation verification |
| `investigate-phase3-bug-20251022.ps1` | 2025-10-22 | Phase 3 bug investigation |
| `list-task-dirs-20251025.ps1` | 2025-10-25 | Task directory listing |
| `locate-child-skeleton-20251022.ps1` | 2025-10-22 | Child skeleton location |
| `test-phase3-diagnostic-20251023.ps1` | 2025-10-23 | Phase 3 diagnostic test |
| `test-skeleton-hierarchy-20251022.ps1` | 2025-10-22 | Skeleton hierarchy test |
| `validate-all-tests-20251018.ps1` | 2025-10-18 | All tests validation |
| `validation-post-sddd-20251007.ps1` | 2025-10-07 | Post-SDDD validation |

## Critères d'Archivage

Les scripts avec un format de date dans le nom (`YYYYMMDD` ou `YYYY-MM-DD`) sont considérés comme "datés" et sont déplacés vers ce dossier :
- Scripts de test/validation temporaires
- Scripts de diagnostic avec date précise
- Scripts de "fix" liés à un incident spécifique

## Non-Archivés

Les scripts suivants ne sont PAS concernés par cet archivage :
- Scripts avec années mais utilisés régulièrement (ex: `fix-*.ps1` dans deployment/diagnostic)
- Scripts dans d'autres dossiers d'archive (`_archive/`, etc.)
- Scripts sans date dans le nom
- Scripts de maintenance régulière

## Statut

✅ **Archivage complété** - 17 scripts déplacés
📝 **README créé** - 2026-03-14
