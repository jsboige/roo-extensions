---
# Rapport de Diagnostic et RÃ©paration mcp_settings.json
**Date:** 2025-10-18 18:59:03
**Fichier:** C:\Users\Administrator\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json
**Auto-rÃ©paration:** False
---


## VÃ©rification de l'existence

**Status:** SUCCESS
**Timestamp:** 2025-10-18 18:59:03

Fichier existant
- Taille: 6938 octets
- ModifiÃ©: 10/16/2025 23:25:57

---


## Validation JSON

**Status:** SUCCESS
**Timestamp:** 2025-10-18 18:59:04

JSON valide
- Taille du contenu: 6933 caractÃ¨res
- PropriÃ©tÃ©s racine: 1

---


## Analyse de la structure

**Status:** INFO
**Timestamp:** 2025-10-18 18:59:04

PropriÃ©tÃ©s racine dÃ©tectÃ©es:
- mcpServers : System.Management.Automation.PSCustomObject


---


## VÃ©rification mcpServers

**Status:** SUCCESS
**Timestamp:** 2025-10-18 18:59:04

mcpServers prÃ©sent
Serveurs configurÃ©s:
- jupyter-mcp
- github-projects-mcp
- playwright
- roo-state-manager
- jinavigator
- quickfiles
- searxng


---


## Configuration roo-state-manager

**Status:** ERROR
**Timestamp:** 2025-10-18 18:59:04

roo-state-manager configurÃ©
- Commande: cmd
- Arguments: /c node C:\dev\roo-extensions\mcps\internal\servers\roo-state-manager\dist\index.js
âŒ Chemin incorrect, ne pointe pas vers dist/index.js

---


## Recherche de backups

**Status:** SUCCESS
**Timestamp:** 2025-10-18 18:59:04

Backups trouvÃ©s:
- mcp_settings.json.backup-20251016-232311 (10/04/2025 12:37:38)
- mcp_settings.json.backup-20251016-232437 (10/04/2025 12:37:38)
- mcp_settings.json.backup-20251016-232557 (10/04/2025 12:37:38)
- mcp_settings.json.backup_20250920_195806 (09/20/2025 14:01:50)
- mcp_settings.json.backup_20250921_181220 (09/21/2025 17:49:34)
- mcp_settings.json.backup_20250921_222224 (09/21/2025 18:12:22)


---


## Analyse du backup le plus rÃ©cent

**Status:** SUCCESS
**Timestamp:** 2025-10-18 18:59:04

Backup le plus rÃ©cent: mcp_settings.json.backup-20251016-232557
JSON valide
Serveurs configurÃ©s:
- jupyter-mcp
- github-projects-mcp
- playwright
- roo-state-manager
- jinavigator
- quickfiles
- searxng


---


## Mode de rÃ©paration

**Status:** INFO
**Timestamp:** 2025-10-18 18:59:04

Mode diagnostic uniquement. Utilisez -AutoRepair pour effectuer la rÃ©paration.

---


## Instructions pour l'utilisateur

**Status:** INFO
**Timestamp:** 2025-10-18 18:59:04

## Instructions pour l'utilisateur

1. **Fermer complÃ¨tement VS Code**
2. **Rouvrir VS Code**
3. **VÃ©rifier que les outils MCP apparaissent dans Roo**
4. **Tester un outil roo-state-manager si disponible**

### Si le problÃ¨me persiste:
- VÃ©rifier les logs de VS Code (Help > Toggle Developer Tools)
- Chercher les erreurs liÃ©es Ã  'mcp' ou 'roo-state-manager'
- ExÃ©cuter ce script avec le paramÃ¨tre -AutoRepair pour tenter une rÃ©paration automatique

### Commande de rÃ©paration automatique:
`powershell
.\scripts\repair\13-diagnose-and-repair-mcp-settings.ps1 -AutoRepair
`

---


