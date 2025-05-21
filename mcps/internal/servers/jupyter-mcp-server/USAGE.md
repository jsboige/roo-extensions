# Utilisation du serveur MCP Jupyter

<!-- START_SECTION: introduction -->
Ce document fournit des exemples détaillés d'utilisation et des bonnes pratiques pour le serveur MCP Jupyter. Vous y trouverez des exemples concrets pour chaque outil exposé par le serveur, ainsi que des scénarios d'utilisation avancés.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: getting_started -->
## Démarrage du serveur

### Démarrage du serveur Jupyter

Avant d'utiliser le serveur MCP Jupyter, vous devez démarrer un serveur Jupyter avec les options recommandées :

```bash
jupyter notebook --NotebookApp.token=test_token --NotebookApp.allow_origin='*' --no-browser
```

> **Note importante** : L'option `--NotebookApp.allow_origin='*'` est nécessaire pour permettre au serveur MCP Jupyter de se connecter au serveur Jupyter. L'option `--NotebookApp.token=test_token` définit un token d'authentification simple pour le serveur Jupyter. En production, utilisez un token plus sécurisé.

### Démarrage standard du serveur MCP Jupyter

Pour démarrer le serveur MCP Jupyter avec la configuration par défaut :

```bash
cd servers/jupyter-mcp-server
npm start
```

### Démarrage avec options

Pour démarrer le serveur avec des options spécifiques :

```bash
# Spécifier un port différent
npm start -- --port 4000

# Spécifier un fichier de configuration personnalisé
npm start -- --config ./config/production.json

# Spécifier l'URL et le token du serveur Jupyter
npm start -- --url http://localhost:8888 --token votre_token_ici
```

### Démarrage en mode hors ligne

Pour démarrer le serveur en mode hors ligne (sans tenter de se connecter à un serveur Jupyter) :

```bash
npm start -- --offline true
```

### Démarrage en mode développement

Pour démarrer le serveur en mode développement avec rechargement automatique :

```bash
npm run dev
```

### Vérification du fonctionnement

Une fois le serveur démarré, vous pouvez vérifier qu'il fonctionne correctement en exécutant le script de test :

```bash
cd mcps/mcp-servers/tests
node test-jupyter-connection.js
```

Vous devriez voir une sortie confirmant que le serveur est opérationnel et que les outils fonctionnent correctement.
<!-- END_SECTION: getting_started -->

<!-- START_SECTION: client_connection -->
## Connexion d'un client MCP

Pour utiliser le serveur MCP Jupyter, vous devez le connecter à un client MCP. Voici comment procéder avec différents clients :

### Connexion avec le client MCP JavaScript

```javascript
const { MCPClient } = require('@modelcontextprotocol/client');

async function connectToJupyterMCP() {
  const client = new MCPClient();
  
  // Connexion au serveur MCP Jupyter
  await client.connect('http://localhost:3000');
  
  // Vérification des outils disponibles
  const tools = await client.listTools();
  console.log('Outils disponibles:', tools);
  
  return client;
}

// Utilisation
connectToJupyterMCP().then(client => {
  // Utiliser le client pour appeler les outils Jupyter MCP
});
```

### Connexion avec Roo

Dans la configuration de Roo, ajoutez le serveur MCP Jupyter dans la section des serveurs MCP :

```json
{
  "servers": [
    {
      "name": "jupyter",
      "url": "http://localhost:3000",
      "type": "mcp"
    }
  ]
}
```

### Connexion avec d'autres clients MCP

Pour d'autres clients MCP, consultez la documentation spécifique du client. En général, vous devrez fournir l'URL du serveur MCP Jupyter (par défaut `http://localhost:3000`).
<!-- END_SECTION: client_connection -->

<!-- START_SECTION: notebook_management -->
## Gestion des notebooks

### Lecture d'un notebook

L'outil `read_notebook` permet de lire le contenu d'un notebook Jupyter à partir d'un fichier.

```javascript
const result = await client.callTool('jupyter-mcp-server', 'read_notebook', {
  path: './mon-notebook.ipynb'
});

console.log(result.notebook);  // Contenu du notebook
console.log(result.notebook.cells.length);  // Nombre de cellules
```

### Création d'un notebook

L'outil `create_notebook` permet de créer un nouveau notebook vide.

```javascript
const result = await client.callTool('jupyter-mcp-server', 'create_notebook', {
  path: './nouveau-notebook.ipynb',
  kernel: 'python3'
});

console.log(result.notebook);  // Notebook vide
console.log(result.success);  // true
```

