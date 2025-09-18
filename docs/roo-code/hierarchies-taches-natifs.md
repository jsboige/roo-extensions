# Analyse des mécanismes natifs de hiérarchies de tâches dans Roo

## 🔍 Investigation approfondie - Résultats

### Découverte critique : Roo ne persiste PAS les relations hiérarchiques

**Date d'investigation** : 18 septembre 2025  
**Statut** : URGENT - Relations parent-enfant non persistées  

## 📋 Résumé exécutif

Roo possède des mécanismes natifs robustes pour gérer les hiérarchies de tâches **EN MÉMOIRE** pendant l'exécution, mais **ne persiste jamais** ces relations dans les fichiers de stockage permanents. Ceci explique pourquoi roo-state-manager ne peut pas reconstituer les arbres de tâches.

## 🏗️ Architecture native de Roo pour les hiérarchies

### 1. Mécanismes en mémoire (fonctionnels)

#### Classes et propriétés clés
```typescript
// roo-code/src/core/task/Task.ts
class Task {
  parentTask?: Task    // Référence en mémoire vers le parent
  rootTask?: Task      // Référence en mémoire vers la racine
  // ... autres propriétés
}

// Extension temporaire pour createTaskWithHistoryItem
(historyItem: HistoryItem & { 
  rootTask?: Task; 
  parentTask?: Task 
})
```

#### Événements de tracking
```typescript
// roo-code/src/core/tools/newTaskTool.ts (L139)
cline.emit(RooCodeEventName.TaskSpawned, newCline.taskId)

// roo-code/src/extension/api.ts (L267-269)  
task.on(RooCodeEventName.TaskSpawned, (childTaskId) => {
  this.emit(RooCodeEventName.TaskSpawned, task.taskId, childTaskId)
})
```

#### Mécanisme de création de sous-tâches
```typescript
// roo-code/src/core/tools/newTaskTool.ts (L125)
const newCline = await provider.createTask(unescapedMessage, undefined, cline, {
  initialTodos: todoItems,
})
// cline = tâche parent passée en paramètre
```

### 2. Mécanismes de persistance (défaillants)

#### Schéma HistoryItem - SANS relations hiérarchiques
```typescript
// roo-code/packages/types/src/history.ts
export const historyItemSchema = z.object({
  id: z.string(),
  number: z.number(),
  ts: z.number(),
  task: z.string(),
  tokensIn: z.number(),
  tokensOut: z.number(),
  // ... autres champs
  mode: z.string().optional(),
  // ❌ AUCUN champ : parentTaskId, rootTaskId, children[]
})
```

#### Global State TaskHistory - Relations perdues
```typescript
// roo-code/src/core/webview/ClineProvider.ts (L1943-1957)
async updateTaskHistory(item: HistoryItem): Promise<HistoryItem[]> {
  const history = (this.getGlobalState("taskHistory") as HistoryItem[] | undefined) || []
  // ❌ item ne contient JAMAIS les relations parent-enfant
  // Les extensions temporaires { rootTask?, parentTask? } ne sont jamais sérialisées
}
```

## 🔧 Outil new_task : Format des instructions

### Paramètres capturés
```typescript
// roo-code/src/core/tools/newTaskTool.ts (L102-107)
const toolMessage = JSON.stringify({
  tool: "newTask",
  mode: targetMode.name,        // Mode de la sous-tâche
  content: message,             // Instructions pour la sous-tâche  
  todos: todoItems,             // Liste de tâches initiales
})
```

### Où trouver ces instructions
1. **ui_messages.json** (PRIORITAIRE) : Résistant à la condensation, conserve TOUS les messages
2. **api_conversation_history.json** : Peut perdre les premières instructions après condensation

## 📂 Structure de stockage Roo

### Emplacements des conversations
```
%APPDATA%/Code/User/globalStorage/rooveterinaryinc.roo-cline/tasks/
├── [taskId-1]/
│   ├── api_conversation_history.json    # ⚠️  Peut être condensé
│   ├── ui_messages.json                 # ✅ Résistant à la condensation
│   └── metadata.json                    # Métadonnées de base
├── [taskId-2]/
└── ...
```

