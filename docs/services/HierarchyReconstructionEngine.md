# HierarchyReconstructionEngine

**Fichier:** `src/utils/hierarchy-reconstruction-engine.ts`
**Lignes:** 1281
**Version:** 1.0.0

---

## Résumé

Moteur de reconstruction hiérarchique en deux passes qui résout le problème des tâches orphelines en reconstruisant les `parentIds` manquants. Il extrait les instructions de sous-tâches depuis les fichiers `ui_messages.json`, les indexe dans un radix tree, puis utilise la similarité textuelle pour associer les tâches enfants à leurs parents.

---

## Méthodes clés

| Méthode | Paramètres | Retour | Usage |
|---------|------------|--------|-------|
| `reconstructHierarchy` | `workspacePath?: string, forceRebuild: boolean` | `Promise<ConversationSkeleton[]>` | Point d'entrée statique principal |
| `doReconstruction` | `skeletons: ConversationSkeleton[]` | `Promise<EnhancedConversationSkeleton[]>` | Exécute la reconstruction (instance) |
| `executePhase1` | `skeletons, config?` | `Promise<Phase1Result>` | Extraction et parsing des instructions |
| `executePhase2` | `skeletons, config?` | `Promise<Phase2Result>` | Résolution des parentIds |
| `extractSubtaskInstructions` | `skeleton` | `Promise<NewTaskInstruction[]>` | Extrait les instructions depuis ui_messages.json |
| `findParentByInstructionPrefix` | `prefix` | `SimilaritySearchResult \| null` | Recherche par préfixe d'instruction |

---

## Dépendances

- **TaskInstructionIndex** : Index radix tree pour recherche par préfixe
- **RooStorageDetector** : Accès aux squelettes de conversation
- **fs/path/crypto** : Modules Node.js natifs
- **Types** : `../types/enhanced-hierarchy.js`, `../types/conversation.js`

---

## Patterns

- **Two-Pass Algorithm** : Phase 1 (extraction) → Phase 2 (résolution)
- **Radix Tree Indexing** : Préfixes d'instructions indexés pour recherche O(k)
- **Batch Processing** : Traitement par lots de 20 squelettes
- **Similarity Matching** : Seuil de 0.85 pour associer parent-enfant
- **Singleton State** : Map `processedTasks` pour éviter re-traitement

---

## Limitations

- **Ne reconstruit pas** les hiérarchies sans instructions de sous-tâches explicites
- **Seuil de similarité** peut créer de faux positifs si ajusté trop bas
- **Dépend de ui_messages.json** : Les tâches sans ce fichier ne peuvent pas être traitées
- **Mode strict désactivé** par défaut pour permettre plus de détections

---

## Exemple d'appel

```typescript
import { HierarchyReconstructionEngine } from './utils/hierarchy-reconstruction-engine.js';

// Reconstruction simple
const skeletons = await HierarchyReconstructionEngine.reconstructHierarchy(
  'd:/dev/roo-extensions',
  false  // forceRebuild
);

// Avec configuration personnalisée
const engine = new HierarchyReconstructionEngine({
  batchSize: 50,
  similarityThreshold: 0.90,
  debugMode: true
});
const enhanced = await engine.doReconstruction(skeletons);
```

---

## Configuration

```typescript
interface ReconstructionConfig {
  batchSize: number;           // 20 par défaut
  similarityThreshold: number; // 0.85 par défaut
  minConfidenceScore: number;  // 0.8 par défaut
  debugMode: boolean;          // true par défaut
  operationTimeout: number;    // 30000ms par défaut
  forceRebuild: boolean;       // false par défaut
  strictMode: boolean;         // false par défaut
  workspaceFilter?: string;    // Optionnel
}
```