### Écriture d'un notebook

L'outil `write_notebook` permet d'écrire/sauvegarder un notebook Jupyter dans un fichier.

```javascript
// Lire un notebook existant
const readResult = await client.callTool('jupyter-mcp-server', 'read_notebook', {
  path: './mon-notebook.ipynb'
});

// Modifier le notebook
readResult.notebook.metadata.title = "Nouveau titre";

// Écrire le notebook modifié
const writeResult = await client.callTool('jupyter-mcp-server', 'write_notebook', {
  path: './mon-notebook-modifié.ipynb',
  content: readResult.notebook
});

console.log(writeResult.success);  // true
console.log(writeResult.message);  // "Notebook écrit avec succès: ./mon-notebook-modifié.ipynb"
```

### Ajout d'une cellule

L'outil `add_cell` permet d'ajouter une cellule à un notebook.

```javascript
// Ajouter une cellule de code
const codeResult = await client.callTool('jupyter-mcp-server', 'add_cell', {
  path: './mon-notebook.ipynb',
  cell_type: 'code',
  source: 'print("Hello, world!")',
  metadata: { tags: ['example'] }
});

console.log(codeResult.cell_index);  // Index de la nouvelle cellule

// Ajouter une cellule markdown
const markdownResult = await client.callTool('jupyter-mcp-server', 'add_cell', {
  path: './mon-notebook.ipynb',
  cell_type: 'markdown',
  source: '# Titre\n\nCeci est un paragraphe.'
});

console.log(markdownResult.cell_index);  // Index de la nouvelle cellule
```

### Suppression d'une cellule

L'outil `remove_cell` permet de supprimer une cellule d'un notebook.

```javascript
const result = await client.callTool('jupyter-mcp-server', 'remove_cell', {
  path: './mon-notebook.ipynb',
  index: 2  // Supprimer la troisième cellule (index 2)
});

console.log(result.success);  // true
console.log(result.message);  // "Cellule supprimée avec succès du notebook: ./mon-notebook.ipynb"
```

### Modification d'une cellule

L'outil `update_cell` permet de modifier une cellule d'un notebook.

```javascript
const result = await client.callTool('jupyter-mcp-server', 'update_cell', {
  path: './mon-notebook.ipynb',
  index: 0,  // Modifier la première cellule (index 0)
  source: '# Titre modifié'
});

console.log(result.success);  // true
console.log(result.message);  // "Cellule modifiée avec succès dans le notebook: ./mon-notebook.ipynb"
```

### Bonnes pratiques pour la gestion des notebooks

- Utilisez des chemins absolus ou relatifs au répertoire de travail du serveur MCP Jupyter
- Sauvegardez régulièrement les notebooks modifiés
- Utilisez des noms de fichiers descriptifs pour les notebooks
- Organisez les notebooks dans des répertoires thématiques
- Incluez des métadonnées utiles dans les notebooks (titre, auteur, description)
<!-- END_SECTION: notebook_management -->

<!-- START_SECTION: kernel_management -->
## Gestion des kernels

### Liste des kernels disponibles

L'outil `list_kernels` permet de lister les kernels disponibles et actifs.

```javascript
const result = await client.callTool('jupyter-mcp-server', 'list_kernels', {});

console.log(result.available_kernels);  // Liste des kernels disponibles
console.log(result.active_kernels);  // Liste des kernels actifs
```

### Démarrage d'un kernel

L'outil `start_kernel` permet de démarrer un nouveau kernel.

```javascript
const result = await client.callTool('jupyter-mcp-server', 'start_kernel', {
  kernel_name: 'python3'
});

console.log(result.kernel_id);  // ID du kernel démarré
console.log(result.kernel_name);  // Nom du kernel démarré
```

### Arrêt d'un kernel

L'outil `stop_kernel` permet d'arrêter un kernel actif.

```javascript
const result = await client.callTool('jupyter-mcp-server', 'stop_kernel', {
  kernel_id: 'kernel-id-1'
});

console.log(result.success);  // true
console.log(result.message);  // "Kernel arrêté avec succès: kernel-id-1"
```

### Interruption d'un kernel

L'outil `interrupt_kernel` permet d'interrompre l'exécution d'un kernel.

