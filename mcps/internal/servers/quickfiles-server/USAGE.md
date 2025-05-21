# Utilisation du serveur MCP QuickFiles

<!-- START_SECTION: introduction -->
Ce document fournit des exemples détaillés d'utilisation et des bonnes pratiques pour le serveur MCP QuickFiles. Vous y trouverez des exemples concrets pour chaque outil exposé par le serveur, ainsi que des scénarios d'utilisation avancés.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: getting_started -->
## Démarrage du serveur

### Démarrage standard

Pour démarrer le serveur QuickFiles avec la configuration par défaut :

```bash
cd servers/quickfiles-server
npm start
```

### Démarrage avec options

Pour démarrer le serveur avec des options spécifiques :

```bash
# Spécifier un port différent
npm start -- --port 4000

# Spécifier un fichier de configuration personnalisé
npm start -- --config ./config/production.json

# Spécifier des chemins autorisés
npm start -- --allowed-paths /chemin/vers/repertoire1,/chemin/vers/repertoire2
```

### Démarrage en mode développement

Pour démarrer le serveur en mode développement avec rechargement automatique :

```bash
npm run dev
```

### Vérification du fonctionnement

Une fois le serveur démarré, vous pouvez vérifier qu'il fonctionne correctement en exécutant le script de test :

```bash
npm run test:simple
```

Vous devriez voir une sortie confirmant que le serveur est opérationnel et que les outils fonctionnent correctement.
<!-- END_SECTION: getting_started -->

<!-- START_SECTION: client_connection -->
## Connexion d'un client MCP

Pour utiliser le serveur QuickFiles, vous devez le connecter à un client MCP. Voici comment procéder avec différents clients :

### Connexion avec le client MCP JavaScript

```javascript
const { MCPClient } = require('@modelcontextprotocol/client');

async function connectToQuickFiles() {
  const client = new MCPClient();
  
  // Connexion au serveur QuickFiles
  await client.connect('http://localhost:3000');
  
  // Vérification des outils disponibles
  const tools = await client.listTools();
  console.log('Outils disponibles:', tools);
  
  return client;
}

// Utilisation
connectToQuickFiles().then(client => {
  // Utiliser le client pour appeler les outils QuickFiles
});
```

### Connexion avec Roo

Dans la configuration de Roo, ajoutez le serveur QuickFiles dans la section des serveurs MCP :

```json
{
  "servers": [
    {
      "name": "quickfiles",
      "url": "http://localhost:3000",
      "type": "mcp"
    }
  ]
}
```

### Connexion avec d'autres clients MCP

Pour d'autres clients MCP, consultez la documentation spécifique du client. En général, vous devrez fournir l'URL du serveur QuickFiles (par défaut `http://localhost:3000`).
<!-- END_SECTION: client_connection -->

<!-- START_SECTION: tool_read_multiple_files -->
## Utilisation de l'outil `read_multiple_files`

L'outil `read_multiple_files` permet de lire le contenu de plusieurs fichiers en une seule requête.

### Lecture simple de fichiers multiples

```javascript
const result = await client.callTool('quickfiles-server', 'read_multiple_files', {
  paths: [
    'chemin/vers/fichier1.txt',
    'chemin/vers/fichier2.txt',
    'chemin/vers/fichier3.txt'
  ],
  show_line_numbers: true
});

console.log(result.content[0].text);
```

### Lecture avec limitation du nombre de lignes

```javascript
const result = await client.callTool('quickfiles-server', 'read_multiple_files', {
  paths: [
    'chemin/vers/fichier1.txt',
    'chemin/vers/fichier2.txt'
  ],
  show_line_numbers: true,
  max_lines_per_file: 100,
  max_total_lines: 500
});

console.log(result.content[0].text);
```

### Lecture d'extraits spécifiques de fichiers

```javascript
const result = await client.callTool('quickfiles-server', 'read_multiple_files', {
  paths: [
    {
      path: 'chemin/vers/fichier.txt',
      excerpts: [
        { start: 10, end: 20 },  // Lignes 10 à 20
        { start: 50, end: 60 }   // Lignes 50 à 60
      ]
    }
  ],
  show_line_numbers: true
});

console.log(result.content[0].text);
```

### Lecture mixte (fichiers complets et extraits)

```javascript
const result = await client.callTool('quickfiles-server', 'read_multiple_files', {
  paths: [
    'chemin/vers/fichier1.txt',  // Fichier complet
    {
      path: 'chemin/vers/fichier2.txt',
      excerpts: [
        { start: 10, end: 20 }   // Extrait du fichier
      ]
    }
  ],
  show_line_numbers: true
});

console.log(result.content[0].text);
```

