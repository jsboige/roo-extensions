# Nouvelles fonctionnalités du MCP Quickfiles

Ce document décrit les nouvelles fonctionnalités ajoutées au MCP Quickfiles et comment les utiliser.

## Table des matières

1. [Extraction de structure markdown](#extraction-de-structure-markdown)
   - [Outil `extract_markdown_structure`](#outil-extract_markdown_structure)
   - [Extension de `list_directory_contents`](#extension-de-list_directory_contents)
2. [Opérations de fichiers avancées](#opérations-de-fichiers-avancées)
   - [Outil `copy_files`](#outil-copy_files)
   - [Outil `move_files`](#outil-move_files)
3. [Recherche et remplacement avancés](#recherche-et-remplacement-avancés)
   - [Outil `search_in_files`](#outil-search_in_files)
   - [Outil `search_and_replace`](#outil-search_and_replace)
4. [Tests et validation](#tests-et-validation)
   - [Tests unitaires](#tests-unitaires)
   - [Tests manuels](#tests-manuels)
   - [Test intégré](#test-intégré)

## Extraction de structure markdown

### Outil `extract_markdown_structure`

Cet outil permet d'analyser les fichiers markdown et d'extraire les titres avec leurs numéros de ligne. Il est particulièrement utile pour générer des tables des matières, comprendre la structure d'un document markdown ou naviguer dans de grands fichiers markdown.

#### Paramètres

- `paths` (obligatoire) : Tableau des chemins de fichiers markdown à analyser
- `max_depth` (optionnel, défaut: 6) : Profondeur maximale des titres à extraire (1=h1, 2=h1+h2, etc.)
- `include_context` (optionnel, défaut: false) : Inclure du contexte autour des titres
- `context_lines` (optionnel, défaut: 2) : Nombre de lignes de contexte à inclure avant et après chaque titre

#### Exemple d'utilisation

```javascript
const result = await client.callTool('extract_markdown_structure', {
  paths: ['chemin/vers/fichier.md'],
  max_depth: 3,
  include_context: true,
  context_lines: 2
});
```

#### Format de sortie

La sortie est formatée en texte markdown et contient :

- Le chemin du fichier analysé
- La liste des titres trouvés avec leurs numéros de ligne
- Le contexte autour de chaque titre (si demandé)
- Des statistiques sur la répartition des niveaux de titres

Exemple de sortie :

```
## Fichier: chemin/vers/fichier.md
5 titres trouvés:

- [Ligne 1] Titre principal
  - [Ligne 5] Section 1
    - [Ligne 9] Sous-section 1.1
  - [Ligne 13] Section 2
  - [Ligne 21] Section 3

Répartition des titres:
- h1: 1
- h2: 3
- h3: 1
```

### Extension de `list_directory_contents`

L'outil `list_directory_contents` a été étendu pour inclure des informations sur la structure des documents markdown. Pour chaque fichier markdown listé, des informations sur le nombre de titres par niveau sont affichées.

#### Format de sortie étendu

Dans la sortie de `list_directory_contents`, les fichiers markdown incluent maintenant des informations sur leur structure :

```
📄 document.md - 15.2 KB (250 lignes) [h1: 1, h2: 5, h3: 10] - Modifié: 2025-05-15 11:30:00
```

Cette information permet de voir rapidement la complexité et la structure des documents markdown sans avoir à les ouvrir.

## Opérations de fichiers avancées

### Outil `copy_files`

Cet outil permet de copier des fichiers avec diverses options avancées comme les motifs glob, les transformations de noms de fichiers et la gestion des conflits.

#### Paramètres

- `operations` (obligatoire) : Tableau des opérations de copie à effectuer
  - `source` (obligatoire) : Chemin source (peut être un motif glob)
  - `destination` (obligatoire) : Chemin de destination (répertoire ou fichier)
  - `transform` (optionnel) : Transformation à appliquer aux noms de fichiers
    - `pattern` : Motif regex à rechercher dans le nom du fichier
    - `replacement` : Texte de remplacement (peut contenir des références de capture comme $1, $2, etc.)
  - `conflict_strategy` (optionnel, défaut: 'overwrite') : Stratégie en cas de conflit
    - `overwrite` : Écraser le fichier existant
    - `ignore` : Ignorer le fichier s'il existe déjà
    - `rename` : Renommer le fichier avec un suffixe numérique

#### Exemple d'utilisation

```javascript
const result = await client.callTool('copy_files', {
  operations: [
    {
      source: 'source/*.txt',
      destination: 'destination/',
      transform: {
        pattern: 'file(\\d+)',
        replacement: 'document$1'
      },
      conflict_strategy: 'rename'
    }
  ]
});
```

### Outil `move_files`

Cet outil permet de déplacer des fichiers avec les mêmes options avancées que `copy_files`. La différence est que les fichiers sources sont supprimés après la copie.

#### Paramètres

Les mêmes paramètres que `copy_files`.

#### Exemple d'utilisation

```javascript
const result = await client.callTool('move_files', {
  operations: [
    {
      source: 'source/*.md',
      destination: 'destination/',
      transform: {
        pattern: '(.*)\\.md',
        replacement: '$1.markdown'
      }
    }
  ]
});
```

## Recherche et remplacement avancés

### Outil `search_in_files`

Cet outil permet de rechercher des motifs dans plusieurs fichiers/répertoires avec support des expressions régulières et affichage du contexte autour des correspondances.

#### Paramètres

- `paths` (obligatoire) : Tableau des chemins de fichiers ou répertoires à rechercher
- `pattern` (obligatoire) : Expression régulière ou texte à rechercher
- `use_regex` (optionnel, défaut: true) : Utiliser une expression régulière
- `case_sensitive` (optionnel, défaut: false) : Recherche sensible à la casse
- `file_pattern` (optionnel) : Motif glob pour filtrer les fichiers (ex: *.js, *.{js,ts})
- `context_lines` (optionnel, défaut: 2) : Nombre de lignes de contexte à afficher avant et après chaque correspondance
- `max_results_per_file` (optionnel, défaut: 100) : Nombre maximum de résultats par fichier
- `max_total_results` (optionnel, défaut: 1000) : Nombre maximum total de résultats
- `recursive` (optionnel, défaut: true) : Rechercher récursivement dans les sous-répertoires

#### Exemple d'utilisation

```javascript
const result = await client.callTool('search_in_files', {
  paths: ['source'],
  pattern: 'fonction\\w+',
  use_regex: true,
  case_sensitive: false,
  file_pattern: '*.js',
  context_lines: 3
});
```

### Outil `search_and_replace`

Cet outil permet de rechercher et remplacer des motifs dans plusieurs fichiers avec support des expressions régulières et des captures de groupes.

#### Paramètres

Il existe deux façons d'utiliser cet outil :

1. Avec un tableau de fichiers spécifiques :
   - `files` : Tableau des fichiers à modifier avec leurs options
     - `path` : Chemin du fichier à modifier
     - `search` : Expression à rechercher
     - `replace` : Texte de remplacement
     - `use_regex` (optionnel, défaut: true) : Utiliser une expression régulière
     - `case_sensitive` (optionnel, défaut: false) : Recherche sensible à la casse
     - `preview` (optionnel, défaut: false) : Prévisualiser les modifications sans les appliquer

2. Avec des chemins et des options globales :
   - `paths` : Tableau des chemins de fichiers ou répertoires à traiter
   - `search` : Expression à rechercher (globale pour tous les fichiers dans paths)
   - `replace` : Texte de remplacement (global pour tous les fichiers dans paths)
   - `use_regex` (optionnel, défaut: true) : Utiliser une expression régulière
   - `case_sensitive` (optionnel, défaut: false) : Recherche sensible à la casse
   - `file_pattern` (optionnel) : Motif glob pour filtrer les fichiers (ex: *.js, *.{js,ts})
   - `recursive` (optionnel, défaut: true) : Rechercher récursivement dans les sous-répertoires
   - `preview` (optionnel, défaut: false) : Prévisualiser les modifications sans les appliquer

#### Exemples d'utilisation

Avec des fichiers spécifiques :

```javascript
const result = await client.callTool('search_and_replace', {
  files: [
    {
      path: 'source/file1.txt',
      search: 'exemple',
      replace: 'échantillon',
      use_regex: false,
      case_sensitive: false
    }
  ]
});
```

Avec des chemins et des options globales :

```javascript
const result = await client.callTool('search_and_replace', {
  paths: ['source'],
  search: 'exemple(\\w*)',
  replace: 'échantillon$1',
  use_regex: true,
  case_sensitive: false,
  file_pattern: '*.txt',
  preview: true
});
```

## Tests et validation

### Tests unitaires

Des tests unitaires ont été créés pour valider le bon fonctionnement des nouvelles fonctionnalités :

- `__tests__/test-markdown-structure.js` : Tests pour l'extraction de structure markdown
- `__tests__/file-operations.test.js` : Tests pour les opérations de fichiers avancées
- `__tests__/search-replace.test.js` : Tests pour les fonctionnalités de recherche et remplacement

Pour exécuter les tests unitaires :

```bash
npm test
```

### Tests manuels

Des scripts de test manuels sont également disponibles :

- `test-markdown-structure.bat` : Test manuel pour l'extraction de structure markdown
- `test-file-operations.js` / `run-file-operations-test.bat` : Tests manuels pour les opérations de fichiers

### Test intégré

Un script de test intégré a été créé pour vérifier le bon fonctionnement de toutes les nouvelles fonctionnalités ensemble :

- `test-all-features.js` : Test intégré de toutes les fonctionnalités

Pour exécuter tous les tests en une seule commande :

```bash
run-all-tests.bat
```

Ce script exécute :
1. Les tests unitaires avec Jest
2. Le test d'extraction de structure markdown
3. Le test des opérations de fichiers
4. Le test intégré de toutes les fonctionnalités

## Conclusion

Ces nouvelles fonctionnalités étendent considérablement les capacités du MCP Quickfiles, permettant une manipulation plus avancée des fichiers, une meilleure compréhension des documents markdown et des opérations de recherche et remplacement puissantes.

Les tests ont confirmé que ces fonctionnalités fonctionnent correctement et n'interfèrent pas avec les fonctionnalités existantes.