```javascript
const result = await client.callTool('jupyter-mcp-server', 'interrupt_kernel', {
  kernel_id: 'kernel-id-1'
});

console.log(result.success);  // true
console.log(result.message);  // "Kernel interrompu avec succès: kernel-id-1"
```

### Redémarrage d'un kernel

L'outil `restart_kernel` permet de redémarrer un kernel.

```javascript
const result = await client.callTool('jupyter-mcp-server', 'restart_kernel', {
  kernel_id: 'kernel-id-1'
});

console.log(result.success);  // true
console.log(result.message);  // "Kernel redémarré avec succès: kernel-id-1"
```

### Bonnes pratiques pour la gestion des kernels

- Arrêtez les kernels inutilisés pour libérer des ressources
- Utilisez le kernel approprié pour chaque notebook (Python pour le calcul scientifique, R pour les statistiques, etc.)
- Redémarrez les kernels en cas de problème ou de fuite de mémoire
- Limitez le nombre de kernels actifs simultanément
<!-- END_SECTION: kernel_management -->

<!-- START_SECTION: code_execution -->
## Exécution de code

### Exécution d'une cellule de code

L'outil `execute_cell` permet d'exécuter du code dans un kernel spécifique.

```javascript
const result = await client.callTool('jupyter-mcp-server', 'execute_cell', {
  kernel_id: 'kernel-id-1',
  code: 'print("Hello, world!")'
});

console.log(result.execution_count);  // Numéro d'exécution
console.log(result.status);  // "ok" ou "error"
console.log(result.outputs);  // Sorties de l'exécution
```

### Exécution d'un notebook complet

L'outil `execute_notebook` permet d'exécuter toutes les cellules de code d'un notebook.

```javascript
const result = await client.callTool('jupyter-mcp-server', 'execute_notebook', {
  path: './mon-notebook.ipynb',
  kernel_id: 'kernel-id-1'
});

console.log(result.success);  // true
console.log(result.message);  // "Notebook exécuté avec succès: ./mon-notebook.ipynb"
console.log(result.cell_count);  // Nombre de cellules dans le notebook
```

### Exécution d'une cellule spécifique d'un notebook

L'outil `execute_notebook_cell` permet d'exécuter une cellule spécifique d'un notebook.

```javascript
const result = await client.callTool('jupyter-mcp-server', 'execute_notebook_cell', {
  path: './mon-notebook.ipynb',
  cell_index: 2,  // Exécuter la troisième cellule (index 2)
  kernel_id: 'kernel-id-1'
});

console.log(result.success);  // true
console.log(result.message);  // "Cellule exécutée avec succès: ./mon-notebook.ipynb[2]"
console.log(result.execution_count);  // Numéro d'exécution
console.log(result.outputs);  // Sorties de l'exécution
```

### Gestion des sorties d'exécution

Les sorties d'exécution peuvent être de différents types :

```javascript
// Exemple de traitement des sorties
const result = await client.callTool('jupyter-mcp-server', 'execute_cell', {
  kernel_id: 'kernel-id-1',
  code: `
    print("Texte standard")
    import sys
    print("Erreur", file=sys.stderr)
    
    import matplotlib.pyplot as plt
    import numpy as np
    x = np.linspace(0, 2*np.pi, 100)
    y = np.sin(x)
    plt.plot(x, y)
    plt.show()
    
    from IPython.display import HTML
    HTML("<h1>Titre HTML</h1>")
  `
});

// Traitement des différents types de sorties
result.outputs.forEach(output => {
  switch (output.output_type) {
    case 'stream':
      console.log(`${output.name}: ${output.text}`);  // stdout ou stderr
      break;
    case 'display_data':
      if (output.data['image/png']) {
        console.log('Image PNG disponible');
      }
      if (output.data['text/html']) {
        console.log('HTML disponible');
      }
      break;
    case 'execute_result':
      console.log('Résultat:', output.data['text/plain']);
      break;
    case 'error':
      console.error(`${output.ename}: ${output.evalue}`);
      console.error(output.traceback.join('\n'));
      break;
  }
});
```

### Bonnes pratiques pour l'exécution de code

- Gérez correctement les erreurs d'exécution
- Limitez la taille des sorties pour éviter les problèmes de mémoire
- Utilisez des timeouts appropriés pour les exécutions longues
- Interrompez les exécutions bloquées plutôt que d'arrêter le kernel
- Exécutez les cellules dans l'ordre pour éviter les problèmes de dépendances
<!-- END_SECTION: code_execution -->

