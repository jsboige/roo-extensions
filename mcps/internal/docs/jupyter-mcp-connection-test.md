# Guide de test pour la connexion MCP Jupyter

Ce guide explique comment tester les modifications apportées au serveur MCP Jupyter, en particulier la possibilité de changer le paramètre du serveur Jupyter cible après l'avoir démarré manuellement.

## 1. Démarrage manuel d'un serveur Jupyter

Avant de tester la connexion MCP, vous devez démarrer un serveur Jupyter:

### Option 1: Utiliser le script de démarrage manuel

```bash
# Windows
scripts\mcp-starters\start-jupyter-manual.bat
```

Sélectionnez l'option 1 pour démarrer uniquement le serveur Jupyter.

### Option 2: Démarrer Jupyter directement

```bash
# Windows
jupyter notebook

# Linux/macOS
jupyter notebook
```

### Résultats attendus
- Un serveur Jupyter démarre et affiche des informations dans le terminal
- Un message indique l'URL du serveur (généralement http://localhost:8888)
- Un token d'authentification est affiché (notez-le pour plus tard)

Exemple de sortie:
```
[I 10:00:00 NotebookApp] Serving notebooks from local directory: /path/to/directory
[I 10:00:00 NotebookApp] Jupyter Notebook 6.4.12 is running at:
[I 10:00:00 NotebookApp] http://localhost:8888/?token=abcdef123456...
[I 10:00:00 NotebookApp] or http://127.0.0.1:8888/?token=abcdef123456...
```

## 2. Vérification du démarrage en mode hors ligne par défaut

Pour vérifier que le MCP Jupyter démarre en mode hors ligne par défaut:

### Étape 1: Démarrer le serveur MCP Jupyter avec le script offline

```bash
# Windows
scripts\mcp-starters\start-jupyter-mcp-offline.bat

# Linux/macOS
./scripts/mcp-starters/start-jupyter-mcp-offline.sh

# JavaScript
node scripts/mcp-starters/start-jupyter-mcp-offline.js
```

### Résultats attendus
- Le serveur MCP Jupyter démarre sans erreur
- Un message indique que le mode hors ligne est activé:
  ```
  Mode hors ligne activé - Le client MCP ne tentera pas de se connecter au serveur Jupyter
  ```
- Aucune erreur de connexion n'est affichée (comme "Erreur lors de la vérification de la version de l'API Jupyter: AxiosError: socket hang up")

## 3. Configuration et test de la connexion à un serveur Jupyter en cours d'exécution

Une fois que vous avez un serveur Jupyter en cours d'exécution et un serveur MCP Jupyter démarré en mode hors ligne, vous pouvez configurer et tester la connexion:

### Option 1: Utiliser le script de connexion

```bash
# Windows
scripts\mcp-starters\start-jupyter-mcp-connect.bat
```

Suivez les instructions à l'écran:
1. Entrez l'URL du serveur Jupyter (par défaut: http://localhost:8888)
2. Entrez le token d'authentification (celui affiché lors du démarrage de Jupyter)
3. Confirmez les informations

### Option 2: Modifier manuellement le fichier de configuration

1. Ouvrez le fichier `servers/jupyter-mcp-server/config.json`
2. Modifiez-le pour qu'il ressemble à ceci:
   ```json
   {
     "jupyterServer": {
       "baseUrl": "http://localhost:8888",
       "token": "votre_token_ici"
     }
   }
   ```
3. Remplacez `votre_token_ici` par le token affiché lors du démarrage de Jupyter

### Étape 3: Tester la connexion

Pour tester que la connexion fonctionne correctement:

```bash
# Windows
node tests/test-jupyter-connection.js

# Linux/macOS
node tests/test-jupyter-connection.js
```

### Résultats attendus
- Le script affiche "✅ Connexion réussie au serveur Jupyter avec le token"
- La sortie montre un tableau JSON des kernels disponibles

## 4. Vérification du fonctionnement correct de la connexion

Pour vérifier que la connexion fonctionne correctement et que vous pouvez utiliser les outils MCP Jupyter:

### Étape 1: Exécuter le script de test MCP

```bash
# Windows
node tests/test-mcp-jupyter-tool.js

# Linux/macOS
node tests/test-mcp-jupyter-tool.js
```

### Étape 2: Vérifier l'état du serveur MCP

```bash
# Windows
node tests/test-mcp-status.js

# Linux/macOS
node tests/test-mcp-status.js
```

### Résultats attendus
- Le script de test MCP affiche des simulations d'appels d'outils MCP
- Le script de vérification d'état affiche:
  - Les processus en cours d'exécution (incluant node.exe pour le serveur MCP)
  - La configuration du serveur MCP Jupyter
  - Un code de statut HTTP 200 pour l'accessibilité du serveur Jupyter

### Étape 3: Tester avec Roo (si disponible)

Si vous utilisez Roo, vous pouvez tester les outils MCP Jupyter avec les commandes suivantes:

```
<use_mcp_tool>
<server_name>jupyter</server_name>
<tool_name>list_kernels</tool_name>
<arguments>
{}
</arguments>
</use_mcp_tool>
```

## Conseils de dépannage

### Problème: Erreur de connexion au serveur Jupyter

**Symptômes:**
```
Erreur lors de la vérification de la version de l'API Jupyter: AxiosError: socket hang up
```

**Solutions:**
1. Vérifiez que le serveur Jupyter est bien en cours d'exécution
2. Vérifiez que l'URL dans le fichier de configuration est correcte
3. Vérifiez que le token dans le fichier de configuration est correct
4. Vérifiez qu'aucun pare-feu ne bloque la connexion

### Problème: Le serveur MCP ne démarre pas en mode hors ligne

**Symptômes:**
- Des erreurs de connexion apparaissent même avec l'option --offline

**Solutions:**
1. Vérifiez que vous utilisez bien le script avec l'option --offline
2. Essayez de définir la variable d'environnement `JUPYTER_MCP_OFFLINE=true`
3. Vérifiez que le code du serveur MCP prend bien en compte l'option --offline

### Problème: Le serveur MCP ne se connecte pas au serveur Jupyter même après configuration

**Symptômes:**
- Le test de connexion échoue avec "❌ Échec de la connexion au serveur Jupyter avec le token"

**Solutions:**
1. Vérifiez que le serveur Jupyter est toujours en cours d'exécution
2. Vérifiez que le token n'a pas expiré (redémarrez Jupyter si nécessaire)
3. Essayez de redémarrer le serveur MCP après avoir modifié la configuration
4. Vérifiez que le format du fichier de configuration est correct (JSON valide)

## Conclusion

Ce guide vous a montré comment:
1. Démarrer manuellement un serveur Jupyter
2. Vérifier que le MCP Jupyter démarre en mode hors ligne par défaut
3. Configurer et tester la connexion à un serveur Jupyter en cours d'exécution
4. Vérifier que la connexion fonctionne correctement

En suivant ces étapes, vous pouvez confirmer que les modifications apportées fonctionnent correctement et que vous pouvez changer le paramètre du serveur Jupyter cible après avoir démarré manuellement Jupyter.