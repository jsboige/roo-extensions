# Guide de test manuel pour valider le MCP Jupyter avec Roo

Ce guide détaille les étapes à suivre pour tester et valider le fonctionnement du serveur MCP Jupyter avec Roo. Il couvre la configuration initiale, les tests en mode hors ligne, les tests avec un serveur Jupyter actif, les tests de changement de configuration, et la validation finale.

## 1. Préparation

### 1.1 Configuration du fichier `mcp_settings.json`

1. **Localiser le fichier de configuration**
   - Le fichier se trouve généralement dans le dossier de configuration de Roo
   - Chemin typique : `C:/Users/[votre_nom]/AppData/Roaming/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json`

2. **Configurer le MCP Jupyter**
   - Ouvrez le fichier `mcp_settings.json` dans un éditeur de texte
   - Assurez-vous qu'il contient une entrée pour le serveur Jupyter :
   ```json
   {
     "mcp_servers": [
       {
         "name": "jupyter",
         "command": "node servers/jupyter-mcp-server/dist/index.js",
         "cwd": "chemin/vers/votre/projet"
       }
     ]
   }
   ```
   - Remplacez `"chemin/vers/votre/projet"` par le chemin absolu vers votre répertoire de projet

3. **Vérifier la configuration du serveur MCP Jupyter**
   - Créez ou modifiez le fichier `servers/jupyter-mcp-server/config.json` :
   ```json
   {
     "jupyterServer": {
       "baseUrl": "http://localhost:8888",
       "token": "test_token",
       "offline": true
     }
   }
   ```
   - Le paramètre `"offline": true` active le mode hors ligne par défaut

### 1.2 Vérification de l'installation

1. **Vérifier l'installation de Node.js**
   - Ouvrez un terminal et exécutez :
   ```bash
   node --version
   ```
   - Assurez-vous que la version est 14.0.0 ou supérieure

2. **Vérifier l'installation de Jupyter**
   - Ouvrez un terminal et exécutez :
   ```bash
   jupyter --version
   ```
   - Assurez-vous que Jupyter Notebook est installé

3. **Vérifier la compilation du serveur MCP Jupyter**
   - Assurez-vous que le dossier `servers/jupyter-mcp-server/dist/` existe et contient des fichiers JavaScript compilés
   - Si ce n'est pas le cas, exécutez :
   ```bash
   cd servers/jupyter-mcp-server
   npm install
   npm run build
   ```

4. **Capture d'écran de référence**

   ![Configuration initiale](../assets/jupyter-mcp-config-initial.png)
   *Figure 1: Exemple de configuration initiale correcte*

## 2. Tests en mode hors ligne

### 2.1 Démarrage du MCP Jupyter en mode hors ligne

1. **Démarrer le serveur MCP Jupyter**
   - Ouvrez un terminal et exécutez :
   ```bash
   # Windows
   scripts\mcp-starters\start-jupyter-mcp-offline.bat
   
   # Linux/macOS
   ./scripts/mcp-starters/start-jupyter-mcp-offline.sh
   
   # Ou directement avec Node.js
   node scripts/mcp-starters/start-jupyter-mcp-offline.js
   ```

2. **Vérifier le message de démarrage**
   - Vous devriez voir un message indiquant que le mode hors ligne est activé :
   ```
   Mode hors ligne activé - Le client MCP ne tentera pas de se connecter au serveur Jupyter
   ```
   - Aucune erreur de connexion ne devrait apparaître

3. **Capture d'écran attendue**

   ![Démarrage en mode hors ligne](../assets/jupyter-mcp-offline-start.png)
   *Figure 2: Message de démarrage en mode hors ligne*

### 2.2 Vérification des fonctionnalités en mode hors ligne

1. **Tester l'état du mode hors ligne**
   - Exécutez le script de test :
   ```bash
   node tests/test-jupyter-mcp-offline.js
   ```
   - Vérifiez que le résultat indique que le mode hors ligne est activé

2. **Tester les fonctionnalités disponibles**
   - Exécutez le script de test des fonctionnalités :
   ```bash
   node tests/test-jupyter-mcp-features.js
   ```
   - Notez quelles fonctionnalités sont disponibles en mode hors ligne
   - Les fonctionnalités comme `get_offline_status` devraient fonctionner

