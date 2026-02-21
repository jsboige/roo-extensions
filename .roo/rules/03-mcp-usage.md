# Regles d'Utilisation des MCPs

## Pre-requis : Verification Disponibilite

**AVANT de commencer tout travail, verifier que les MCPs critiques repondent.**
Voir `.roo/rules/05-tool-availability.md` pour le protocole STOP & REPAIR.

## MCP Shell : win-cli (OBLIGATOIRE)

**win-cli est le SEUL MCP shell actif** depuis le retrait de desktop-commander et la suppression du groupe `command` sur les modes `-simple`.

```
execute_command(shell="powershell", command="COMMANDE")
execute_command(shell="gitbash", command="COMMANDE")
```

**Shells disponibles :** `powershell`, `cmd`, `gitbash`

**Config :** Fork local 0.2.0 - `node mcps/external/win-cli/server/dist/index.js`
**NE JAMAIS utiliser** `npx @anthropic/win-cli` (npm 0.2.1 casse).

**MCPs Retires (NE PAS utiliser) :**
- `desktop-commander` (retire, ne plus y faire reference)
- `quickfiles` (retire, CONS-1)

## Autres MCPs Disponibles

- **roo-state-manager** : Grounding conversationnel, historique taches (36 outils)
- **markitdown** : Conversion documents (PDF, DOCX, etc.) en markdown
- **playwright** : Automatisation web, screenshots

## roo-state-manager - Outils AUTORISES et INTERDITS

**REGLE ABSOLUE : Ne JAMAIS utiliser les outils RooSync.**

RooSync (roosync_send, roosync_read, roosync_manage, etc.) est **EXCLUSIVEMENT pour Claude Code** (communication inter-machines). Roo communique avec Claude Code via **INTERCOM uniquement** (`.claude/local/INTERCOM-{MACHINE}.md`).

**Outils AUTORISES pour Roo :**
- `conversation_browser` (arbre taches, vue conversation, resume - outil unifie)
- `view_task_details`, `get_raw_conversation`, `task_export` (lecture historique)
- `roosync_search` (recherche dans les taches - texte et semantique)
- `codebase_search` (recherche semantique dans le code)
- `read_vscode_logs` (diagnostic)
- `storage_info`, `maintenance` (maintenance)

**Outils INTERDITS pour Roo (reserves a Claude Code) :**
- `roosync_send`, `roosync_read`, `roosync_manage` (messagerie inter-machine)
- `roosync_config`, `roosync_baseline`, `roosync_inventory` (gestion RooSync)
- `roosync_heartbeat`, `roosync_decision`, `roosync_decision_info` (monitoring/decisions)
- `roosync_compare_config`, `roosync_list_diffs`, `roosync_refresh_dashboard` (diffs/dashboard)
- Tout outil commencant par `roosync_` sauf `roosync_search`

## Economie de Tokens

- Regrouper operations similaires en batch MCP
- Filtrer a la source (pas tout lire puis filtrer en post)
- Utiliser pagination et extraits cibles
- Pour fichiers >1000 lignes : utiliser extraits cibles (offset/limit avec read_file)
- **JAMAIS** `--coverage` dans les tests (output trop volumineux)
- **TOUJOURS** piper vers `Select-Object -Last 30` pour limiter l'output
