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

- **roo-state-manager** : Grounding conversationnel, historique taches, RooSync
- **jinavigator** : Extraction contenu web en markdown
- **searxng** : Recherche web

### Economie de tokens

- Regrouper operations similaires en batch MCP
- Filtrer a la source (pas tout lire puis filtrer en post)
- Utiliser pagination et extraits cibles
- Pour fichiers >1000 lignes : utiliser extraits cibles (offset/limit avec read_file)
