# Extraction de Structure Markdown dans QuickFiles

## Description de la fonctionnalité

Le serveur MCP QuickFiles intègre désormais une fonctionnalité d'extraction de structure de répertoires avec affichage des titres des fichiers markdown. Cette fonctionnalité permet non seulement de générer une représentation visuelle et hiérarchique de la structure de fichiers et dossiers, mais aussi d'afficher le squelette des titres des fichiers markdown directement dans l'arborescence.

Cette option d'exploration supplémentaire est particulièrement utile pour comprendre rapidement le contenu des fichiers markdown sans avoir à les ouvrir individuellement, facilitant ainsi la navigation dans les documentations, les wikis ou tout projet contenant de nombreux fichiers markdown.

Cette fonctionnalité est implémentée comme une option de l'outil `list_directory_contents` existant, permettant une intégration transparente avec les workflows actuels.

## Intégration dans QuickFiles

L'extraction de structure markdown est intégrée à l'outil `list_directory_contents` via le paramètre booléen `extract_markdown_structure`. Lorsque ce paramètre est défini sur `true`, l'outil affiche non seulement la structure des répertoires et fichiers, mais extrait également les titres des fichiers markdown et les affiche directement sous chaque fichier .md dans l'arborescence.

### Modifications apportées

- Ajout du paramètre optionnel `extract_markdown_structure` à l'outil `list_directory_contents`
- Implémentation de l'extraction des titres des fichiers markdown
- Utilisation d'icônes spécifiques (📑, 📌) pour différencier les titres selon leur niveau
- Indentation correcte pour montrer la hiérarchie des titres par rapport au fichier
- Formatage hiérarchique avec indentation pour représenter la structure de répertoires

## Utilisation

### Syntaxe de base

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "list_directory_contents",
    "arguments": {
      "paths": ["chemin/vers/repertoire"],
      "extract_markdown_structure": true
    }
  }
}
```

### Paramètres

| Paramètre | Type | Description |
|-----------|------|-------------|
| paths | array | Tableau des chemins de répertoires à analyser |
| extract_markdown_structure | boolean | (Optionnel) Si `true`, affiche le squelette des titres des fichiers markdown dans l'arborescence |
| recursive | boolean | (Optionnel) Si `true`, analyse récursivement les sous-répertoires |
| include_hidden | boolean | (Optionnel) Si `true`, inclut les fichiers et dossiers cachés |
| max_depth | number | (Optionnel) Profondeur maximale pour l'analyse récursive |

## Exemples d'utilisation

### Exemple 1: Structure simple d'un répertoire

#### Requête
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "list_directory_contents",
    "arguments": {
      "paths": ["/chemin/vers/projet"],
      "extract_markdown_structure": true
    }
  }
}
```

#### Réponse
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "content": [
      {
        "path": "/chemin/vers/projet",
        "text": "# Structure du répertoire: /chemin/vers/projet\n\n## Structure\n\n- 📁 **src**\n- 📁 **docs**\n- 📄 README.md\n  - 📑 *Test Project*\n-  package.json\n- 📄 .gitignore\n"
      }
    ]
  }
}
```

### Exemple 2: Structure récursive avec profondeur maximale

#### Requête
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "list_directory_contents",
    "arguments": {
      "paths": ["/chemin/vers/projet"],
      "extract_markdown_structure": true,
      "recursive": true,
      "max_depth": 2
    }
  }
}
```

#### Réponse
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {
    "content": [
      {
        "path": "/chemin/vers/projet",
        "text": "# Structure du répertoire: /chemin/vers/projet\n\n## Structure\n\n- 📁 **src**\n  - 📄 index.js\n  - 📄 utils.js\n  - 📁 **components**\n- 📁 **docs**\n  - 📄 guide.md\n    - 📑 *User Guide*\n  -  api.md\n    - 📑 *API Reference*\n- � README.md\n  - 📑 *Test Project*\n- � package.json\n- 📄 .gitignore\n"
      }
    ]
  }
}
```

### Exemple 3: Analyse de plusieurs répertoires

#### Requête
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "list_directory_contents",
    "arguments": {
      "paths": ["/chemin/vers/projet/src", "/chemin/vers/projet/docs"],
      "extract_markdown_structure": true,
      "recursive": true
    }
  }
}
```

#### Réponse
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "result": {
    "content": [
      {
        "path": "/chemin/vers/projet/src",
        "text": "# Structure du répertoire: /chemin/vers/projet/src\n\n## Structure\n\n- 📄 index.js\n- 📄 utils.js\n- 📁 **components**\n  - 📄 Button.js\n  - 📄 Input.js\n"
      },
      {
        "path": "/chemin/vers/projet/docs",
        "text": "# Structure du répertoire: /chemin/vers/projet/docs\n\n## Structure\n\n- 📄 guide.md\n  - 📑 *User Guide*\n- 📄 api.md\n  - 📑 *API Reference*\n"
      }
    ]
  }
}
```

## Exemples de sortie au format Markdown

Voici un exemple de la sortie Markdown générée pour un projet typique:

```markdown
# Structure du répertoire: /chemin/vers/projet