### Métadonnées disponibles
```typescript
// mcps/internal/servers/roo-state-manager/src/types/conversation.ts
interface TaskMetadata {
  taskId: string
  mode?: string
  workspace?: string
  timestamp?: string
  // ❌ AUCUN parentTaskId native
}
```

## 🔍 Tests et validation existants

### test-hierarchy-inference.js
- **Ancienne approche** : Cherche dans les conversations **enfants** pour des patterns comme :
  - `CONTEXTE HÉRITÉ de la tâche parente [UUID]`
  - `ORCHESTRATEUR: [UUID] a délégué cette tâche`
- **Problème** : Approche inversée et peu fiable

### relationship-analyzer.ts  
- **Architecture prête** : Méthodes `analyzeParentChildRelationships()` attendent `parentTaskId`
- **Problème** : `parentTaskId` n'existe jamais dans les données

### task-navigator.ts
- **Interface fonctionnelle** : `getTaskParent()`, `getTaskChildren()`, `getTaskTree()`
- **Problème** : Toutes dépendent de `parentTaskId` inexistant

## 🚨 Impact sur roo-state-manager

### Outils affectés
- `get_task_tree` : Ne peut pas construire les arbres
- `list_conversations` avec hiérarchies : Toutes les tâches apparaissent comme racines
- `search_tasks_semantic` : Pas de contexte hiérarchique  
- Tous les exports XML/JSON : Relations manquantes

### Solution de contournement actuelle
```typescript
// mcps/internal/servers/roo-state-manager/src/utils/roo-storage-detector.ts (SUPPRIMÉ)
// Mapping hardcodé pour projet EPITA - temporaire et non-évolutif
const knownChildToParentMapping: Record<string, string> = {
  '7a7c2a6a-a48b-4983-94b3-36b9e5ba6e6c': '07f0d1b6-996e-4f82-a874-83d9a82d614e',
  // ...
}
```

## 📊 Analyse de la cause racine

### Pourquoi Roo ne persiste pas les relations ?

1. **Choix architectural** : Roo privilégie la simplicité du schéma HistoryItem
2. **Extension temporaire** : Les relations `{ rootTask?, parentTask? }` ne sont qu'en mémoire
3. **Sérialisation manquante** : Aucun mécanisme pour persister les références d'objets Task
4. **Impact limité sur Roo** : L'interface utilisateur ne dépend pas des arbres complets

### Conséquences pour les outils externes
- **roo-state-manager** : Principal impacté, ne peut reconstituer les hiérarchies
- **Futurs outils d'analyse** : Même problème pour tout outil externe
- **Exports et rapports** : Contexte hiérarchique perdu

## 🔬 Données disponibles pour la reconstruction

### Dans ui_messages.json (fiable)
```json
{
  "type": "tool_call",
  "content": {
    "tool": "new_task",
    "mode": "code",
    "content": "Implémentez la fonction validateUser...",
    "todos": [...] 
  }
}
```

### Dans api_conversation_history.json (risque de condensation)
```json
{
  "role": "assistant",
  "content": [
    {
      "type": "tool_use",
      "name": "new_task", 
      "input": {
        "mode": "code",
        "message": "Implémentez la fonction validateUser..."
      }
    }
  ]
}
```

## ✅ Recommandations

### Stratégie de reconstruction recommandée
1. **Scanner tous les ui_messages.json** pour instructions `new_task` 
2. **Corréler avec les tâches existantes** par similarité mode + message
3. **Utiliser la proximité temporelle** comme critère de validation
4. **Implémenter un cache** pour éviter les re-scans répétés

### Priorité d'implémentation
1. **URGENT** : Nouvelle logique de reconstruction dans roo-storage-detector.ts
2. **MOYEN** : Tests de validation avec vraies données
3. **LONG TERME** : Proposer amélioration du schéma HistoryItem à l'équipe Roo

---

*Document généré le 18/09/2025 dans le cadre de la mission critique de réparation des hiérarchies de tâches*