<!-- START_SECTION: advanced_usage -->
## Utilisations avancées

### Création d'un notebook d'analyse de données

```javascript
// Démarrer un kernel Python
const kernelResult = await client.callTool('jupyter-mcp-server', 'start_kernel', {
  kernel_name: 'python3'
});
const kernelId = kernelResult.kernel_id;

// Créer un nouveau notebook
const notebookResult = await client.callTool('jupyter-mcp-server', 'create_notebook', {
  path: './analyse_donnees.ipynb',
  kernel: 'python3'
});

// Ajouter une cellule markdown d'introduction
await client.callTool('jupyter-mcp-server', 'add_cell', {
  path: './analyse_donnees.ipynb',
  cell_type: 'markdown',
  source: '# Analyse de données\n\nCe notebook démontre une analyse de données simple avec pandas et matplotlib.'
});

// Ajouter une cellule pour importer les bibliothèques
await client.callTool('jupyter-mcp-server', 'add_cell', {
  path: './analyse_donnees.ipynb',
  cell_type: 'code',
  source: 'import pandas as pd\nimport matplotlib.pyplot as plt\nimport numpy as np\n\n%matplotlib inline'
});

// Ajouter une cellule pour générer des données
await client.callTool('jupyter-mcp-server', 'add_cell', {
  path: './analyse_donnees.ipynb',
  cell_type: 'code',
  source: `
# Créer des données d'exemple
np.random.seed(42)
data = {
    'x': np.random.rand(100),
    'y': np.random.rand(100),
    'groupe': np.random.choice(['A', 'B', 'C'], 100)
}
df = pd.DataFrame(data)
df.head()
`
});

// Ajouter une cellule pour visualiser les données
await client.callTool('jupyter-mcp-server', 'add_cell', {
  path: './analyse_donnees.ipynb',
  cell_type: 'code',
  source: `
# Visualiser les données
plt.figure(figsize=(10, 6))
for groupe, subset in df.groupby('groupe'):
    plt.scatter(subset['x'], subset['y'], label=groupe)
plt.xlabel('X')
plt.ylabel('Y')
plt.title('Nuage de points par groupe')
plt.legend()
plt.grid(True)
plt.show()
`
});

// Exécuter toutes les cellules du notebook
await client.callTool('jupyter-mcp-server', 'execute_notebook', {
  path: './analyse_donnees.ipynb',
  kernel_id: kernelId
});

// Arrêter le kernel
await client.callTool('jupyter-mcp-server', 'stop_kernel', {
  kernel_id: kernelId
});
```

### Conversion d'un script Python en notebook

```javascript
// Lire le contenu du script Python
const fs = require('fs');
const scriptContent = fs.readFileSync('./script.py', 'utf8');

// Diviser le script en cellules basées sur les commentaires
const cellContents = [];
let currentCell = '';

scriptContent.split('\n').forEach(line => {
  if (line.startsWith('# %% ') || line === '# %%') {
    // Nouvelle cellule
    if (currentCell.trim()) {
      cellContents.push(currentCell);
    }
    currentCell = line.replace(/^# %% ?/, '') + '\n';
  } else {
    currentCell += line + '\n';
  }
});

// Ajouter la dernière cellule
if (currentCell.trim()) {
  cellContents.push(currentCell);
}

// Créer un nouveau notebook
const notebookResult = await client.callTool('jupyter-mcp-server', 'create_notebook', {
  path: './script_converti.ipynb',
  kernel: 'python3'
});

// Ajouter chaque cellule au notebook
for (const cellContent of cellContents) {
  await client.callTool('jupyter-mcp-server', 'add_cell', {
    path: './script_converti.ipynb',
    cell_type: 'code',
    source: cellContent
  });
}

console.log('Script converti en notebook avec succès!');
```

### Exécution automatisée de notebooks

