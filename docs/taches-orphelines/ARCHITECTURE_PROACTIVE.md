# Architecture d'Auto-Réparation Proactive des Squelettes

## 1. Objectif

L'objectif de cette architecture est de doter le MCP `roo-state-manager` d'un mécanisme d'auto-réparation qui détecte et génère les fichiers de métadonnées (`task_metadata.json`) manquants pour les conversations existantes. Cela garantit la cohérence des données et la visibilité de toutes les tâches dans l'UI `roo-code` sans intervention manuelle.

## 2. Fichier Principal Impacté

-   **`mcps/internal/servers/roo-state-manager/src/index.ts`** : Point d'entrée du serveur MCP, où la logique d'initialisation sera ajoutée.

## 3. Conception Architecturale : Scan au Démarrage

Le mécanisme sera implémenté comme une routine de fond non bloquante qui s'exécute au démarrage du serveur MCP.

### Étape 1 : Modification de la classe `RooStateManager`

Une nouvelle méthode privée sera ajoutée à la classe principale du serveur.

```typescript
// Dans mcps/internal/servers/roo-state-manager/src/index.ts

class RooStateManager {
    // ... autres méthodes et propriétés ...

    constructor() {
        this.initialize();
        this.startProactiveSkeletonRepair(); // Lancer l'auto-réparation
    }

    private async startProactiveSkeletonRepair(): Promise<void> {
        console.log('[Auto-Repair] Starting proactive skeleton repair scan...');
        
        try {
            const locations = await RooStorageDetector.detectStorageLocations();
            if (locations.length === 0) {
                console.log('[Auto-Repair] No storage locations found. Scan finished.');
                return;
            }

            let repairedCount = 0;
            const tasksToRepair: { taskId: string, taskPath: string }[] = [];

            // 1. Détecter toutes les tâches nécessitant une réparation
            for (const loc of locations) {
                const tasksPath = path.join(loc, 'tasks');
                const taskIds = await fs.readdir(tasksPath).catch(() => []);

                for (const taskId of taskIds) {
                    const taskPath = path.join(tasksPath, taskId);
                    const metadataPath = path.join(taskPath, 'task_metadata.json');
                    
                    try {
                        await fs.access(metadataPath);
                    } catch {
                        // Le fichier n'existe pas, il faut le réparer
                        tasksToRepair.push({ taskId, taskPath });
                    }
                }
            }
            
            if (tasksToRepair.length === 0) {
                console.log('[Auto-Repair] All skeletons are consistent. Scan finished.');
                return;
            }

            console.log(`[Auto-Repair] Found ${tasksToRepair.length} tasks needing skeleton repair.`);

            // 2. Traiter la réparation en parallèle (avec une limite)
            const concurrencyLimit = 5; // Évite de surcharger le disque
            for (let i = 0; i < tasksToRepair.length; i += concurrencyLimit) {
                const batch = tasksToRepair.slice(i, i + concurrencyLimit);
                await Promise.all(batch.map(async (task) => {
                    try {
                        const skeleton = await RooStorageDetector.analyzeConversation(task.taskId, task.taskPath);
                        if (skeleton) {
                            const metadataFilePath = path.join(task.taskPath, 'task_metadata.json');
                            await fs.writeFile(metadataFilePath, JSON.stringify(skeleton.metadata, null, 2), 'utf-8');
                            repairedCount++;
                        }
                    } catch (e) {
                         console.error(`[Auto-Repair] Failed to repair skeleton for ${task.taskId}:`, e);
                    }
                }));
                 console.log(`[Auto-Repair] Processed batch, ${repairedCount}/${tasksToRepair.length} repaired so far...`);
            }

            console.log(`[Auto-Repair] Scan finished. Repaired ${repairedCount} skeletons.`);

        } catch (error) {
            console.error('[Auto-Repair] A critical error occurred during the scan:', error);
        }
    }
}
```

### Étape 2 : Lancement au démarrage

Le constructeur de la classe `RooStateManager` sera modifié pour appeler cette nouvelle méthode. L'appel sera fait sans `await` pour ne pas bloquer le démarrage du serveur.

```typescript
// Dans le constructeur de RooStateManager

constructor() {
    this.initialize(); // Méthode existante
    
    // Lancer en arrière-plan sans bloquer le constructeur
    this.startProactiveSkeletonRepair(); 
}
```

## 4. Avantages

-   **Automatisation Complète :** Le système se répare de lui-même, éliminant le besoin d'exécuter manuellement `rebuild_task_index` pour ce cas d'usage.
-   **Non Bloquant :** Le scan s'exécute en arrière-plan et n'impacte pas la réactivité du serveur MCP à son démarrage.
-   **Robustesse :** Le système devient résilient à la corruption ou la suppression accidentelle des fichiers de métadonnées.
-   **Performance :** Utilise un traitement par lots pour éviter de surcharger les I/O disque.

## 5. Dépendances

-   `RooStorageDetector` doit être importé dans `index.ts`.
-   Les modules `fs/promises` et `path` sont déjà probablement disponibles.

Ce document fournit les bases pour une implémentation robuste de l'auto-réparation.