### Bonnes pratiques pour la lecture de fichiers

- Utilisez les extraits pour les fichiers volumineux afin d'économiser de la bande passante et de la mémoire
- Limitez le nombre de lignes lues avec `max_lines_per_file` et `max_total_lines` pour éviter les problèmes de performance
- Activez `show_line_numbers` pour faciliter la référence aux lignes spécifiques
- Regroupez les lectures de fichiers connexes en une seule requête pour améliorer les performances
<!-- END_SECTION: tool_read_multiple_files -->

<!-- START_SECTION: tool_list_directory_contents -->
## Utilisation de l'outil `list_directory_contents`

L'outil `list_directory_contents` permet de lister le contenu des répertoires avec des informations détaillées.

### Listage simple d'un répertoire

```javascript
const result = await client.callTool('quickfiles-server', 'list_directory_contents', {
  paths: ['chemin/vers/repertoire']
});

console.log(result.content[0].text);
```

### Listage récursif

```javascript
const result = await client.callTool('quickfiles-server', 'list_directory_contents', {
  paths: [
    {
      path: 'chemin/vers/repertoire',
      recursive: true  // Lister récursivement
    }
  ],
  max_lines: 1000
});

console.log(result.content[0].text);
```

### Listage avec filtrage par motif glob

```javascript
const result = await client.callTool('quickfiles-server', 'list_directory_contents', {
  paths: [
    {
      path: 'chemin/vers/repertoire',
      recursive: true,
      file_pattern: '*.js'  // Ne lister que les fichiers JavaScript
    }
  ],
  max_lines: 1000
});

console.log(result.content[0].text);
```

### Listage avec tri personnalisé

```javascript
const result = await client.callTool('quickfiles-server', 'list_directory_contents', {
  paths: [
    {
      path: 'chemin/vers/repertoire',
      recursive: true,
      sort_by: 'size',        // Trier par taille
      sort_order: 'desc'      // Ordre descendant (du plus grand au plus petit)
    }
  ],
  max_lines: 1000
});

console.log(result.content[0].text);
```

### Listage de plusieurs répertoires avec options différentes

```javascript
const result = await client.callTool('quickfiles-server', 'list_directory_contents', {
  paths: [
    {
      path: 'chemin/vers/repertoire1',
      recursive: true,
      file_pattern: '*.js',
      sort_by: 'modified',
      sort_order: 'desc'
    },
    {
      path: 'chemin/vers/repertoire2',
      recursive: false,
      file_pattern: '*.json',
      sort_by: 'name',
      sort_order: 'asc'
    }
  ],
  max_lines: 2000
});

console.log(result.content[0].text);
```

### Bonnes pratiques pour le listage de répertoires

- Utilisez le paramètre `recursive: false` pour les répertoires volumineux si vous n'avez besoin que du contenu de premier niveau
- Utilisez des motifs glob spécifiques pour filtrer les fichiers pertinents
- Choisissez un critère de tri approprié pour faciliter la navigation dans les résultats
- Limitez le nombre de lignes avec `max_lines` pour éviter les problèmes de performance
<!-- END_SECTION: tool_list_directory_contents -->

<!-- START_SECTION: tool_delete_files -->
## Utilisation de l'outil `delete_files`

L'outil `delete_files` permet de supprimer plusieurs fichiers en une seule opération.

### Suppression de fichiers

```javascript
const result = await client.callTool('quickfiles-server', 'delete_files', {
  paths: [
    'chemin/vers/fichier1.txt',
    'chemin/vers/fichier2.txt',
    'chemin/vers/fichier3.txt'
  ]
});

console.log(result.content[0].text);
```

### Bonnes pratiques pour la suppression de fichiers

- Vérifiez toujours les chemins des fichiers avant de les supprimer
- Utilisez des chemins absolus pour éviter les erreurs
- Évitez de supprimer des fichiers système ou des fichiers de configuration importants
- Considérez la création de sauvegardes avant de supprimer des fichiers importants
- Limitez le nombre de fichiers supprimés en une seule opération pour éviter les problèmes de performance

> **Attention** : La suppression de fichiers est irréversible. Assurez-vous de ne supprimer que les fichiers que vous souhaitez réellement supprimer.
<!-- END_SECTION: tool_delete_files -->

<!-- START_SECTION: tool_edit_multiple_files -->
## Utilisation de l'outil `edit_multiple_files`

