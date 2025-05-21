# Configurations du MCP Jupyter

Ce document présente les différentes configurations possibles pour le serveur MCP Jupyter, leurs avantages et inconvénients, ainsi que les instructions pour passer d'une configuration à une autre.

## 1. Configuration en mode hors ligne (offline: true)

### Description
Le mode hors ligne permet au serveur MCP Jupyter de fonctionner sans connexion à un serveur Jupyter. Dans ce mode, certaines fonctionnalités sont limitées, mais le serveur reste opérationnel et peut être utilisé pour des tâches ne nécessitant pas d'exécution de code.

### Configuration
```json
{
  "jupyterServer": {
    "baseUrl": "http://localhost:8888",
    "token": "votre_token_ici",
    "offline": true
  }
}
```

### Avantages
- Démarrage rapide et sans erreur, même en l'absence d'un serveur Jupyter
- Pas de tentative de connexion au démarrage, évitant les erreurs de timeout
- Idéal pour les environnements où Jupyter n'est pas installé ou disponible
- Permet d'utiliser les fonctionnalités de base comme la création et la modification de notebooks

### Inconvénients
- Impossible d'exécuter du code dans les notebooks
- Fonctionnalités liées aux kernels non disponibles
- Pas d'accès aux résultats d'exécution

### Cas d'utilisation recommandés
- Environnements de développement sans Jupyter
- Édition de notebooks sans exécution de code
- Situations où la stabilité est prioritaire sur les fonctionnalités complètes

## 2. Configuration avec serveur local sur le port 8888

### Description
Configuration standard utilisant un serveur Jupyter local sur le port par défaut (8888). Cette configuration est idéale pour les utilisateurs qui exécutent Jupyter Notebook ou JupyterLab localement avec les paramètres par défaut.

### Configuration
```json
{
  "jupyterServer": {
    "baseUrl": "http://localhost:8888",
    "token": "votre_token_ici",
    "offline": false
  }
}
```

### Avantages
- Compatible avec l'installation par défaut de Jupyter Notebook/JupyterLab
- Configuration simple et standard
- Accès à toutes les fonctionnalités du MCP Jupyter
- Intégration transparente avec l'environnement Jupyter existant

### Inconvénients
- Peut entrer en conflit avec d'autres services utilisant le port 8888
- Nécessite que Jupyter soit déjà en cours d'exécution sur ce port
- Le token doit correspondre exactement à celui du serveur Jupyter

### Cas d'utilisation recommandés
- Utilisateurs ayant déjà Jupyter installé et configuré par défaut
- Environnements de développement individuels
- Intégration avec des workflows Jupyter existants

## 3. Configuration avec serveur local sur le port 8890

### Description
Cette configuration utilise un serveur Jupyter local sur un port alternatif (8890), ce qui permet d'éviter les conflits avec d'autres instances de Jupyter ou services utilisant le port par défaut.

### Configuration
```json
{
  "jupyterServer": {
    "baseUrl": "http://localhost:8890",
    "token": "votre_token_ici",
    "offline": false
  }
}
```

### Avantages
- Évite les conflits avec le port par défaut de Jupyter (8888)
- Permet d'exécuter plusieurs instances de Jupyter en parallèle
- Isolation de l'instance utilisée par le MCP Jupyter
- Meilleure sécurité grâce à l'utilisation d'un port non standard

### Inconvénients
- Nécessite de configurer manuellement Jupyter pour utiliser ce port
- Peut nécessiter des ajustements dans les pare-feu ou les configurations réseau
- Moins standard, ce qui peut compliquer le dépannage

### Cas d'utilisation recommandés
- Environnements multi-utilisateurs
- Systèmes avec plusieurs instances de Jupyter
- Configurations où le port 8888 est déjà utilisé

## 4. Configuration avec serveur HTTP dédié sur le port 8891

