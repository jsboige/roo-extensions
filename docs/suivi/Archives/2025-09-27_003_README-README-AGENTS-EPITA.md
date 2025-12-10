# Guide des Agents pour les Dépôts Epita

## Vue d'ensemble

Ce guide explique comment les agents Roo peuvent travailler efficacement avec les dépôts GitHub Epita en utilisant le système de basculement de tokens GitHub intégré.

## Configuration des Tokens

### Tokens Disponibles

Le système dispose de deux tokens GitHub configurés :

1. **Token Principal** (`jsboige@gmail.com`)
   - Token : `ghp_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`
   - Utilisateur : `jsboige`
   - Accès : Dépôts personnels et organisations publiques

2. **Token Epita** (`jsboigeEpita`)
   - Token : `ghp_YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY`
   - Utilisateur : `jsboigeEpita`
   - Accès : Dépôts Epita et projets académiques

### Fichiers de Configuration

#### 1. Configuration Locale (`.env`)
```bash
# Fichier: mcps/internal/servers/github-projects-mcp/.env
GITHUB_TOKEN=ghp_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
GITHUB_TOKEN_EPITA=ghp_YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY
GITHUB_TOKEN_ACTIVE=primary  # ou "epita"
DEFAULT_USER=jsboige
```

#### 2. Configuration MCP Globale
```json
// Fichier: c:/Users/jsboi/AppData/Roaming/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json
{
  "mcpServers": {
    "github-projectsglobal": {
      "env": {
        "GITHUB_TOKEN": "ghp_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
        "GITHUB_TOKEN_EPITA": "ghp_YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY",
        "GITHUB_TOKEN_ACTIVE": "primary",
        "DEFAULT_USER": "jsboige"
      }
    },
    "gitglobal": {
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
        "GITHUB_TOKEN": "ghp_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
        "GITHUB_TOKEN_EPITA": "ghp_YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY",
        "GITHUB_TOKEN_ACTIVE": "primary"
      }
    }
  }
}
```

## Utilisation du Script de Gestion

### Script Principal
Le script [`manage-tokens.ps1`](mcps/internal/servers/github-projects-mcp/manage-tokens.ps1) permet de gérer le basculement entre tokens.

### Actions Disponibles

```powershell
# Afficher le statut actuel
.\manage-tokens.ps1 status

# Basculer vers le token principal
.\manage-tokens.ps1 primary

# Basculer vers le token Epita
.\manage-tokens.ps1 epita

# Tester la connectivité
.\manage-tokens.ps1 test

# Afficher l'aide
.\manage-tokens.ps1 help
```

## Workflow pour Travailler avec les Dépôts Epita

### 1. Vérification du Statut Initial
```powershell
powershell -ExecutionPolicy Bypass -File "mcps/internal/servers/github-projects-mcp/manage-tokens.ps1" -Action status
```

### 2. Basculement vers le Token Epita
```powershell
powershell -ExecutionPolicy Bypass -File "mcps/internal/servers/github-projects-mcp/manage-tokens.ps1" -Action epita
```

### 3. Test de Connectivité
```powershell
powershell -ExecutionPolicy Bypass -File "mcps/internal/servers/github-projects-mcp/manage-tokens.ps1" -Action test
```

### 4. Travail avec les MCPs
Une fois le token Epita activé, les MCPs `gitglobal` et `github-projectsglobal` utiliseront automatiquement le token Epita pour toutes les opérations.

### 5. Retour au Token Principal
```powershell
powershell -ExecutionPolicy Bypass -File "mcps/internal/servers/github-projects-mcp/manage-tokens.ps1" -Action primary
```

## Permissions et Accès

### Token Principal (`jsboige`)
- ✅ Dépôts personnels
- ✅ Organisations publiques
- ✅ Création de dépôts
- ✅ Issues et Pull Requests
- ❌ Dépôts Epita privés

