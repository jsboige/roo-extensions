# NarrativeContextBuilderService

**Fichier:** `src/services/synthesis/NarrativeContextBuilderService.ts`
**Lignes:** 1360
**Version:** 1.1.0

---

## Résumé

Service de construction de contexte narratif récursif pour les synthèses de conversations. Il parcourt l'arbre des tâches de manière stratégique (parent, enfants, sœurs) pour construire un contexte cohérent et optimisé. Gère la condensation automatique quand le contexte dépasse le seuil configuré.

---

## Méthodes clés

| Méthode | Paramètres | Retour | Usage |
|---------|------------|--------|-------|
| `buildContext` | `taskId, options?` | `Promise<ContextBuildingResult>` | Point d'entrée principal |
| `traverseConversationTree` | `taskId, options, depth` | `Promise<TreeTraversalResult>` | Parcours récursif de l'arbre |
| `collectParentContext` | `skeleton, options` | `Promise<TreeTraversalResult>` | Collecte le contexte parent |
| `collectSiblingContext` | `skeleton, options` | `Promise<TreeTraversalResult>` | Collecte le contexte des sœurs |
| `analyzeConversationStructure` | `skeleton` | `ConversationStructure` | Analyse la structure |
| `buildNarrativeContext` | `traversalResult, taskId` | `NarrativeContext` | Construit le résumé narratif |

---

## Dépendances

- **TaskNavigator** : Navigation dans l'arbre des tâches
- **SynthesisModels** : Types de synthèse (ContextBuildingOptions, etc.)
- **ConversationSkeleton** : Structure des conversations
- **CondensedSynthesisBatch** : Lots de synthèse condensée

---

## Patterns

- **Recursive Tree Traversal** : Parcours parent → enfants → sœurs
- **Strategy Pattern** : Options de parcours configurables
- **Caching** : `conversationCache` et `analysisCache` pour performance
- **Lazy Loading** : Chargement à la demande des analyses

---

## Limitations

- **Dépend de TaskNavigator** : Nécessite un arbre de tâches valide
- **Condensation non-réversible** : Une fois condensé, le détail est perdu
- **Cache non-persistant** : Perdu au redémarrage du service
- **Pas de parallélisation** : Parcours séquentiel de l'arbre

---

## Exemple d'appel

```typescript
import { NarrativeContextBuilderService } from './services/synthesis/NarrativeContextBuilderService.js';

const service = new NarrativeContextBuilderService(
  {
    synthesisBaseDir: '.claude/synthesis',
    condensedBatchesDir: '.claude/synthesis/condensed',
    maxContextSizeBeforeCondensation: 50000,
    defaultMaxDepth: 10
  },
  conversationCache  // Map<string, ConversationSkeleton>
);

const result = await service.buildContext('task-123', {
  maxDepth: 5,
  includeParents: true,
  includeSiblings: true,
  includeCondensedBatches: true
});

console.log(result.contextTrace);
// { rootTaskId: 'task-123', parentTaskId: 'task-100', depth: 3 }
```

---

## Options de configuration

```typescript
interface NarrativeContextBuilderOptions {
  synthesisBaseDir: string;                      // Répertoire de base
  condensedBatchesDir: string;                   // Répertoire condensé
  maxContextSizeBeforeCondensation: number;      // Seuil de condensation
  defaultMaxDepth: number;                       // Profondeur max par défaut
}

interface ContextBuildingOptions {
  maxDepth?: number;                // Profondeur de remontée
  includeParents?: boolean;         // Inclure les parents
  includeSiblings?: boolean;        // Inclure les sœurs
  includeCondensedBatches?: boolean; // Utiliser lots condensés
  strategy?: 'depth_first' | 'breadth_first';
}
```

---

## Types de structure analysée

```typescript
interface ConversationStructure {
  sequences: ConversationSequence[];  // Phases identifiées
  timeline: ChronologicalEvent[];     // Événements chronologiques
  metadata: {
    totalMessages: number;
    totalActions: number;
    conversationDuration: number;
    participantCount: number;
  };
}

interface ThematicAnalysis {
  themes: ThematicCluster[];     // Clusters thématiques
  decisions: DecisionPoint[];    // Points de décision
  confidence: number;
}
```
