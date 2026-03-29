# Regles d'Utilisation des MCPs

**Documentation complete des MCPs :** Voir [`docs/mcps/INDEX.md`](../../docs/mcps/INDEX.md) pour la documentation centralisee de tous les serveurs MCP (installation, configuration, outils disponibles, exemples).

## Pre-requis : Verification Disponibilite

**AVANT de commencer tout travail, verifier que les MCPs critiques repondent.**
Voir `.claude/rules/tool-availability.md` pour le protocole STOP & REPAIR.

**MCPs CRITIQUES pour Roo :**

- **roo-state-manager** (34 outils) : Grounding conversationnel, historique taches, RooSync
- **win-cli** (9 outils) : Shell commands (OBLIGATOIRE depuis modes fix b91a841c)

## MCP Shell : win-cli (OBLIGATOIRE)

**win-cli est le SEUL MCP shell actif** depuis le retrait de desktop-commander et la suppression du groupe `command` sur les modes `-simple`.

```bash
execute_command(shell="powershell", command="COMMANDE")
execute_command(shell="gitbash", command="COMMANDE")
```

**Shells disponibles :** `powershell`, `cmd`, `gitbash`

**Config :** Fork local 0.2.0 (PAS npm 0.2.1)

- Voir [`docs/mcps/INDEX.md`](../../docs/mcps/INDEX.md#win-cli-fork-local) pour la configuration complete

**MCPs Retires (NE PAS utiliser) :**

- `desktop-commander` → Remplace par win-cli
- `quickfiles` → Remplace par outils natifs Read/Write
- `github-projects-mcp` → Remplace par `gh` CLI natif

## roo-state-manager - Outils Disponibles

**Roo a acces a TOUS les outils roo-state-manager (34), y compris RooSync.**

**Categorisation des outils :** Voir [`docs/mcps/INDEX.md`](../../docs/mcps/INDEX.md#roo-state-manager) pour la liste complete organisee par categorie.

### Outils RooSync (communication inter-machine)

- `roosync_send`, `roosync_read`, `roosync_manage` (messagerie)
- `roosync_config`, `roosync_baseline`, `roosync_inventory` (gestion config)
- `roosync_heartbeat`, `roosync_compare_config`, `roosync_list_diffs` (monitoring)
- `analyze_roosync_problems` (diagnostic)

### Outils de grounding et recherche

- `conversation_browser` (arbre taches, vue conversation, resume - outil unifie)
- `codebase_search` (recherche semantique dans le code)
- `roosync_search` (recherche dans les taches - texte et semantique)
- `view_task_details`, `get_raw_conversation`, `task_export` (lecture historique)

**Bonne pratique :** Privilegier INTERCOM (`.claude/local/INTERCOM-{MACHINE}.md`) pour la communication locale avec Claude Code sur la meme machine. Utiliser RooSync pour la communication inter-machines ou pour lire les directives du coordinateur.

## Economie de Tokens

- Regrouper operations similaires en batch MCP
- Filtrer a la source (pas tout lire puis filtrer en post)
- Utiliser pagination et extraits cibles
- Pour fichiers >1000 lignes : utiliser extraits cibles (offset/limit avec read_file)
- **JAMAIS** `--coverage` dans les tests (output trop volumineux)
- **TOUJOURS** piper vers `Select-Object -Last 30` pour limiter l'output
