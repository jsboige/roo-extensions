# Serveur MCP Jupyter

Ce serveur MCP permet d'interagir avec des notebooks Jupyter, en offrant des fonctionnalités pour la lecture, la modification et l'exécution de notebooks via le protocole Model Context Protocol (MCP).

## Table des matières

- [Fonctionnalités](#fonctionnalités)
- [Outils MCP exposés](#outils-mcp-exposés)
  - [Outils de gestion des notebooks](#outils-de-gestion-des-notebooks)
  - [Outils de gestion des kernels](#outils-de-gestion-des-kernels)
  - [Outils d'exécution de code](#outils-dexécution-de-code)
- [Prérequis](#prérequis)
- [Guide d'installation détaillé](#guide-dinstallation-détaillé)
  - [Installation de Jupyter](#installation-de-jupyter)
  - [Installation du serveur MCP](#installation-du-serveur-mcp)
- [Configuration](#configuration)
- [Utilisation](#utilisation)
- [Exemples d'utilisation](#exemples-dutilisation)
- [Limitations et considérations de performance](#limitations-et-considérations-de-performance)
- [Guide de dépannage](#guide-de-dépannage)
- [Développement et tests](#développement-et-tests)
- [Dépendances](#dépendances)

## Fonctionnalités

- **Gestion des notebooks** : lecture, création, modification et sauvegarde de notebooks Jupyter
- **Gestion des kernels** : démarrage, arrêt, interruption et redémarrage de kernels Jupyter
- **Exécution de code** : exécution de cellules individuelles ou de notebooks complets
- **Récupération des résultats** : récupération des sorties textuelles et riches (images, HTML, etc.)
- **Manipulation de cellules** : ajout, suppression et modification de cellules dans les notebooks

## Outils MCP exposés

### Outils de gestion des notebooks

#### `read_notebook`
Lit un notebook Jupyter à partir d'un fichier.

**Schéma d'entrée :**
```json
{
  "type": "object",
  "properties": {
    "path": {
      "type": "string",
      "description": "Chemin du fichier notebook (.ipynb)"
    }
  },
  "required": ["path"]
}
```

**Schéma de sortie :**
```json
{
  "notebook": {
    "cells": [...],
    "metadata": {...},
    "nbformat": 4,
    "nbformat_minor": 5
  }
}
```

**Exemple :**
```javascript
const response = await client.callTool('jupyter-mcp-server', 'read_notebook', {
  path: './mon-notebook.ipynb'
});
console.log(response.notebook.cells.length); // Nombre de cellules
```

#### `write_notebook`
Écrit/sauvegarde un notebook Jupyter dans un fichier.

**Schéma d'entrée :**
```json
{
  "type": "object",
  "properties": {
    "path": {
      "type": "string",
      "description": "Chemin du fichier notebook (.ipynb)"
    },
    "content": {
      "type": "object",
      "description": "Contenu du notebook au format nbformat"
    }
  },
  "required": ["path", "content"]
}
```

**Schéma de sortie :**
```json
{
  "success": true,
  "message": "Notebook écrit avec succès: ./mon-notebook.ipynb"
}
```

**Exemple :**
```javascript
const notebook = await client.callTool('jupyter-mcp-server', 'read_notebook', {
  path: './mon-notebook.ipynb'
});

// Modifier le notebook
notebook.notebook.metadata.title = "Nouveau titre";

const response = await client.callTool('jupyter-mcp-server', 'write_notebook', {
  path: './mon-notebook-modifié.ipynb',
  content: notebook.notebook
});
console.log(response.success); // true
```

#### `create_notebook`
Crée un nouveau notebook vide.

**Schéma d'entrée :**
```json
{
  "type": "object",
  "properties": {
    "path": {
      "type": "string",
      "description": "Chemin du fichier notebook (.ipynb)"
    },
    "kernel": {
      "type": "string",
      "description": "Nom du kernel (ex: python3)",
      "default": "python3"
    }
  },
  "required": ["path"]
}
```

**Schéma de sortie :**
```json
{
  "success": true,
  "message": "Notebook créé avec succès: ./nouveau-notebook.ipynb",
  "notebook": {
    "cells": [],
    "metadata": {...},
    "nbformat": 4,
    "nbformat_minor": 5
  }
}
```

**Exemple :**
```javascript
const response = await client.callTool('jupyter-mcp-server', 'create_notebook', {
  path: './nouveau-notebook.ipynb',
  kernel: 'python3'
});
console.log(response.notebook); // Notebook vide
```

#### `add_cell`
Ajoute une cellule à un notebook.

**Schéma d'entrée :**
```json
{
  "type": "object",
  "properties": {
    "path": {
      "type": "string",
      "description": "Chemin du fichier notebook (.ipynb)"
    },
    "cell_type": {
      "type": "string",
      "enum": ["code", "markdown", "raw"],
      "description": "Type de cellule"
    },
    "source": {
      "type": "string",
      "description": "Contenu de la cellule"
    },
    "metadata": {
      "type": "object",
      "description": "Métadonnées de la cellule (optionnel)"
    }
  },
  "required": ["path", "cell_type", "source"]
}
```

**Schéma de sortie :**
```json
{
  "success": true,
  "message": "Cellule ajoutée avec succès au notebook: ./mon-notebook.ipynb",
  "cell_index": 2
}
```

**Exemple :**
```javascript
const response = await client.callTool('jupyter-mcp-server', 'add_cell', {
  path: './mon-notebook.ipynb',
  cell_type: 'code',
  source: 'print("Hello, world!")',
  metadata: { tags: ['example'] }
});
console.log(response.cell_index); // Index de la nouvelle cellule
```

#### `remove_cell`
Supprime une cellule d'un notebook.

**Schéma d'entrée :**
```json
{
  "type": "object",
  "properties": {
    "path": {
      "type": "string",
      "description": "Chemin du fichier notebook (.ipynb)"
    },
    "index": {
      "type": "number",
      "description": "Index de la cellule à supprimer"
    }
  },
  "required": ["path", "index"]
}
```

**Schéma de sortie :**
```json
{
  "success": true,
  "message": "Cellule supprimée avec succès du notebook: ./mon-notebook.ipynb"
}
```

**Exemple :**
```javascript
const response = await client.callTool('jupyter-mcp-server', 'remove_cell', {
  path: './mon-notebook.ipynb',
  index: 2
});
console.log(response.success); // true
```

#### `update_cell`
Modifie une cellule d'un notebook.

**Schéma d'entrée :**
```json
{
  "type": "object",
  "properties": {
    "path": {
      "type": "string",
      "description": "Chemin du fichier notebook (.ipynb)"
    },
    "index": {
      "type": "number",
      "description": "Index de la cellule à modifier"
    },
    "source": {
      "type": "string",
      "description": "Nouveau contenu de la cellule"
    }
  },
  "required": ["path", "index", "source"]
}
```

**Schéma de sortie :**
```json
{
  "success": true,
  "message": "Cellule modifiée avec succès dans le notebook: ./mon-notebook.ipynb"
}
```

**Exemple :**
```javascript
const response = await client.callTool('jupyter-mcp-server', 'update_cell', {
  path: './mon-notebook.ipynb',
  index: 0,
  source: '# Titre modifié'
});
console.log(response.success); // true
```
### Outils de gestion des kernels

#### `list_kernels`
Liste les kernels disponibles et actifs.

**Schéma d'entrée :**
```json
{
  "type": "object",
  "properties": {},
  "required": []
}
```

**Schéma de sortie :**
```json
{
  "available_kernels": [
    { "name": "python3", "spec": { "display_name": "Python 3" } },
    { "name": "ir", "spec": { "display_name": "R" } }
  ],
  "active_kernels": [
    { "id": "kernel-id-1", "name": "python3" }
  ]
}
```

**Exemple :**
```javascript
const response = await client.callTool('jupyter-mcp-server', 'list_kernels', {});
console.log(response.available_kernels); // Liste des kernels disponibles
console.log(response.active_kernels); // Liste des kernels actifs
```

#### `start_kernel`
Démarre un nouveau kernel.

**Schéma d'entrée :**
```json
{
  "type": "object",
  "properties": {
    "kernel_name": {
      "type": "string",
      "description": "Nom du kernel à démarrer (ex: python3)",
      "default": "python3"
    }
  },
  "required": []
}
```

**Schéma de sortie :**
```json
{
  "kernel_id": "kernel-id-1",
  "kernel_name": "python3",
  "message": "Kernel démarré avec succès: kernel-id-1"
}
```

**Exemple :**
```javascript
const response = await client.callTool('jupyter-mcp-server', 'start_kernel', {
  kernel_name: 'python3'
});
console.log(response.kernel_id); // ID du kernel démarré
```

#### `stop_kernel`
Arrête un kernel actif.

**Schéma d'entrée :**
```json
{
  "type": "object",
  "properties": {
    "kernel_id": {
      "type": "string",
      "description": "ID du kernel à arrêter"
    }
## Limitations et considérations de performance

### Limitations

- **Taille des notebooks** : Le serveur peut avoir des difficultés à gérer des notebooks très volumineux (>100 Mo) en raison des limitations de mémoire de Node.js.
- **Types de sorties** : Certains types de sorties complexes (widgets interactifs, visualisations 3D) peuvent ne pas être correctement sérialisés.
- **Connexion au serveur Jupyter** : Le serveur MCP Jupyter doit pouvoir se connecter à un serveur Jupyter en cours d'exécution. Si le serveur Jupyter n'est pas accessible, les opérations échoueront.
- **Authentification** : Le support pour les serveurs Jupyter nécessitant une authentification complexe est limité.

### Considérations de performance

- **Exécution de notebooks volumineux** : L'exécution de notebooks contenant de nombreuses cellules peut prendre du temps. Envisagez d'exécuter uniquement les cellules nécessaires.
- **Gestion de la mémoire** : La manipulation de notebooks volumineux peut consommer beaucoup de mémoire. Assurez-vous que votre système dispose de suffisamment de mémoire.
- **Connexions simultanées** : Le serveur peut gérer plusieurs connexions simultanées, mais les performances peuvent se dégrader avec un grand nombre de connexions.
- **Sorties volumineuses** : Les cellules produisant des sorties très volumineuses (grandes images, grands ensembles de données) peuvent ralentir les performances.

### Recommandations

- Limitez la taille des notebooks à moins de 50 Mo pour de meilleures performances.
- Évitez d'exécuter des cellules qui produisent des sorties très volumineuses.
- Utilisez des kernels appropriés pour vos besoins (Python pour le calcul scientifique, R pour les statistiques, etc.).
- Arrêtez les kernels inutilisés pour libérer des ressources.

## Guide de dépannage

### Problèmes courants et solutions

#### Le serveur MCP ne peut pas se connecter au serveur Jupyter

**Symptômes** : Erreurs de connexion, timeouts.

**Solutions** :
- Vérifiez que le serveur Jupyter est en cours d'exécution (`jupyter notebook list`).
- Vérifiez que l'URL et le port sont corrects dans la configuration.
- Vérifiez que le token d'authentification est correct si nécessaire.
- Vérifiez les pare-feu ou les restrictions réseau qui pourraient bloquer la connexion.

#### Erreurs lors de l'exécution de cellules

**Symptômes** : Les cellules ne s'exécutent pas, erreurs d'exécution.

**Solutions** :
- Vérifiez que le kernel est démarré et actif.
- Vérifiez que le code est valide.
- Redémarrez le kernel si nécessaire.
- Vérifiez les dépendances requises par le code.

#### Problèmes de lecture/écriture de notebooks

**Symptômes** : Erreurs lors de la lecture ou de l'écriture de notebooks.

**Solutions** :
- Vérifiez les permissions des fichiers.
- Vérifiez que le chemin du fichier est correct.
- Vérifiez que le format du notebook est valide.
- Vérifiez l'espace disque disponible.

#### Problèmes de performance

**Symptômes** : Lenteur, timeouts, consommation élevée de mémoire.

**Solutions** :
- Limitez la taille des notebooks.
- Exécutez moins de cellules à la fois.
- Augmentez la mémoire disponible pour Node.js.
- Utilisez des techniques de streaming pour les grandes sorties.

### Journalisation et débogage

Le serveur MCP Jupyter utilise la console pour journaliser les informations de débogage. Pour activer une journalisation plus détaillée, vous pouvez modifier le niveau de journalisation dans le code source.

Pour déboguer les problèmes, vous pouvez également :

1. Exécuter le serveur en mode développement :
   ```bash
   npm run dev
   ```

2. Utiliser les outils de débogage de Node.js :
   ```bash
   node --inspect dist/index.js
   ```

3. Consulter les journaux du serveur Jupyter :
   ```bash
   jupyter notebook --debug
   ```

## Développement et tests

### Structure du projet

```
jupyter-mcp-server/
├── src/
│   ├── index.ts                # Point d'entrée du serveur
│   ├── services/
│   │   └── jupyter.ts          # Services d'interaction avec Jupyter
│   ├── tools/
│   │   ├── notebook.ts         # Outils de gestion des notebooks
│   │   ├── kernel.ts           # Outils de gestion des kernels
│   │   └── execution.ts        # Outils d'exécution de code
│   └── types/
│       ├── modelcontextprotocol.d.ts  # Types pour le protocole MCP
│       └── nbformat.d.ts       # Types pour le format de notebook
├── __tests__/                  # Tests unitaires
│   ├── notebook.test.js        # Tests pour les outils de notebook
│   ├── kernel.test.js          # Tests pour les outils de kernel
│   ├── execution.test.js       # Tests pour les outils d'exécution
│   ├── error-handling.test.js  # Tests de gestion d'erreurs
│   └── performance.test.js     # Tests de performance
├── dist/                       # Code compilé
├── package.json                # Configuration du projet
└── tsconfig.json               # Configuration TypeScript
```

### Exécution des tests

Pour exécuter tous les tests :

```bash
npm test
```

Pour exécuter des tests spécifiques :

```bash
npm run test:notebook    # Tests des outils de notebook
npm run test:kernel      # Tests des outils de kernel
npm run test:execution   # Tests des outils d'exécution
npm run test:error       # Tests de gestion d'erreurs
npm run test:performance # Tests de performance
```

Pour exécuter les tests avec couverture de code :

```bash
npm run test:coverage
```

### Contribution au développement

1. Assurez-vous que les tests passent avant de soumettre des modifications.
2. Suivez les conventions de codage existantes.
3. Documentez les nouvelles fonctionnalités ou modifications.
4. Ajoutez des tests pour les nouvelles fonctionnalités.
  },
  "required": ["kernel_id"]
}
```

**Schéma de sortie :**
```json
{
  "success": true,
  "message": "Kernel arrêté avec succès: kernel-id-1"
}
```

**Exemple :**
```javascript
const response = await client.callTool('jupyter-mcp-server', 'stop_kernel', {
  kernel_id: 'kernel-id-1'
});
console.log(response.success); // true
```

#### `interrupt_kernel`
Interrompt l'exécution d'un kernel.

**Schéma d'entrée :**
```json
{
  "type": "object",
  "properties": {
    "kernel_id": {
      "type": "string",
      "description": "ID du kernel à interrompre"
    }
  },
  "required": ["kernel_id"]
}
```

**Schéma de sortie :**
```json
{
  "success": true,
  "message": "Kernel interrompu avec succès: kernel-id-1"
}
```

**Exemple :**
```javascript
const response = await client.callTool('jupyter-mcp-server', 'interrupt_kernel', {
  kernel_id: 'kernel-id-1'
});
console.log(response.success); // true
```

#### `restart_kernel`
Redémarre un kernel.

**Schéma d'entrée :**
```json
{
  "type": "object",
  "properties": {
    "kernel_id": {
      "type": "string",
      "description": "ID du kernel à redémarrer"
    }
  },
  "required": ["kernel_id"]
}
```

**Schéma de sortie :**
```json
{
  "success": true,
  "message": "Kernel redémarré avec succès: kernel-id-1"
}
```

**Exemple :**
```javascript
const response = await client.callTool('jupyter-mcp-server', 'restart_kernel', {
  kernel_id: 'kernel-id-1'
});
console.log(response.success); // true
```

### Outils d'exécution de code

#### `execute_cell`
Exécute du code dans un kernel spécifique.

**Schéma d'entrée :**
```json
{
  "type": "object",
  "properties": {
    "kernel_id": {
      "type": "string",
      "description": "ID du kernel sur lequel exécuter le code"
    },
    "code": {
      "type": "string",
      "description": "Code à exécuter"
    }
  },
  "required": ["kernel_id", "code"]
}
```

**Schéma de sortie :**
```json
{
  "execution_count": 1,
  "status": "ok",
  "outputs": [
    {
      "type": "stream",
      "name": "stdout",
      "text": "Hello, world!"
    }
  ]
}
```

**Exemple :**
```javascript
const response = await client.callTool('jupyter-mcp-server', 'execute_cell', {
  kernel_id: 'kernel-id-1',
  code: 'print("Hello, world!")'
});
console.log(response.outputs); // Sorties de l'exécution
```

#### `execute_notebook`
Exécute toutes les cellules de code d'un notebook.

**Schéma d'entrée :**
```json
{
  "type": "object",
  "properties": {
    "path": {
      "type": "string",
      "description": "Chemin du fichier notebook (.ipynb)"
    },
    "kernel_id": {
      "type": "string",
      "description": "ID du kernel sur lequel exécuter le notebook"
    }
  },
  "required": ["path", "kernel_id"]
}
```

**Schéma de sortie :**
```json
{
  "success": true,
  "message": "Notebook exécuté avec succès: ./mon-notebook.ipynb",
  "cell_count": 5
}
```

**Exemple :**
```javascript
const response = await client.callTool('jupyter-mcp-server', 'execute_notebook', {
  path: './mon-notebook.ipynb',
  kernel_id: 'kernel-id-1'
});
console.log(response.cell_count); // Nombre de cellules dans le notebook
```

#### `execute_notebook_cell`
Exécute une cellule spécifique d'un notebook.

**Schéma d'entrée :**
```json
{
  "type": "object",
  "properties": {
    "path": {
      "type": "string",
      "description": "Chemin du fichier notebook (.ipynb)"
    },
    "cell_index": {
      "type": "number",
      "description": "Index de la cellule à exécuter"
    },
    "kernel_id": {
      "type": "string",
      "description": "ID du kernel sur lequel exécuter la cellule"
    }
  },
  "required": ["path", "cell_index", "kernel_id"]
}
```

**Schéma de sortie :**
```json
{
  "success": true,
  "message": "Cellule exécutée avec succès: ./mon-notebook.ipynb[2]",
  "execution_count": 1,
  "outputs": [
    {
      "type": "stream",
      "name": "stdout",
      "text": "Hello, world!"
    }
  ]
}
```

**Exemple :**
```javascript
const response = await client.callTool('jupyter-mcp-server', 'execute_notebook_cell', {
  path: './mon-notebook.ipynb',
  cell_index: 2,
  kernel_id: 'kernel-id-1'
});
console.log(response.outputs); // Sorties de l'exécution
```

## Prérequis

- Node.js (v14 ou supérieur)
- npm (v6 ou supérieur)
- Python (v3.6 ou supérieur)
- Jupyter Notebook ou JupyterLab
- Un serveur Jupyter en cours d'exécution (par défaut sur http://localhost:8888)

## Guide d'installation détaillé

### Installation de Jupyter

Pour utiliser ce serveur MCP, vous devez avoir Jupyter installé et en cours d'exécution. Voici comment l'installer et le démarrer :

#### Sous Windows

1. Installez Python depuis [python.org](https://www.python.org/downloads/)
2. Ouvrez une invite de commande et créez un environnement virtuel :
   ```bash
   python -m venv jupyter-env
   ```
3. Activez l'environnement virtuel :
   ```bash
   jupyter-env\Scripts\activate
   ```
4. Installez Jupyter :
   ```bash
   pip install jupyter
   ```
5. Créez un script `start-jupyter.bat` avec le contenu suivant :
   ```batch
   @echo off
   call jupyter-env\Scripts\activate
   jupyter notebook --no-browser
   ```
6. Exécutez le script pour démarrer Jupyter :
   ```bash
   start-jupyter.bat
   ```

#### Sous macOS/Linux

1. Ouvrez un terminal et créez un environnement virtuel :
   ```bash
   python3 -m venv jupyter-env
   ```
2. Activez l'environnement virtuel :
   ```bash
   source jupyter-env/bin/activate
   ```
3. Installez Jupyter :
   ```bash
   pip install jupyter
   ```
4. Créez un script `start-jupyter.sh` avec le contenu suivant :
   ```bash
   #!/bin/bash
   source jupyter-env/bin/activate
   jupyter notebook --no-browser
   ```
5. Rendez le script exécutable :
   ```bash
   chmod +x start-jupyter.sh
   ```
6. Exécutez le script pour démarrer Jupyter :
   ```bash
   ./start-jupyter.sh
   ```

Le serveur Jupyter démarrera sans ouvrir de navigateur. Il sera accessible à l'adresse http://localhost:8888.

### Installation du serveur MCP

1. Clonez ce dépôt ou téléchargez les fichiers source
2. Naviguez vers le dossier du serveur MCP Jupyter :
   ```bash
   cd servers/jupyter-mcp-server
   ```
3. Installez les dépendances :
   ```bash
   npm install
   ```
4. Compilez le projet :
   ```bash
   npm run build
   ```

## Configuration

Par défaut, le serveur MCP Jupyter se connecte à un serveur Jupyter en cours d'exécution sur http://localhost:8888. Vous pouvez modifier cette configuration en passant des options lors de l'initialisation du serveur.

## Utilisation

Pour démarrer le serveur MCP Jupyter :

```bash
npm start
```

## Dépendances principales

- `@modelcontextprotocol/sdk` : SDK pour l'implémentation du serveur MCP
- `@jupyterlab/services` : Pour l'interaction avec les kernels Jupyter
- `nbformat` : Pour la manipulation des fichiers notebook
- `ws` : Pour la communication WebSocket
- `axios` : Pour les requêtes HTTP

## Exemple d'utilisation

Voici un exemple d'utilisation du serveur MCP Jupyter pour exécuter une cellule de code :

```javascript
// Démarrer un kernel
const kernelResponse = await client.callTool('jupyter-mcp-server', 'start_kernel', {
  kernel_name: 'python3'
});

const kernelId = kernelResponse.kernel_id;

// Exécuter du code
const result = await client.callTool('jupyter-mcp-server', 'execute_cell', {
  kernel_id: kernelId,
  code: 'print("Hello, world!")'
});

console.log(result.outputs);

// Arrêter le kernel
await client.callTool('jupyter-mcp-server', 'stop_kernel', {
  kernel_id: kernelId
});
```

## Remarques importantes

- Assurez-vous que le serveur Jupyter est en cours d'exécution avant de démarrer le serveur MCP Jupyter.
- Pour utiliser ce serveur MCP, vous devez avoir installé les dépendances nécessaires, notamment `@modelcontextprotocol/sdk` et `@jupyterlab/services`.