L'outil `edit_multiple_files` permet de modifier plusieurs fichiers en une seule opération en appliquant des diffs.

### Édition simple d'un fichier

```javascript
const result = await client.callTool('quickfiles-server', 'edit_multiple_files', {
  files: [
    {
      path: 'chemin/vers/fichier.txt',
      diffs: [
        {
          search: 'texte à remplacer',
          replace: 'nouveau texte'
        }
      ]
    }
  ]
});

console.log(result.content[0].text);
```

### Édition avec plusieurs remplacements dans un fichier

```javascript
const result = await client.callTool('quickfiles-server', 'edit_multiple_files', {
  files: [
    {
      path: 'chemin/vers/fichier.txt',
      diffs: [
        {
          search: 'premier texte à remplacer',
          replace: 'premier nouveau texte'
        },
        {
          search: 'deuxième texte à remplacer',
          replace: 'deuxième nouveau texte'
        },
        {
          search: 'troisième texte à remplacer',
          replace: 'troisième nouveau texte'
        }
      ]
    }
  ]
});

console.log(result.content[0].text);
```

### Édition de plusieurs fichiers

```javascript
const result = await client.callTool('quickfiles-server', 'edit_multiple_files', {
  files: [
    {
      path: 'src/app.js',
      diffs: [
        {
          search: '// Configuration',
          replace: '// Configuration mise à jour'
        }
      ]
    },
    {
      path: 'src/utils.js',
      diffs: [
        {
          search: 'function oldName',
          replace: 'function newName'
        },
        {
          search: 'const VERSION = "1.0.0"',
          replace: 'const VERSION = "1.1.0"'
        }
      ]
    }
  ]
});

console.log(result.content[0].text);
```

### Édition avec spécification de ligne de départ

```javascript
const result = await client.callTool('quickfiles-server', 'edit_multiple_files', {
  files: [
    {
      path: 'chemin/vers/fichier.txt',
      diffs: [
        {
          search: 'texte à remplacer',
          replace: 'nouveau texte',
          start_line: 100  // Commencer la recherche à partir de la ligne 100
        }
      ]
    }
  ]
});

console.log(result.content[0].text);
```

### Bonnes pratiques pour l'édition de fichiers

- Utilisez des chaînes de recherche précises pour éviter les remplacements non désirés
- Testez vos modifications sur un petit ensemble de fichiers avant de les appliquer à grande échelle
- Utilisez le paramètre `start_line` pour cibler des sections spécifiques dans les fichiers volumineux
- Créez des sauvegardes des fichiers importants avant de les modifier
- Vérifiez les résultats après l'édition pour vous assurer que les modifications ont été appliquées correctement
<!-- END_SECTION: tool_edit_multiple_files -->

<!-- START_SECTION: advanced_usage -->
## Utilisations avancées

### Analyse de code source

QuickFiles peut être utilisé pour analyser rapidement une base de code :

```javascript
// Lister tous les fichiers JavaScript dans un projet
const jsFiles = await client.callTool('quickfiles-server', 'list_directory_contents', {
  paths: [
    {
      path: 'chemin/vers/projet',
      recursive: true,
      file_pattern: '*.js'
    }
  ],
  sort_by: 'modified',
  sort_order: 'desc'
});

// Rechercher des motifs spécifiques dans le code
const filesWithPattern = [];
for (const file of jsFiles.result) {
  const content = await client.callTool('quickfiles-server', 'read_multiple_files', {
    paths: [file.path]
  });
  
  if (content.result.includes('TODO') || content.result.includes('FIXME')) {
    filesWithPattern.push(file.path);
  }
}

console.log('Fichiers contenant des TODOs ou FIXMEs:', filesWithPattern);
```

### Refactoring de code

QuickFiles peut être utilisé pour effectuer des refactorings à grande échelle :

```javascript
// Remplacer une API obsolète par une nouvelle API dans tous les fichiers JavaScript
const jsFiles = await client.callTool('quickfiles-server', 'list_directory_contents', {
  paths: [
    {
      path: 'chemin/vers/projet',
      recursive: true,
      file_pattern: '*.js'
    }
  ]
});

const filesToEdit = [];
for (const file of jsFiles.result) {
  const content = await client.callTool('quickfiles-server', 'read_multiple_files', {
    paths: [file.path]
  });
  
  if (content.result.includes('oldAPI.method(')) {
    filesToEdit.push(file.path);
  }
}

// Appliquer les modifications à tous les fichiers concernés
await client.callTool('quickfiles-server', 'edit_multiple_files', {
  files: filesToEdit.map(path => ({
    path,
    diffs: [
      {
        search: 'oldAPI.method(',
        replace: 'newAPI.improvedMethod('
      }
    ]
  }))
});
```