```javascript
// Fonction pour exécuter un notebook et sauvegarder les résultats
async function executeNotebook(notebookPath, kernelName = 'python3') {
  // Démarrer un kernel
  const kernelResult = await client.callTool('jupyter-mcp-server', 'start_kernel', {
    kernel_name: kernelName
  });
  const kernelId = kernelResult.kernel_id;
  
  console.log(`Exécution du notebook ${notebookPath} avec le kernel ${kernelName} (ID: ${kernelId})...`);
  
  try {
    // Exécuter le notebook
    const executeResult = await client.callTool('jupyter-mcp-server', 'execute_notebook', {
      path: notebookPath,
      kernel_id: kernelId
    });
    
    console.log(`Notebook exécuté avec succès: ${executeResult.cell_count} cellules`);
    
    // Sauvegarder le notebook avec un nouveau nom
    const readResult = await client.callTool('jupyter-mcp-server', 'read_notebook', {
      path: notebookPath
    });
    
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const outputPath = notebookPath.replace('.ipynb', `_executed_${timestamp}.ipynb`);
    
    await client.callTool('jupyter-mcp-server', 'write_notebook', {
      path: outputPath,
      content: readResult.notebook
    });
    
    console.log(`Résultats sauvegardés dans ${outputPath}`);
    
    return outputPath;
  } finally {
    // Arrêter le kernel
    await client.callTool('jupyter-mcp-server', 'stop_kernel', {
      kernel_id: kernelId
    });
    console.log(`Kernel ${kernelId} arrêté`);
  }
}

// Exécuter plusieurs notebooks
const notebooks = [
  './notebook1.ipynb',
  './notebook2.ipynb',
  './notebook3.ipynb'
];

async function runAllNotebooks() {
  for (const notebook of notebooks) {
    try {
      await executeNotebook(notebook);
    } catch (error) {
      console.error(`Erreur lors de l'exécution de ${notebook}:`, error);
    }
  }
}

runAllNotebooks();
```
<!-- END_SECTION: advanced_usage -->

<!-- START_SECTION: integration_with_roo -->
## Intégration avec Roo

Le serveur MCP Jupyter s'intègre parfaitement avec Roo, permettant à l'assistant IA de créer, modifier et exécuter des notebooks Jupyter.

### Configuration de Roo pour utiliser Jupyter MCP

1. Assurez-vous que le serveur MCP Jupyter est en cours d'exécution
2. Dans la configuration de Roo, ajoutez le serveur MCP Jupyter dans la section des serveurs MCP

```json
{
  "servers": [
    {
      "name": "jupyter",
      "url": "http://localhost:3000",
      "type": "mcp"
    }
  ]
}
```

### Exemples d'utilisation avec Roo

#### Création d'un notebook

```
Utilisateur: Crée un notebook Python qui analyse des données.

