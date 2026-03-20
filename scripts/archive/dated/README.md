# Scripts Datés - Archive

This directory contains PowerShell scripts with dates in their filenames, archived during the consolidation effort (Issue #656, P0 - Scripts datés).

## Archivé le 2026-03-16

**Scripts de messaging (2025-10-20)** - déplacés depuis `scripts/_archive/messaging-investigation-2025-10-20/` :

| Script | Description originale |
|--------|----------------------|
| `01-analyze-roo-state-manager-novelties.ps1` | Analyse des nouveautés roo-state-manager |
| `02-check-compilation-state.ps1` | Vérification état compilation |
| `03-compile-and-search-messaging.ps1` | Compilation et recherche messaging |
| `04-analyze-sources-direct.ps1` | Analyse directe des sources |
| `06-check-compilation-and-env.ps1` | Vérification compilation et environnement |
| `07-update-env-messaging.ps1` | Mise à jour environnement messaging |
| `08-check-mcp-config-final-report.ps1` | Rapport final configuration MCP |
| `09-fix-mcp-compilation-path.ps1` | Correction chemin compilation MCP |
| `10-fix-mcp-path-improved.ps1` | Correction améliorée chemin MCP |
| `11-fix-mcp-path-final.ps1` | Correction finale chemin MCP |

**Scripts superseded** - remplacés par des versions consolidées plus récentes :

| Script | Raison d'archivage |
|--------|-------------------|
| `12-legacy-diagnostic-utf8.ps1` | Superseded by `scripts/encoding/diagnostic-encoding-consolide.ps1` v2.0 (2025-11-11) |

## Critère d'archivage

Scripts archivés s'ils contiennent une date dans le nom (format `YYYY-MM-DD`) ou s'ils font partie d'un dossier daté.

**Source**: Issue #656 - Tâche de consolidation idle P0
