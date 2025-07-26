# Plan de Projet : Recherche Sémantique et Navigation Optimisée

Ce document décrit le plan d'implémentation et la stratégie de test pour les nouvelles fonctionnalités du MCP `roo-state-manager`.

**Documents de Conception de Référence :**
- [Conception de la Recherche Sémantique pour les Tâches](./features/semantic-task-search.md)
- [Conception de la Navigation Optimisée pour les Tâches](./features/optimized-task-navigation.md)

## 1. Plan d'Implémentation

Le travail est découpé en tâches séquentielles. L'implémentation de la navigation optimisée est prioritaire car elle sert de base à la consultation des tâches, y compris celles issues de la recherche.

### Phase 1 : Navigation Optimisée (Prérequis)

| Tâche | Description | Complexité |
| --- | --- | --- |
| **1.1 : Module d'Analyse de Conversation** | Créer un service/module partagé capable de lire `api_conversation_history.json` et de le transformer en une structure `OptimizedTaskView`, séparant les dialogues légers des artefacts lourds. | Moyen |
| **1.2 : Implémentation `get_task_summary`** | Exposer la nouvelle méthode MCP qui utilise le module d'analyse pour retourner la vue résumée d'une tâche. | Simple |
| **1.3 : Implémentation `get_task_details`** | Exposer la méthode MCP pour charger le contenu complet d'un artefact à partir de son `artefactId`. | Moyen |
| **1.4 : Mise à jour de la Webview**| Adapter l'interface de consultation de tâche pour qu'elle utilise `get_task_summary` et `get_task_details` (simulation ou implémentation frontend). | Moyen |

### Phase 2 : Recherche Sémantique

| Tâche | Description | Complexité |
| --- | --- | --- |
| **2.1 : Configuration Qdrant & Client** | Mettre en place la configuration pour se connecter à l'instance Qdrant (via Docker Compose ou service cloud). Implémenter le client Qdrant dans le MCP. | Simple |
| **2.2 : Service d'Indexation** | Développer le service qui scanne les tâches, utilise le module d'analyse (Tâche 1.1) pour extraire les dialogues, génère les embeddings via l'API OpenAI et les stocke dans Qdrant. | Complexe |
| **2.3 : Implémentation `search_tasks_semantic`**| Exposer la nouvelle méthode MCP qui vectorise la requête de l'utilisateur, interroge Qdrant avec les filtres appropriés (date, etc.) et formate les résultats. | Moyen |
| **2.4 : Intégration à l'UI** | Créer ou adapter une interface de recherche qui utilise `search_tasks_semantic` et affiche les résultats. Un clic sur un résultat redirige vers la vue de tâche optimisée (Phase 1). | Moyen |

## 2. Stratégie de Test E2E

L'objectif est de valider les flux complets, de l'action de l'utilisateur à la réponse du système, en passant par toutes les nouvelles couches (OpenAI, Qdrant).

### 2.1 Approche et Outils

Pour itérer rapidement, nous utiliserons une approche basée sur des **scripts de test clients légers**. Un simple client en TypeScript/JavaScript utilisant une bibliothèque comme `axios` ou `fetch` pour appeler directement les API du MCP est suffisant.

- **Framework :** **Jest** sera utilisé pour structurer les tests, lancer les scénarios et fournir des assertions claires.
- **Environnement de Test :** Une configuration `docker-compose.yml` sera créée pour lancer localement le MCP `roo-state-manager` et une instance de **Qdrant**. Cela garantit un environnement de test isolé et reproductible.

### 2.2 Scénarios de Test Clés

#### Scénarios pour la Recherche Sémantique

1.  **Indexation d'une tâche :**
    -   **Action :** Exécuter le service d'indexation.
    -   **Validation :** Vérifier via l'API de Qdrant que les vecteurs correspondant à une tâche de test ont bien été créés dans la collection.

2.  **Recherche simple :**
    -   **Action :** Appeler `search_tasks_semantic` avec une requête simple (ex: "créer un site web").
    -   **Validation :** S'assurer que la tâche la plus pertinente est retournée et que le `dialogue_snippet` correspond à la requête.

3.  **Recherche avec filtre de date :**
    -   **Action :** Appeler `search_tasks_semantic` avec une requête et un `date_range`.
    -   **Validation :** Vérifier que seules les tâches dans la période spécifiée sont retournées.

4.  **Recherche sans résultat :**
    -   **Action :** Appeler `search_tasks_semantic` avec une requête absurde.
    -   **Validation :** S'assurer que la réponse est une liste vide et non une erreur.

#### Scénarios pour la Navigation Optimisée

5.  **Chargement du résumé d'une tâche volumineuse :**
    -   **Action :** Appeler `get_task_summary` sur une tâche de test contenant de gros artefacts (ex: un fichier log de 10 Mo).
    -   **Validation :** Vérifier que la réponse est rapide, que la conversation est présente et que les `ArtefactPlaceholder` sont corrects (bon `summary`, `artefactId`, etc.). Le contenu complet du log ne doit PAS être dans la réponse.

6.  **Chargement du détail d'un artefact :**
    -   **Action :** Appeler `get_task_details` avec un `artefactId` obtenu du scénario précédent.
    -   **Validation :** Vérifier que le contenu complet de l'artefact est retourné et correspond au contenu original.

#### Scénario Combiné (Flux Utilisateur Complet)

7.  **Recherche et consultation :**
    -   **Action 1 :** Appeler `search_tasks_semantic` pour trouver une tâche.
    -   **Action 2 :** Utiliser le `taskId` du résultat pour appeler `get_task_summary`.
    -   **Action 3 :** Utiliser l'`artefactId` du résumé pour appeler `get_task_details`.
    -   **Validation :** Confirmer que chaque étape retourne les données attendues et que le flux est cohérent.