### Description
Cette configuration utilise un serveur Jupyter dédié sur le port 8891, généralement configuré spécifiquement pour l'intégration avec le MCP Jupyter. Elle offre la meilleure isolation et personnalisation.

### Configuration
```json
{
  "jupyterServer": {
    "baseUrl": "http://localhost:8891",
    "token": "votre_token_ici",
    "offline": false
  }
}
```

### Avantages
- Isolation complète du serveur Jupyter utilisé par le MCP
- Personnalisation maximale des paramètres du serveur
- Évite toute interférence avec d'autres instances de Jupyter
- Peut être configuré avec des extensions et des kernels spécifiques

### Inconvénients
- Nécessite plus de ressources système (mémoire, CPU)
- Configuration plus complexe
- Maintenance de deux instances de Jupyter (standard et MCP)

### Cas d'utilisation recommandés
- Environnements de production
- Intégrations critiques nécessitant une haute disponibilité
- Situations où des extensions ou configurations spécifiques sont nécessaires

## Comment changer de configuration

### Méthode 1: Modification directe du fichier config.json

1. Localisez le fichier de configuration:
   ```
   mcps/mcp-servers/servers/jupyter-mcp-server/config.json
   ```

2. Ouvrez-le dans un éditeur de texte et modifiez les paramètres selon vos besoins:
   - Changez `baseUrl` pour pointer vers le bon serveur et port
   - Modifiez `token` pour correspondre au token de votre serveur Jupyter
   - Définissez `offline` à `true` ou `false` selon vos besoins

3. Sauvegardez le fichier

4. Redémarrez le serveur MCP Jupyter pour appliquer les changements

### Méthode 2: Utilisation des scripts de démarrage avec paramètres

Vous pouvez utiliser les scripts de démarrage avec différents paramètres:

```bash
# Mode hors ligne
scripts/mcp-starters/start-jupyter-mcp-offline.bat

# Mode connecté (port par défaut)
node mcps/mcp-servers/servers/jupyter-mcp-server/dist/index.js

# Mode connecté avec port spécifique (via variable d'environnement)
set JUPYTER_SERVER_URL=http://localhost:8890
node mcps/mcp-servers/servers/jupyter-mcp-server/dist/index.js
```

### Méthode 3: Utilisation du script d'intégration VSCode

Le script d'intégration VSCode (`start-jupyter-mcp-vscode.bat`) détecte automatiquement les kernels disponibles dans VSCode et configure le MCP Jupyter en conséquence:

```bash
# Démarrage avec détection automatique des kernels VSCode
mcps/jupyter/start-jupyter-mcp-vscode.bat
```

### Changement dynamique de configuration

Le serveur MCP Jupyter surveille les modifications du fichier de configuration et peut passer du mode connecté au mode hors ligne (et vice versa) sans nécessiter de redémarrage:

1. Modifiez le fichier `config.json` pendant que le serveur est en cours d'exécution
2. Le serveur détectera automatiquement les changements et ajustera son comportement
3. Vérifiez la console du serveur pour confirmer le changement de mode

## Recommandations générales

- **Pour le développement**: Utilisez le mode hors ligne ou le port 8890 pour éviter les conflits
- **Pour la production**: Utilisez le port 8891 avec un serveur dédié
- **Pour l'intégration VSCode**: Utilisez le script `start-jupyter-mcp-vscode.bat`
- **Pour les tests**: Utilisez le mode hors ligne pour garantir la stabilité

## Dépannage

Si vous rencontrez des problèmes de connexion:

1. Vérifiez que le serveur Jupyter est bien en cours d'exécution sur le port configuré
2. Assurez-vous que le token est correct
3. Essayez le mode hors ligne pour isoler les problèmes
4. Consultez les logs du serveur MCP Jupyter pour plus d'informations

Pour plus d'informations sur le dépannage, consultez le document [jupyter-mcp-troubleshooting.md](../mcp-servers/docs/jupyter-mcp-troubleshooting.md).