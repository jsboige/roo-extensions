# Rapport d'Analyse : Avertissements "large extension state"

**Date :** 2025-09-09
**Auteur :** Roo Architect
**Statut :** Analyse terminée

## 1. Description du Problème

L'extension Roo génère des avertissements "large extension state" dans les logs de développeur de VSCode. Ces avertissements indiquent que l'extension stocke une quantité excessive de données dans le `globalState` de VSCode, ce qui peut potentiellement dégrader les performances de l'éditeur.

## 2. Analyse de la Cause Racine

L'enquête a été menée en analysant les fichiers `roo-code/src/core/webview/ClineProvider.ts` et `roo-code/src/core/config/ContextProxy.ts`. La cause du problème a été identifiée dans la manière dont l'historique des tâches (`taskHistory`) est persisté.

Le fichier `ContextProxy.ts` révèle une gestion de l'état à deux vitesses :

1.  **État mis en cache** : La plupart des paramètres de configuration sont mis en cache en mémoire pour des lectures rapides.
2.  **État "Pass-Through"** : La clé `taskHistory` est explicitement désignée comme "pass-through".

```typescript
// roo-code/src/core/config/ContextProxy.ts:27
const PASS_THROUGH_STATE_KEYS = ["taskHistory"]
```

Cela signifie que chaque lecture et, plus important encore, chaque écriture de `taskHistory` interagit directement avec le disque via l'API `globalState` de VSCode.

La méthode `updateTaskHistory` dans `ClineProvider.ts` charge l'historique complet, y ajoute ou modifie un élément, puis ré-écrit l'intégralité du tableau. Si l'historique est volumineux (contenant de nombreuses tâches avec des conversations longues), cet objet sérialisé en JSON peut atteindre une taille de plusieurs mégaoctets.

VSCode détecte cette taille importante et émet l'avertissement pour signaler un risque potentiel de performance.

## 3. Recommandations

Pour résoudre ce problème de manière pérenne, il est recommandé de refactoriser la stratégie de persistance de l'historique des tâches.

### 3.1 Solution à court terme : Plafonnement et Nettoyage

- **Plafonner la taille de `taskHistory`** : Implémenter une logique qui limite le nombre de tâches conservées dans l'historique (par exemple, les 100 plus récentes).
- **Outil de nettoyage** : Ajouter une commande dans l'extension pour permettre aux utilisateurs de purger leur historique de tâches.

### 3.2 Solution à long terme : Persistance individuelle des tâches

- **Modifier la stratégie de stockage** : Au lieu de stocker tout `taskHistory` comme un unique blob JSON, chaque tâche devrait être stockée dans son propre fichier ou sa propre entrée de base de données (si une solution de stockage plus robuste comme SQLite est envisagée).
- **Index en mémoire** : `taskHistory` en mémoire ne contiendrait alors qu'une liste d'IDs de tâches et de métadonnées légères. Le contenu complet d'une tâche ne serait chargé depuis le disque que lorsque l'utilisateur la consulte explicitement.

Cette approche granulaire résoudrait le problème de "large extension state" et améliorerait considérablement les performances de l'extension pour les utilisateurs ayant un grand nombre de tâches.

## 4. Conclusion

Le problème est bien identifié et ne constitue pas un bug critique, mais plutôt une dette technique liée à une conception qui n'est pas optimisée pour une utilisation à grandeéchelle. La mise en œuvre de la solution à long terme est recommandée pour garantir la performance et la scalabilité de l'extension.