3. **Tester avec Roo**
   - Dans Roo, essayez d'utiliser l'outil MCP pour vérifier le statut hors ligne :
   ```
   <use_mcp_tool>
   <server_name>jupyter</server_name>
   <tool_name>get_offline_status</tool_name>
   <arguments>
   {}
   </arguments>
   </use_mcp_tool>
   ```
   - La réponse devrait indiquer que le mode hors ligne est activé

### 2.3 Identification des messages d'erreur normaux

1. **Tester les fonctionnalités nécessitant une connexion**
   - Dans Roo, essayez d'utiliser l'outil MCP pour lister les kernels :
   ```
   <use_mcp_tool>
   <server_name>jupyter</server_name>
   <tool_name>list_kernels</tool_name>
   <arguments>
   {}
   </arguments>
   </use_mcp_tool>
   ```
   - Vous devriez recevoir un message d'erreur indiquant que cette fonctionnalité n'est pas disponible en mode hors ligne

2. **Messages d'erreur attendus**
   - "Cette fonctionnalité nécessite une connexion au serveur Jupyter"
   - "Le serveur est en mode hors ligne"
   - "Veuillez activer le mode connecté pour utiliser cette fonctionnalité"

3. **Capture d'écran des erreurs normales**

   ![Erreurs en mode hors ligne](../assets/jupyter-mcp-offline-errors.png)
   *Figure 3: Messages d'erreur normaux en mode hors ligne*

## 3. Tests avec un serveur Jupyter

### 3.1 Démarrage d'un serveur Jupyter

1. **Démarrer un serveur Jupyter manuellement**
   - Ouvrez un nouveau terminal et exécutez :
   ```bash
   # Option 1: Script de démarrage
   scripts\mcp-starters\start-jupyter-manual.bat
   
   # Option 2: Commande directe
   jupyter notebook --NotebookApp.token=test_token --NotebookApp.allow_origin='*' --no-browser
   ```

2. **Vérifier le démarrage du serveur**
   - Le terminal devrait afficher des informations sur le serveur Jupyter
   - Notez l'URL (généralement http://localhost:8888) et le token d'authentification
   - Exemple de sortie :
   ```
   [I 10:00:00 NotebookApp] Serving notebooks from local directory: /path/to/directory
   [I 10:00:00 NotebookApp] Jupyter Notebook 6.4.12 is running at:
   [I 10:00:00 NotebookApp] http://localhost:8888/?token=test_token
   ```

3. **Capture d'écran du serveur démarré**

   ![Serveur Jupyter démarré](../assets/jupyter-server-started.png)
   *Figure 4: Serveur Jupyter démarré avec succès*

### 3.2 Configuration de Roo pour la connexion

1. **Modifier le fichier de configuration**
   - Ouvrez le fichier `servers/jupyter-mcp-server/config.json`
   - Modifiez-le pour désactiver le mode hors ligne :
   ```json
   {
     "jupyterServer": {
       "baseUrl": "http://localhost:8888",
       "token": "test_token",
       "offline": false
     }
   }
   ```
   - Assurez-vous que le token correspond à celui utilisé pour démarrer le serveur Jupyter

2. **Utiliser le script de connexion (alternative)**
   - Exécutez le script de connexion :
   ```bash
   scripts\mcp-starters\start-jupyter-mcp-connect.bat
   ```
   - Suivez les instructions à l'écran pour configurer la connexion

3. **Redémarrer le serveur MCP Jupyter**
   - Arrêtez le serveur MCP Jupyter (Ctrl+C dans le terminal)
   - Redémarrez-le avec :
   ```bash
   scripts\mcp-starters\start-jupyter-mcp.bat
   ```

### 3.3 Vérification de la connexion

1. **Tester la connexion**
   - Exécutez le script de test de connexion :
   ```bash
   node tests/test-jupyter-connection.js
   ```
   - Vérifiez que le résultat indique "✅ Connexion réussie au serveur Jupyter avec le token"

2. **Vérifier l'état du serveur MCP**
   - Exécutez le script de vérification d'état :
   ```bash
   node tests/test-mcp-status.js
   ```
   - Vérifiez que le statut indique que le serveur est connecté

