# Guide d'intégration du MCP QuickFiles dans les modes de Roo

## Table des matières

1. [Introduction](#introduction)
2. [Principes d'intégration](#principes-dintégration)
3. [Configuration par mode](#configuration-par-mode)
4. [Suggestions automatiques](#suggestions-automatiques)
5. [Métriques et suivi](#métriques-et-suivi)
6. [Exemples d'implémentation](#exemples-dimplémentation)
7. [Feuille de route d'intégration](#feuille-de-route-dintégration)

## Introduction

Ce document présente une stratégie d'intégration du MCP QuickFiles dans les différents modes de Roo pour maximiser son utilisation et optimiser la consommation de tokens. L'objectif est de configurer chaque mode pour qu'il utilise automatiquement les fonctionnalités du MCP QuickFiles lorsque c'est pertinent, sans nécessiter d'intervention manuelle de l'utilisateur.

## Principes d'intégration

### 1. Détection automatique des opportunités

Chaque mode doit être capable de détecter automatiquement les situations où l'utilisation du MCP QuickFiles serait bénéfique :

- Opérations sur plusieurs fichiers
- Lecture de fichiers volumineux où seules certaines parties sont pertinentes
- Navigation dans des structures de répertoires complexes
- Modifications similaires à appliquer à plusieurs fichiers

### 2. Substitution transparente

L'intégration doit être transparente pour l'utilisateur :

- Remplacer automatiquement les appels standards par des appels au MCP QuickFiles
- Maintenir la même interface et les mêmes formats de retour
- Conserver la compatibilité avec le code existant

### 3. Feedback sur les économies

Fournir un feedback sur les économies réalisées :

- Afficher les économies de tokens en temps réel
- Proposer des optimisations supplémentaires
- Éduquer l'utilisateur sur les bonnes pratiques

## Configuration par mode

### Mode Code

#### Intégration recommandée

1. **Lecture de fichiers** :
   - Intercepter les appels à `read_file` multiples et les regrouper en un seul appel à `read_multiple_files`
   - Détecter les patterns de lecture partielle et utiliser les extraits

2. **Édition de fichiers** :
   - Regrouper les modifications similaires à travers plusieurs fichiers
   - Utiliser `edit_multiple_files` pour les refactorisations

3. **Navigation** :
   - Remplacer les appels récursifs à `list_files` par `list_directory_contents`

#### Configuration spécifique

```javascript
// Configuration pour le mode Code
const codeModeMcpConfig = {
  // Seuil à partir duquel regrouper les lectures de fichiers
  fileReadBatchThreshold: 3,
  
  // Taille maximale de fichier avant d'utiliser des extraits
  largeFileThreshold: 1000, // lignes
  
  // Nombre maximum de fichiers à éditer en une seule opération
  maxBatchEditFiles: 10,
  
  // Activer la détection automatique des opportunités
  enableAutoDetection: true,
  
  // Afficher les économies de tokens
  showTokenSavings: true
};
```

### Mode Debug

#### Intégration recommandée

1. **Analyse de logs** :
   - Utiliser `read_multiple_files` avec extraits pour cibler les sections pertinentes des logs
   - Activer la numérotation des lignes pour faciliter le débogage

2. **Comparaison de fichiers** :
   - Charger efficacement les différentes versions d'un fichier pour comparaison

3. **Correction de bugs** :
   - Utiliser `edit_multiple_files` pour corriger des bugs similaires dans plusieurs fichiers

#### Configuration spécifique

```javascript
// Configuration pour le mode Debug
const debugModeMcpConfig = {
  // Toujours activer la numérotation des lignes
  alwaysShowLineNumbers: true,
  
  // Contexte par défaut autour des erreurs (lignes)
  defaultErrorContext: 10,
  
  // Taille maximale de logs à charger avant d'utiliser des extraits
  maxLogSizeBeforeExcerpts: 500, // lignes
  
  // Patterns de fichiers à toujours traiter avec QuickFiles
  priorityFilePatterns: [
    '*.log',
    'error-*.txt',
    'debug-*.txt'
  ]
};
```

### Mode Architect

#### Intégration recommandée

1. **Analyse de structure** :
   - Utiliser `list_directory_contents` pour cartographier efficacement les projets
   - Générer des visualisations de la structure du projet

2. **Documentation** :
   - Utiliser `read_multiple_files` pour analyser les interfaces et les dépendances
   - Utiliser `edit_multiple_files` pour mettre à jour la documentation

#### Configuration spécifique

```javascript
// Configuration pour le mode Architect
const architectModeMcpConfig = {
  // Toujours utiliser la récursion pour list_directory_contents
  alwaysRecursive: true,
  
  // Types de fichiers à inclure dans l'analyse architecturale
  architectureFileTypes: [
    '*.js', '*.ts', '*.jsx', '*.tsx',
    '*.py', '*.java', '*.go',
    'package.json', 'tsconfig.json', '*.csproj'
  ],
  
  // Types de fichiers à exclure
  excludeFileTypes: [
    'node_modules/**',
    'dist/**',
    'build/**'
  ],
  
  // Activer la génération automatique de diagrammes
  enableDiagramGeneration: true
};
```

### Mode Ask

#### Intégration recommandée

1. **Recherche d'informations** :
   - Utiliser `read_multiple_files` pour extraire efficacement le contexte pertinent
   - Limiter strictement la quantité d'information chargée

2. **Exploration de documentation** :
   - Utiliser `list_directory_contents` pour identifier les fichiers de documentation

#### Configuration spécifique

```javascript
// Configuration pour le mode Ask
const askModeMcpConfig = {
  // Limite stricte de lignes par fichier
  strictMaxLinesPerFile: 200,
  
  // Limite stricte de lignes totales
  strictMaxTotalLines: 1000,
  
  // Priorité aux fichiers de documentation
  documentationPriority: [
    'README.md',
    'docs/*.md',
    '*.md',
    'comments'
  ],
  
  // Activer l'extraction intelligente de contexte
  enableSmartContextExtraction: true
};
```

### Mode Orchestrator

#### Intégration recommandée

1. **Coordination entre modes** :
   - Utiliser toutes les fonctionnalités pour optimiser le transfert de contexte
   - Contrôler strictement la consommation de tokens

2. **Gestion des ressources** :
   - Surveiller et optimiser l'utilisation des tokens à travers les modes

#### Configuration spécifique

```javascript
// Configuration pour le mode Orchestrator
const orchestratorModeMcpConfig = {
  // Limite globale de tokens par session
  globalTokenBudget: 100000,
  
  // Répartition du budget par mode (%)
  tokenBudgetAllocation: {
    code: 40,
    debug: 20,
    architect: 15,
    ask: 25
  },
  
  // Seuils d'optimisation automatique
  optimizationThresholds: {
    aggressive: 0.8,  // 80% du budget utilisé
    moderate: 0.5,    // 50% du budget utilisé
    light: 0.3        // 30% du budget utilisé
  },
  
  // Activer l'optimisation automatique
  enableAutoOptimization: true
};
```

## Suggestions automatiques

Pour encourager l'utilisation du MCP QuickFiles, chaque mode peut intégrer un système de suggestions automatiques qui propose d'utiliser les fonctionnalités du MCP QuickFiles lorsque c'est pertinent.

### Exemples de suggestions

1. **Mode Code** :
   ```
   💡 Détection de 5 lectures de fichiers similaires. 
   Utiliser read_multiple_files pourrait économiser ~75% de tokens.
   ```

2. **Mode Debug** :
   ```
   💡 Ce fichier de log contient 5000 lignes, mais seules les lignes 
   3000-3100 semblent pertinentes pour cette erreur.
   Utiliser read_multiple_files avec excerpts pourrait économiser ~90% de tokens.
   ```

3. **Mode Architect** :
   ```
   💡 Vous analysez une structure de projet complexe.
   Utiliser list_directory_contents avec recursive=true 
   pourrait économiser ~85% de tokens.
   ```

### Implémentation des suggestions

```javascript
// Exemple d'implémentation de suggestions automatiques
function suggestMcpOptimization(context, mode) {
  // Analyser le contexte pour détecter les opportunités
  const opportunities = detectOpportunities(context, mode);
  
  if (opportunities.length === 0) return;
  
  // Générer et afficher les suggestions
  for (const opportunity of opportunities) {
    const suggestion = formatSuggestion(opportunity, mode);
    displaySuggestion(suggestion);
    
    // Proposer d'appliquer automatiquement la suggestion
    if (opportunity.canAutoApply) {
      offerAutoApply(opportunity);
    }
  }
}
```

## Métriques et suivi

Pour mesurer l'efficacité de l'intégration et encourager l'utilisation du MCP QuickFiles, il est recommandé de mettre en place un système de métriques et de suivi.

### Métriques à suivre

1. **Taux d'utilisation** :
   - Pourcentage d'opérations éligibles utilisant le MCP QuickFiles
   - Répartition par mode et par fonctionnalité

2. **Économies de tokens** :
   - Tokens économisés par session
   - Économies cumulées sur le temps
   - Comparaison avec les méthodes traditionnelles

3. **Performance** :
   - Temps de réponse des opérations
   - Taux de réussite des opérations

### Tableau de bord proposé

```
📊 Utilisation du MCP QuickFiles (Session actuelle)

Mode Code:
  - Utilisation: 78% des opérations éligibles
  - Économie: ~12,500 tokens (équivalent à $0.25)
  - Top fonctionnalité: edit_multiple_files (85% d'économie)

Mode Debug:
  - Utilisation: 92% des opérations éligibles
  - Économie: ~8,300 tokens (équivalent à $0.17)
  - Top fonctionnalité: read_multiple_files avec excerpts (93% d'économie)

Total cumulé:
  - Économie: ~32,800 tokens (équivalent à $0.66)
  - Taux d'adoption: 85%
```

## Exemples d'implémentation

### Intercepteur pour le mode Code

```javascript
// Exemple d'intercepteur pour le mode Code
class CodeModeInterceptor {
  constructor(config) {
    this.config = config;
    this.pendingFileReads = [];
    this.pendingFileEdits = [];
    this.tokensSaved = 0;
  }
  
  // Intercepter les appels à read_file
  async interceptReadFile(path, options) {
    // Ajouter à la liste des lectures en attente
    this.pendingFileReads.push({ path, options });
    
    // Si nous avons atteint le seuil, utiliser read_multiple_files
    if (this.pendingFileReads.length >= this.config.fileReadBatchThreshold) {
      return this.processBatchFileReads();
    }
    
    // Sinon, utiliser la méthode standard
    const result = await originalReadFile(path, options);
    
    // Programmer un traitement différé pour les lectures restantes
    this.scheduleProcessing();
    
    return result;
  }
  
  // Traiter un lot de lectures de fichiers
  async processBatchFileReads() {
    const batch = [...this.pendingFileReads];
    this.pendingFileReads = [];
    
    // Convertir en format pour read_multiple_files
    const paths = batch.map(item => item.path);
    
    // Estimer les tokens qui auraient été utilisés
    const standardTokens = estimateStandardTokens(batch);
    
    // Appeler read_multiple_files
    const result = await client.callTool('quickfiles-server', 'read_multiple_files', {
      paths,
      show_line_numbers: shouldShowLineNumbers(batch),
      max_lines_per_file: this.config.largeFileThreshold,
      max_total_lines: this.config.largeFileThreshold * paths.length
    });
    
    // Estimer les tokens utilisés avec QuickFiles
    const quickfilesTokens = estimateQuickfilesTokens(result);
    
    // Calculer et enregistrer l'économie
    const tokensSaved = standardTokens - quickfilesTokens;
    this.tokensSaved += tokensSaved;
    
    // Afficher l'économie si configuré
    if (this.config.showTokenSavings) {
      displayTokenSavings(tokensSaved);
    }
    
    // Convertir le résultat au format attendu par l'appelant
    return convertResultFormat(result, batch);
  }
  
  // Méthodes similaires pour edit_multiple_files, etc.
  // ...
}
```

### Détecteur d'opportunités pour le mode Debug

```javascript
// Exemple de détecteur d'opportunités pour le mode Debug
class DebugOpportunityDetector {
  constructor(config) {
    this.config = config;
    this.detectedPatterns = new Map();
  }
  
  // Analyser un fichier de log pour détecter des patterns
  analyzeLogFile(content, path) {
    // Détecter les sections d'erreur
    const errorSections = this.detectErrorSections(content);
    
    if (errorSections.length > 0) {
      // Enregistrer les opportunités détectées
      this.detectedPatterns.set(path, {
        type: 'error_sections',
        sections: errorSections,
        potentialSavings: this.calculatePotentialSavings(content, errorSections)
      });
      
      return true;
    }
    
    return false;
  }
  
  // Détecter les sections contenant des erreurs
  detectErrorSections(content) {
    const lines = content.split('\n');
    const errorSections = [];
    
    // Rechercher des patterns d'erreur
    for (let i = 0; i < lines.length; i++) {
      if (this.isErrorLine(lines[i])) {
        // Extraire le contexte autour de l'erreur
        const start = Math.max(0, i - this.config.defaultErrorContext);
        const end = Math.min(lines.length - 1, i + this.config.defaultErrorContext);
        
        errorSections.push({ start: start + 1, end: end + 1 });
        
        // Sauter le contexte pour éviter les doublons
        i = end;
      }
    }
    
    return this.mergeOverlappingSections(errorSections);
  }
  
  // Vérifier si une ligne contient une erreur
  isErrorLine(line) {
    const errorPatterns = [
      /error/i, /exception/i, /fail/i, /crash/i,
      /fatal/i, /critical/i, /bug/i, /issue/i
    ];
    
    return errorPatterns.some(pattern => pattern.test(line));
  }
  
  // Fusionner les sections qui se chevauchent
  mergeOverlappingSections(sections) {
    if (sections.length <= 1) return sections;
    
    sections.sort((a, b) => a.start - b.start);
    
    const merged = [sections[0]];
    
    for (let i = 1; i < sections.length; i++) {
      const current = sections[i];
      const previous = merged[merged.length - 1];
      
      if (current.start <= previous.end) {
        // Chevauchement, fusionner
        previous.end = Math.max(previous.end, current.end);
      } else {
        // Pas de chevauchement, ajouter
        merged.push(current);
      }
    }
    
    return merged;
  }
  
  // Calculer les économies potentielles
  calculatePotentialSavings(content, sections) {
    const totalLines = content.split('\n').length;
    const extractedLines = sections.reduce((sum, section) => sum + (section.end - section.start + 1), 0);
    
    // Estimer les tokens pour la lecture complète
    const fullReadTokens = estimateTokensForLines(totalLines);
    
    // Estimer les tokens pour la lecture des extraits
    const extractTokens = estimateTokensForLines(extractedLines) + sections.length * 10; // 10 tokens par extrait pour les métadonnées
    
    return {
      fullReadTokens,
      extractTokens,
      savings: fullReadTokens - extractTokens,
      savingsPercentage: ((fullReadTokens - extractTokens) / fullReadTokens) * 100
    };
  }
  
  // Générer une suggestion basée sur les opportunités détectées
  generateSuggestion(path) {
    const opportunity = this.detectedPatterns.get(path);
    
    if (!opportunity) return null;
    
    if (opportunity.type === 'error_sections') {
      return {
        message: `Ce fichier de log contient ${opportunity.sections.length} sections d'erreur. Utiliser read_multiple_files avec excerpts pourrait économiser ~${opportunity.savingsPercentage.toFixed(0)}% de tokens.`,
        code: `
// Exemple de code optimisé
const result = await client.callTool('quickfiles-server', 'read_multiple_files', {
  paths: [{
    path: '${path}',
    excerpts: ${JSON.stringify(opportunity.sections)}
  }],
  show_line_numbers: true
});`,
        savings: opportunity.savings
      };
    }
    
    return null;
  }
}
```

## Feuille de route d'intégration

Pour maximiser l'adoption du MCP QuickFiles, voici une feuille de route d'intégration progressive :

### Phase 1: Intégration de base (1-2 semaines)

1. **Implémentation des intercepteurs** :
   - Développer les intercepteurs pour chaque mode
   - Tester avec des cas d'utilisation simples

2. **Configuration initiale** :
   - Définir les configurations par défaut pour chaque mode
   - Mettre en place les mécanismes de substitution transparente

3. **Documentation de base** :
   - Créer une documentation utilisateur initiale
   - Former l'équipe sur l'utilisation du MCP QuickFiles

### Phase 2: Optimisation et feedback (2-3 semaines)

1. **Système de suggestions** :
   - Implémenter le système de détection d'opportunités
   - Développer les mécanismes de suggestion

2. **Métriques et suivi** :
   - Mettre en place le système de suivi des métriques
   - Créer le tableau de bord d'utilisation

3. **Optimisation des performances** :
   - Analyser les performances et optimiser les implémentations
   - Ajuster les configurations en fonction des retours

### Phase 3: Intégration avancée (3-4 semaines)

1. **Intégration avec d'autres MCPs** :
   - Développer des workflows combinés avec Jinavigator
   - Créer des exemples de workflows complets

2. **Fonctionnalités avancées** :
   - Implémenter l'extraction intelligente de contexte
   - Développer des mécanismes d'optimisation automatique

3. **Formation et adoption** :
   - Former tous les utilisateurs sur les bonnes pratiques
   - Promouvoir activement l'utilisation du MCP QuickFiles

### Phase 4: Évaluation et amélioration continue (en cours)

1. **Analyse d'utilisation** :
   - Analyser les patterns d'utilisation réels
   - Identifier les opportunités d'amélioration

2. **Optimisation continue** :
   - Ajuster les configurations en fonction des données d'utilisation
   - Développer de nouvelles fonctionnalités selon les besoins

3. **Documentation évolutive** :
   - Mettre à jour la documentation avec de nouveaux exemples
   - Partager les meilleures pratiques et les cas de réussite