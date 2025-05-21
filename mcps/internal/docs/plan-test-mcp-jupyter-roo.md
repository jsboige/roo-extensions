# Plan de Test pour le MCP Jupyter avec Roo

Ce plan détaille les étapes à suivre pour tester manuellement le MCP Jupyter avec Roo, en utilisant une conversation Roo plutôt que des scripts automatisés.

## 1. Préparation

### 1.1 Démarrage manuel d'un serveur Jupyter

1. **Ouvrir un terminal et démarrer un serveur Jupyter**:
   ```bash
   # Option 1: Utiliser le script de démarrage
   scripts\mcp-starters\start-jupyter-manual.bat
   
   # Option 2: Commande directe
   jupyter notebook --NotebookApp.token=test_token --NotebookApp.allow_origin='*' --no-browser
   ```

2. **Noter les informations de connexion**:
   - URL du serveur (généralement http://localhost:8888)
   - Token d'authentification (affiché dans le terminal)
   - Exemple de sortie attendue:
   ```
   [I 10:00:00 NotebookApp] Serving notebooks from local directory: /path/to/directory
   [I 10:00:00 NotebookApp] Jupyter Notebook 6.4.12 is running at:
   [I 10:00:00 NotebookApp] http://localhost:8888/?token=test_token
   ```

### 1.2 Configuration du MCP Jupyter

1. **Vérifier le fichier de configuration du MCP Jupyter**:
   - Ouvrir le fichier `servers/jupyter-mcp-server/config.json`
   - S'assurer qu'il contient les informations correctes:
   ```json
   {
     "jupyterServer": {
       "baseUrl": "http://localhost:8888",
       "token": "test_token",
       "offline": false
     }
   }
   ```
   - Remplacer `"test_token"` par le token noté précédemment

2. **Vérifier le fichier de configuration de Roo**:
   - Localiser le fichier `mcp_settings.json` (généralement dans `C:/Users/[votre_nom]/AppData/Roaming/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json`)
   - S'assurer qu'il contient une entrée pour le serveur Jupyter:
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
   - Remplacer `"chemin/vers/votre/projet"` par le chemin absolu vers votre répertoire de projet

### 1.3 Démarrage du MCP Jupyter

1. **Démarrer le serveur MCP Jupyter**:
   ```bash
   # Windows
   scripts\mcp-starters\start-jupyter-mcp.bat
   
   # Linux/macOS
   ./scripts/mcp-starters/start-jupyter-mcp.sh
   
   # Ou directement avec Node.js
   node scripts/mcp-starters/start-jupyter-mcp.js
   ```

2. **Vérifier le message de démarrage**:
   - Le terminal devrait afficher un message indiquant que le serveur MCP est démarré
   - Aucune erreur de connexion ne devrait apparaître

### 1.4 Vérification de la configuration

1. **Ouvrir une conversation avec Roo**
2. **Vérifier que le MCP Jupyter est correctement configuré**:
   ```
   <use_mcp_tool>
   <server_name>jupyter</server_name>
   <tool_name>get_offline_status</tool_name>
   <arguments>
   {}
   </arguments>
   </use_mcp_tool>
   ```
   - La réponse devrait indiquer que le mode hors ligne est désactivé

## 2. Tests en mode connecté

### 2.1 Test des fonctionnalités de base

1. **Lister les kernels disponibles**:
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
   - Noter un ID de kernel pour les tests suivants

2. **Démarrer un nouveau kernel**:
   ```
   <use_mcp_tool>
   <server_name>jupyter</server_name>
   <tool_name>start_kernel</tool_name>
   <arguments>
   {
     "kernel_name": "python3"
   }
   </arguments>
   </use_mcp_tool>
   ```
   - La réponse devrait inclure un ID de kernel
   - Noter cet ID pour les tests suivants

### 2.2 Test de manipulation de notebooks

1. **Créer un nouveau notebook**:
   ```
   <use_mcp_tool>
   <server_name>jupyter</server_name>
   <tool_name>create_notebook</tool_name>
   <arguments>
   {
     "path": "tests/test_notebook_roo.ipynb",
     "kernel": "python3"
   }
   </arguments>
   </use_mcp_tool>
   ```
   - La réponse devrait confirmer la création du notebook

2. **Ajouter une cellule au notebook**:
   ```
   <use_mcp_tool>
   <server_name>jupyter</server_name>
   <tool_name>add_cell</tool_name>
   <arguments>
   {
     "path": "tests/test_notebook_roo.ipynb",
     "cell_type": "code",
     "source": "print('Hello from Jupyter MCP!')"
   }
   </arguments>
   </use_mcp_tool>
   ```
   - La réponse devrait confirmer l'ajout de la cellule

3. **Lire le contenu du notebook**:
   ```
   <use_mcp_tool>
   <server_name>jupyter</server_name>
   <tool_name>read_notebook</tool_name>
   <arguments>
   {
     "path": "tests/test_notebook_roo.ipynb"
   }
   </arguments>
   </use_mcp_tool>
   ```
   - La réponse devrait afficher le contenu du notebook, incluant la cellule ajoutée

### 2.3 Test d'exécution de code

1. **Exécuter une cellule de code**:
   ```
   <use_mcp_tool>
   <server_name>jupyter</server_name>
   <tool_name>execute_cell</tool_name>
   <arguments>
   {
     "kernel_id": "KERNEL_ID",
     "code": "import sys\nprint(f'Python version: {sys.version}')\nprint('Hello from Jupyter!')"
   }
   </arguments>
   </use_mcp_tool>
   ```
   - Remplacer `KERNEL_ID` par l'ID du kernel noté précédemment
   - La réponse devrait inclure la sortie du code Python exécuté

2. **Exécuter une cellule avec des calculs mathématiques**:
   ```
   <use_mcp_tool>
   <server_name>jupyter</server_name>
   <tool_name>execute_cell</tool_name>
   <arguments>
   {
     "kernel_id": "KERNEL_ID",
     "code": "import numpy as np\nx = np.array([1, 2, 3, 4, 5])\nprint(f'Mean: {np.mean(x)}')\nprint(f'Sum: {np.sum(x)}')"
   }
   </arguments>
   </use_mcp_tool>
   ```
   - La réponse devrait inclure les résultats des calculs

3. **Exécuter une cellule avec visualisation (si matplotlib est disponible)**:
   ```
   <use_mcp_tool>
   <server_name>jupyter</server_name>
   <tool_name>execute_cell</tool_name>
   <arguments>
   {
     "kernel_id": "KERNEL_ID",
     "code": "import matplotlib.pyplot as plt\nimport numpy as np\nx = np.linspace(0, 10, 100)\nplt.figure()\nplt.plot(x, np.sin(x))\nplt.title('Sine Wave')\nplt.show()"
   }
   </arguments>
   </use_mcp_tool>
   ```
   - La réponse devrait indiquer que la visualisation a été générée

### 2.4 Test de gestion des kernels

1. **Redémarrer un kernel**:
   ```
   <use_mcp_tool>
   <server_name>jupyter</server_name>
   <tool_name>restart_kernel</tool_name>
   <arguments>
   {
     "kernel_id": "KERNEL_ID"
   }
   </arguments>
   </use_mcp_tool>
   ```
   - La réponse devrait confirmer le redémarrage du kernel

2. **Vérifier que les variables ont été réinitialisées**:
   ```
   <use_mcp_tool>
   <server_name>jupyter</server_name>
   <tool_name>execute_cell</tool_name>
   <arguments>
   {
     "kernel_id": "KERNEL_ID",
     "code": "try:\n    print(x)\nexcept NameError:\n    print('Variable x not defined')"
   }
   </arguments>
   </use_mcp_tool>
   ```
   - La réponse devrait indiquer que la variable x n'est pas définie

3. **Arrêter un kernel**:
   ```
   <use_mcp_tool>
   <server_name>jupyter</server_name>
   <tool_name>stop_kernel</tool_name>
   <arguments>
   {
     "kernel_id": "KERNEL_ID"
   }
   </arguments>
   </use_mcp_tool>
   ```
   - La réponse devrait confirmer l'arrêt du kernel

## 3. Tests en mode hors ligne

### 3.1 Passage en mode hors ligne

1. **Modifier le fichier de configuration**:
   - Ouvrir le fichier `servers/jupyter-mcp-server/config.json`
   - Modifier le paramètre `offline` pour activer le mode hors ligne:
   ```json
   {
     "jupyterServer": {
       "baseUrl": "http://localhost:8888",
       "token": "test_token",
       "offline": true
     }
   }
   ```
   - Sauvegarder le fichier

2. **Vérifier le changement de mode**:
   ```
   <use_mcp_tool>
   <server_name>jupyter</server_name>
   <tool_name>get_offline_status</tool_name>
   <arguments>
   {}
   </arguments>
   </use_mcp_tool>
   ```
   - La réponse devrait indiquer que le mode hors ligne est maintenant activé

### 3.2 Test des fonctionnalités en mode hors ligne

1. **Tenter de lister les kernels**:
   ```
   <use_mcp_tool>
   <server_name>jupyter</server_name>
   <tool_name>list_kernels</tool_name>
   <arguments>
   {}
   </arguments>
   </use_mcp_tool>
   ```
   - La réponse devrait indiquer que cette fonctionnalité n'est pas disponible en mode hors ligne

2. **Créer un nouveau notebook en mode hors ligne**:
   ```
   <use_mcp_tool>
   <server_name>jupyter</server_name>
   <tool_name>create_notebook</tool_name>
   <arguments>
   {
     "path": "tests/test_notebook_offline.ipynb",
     "kernel": "python3"
   }
   </arguments>
   </use_mcp_tool>
   ```
   - Observer si cette fonctionnalité est disponible en mode hors ligne

3. **Ajouter une cellule au notebook en mode hors ligne**:
   ```
   <use_mcp_tool>
   <server_name>jupyter</server_name>
   <tool_name>add_cell</tool_name>
   <arguments>
   {
     "path": "tests/test_notebook_offline.ipynb",
     "cell_type": "code",
     "source": "print('This is an offline test')"
   }
   </arguments>
   </use_mcp_tool>
   ```
   - Observer si cette fonctionnalité est disponible en mode hors ligne

4. **Tenter d'exécuter du code en mode hors ligne**:
   ```
   <use_mcp_tool>
   <server_name>jupyter</server_name>
   <tool_name>execute_cell</tool_name>
   <arguments>
   {
     "kernel_id": "simulated-kernel",
     "code": "print('Hello from offline mode')"
   }
   </arguments>
   </use_mcp_tool>
   ```
   - La réponse devrait indiquer que cette fonctionnalité n'est pas disponible en mode hors ligne ou fournir une simulation

### 3.3 Passage dynamique entre les modes

1. **Désactiver le mode hors ligne via l'outil MCP**:
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
   - La réponse devrait confirmer le changement de mode

2. **Vérifier que le mode hors ligne est désactivé**:
   ```
   <use_mcp_tool>
   <server_name>jupyter</server_name>
   <tool_name>get_offline_status</tool_name>
   <arguments>
   {}
   </arguments>
   </use_mcp_tool>
   ```
   - La réponse devrait indiquer que le mode hors ligne est désactivé

3. **Tester une fonctionnalité qui nécessite une connexion**:
   ```
   <use_mcp_tool>
   <server_name>jupyter</server_name>
   <tool_name>list_kernels</tool_name>
   <arguments>
   {}
   </arguments>
   </use_mcp_tool>
   ```
   - La réponse devrait maintenant afficher la liste des kernels disponibles

4. **Réactiver le mode hors ligne**:
   ```
   <use_mcp_tool>
   <server_name>jupyter</server_name>
   <tool_name>set_offline_mode</tool_name>
   <arguments>
   {
     "enabled": true
   }
   </arguments>
   </use_mcp_tool>
   ```
   - La réponse devrait confirmer le changement de mode

## 4. Vérification finale

### 4.1 Vérification du comportement au démarrage

1. **Arrêter le serveur MCP Jupyter** (Ctrl+C dans le terminal)

2. **Configurer le mode hors ligne par défaut**:
   - Ouvrir le fichier `servers/jupyter-mcp-server/config.json`
   - S'assurer que le mode hors ligne est activé:
   ```json
   {
     "jupyterServer": {
       "baseUrl": "http://localhost:8888",
       "token": "test_token",
       "offline": true
     }
   }
   ```

3. **Redémarrer le serveur MCP Jupyter**:
   ```bash
   scripts\mcp-starters\start-jupyter-mcp.bat
   ```

4. **Vérifier qu'aucune invite de commande supplémentaire n'est lancée**:
   - Observer qu'aucune fenêtre de terminal supplémentaire n'est ouverte
   - Vérifier qu'aucune tentative de connexion n'est effectuée au démarrage

5. **Vérifier le mode hors ligne**:
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

### 4.2 Vérification du fonctionnement en mode connecté et hors ligne

1. **Créer un tableau récapitulatif des fonctionnalités testées**:

   | Fonctionnalité | Mode hors ligne | Mode connecté | Résultat |
   |----------------|-----------------|---------------|----------|
   | Démarrage du serveur | ✓ | ✓ | |
   | `get_offline_status` | ✓ | ✓ | |
   | `set_offline_mode` | ✓ | ✓ | |
   | `list_kernels` | ✗ | ✓ | |
   | `start_kernel` | ✗ | ✓ | |
   | `restart_kernel` | ✗ | ✓ | |
   | `stop_kernel` | ✗ | ✓ | |
   | `create_notebook` | ? | ✓ | |
   | `read_notebook` | ? | ✓ | |
   | `write_notebook` | ? | ✓ | |
   | `add_cell` | ? | ✓ | |
   | `execute_cell` | ✗ | ✓ | |
   | `execute_notebook` | ✗ | ✓ | |
   | Changement de mode | ✓ | ✓ | |

2. **Remplir le tableau avec les résultats des tests**:
   - Pour chaque fonctionnalité, indiquer si elle fonctionne (✓), ne fonctionne pas (✗) ou fonctionne partiellement (?)
   - Noter tout comportement inattendu ou problème rencontré

### 4.3 Documentation des résultats

1. **Créer un rapport de validation**:
   - Créer un fichier `docs/jupyter-mcp-validation-report.md`
   - Documenter les résultats des tests
   - Inclure des captures d'écran des étapes clés
   - Noter les problèmes rencontrés et leurs solutions

2. **Format recommandé pour le rapport**:
   ```markdown
   # Rapport de validation du MCP Jupyter avec Roo
   
   ## Environnement de test
   - Date : [date]
   - Version de Roo : [version]
   - Version de Jupyter : [version]
   - Système d'exploitation : [OS]
   
   ## Résultats des tests
   
   ### 1. Tests en mode connecté
   - [Résultats]
   
   ### 2. Tests en mode hors ligne
   - [Résultats]
   
   ### 3. Tests de changement de configuration
   - [Résultats]
   
   ## Problèmes rencontrés
   - [Liste des problèmes]
   
   ## Conclusion
   - [Conclusion générale]
   ```

## Résumé des commandes MCP Jupyter pour Roo

Voici un résumé des commandes MCP Jupyter que vous pouvez utiliser dans la conversation Roo:

### Gestion du mode hors ligne
```
<use_mcp_tool>
<server_name>jupyter</server_name>
<tool_name>get_offline_status</tool_name>
<arguments>
{}
</arguments>
</use_mcp_tool>

<use_mcp_tool>
<server_name>jupyter</server_name>
<tool_name>set_offline_mode</tool_name>
<arguments>
{
  "enabled": true|false
}
</arguments>
</use_mcp_tool>
```

### Gestion des kernels
```
<use_mcp_tool>
<server_name>jupyter</server_name>
<tool_name>list_kernels</tool_name>
<arguments>
{}
</arguments>
</use_mcp_tool>

<use_mcp_tool>
<server_name>jupyter</server_name>
<tool_name>start_kernel</tool_name>
<arguments>
{
  "kernel_name": "python3"
}
</arguments>
</use_mcp_tool>

<use_mcp_tool>
<server_name>jupyter</server_name>
<tool_name>restart_kernel</tool_name>
<arguments>
{
  "kernel_id": "KERNEL_ID"
}
</arguments>
</use_mcp_tool>

<use_mcp_tool>
<server_name>jupyter</server_name>
<tool_name>stop_kernel</tool_name>
<arguments>
{
  "kernel_id": "KERNEL_ID"
}
</arguments>
</use_mcp_tool>
```

### Gestion des notebooks
```
<use_mcp_tool>
<server_name>jupyter</server_name>
<tool_name>create_notebook</tool_name>
<arguments>
{
  "path": "chemin/vers/notebook.ipynb",
  "kernel": "python3"
}
</arguments>
</use_mcp_tool>

<use_mcp_tool>
<server_name>jupyter</server_name>
<tool_name>read_notebook</tool_name>
<arguments>
{
  "path": "chemin/vers/notebook.ipynb"
}
</arguments>
</use_mcp_tool>

<use_mcp_tool>
<server_name>jupyter</server_name>
<tool_name>add_cell</tool_name>
<arguments>
{
  "path": "chemin/vers/notebook.ipynb",
  "cell_type": "code|markdown|raw",
  "source": "contenu de la cellule"
}
</arguments>
</use_mcp_tool>
```

### Exécution de code
```
<use_mcp_tool>
<server_name>jupyter</server_name>
<tool_name>execute_cell</tool_name>
<arguments>
{
  "kernel_id": "KERNEL_ID",
  "code": "print('Hello from Jupyter!')"
}
</arguments>
</use_mcp_tool>

<use_mcp_tool>
<server_name>jupyter</server_name>
<tool_name>execute_notebook</tool_name>
<arguments>
{
  "path": "chemin/vers/notebook.ipynb",
  "kernel_id": "KERNEL_ID"
}
</arguments>
</use_mcp_tool>