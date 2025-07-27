# API des outils du Roo State Manager

Ce document décrit les outils disponibles via le MCP `roo-state-manager`.

## `get_task_tree`

Récupère une vue arborescente et hiérarchique des tâches à partir d'un nœud racine.

### Paramètres

- `conversation_id` (string, requis) : L'ID de la tâche racine pour laquelle construire l'arbre.
- `max_depth` (number, optionnel) : La profondeur maximale de l'arbre à retourner. Si non fourni, l'arbre complet est retourné.

### Exemple de retour

```json
{
  "taskId": "root-task-id",
  "children": [
    {
      "taskId": "child-task-1",
      "children": [
        {
          "taskId": "grandchild-task-1"
        }
      ]
    },
    {
      "taskId": "child-task-2"
    }
  ]
}
```

## `search_tasks_semantic`

Recherche des tâches de manière sémantique au sein d'une conversation spécifique.

### Paramètres

- `conversation_id` (string, requis) : L'ID de la conversation dans laquelle effectuer la recherche.
- `search_query` (string, requis) : La requête de recherche sémantique.
- `max_results` (number, optionnel) : Le nombre maximum de résultats à retourner.

### Exemple de retour

```json
[
  {
    "task": "Démonstration de l'outil `get_task_tree`",
    "id": "demo-get-task-tree-001",
    "score": 0.98
  },
  {
    "task": "Analyse initiale du `roo-state-manager`",
    "id": "initial-analysis-sm-002",
    "score": 0.87
  }
]
```

## `build_skeleton_cache`

Force la reconstruction complète du cache de squelettes sur le disque. Utile lorsque les données sources ont changé et que le cache doit être rafraîchi. Cette opération peut être longue en fonction du nombre de conversations.

### Paramètres

Aucun.

### Exemple de retour

```json
{
  "message": "Cache skeleton build process finished.",
  "duration": "5m 32s",
  "skeletonCount": 3345,
  "cacheSize": "25.7 MB",
  "averageSkeletonSize": "7.8 KB"
}
```

## `view_conversation_tree`

Fournit une vue arborescente et condensée des conversations pour une analyse rapide.

### Paramètres

- `task_id` (string, optionnel) : L'ID de la tâche de départ. Si non fourni, l'outil utilise la tâche la plus récente.
- `view_mode` (string, optionnel, défaut: 'chain') : Le mode d'affichage.
    - `'single'`: Affiche uniquement la tâche spécifiée.
    - `'chain'`: Affiche la tâche et toute sa chaîne de tâches parentes.
    - `'cluster'`: Affiche la tâche, son parent direct, et tous les enfants du parent (les "frères et sœurs" de la tâche).
- `truncate` (number, optionnel, défaut: 5) : Nombre de lignes à conserver au début et à la fin de chaque message pour le condenser. Mettre à `0` pour désactiver la troncature.

### Exemple de retour

```
Conversation Tree (Mode: chain)
======================================
▶️ Task: Analyse initiale du roo-state-manager (ID: initial-analysis-sm-002)
  Parent: None
  Messages: 5
  [👤 User]:
    | Bonjour, pouvez-vous analyser l'état actuel du MCP roo-state-manager ?
    | [...]
    | J'aimerais une vue d'ensemble.
  [🤖 Assistant]:
    | Bien sûr. Le MCP contient actuellement 3 outils principaux...
    | [...]
    | Je peux vous fournir un arbre des tâches si vous le souhaitez.
  ▶️ Task: Démonstration de l'outil get_task_tree (ID: demo-get-task-tree-001)
    Parent: initial-analysis-sm-002
    Messages: 3
    [👤 User]:
      | Oui, montrez-moi l'arbre pour la conversation `initial-analysis-sm-002`.
    [🤖 Assistant]:
      | Voici l'arbre des tâches demandé.
```