Roo: Je vais créer un notebook pour vous.
[Utilisation de l'outil jupyter-mcp-server.create_notebook]
J'ai créé un nouveau notebook. Maintenant, je vais ajouter du code pour analyser des données...

[Utilisation de l'outil jupyter-mcp-server.add_cell]
[Utilisation de l'outil jupyter-mcp-server.add_cell]
[Utilisation de l'outil jupyter-mcp-server.add_cell]

Le notebook a été créé avec succès avec des cellules pour l'analyse de données.
```

#### Exécution de code

```
Utilisateur: Exécute du code Python pour générer un graphique.

Roo: Je vais exécuter du code Python pour générer un graphique.
[Utilisation de l'outil jupyter-mcp-server.start_kernel]
[Utilisation de l'outil jupyter-mcp-server.execute_cell]

Voici le graphique généré:
[Affichage du graphique]

[Utilisation de l'outil jupyter-mcp-server.stop_kernel]
```

#### Modification d'un notebook existant

```
Utilisateur: Ajoute une cellule de visualisation au notebook analyse_donnees.ipynb.

Roo: Je vais ajouter une cellule de visualisation au notebook.
[Utilisation de l'outil jupyter-mcp-server.read_notebook]
[Utilisation de l'outil jupyter-mcp-server.add_cell]
[Utilisation de l'outil jupyter-mcp-server.write_notebook]

J'ai ajouté une cellule de visualisation au notebook analyse_donnees.ipynb.
```
<!-- END_SECTION: integration_with_roo -->

<!-- START_SECTION: troubleshooting -->
## Dépannage courant

### Problèmes de connexion au serveur Jupyter

#### Erreur "Cannot connect to Jupyter server"

**Problème** : Le serveur MCP Jupyter ne peut pas se connecter au serveur Jupyter.

**Solutions** :
- Vérifiez que le serveur Jupyter est en cours d'exécution
- Vérifiez que l'URL et le token dans `config.json` sont corrects
- Assurez-vous que le serveur Jupyter est démarré avec `--NotebookApp.allow_origin='*'`
- Vérifiez qu'aucun pare-feu ne bloque la connexion

#### Erreur "403 Forbidden"

**Problème** : Le serveur MCP Jupyter reçoit une erreur 403 Forbidden lors de la connexion au serveur Jupyter.

**Solutions** :
- Vérifiez que le token dans `config.json` correspond exactement au token du serveur Jupyter
- Assurez-vous que le serveur Jupyter est démarré avec `--NotebookApp.allow_origin='*'`
- Redémarrez le serveur Jupyter et le serveur MCP Jupyter

### Problèmes avec les notebooks

#### Erreur "File not found"

**Problème** : L'outil renvoie une erreur indiquant que le fichier notebook n'existe pas.

**Solutions** :
- Vérifiez que le chemin du fichier est correct
- Assurez-vous que le fichier existe
- Utilisez des chemins absolus ou relatifs au répertoire de travail du serveur MCP Jupyter

#### Erreur "Invalid notebook format"

**Problème** : L'outil renvoie une erreur indiquant que le format du notebook est invalide.

**Solutions** :
- Vérifiez que le fichier est un notebook Jupyter valide (.ipynb)
- Essayez d'ouvrir le notebook dans Jupyter Notebook pour vérifier qu'il est valide
- Recréez le notebook si nécessaire

### Problèmes avec les kernels

#### Erreur "Kernel not found"

**Problème** : L'outil renvoie une erreur indiquant que le kernel n'existe pas.

**Solutions** :
- Vérifiez que le kernel est disponible avec l'outil `list_kernels`
- Installez le kernel manquant (par exemple, `pip install ipykernel` pour Python)
- Utilisez un kernel disponible

#### Erreur "Kernel connection timeout"

**Problème** : L'outil renvoie une erreur de timeout lors de la connexion au kernel.

**Solutions** :
- Augmentez le timeout dans la configuration
- Redémarrez le kernel
- Vérifiez que le serveur Jupyter a suffisamment de ressources
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: performance_tips -->
## Conseils de performance

### Optimisation des notebooks

- Limitez la taille des notebooks pour éviter les problèmes de mémoire
- Divisez les notebooks volumineux en plusieurs notebooks plus petits
- Supprimez les sorties volumineuses avant de sauvegarder les notebooks
- Utilisez des formats de sortie compressés pour les images (JPEG au lieu de PNG)

### Gestion des kernels

- Arrêtez les kernels inutilisés pour libérer des ressources
- Limitez le nombre de kernels actifs simultanément
- Redémarrez régulièrement les kernels pour éviter les fuites de mémoire
- Utilisez des kernels légers pour les opérations simples

### Exécution de code

- Exécutez uniquement les cellules nécessaires plutôt que des notebooks entiers
- Limitez la taille des sorties générées
- Utilisez des timeouts appropriés pour les exécutions longues
- Évitez les boucles infinies et les calculs intensifs inutiles
<!-- END_SECTION: performance_tips -->

<!-- START_SECTION: security_considerations -->
## Considérations de sécurité

### Exécution de code arbitraire

Le serveur MCP Jupyter permet d'exécuter du code arbitraire sur le serveur, ce qui présente des risques de sécurité importants. Prenez les précautions suivantes :

- Limitez l'accès au serveur MCP Jupyter aux utilisateurs de confiance
- Exécutez le serveur Jupyter dans un environnement isolé (conteneur, machine virtuelle)
- Utilisez des kernels avec des permissions limitées
- Évitez d'exécuter du code provenant de sources non fiables

### Authentification

- Utilisez un token d'authentification fort pour le serveur Jupyter
- Ne stockez pas le token d'authentification dans des fichiers publics
- Utilisez HTTPS pour chiffrer les communications
- Mettez en place un proxy inverse avec authentification devant le serveur MCP Jupyter

### Accès aux fichiers

- Limitez l'accès aux répertoires contenant des données sensibles
- Utilisez des permissions de fichiers appropriées
- Évitez de stocker des informations sensibles dans les notebooks
<!-- END_SECTION: security_considerations -->

<!-- START_SECTION: next_steps -->
## Prochaines étapes

Maintenant que vous savez comment utiliser le serveur MCP Jupyter, vous pouvez :

1. [Consulter le guide de dépannage](TROUBLESHOOTING.md) pour résoudre les problèmes courants
2. [Explorer les cas d'utilisation avancés](../docs/jupyter-mcp-use-cases.md) pour tirer le meilleur parti du serveur
3. [Contribuer au développement](../CONTRIBUTING.md) du serveur MCP Jupyter
<!-- END_SECTION: next_steps -->