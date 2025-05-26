# Configuration Flexible des Tokens GitHub pour les MCPs

## Vue d'ensemble

Cette configuration permet de gérer facilement plusieurs tokens GitHub et de basculer entre eux selon le contexte de travail. Elle supporte deux utilisateurs GitHub :

- **Token Principal** : `jsboige@gmail.com` (jsboige)
- **Token Epita** : `jsboigeEpita`

## Fichiers de Configuration

### 1. `.env` - Variables d'environnement
```bash
# Token principal (jsboige@gmail.com)
GITHUB_TOKEN=ghp_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# Token alternatif (jsboigeEpita)
GITHUB_TOKEN_EPITA=ghp_YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY

# Configuration par défaut
DEFAULT_USER=jsboige
DEFAULT_ORG=

# Token actif (primary ou epita)
GITHUB_TOKEN_ACTIVE=primary
```

### 2. `config.js` - Configuration JavaScript
Module Node.js qui gère la logique de basculement entre les tokens.

### 3. `mcp_settings.json` - Configuration MCP
Configuration VSCode avec les variables d'environnement pour les serveurs MCP :
- `github-projectsglobal`
- `gitglobal`

## Utilisation

### Script PowerShell de Gestion

Le script `manage-tokens.ps1` permet de gérer facilement les tokens :

```powershell
# Afficher le statut actuel
.\manage-tokens.ps1 status

# Basculer vers le token principal
.\manage-tokens.ps1 primary

# Basculer vers le token Epita
.\manage-tokens.ps1 epita

# Tester la connectivité GitHub
.\manage-tokens.ps1 test

# Afficher l'aide
.\manage-tokens.ps1 help
```

### Basculement Manuel

1. **Modifier le fichier `.env`** :
   ```bash
   GITHUB_TOKEN_ACTIVE=epita  # ou primary
   ```

2. **Redémarrer VSCode** pour appliquer les changements aux MCPs

### Utilisation dans le Code

Le serveur GitHub Projects MCP utilise automatiquement le token configuré :

```javascript
const config = require('./config');
const token = config.getActiveToken();
```

## Fonctionnalités

### ✅ Gestion Flexible des Tokens
- Basculement facile entre différents comptes GitHub
- Configuration centralisée dans le fichier `.env`
- Mise à jour automatique de la configuration MCP

### ✅ Validation et Tests
- Test de connectivité GitHub intégré
- Validation des tokens avant utilisation
- Messages d'erreur détaillés

### ✅ Compatibilité
- Fonctionne avec tous les MCPs GitHub existants
- Rétrocompatible avec les configurations existantes
- Support des variables d'environnement standard

## Serveurs MCP Supportés

### 1. github-projectsglobal
- **Chemin** : `d:/Dev/roo-extensions/mcps/internal/servers/github-projects-mcp/`
- **Fonctions** : Gestion des projets GitHub
- **Variables** : `GITHUB_TOKEN`, `GITHUB_TOKEN_EPITA`, `GITHUB_TOKEN_ACTIVE`

### 2. gitglobal
- **Package** : `@modelcontextprotocol/server-github`
- **Fonctions** : API GitHub complète
- **Variables** : `GITHUB_PERSONAL_ACCESS_TOKEN`, `GITHUB_TOKEN_ACTIVE`

## Dépannage

### Problème : Token non reconnu
```bash
# Vérifier la configuration
.\manage-tokens.ps1 status

# Tester la connectivité
.\manage-tokens.ps1 test
```

### Problème : MCP ne fonctionne pas
1. Vérifier que VSCode a été redémarré après le changement de token
2. Vérifier les logs MCP dans VSCode
3. Tester la connectivité avec le script

### Problème : Erreur de parsing PowerShell
- S'assurer que le fichier `.ps1` est encodé en UTF-8
- Vérifier les permissions d'exécution PowerShell

## Sécurité

### ⚠️ Tokens GitHub
- Les tokens sont stockés en clair dans les fichiers de configuration
- Ne pas commiter les fichiers `.env` dans Git
- Utiliser des tokens avec les permissions minimales nécessaires

### 🔒 Bonnes Pratiques
- Régénérer les tokens périodiquement
- Utiliser des tokens différents pour différents projets
- Surveiller l'utilisation des tokens dans GitHub

## Maintenance

### Ajout d'un Nouveau Token
1. Ajouter la variable dans `.env` :
   ```bash
   GITHUB_TOKEN_NOUVEAU=ghp_...
   ```

2. Modifier `config.js` pour inclure le nouveau token

3. Mettre à jour le script `manage-tokens.ps1`

### Suppression d'un Token
1. Supprimer la variable du fichier `.env`
2. Révoquer le token dans GitHub
3. Mettre à jour les scripts de gestion

## Support

Pour toute question ou problème :
1. Vérifier les logs VSCode
2. Tester avec le script PowerShell
3. Vérifier la connectivité réseau
4. Consulter la documentation GitHub API

---

**Dernière mise à jour** : 24/05/2025
**Version** : 1.0
**Auteur** : Configuration automatisée Roo