### Génération de rapports

QuickFiles peut être utilisé pour générer des rapports sur la structure et le contenu des fichiers :

```javascript
// Générer un rapport sur la taille des fichiers dans un projet
const allFiles = await client.callTool('quickfiles-server', 'list_directory_contents', {
  paths: [
    {
      path: 'chemin/vers/projet',
      recursive: true,
      sort_by: 'size',
      sort_order: 'desc'
    }
  ]
});

// Analyser les résultats et générer un rapport
const report = {
  totalFiles: allFiles.result.length,
  totalSize: allFiles.result.reduce((sum, file) => sum + file.size, 0),
  largestFiles: allFiles.result.slice(0, 10),
  fileTypeDistribution: {}
};

// Calculer la distribution par type de fichier
allFiles.result.forEach(file => {
  const ext = file.path.split('.').pop() || 'no-extension';
  if (!report.fileTypeDistribution[ext]) {
    report.fileTypeDistribution[ext] = { count: 0, size: 0 };
  }
  report.fileTypeDistribution[ext].count++;
  report.fileTypeDistribution[ext].size += file.size;
});

// Écrire le rapport dans un fichier
const reportContent = JSON.stringify(report, null, 2);
await client.callTool('quickfiles-server', 'edit_multiple_files', {
  files: [
    {
      path: 'chemin/vers/projet/file-report.json',
      diffs: [
        {
          search: '.*',
          replace: reportContent
        }
      ]
    }
  ]
});
```
<!-- END_SECTION: advanced_usage -->

<!-- START_SECTION: integration_with_roo -->
## Intégration avec Roo

QuickFiles s'intègre parfaitement avec Roo, permettant à l'assistant IA d'accéder et de manipuler des fichiers locaux.

### Configuration de Roo pour utiliser QuickFiles

1. Assurez-vous que le serveur QuickFiles est en cours d'exécution
2. Dans la configuration de Roo, ajoutez le serveur QuickFiles dans la section des serveurs MCP

```json
{
  "servers": [
    {
      "name": "quickfiles",
      "url": "http://localhost:3000",
      "type": "mcp"
    }
  ]
}
```

### Exemples d'utilisation avec Roo

#### Lecture de fichiers

```
Utilisateur: Peux-tu lire le contenu du fichier config.json?

Roo: Je vais lire ce fichier pour vous.
[Utilisation de l'outil quickfiles-server.read_multiple_files]
Voici le contenu du fichier config.json:
{
  "server": {
    "port": 3000,
    "host": "localhost"
  },
  ...
}
```

#### Listage de répertoires

```
Utilisateur: Quels sont les fichiers JavaScript dans le répertoire src?

Roo: Je vais lister les fichiers JavaScript dans le répertoire src.
[Utilisation de l'outil quickfiles-server.list_directory_contents]
Voici les fichiers JavaScript dans le répertoire src:
- src/app.js (5.2 KB, 150 lignes)
- src/utils.js (2.1 KB, 80 lignes)
- src/components/Button.js (1.5 KB, 60 lignes)
...
```

#### Modification de fichiers

```
Utilisateur: Peux-tu ajouter un commentaire de copyright en haut de tous les fichiers JavaScript?

Roo: Je vais ajouter un commentaire de copyright à tous les fichiers JavaScript.
[Utilisation de l'outil quickfiles-server.list_directory_contents]
[Utilisation de l'outil quickfiles-server.edit_multiple_files]
J'ai ajouté le commentaire de copyright à tous les fichiers JavaScript dans le répertoire src.
```
<!-- END_SECTION: integration_with_roo -->

<!-- START_SECTION: troubleshooting -->
## Dépannage courant

### Problèmes de lecture de fichiers

#### Erreur "Fichier non trouvé"

**Problème** : L'outil `read_multiple_files` renvoie une erreur indiquant que le fichier n'existe pas.

**Solutions** :
- Vérifiez que le chemin du fichier est correct et que le fichier existe
- Assurez-vous que le chemin est relatif au répertoire de travail du serveur ou qu'il s'agit d'un chemin absolu autorisé
- Vérifiez que le serveur a les permissions nécessaires pour accéder au fichier

#### Erreur "Permission denied"

**Problème** : L'outil renvoie une erreur de permission lors de la lecture d'un fichier.

