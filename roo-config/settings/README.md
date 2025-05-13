# Configuration générale de Roo

Ce répertoire contient les fichiers de configuration générale pour Roo, indépendamment des modes personnalisés.

## Structure des fichiers

- `settings.json` : Configuration générale de Roo, incluant les paramètres globaux et les associations de modes avec les profils d'API.
- `deploy-settings.ps1` : Script PowerShell pour déployer la configuration générale.

## Contenu du fichier settings.json

Le fichier `settings.json` contient deux sections principales :

1. **globalSettings** : Paramètres globaux de Roo
   - **customInstructions** : Instructions personnalisées pour les modèles d'IA
   - **Autorisations** :
     - `autoApprovalEnabled` : Active/désactive l'approbation automatique des actions
     - `alwaysAllowReadOnly` : Autorise toujours la lecture des fichiers
     - `alwaysAllowReadOnlyOutsideWorkspace` : Autorise la lecture des fichiers en dehors de l'espace de travail
     - `alwaysAllowWrite` : Autorise toujours l'écriture des fichiers
     - `alwaysAllowWriteOutsideWorkspace` : Autorise l'écriture des fichiers en dehors de l'espace de travail
     - `alwaysAllowBrowser` : Autorise toujours l'utilisation du navigateur
     - `alwaysAllowMcp` : Autorise toujours l'utilisation des serveurs MCP
     - `alwaysAllowModeSwitch` : Autorise toujours le changement de mode
     - `alwaysAllowSubtasks` : Autorise toujours la création de sous-tâches
     - `alwaysAllowExecute` : Autorise toujours l'exécution de commandes
   - **Paramètres du terminal** :
     - `terminalOutputLineLimit` : Limite de lignes pour la sortie du terminal
     - `terminalShellIntegrationTimeout` : Délai d'attente pour l'intégration du shell
     - Autres paramètres spécifiques aux différents shells (PowerShell, Zsh, etc.)
   - **Paramètres du navigateur** :
     - `browserToolEnabled` : Active/désactive l'outil de navigation
     - `browserViewportSize` : Taille de la fenêtre du navigateur
     - `screenshotQuality` : Qualité des captures d'écran
   - **Commandes autorisées** : Liste des commandes que Roo est autorisé à exécuter
   - **Autres paramètres** :
     - `language` : Langue de l'interface
     - `telemetrySetting` : Paramètres de télémétrie
     - `mcpEnabled` : Active/désactive les serveurs MCP
     - `enableMcpServerCreation` : Autorise la création de serveurs MCP
     - `mode` : Mode par défaut
     - `customModes` : Modes personnalisés définis localement

2. **modeApiConfigs** : Association entre les modes et les profils d'API
   - Définit quel profil d'API est utilisé pour chaque mode
   - Exemple : `"code": "default"` signifie que le mode "code" utilise le profil d'API "default"
   - Les profils "default" et "simple" sont prédéfinis et correspondent à différents modèles d'IA

## Utilisation du script de déploiement

Le script `deploy-settings.ps1` permet de déployer la configuration générale de Roo.

### Syntaxe

```powershell
.\deploy-settings.ps1 [-ConfigFile <chemin>] [-Force]
```

### Paramètres

- `-ConfigFile` : Chemin du fichier de configuration à déployer (relatif au répertoire `roo-config/settings/`)
  - Par défaut : `settings.json`

- `-Force` : Force le remplacement du fichier de destination sans demander de confirmation

### Exemples

1. Déployer la configuration générale standard :
   ```powershell
   .\roo-config/settings\deploy-settings.ps1
   ```

2. Déployer une configuration personnalisée sans confirmation :
   ```powershell
   .\roo-config/settings\deploy-settings.ps1 -ConfigFile ma-config.json -Force
   ```

## Emplacement de déploiement

Le fichier de configuration est déployé dans un emplacement spécifique selon le système d'exploitation :

- **Windows** : `%APPDATA%\roo\config.json`
- **macOS** : `~/Library/Application Support/roo/config.json`
- **Linux** : `~/.config/roo/config.json`

## Relation avec roo-modes

Alors que le répertoire `roo-config/settings` gère les configurations générales de Roo, le répertoire `roo-modes` se concentre sur la définition des modes personnalisés. Les deux sont complémentaires :

- **roo-config/settings** : Configuration globale, paramètres généraux, associations mode-API
- **roo-modes** : Définition des modes personnalisés, leurs propriétés et comportements

Pour une configuration complète de Roo, vous devrez généralement déployer à la fois :
1. Une configuration générale (via `roo-config/settings/deploy-settings.ps1`)
2. Une configuration de modes (via `roo-modes/deploy-modes.ps1`)

Pour plus d'informations sur les configurations de modes, consultez la [documentation de roo-modes](../roo-modes/README.md).

## Sécurité

Ce fichier de configuration a été nettoyé pour supprimer toutes les informations sensibles :
- Clés d'API (OpenAI, OpenRouter, Gemini, etc.)
- URLs spécifiques aux endpoints privés
- Autres informations d'authentification

Lors de l'utilisation de cette configuration, assurez-vous d'ajouter vos propres clés d'API et informations d'authentification.

## Recommandations

- Déployez la configuration générale une fois sur chaque machine que vous utilisez.
- Ajoutez manuellement vos clés d'API et autres informations sensibles après le déploiement.
- Sauvegardez votre configuration complète (avec les clés) dans un emplacement sécurisé.
- Après chaque déploiement, redémarrez Visual Studio Code pour appliquer les changements.
- Ne partagez jamais votre fichier de configuration contenant des clés d'API.