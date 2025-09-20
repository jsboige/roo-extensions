# Plan de Modification Architecturale pour la Restauration des Tâches

## 1. Contexte

L'analyse a révélé que l'outil `rebuild_task_index` ajoute correctement les tâches orphelines à l'index global de VS Code (`taskHistory`), mais échoue à créer le fichier `task_metadata.json` nécessaire à l'interface `roo-code` pour afficher ces tâches.

Ce plan détaille les modifications à apporter au fichier `mcps/internal/servers/roo-state-manager/src/tools/vscode-global-state.ts` pour corriger ce problème.

## 2. Fichier à Modifier

-   **Chemin :** `mcps/internal/servers/roo-state-manager/src/tools/vscode-global-state.ts`

## 3. Modifications Détaillées

### Étape 1 : Importer les dépendances nécessaires

Ajouter l'importation de `RooStorageDetector` et des types nécessaires au début du fichier.

```typescript
// Au début de vscode-global-state.ts
import { RooStorageDetector } from '../utils/roo-storage-detector.js';
import { ConversationSkeleton } from '../types/conversation.js';
```

### Étape 2 : Modifier la fonction `rebuildTaskIndex`

Localiser la fonction `handler` de l'objet `rebuildTaskIndex`. À l'intérieur de la boucle `for (const orphanTask of orphanTasks)` (autour de la ligne 866), nous allons injecter la logique de génération de métadonnées.

**Logique d'injection :**

1.  **Obtenir le chemin complet de la tâche** : Nous avons déjà le `taskId` (`orphanTask.id`) et le répertoire parent `tasksDir`.
2.  **Appeler `analyzeConversation`** : Utiliser `RooStorageDetector.analyzeConversation` pour générer le squelette de la tâche.
3.  **Générer et Sauvegarder `task_metadata.json`** : Si le squelette est généré avec succès, construire l'objet de métadonnées final et l'écrire sur le disque dans le répertoire de la tâche.
4.  **Mettre à jour le `HistoryItem`** : Utiliser les informations du squelette (comme le `title`) pour créer un `HistoryItem` plus riche et plus précis que celui existant.

**Exemple de code à insérer dans la boucle :**

```typescript
// DANS la boucle 'for (const orphanTask of orphanTasks)' de rebuildTaskIndex

const taskPath = path.join(tasksDir, orphanTask.id);
let skeleton: ConversationSkeleton | null = null;
let metadataGenerated = false;

try {
    skeleton = await RooStorageDetector.analyzeConversation(orphanTask.id, taskPath);
    
    if (skeleton) {
        const metadataFilePath = path.join(taskPath, 'task_metadata.json');
        
        // Nous ne sauvegardons que les métadonnées, pas la séquence complète
        const metadataToSave = skeleton.metadata; 
        
        // En mode non-dry-run, on écrit le fichier
        if (!dry_run) {
            await fs.writeFile(metadataFilePath, JSON.stringify(metadataToSave, null, 2), 'utf-8');
        }
        metadataGenerated = true;
    }
} catch (e) {
    console.error(`Failed to generate metadata for ${orphanTask.id}:`, e);
    // On ne bloque pas le processus, on continue avec un HistoryItem basique
}

// Création du HistoryItem (amélioré avec les données du squelette si disponible)
const historyItem: HistoryItem = {
    ts: orphanTask.lastActivity ? orphanTask.lastActivity.getTime() : Date.now(),
    // Utiliser le titre du squelette si disponible, sinon l'ID de la tâche
    task: skeleton?.metadata?.title || orphanTask.id, 
    workspace: skeleton?.metadata?.workspace || orphanTask.workspace || 'unknown',
    id: orphanTask.id
};

newHistoryItems.push(historyItem);
addedTasks++;
// On pourrait aussi logger les succès/échecs de la génération de métadonnées
if(metadataGenerated) {
    // console.log(`Metadata successfully generated for ${orphanTask.id}`);
}

```

### Étape 3 : Mettre à jour le rapport final

Ajouter des statistiques sur la génération des métadonnées dans le rapport retourné par l'outil pour informer l'utilisateur.

**Exemple d'ajout au rapport :**

```typescript
// À la fin de la fonction, avant le 'return'

let metadataReport = '';
let successfulMetadata = 0; // Il faudra compter les succès dans la boucle
let failedMetadata = 0; // Et les échecs

// ... (logique pour compter) ...

report += `**Génération de Métadonnées:**\n`;
report += `  - Succès: ${successfulMetadata}\n`;
report += `  - Échecs: ${failedMetadata}\n`;
```

## 4. Impact et Risques

-   **Impact :** Élevé. Cette modification est la clé pour résoudre le bug de visibilité des anciennes tâches.
-   **Risques :** Faibles.
    -   La logique est ajoutée à un outil de réparation existant et peut être contrôlée par l'option `dry_run`.
    -   Les erreurs de génération de métadonnées pour une tâche ne bloqueront pas la réparation des autres tâches grâce à un bloc `try...catch`.
    -   On ne modifie que les tâches orphelines, sans toucher aux tâches déjà indexées.

Ce plan fournit une feuille de route claire pour l'implémentation de la solution.