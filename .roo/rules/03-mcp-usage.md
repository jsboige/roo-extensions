# Regles d'Utilisation des MCPs

## Priorite MCP sur outils standards

Privilegier SYSTEMATIQUEMENT les MCPs sur les outils natifs Roo.

### win-cli - Commandes systeme (PRIORITAIRE)

```xml
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>execute_command</tool_name>
<arguments>{"shell": "powershell", "command": "COMMANDE"}</arguments>
</use_mcp_tool>
```

Shells disponibles : `powershell`, `cmd`, `gitbash`.
Ne PAS utiliser `&&` en PowerShell, utiliser `;` a la place.

### Autres MCPs disponibles

- **roo-state-manager** : Grounding conversationnel, historique taches (36 outils)
- **jinavigator** : Extraction contenu web en markdown
- **searxng** : Recherche web

### roo-state-manager - Outils AUTORISES et INTERDITS

**REGLE ABSOLUE : Ne JAMAIS utiliser les outils RooSync.**

RooSync (roosync_send, roosync_read, roosync_manage, etc.) est **EXCLUSIVEMENT pour Claude Code** (communication inter-machines). Roo communique avec Claude Code via **INTERCOM uniquement** (`.claude/local/INTERCOM-{MACHINE}.md`).

**Outils AUTORISES pour Roo :**
- `task_browse`, `view_task_details`, `view_conversation_tree` (grounding conversationnel)
- `get_raw_conversation`, `task_export` (lecture historique)
- `roosync_search` (recherche dans les taches)
- `diagnose_env`, `minimal_test_tool`, `read_vscode_logs` (diagnostic)
- `storage_info`, `maintenance` (maintenance)

**Outils INTERDITS pour Roo (reserv&eacute;s a Claude Code) :**
- `roosync_send`, `roosync_read`, `roosync_manage` (messagerie inter-machine)
- `roosync_config`, `roosync_baseline`, `roosync_inventory` (gestion RooSync)
- `roosync_heartbeat`, `roosync_decision`, `roosync_decision_info` (monitoring/decisions)
- `roosync_compare_config`, `roosync_list_diffs`, `roosync_refresh_dashboard` (diffs/dashboard)
- Tout outil commencant par `roosync_` sauf `roosync_search`

### Economie de tokens

- Regrouper operations similaires en batch MCP
- Filtrer a la source (pas tout lire puis filtrer en post)
- Utiliser pagination et extraits cibles
- Pour fichiers >1000 lignes : utiliser extraits cibles (offset/limit avec read_file)
