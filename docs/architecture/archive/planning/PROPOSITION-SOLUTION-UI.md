# Proposition de Solution "Interface-First" pour les Tâches Orphelines

**Date :** 17 septembre 2025
**Auteur :** Roo Architect

## 1. Rappel du Diagnostic

L'analyse architecturale a identifié le point de rupture probable : la fonction `readTaskMessages` (et ses dépendances) ne parvient pas à lire ou à interpréter les fichiers `ui_messages.json` des tâches créées avant août 2025. La chaîne de traitement des données est interrompue à sa source, ce qui empêche la génération correcte des `HistoryItem` et leur ajout au `globalState` de VS Code.

## 2. Principe de la Solution : Migration de Données à la Volée

La solution proposée n'est pas de contourner la chaîne existante, mais de la réparer à la source. Nous allons introduire un **mécanisme de migration de format de données** qui s'activera lors de la lecture des tâches.

L'objectif est de rendre les anciennes données de messages compatibles avec le code actuel, garantissant ainsi que le flux `Disque -> globalState -> UI` fonctionne comme prévu.

## 3. Plan d'Action en Deux Étapes

### Étape 1 : Création d'un Script de Diagnostic (Validation de l'Hypothèse)

Avant de modifier le code de l'extension, nous devons valider à 100% que le format des fichiers est bien le problème.

**Objectif :** Créer un script autonome (ex: `scripts/diagnostic/test-read-orphan-task.ts`) qui :
1.  Prend en entrée l'ID d'une tâche orpheline connue.
2.  Utilise la logique exacte de `readTaskMessages` et de ses dépendances pour tenter de lire le fichier `ui_messages.json` de cette tâche.
3.  Affiche en sortie :
    *   **Succès :** Le contenu des messages lus (improbable).
    *   **Échec :** L'erreur exacte levée lors de la lecture ou du parsing JSON.
    *   **Aucun message :** Si la fonction retourne un tableau vide sans erreur.

Ce script servira de preuve irréfutable et de base pour le développement du convertisseur.

### Étape 2 : Implémentation du Mécanisme de Migration (Solution Corrective)

Une fois l'hypothèse confirmée, nous implémenterons la logique de migration, directement dans le code de l'extension.

**Modification Architecturale :**

1.  **Détection de l'Ancien Format :** Dans `readTaskMessages` (ou une fonction parente), ajouter une logique pour détecter si un fichier `ui_messages.json` est à l'ancien format. Cette détection peut se baser sur la présence/absence d'un champ spécifique, ou une structure JSON différente.
2.  **Création d'un Convertisseur :** Isoler la logique de conversion dans une nouvelle fonction, par exemple `convertLegacyMessages(data: any): ClineMessage[]`. Cette fonction prendra en entrée les données brutes de l'ancien format et retournera un tableau de `ClineMessage` au format actuel.
3.  **Migration et Sauvegarde :**
    *   Si un ancien format est détecté, la fonction de lecture appellera le `convertLegacyMessages`.
    *   Elle remplacera ensuite le contenu de l'ancien `ui_messages.json` par la version convertie et correctement formatée.
    *   Enfin, elle retournera les messages convertis pour que le reste du flux d'exécution continue normalement.

**Avantages de cette approche :**
*   **Robuste :** Corrige le problème à la racine.
*   **Auto-réparatrice :** Les tâches sont migrées une par une, à la première lecture, sans nécessiter d'opération manuelle lourde.
*   **Impact "Interface-First" :** Une fois la migration effectuée pour une tâche, celle-ci devrait immédiatement apparaître correctement dans l'UI lors du prochain rafraîchissement.

## 4. Protocole de Test et Validation

1.  **Exécution du script de diagnostic** sur une tâche orpheline -> Vérifier qu'il échoue comme attendu.
2.  **Implémentation du mécanisme de migration**.
3.  **Lancement de l'extension en mode débug**.
4.  **Déclenchement de la relecture de l'historique** (par exemple via une commande VS Code que nous pourrions créer : `Roo-Code: Refresh History`).
5.  **Validation Interface-First :** Observer l'interface et vérifier que les tâches orphelines apparaissent maintenant dans la liste.
6.  **Validation Disque :** Inspecter le fichier `ui_messages.json` d'une tâche migrée et vérifier que son contenu est maintenant au nouveau format.