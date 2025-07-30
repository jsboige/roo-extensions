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
- `truncation_pattern` (object, optionnel) : Un objet pour une troncature asymétrique.
    - `head` (number) : Nombre de caractères à conserver au début.
    - `tail` (number) : Nombre de caractères à conserver à la fin.
 - `preset` (string, optionnel) : Un preset pour appliquer rapidement une configuration commune. Si utilisé, il écrase les valeurs par défaut des autres paramètres. Les paramètres spécifiés explicitement dans la même requête auront toujours la priorité sur le preset.
    - `'overview'`: `{ view_mode: 'chain', truncate: 1 }` - Idéal pour une vue d'ensemble rapide.
    - `'cluster_debug'`: `{ view_mode: 'cluster', truncate: 5 }` - Utile pour déboguer les relations entre tâches sœurs.
    - `'full_audit'`: `{ view_mode: 'chain', truncate: 0 }` - Affiche tout le contenu, sans aucune troncature.
    - `'content_focus'`: `{ view_mode: 'chain', truncate: 15 }` - Met l'accent sur le contenu tout en gardant une vue concise.

### Exemple de retour

L'outil retourne d'abord un bloc de statistiques sur l'arbre de conversation analysé, puis l'arbre lui-même.

```
Conversation Tree Metrics
=========================
- Total Nodes: 15
- Max Depth: 4
- Max Width: 5
- Total Size: 123.45 KB

Conversation Tree (Mode: chain)
======================================
▶️ Task: Refactoring de `roo-storage-detector` (ID: refactor-storagedetector-003)
  Parent: initial-analysis-sm-002
  Messages: 2
  [...
▶️ Task: Rapport final et déploiement 🏁 (ID: final-report-and-deploy-004)
  Parent: refactor-storagedetector-003
  Messages: 1
  [🤖 Assistant]:
    | Rapport de Mission[...]n est terminée avec succès...
```

L'indicateur `🏁` est ajouté au titre de la tâche si un rapport de mission est détecté à la fin de la conversation.

## `detect_roo_storage`

Détecte automatiquement les emplacements de stockage Roo et retourne une liste des chemins contenant les répertoires `tasks`.

### Paramètres

Aucun.

### Exemple de retour

```json
{
  "locations": [
    "C:\\Users\\user\\AppData\\Roaming\\Code\\User\\globalStorage\\rooveterinaryinc.roo-cline\\tasks"
  ]
}
```

## `get_storage_stats`

Calcule des statistiques agrégées sur tous les emplacements de stockage détectés, comme le nombre total de conversations et la taille totale.

### Paramètres

Aucun.

### Exemple de retour

```json
{
  "stats": {
    "conversationCount": 3385,
    "totalSize": 58734291
  }
}
```

## `list_conversations`

Retourne un tableau de toutes les tâches racines (celles sans parent), chacune contenant potentiellement un tableau `children` imbriqué pour former une forêt d'arborescences de conversations.

### Paramètres

- `limit` (number, optionnel): Nombre maximum de conversations racines à retourner.
- `sortBy` (string, optionnel): Critère de tri pour les tâches racines. Valeurs possibles : `'lastActivity'`, `'messageCount'`, `'totalSize'`.
- `sortOrder` (string, optionnel): Ordre de tri. `'asc'` ou `'desc'`.
- `hasApiHistory` (boolean, optionnel): Filtrer les conversations qui contiennent ou non un historique d'API.
- `hasUiMessages` (boolean, optionnel): Filtrer les conversations qui contiennent ou non des messages UI.

### Exemple de retour

```json
[
  {
    "taskId": "root-task-1",
    "metadata": { "title": "Tâche Racine 1", "..." },
    "children": [
      {
        "taskId": "child-task-1.1",
        "metadata": { "title": "Tâche Enfant 1.1", "..." },
        "children": []
      },
      {
        "taskId": "child-task-1.2",
        "metadata": { "title": "Tâche Enfant 1.2", "..." },
        "children": [
          {
            "taskId": "grandchild-task-1.2.1",
            "metadata": { "title": "Petite-Tâche Enfant 1.2.1", "..." },
            "children": []
          }
        ]
      }
    ]
  },
  {
    "taskId": "root-task-2",
    "metadata": { "title": "Tâche Racine 2", "..." },
    "children": []
  }
]
```

## `touch_mcp_settings`

Touche le fichier de paramètres `mcp_settings.json` pour forcer VSCode à recharger les MCPs Roo. Utile après une recompilation pour s'assurer que les changements sont pris en compte.

### Paramètres

Aucun.

### Exemple de retour

```json
{
  "success": true,
  "message": "Configuration UTF-8 chargee automatiquement"
}
```

## `debug_analyze_conversation`

Outil de débogage pour analyser une seule conversation par son ID et retourner le squelette brut généré, sans passer par le cache.

### Paramètres

- `taskId` (string, requis) : L'ID de la tâche/conversation à analyser.

### Exemple de retour

```json
{
  "taskId": "task-001",
  "parentTaskId": "...",
  "sequence": [ ... ],
  "metadata": { ... }
}
```