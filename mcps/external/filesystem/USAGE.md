# Utilisation du MCP Filesystem

<!-- START_SECTION: introduction -->
## Introduction

Ce document détaille comment utiliser le MCP Filesystem avec Roo. Le MCP Filesystem permet à Roo d'interagir avec le système de fichiers local pour lire, écrire, modifier et gérer des fichiers et répertoires directement depuis l'interface de conversation.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: available_tools -->
## Outils disponibles

Le MCP Filesystem expose les outils suivants:

| Outil | Description |
|-------|-------------|
| `read_file` | Lit le contenu d'un fichier |
| `read_multiple_files` | Lit le contenu de plusieurs fichiers simultanément |
| `write_file` | Crée ou écrase un fichier avec un nouveau contenu |
| `edit_file` | Modifie un fichier existant en remplaçant des portions spécifiques |
| `create_directory` | Crée un nouveau répertoire |
| `list_directory` | Liste le contenu d'un répertoire |
| `directory_tree` | Obtient une vue arborescente d'un répertoire |
| `move_file` | Déplace ou renomme un fichier ou un répertoire |
| `search_files` | Recherche des fichiers correspondant à un motif |
| `get_file_info` | Obtient des informations sur un fichier ou un répertoire |
| `list_allowed_directories` | Liste les répertoires autorisés pour l'accès |
<!-- END_SECTION: available_tools -->

<!-- START_SECTION: basic_usage -->
## Utilisation de base

### Lire un fichier

Pour lire le contenu d'un fichier:

```
Outil: read_file
Arguments:
{
  "path": "/chemin/vers/fichier.txt"
}
```

### Écrire dans un fichier

Pour créer un nouveau fichier ou écraser un fichier existant:

```
Outil: write_file
Arguments:
{
  "path": "/chemin/vers/fichier.txt",
  "content": "Contenu du fichier"
}
```

### Lister le contenu d'un répertoire

Pour lister les fichiers et sous-répertoires d'un répertoire:

```
Outil: list_directory
Arguments:
{
  "path": "/chemin/vers/repertoire"
}
```

### Créer un répertoire

Pour créer un nouveau répertoire:

```
Outil: create_directory
Arguments:
{
  "path": "/chemin/vers/nouveau/repertoire"
}
```

### Obtenir des informations sur un fichier

Pour obtenir des métadonnées sur un fichier ou un répertoire:

```
Outil: get_file_info
Arguments:
{
  "path": "/chemin/vers/fichier.txt"
}
```
<!-- END_SECTION: basic_usage -->

<!-- START_SECTION: advanced_usage -->
## Utilisation avancée

### Lire plusieurs fichiers

Pour lire le contenu de plusieurs fichiers en une seule opération:

```
Outil: read_multiple_files
Arguments:
{
  "paths": [
    "/chemin/vers/fichier1.txt",
    "/chemin/vers/fichier2.txt",
    "/chemin/vers/fichier3.txt"
  ]
}
```

### Éditer un fichier existant

Pour modifier des portions spécifiques d'un fichier existant:

```
Outil: edit_file
Arguments:
{
  "path": "/chemin/vers/fichier.txt",
  "edits": [
    {
      "oldText": "texte à remplacer",
      "newText": "nouveau texte"
    },
    {
      "oldText": "autre texte à remplacer",
      "newText": "autre nouveau texte"
    }
  ],
  "dryRun": false
}
```

L'option `dryRun` permet de prévisualiser les modifications sans les appliquer.

### Obtenir une vue arborescente d'un répertoire

Pour obtenir une représentation JSON de la structure d'un répertoire:

```
Outil: directory_tree
Arguments:
{
  "path": "/chemin/vers/repertoire"
}
```

### Déplacer ou renommer un fichier

Pour déplacer ou renommer un fichier ou un répertoire:

```
Outil: move_file
Arguments:
{
  "source": "/chemin/vers/source.txt",
  "destination": "/chemin/vers/destination.txt"
}
```

### Rechercher des fichiers

Pour rechercher des fichiers correspondant à un motif:

```
Outil: search_files
Arguments:
{
  "path": "/chemin/vers/repertoire",
  "pattern": "*.js",
  "excludePatterns": ["node_modules", ".git"]
}
```
<!-- END_SECTION: advanced_usage -->

<!-- START_SECTION: use_cases -->
## Cas d'utilisation

### Gestion de projet de développement

Le MCP Filesystem est particulièrement utile pour gérer des projets de développement:

1. Lister la structure du projet:

```
Outil: directory_tree
Arguments:
{
  "path": "/chemin/vers/projet"
}
```

2. Rechercher des fichiers spécifiques:

```
Outil: search_files
Arguments:
{
  "path": "/chemin/vers/projet",
  "pattern": "*.js"
}
```

3. Lire le contenu des fichiers importants:

```
Outil: read_multiple_files
Arguments:
{
  "paths": [
    "/chemin/vers/projet/package.json",
    "/chemin/vers/projet/README.md",
    "/chemin/vers/projet/src/index.js"
  ]
}
```

