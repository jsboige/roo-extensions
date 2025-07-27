# Synthèse SDDD : Fonctionnement des Tâches Roo et Condensation de Contexte

Ce document, rédigé selon la méthodologie SDDD (Semantic Doc Driven Design), a pour but de servir de fondation technique à la refonte du MCP `roo-state-manager`. Il se base sur une analyse approfondie du code source de `roo-code` (le sous-module de l'extension VSCode) et du `roo-state-manager` lui-même.

## 1. Architecture et Cycle de Vie d'une Tâche Roo (`roo-code`)

L'intelligence et l'autonomie de Roo reposent sur la gestion de "Tâches". Chaque tâche est une instance encapsulée qui gère un objectif spécifique de l'utilisateur.

### 1.1. La Classe `Task` : Le Cœur du Réacteur

Le fichier `roo-code/src/core/task/Task.ts` définit la classe `Task`, qui est le véritable centre de contrôle d'une conversation. Une instance de `Task` est responsable de :
-   **Son propre état** : gestion de l'historique de la conversation (`apiConversationHistory`), des messages affichés à l'utilisateur (`clineMessages`), et de son cycle de vie (actif, en pause, abandonné).
-   **La boucle d'inférence** : La méthode `recursivelyMakeClineRequests` orchestre la boucle principale : envoi de la requête au LLM, réception et parsing de la réponse.
-   **L'exécution des outils** : L'instance `Task` interprète les demandes d'outils du LLM et les exécute dans l'environnement de l'utilisateur.
-   **La communication** : Elle utilise un `EventEmitter` pour communiquer avec l'interface web (`ClineProvider`) et mettre à jour l'affichage en temps réel.

### 1.2. Persistance des Tâches

La persistance de l'état d'une tâche est assurée par le module `roo-code/src/core/task-persistence/`. Chaque tâche est stockée dans un répertoire unique identifié par son `taskId`. Ce répertoire contient trois fichiers principaux :
-   `api_conversation_history.json` : L'historique complet des échanges avec le LLM, incluant les messages système et les réponses brutes.
-   `ui_messages.json` : Les messages formatés pour l'affichage dans l'interface utilisateur.
-   `task_metadata.json` : Des métadonnées sur la tâche, comme son titre, l'heure de création, et l'usage des tokens.

## 2. Le Mécanisme de Condensation de Contexte (`roo-code`)

Pour pallier la limitation de la taille du contexte des LLMs, Roo implémente un mécanisme de condensation intelligent.

### 2.1. Implémentation dans `summarizeConversation`

La logique est centralisée dans la fonction `summarizeConversation` du fichier `roo-code/src/core/condense/index.ts`.
-   **Déclenchement** : La condensation est déclenchée par la classe `Task` juste avant d'envoyer une requête à l'API, si le nombre de tokens du contexte dépasse un certain seuil (`autoCondenseContextPercent`).
-   **Processus** :
    1.  La fonction conserve les `N_MESSAGES_TO_KEEP` messages les plus récents.
    2.  Les messages plus anciens sont envoyés à une API (probablement un LLM) avec un prompt système très spécifique (`SUMMARY_PROMPT`) qui demande de générer un résumé technique détaillé.
    3.  Ce résumé structuré aborde le contexte général, le travail en cours, les concepts techniques clés, les fichiers modifiés et les prochaines étapes.
-   **Résultat** : Les anciens messages sont remplacés par un unique message `ApiMessage` contenant le résumé, avec un flag `isSummary: true`. Le contexte pour le LLM est ainsi allégé tout en préservant une mémoire sémantique de la conversation.

## 3. Rôle et Objectifs du `roo-state-manager`

Le `roo-state-manager` est un MCP dont le rôle est d'analyser et d'organiser l'ensemble des tâches persistées par `roo-code`.

### 3.1. Rôle Actuel : Détecteur et Organisateur

-   **`RooStorageDetector`** : Ce service scanne le système de fichiers pour trouver les répertoires de stockage des tâches Roo. Il est capable de lire l'historique et les métadonnées de chaque tâche pour en créer une représentation légère en mémoire : le `ConversationSkeleton`.
-   **`TaskTreeBuilder`** : Ce constructeur utilise les squelettes de conversation pour les agréger et les organiser en une arborescence sémantique et hiérarchique : `Workspace` > `Project` > `TaskCluster` > `Conversation`. L'objectif est de transformer une liste plate de tâches en une vue structurée et navigable.

### 3.2. Objectif de la Refonte : Vers l'Analyse Active

L'analyse du code révèle que les services `task-summarizer.ts` et `task-indexer.ts` sont actuellement des coquilles vides (leur code est commenté). La refonte du `roo-state-manager` vise donc à :
-   **Activer l'indexation sémantique** : Utiliser un service comme Qdrant pour indexer le contenu des tâches et permettre une recherche sémantique puissante sur l'ensemble des conversations. On peut s'inspirer du mécanisme de condensation de Roo pour générer des résumés à indexer.
-   **Offrir des capacités d'analyse** : Fournir des outils pour naviguer, rechercher et obtenir des insights à partir de l'arborescence des tâches, en s'appuyant sur l'index sémantique.
-   **S'inspirer de `roo-code`** : Les mécanismes de manipulation de tâches (comme la lecture et le résumé) peuvent être directement adaptés de ceux existants dans `roo-code` pour être utilisés au sein du MCP.