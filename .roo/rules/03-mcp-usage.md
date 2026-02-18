# Regles d'Utilisation des MCPs

## Priorite MCP sur outils standards

Privilegier SYSTEMATIQUEMENT les MCPs sur les outils natifs Roo.

### desktop-commander - Commandes systeme (PRIORITAIRE)

**Note (#468 Phase 3) :** DesktopCommanderMCP remplace win-cli sur toutes les machines.

```xml
<use_mcp_tool>
<server_name>desktop-commander</server_name>
<tool_name>start_process</tool_name>
<arguments>{"command": "COMMANDE", "shell": "powershell"}</arguments>
</use_mcp_tool>
```

**Shells disponibles :** `powershell`, `cmd`, `gitbash`, `wsl` (configurable via `set_config_value`)

**Differences importantes vs win-cli :**

**Differences importantes vs win-cli :**
- `start_process` (asynchrone) au lieu de `execute_command`
- Operateurs shell (`&&`, `|`, `;`) fonctionnent **nativement** - pas de fork necessaire
- 26 outils vs 9 dans win-cli : operations fichier, recherche, processus
- Config path : `~/.claude-server-commander/config.json`

### Autres MCPs disponibles

- **roo-state-manager** : Grounding conversationnel, historique taches (36 outils)
- **sk-agent** : Agents LLM multi-modeles (glm-4.6v, glm-5, zwz-8b, glm-4.7-flash)
- **markitdown** : Conversion documents (PDF, DOCX, etc.) en markdown

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