4. Modifier un fichier de configuration:

```
Outil: edit_file
Arguments:
{
  "path": "/chemin/vers/projet/config.json",
  "edits": [
    {
      "oldText": "\"debug\": false",
      "newText": "\"debug\": true"
    }
  ]
}
```

### Analyse de données

Pour analyser des fichiers de données:

1. Lister les fichiers de données disponibles:

```
Outil: list_directory
Arguments:
{
  "path": "/chemin/vers/donnees"
}
```

2. Obtenir des informations sur les fichiers:

```
Outil: get_file_info
Arguments:
{
  "path": "/chemin/vers/donnees/data.csv"
}
```

3. Lire le contenu des fichiers de données:

```
Outil: read_file
Arguments:
{
  "path": "/chemin/vers/donnees/data.csv"
}
```

4. Écrire les résultats de l'analyse:

```
Outil: write_file
Arguments:
{
  "path": "/chemin/vers/resultats/analyse.txt",
  "content": "Résultats de l'analyse: ..."
}
```

### Gestion de documentation

Pour gérer des fichiers de documentation:

1. Créer une structure de répertoires:

```
Outil: create_directory
Arguments:
{
  "path": "/chemin/vers/docs/api"
}
```

2. Créer un nouveau fichier de documentation:

```
Outil: write_file
Arguments:
{
  "path": "/chemin/vers/docs/api/endpoints.md",
  "content": "# API Endpoints\n\n## GET /users\n..."
}
```

3. Mettre à jour un fichier existant:

```
Outil: edit_file
Arguments:
{
  "path": "/chemin/vers/docs/README.md",
  "edits": [
    {
      "oldText": "# Documentation (Draft)",
      "newText": "# Documentation (v1.0)"
    }
  ]
}
```
<!-- END_SECTION: use_cases -->

<!-- START_SECTION: best_practices -->
## Bonnes pratiques

### Gestion des chemins

- **Utilisez des chemins absolus** quand c'est possible pour éviter les ambiguïtés
- **Vérifiez que les chemins sont dans des répertoires autorisés** avant d'essayer d'y accéder
- **Utilisez `list_allowed_directories`** pour connaître les répertoires accessibles:

```
Outil: list_allowed_directories
Arguments: {}
```

### Opérations sur les fichiers

- **Vérifiez l'existence des fichiers** avant de les modifier:

```
Outil: get_file_info
Arguments:
{
  "path": "/chemin/vers/fichier.txt"
}
```

- **Utilisez `edit_file` plutôt que `write_file`** pour modifier des fichiers existants afin de préserver le contenu non modifié
- **Utilisez l'option `dryRun: true`** avec `edit_file` pour prévisualiser les modifications avant de les appliquer

### Performance

- **Utilisez `read_multiple_files`** au lieu de plusieurs appels à `read_file` pour améliorer les performances
- **Limitez la profondeur de récursion** lors de l'utilisation de `directory_tree` sur des répertoires volumineux
- **Utilisez des motifs d'exclusion** avec `search_files` pour ignorer les répertoires non pertinents comme `node_modules` ou `.git`

### Sécurité

- **Ne stockez pas d'informations sensibles** dans des fichiers accessibles via le MCP Filesystem
- **Vérifiez le contenu avant d'écrire** dans des fichiers pour éviter les injections de code malveillant
- **Limitez les opérations d'écriture** aux fichiers qui doivent réellement être modifiés
<!-- END_SECTION: best_practices -->

<!-- START_SECTION: error_handling -->
## Gestion des erreurs

Le MCP Filesystem peut renvoyer différentes erreurs. Voici comment les gérer:

### Erreurs courantes

| Erreur | Description | Solution |
|--------|-------------|----------|
| `PathNotAllowedError` | Le chemin n'est pas dans un répertoire autorisé | Utilisez un chemin dans un répertoire autorisé |
| `FileNotFoundError` | Le fichier n'existe pas | Vérifiez le chemin ou créez le fichier |
| `PermissionDeniedError` | Permissions insuffisantes | Vérifiez les permissions du fichier |
| `InvalidArgumentError` | Arguments invalides | Vérifiez le format des arguments |
| `FileAlreadyExistsError` | Le fichier existe déjà | Utilisez un autre nom ou écrasez le fichier |

### Stratégies de gestion des erreurs

1. **Vérification préalable**:
   - Vérifiez l'existence des fichiers avec `get_file_info` avant de les manipuler
   - Vérifiez que les répertoires existent avant d'y créer des fichiers

2. **Gestion des cas particuliers**:
   - Créez les répertoires parents si nécessaire avec `create_directory`
   - Utilisez des opérations conditionnelles basées sur l'existence des fichiers

3. **Récupération après erreur**:
   - Si une opération échoue, essayez une approche alternative
   - Gardez une trace des opérations pour pouvoir les annuler si nécessaire
