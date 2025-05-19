# Guide d'utilisation optimisée des MCPs

Ce guide explique comment utiliser efficacement les Model Context Protocol (MCP) servers disponibles pour optimiser les performances et réduire le nombre d'interactions nécessaires.

## Table des matières

1. [Introduction](#introduction)
2. [Principes généraux d'optimisation](#principes-généraux-doptimisation)
3. [MCP quickfiles](#mcp-quickfiles)
   - [Lecture multiple de fichiers](#lecture-multiple-de-fichiers)
   - [Édition multiple de fichiers](#édition-multiple-de-fichiers)
   - [Suppression de fichiers](#suppression-de-fichiers)
   - [Listage de répertoires](#listage-de-répertoires)
   - [Extraction de structure Markdown](#extraction-de-structure-markdown)
4. [MCP jinavigator](#mcp-jinavigator)
   - [Conversion de pages web en Markdown](#conversion-de-pages-web-en-markdown)
   - [Conversion multiple de pages web](#conversion-multiple-de-pages-web)
   - [Extraction de plan de pages web](#extraction-de-plan-de-pages-web)
5. [MCP searxng](#mcp-searxng)
   - [Recherche web](#recherche-web)
   - [Lecture de contenu d'URL](#lecture-de-contenu-durl)
6. [Comparaison avec les outils standards](#comparaison-avec-les-outils-standards)
7. [Bonnes pratiques](#bonnes-pratiques)
8. [Résolution de problèmes](#résolution-de-problèmes)

## Introduction

Les Model Context Protocol (MCP) servers sont des extensions qui permettent d'effectuer des opérations complexes sans validation humaine intermédiaire. Ils offrent des outils spécialisés qui peuvent considérablement améliorer l'efficacité des interactions en:

- Réduisant le nombre d'opérations nécessaires
- Diminuant le temps d'attente
- Économisant des tokens
- Simplifiant les workflows complexes

Ce guide se concentre sur l'utilisation optimisée des trois MCPs principaux: quickfiles, jinavigator et searxng.

## Principes généraux d'optimisation

Pour utiliser efficacement les MCPs, suivez ces principes généraux:

1. **Privilégiez systématiquement** l'utilisation des MCPs par rapport aux outils standards nécessitant une validation humaine
2. **Regroupez les opérations similaires** en une seule commande MCP
3. **Utilisez les outils de lecture/écriture multiple** plutôt que des opérations individuelles
4. **Filtrez les données à la source** plutôt que de tout lire puis filtrer
5. **Limitez l'affichage des résultats volumineux** en utilisant les paramètres de pagination

## MCP quickfiles

Le MCP quickfiles est spécialisé dans la manipulation efficace de fichiers multiples.

### Lecture multiple de fichiers

Au lieu de lire plusieurs fichiers un par un avec `read_file`, utilisez `read_multiple_files`:

```xml
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>read_multiple_files</tool_name>
<arguments>
{
  "paths": [
    "chemin/fichier1.js",
    "chemin/fichier2.js",
    "chemin/fichier3.js"
  ],
  "show_line_numbers": true,
  "max_lines_per_file": 2000,
  "max_total_lines": 5000
}
</arguments>
</use_mcp_tool>
```

**Optimisations possibles**:
- Utilisez `max_lines_per_file` et `max_total_lines` pour limiter la taille des résultats
- Utilisez `max_chars_per_file` et `max_total_chars` pour éviter les problèmes de mémoire
- Pour lire des extraits spécifiques, utilisez la syntaxe avec excerpts:

```json
"paths": [
  {
    "path": "chemin/fichier1.js",
    "excerpts": [
      {
        "start": 10,
        "end": 20
      },
      {
        "start": 50,
        "end": 60
      }
    ]
  }
]
```

### Édition multiple de fichiers

Au lieu d'utiliser `apply_diff` ou `search_and_replace` plusieurs fois, utilisez `edit_multiple_files`:

```xml
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>edit_multiple_files</tool_name>
<arguments>
{
  "files": [
    {
      "path": "chemin/fichier1.js",
      "diffs": [
        {
          "search": "ancien code",
          "replace": "nouveau code"
        },
        {
          "search": "autre ancien code",
          "replace": "autre nouveau code"
        }
      ]
    },
    {
      "path": "chemin/fichier2.js",
      "diffs": [
        {
          "search": "ancien code",
          "replace": "nouveau code"
        }
      ]
    }
  ]
}
</arguments>
</use_mcp_tool>
```

**Optimisations possibles**:
- Regroupez plusieurs modifications sur un même fichier dans le tableau `diffs`
- Modifiez plusieurs fichiers en une seule opération
- Utilisez `start_line` pour cibler une section spécifique du fichier

### Suppression de fichiers

Pour supprimer plusieurs fichiers en une seule opération:

```xml
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>delete_files</tool_name>
<arguments>
{
  "paths": [
    "chemin/fichier1.tmp",
    "chemin/fichier2.tmp",
    "chemin/fichier3.tmp"
  ]
}
</arguments>
</use_mcp_tool>
```

### Listage de répertoires

Pour lister le contenu de plusieurs répertoires avec des options avancées:

```xml
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>list_directory_contents</tool_name>
<arguments>
{
  "paths": [
    {
      "path": "src/components",
      "recursive": true,
      "file_pattern": "*.js",
      "sort_by": "modified",
      "sort_order": "desc"
    },
    {
      "path": "src/utils",
      "recursive": false
    }
  ],
  "max_lines": 2000
}
</arguments>
</use_mcp_tool>
```

**Optimisations possibles**:
- Utilisez `file_pattern` pour filtrer les fichiers (ex: `*.js`, `*.{js,ts}`)
- Utilisez `sort_by` et `sort_order` pour trier les résultats
- Limitez le nombre de lignes avec `max_lines`

### Extraction de structure Markdown

Pour générer une représentation Markdown de la structure d'un répertoire:

```xml
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>list_directory_contents</tool_name>
<arguments>
{
  "paths": ["src/projet"],
  "output_format": "markdown",
  "recursive": true,
  "max_depth": 3
}
</arguments>
</use_mcp_tool>
```

**Optimisations possibles**:
- Utilisez `recursive` et `max_depth` pour contrôler la profondeur de l'analyse
- Utilisez `file_pattern` pour filtrer les fichiers inclus dans la structure
- Combinez avec `include_hidden` pour inclure ou exclure les fichiers cachés

**Exemple de sortie**:
```markdown
# Structure du répertoire: src/projet

## Structure

- 📁 **components**
  - 📄 Button.js
  - 📄 Input.js
- 📁 **utils**
  - 📄 format.js
  - 📄 validation.js
- 📄 index.js
- 📄 README.md
```

Pour plus de détails sur cette fonctionnalité, consultez la [documentation complète](../mcps/quickfiles/MARKDOWN_EXTRACTION.md).

## MCP jinavigator

Le MCP jinavigator est spécialisé dans l'extraction et la conversion de contenu web.

### Conversion de pages web en Markdown

Pour convertir une page web en Markdown:

```xml
<use_mcp_tool>
<server_name>jinavigator</server_name>
<tool_name>convert_web_to_markdown</tool_name>
<arguments>
{
  "url": "https://example.com",
  "start_line": 1,
  "end_line": 500
}
</arguments>
</use_mcp_tool>
```

**Optimisations possibles**:
- Utilisez `start_line` et `end_line` pour extraire une partie spécifique du contenu
- Accédez directement à une ressource avec `access_mcp_resource`:

```xml
<access_mcp_resource>
<server_name>jinavigator</server_name>
<uri>jina://https://example.com</uri>
</access_mcp_resource>
```

### Conversion multiple de pages web

Pour convertir plusieurs pages web en une seule opération:

```xml
<use_mcp_tool>
<server_name>jinavigator</server_name>
<tool_name>multi_convert</tool_name>
<arguments>
{
  "urls": [
    {"url": "https://example.com"},
    {"url": "https://developer.mozilla.org/fr/docs/Web/JavaScript", "start_line": 10, "end_line": 50},
    {"url": "https://docs.microsoft.com/fr-fr/powershell/"}
  ]
}
</arguments>
</use_mcp_tool>
```

### Extraction de plan de pages web

Pour extraire le plan hiérarchique des titres d'une ou plusieurs pages web:

```xml
<use_mcp_tool>
<server_name>jinavigator</server_name>
<tool_name>extract_markdown_outline</tool_name>
<arguments>
{
  "urls": [
    {"url": "https://example.com"},
    {"url": "https://developer.mozilla.org/fr/docs/Web/JavaScript"}
  ],
  "max_depth": 3
}
</arguments>
</use_mcp_tool>
```

**Optimisations possibles**:
- Ajustez `max_depth` pour contrôler la profondeur des titres extraits (1=h1, 2=h1+h2, etc.)

## MCP searxng

Le MCP searxng est spécialisé dans la recherche web et l'extraction de contenu.

### Recherche web

Pour effectuer une recherche web:

```xml
<use_mcp_tool>
<server_name>searxng</server_name>
<tool_name>searxng_web_search</tool_name>
<arguments>
{
  "query": "JavaScript latest features ES2023",
  "pageno": 1,
  "time_range": "month",
  "language": "fr",
  "safesearch": "0"
}
</arguments>
</use_mcp_tool>
```

**Optimisations possibles**:
- Utilisez `time_range` pour limiter les résultats à une période spécifique ("day", "month", "year")
- Utilisez `language` pour spécifier la langue des résultats
- Utilisez `pageno` pour accéder aux pages suivantes des résultats

### Lecture de contenu d'URL

Pour lire le contenu d'une URL spécifique:

```xml
<use_mcp_tool>
<server_name>searxng</server_name>
<tool_name>web_url_read</tool_name>
<arguments>
{
  "url": "https://example.com/article"
}
</arguments>
</use_mcp_tool>
```

## Comparaison avec les outils standards

| Opération | Outil standard | MCP | Avantage MCP |
|-----------|----------------|-----|--------------|
| Lire plusieurs fichiers | Multiples `read_file` | `quickfiles.read_multiple_files` | Une seule opération, pas de validation intermédiaire |
| Modifier plusieurs fichiers | Multiples `apply_diff` | `quickfiles.edit_multiple_files` | Une seule opération, modifications groupées |
| Lister des fichiers | `list_files` | `quickfiles.list_directory_contents` | Options avancées de filtrage et tri |
| Convertir une page web | `browser_action` | `jinavigator.convert_web_to_markdown` | Pas de manipulation de navigateur, résultat structuré |
| Rechercher sur le web | `browser_action` | `searxng.searxng_web_search` | Pas de manipulation de navigateur, résultats structurés |

## Bonnes pratiques

1. **Planifiez vos opérations**: Avant d'utiliser un MCP, identifiez toutes les opérations similaires que vous pourriez regrouper

2. **Filtrez à la source**: Utilisez les paramètres de filtrage des MCPs plutôt que de filtrer les résultats après coup

3. **Limitez les résultats**: Utilisez les paramètres de limitation pour éviter de surcharger le contexte

4. **Utilisez les formats appropriés**: Pour les patterns de fichiers, utilisez la syntaxe glob (ex: `*.{js,ts}`)

5. **Commandes PowerShell**: N'utilisez PAS la syntaxe "&&" pour chaîner les commandes (incompatible avec PowerShell). Utilisez plutôt le point-virgule ";" ou les blocs de commandes avec des variables:
   ```powershell
   $dir = "chemin"; Set-Location $dir; Get-ChildItem
   ```

## Résolution de problèmes

| Problème | Cause possible | Solution |
|----------|----------------|----------|
| Timeout lors de la lecture de fichiers volumineux | Fichiers trop grands | Utilisez `max_lines_per_file` et `max_chars_per_file` |
| Erreur lors de la conversion de pages web | Page inaccessible ou protégée | Vérifiez l'URL ou essayez une autre page |
| Résultats de recherche non pertinents | Requête trop générique | Affinez la requête et utilisez `time_range` |
| Modifications de fichiers non appliquées | Pattern de recherche incorrect | Vérifiez que le pattern correspond exactement au texte à remplacer |
| Erreur "MCP non disponible" | Serveur MCP non démarré | Vérifiez que le serveur MCP est en cours d'exécution |