**Solutions** :
- Vérifiez les permissions du fichier et assurez-vous que l'utilisateur qui exécute le serveur a les droits de lecture
- Ajoutez le répertoire contenant le fichier à la liste des chemins autorisés dans la configuration

### Problèmes de listage de répertoires

#### Résultats tronqués

**Problème** : Les résultats du listage de répertoires sont tronqués.

**Solutions** :
- Augmentez la valeur de `max_lines` dans la requête
- Utilisez des filtres plus spécifiques pour réduire le nombre de résultats
- Divisez la requête en plusieurs requêtes plus petites

#### Performances lentes

**Problème** : Le listage de répertoires est lent pour les répertoires volumineux.

**Solutions** :
- Utilisez `recursive: false` si vous n'avez pas besoin de lister les sous-répertoires
- Utilisez des motifs glob spécifiques pour filtrer les fichiers
- Activez le cache dans la configuration du serveur

### Problèmes d'édition de fichiers

#### Aucune modification appliquée

**Problème** : L'outil `edit_multiple_files` ne modifie pas les fichiers comme prévu.

**Solutions** :
- Vérifiez que la chaîne de recherche correspond exactement au texte dans le fichier, y compris les espaces et les sauts de ligne
- Utilisez l'outil `read_multiple_files` pour vérifier le contenu exact du fichier avant d'appliquer les modifications
- Assurez-vous que le serveur a les permissions d'écriture sur les fichiers

#### Modifications incorrectes

**Problème** : L'outil `edit_multiple_files` applique des modifications incorrectes ou à des endroits inattendus.

**Solutions** :
- Utilisez des chaînes de recherche plus spécifiques pour cibler précisément le texte à remplacer
- Utilisez le paramètre `start_line` pour limiter la recherche à une partie spécifique du fichier
- Testez vos modifications sur un petit ensemble de fichiers avant de les appliquer à grande échelle
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: performance_tips -->
## Conseils de performance

### Optimisation des lectures de fichiers

- Utilisez des extraits pour lire uniquement les parties nécessaires des fichiers volumineux
- Limitez le nombre de fichiers lus en une seule requête
- Utilisez `max_lines_per_file` et `max_total_lines` pour limiter la quantité de données lues
- Désactivez `show_line_numbers` si vous n'avez pas besoin des numéros de ligne

### Optimisation des listages de répertoires

- Évitez de lister récursivement des répertoires volumineux si ce n'est pas nécessaire
- Utilisez des motifs glob spécifiques pour filtrer les fichiers pertinents
- Limitez la profondeur de récursion si possible
- Utilisez le cache pour les opérations répétées

### Optimisation des éditions de fichiers

- Regroupez les modifications connexes en une seule requête
- Utilisez des chaînes de recherche précises pour éviter les remplacements non désirés
- Limitez le nombre de fichiers modifiés en une seule requête
- Utilisez le paramètre `start_line` pour cibler des sections spécifiques dans les fichiers volumineux
<!-- END_SECTION: performance_tips -->

<!-- START_SECTION: security_considerations -->
## Considérations de sécurité

### Accès aux fichiers

- Configurez soigneusement `security.allowedPaths` pour limiter l'accès aux répertoires nécessaires uniquement
- Utilisez `security.disallowedPatterns` pour bloquer l'accès aux fichiers sensibles
- Évitez d'exposer des fichiers de configuration, des clés privées ou des informations d'identification

### Validation des entrées

- Validez toujours les chemins de fichiers fournis par les utilisateurs
- Méfiez-vous des chemins relatifs qui pourraient accéder à des fichiers en dehors des répertoires autorisés
- Évitez d'utiliser des entrées utilisateur directement dans les chaînes de recherche pour l'édition de fichiers

### Permissions

- Exécutez le serveur QuickFiles avec les privilèges minimaux nécessaires
- Assurez-vous que le serveur a uniquement les permissions nécessaires sur les fichiers qu'il doit manipuler
- Utilisez un utilisateur dédié avec des permissions limitées pour exécuter le serveur en production
<!-- END_SECTION: security_considerations -->

<!-- START_SECTION: next_steps -->
## Prochaines étapes

Maintenant que vous savez comment utiliser le serveur QuickFiles, vous pouvez :

1. [Consulter le guide de dépannage](TROUBLESHOOTING.md) pour résoudre les problèmes courants
2. [Explorer les cas d'utilisation avancés](../docs/quickfiles-use-cases.md) pour tirer le meilleur parti du serveur
3. [Contribuer au développement](../CONTRIBUTING.md) du serveur QuickFiles
<!-- END_SECTION: next_steps -->