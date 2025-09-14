# Configuration des MCPs dans Roo

Ce document détaille la configuration des serveurs MCP (Model Context Protocol) dans l'environnement Roo, leurs emplacements et les outils pour y accéder.

## 📍 Emplacement du Fichier de Configuration Principal

Le fichier de configuration principal des MCPs dans Roo est situé à :

### Windows
```
C:\Users\<username>\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json
```

### macOS
```
~/Library/Application Support/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json
```

### Linux
```
~/.config/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json
```

## 🔧 Accès via roo-state-manager

Le serveur MCP **roo-state-manager** fournit des outils dédiés pour accéder et gérer ce fichier de configuration :

### Outils disponibles

| Outil | Description | Usage |
|-------|-------------|--------|
| `detect_roo_storage` | Détecte automatiquement les emplacements de stockage Roo | Localise le fichier mcp_settings.json |
| `get_storage_stats` | Calcule des statistiques sur le stockage | Informations sur la configuration MCP |
| `touch_mcp_settings` | Force le rechargement des MCPs | Redémarre les serveurs MCP après modification |

### Exemple d'utilisation

```javascript
// Via Roo, vous pouvez utiliser ces commandes :
// "Utilise roo-state-manager pour détecter l'emplacement de ma configuration MCP"
// "Touche mon fichier de configuration MCP pour recharger les serveurs"
```

## 📋 Structure du Fichier mcp_settings.json

```json
{
  "mcpServers": {
    "nom-du-serveur": {
      "command": "commande-de-démarrage",
      "args": ["arguments", "du", "serveur"],
      "env": {
        "VARIABLE": "valeur"
      },
      "cwd": "répertoire-de-travail",
      "disabled": false,
      "enabled": true,
      "autoApprove": [],
      "alwaysAllow": [
        "outil1",
        "outil2"
      ],
      "transportType": "stdio"
    }
  }
}
```

## 🚀 Gestion Automatique

### Scripts et Outils

- **Scripts PowerShell** : `scripts/mcp/` contient des utilitaires de gestion
- **Sauvegarde automatique** : Le système crée des sauvegardes avant modification
- **Validation** : `scripts/validation/validate-mcp-config.ps1` vérifie la configuration

### roo-state-manager comme Gestionnaire Central

Le serveur `roo-state-manager` sert de **gestionnaire central** pour :

1. **Détection automatique** des emplacements de configuration
2. **Surveillance des changements** de configuration
3. **Rechargement à chaud** des serveurs MCP
4. **Diagnostic** des problèmes de configuration

## 🛠️ Configuration Pratique

### Ajout d'un nouveau MCP

1. **Localisation** : Utilisez `roo-state-manager.detect_roo_storage`
2. **Modification** : Éditez le fichier mcp_settings.json
3. **Rechargement** : Utilisez `roo-state-manager.touch_mcp_settings`

### Exemple : jupyter-papermill-mcp-server

```json
{
  "mcpServers": {
    "jupyter-papermill": {
      "command": "python",
      "args": [
        "-m", 
        "papermill_mcp.main_fixed"
      ],
      "cwd": "d:/roo-extensions/mcps/internal/servers/jupyter-papermill-mcp-server",
      "env": {
        "JUPYTER_MCP_LOG_LEVEL": "INFO"
      },
      "disabled": false,
      "enabled": true,
      "alwaysAllow": [
        "read_notebook",
        "write_notebook", 
        "execute_notebook_papermill",
        "start_kernel",
        "execute_cell"
      ],
      "transportType": "stdio"
    }
  }
}
```

## 📖 Références

- **Documentation MCPs** : [mcps/README.md](../mcps/README.md)
- **Scripts de gestion** : [scripts/mcp/README.md](../scripts/mcp/README.md)
- **roo-state-manager** : [mcps/internal/servers/roo-state-manager/README.md](../mcps/internal/servers/roo-state-manager/README.md)

## ⚠️ Important

> **Note** : Toujours utiliser `roo-state-manager.touch_mcp_settings` après modification manuelle du fichier de configuration pour garantir le rechargement correct des serveurs MCP.

---

*Cette documentation est maintenue automatiquement et reflète la structure actuelle de l'écosystème Roo.*