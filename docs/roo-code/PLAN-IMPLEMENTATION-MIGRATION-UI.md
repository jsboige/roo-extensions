# Plan d'Implémentation : Mécanisme de Migration des Tâches Orphelines

**Date :** 17 septembre 2025
**Auteur :** Roo Architect
**Objectif :** Guider l'implémentation de la solution corrective pour restaurer l'affichage des 2126 tâches orphelines dans l'UI de Roo-Code.

## 1. Contexte

Ce plan s'appuie sur le diagnostic architectural ([`DIAGNOSTIC-ARCHITECTURAL-UI.md`](DIAGNOSTIC-ARCHITECTURAL-UI.md)) et la proposition de solution ([`PROPOSITION-SOLUTION-UI.md`](PROPOSITION-SOLUTION-UI.md)). L'objectif est de créer un mécanisme de migration à la volée pour les anciens formats de fichiers `ui_messages.json`.

## 2. Feuille de Route pour le Mode `Code`

### Étape 1 : Création du Script de Diagnostic

**Objectif :** Valider l'hypothèse de l'incompatibilité de format.

1.  **Créer un nouveau fichier** : `roo-code/scripts/diag-orphan-task.ts`.
2.  **Importer les dépendances nécessaires** : `fs/promises`, `path`, et la fonction `readTaskMessages` (ainsi que ses dépendances internes) depuis `src/core/fs/readTaskMessages.ts`. Vous devrez peut-être ajuster les chemins d'importation pour un usage en script.
3.  **Logique du script :**
    *   Prendre un `taskId` en argument de ligne de commande.
    *   Construire le chemin vers le répertoire de la tâche.
    *   Appeler `readTaskMessages` avec les paramètres appropriés.
    *   Utiliser un bloc `try...catch` pour capturer toute erreur.
    *   Afficher clairement le résultat :
        *   Si succès, logger le nombre de messages lus et un échantillon.
        *   Si erreur, logger l'erreur complète.
        *   Si tableau vide, logger "Aucun message trouvé ou format invalide."

**Critère de succès :** Le script, exécuté avec l'ID d'une tâche orpheline, échoue ou retourne un tableau vide. Exécuté avec une tâche récente, il réussit.

### Étape 2 : Implémentation du Mécanisme de Migration

**Objectif :** Modifier l'application pour qu'elle puisse lire, convertir et réparer les anciens formats de messages.

1.  **Créer une fonction de conversion** :
    *   Créer un nouveau fichier : `roo-code/src/core/fs/legacyMessageConverter.ts`.
    *   Définir et exporter une fonction `convertLegacyMessages(data: any): ClineMessage[]`.
    *   *Note :* La logique interne de cette fonction est la partie la plus incertaine. Il faudra inspecter manuellement le contenu d'un ancien `ui_messages.json` pour déterminer comment mapper ses champs vers la structure `ClineMessage` actuelle. Il faudra probablement gérer plusieurs anciens formats.

2.  **Modifier la logique de lecture principale** :
    *   Ouvrir le fichier `roo-code/src/core/fs/readTaskMessages.ts`.
    *   Dans la fonction qui lit et parse le fichier `ui_messages.json`, ajoutez un bloc `try...catch` autour de `JSON.parse`.
    *   **Dans le `catch` (ou après une première lecture échouée) :**
        *   Tenter de lire le fichier comme du texte brut.
        *   Appeler `convertLegacyMessages` avec le contenu brut.
        *   Si la conversion réussit :
            *   Sauvegarder les messages convertis dans le fichier `ui_messages.json` avec un formatage JSON correct (`JSON.stringify(convertedMessages, null, 2)`).
            *   Retourner les messages convertis.
        *   Si la conversion échoue aussi, logger l'erreur et retourner un tableau vide.

### Étape 3 : Création d'une Commande de Rafraîchissement Forcé

**Objectif :** Fournir un moyen de déclencher la relecture de tout l'historique pour appliquer la migration.

1.  **Ouvrir `roo-code/src/extension.ts`**.
2.  **Créer une nouvelle commande VS Code** : `roo.refreshHistory`.
3.  **Logique de la commande :**
    *   Obtenir une référence au `ClineProvider`.
    *   Dans `ClineProvider`, créer une nouvelle méthode `async refreshHistoryFromDisk()`.
    *   Cette méthode devra :
        *   Lister tous les répertoires de tâches dans le dossier de stockage global.
        *   Pour chaque `taskId`, appeler une version adaptée de `resumeTaskFromHistory` de `Task.ts` qui ne fait que lire les messages, potentiellement les migrer (via la nouvelle logique), et mettre à jour le `HistoryItem` dans le `globalState`.
        *   Après avoir traité toutes les tâches, appeler `postStateToWebview()` pour synchroniser avec l'UI.

## 3. Protocole de Déploiement et de Validation (Hotfix)

Ce protocole utilise le script `deploy-fix.ps1` pour appliquer les modifications à l'extension installée sans passer par un cycle de build complet et une réinstallation.

1.  **Exécuter le script de diagnostic** (`diag-orphan-task.ts`) sur une tâche orpheline pour confirmer l'échec initial.
2.  **Appliquer les modifications de code** de l'Étape 2 dans le répertoire `roo-code/src`.
3.  **Compiler le projet `roo-code`** pour générer les fichiers JavaScript mis à jour dans les sous-répertoires `dist/`.
    ```powershell
    cd roo-code
    npm run build
    cd ..
    ```
4.  **Déployer le correctif** en utilisant le script de déploiement.
    ```powershell
    cd roo-code-customization
    ./deploy-fix.ps1 -Action Deploy
    cd ..
    ```
5.  **Redémarrer VS Code** pour s'assurer que l'extension patchée est chargée.
6.  **Exécuter la commande de rafraîchissement** via la palette de commandes VS Code (Ctrl+Shift+P) : `Roo-Code: Refresh History`.
7.  **Validation Interface-First :** Observer l'UI. La liste des tâches doit maintenant contenir les tâches orphelines.
8.  **Validation sur le disque :** Inspecter le fichier `ui_messages.json` d'une tâche migrée pour confirmer que son format a été mis à jour.
9.  **(Si nécessaire) Annuler les modifications :**
    ```powershell
    cd roo-code-customization
    ./deploy-fix.ps1 -Action Rollback
    cd ..
    ```
    Puis redémarrer VS Code.