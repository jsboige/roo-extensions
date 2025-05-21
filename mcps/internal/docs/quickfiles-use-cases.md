# Cas d'utilisation du MCP QuickFiles par mode

## Table des matières

1. [Introduction](#introduction)
2. [Mode Code](#mode-code)
3. [Mode Debug](#mode-debug)
4. [Mode Architect](#mode-architect)
5. [Mode Ask](#mode-ask)
6. [Mode Orchestrator](#mode-orchestrator)
7. [Métriques d'économie de tokens](#métriques-déconomie-de-tokens)
8. [Conclusion](#conclusion)

## Introduction

Ce document présente des cas d'utilisation concrets du MCP QuickFiles pour chaque mode de Roo, avec des exemples détaillés et des métriques d'économie de tokens. Ces exemples sont basés sur des scénarios réels et montrent comment le MCP QuickFiles peut être utilisé efficacement dans différents contextes.

## Mode Code

### Cas d'utilisation 1: Refactorisation d'une API

**Scénario**: Un développeur doit renommer une fonction d'API et mettre à jour tous ses appels dans une base de code JavaScript.

**Approche traditionnelle**:
1. Utiliser `search_files` pour trouver toutes les occurrences
2. Utiliser `read_file` pour chaque fichier concerné
3. Utiliser `write_to_file` pour chaque fichier modifié

**Approche avec QuickFiles**:

```javascript
// 1. Trouver les fichiers concernés (toujours nécessaire)
const searchResult = await search_files({
  path: "src",
  regex: "oldApiFunction\\(",
  file_pattern: "*.js"
});

// Extraire les chemins des fichiers
const filePaths = extractFilePaths(searchResult);

// 2. Utiliser edit_multiple_files pour effectuer toutes les modifications en une seule opération
const editResult = await client.callTool('quickfiles-server', 'edit_multiple_files', {
  files: filePaths.map(path => ({
    path,
    diffs: [
      {
        search: "oldApiFunction(",
        replace: "newApiFunction("
      },
      {
        search: "import { oldApiFunction }",
        replace: "import { newApiFunction }"
      }
    ]
  }))
});

console.log(`${editResult.filter(r => r.modified).length} fichiers modifiés sur ${filePaths.length}`);
```

**Économie de tokens**:
- Pour 10 fichiers modifiés:
  - Approche traditionnelle: ~5000 tokens (500 tokens par fichier × 10 fichiers)
  - Approche QuickFiles: ~1500 tokens (70% d'économie)

### Cas d'utilisation 2: Analyse de dépendances

**Scénario**: Un développeur doit analyser les imports dans plusieurs fichiers pour comprendre les dépendances.

**Approche traditionnelle**:
1. Utiliser `list_files` pour trouver tous les fichiers
2. Utiliser `read_file` pour chaque fichier
3. Analyser les imports dans chaque fichier

**Approche avec QuickFiles**:

```javascript
// Utiliser read_multiple_files avec excerpts pour extraire uniquement les sections d'import
const filesResult = await client.callTool('quickfiles-server', 'read_multiple_files', {
  paths: jsFiles.map(file => ({
    path: file,
    excerpts: [
      { start: 1, end: 20 }  // Les imports sont généralement au début du fichier
    ]
  })),
  show_line_numbers: true
});

// Analyser les imports
const dependencies = {};
for (const fileResult of filesResult) {
  const imports = extractImports(fileResult.content);
  dependencies[fileResult.path] = imports;
}

// Générer un graphe de dépendances
const dependencyGraph = generateDependencyGraph(dependencies);
```

**Économie de tokens**:
- Pour 50 fichiers:
  - Approche traditionnelle: ~25000 tokens (500 tokens par fichier × 50 fichiers)
  - Approche QuickFiles: ~3000 tokens (88% d'économie)

### Cas d'utilisation 3: Migration de framework

**Scénario**: Migration d'un projet de React à Vue.js, nécessitant des modifications similaires dans de nombreux fichiers.

**Approche avec QuickFiles**:

```javascript
// Utiliser edit_multiple_files pour effectuer plusieurs types de modifications
const migrationResult = await client.callTool('quickfiles-server', 'edit_multiple_files', {
  files: componentFiles.map(file => ({
    path: file,
    diffs: [
      // Remplacer les imports React
      {
        search: "import React from 'react';",
        replace: "import Vue from 'vue';"
      },
      // Convertir les composants fonctionnels
      {
        search: "function Component(props) {",
        replace: "export default {"
      },
      // Convertir JSX en template Vue
      {
        search: "return (",
        replace: "template: `"
      },
      // Fermer le template
      {
        search: ");",
        replace: "`,\n  props: {"
      }
      // Autres remplacements...
    ]
  }))
});
```

**Économie de tokens**:
- Pour 30 composants:
  - Approche traditionnelle: ~30000 tokens (1000 tokens par composant × 30 composants)
  - Approche QuickFiles: ~5000 tokens (83% d'économie)

## Mode Debug

### Cas d'utilisation 1: Analyse de logs d'erreur

**Scénario**: Un développeur doit analyser des fichiers de logs volumineux pour identifier la cause d'une erreur.

**Approche traditionnelle**:
1. Utiliser `read_file` pour chaque fichier de log
2. Filtrer manuellement les sections pertinentes

**Approche avec QuickFiles**:

```javascript
// Utiliser read_multiple_files avec excerpts pour cibler les sections d'erreur
const logsResult = await client.callTool('quickfiles-server', 'read_multiple_files', {
  paths: [
    {
      path: 'logs/error.log',
      excerpts: [
        { start: 5000, end: 5050 },  // Section avec l'erreur
        { start: 10000, end: 10050 }  // Section avec le contexte
      ]
    },
    {
      path: 'logs/app.log',
      excerpts: [
        { start: 8000, end: 8050 }  // Section correspondante dans le log d'application
      ]
    }
  ],
  show_line_numbers: true
});

// Analyser les sections d'erreur
const errorAnalysis = analyzeErrorSections(logsResult);
```

**Économie de tokens**:
- Pour des logs totalisant 50000 lignes:
  - Approche traditionnelle: ~100000 tokens
  - Approche QuickFiles: ~5000 tokens (95% d'économie)

### Cas d'utilisation 2: Comparaison de configurations

**Scénario**: Un développeur doit comparer plusieurs fichiers de configuration pour identifier des différences qui pourraient causer un bug.

**Approche avec QuickFiles**:

```javascript
// Lire plusieurs fichiers de configuration
const configsResult = await client.callTool('quickfiles-server', 'read_multiple_files', {
  paths: [
    'config/dev.json',
    'config/staging.json',
    'config/prod.json'
  ],
  show_line_numbers: true
});

// Analyser les différences
const configDiffs = compareConfigurations(configsResult);

// Identifier les différences potentiellement problématiques
const suspiciousDiffs = findSuspiciousDiffs(configDiffs);
```

**Économie de tokens**:
- Pour 5 fichiers de configuration:
  - Approche traditionnelle: ~2500 tokens (500 tokens par fichier × 5 fichiers)
  - Approche QuickFiles: ~1000 tokens (60% d'économie)

### Cas d'utilisation 3: Correction de bugs similaires

**Scénario**: Un développeur a identifié un bug qui se répète dans plusieurs fichiers et doit appliquer la même correction partout.

**Approche avec QuickFiles**:

```javascript
// Appliquer la même correction à plusieurs fichiers
const fixResult = await client.callTool('quickfiles-server', 'edit_multiple_files', {
  files: affectedFiles.map(file => ({
    path: file,
    diffs: [
      {
        search: "if (value = target) {",  // Bug: assignation au lieu de comparaison
        replace: "if (value === target) {"
      }
    ]
  }))
});

// Vérifier les résultats
console.log(`Correction appliquée à ${fixResult.filter(r => r.modified).length} fichiers sur ${affectedFiles.length}`);
```

**Économie de tokens**:
- Pour 20 fichiers:
  - Approche traditionnelle: ~10000 tokens (500 tokens par fichier × 20 fichiers)
  - Approche QuickFiles: ~2000 tokens (80% d'économie)

## Mode Architect

### Cas d'utilisation 1: Cartographie de la structure du projet

**Scénario**: Un architecte doit analyser la structure d'un projet pour comprendre son organisation et identifier des opportunités d'amélioration.

**Approche traditionnelle**:
1. Utiliser `list_files` récursivement pour chaque dossier
2. Agréger manuellement les résultats

**Approche avec QuickFiles**:

```javascript
// Utiliser list_directory_contents pour obtenir une vue complète de la structure
const structureResult = await client.callTool('quickfiles-server', 'list_directory_contents', {
  paths: [
    {
      path: 'src',
      recursive: true
    },
    {
      path: 'tests',
      recursive: true
    }
  ],
  max_lines: 5000
});

// Analyser la structure
const projectStructure = analyzeProjectStructure(structureResult);

// Générer un rapport ou un diagramme
const structureReport = generateStructureReport(projectStructure);
```

**Économie de tokens**:
- Pour un projet avec 500 fichiers:
  - Approche traditionnelle: ~10000 tokens (20 tokens par fichier × 500 fichiers)
  - Approche QuickFiles: ~3000 tokens (70% d'économie)

### Cas d'utilisation 2: Analyse des interfaces et contrats

**Scénario**: Un architecte doit analyser les interfaces et contrats entre différents modules d'une application.

**Approche avec QuickFiles**:

```javascript
// Lire les fichiers d'interface et d'API
const interfacesResult = await client.callTool('quickfiles-server', 'read_multiple_files', {
  paths: interfaceFiles.map(file => ({
    path: file,
    excerpts: [
      // Extraire uniquement les définitions d'interface/classe
      ...findInterfaceDefinitions(file)
    ]
  })),
  show_line_numbers: true
});

// Analyser les interfaces
const interfaceAnalysis = analyzeInterfaces(interfacesResult);

// Générer un rapport de cohérence
const interfaceReport = generateInterfaceReport(interfaceAnalysis);
```

**Économie de tokens**:
- Pour 30 fichiers d'interface:
  - Approche traditionnelle: ~15000 tokens (500 tokens par fichier × 30 fichiers)
  - Approche QuickFiles: ~4500 tokens (70% d'économie)

### Cas d'utilisation 3: Mise à jour de la documentation

**Scénario**: Un architecte doit mettre à jour la documentation technique dans plusieurs fichiers Markdown.

**Approche avec QuickFiles**:

```javascript
// Mettre à jour la documentation dans plusieurs fichiers
const docsUpdateResult = await client.callTool('quickfiles-server', 'edit_multiple_files', {
  files: docFiles.map(file => ({
    path: file,
    diffs: [
      {
        search: "## API v1.0",
        replace: "## API v2.0"
      },
      {
        search: "Pour plus d'informations, consultez [l'ancienne documentation](old-docs.md).",
        replace: "Pour plus d'informations, consultez [la nouvelle documentation](new-docs.md)."
      }
    ]
  }))
});
```

**Économie de tokens**:
- Pour 20 fichiers de documentation:
  - Approche traditionnelle: ~10000 tokens (500 tokens par fichier × 20 fichiers)
  - Approche QuickFiles: ~2000 tokens (80% d'économie)

## Mode Ask

### Cas d'utilisation 1: Recherche d'informations dans la documentation

**Scénario**: Un utilisateur pose une question sur l'API d'un projet, et Roo doit rechercher des informations dans plusieurs fichiers de documentation.

**Approche traditionnelle**:
1. Utiliser `list_files` pour trouver les fichiers de documentation
2. Utiliser `read_file` pour chaque fichier
3. Filtrer manuellement les sections pertinentes

**Approche avec QuickFiles**:

```javascript
// Rechercher des informations dans plusieurs fichiers de documentation
const docsResult = await client.callTool('quickfiles-server', 'read_multiple_files', {
  paths: [
    'docs/api.md',
    'docs/examples.md',
    'README.md',
    'CONTRIBUTING.md'
  ],
  show_line_numbers: false,
  max_lines_per_file: 200,  // Limiter la quantité d'information
  max_total_lines: 500
});

// Extraire les informations pertinentes
const relevantInfo = extractRelevantInfo(docsResult, userQuery);

// Générer une réponse
const response = generateResponse(relevantInfo, userQuery);
```

**Économie de tokens**:
- Pour 5 fichiers de documentation:
  - Approche traditionnelle: ~10000 tokens (2000 tokens par fichier × 5 fichiers)
  - Approche QuickFiles: ~2000 tokens (80% d'économie)

### Cas d'utilisation 2: Exploration de code pour répondre à des questions techniques

**Scénario**: Un utilisateur pose une question sur l'implémentation d'une fonctionnalité, et Roo doit explorer le code pour trouver la réponse.

**Approche avec QuickFiles**:

```javascript
// Rechercher des informations dans le code source
const codeResult = await client.callTool('quickfiles-server', 'read_multiple_files', {
  paths: relevantFiles.map(file => ({
    path: file,
    excerpts: [
      // Extraire uniquement les sections pertinentes
      ...findRelevantCodeSections(file, userQuery)
    ]
  })),
  show_line_numbers: true,
  max_total_lines: 300
});

// Analyser le code
const codeAnalysis = analyzeCode(codeResult, userQuery);

// Générer une réponse
const response = generateTechnicalResponse(codeAnalysis, userQuery);
```

**Économie de tokens**:
- Pour 10 fichiers de code:
  - Approche traditionnelle: ~10000 tokens (1000 tokens par fichier × 10 fichiers)
  - Approche QuickFiles: ~1500 tokens (85% d'économie)

### Cas d'utilisation 3: Collecte de contexte pour répondre à des questions complexes

**Scénario**: Un utilisateur pose une question qui nécessite de comprendre plusieurs aspects du projet (code, configuration, documentation).

**Approche avec QuickFiles**:

```javascript
// Collecter du contexte à partir de plusieurs sources
const contextResult = await Promise.all([
  // Code source
  client.callTool('quickfiles-server', 'read_multiple_files', {
    paths: relevantCodeFiles.map(file => ({
      path: file,
      excerpts: findRelevantCodeSections(file, userQuery)
    })),
    max_total_lines: 200
  }),
  
  // Configuration
  client.callTool('quickfiles-server', 'read_multiple_files', {
    paths: ['config/default.json', 'config/production.json'],
    max_total_lines: 100
  }),
  
  // Documentation
  client.callTool('quickfiles-server', 'read_multiple_files', {
    paths: relevantDocFiles,
    max_total_lines: 200
  })
]);

// Intégrer le contexte
const integratedContext = integrateContext(contextResult);

// Générer une réponse complète
const response = generateComprehensiveResponse(integratedContext, userQuery);
```

**Économie de tokens**:
- Pour un total de 15 fichiers:
  - Approche traditionnelle: ~15000 tokens (1000 tokens par fichier × 15 fichiers)
  - Approche QuickFiles: ~2500 tokens (83% d'économie)

## Mode Orchestrator

### Cas d'utilisation 1: Coordination entre modes pour une tâche complexe

**Scénario**: L'Orchestrator doit coordonner une tâche qui implique l'analyse de code (Mode Code), le débogage (Mode Debug) et la documentation (Mode Architect).

**Approche avec QuickFiles**:

```javascript
// 1. Collecter le contexte initial
const contextResult = await client.callTool('quickfiles-server', 'read_multiple_files', {
  paths: [
    {
      path: 'src/main.js',
      excerpts: [{ start: 10, end: 50 }]
    },
    'package.json',
    'README.md'
  ],
  max_total_lines: 200
});

// 2. Préparer le contexte pour le Mode Code
const codeContext = prepareContextForMode(contextResult, 'code');

// 3. Transférer au Mode Code
const codeResult = await switchToMode('code', codeContext);

// 4. Préparer le contexte pour le Mode Debug
const debugContext = prepareContextForMode(codeResult, 'debug');

// 5. Transférer au Mode Debug
const debugResult = await switchToMode('debug', debugContext);

// 6. Préparer le contexte pour le Mode Architect
const architectContext = prepareContextForMode(debugResult, 'architect');

// 7. Transférer au Mode Architect
const architectResult = await switchToMode('architect', architectContext);

// 8. Intégrer les résultats
const finalResult = integrateResults([codeResult, debugResult, architectResult]);
```

**Économie de tokens**:
- Pour l'ensemble du workflow:
  - Approche traditionnelle: ~30000 tokens
  - Approche QuickFiles: ~10000 tokens (67% d'économie)

### Cas d'utilisation 2: Gestion efficace des ressources entre modes

**Scénario**: L'Orchestrator doit optimiser l'utilisation des tokens lors du transfert de contexte entre modes.

**Approche avec QuickFiles**:

```javascript
// Fonction pour optimiser le transfert de contexte
async function optimizeContextTransfer(context, targetMode, tokenBudget) {
  // Déterminer les fichiers pertinents pour le mode cible
  const relevantFiles = identifyRelevantFiles(context, targetMode);
  
  // Déterminer les sections pertinentes dans chaque fichier
  const relevantSections = identifyRelevantSections(relevantFiles, targetMode);
  
  // Calculer le budget de tokens par fichier
  const tokensPerFile = calculateTokenBudget(tokenBudget, relevantFiles.length);
  
  // Lire les sections pertinentes avec un budget strict
  const optimizedContext = await client.callTool('quickfiles-server', 'read_multiple_files', {
    paths: relevantFiles.map((file, index) => ({
      path: file,
      excerpts: relevantSections[index] || []
    })),
    max_lines_per_file: tokensPerFile / 2,  // Estimation: 2 tokens par ligne
    max_total_lines: tokenBudget / 2
  });
  
  return optimizedContext;
}
```

**Économie de tokens**:
- Pour un transfert de contexte entre modes:
  - Approche traditionnelle: ~10000 tokens
  - Approche QuickFiles: ~3000 tokens (70% d'économie)

### Cas d'utilisation 3: Workflow de développement complet

**Scénario**: L'Orchestrator doit gérer un workflow complet de développement: analyse des exigences, implémentation, tests et documentation.

**Approche avec QuickFiles**:

```javascript
// Workflow complet de développement
async function developmentWorkflow(requirement) {
  // 1. Analyser les exigences (Mode Ask)
  const requirementAnalysis = await analyzeRequirement(requirement);
  
  // 2. Identifier les fichiers à modifier
  const filesToModify = identifyFilesToModify(requirementAnalysis);
  
  // 3. Lire l'état actuel des fichiers
  const currentState = await client.callTool('quickfiles-server', 'read_multiple_files', {
    paths: filesToModify,
    show_line_numbers: true
  });
  
  // 4. Implémenter les modifications (Mode Code)
  const implementationPlan = createImplementationPlan(currentState, requirementAnalysis);
  const implementationResult = await implementChanges(implementationPlan);
  
  // 5. Mettre à jour les tests (Mode Debug)
  const testsToUpdate = identifyTestsToUpdate(filesToModify);
  const testUpdateResult = await updateTests(testsToUpdate, implementationResult);
  
  // 6. Mettre à jour la documentation (Mode Architect)
  const docsToUpdate = identifyDocsToUpdate(filesToModify);
  const docsUpdateResult = await updateDocs(docsToUpdate, implementationResult);
  
  // 7. Vérifier la cohérence globale
  const consistencyCheck = checkConsistency([
    implementationResult,
    testUpdateResult,
    docsUpdateResult
  ]);
  
  return {
    implementation: implementationResult,
    tests: testUpdateResult,
    docs: docsUpdateResult,
    consistency: consistencyCheck
  };
}
```

**Économie de tokens**:
- Pour l'ensemble du workflow:
  - Approche traditionnelle: ~50000 tokens
  - Approche QuickFiles: ~15000 tokens (70% d'économie)

## Métriques d'économie de tokens

### Tableau récapitulatif par mode

| Mode | Cas d'utilisation | Économie moyenne | Facteurs clés |
|------|------------------|-----------------|--------------|
| Code | Refactorisation, analyse de code | 70-85% | Modifications groupées, extraits ciblés |
| Debug | Analyse de logs, correction de bugs | 80-95% | Extraits de logs, modifications groupées |
| Architect | Structure de projet, documentation | 70-80% | Navigation récursive, modifications groupées |
| Ask | Recherche d'informations, contexte | 80-90% | Extraits ciblés, limitation stricte |
| Orchestrator | Coordination, workflows | 65-75% | Transfert de contexte optimisé |

### Calcul des économies

Les économies de tokens sont calculées en comparant:

1. **Approche traditionnelle**: Nombre de tokens utilisés avec les méthodes standard
   ```
   tokens_traditionnels = nombre_fichiers × tokens_par_fichier
   ```

2. **Approche QuickFiles**: Nombre de tokens utilisés avec le MCP QuickFiles
   ```
   tokens_quickfiles = tokens_overhead + tokens_contenu_pertinent
   ```

3. **Économie**:
   ```
   économie = (tokens_traditionnels - tokens_quickfiles) / tokens_traditionnels × 100
   ```

### Facteurs influençant les économies

1. **Taille des fichiers**: Plus les fichiers sont grands, plus les économies sont importantes
2. **Pertinence du contenu**: Plus la portion pertinente est petite par rapport au fichier total, plus les économies sont importantes
3. **Nombre de fichiers**: Plus le nombre de fichiers est grand, plus les économies sont importantes
4. **Complexité des opérations**: Les opérations complexes (comme les refactorisations) bénéficient davantage du traitement par lots

## Conclusion

Le MCP QuickFiles offre des économies significatives de tokens dans tous les modes de Roo, avec des économies moyennes allant de 65% à 95% selon les cas d'utilisation. Ces économies sont particulièrement importantes pour:

1. **Les opérations sur des fichiers volumineux** où seules certaines parties sont pertinentes
2. **Les opérations sur de nombreux fichiers** qui peuvent être traitées en une seule requête
3. **Les workflows complexes** qui impliquent plusieurs modes et nécessitent un transfert efficace de contexte

En intégrant systématiquement le MCP QuickFiles dans les différents modes de Roo, il est possible de réduire considérablement la consommation globale de tokens tout en améliorant l'efficacité et la réactivité du système.