### Token Epita (`jsboigeEpita`)
- ✅ Dépôts Epita
- ✅ Projets académiques
- ✅ Collaboration sur projets étudiants
- ❌ Dépôts personnels jsboige

## Bonnes Pratiques

### 1. Vérification Avant Utilisation
Toujours vérifier le token actif avant de commencer un travail :
```powershell
.\manage-tokens.ps1 status
```

### 2. Test de Connectivité
Tester la connectivité après chaque basculement :
```powershell
.\manage-tokens.ps1 test
```

### 3. Gestion des Erreurs
Si une opération échoue, vérifier :
- Le token actif correspond au dépôt cible
- Les permissions sont suffisantes
- La connectivité réseau

### 4. Nettoyage
Revenir au token principal après le travail sur les dépôts Epita :
```powershell
.\manage-tokens.ps1 primary
```

## Exemples d'Utilisation

### Exemple 1 : Travail sur un Projet Epita
```powershell
# 1. Vérifier le statut
.\manage-tokens.ps1 status

# 2. Basculer vers Epita
.\manage-tokens.ps1 epita

# 3. Tester la connectivité
.\manage-tokens.ps1 test

# 4. Utiliser les MCPs pour le travail
# (Les MCPs utilisent automatiquement le token Epita)

# 5. Revenir au token principal
.\manage-tokens.ps1 primary
```

### Exemple 2 : Vérification Rapide
```powershell
# Statut et test en une commande
.\manage-tokens.ps1 status && .\manage-tokens.ps1 test
```

## Dépannage

### Problème : MCPs Non Connectés
Si les MCPs n'apparaissent pas dans Roo après redémarrage :

1. **Vérifier l'encodage du fichier de configuration :**
   ```powershell
   powershell -ExecutionPolicy Bypass -File "fix-mcp-encoding.ps1"
   ```

2. **Redémarrer VS Code complètement**

3. **Vérifier la syntaxe JSON :**
   ```powershell
   Get-Content 'c:/Users/jsboi/AppData/Roaming/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json' | ConvertFrom-Json
   ```

### Problème : Token Non Reconnu
```powershell
# Vérifier les variables d'environnement
.\manage-tokens.ps1 status

# Tester la connectivité
.\manage-tokens.ps1 test
```

### Problème : Permissions Insuffisantes
- Vérifier que le bon token est actif
- Confirmer les permissions du token sur GitHub
- Essayer de basculer vers l'autre token

## Maintenance

### Sauvegarde des Configurations
```powershell
# Sauvegarder le fichier .env
Copy-Item "mcps/internal/servers/github-projects-mcp/.env" "mcps/internal/servers/github-projects-mcp/.env.backup"

# Sauvegarder la configuration MCP
Copy-Item "c:/Users/jsboi/AppData/Roaming/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json" "c:/Users/jsboi/AppData/Roaming/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json.backup"
```

### Mise à Jour des Tokens
1. Modifier le fichier `.env`
2. Mettre à jour la configuration MCP
3. Redémarrer VS Code
4. Tester la connectivité

## Sécurité

### Protection des Tokens
- ❌ Ne jamais commiter les tokens dans Git
- ✅ Utiliser des fichiers `.env` ignorés par Git
- ✅ Renouveler les tokens périodiquement
- ✅ Révoquer les tokens compromis immédiatement

### Bonnes Pratiques de Sécurité
- Utiliser des tokens avec permissions minimales
- Surveiller l'utilisation des tokens
- Documenter les accès et permissions
- Effectuer des audits réguliers

## Support

### Fichiers de Log
Les logs des MCPs sont disponibles dans la console de développement de VS Code.

### Commandes de Diagnostic
```powershell
# Test complet du système
.\manage-tokens.ps1 status
.\manage-tokens.ps1 test
Get-Content "mcps/internal/servers/github-projects-mcp/.env"
```

### Contact
Pour toute question ou problème, consulter la documentation technique ou contacter l'administrateur système.

---

**Dernière mise à jour :** 24/05/2025  
**Version :** 1.0  
**Auteur :** Système Roo MCP