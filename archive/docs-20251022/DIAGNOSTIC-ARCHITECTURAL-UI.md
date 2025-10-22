# Diagnostic Architectural de l'Affichage des Tâches dans Roo-Code

**Date :** 17 septembre 2025
**Auteur :** Roo Architect

## 1. Contexte

Cette analyse fait suite à l'échec de multiples tentatives pour restaurer la visibilité de ~2126 tâches dans l'interface utilisateur de Roo-Code. L'investigation a révélé que la cause racine technique est l'absence de fichiers `task_metadata.json`, mais les solutions implémentées n'ont eu aucun impact sur l'UI.

Ce document cartographie le flux de données réel de l'affichage des tâches et formule des hypothèses précises sur les points de rupture.

## 2. Diagramme du Flux de Données

L'analyse du code révèle un flux de données linéaire et sans cache intermédiaire complexe pour l'affichage de l'historique. La base de données SQLite mentionnée dans les anciens documents ne semble pas être impliquée dans ce processus spécifique.

```mermaid
graph TD
    subgraph "Système de Fichiers (Disque)"
        A[task_xxxx/ui_messages.json]
        B[task_xxxx/api_conversation_history.json]
    end

    subgraph "Extension Roo-Code (Backend)"
        C(Task.ts)
        D[taskMetadata.ts]
        E[ClineProvider.ts]
        F[VS Code GlobalState<br>key: "taskHistory"]
    end

    subgraph "Interface Utilisateur (Frontend)"
        G[webview-ui/src/App.tsx]
        H[React Context<br>(ExtensionStateContextProvider)]
        I[HistoryView.tsx]
    end

    A -- "Lecture par<br>readTaskMessages()" --> C
    B -- "Lecture par<br>readApiMessages()" --> C
    C -- "Appelle<br>saveClineMessages()" --> D
    D -- "Génère 'HistoryItem'" --> C
    C -- "Appelle<br>updateTaskHistory(HistoryItem)" --> E
    E -- "Met à jour le tableau" --> F
    F -- "Envoie l'état complet via<br>postStateToWebview()" --> G
    G -- "Reçoit le message 'state'<br>et met à jour le contexte" --> H
    H -- "Fournit taskHistory" --> I
    I -- "Affiche la liste des tâches" --> I
```

## 3. Analyse du Flux

1.  **Démarrage/Reprise d'une tâche** : Quand une tâche est reprise depuis l'historique (`resumeTaskFromHistory` dans `Task.ts`), ses fichiers de messages (`ui_messages.json`, `api_conversation_history.json`) sont lus depuis le disque.
2.  **Mise en Mémoire** : Le contenu de ces fichiers peuple la propriété `this.clineMessages` de l'instance de la classe `Task`.
3.  **Génération des Métadonnées** : À chaque sauvegarde (`saveClineMessages`), la fonction `taskMetadata` est appelée. Elle prend `this.clineMessages` en entrée pour (re)calculer un objet `HistoryItem` complet, contenant toutes les informations nécessaires à l'affichage (ID, titre, date, etc.).
4.  **Stockage dans le `globalState`** : L'objet `HistoryItem` généré est passé à `ClineProvider.ts`, qui met à jour un tableau d'objets `HistoryItem` stocké dans le `globalState` de VS Code sous la clé `"taskHistory"`.
5.  **Synchronisation avec l'UI** : Le `ClineProvider` envoie alors l'intégralité de l'état, y compris le tableau `taskHistory`, à la webview via `postMessage`.
6.  **Affichage** : Le composant React `App.tsx` reçoit l'état et le stocke dans un Contexte React. Le composant `HistoryView.tsx` consomme ce contexte et affiche la liste des tâches.

## 4. Hypothèses sur le Point de Rupture

L'échec de l'affichage des 2126 tâches orphelines, malgré l'implémentation de logiques de réparation, provient très probablement d'une rupture en tout début de chaîne.

**Hypothèse Principale : Échec de la lecture des messages (`ui_messages.json`)**

La logique de réparation (comme `rebuild_task_index`) génère correctement les `task_metadata.json` manquants. Cependant, lors de la reprise de ces tâches anciennes dans l'UI :

*   **Scénario A (Fichiers manquants)** : Le processus de reprise ne trouve pas de `ui_messages.json` ou `api_conversation_history.json` pour la tâche. La propriété `this.clineMessages` dans `Task.ts` reste donc un tableau vide.
*   **Scénario B (Format invalide)** : Les fichiers de messages existent, mais leur format est obsolète ou corrompu. La fonction `readTaskMessages` échoue silencieusement ou retourne un tableau vide.

**Conséquence Commune :**
Dans les deux cas, `taskMetadata` est appelée avec un tableau de messages vide (`hasMessages` est `false`). Elle génère un `HistoryItem` par défaut (ligne 43-55 de `taskMetadata.ts`) avec des valeurs minimales (timestamp actuel, pas de titre, etc.). Cet `HistoryItem` incomplet est ensuite envoyé à l'UI, qui ne peut pas l'afficher correctement, le filtre, ou l'affiche comme une tâche invalide.

**Pourquoi l'outil `rebuild_task_index` semble réussir :**
L'outil en lui-même fonctionne. Il analyse la conversation et écrit un `task_metadata.json`. Cependant, ce n'est qu'une partie du problème. Le véritable test se produit lorsque l'UI tente de *lire et d'interpréter* cette tâche, en se basant sur les autres fichiers de conversation. La génération du `task_metadata.json` seul ne garantit pas que le reste de la chaîne fonctionnera.

**Différence Post-Août / Pré-Août :**
Il est quasi certain qu'un changement dans le format de sauvegarde des fichiers `ui_messages.json` et/ou `api_conversation_history.json` a eu lieu autour du mois d'août. Les tâches créées après cette date ont des fichiers de messages dans le format attendu par la version actuelle de `readTaskMessages`, tandis que les anciennes ne les ont pas.