## Structure

- 📁 **src**
  - 📄 index.js
  - 📄 utils.js
  - 📁 **components**
    - 📄 Button.js
    - 📄 Input.js
- 📁 **docs**
  - 📄 guide.md
    - 📑 *User Guide*
    - 📌 *Introduction*
    - 📌 *Getting Started*
  - 📄 api.md
    - 📑 *API Reference*
    - 📌 *Endpoints*
    - 📌 *Parameters*
- 📁 **tests**
  - 📄 index.test.js
- 📄 README.md
  - 📑 *Test Project*
  - 📌 *Overview*
  - 📌 *Installation*
- 📄 package.json
- 📄 .gitignore
```

Ce format est particulièrement utile pour:
- Documenter la structure d'un projet
- Inclure une vue d'ensemble des fichiers dans une documentation
- Générer des rapports sur l'organisation des fichiers

## Cas d'utilisation pratiques

### 1. Documentation de projet

L'extraction de structure Markdown est idéale pour générer automatiquement une section "Structure du projet" dans votre documentation. Cela permet aux nouveaux développeurs de comprendre rapidement l'organisation du code.

```javascript
// Exemple d'utilisation dans un script de génération de documentation
const projectStructure = await quickfilesMCP.callTool('list_directory_contents', {
  paths: ['/chemin/vers/projet'],
  extract_markdown_structure: true,
  recursive: true,
  max_depth: 3
});

const readmeContent = `
# Mon Projet

## Description
Ce projet fait des choses incroyables.

## Structure du projet
${projectStructure.result.content[0].text}

## Installation
...
`;

fs.writeFileSync('README.md', readmeContent);
```

### 2. Rapports d'analyse de code

Utilisez cette fonctionnalité pour générer des rapports sur la structure de votre code, par exemple pour identifier des problèmes d'organisation ou pour documenter des changements structurels.

```javascript
// Exemple d'utilisation dans un script d'analyse
const beforeRefactoring = await quickfilesMCP.callTool('list_directory_contents', {
  paths: ['/chemin/vers/projet/avant'],
  extract_markdown_structure: true,
  recursive: true
});

const afterRefactoring = await quickfilesMCP.callTool('list_directory_contents', {
  paths: ['/chemin/vers/projet/apres'],
  extract_markdown_structure: true,
  recursive: true
});

const report = `
# Rapport de refactoring

## Structure avant refactoring
${beforeRefactoring.result.content[0].text}

## Structure après refactoring
${afterRefactoring.result.content[0].text}
`;

fs.writeFileSync('refactoring-report.md', report);
```

### 3. Intégration avec les modèles de langage

Cette fonctionnalité est particulièrement utile pour fournir un contexte structurel à un modèle de langage comme Roo. En générant une représentation Markdown de la structure du projet, vous pouvez aider le modèle à mieux comprendre l'organisation du code.

```javascript
// Exemple d'utilisation avec Roo
const projectStructure = await quickfilesMCP.callTool('list_directory_contents', {
  paths: ['/chemin/vers/projet'],
  extract_markdown_structure: true,
  recursive: true
});

// Fournir la structure du projet à Roo
const rooResponse = await roo.sendMessage(`
Voici la structure de mon projet:

${projectStructure.result.content[0].text}

Pouvez-vous me suggérer des améliorations pour l'organisation des fichiers?
`);
```

### 4. Génération de documentation pour les utilisateurs finaux

Utilisez cette fonctionnalité pour générer une documentation claire sur la structure des fichiers fournis aux utilisateurs finaux, par exemple dans un package distribué.

```javascript
// Exemple de script de génération de documentation pour un package distribué
const packageStructure = await quickfilesMCP.callTool('list_directory_contents', {
  paths: ['/chemin/vers/package/dist'],
  extract_markdown_structure: true,
  recursive: true
});

const userGuide = `
# Guide d'utilisation

## Fichiers inclus dans le package
${packageStructure.result.content[0].text}

## Installation
...
`;

fs.writeFileSync('user-guide.md', userGuide);
```

## Conclusion

La fonctionnalité d'extraction de structure markdown de QuickFiles offre une méthode simple et efficace pour explorer les fichiers markdown dans leur contexte. En affichant les titres directement dans l'arborescence des fichiers, elle permet de comprendre rapidement le contenu et l'organisation des documents sans avoir à les ouvrir individuellement.

Cette fonctionnalité est particulièrement utile pour:
- Explorer des wikis ou des documentations volumineuses
- Comprendre la structure de documentation d'un projet
- Naviguer efficacement dans des répertoires contenant de nombreux fichiers markdown
- Fournir un aperçu du contenu des fichiers markdown aux modèles de langage

Elle s'intègre parfaitement aux workflows existants et peut être utilisée en combinaison avec d'autres outils de QuickFiles, comme `read_multiple_files`, pour fournir une compréhension complète d'un projet ou d'un ensemble de fichiers.