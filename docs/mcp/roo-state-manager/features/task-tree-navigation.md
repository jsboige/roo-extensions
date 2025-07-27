# Conception de la Navigation Arborescente des Tâches

**Auteur:** Roo, Architecte Technique  
**Date:** 2025-07-26  
**Statut:** Proposition  

## 1. Contexte (SDDD)

Ce document est le résultat de la phase de conception suivant le paradigme **Semantic Doc Driven Design (SDDD)**. Il s'appuie sur une analyse sémantique de la documentation et du code source existants.

**Documents de référence analysés :**
- `docs/roo-state-manager-architecture.md`
- `docs/modules/roo-code/analysis.md`
- Code source de `roo-code` relatif à la création de tâches.

## 2. Analyse de la filiation des tâches

### Constat

L'analyse révèle que la relation parent-enfant est gérée en mémoire lors de la création d'une sous-tâche (via le paramètre `parentTask` de la classe `Task`). Un événement `taskSpawned(parentId, childId)` est même émis.

Cependant, **cette information de filiation n'est pas persistée** dans les métadonnées (`task_metadata.json`) stockées sur le disque.

### Recommandation Stratégique

Pour garantir une navigation arborescente fiable et déterministe, il est **impératif de modifier le processus de persistance des tâches** pour y inclure la relation de filiation.

**Action requise (hors périmètre de ce MCP) :**
- Modifier la structure `HistoryItem` dans `roo-code/src/shared/HistoryItem.ts` pour y ajouter :
  - `parentTaskId?: string`
  - `rootTaskId?: string`
- Mettre à jour la fonction `taskMetadata` dans `roo-code/src/core/task-persistence/taskMetadata.ts` pour peupler ces nouveaux champs à partir de l'objet `Task` en mémoire.

### Stratégie de contournement (pour les tâches existantes)

Pour les 901+ tâches existantes sans information de filiation, nous utiliserons une approche heuristique pour reconstruire une arborescence plausible, basée sur :
1.  **Le Workspace (`workspace` dans `HistoryItem`) :** premier niveau de regroupement.
2.  **La proximité temporelle (`ts` dans `HistoryItem`) :** les tâches créées à quelques secondes d'intervalle sont probablement liées.
3.  **L'analyse sémantique des titres (`task` dans `HistoryItem`) :** non implémenté dans un premier temps, mais possible via des embeddings.

## 3. Contrats d'API MCP

Les méthodes suivantes seront ajoutées au MCP `roo-state-manager`.

### 3.1. `get_task_parent(taskId: string)`

Retourne la tâche parente directe d'une tâche donnée.

- **Logique :**
    1.  Lit les métadonnées de la `taskId` fournie.
    2.  Si `parentTaskId` existe, retourne les métadonnées de la tâche parente.
    3.  Sinon (pour les anciennes tâches), retourne `null`.

- **Paramètres :**
  ```json
  {
    "taskId": "string"
  }
  ```

- **Format de retour :**
  ```json
  // Retourne un objet HistoryItem ou null
  {
    "id": "parent-task-id",
    "number": 123,
    "ts": 1679600000,
    "task": "Tâche parente",
    "workspace": "/path/to/project",
    // ... autres champs de HistoryItem
  } | null
  ```

### 3.2. `get_task_children(taskId: string)`

Retourne la liste des enfants directs d'une tâche donnée.

- **Logique :**
    1.  Scanne l'index des métadonnées de toutes les tâches.
    2.  Filtre les tâches où le champ `parentTaskId` correspond à la `taskId` fournie.
    3.  Retourne la liste des `HistoryItem` correspondants.
    4.  Pour les anciennes tâches, cette méthode retournera toujours un tableau vide.

- **Paramètres :**
  ```json
  {
    "taskId": "string"
  }
  ```

- **Format de retour :**
  ```json
  // Retourne un tableau de HistoryItem
  [
    {
      "id": "child-task-id-1",
      "number": 124,
      // ...
    },
    {
      "id": "child-task-id-2",
      "number": 125,
      // ...
    }
  ]
  ```

### 3.3. `get_task_tree(taskId: string)`

Retourne l'arborescence complète (ou un sous-arbre) à partir d'un nœud donné.

- **Logique :**
    1.  Utilise `get_task_children` de manière récursive pour construire l'arbre descendant à partir du `taskId` fourni.
    2.  La structure de chaque nœud inclura le `HistoryItem` complet et un tableau `children`.

- **Paramètres :**
  ```json
  {
    "taskId": "string"
  }
  ```

- **Format de retour :**
  ```json
  // Type TreeNode
  {
    "id": "task-id",
    "number": 123,
    "ts": 1679600000,
    "task": "Tâche racine de l'arbre demandé",
    "workspace": "/path/to/project",
    // ... autres champs de HistoryItem
    "children": [
      {
        "id": "child-task-id-1",
        // ...
        "children": []
      },
      {
        "id": "child-task-id-2",
        // ...
        "children": [
          // ... enfants du deuxième niveau
        ]
      }
    ]
  }
  ```

## 4. Logique de Haut Niveau

L'implémentation dans le MCP `roo-state-manager` nécessitera les composants suivants :

1.  **Cache/Index des Métadonnées :**
    - Au démarrage, le MCP scannera tous les répertoires de tâches.
    - Il chargera en mémoire une `Map<string, HistoryItem>` (ou une structure plus optimisée comme une base de données in-memory type LokiJS) pour un accès instantané aux métadonnées par `taskId`.
    - Un index supplémentaire (`Map<string, string[]>`) sera construit pour mapper un `parentTaskId` à une liste de `childTaskId` afin d'accélérer `get_task_children`.
    - Ce cache sera périodiquement rafraîchi ou mis à jour via un mécanisme de veille sur les fichiers.

2.  **Service de Navigation (`TaskTreeService`) :**
    - Ce service implémentera la logique des trois nouvelles méthodes.
    - `get_task_parent` sera une simple recherche dans le cache principal.
    - `get_task_children` sera une simple recherche dans l'index de filiation.
    - `get_task_tree` sera une fonction récursive qui appellera `get_task_children` à chaque niveau.

3.  **Point d'entrée du MCP :**
    - Le fichier principal du MCP (`server.ts` ou équivalent) exposera les nouvelles méthodes et les reliera aux appels du `TaskTreeService`.

## 5. Prochaines Étapes

Une fois cette conception approuvée, les prochaines étapes seront :
1.  **Implémentation** de la logique dans le MCP `roo-state-manager`.
2.  **Création des tests unitaires et d'intégration** pour les nouvelles méthodes.
3.  **Coordination avec l'équipe `roo-code`** pour prioriser la modification de la persistance des métadonnées de tâche.