<!-- END_SECTION: error_handling -->

<!-- START_SECTION: integration_with_roo -->
## Intégration avec Roo

Le MCP Filesystem s'intègre parfaitement avec Roo, permettant des interactions naturelles en langage courant. Voici quelques exemples de demandes que vous pouvez faire à Roo:

- "Montre-moi le contenu du fichier config.json"
- "Crée un nouveau répertoire pour mon projet"
- "Liste tous les fichiers JavaScript dans le répertoire src"
- "Modifie le fichier README.md pour mettre à jour la section d'installation"
- "Recherche tous les fichiers contenant le mot 'TODO' dans le projet"

Roo traduira automatiquement ces demandes en appels aux outils appropriés du MCP Filesystem.
<!-- END_SECTION: integration_with_roo -->

<!-- START_SECTION: performance_optimization -->
## Optimisation des performances

### Lecture efficace

Pour lire efficacement de grands fichiers ou de nombreux fichiers:

- **Utilisez `read_multiple_files`** pour lire plusieurs fichiers en une seule opération
- **Limitez la taille des fichiers** lus pour éviter les problèmes de mémoire
- **Utilisez des extraits de fichiers** plutôt que de lire des fichiers entiers quand c'est possible:

```
Outil: read_multiple_files
Arguments:
{
  "paths": [
    {
      "path": "/chemin/vers/grand_fichier.log",
      "excerpts": [
        {
          "start": 100,
          "end": 200
        }
      ]
    }
  ]
}
```

### Recherche optimisée

Pour optimiser les recherches de fichiers:

- **Utilisez des motifs d'exclusion** pour ignorer les répertoires non pertinents
- **Limitez la profondeur de recherche** pour les grandes arborescences
- **Utilisez des motifs de recherche spécifiques** plutôt que des recherches génériques

```
Outil: search_files
Arguments:
{
  "path": "/chemin/vers/projet",
  "pattern": "*.js",
  "excludePatterns": ["node_modules", "dist", ".git"]
}
```

### Modifications efficaces

Pour modifier efficacement des fichiers:

- **Utilisez `edit_file` avec des modifications ciblées** plutôt que de réécrire tout le fichier
- **Regroupez plusieurs modifications** dans un seul appel à `edit_file`
- **Utilisez `dryRun: true`** pour vérifier les modifications avant de les appliquer
<!-- END_SECTION: performance_optimization -->

<!-- START_SECTION: security_considerations -->
## Considérations de sécurité

### Limites d'accès

Le MCP Filesystem limite l'accès aux répertoires spécifiés lors de sa configuration. Cependant, il est important de:

- **Ne pas autoriser l'accès à des répertoires sensibles** comme `/etc`, `/var`, ou `C:\Windows`
- **Créer des répertoires dédiés** pour les opérations du MCP Filesystem
- **Vérifier régulièrement les répertoires autorisés** avec `list_allowed_directories`

### Validation des entrées

Pour éviter les problèmes de sécurité:

- **Validez les chemins de fichiers** avant de les utiliser
- **Évitez les traversées de répertoire** avec des séquences comme `../`
- **Validez le contenu des fichiers** avant de les écrire, surtout s'ils contiennent du code exécutable

### Permissions des fichiers

Sur les systèmes Unix/Linux:

- **Utilisez des permissions restrictives** pour les fichiers créés
- **Évitez de modifier les permissions** des fichiers système
- **Respectez le principe du moindre privilège** en n'accordant que les permissions nécessaires
<!-- END_SECTION: security_considerations -->

<!-- START_SECTION: troubleshooting -->
## Résolution des problèmes

### Problèmes d'accès aux fichiers

Si vous rencontrez des erreurs d'accès aux fichiers:

1. **Vérifiez que le chemin est dans un répertoire autorisé**:

```
Outil: list_allowed_directories
Arguments: {}
```

2. **Vérifiez les permissions du fichier**:

```
Outil: get_file_info
Arguments:
{
  "path": "/chemin/vers/fichier.txt"
}
```

3. **Vérifiez que le fichier existe**:

```
Outil: get_file_info
Arguments:
{
  "path": "/chemin/vers/fichier.txt"
}
```

### Problèmes de modification de fichiers

Si vous rencontrez des problèmes lors de la modification de fichiers:

1. **Vérifiez que le fichier est accessible en écriture**:

```
Outil: get_file_info
Arguments:
{
  "path": "/chemin/vers/fichier.txt"
}
```

2. **Essayez d'utiliser `edit_file` avec `dryRun: true`** pour voir si les modifications seraient appliquées correctement:

```
Outil: edit_file
Arguments:
{
  "path": "/chemin/vers/fichier.txt",
  "edits": [
    {
      "oldText": "texte à remplacer",
      "newText": "nouveau texte"
    }
  ],
  "dryRun": true
}
```

Pour plus de détails sur la résolution des problèmes, consultez le fichier [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).
<!-- END_SECTION: troubleshooting -->