3. **Capture d'écran de la connexion réussie**

   ![Connexion réussie](../assets/jupyter-mcp-connected.png)
   *Figure 5: Connexion réussie au serveur Jupyter*

### 3.4 Test des fonctionnalités après connexion

1. **Tester les fonctionnalités de base**
   - Exécutez le script de test des fonctionnalités :
   ```bash
   node tests/test-jupyter-mcp-features.js
   ```
   - Vérifiez que toutes les fonctionnalités sont disponibles

2. **Tester avec Roo**
   - Dans Roo, essayez d'utiliser l'outil MCP pour lister les kernels :
   ```
   <use_mcp_tool>
   <server_name>jupyter</server_name>
   <tool_name>list_kernels</tool_name>
   <arguments>
   {}
   </arguments>
   </use_mcp_tool>
   ```
   - La réponse devrait afficher la liste des kernels disponibles

3. **Tester l'exécution de code**
   - Dans Roo, essayez d'exécuter du code Python :
   ```
   <use_mcp_tool>
   <server_name>jupyter</server_name>
   <tool_name>execute_cell</tool_name>
   <arguments>
   {
     "kernel_id": "kernel-id-from-list-kernels",
     "code": "print('Hello from Jupyter!')"
   }
   </arguments>
   </use_mcp_tool>
   ```
   - Remplacez `kernel-id-from-list-kernels` par un ID de kernel obtenu précédemment
   - Vérifiez que le résultat contient la sortie "Hello from Jupyter!"

4. **Capture d'écran des fonctionnalités**

   ![Fonctionnalités en mode connecté](../assets/jupyter-mcp-features.png)
   *Figure 6: Fonctionnalités disponibles en mode connecté*

## 4. Tests de changement de configuration

### 4.1 Modification de la configuration pendant l'exécution

1. **Modifier le fichier de configuration**
   - Pendant que le serveur MCP Jupyter est en cours d'exécution, ouvrez le fichier `servers/jupyter-mcp-server/config.json`
   - Modifiez le paramètre `offline` :
   ```json
   {
     "jupyterServer": {
       "baseUrl": "http://localhost:8888",
       "token": "test_token",
       "offline": true
     }
   }
   ```
   - Sauvegardez le fichier

2. **Observer les logs du serveur**
   - Vérifiez que le serveur MCP Jupyter détecte le changement
   - Un message devrait indiquer que le mode hors ligne a été activé

3. **Capture d'écran du changement détecté**

   ![Changement de configuration détecté](../assets/jupyter-mcp-config-change.png)
   *Figure 7: Détection du changement de configuration*

### 4.2 Vérification de la prise en compte des changements

1. **Tester l'état du mode hors ligne**
   - Exécutez le script de test :
   ```bash
   node tests/test-jupyter-mcp-offline.js
   ```
   - Vérifiez que le résultat indique que le mode hors ligne est maintenant activé

2. **Tester les fonctionnalités**
   - Exécutez le script de test des fonctionnalités :
   ```bash
   node tests/test-jupyter-mcp-features.js
   ```
   - Vérifiez que les fonctionnalités nécessitant une connexion ne sont plus disponibles

3. **Tester avec Roo**
   - Dans Roo, essayez à nouveau d'utiliser l'outil MCP pour lister les kernels
   - Vous devriez maintenant recevoir un message d'erreur indiquant que cette fonctionnalité n'est pas disponible en mode hors ligne

### 4.3 Test du passage entre modes connecté et hors ligne

1. **Tester le passage dynamique**
   - Exécutez le script de test de changement de mode :
   ```bash
   node tests/test-jupyter-mcp-switch-offline.js
   ```
   - Ce script teste le passage entre le mode connecté et le mode hors ligne sans redémarrer le serveur

2. **Utiliser l'outil MCP pour changer de mode**
   - Dans Roo, utilisez l'outil MCP pour désactiver le mode hors ligne :
   ```
   <use_mcp_tool>
   <server_name>jupyter</server_name>
   <tool_name>set_offline_mode</tool_name>
   <arguments>
   {
     "enabled": false
   }
   </arguments>
   </use_mcp_tool>
   ```
   - Vérifiez que le serveur se connecte au serveur Jupyter

