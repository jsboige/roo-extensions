# Scripts Archivés

Ce répertoire contient des scripts obsolètes ou à usage unique qui ont été archivés lors de la consolidation #481 (2026-02-17). **Ces scripts ne doivent pas être utilisés.**

## Sous-répertoires

| Répertoire | Description | Scripts | Raison archivage |
|------------|-------------|---------|------------------|
| `consolidate-docs/` | Consolidation documentation | 4 scripts | Usage unique, terminé |
| `consolidation-phase/` | Scripts de phases #481 | 4 scripts | Phase terminée |
| `demo-scripts/` | Scripts de démo | 3 scripts | Obsolètes |
| `ffmpeg/` | Installation/diagnostic FFmpeg | 6 scripts | FFmpeg non utilisé sur po-2026 |
| `github-projects-mcp/` | Tests MCP GitHub Projects | 3 scripts | MCP déprécié (#368) |
| `quickfiles-deprecated/` | Scripts QuickFiles dépréciés | 9 scripts | MCP déprécié (#368) |
| `roosync-oneshot/` | Scripts RooSync one-shot | 3 scripts | Issues résolues |
| `roosync-phase3/` | Scripts RooSync Phase 3 | 8 scripts | Phase terminée |
| `transients/` | Scripts temporaires | 1 script | Usage unique |

## Résumé

- **Total scripts archivés :** 33
- **Date d'archivage initiale :** 2026-02-17
- **Date de consolidation :** 2026-04-08
- **Issue :** #481 (archivage), #656 (consolidation)

## Consolidations #656 (2026-04-08)

### Doublons identifiés et consolidés :

1. **phase2-ventilate.ps1 + phase2-ventilate-clean.ps1** → Conserver `phase2-ventilate.ps1` (version complète avec messages détaillés)
2. **FFmpeg (6 fichiers)** → Conservés pour audit trail (obsolètes)
3. **GitHub Projects MCP (3 fichiers)** → Conservés pour audit trail (MCP retiré #368)
4. **QuickFiles Deprecated (9 fichiers)** → Conservés pour audit trail (MCP retiré #368)
5. **RooSync One-Shot (3 fichiers)** → Conservés pour audit trail (issues résolues)
6. **RooSync Phase 3 (8 fichiers)** → Conservés pour audit trail (phase terminée)
7. **Demo Scripts (3 fichiers)** → Conservés pour audit trail (usage unique)

**Note :** Le répertoire `scripts/` racine ne contient plus aucun script (tous ventilés dans les sous-répertoires).
