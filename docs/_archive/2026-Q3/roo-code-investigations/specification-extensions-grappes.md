> **Archived 2026-07-21** — W6 #2883 (Epic #2877 livrable #2).
>
> **Source:** `roo-code-customization/investigations/specification-extensions-grappes.md` · **Last commit:** `c131af2e` (2025-09-12) · **Theme:** grappes (extensions spec)
>
> **Preservation:** git history (`git show c131af2e:roo-code-customization/investigations/specification-extensions-grappes.md`) + this archive copy. No content modified — move-only.
>
> **Incoming links:** 0 functional navigation links. Only audit inventories (#2876 doc-audit, #2886 broken-links, #2896 W6-investigations) reference this file — all point-in-time mentions that remain valid post-archive.
>
> **Superseded by:** historical grappes extensions specification, superseded by the merged implementation.

# SPÉCIFICATION DES EXTENSIONS - GRAPPES DE TÂCHES
*Phase 3 du SDDD - Semantic-Documentation-Driven-Design*

---

## MÉTADONNÉES DU DOCUMENT

| **Attribut** | **Valeur** |
|--------------|------------|
| **Mission SDDD** | Extension TraceSummaryService pour support grappes de tâches |
| **Phase** | 3 - Spécification des Extensions |
| **Date de conception** | 2025-09-12 |
| **Architecte technique** | Roo Code |
| **Statut** | 🚧 Spécification en cours |
| **Base architecturale** | `analyse-architecture-actuelle-grappes.md` |

---

## RÉSUMÉ EXÉCUTIF

Cette spécification définit les **extensions précises** au `TraceSummaryService` pour supporter les **grappes de tâches** (clusters). Les extensions sont conçues pour :

- 🎯 **Réutiliser** l'architecture modulaire existante
- ⚡ **Intégrer** la logique cluster de `view_conversation_tree`
- 📊 **Étendre** les statistiques et options existantes
- 🔧 **Minimiser** l'impact sur l'architecture actuelle

**Principe de conception :** **Extension plutôt que modification**

---

## ARCHITECTURE DE SOLUTION

### 🏗️ Vue d'Ensemble des Extensions

```mermaid
graph TB
    subgraph "Extensions Principales"
        CTSS[ClusterTraceSummaryService<br/>Nouvelles méthodes]
        CSO[ClusterSummaryOptions<br/>Options étendues]
        CSS[ClusterSummaryStatistics<br/>Métriques étendues]
        CTSS --> CSO
        CTSS --> CSS
    end
    
    subgraph "TraceSummaryService Étendu"
        TSS[TraceSummaryService<br/>Service existant]
        GCLS[generateClusterSummary()<br/>NOUVELLE MÉTHODE]
        RCH[renderClusterHeader()<br/>NOUVEAU RENDU]
        RCS[renderClusterStats()<br/>NOUVEAU RENDU]
        
        TSS --> GCLS
        GCLS --> RCH
        GCLS --> RCS
    end
    
    subgraph "Intégration MCP"
        RSM[RooStateManagerServer]
        GCST[generate_cluster_summary<br/>NOUVEAU TOOL]
        RSM --> GCST
        GCST --> CTSS
    end
    
    subgraph "Données & Structures"
        CS[ConversationSkeleton<br/>INCHANGÉ]
        CL[ClusterLogic<br/>Réutilisée de view_tree]
        CS --> CL
    end
```

### 🎯 Stratégie d'Extension

| **Composant** | **Type Extension** | **Justification** |
|---------------|-------------------|-------------------|
| `TraceSummaryService` | **Méthodes ajoutées** | Préserve l'existant, ajoute fonctionnalités |
| `SummaryOptions` | **Interface étendue** | Rétrocompatibilité totale |
| `SummaryStatistics` | **Interface étendue** | Ajout métriques cluster |
| `RooStateManagerServer` | **Nouvel outil MCP** | Intégration transparente |

---

## SPÉCIFICATIONS DÉTAILLÉES

### 1. 📊 **Extensions des Interfaces**

#### 1.1 `ClusterSummaryOptions`

```typescript
/**
 * Options étendues pour la génération de résumés de grappes de tâches
 */
export interface ClusterSummaryOptions extends SummaryOptions {
    // Mode de génération de grappe
    clusterMode?: 'aggregated' | 'detailed' | 'comparative';
    
    // Inclusion des statistiques de grappe
    includeClusterStats?: boolean;
    
    // Analyse cross-task des patterns communs
    crossTaskAnalysis?: boolean;
    
    // Profondeur maximale de la hiérarchie à inclure
    maxClusterDepth?: number;
    
    // Tri des tâches dans la grappe
    clusterSortBy?: 'chronological' | 'size' | 'activity' | 'alphabetical';
    
    // Inclusion d'une timeline unifiée
    includeClusterTimeline?: boolean;
    
    // Seuil de troncature spécifique aux grappes
    clusterTruncationChars?: number;
    
    // Affichage des relations inter-tâches
    showTaskRelationships?: boolean;
}
```

#### 1.2 `ClusterSummaryStatistics`

```typescript
/**
 * Statistiques étendues pour les grappes de tâches
 */
export interface ClusterSummaryStatistics extends SummaryStatistics {
    // Métriques de grappe
    totalTasks: number;
    clusterDepth: number;
    averageTaskSize: number;
    
    // Distribution des tâches
    taskDistribution: {
        byMode: Record<string, number>;
        bySize: { small: number; medium: number; large: number };
        byActivity: Record<string, number>;
    };
    
    // Métriques temporelles
    clusterTimeSpan: {
        startTime: string;
        endTime: string;
        totalDurationHours: number;
    };
    
    // Métriques de contenu agrégées
    clusterContentStats: {
        totalUserMessages: number;
        totalAssistantMessages: number;
        totalToolResults: number;
        totalContentSize: number;
        averageMessagesPerTask: number;
    };
    
    // Analyse des patterns
    commonPatterns?: {
        frequentTools: Record<string, number>;
        commonModes: Record<string, number>;
        crossTaskTopics: string[];
    };
}
```

#### 1.3 `ClusterSummaryResult`

```typescript
/**
 * Résultat de génération de résumé de grappe
 */
export interface ClusterSummaryResult extends SummaryResult {
    // Métadonnées de grappe
    clusterMetadata: {
        rootTaskId: string;
        totalTasks: number;
        clusterMode: string;
        generationTimestamp: string;
    };
    
    // Statistiques de grappe
    clusterStatistics: ClusterSummaryStatistics;
    
    // Index des tâches incluses
    taskIndex: {
        taskId: string;
        title: string;
        order: number;
        size: number;
    }[];
}
```

### 2. 🔧 **Nouvelles Méthodes du TraceSummaryService**

#### 2.1 Méthode Principale : `generateClusterSummary`

```typescript
/**
 * Génère un résumé complet pour une grappe de tâches
 * 
 * @param rootTask Tâche racine de la grappe (parent principal)
 * @param childTasks Liste des tâches enfantes de la grappe
 * @param options Options de génération spécifiques aux grappes
 * @returns Résumé structuré de la grappe complète
 */
async generateClusterSummary(
    rootTask: ConversationSkeleton,
    childTasks: ConversationSkeleton[],
    options: Partial<ClusterSummaryOptions> = {}
): Promise<ClusterSummaryResult> {
    
    // 1. Validation des entrées
    this.validateClusterInput(rootTask, childTasks);
    
    // 2. Configuration avec valeurs par défaut
    const finalOptions = this.mergeClusterOptions(options);
    
    // 3. Tri et organisation des tâches
    const organizedTasks = this.organizeClusterTasks(rootTask, childTasks, finalOptions);
    
    // 4. Classification du contenu agrégé
    const classifiedContent = this.classifyClusterContent(organizedTasks);
    
    // 5. Calcul des statistiques de grappe
    const clusterStats = this.calculateClusterStatistics(organizedTasks, classifiedContent);
    
    // 6. Génération du contenu selon le mode
    const content = await this.renderClusterSummary(
        organizedTasks, 
        clusterStats, 
        finalOptions
    );
    
    // 7. Construction du résultat
    return this.buildClusterResult(content, clusterStats, organizedTasks, finalOptions);
}
```

#### 2.2 Méthodes d'Organisation des Données

```typescript
/**
 * Organise et trie les tâches de la grappe selon les options
 */
private organizeClusterTasks(
    rootTask: ConversationSkeleton,
    childTasks: ConversationSkeleton[],
    options: ClusterSummaryOptions
): OrganizedClusterTasks {
    
    const allTasks = [rootTask, ...childTasks];
    
    // Tri selon la stratégie choisie
    switch (options.clusterSortBy) {
        case 'chronological':
            return this.sortByChronology(allTasks);
        case 'size':
            return this.sortBySize(allTasks);
        case 'activity':
            return this.sortByActivity(allTasks);
        case 'alphabetical':
            return this.sortAlphabetically(allTasks);
        default:
            return this.sortByChronology(allTasks);
    }
}

/**
 * Classifie le contenu agrégé de toutes les tâches de la grappe
 */
private classifyClusterContent(
    organizedTasks: OrganizedClusterTasks
): ClassifiedClusterContent {
    
    const allClassifiedContent: ClassifiedContent[] = [];
    const taskContentMap: Map<string, ClassifiedContent[]> = new Map();
    
    // Classification par tâche individuelle
    for (const task of organizedTasks.allTasks) {
        const taskContent = this.classifyConversationContent(task);
        taskContentMap.set(task.taskId, taskContent);
        allClassifiedContent.push(...taskContent);
    }
    
    return {
        aggregatedContent: allClassifiedContent,
        perTaskContent: taskContentMap,
        crossTaskPatterns: this.identifyCrossTaskPatterns(taskContentMap)
    };
}
```

#### 2.3 Méthodes de Calcul des Statistiques

```typescript
/**
 * Calcule les statistiques complètes de la grappe
 */
private calculateClusterStatistics(
    organizedTasks: OrganizedClusterTasks,
    classifiedContent: ClassifiedClusterContent
): ClusterSummaryStatistics {
    
    // Statistiques de base (réutilise la logique existante)
    const baseStats = this.calculateStatistics(classifiedContent.aggregatedContent);
    
    // Métriques spécifiques aux grappes
    const clusterMetrics = this.calculateClusterMetrics(organizedTasks);
    
    // Distribution des tâches
    const taskDistribution = this.calculateTaskDistribution(organizedTasks.allTasks);
    
    // Analyse temporelle
    const timeSpan = this.calculateClusterTimeSpan(organizedTasks.allTasks);
    
    // Patterns communs
    const commonPatterns = this.analyzeCommonPatterns(classifiedContent);
    
    return {
        ...baseStats,
        totalTasks: organizedTasks.allTasks.length,
        clusterDepth: this.calculateClusterDepth(organizedTasks),
        averageTaskSize: this.calculateAverageTaskSize(organizedTasks.allTasks),
        taskDistribution,
        clusterTimeSpan: timeSpan,
        clusterContentStats: this.aggregateContentStats(organizedTasks.allTasks),
        commonPatterns
    };
}
```

### 3. 🎨 **Méthodes de Rendu pour Grappes**

#### 3.1 Pipeline de Rendu Principal

```typescript
/**
 * Rendu complet du résumé de grappe selon le mode choisi
 */
private async renderClusterSummary(
    organizedTasks: OrganizedClusterTasks,
    statistics: ClusterSummaryStatistics,
    options: ClusterSummaryOptions
): Promise<string> {
    
    const parts: string[] = [];
    
    // En-tête de grappe
    parts.push(this.renderClusterHeader(organizedTasks.rootTask, statistics, options));
    
    // Métadonnées de grappe
    parts.push(this.renderClusterMetadata(organizedTasks, statistics, options));
    
    // Statistiques de grappe
    if (options.includeClusterStats !== false) {
        parts.push(this.renderClusterStatistics(statistics, options));
    }
    
    // Table des matières
    if (options.generateToc !== false) {
        parts.push(this.renderClusterTableOfContents(organizedTasks, options));
    }
    
    // Timeline unifiée
    if (options.includeClusterTimeline) {
        parts.push(this.renderClusterTimeline(organizedTasks, statistics));
    }
    
    // Contenu selon le mode
    switch (options.clusterMode) {
        case 'aggregated':
            parts.push(await this.renderAggregatedContent(organizedTasks, statistics, options));
            break;
        case 'detailed':
            parts.push(await this.renderDetailedContent(organizedTasks, statistics, options));
            break;
        case 'comparative':
            parts.push(await this.renderComparativeContent(organizedTasks, statistics, options));
            break;
        default:
            parts.push(await this.renderAggregatedContent(organizedTasks, statistics, options));
    }
    
    // Analyse cross-task
    if (options.crossTaskAnalysis) {
        parts.push(this.renderCrossTaskAnalysis(organizedTasks, statistics));
    }
    
    return parts.join('\n\n');
}
```

#### 3.2 Templates de Rendu Spécialisés

```typescript
/**
 * Rendu de l'en-tête de grappe avec métadonnées principales
 */
private renderClusterHeader(
    rootTask: ConversationSkeleton,
    statistics: ClusterSummaryStatistics,
    options: ClusterSummaryOptions
): string {
    
    const title = rootTask.metadata.title || 'Grappe de Tâches Sans Titre';
    const taskCount = statistics.totalTasks;
    const timeSpan = this.formatDuration(statistics.clusterTimeSpan.totalDurationHours);
    
    return options.outputFormat === 'html' ? 
        this.renderClusterHeaderHTML(title, taskCount, timeSpan, options) :
        this.renderClusterHeaderMarkdown(title, taskCount, timeSpan, options);
}

/**
 * Rendu des statistiques de grappe avec progressive disclosure
 */
private renderClusterStatistics(
    statistics: ClusterSummaryStatistics,
    options: ClusterSummaryOptions
): string {
    
    const sections: string[] = [];
    
    // Vue compacte ou détaillée selon les options
    if (options.compactStats) {
        sections.push(this.renderCompactClusterStats(statistics));
    } else {
        sections.push(this.renderDetailedClusterStats(statistics));
    }
    
    // Distribution des tâches
    sections.push(this.renderTaskDistribution(statistics.taskDistribution));
    
    // Métriques temporelles
    sections.push(this.renderTimeSpanAnalysis(statistics.clusterTimeSpan));
    
    // Patterns communs si disponibles
    if (statistics.commonPatterns) {
        sections.push(this.renderCommonPatterns(statistics.commonPatterns));
    }
    
    return this.wrapInCollapsibleSection('📊 Statistiques de Grappe', sections.join('\n'), options);
}
```

### 4. 🔧 **Modes de Rendu Spécialisés**

#### 4.1 Mode `aggregated`

```typescript
/**
 * Mode agrégé : Vue unifiée de toute la grappe comme une seule conversation
 */
private async renderAggregatedContent(
    organizedTasks: OrganizedClusterTasks,
    statistics: ClusterSummaryStatistics,
    options: ClusterSummaryOptions
): Promise<string> {
    
    // Fusion chronologique de tous les contenus
    const mergedContent = this.mergeTasksChronologically(organizedTasks.allTasks);
    
    // Application des filtres de niveau de détail
    const filteredContent = this.applyDetailLevel(mergedContent, options.detailLevel);
    
    // Rendu avec marqueurs de transition entre tâches
    return this.renderWithTaskTransitions(filteredContent, organizedTasks, options);
}
```

#### 4.2 Mode `detailed`

```typescript
/**
 * Mode détaillé : Vue tâche par tâche avec sections individuelles
 */
private async renderDetailedContent(
    organizedTasks: OrganizedClusterTasks,
    statistics: ClusterSummaryStatistics,
    options: ClusterSummaryOptions
): Promise<string> {
    
    const sections: string[] = [];
    
    for (const [index, task] of organizedTasks.allTasks.entries()) {
        // Génération du résumé individuel
        const individualSummary = await this.generateSummary(task, {
            ...options,
            generateToc: false, // Pas de TOC individuel
            includeCss: false   // CSS seulement au niveau global
        });
        
        // Encapsulation dans une section de grappe
        const taskSection = this.wrapTaskInClusterSection(
            task, 
            individualSummary.content, 
            index + 1, 
            options
        );
        
        sections.push(taskSection);
    }
    
    return sections.join('\n\n');
}
```

#### 4.3 Mode `comparative`

```typescript
/**
 * Mode comparatif : Analyse côte-à-côte des tâches de la grappe
 */
private async renderComparativeContent(
    organizedTasks: OrganizedClusterTasks,
    statistics: ClusterSummaryStatistics,
    options: ClusterSummaryOptions
): Promise<string> {
    
    const sections: string[] = [];
    
    // Tableau comparatif des métriques
    sections.push(this.renderComparativeMetricsTable(organizedTasks.allTasks));
    
    // Analyse des différences et similitudes
    sections.push(this.renderSimilarityAnalysis(organizedTasks.allTasks));
    
    // Timeline comparative
    sections.push(this.renderComparativeTimeline(organizedTasks.allTasks));
    
    // Analyse des patterns divergents
    sections.push(this.renderDivergentPatterns(organizedTasks.allTasks));
    
    return sections.join('\n\n');
}
```

### 5. 🛠️ **Intégration MCP - Nouvel Outil**

#### 5.1 Définition de l'Outil `generate_cluster_summary`

```typescript
/**
 * Outil MCP pour génération de résumés de grappes de tâches
 */
export interface GenerateClusterSummaryArgs {
    // Tâche racine de la grappe
    rootTaskId: string;
    
    // Mode de génération
    clusterMode?: 'aggregated' | 'detailed' | 'comparative';
    
    // Options de formatage
    detailLevel?: 'Full' | 'NoTools' | 'NoResults' | 'Messages' | 'Summary' | 'UserOnly';
    outputFormat?: 'markdown' | 'html';
    
    // Options spécifiques aux grappes
    maxClusterDepth?: number;
    includeClusterStats?: boolean;
    crossTaskAnalysis?: boolean;
    includeClusterTimeline?: boolean;
    clusterSortBy?: 'chronological' | 'size' | 'activity' | 'alphabetical';
    
    // Options de troncature
    truncationChars?: number;
    clusterTruncationChars?: number;
    
    // Options d'affichage
    compactStats?: boolean;
    includeCss?: boolean;
    generateToc?: boolean;
    showTaskRelationships?: boolean;
}
```

#### 5.2 Implémentation de l'Handler

```typescript
/**
 * Handler pour l'outil generate_cluster_summary
 */
private async handleGenerateClusterSummary(args: GenerateClusterSummaryArgs): Promise<CallToolResult> {
    try {
        // 1. Validation des arguments
        if (!args.rootTaskId) {
            return this.createErrorResult('rootTaskId is required');
        }
        
        // 2. Récupération de la tâche racine
        const rootTask = this.conversationCache.get(args.rootTaskId);
        if (!rootTask) {
            return this.createErrorResult(`Task not found: ${args.rootTaskId}`);
        }
        
        // 3. Identification des tâches enfantes
        const childTasks = Array.from(this.conversationCache.values())
            .filter(task => task.parentTaskId === args.rootTaskId);
        
        if (childTasks.length === 0) {
            return this.createErrorResult(`No child tasks found for root task: ${args.rootTaskId}`);
        }
        
        // 4. Configuration des options
        const clusterOptions: Partial<ClusterSummaryOptions> = {
            clusterMode: args.clusterMode || 'aggregated',
            detailLevel: args.detailLevel || 'Full',
            outputFormat: args.outputFormat || 'markdown',
            maxClusterDepth: args.maxClusterDepth || 10,
            includeClusterStats: args.includeClusterStats !== false,
            crossTaskAnalysis: args.crossTaskAnalysis || false,
            includeClusterTimeline: args.includeClusterTimeline || false,
            clusterSortBy: args.clusterSortBy || 'chronological',
            truncationChars: args.truncationChars || 0,
            clusterTruncationChars: args.clusterTruncationChars || 0,
            compactStats: args.compactStats || false,
            includeCss: args.includeCss !== false,
            generateToc: args.generateToc !== false,
            showTaskRelationships: args.showTaskRelationships || true
        };
        
        // 5. Génération du résumé de grappe
        const result = await this.traceSummaryService.generateClusterSummary(
            rootTask,
            childTasks,
            clusterOptions
        );
        
        // 6. Formatage du résultat
        return {
            content: [{
                type: 'text',
                text: `# Résumé de Grappe de Tâches

**Tâche racine :** ${rootTask.metadata.title || rootTask.taskId}  
**Nombre de tâches :** ${result.clusterStatistics.totalTasks}  
**Mode de génération :** ${args.clusterMode || 'aggregated'}  
**Généré le :** ${new Date().toISOString()}

---

${result.content}

---

## Métadonnées de Génération

- **Format :** ${result.format}
- **Taille du contenu :** ${result.size} caractères
- **Statistiques disponibles :** Oui
- **Tâches incluses :** ${result.taskIndex.map(t => t.title || t.taskId).join(', ')}
`
            }],
            isError: false
        };
        
    } catch (error) {
        return this.createErrorResult(`Error generating cluster summary: ${error.message}`);
    }
}
```

### 6. 📋 **Structures de Données Auxiliaires**

#### 6.1 Types d'Organisation

```typescript
/**
 * Structure d'organisation des tâches dans une grappe
 */
export interface OrganizedClusterTasks {
    rootTask: ConversationSkeleton;
    allTasks: ConversationSkeleton[];
    sortedTasks: ConversationSkeleton[];
    taskHierarchy: Map<string, ConversationSkeleton[]>;
    taskOrder: string[];
}

/**
 * Contenu classifié au niveau de la grappe
 */
export interface ClassifiedClusterContent {
    aggregatedContent: ClassifiedContent[];
    perTaskContent: Map<string, ClassifiedContent[]>;
    crossTaskPatterns: CrossTaskPattern[];
}

/**
 * Pattern identifié à travers plusieurs tâches
 */
export interface CrossTaskPattern {
    pattern: string;
    frequency: number;
    taskIds: string[];
    category: 'tool' | 'mode' | 'topic' | 'interaction';
}
```

#### 6.2 Configuration par Défaut

```typescript
/**
 * Configuration par défaut pour les résumés de grappes
 */
export const DEFAULT_CLUSTER_OPTIONS: ClusterSummaryOptions = {
    // Options héritées
    detailLevel: 'Full',
    truncationChars: 0,
    compactStats: false,
    includeCss: true,
    generateToc: true,
    outputFormat: 'markdown',
    
    // Options spécifiques aux grappes
    clusterMode: 'aggregated',
    includeClusterStats: true,
    crossTaskAnalysis: false,
    maxClusterDepth: 10,
    clusterSortBy: 'chronological',
    includeClusterTimeline: false,
    clusterTruncationChars: 0,
    showTaskRelationships: true
};
```

---

## CAS D'USAGE ET EXEMPLES

### 🎯 **Cas d'Usage Principaux**

#### 1. **Résumé de Projet Multi-Tâches**
```typescript
// Génération résumé pour un projet avec 5 sous-tâches
const result = await traceSummaryService.generateClusterSummary(
    projectRootTask,
    subTasks,
    {
        clusterMode: 'detailed',
        includeClusterStats: true,
        crossTaskAnalysis: true,
        includeClusterTimeline: true
    }
);
```

#### 2. **Analyse Comparative de Refactoring**
```typescript
// Comparaison de différentes approches de refactoring
const result = await traceSummaryService.generateClusterSummary(
    refactoringRootTask,
    approachTasks,
    {
        clusterMode: 'comparative',
        clusterSortBy: 'size',
        showTaskRelationships: true
    }
);
```

#### 3. **Vue Agrégée pour Reporting**
```typescript
// Résumé exécutif pour management
const result = await traceSummaryService.generateClusterSummary(
    sprintRootTask,
    sprintTasks,
    {
        clusterMode: 'aggregated',
        detailLevel: 'Summary',
        compactStats: true
    }
);
```

### 📊 **Exemples de Sorties**

#### Exemple 1 : Mode Aggregated

```markdown
# Résumé de Grappe - Développement Module Auth

## 📊 Statistiques de Grappe

| Métrique | Valeur |
|----------|--------|
| Nombre de tâches | 4 |
| Durée totale | 12.5 heures |
| Messages totaux | 156 |
| Outils utilisés | 23 |

## 🕒 Timeline Unifiée

- **09:00** - Début analyse architecture (Tâche 1)
- **11:30** - Implémentation login (Tâche 2)  
- **14:00** - Tests unitaires (Tâche 3)
- **16:30** - Documentation (Tâche 4)

## 💬 Conversation Agrégée

[Contenu fusionné chronologiquement avec marqueurs de transition]
```

#### Exemple 2 : Mode Comparative

```markdown
# Analyse Comparative - Approches de Refactoring

## 📊 Tableau Comparatif

| Tâche | Messages | Outils | Durée | Complexité |
|-------|----------|--------|-------|------------|
| Approche A | 45 | 12 | 3.2h | Moyenne |
| Approche B | 62 | 18 | 4.1h | Élevée |
| Approche C | 38 | 9 | 2.8h | Faible |

## 🔍 Analyse des Similitudes

- **Outils communs :** `read_file`, `apply_diff`, `execute_command`
- **Patterns répétés :** Tests de régression systématiques
- **Approches divergentes :** Gestion des migrations de données
```

---

## INTÉGRATION ET MIGRATION

### 🔧 **Plan d'Implémentation**

#### Phase 1 : Extensions d'Interfaces (1 jour)
- [ ] Définition `ClusterSummaryOptions`
- [ ] Définition `ClusterSummaryStatistics`  
- [ ] Définition `ClusterSummaryResult`
- [ ] Tests unitaires des interfaces

#### Phase 2 : Méthodes Core (2-3 jours)
- [ ] Implémentation `generateClusterSummary()`
- [ ] Méthodes d'organisation des données
- [ ] Calcul statistiques de grappe
- [ ] Tests d'intégration

#### Phase 3 : Templates de Rendu (2 jours)
- [ ] Pipeline de rendu principal
- [ ] Mode `aggregated`
- [ ] Mode `detailed` 
- [ ] Mode `comparative`
- [ ] Tests de rendu

#### Phase 4 : Intégration MCP (1 jour)
- [ ] Outil `generate_cluster_summary`
- [ ] Handler et validation
- [ ] Tests end-to-end

### 🧪 **Stratégie de Tests**

```typescript
describe('ClusterSummaryService', () => {
    describe('generateClusterSummary', () => {
        it('should generate aggregated summary for valid cluster');
        it('should handle empty child tasks gracefully');
        it('should respect truncation limits');
        it('should calculate accurate cluster statistics');
    });
    
    describe('modes', () => {
        it('should render detailed mode correctly');
        it('should render comparative analysis');  
        it('should merge chronological content');
    });
    
    describe('MCP integration', () => {
        it('should handle generate_cluster_summary tool');
        it('should validate required parameters');
        it('should return proper error messages');
    });
});
```

### 📋 **Checklist de Validation**

- [ ] **Compatibilité** : Aucune régression sur `generateSummary()` existant
- [ ] **Performance** : Temps de traitement acceptable pour grappes 1-20 tâches
- [ ] **Mémoire** : Pas de fuites mémoire avec gros clusters
- [ ] **Options** : Toutes les combinaisons d'options fonctionnelles
- [ ] **Formats** : HTML et Markdown correctement générés
- [ ] **Erreurs** : Gestion gracieuse des cas d'erreur
- [ ] **Documentation** : Code documenté et exemples fournis

---

## CONCLUSION DE LA SPÉCIFICATION

### 🎯 **Synthèse Technique**

Cette spécification définit une **extension cohérente et complète** du `TraceSummaryService` pour supporter les grappes de tâches. Les principales forces de la conception :

✅ **Architecture modulaire préservée**  
✅ **Réutilisation maximale du code existant**  
✅ **Extensibilité via interfaces étendues**  
✅ **3 modes de rendu spécialisés**  
✅ **Intégration MCP transparente**  
✅ **Compatibilité ascendante totale**  

### 📊 **Estimation Actualisée**

| **Composant** | **Effort** | **Complexité** |
|---------------|------------|----------------|
| **Interfaces** | 1 jour | 🟢 Faible |
| **Méthodes Core** | 2-3 jours | 🟡 Moyenne |
| **Templates Rendu** | 2 jours | 🟡 Moyenne |
| **Intégration MCP** | 1 jour | 🟢 Faible |
| **Tests & Documentation** | 2 jours | 🟡 Moyenne |
| **Total** | **8-9 jours** | 🟡 **Moyenne** |

### 🚀 **Prêt pour l'Implémentation**

La spécification est **complète et détaillée**, prête pour la **Phase 5 : Implémentation**. Tous les composants, interfaces, méthodes et intégrations sont précisément définis.

---

*Document généré le 2025-09-12 dans le cadre de la Phase 3 SDDD*  
*Prochaine étape : Phase 4 - Checkpoint Sémantique Mi-Mission*