3. **Capture d'écran du changement de mode**

   ![Changement de mode](../assets/jupyter-mcp-mode-switch.png)
   *Figure 8: Passage entre les modes connecté et hors ligne*

## 5. Validation finale

### 5.1 Liste de vérification des fonctionnalités

Utilisez cette liste pour vérifier que toutes les fonctionnalités ont été testées avec succès :

| Fonctionnalité | Mode hors ligne | Mode connecté | Résultat |
|----------------|-----------------|---------------|----------|
| Démarrage du serveur | ✓ | ✓ | |
| `get_offline_status` | ✓ | ✓ | |
| `set_offline_mode` | ✓ | ✓ | |
| `list_kernels` | ✗ | ✓ | |
| `start_kernel` | ✗ | ✓ | |
| `restart_kernel` | ✗ | ✓ | |
| `stop_kernel` | ✗ | ✓ | |
| `create_notebook` | ✗ | ✓ | |
| `get_notebook_content` | ✗ | ✓ | |
| `write_notebook` | ✗ | ✓ | |
| `add_cell` | ✗ | ✓ | |
| `execute_cell` | ✗ | ✓ | |
| `execute_notebook` | ✗ | ✓ | |
| Changement de mode | ✓ | ✓ | |

### 5.2 Documentation des résultats

1. **Créer un rapport de validation**
   - Créez un fichier `docs/jupyter-mcp-validation-report.md`
   - Documentez les résultats des tests
   - Incluez des captures d'écran des étapes clés
   - Notez les problèmes rencontrés et leurs solutions

2. **Format recommandé pour le rapport**
   ```markdown
   # Rapport de validation du MCP Jupyter avec Roo
   
   ## Environnement de test
   - Date : [date]
   - Version de Roo : [version]
   - Version de Jupyter : [version]
   - Système d'exploitation : [OS]
   
   ## Résultats des tests
   
   ### 1. Tests en mode hors ligne
   - [Résultats]
   
   ### 2. Tests avec serveur Jupyter
   - [Résultats]
   
   ### 3. Tests de changement de configuration
   - [Résultats]
   
   ## Problèmes rencontrés
   - [Liste des problèmes]
   
   ## Conclusion
   - [Conclusion générale]
   ```

3. **Capture d'écran du rapport**

   ![Rapport de validation](../assets/jupyter-mcp-validation-report.png)
   *Figure 9: Exemple de rapport de validation*

### 5.3 Recommandations pour les commits et les pushs

1. **Utiliser le script d'automatisation**
   - Exécutez le script d'automatisation des tests et commits :
   ```bash
   node scripts/commit-jupyter-changes.js
   ```
   - Ce script vérifie que tous les tests sont réussis avant d'effectuer un commit

2. **Commit manuel**
   - Si vous préférez faire un commit manuel, assurez-vous que tous les tests sont réussis
   - Utilisez un message de commit descriptif :
   ```bash
   git add .
   git commit -m "Validation du MCP Jupyter avec Roo - Tous les tests réussis"
   ```

3. **Push vers le dépôt distant**
   - Après avoir validé les modifications localement, poussez-les vers le dépôt distant :
   ```bash
   git push origin main
   ```

4. **Capture d'écran du commit réussi**

   ![Commit réussi](../assets/jupyter-mcp-commit.png)
   *Figure 10: Commit réussi après validation*

## Conclusion

Ce guide vous a permis de tester et valider le fonctionnement du MCP Jupyter avec Roo. En suivant ces étapes, vous avez vérifié :

1. La configuration correcte du MCP Jupyter
2. Le fonctionnement en mode hors ligne
3. La connexion à un serveur Jupyter
4. Le passage dynamique entre les modes
5. Toutes les fonctionnalités disponibles

Si vous avez rencontré des problèmes pendant les tests, consultez le document [jupyter-mcp-troubleshooting.md](jupyter-mcp-troubleshooting.md) pour des solutions aux problèmes courants.

Pour plus d'informations sur le mode hors ligne, consultez [jupyter-mcp-offline-mode.md](jupyter-mcp-offline-mode.md).

Pour les tests de connexion, consultez [jupyter-mcp-connection-test.md](jupyter-mcp-connection-test.md).