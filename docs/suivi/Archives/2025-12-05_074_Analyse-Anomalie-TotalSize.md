# Rapport d'Analyse : Anomalie `totalSize: 0` dans roo-state-manager

**Date :** 2025-09-09
**Auteur :** Roo Architect
**Statut :** Analyse terminée

## 1. Description de l'Anomalie

Le MCP `roo-state-manager`, via son outil `get_storage_stats`, retourne une `totalSize` de 0, même lorsque des conversations existent sur le disque. Cela fausse les métriques de supervision de l'écosystème Roo.

## 2. Analyse de la Cause Racine

L'enquête a été menée en analysant le code source du fichier `mcps/internal/servers/roo-state-manager/src/utils/roo-storage-detector.ts`. La cause du problème a été localisée dans la fonction `getStatsForPath`.

Cette fonction est appelée par `getStorageStats` pour calculer les statistiques de chaque répertoire de stockage. Voici l'extrait de code problématique :

```typescript
// Ligne 81:
public static async getStatsForPath(storagePath: string): Promise<StorageStats> {
    // ...
    for (const entry of entries) {
        if (entry.isDirectory()) {
            const taskPath = path.join(storagePath, entry.name);
            // ...
                const stats = await fs.stat(taskPath); // stat sur le répertoire
                totalSize += stats.size; // Problème : stats.size pour un répertoire est souvent 0 sur Windows
            // ...
        }
    }
    return { conversationCount: count, totalSize, fileTypes: {} };
}
```

Le problème est que `stats.size` pour un répertoire ne représente pas la somme de la taille des fichiers qu'il contient. Sur de nombreux systèmes de fichiers, notamment NTFS (Windows), cette valeur est soit 0, soit une petite valeur fixe qui ne reflète pas le contenu.

Par conséquent, l'addition `totalSize += stats.size` accumule des zéros, menant à un résultat final de `totalSize: 0`.

## 3. Solution Recommandée

Il est nécessaire de refactoriser la fonction `getStatsForPath` pour qu'elle calcule la taille réelle de chaque sous-répertoire de conversation.

**Algorithme proposé pour la nouvelle fonction :**

1. Pour chaque `entry` qui est un répertoire dans `storagePath` :
2. Lire le contenu de ce répertoire de tâche (`taskPath`).
3. Pour chaque fichier à l'intérieur du répertoire de tâche :
4. Obtenir ses `stats` via `fs.stat`.
5. Additionner la `stats.size` de ce fichier à une variable `totalSize`.

Cette approche garantira un calcul exact de l'espace disque utilisé par les conversations.

## 4. Conclusion

L'anomalie `totalSize: 0` est un bug de calcul et non un problème de détection de données. La correction est relativement simple et peut être implémentée en modifiant une unique fonction dans le `roo-state-manager`.