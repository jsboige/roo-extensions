# Analyse de la Réassociation des Tâches Roo et du Workspace

**Auteur:** Roo
**Date:** 28 août 2025
**Statut:** Version 1.0

## 1. Contexte et Problématique

Suite à une opération de maintenance visant à réassocier des milliers de tâches "orphelines" à leurs workspaces respectifs, il a été constaté que ces tâches n'apparaissaient toujours pas dans l'historique de l'interface utilisateur de Roo.

L'opération initiale a correctement mis à jour le champ `workspacePath` dans les fichiers `task_metadata.json` de chaque tâche individuelle. Cependant, cette modification seule s'est avérée insuffisante pour que les tâches soient reconnues et affichées dans les bons workspaces.

Ce document détaille l'analyse technique qui a permis d'identifier la cause racine du problème et propose une solution de correction durable.

## 2. Architecture de Persistance des Tâches Roo

L'investigation du code source de `roo-code` a révélé une architecture de persistance à deux niveaux qui est au cœur du problème de désynchronisation.

### 2.1. Fichiers de Tâches Individuels

Chaque tâche Roo est stockée dans un répertoire unique sur le système de fichiers. Ce répertoire contient plusieurs fichiers JSON, dont le plus pertinent pour ce diagnostic est :

-   **`task_metadata.json`**: Contient les métadonnées essentielles de la tâche, y compris le chemin du workspace auquel elle est logiquement associée via la clé `workspacePath`. C'est ce fichier qui a été correctement mis à jour lors de la réparation initiale.

### 2.2. Index Global de l'Historique (`taskHistory`)

Pour des raisons de performance, l'extension Roo ne scanne pas l'intégralité des répertoires de tâches à chaque fois qu'elle doit afficher l'historique. À la place, elle maintient un **index centralisé** dans l'état global de VS Code.

-   **Clé de stockage :** `taskHistory`
-   **Emplacement :** Base de données `state.vscdb` de VS Code.
-   **Structure :** Un tableau d'objets `HistoryItem`, où chaque objet est un résumé d'une tâche.

Le point crucial est que chaque `HistoryItem` contient son propre champ `workspace`, qui est utilisé par l'interface utilisateur pour filtrer et afficher les tâches par workspace.

## 3. Identification du "Chaînon Manquant"

La cause racine du problème est une **désynchronisation** entre les données des fichiers individuels et l'index global.

1.  **Source de Vérité pour l'UI :** L'interface utilisateur de Roo se base **exclusivement** sur l'index `taskHistory` pour construire la liste des tâches.
2.  **Source de Vérité pour les Données :** Les fichiers `task_metadata.json` contiennent le `workspacePath` correct.
3.  **Le Chaînon Manquant :** Le script de réparation initial a mis à jour la source de vérité des données (`task_metadata.json`) mais a omis de mettre à jour la source de vérité de l'UI (`taskHistory`).

Par conséquent, bien que les fichiers des tâches soient correctement associés, l'index, lui, contient toujours les anciens chemins de workspace obsolètes, rendant les tâches invisibles dans leurs nouveaux emplacements.

L'analyse du code a confirmé ce mécanisme dans [`roo-code/src/core/webview/ClineProvider.ts`](roo-code/src/core/webview/ClineProvider.ts:1444), qui lit directement `taskHistory` depuis l'état global.

## 4. Plan de Correction Détaillé

Pour résoudre ce problème de manière définitive, il est nécessaire de resynchroniser l'index `taskHistory` avec les métadonnées des fichiers de tâches.

### 4.1. Stratégie Recommandée : Script de Synchronisation

Un script (PowerShell ou autre) doit être développé pour effectuer les opérations suivantes :

1.  **Lire l'index `taskHistory`** depuis la base de données `state.vscdb` de VS Code.
2.  **Itérer sur chaque `HistoryItem`** de l'index.
3.  Pour chaque item, **lire le `workspacePath`** depuis le fichier `task_metadata.json` correspondant.
4.  **Comparer** le `workspace` de l'index avec le `workspacePath` du fichier.
5.  Si une différence est détectée, **mettre à jour le champ `workspace`** dans l'objet `HistoryItem` en mémoire.
6.  Après avoir parcouru toutes les tâches, **réécrire l'intégralité de l'index `taskHistory` mis à jour** dans la base de données `state.vscdb`.

### 4.2. Prévention Future

Pour éviter que ce problème ne se reproduise, toute opération de maintenance future modifiant l'association d'une tâche à un workspace devra impérativement inclure une étape de mise à jour de l'index `taskHistory`. La méthode `updateTaskHistory` dans `ClineProvider` est le point d'entrée approprié pour de telles modifications au sein de l'extension.

## 5. Conclusion

Le problème des tâches invisibles n'est pas une perte de données, mais une désynchronisation de l'index utilisé par l'interface utilisateur. La correction passe par une resynchronisation ciblée de cet index avec les métadonnées des tâches, qui sont la source de vérité.