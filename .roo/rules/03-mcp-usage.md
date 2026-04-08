# Regles d'Utilisation des MCPs

**Version:** 2.0.0 (condensed from 1.0.0, aligned with .claude/rules/tool-availability.md)
**MAJ:** 2026-04-08

## Pre-requis

AVANT tout travail, verifier que les MCPs critiques repondent. Voir `.claude/rules/tool-availability.md` pour STOP & REPAIR.

## MCPs critiques

| MCP | Outils | Role |
| --- | ------ | ---- |
| **roo-state-manager** | 34 | Grounding, historique, RooSync |
| **win-cli** (fork local 0.2.0) | 9 | Shell commands (OBLIGATOIRE modes -simple) |

## win-cli

SEUL MCP shell actif. `execute_command(shell="powershell", command="...")`. Shells : `powershell`, `cmd`, `gitbash`.

**NE JAMAIS** `npx @anthropic/win-cli` (npm 0.2.1 casse). Fork local uniquement.

## roo-state-manager — Categories

- **RooSync** : `roosync_send`, `roosync_read`, `roosync_manage`, `roosync_config`, `roosync_heartbeat`
- **Grounding** : `conversation_browser`, `codebase_search`, `roosync_search`, `view_task_details`
- **Dashboard** : `roosync_dashboard` (canal principal de coordination)

## MCPs retires

`desktop-commander` (→ win-cli), `quickfiles` (→ outils natifs), `github-projects-mcp` (→ `gh` CLI)

## Economie de tokens

- Regrouper operations en batch MCP
- Filtrer a la source, pas en post-traitement
- Fichiers >1000 lignes : utiliser offset/limit
- **JAMAIS** `--coverage`. **TOUJOURS** piper vers `Select-Object -Last 30`

---
**Historique versions completes :** Git history avant 2026-04-08
