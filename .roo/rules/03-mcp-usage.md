# Regles d'Utilisation des MCPs

**Version:** 2.1.0 (added win-cli schema + 502 death spiral mitigation)
**MAJ:** 2026-05-02

## Pre-requis

AVANT tout travail, verifier que les MCPs critiques repondent. Voir `.claude/rules/tool-availability.md` pour STOP & REPAIR.

## MCPs critiques

| MCP | Outils | Role |
| --- | ------ | ---- |
| **roo-state-manager** | 34 | Grounding, historique, RooSync |
| **win-cli** (fork local 0.2.0) | 9 | Shell commands (OBLIGATOIRE modes -simple) |

## win-cli

SEUL MCP shell actif. Shells disponibles : `powershell`, `cmd`, `gitbash`.

### Schema OBLIGATOIRE (Issue #1783)

**Les 2 parametres sont REQUIS.** Omettre `shell` provoque une erreur schema `-32602`.

```
# CORRECT — toujours specifier shell ET command
execute_command(shell="powershell", command="Get-Date")
execute_command(shell="gitbash", command="git status")

# INCORRECT — provoque MCP error -32602: Invalid arguments: Required
execute_command(command="Get-Date")  # MANQUE shell
execute_command(shell="powershell")  # MANQUE command
```

**Parametres :**
| Parametre | Type | Requis | Valeurs |
| --------- | ---- | ------ | ------- |
| `shell` | string | **OUI** | `"powershell"`, `"cmd"`, `"gitbash"` |
| `command` | string | **OUI** | Toute commande valide pour le shell choisi |

**NE JAMAIS** `npx @anthropic/win-cli` (npm 0.2.1 casse). Fork local uniquement.

## roo-state-manager — Categories

- **RooSync** : `roosync_send`, `roosync_read`, `roosync_manage`, `roosync_config`, `roosync_inventory` (heartbeat automatique #1609)
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
