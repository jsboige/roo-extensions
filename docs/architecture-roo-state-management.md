# Architecture de Gestion de l'État de Roo

**Auteur:** Roo, Architecte Technique
**Date:** 2025-08-30
**Statut:** Implémenté

## 1. Contexte et Problématique

### 1.1. Le problème du "Large Extension State"

L'extension Roo rencontre actuellement des problèmes d'instabilité critiques, manifestés par des échecs de connexion des MCPs et une lenteur générale. La cause racine identifiée est le volume excessif de l'état de l'extension, stocké dans les répertoires globaux de VSCode. Le message d'erreur `large extension state detected ... Consider to use 'storageUri' or 'globalStorageUri' to store this data on disk instead` confirme ce diagnostic.

### 1.2. Données Critiques à Préserver

Le cœur de l'état de Roo réside dans l'arborescence de répertoires sous `C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks`. Cette arborescence contient des milliers de conversations et représente une donnée métier précieuse qui doit être préservée à tout prix.

### 1.3. Scénario de Catastrophe : Perte du `state.vscdb`

Un scénario de "crash" a été identifié où le fichier `state.vscdb` de VSCode peut être perdu ou corrompu, tandis que l'arborescence `tasks` reste intacte. La solution d'architecture doit donc impérativement inclure un mécanisme de reconstruction de l'état de Roo à partir de cette arborescence de tâches.

## 2. Analyse de la Structure Actuelle de l'État

L'état de Roo repose sur une architecture de stockage à deux niveaux principaux, entièrement basée sur des fichiers JSON.

### 2.1. Stockage Principal : Les Données Brutes de l'Extension

C'est la source de vérité, directement gérée par l'extension VS Code `rooveterinaryinc.roo-cline`.

-   **Contenu :** L'intégralité des conversations, tâches et métadonnées.
-   **Emplacement :** Un sous-répertoire du `globalStorage` de VS Code, dont le chemin varie selon l'OS (par exemple, `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline-1.0.0` sur Windows).
-   **Structure :**
    ```
    <globalStorage>/rooveterinaryinc.roo-cline-1.0.0/
    └── tasks/
        ├── <task_id_1>/
        │   ├── api_conversation_history.json
        │   ├── ui_messages.json
        │   └── task_metadata.json
        └── <task_id_2>/
            └── ...
    ```
-   **Problème :** C'est ce répertoire `tasks` qui, en devenant trop volumineux, dépasse les limites de ce que le `globalState` (géré par `state.vscdb`) est conçu pour gérer, provoquant le `large extension state`.

### 2.2. Stockage Secondaire : Le Cache du `roo-state-manager`

Pour des raisons de performance, le MCP `roo-state-manager` maintient un cache local.

-   **Contenu :** Données agrégées, index, et arborescences de tâches pré-calculées pour un accès rapide.
-   **Emplacement :** Un répertoire `.cache/roo-state-manager/` relatif au lieu d'exécution du MCP.
-   **Rôle :** Il sert d'optimisation et peut être reconstruit à partir du stockage principal. Sa perte n'entraîne pas de perte de données critiques.

### 2.3. Le rôle du `state.vscdb`

Le fichier `state.vscdb` est une base de données SQLite utilisée par VSCode pour gérer le `globalState` des extensions (un simple stockage clé/valeur). Lorsque l'extension Roo tente de stocker des références ou des métadonnées sur ses milliers de tâches dans ce `globalState`, la taille de la base de données explose, entraînant l'erreur. La solution n'est donc pas de stocker les données **dans** le `globalState`, mais **à côté**, en utilisant un pointeur fourni par `globalStorageUri`.

Il est crucial de comprendre cette distinction :
-   Le **`state.vscdb`** contient les données "chaudes" et légères que l'extension enregistre via l'API `Memento` de VSCode. C'est ce fichier, lorsqu'il atteint quelques mégaoctets (par exemple, 7 Mo), qui déclenche l'avertissement `large extension state` de VSCode. Il est conçu pour des clés/valeurs simples, pas pour le stockage de masse.
-   Le **répertoire `tasks`**, géré via `globalStorageUri`, contient les données "froides" et lourdes. Il peut atteindre plusieurs centaines de gigaoctets sans que VSCode ne s'en aperçoive directement. La saturation de ce répertoire n'est pas détectée par VSCode mais cause des ralentissements et des problèmes de performance au sein de l'extension elle-même.

### 2.4. Composition du Répertoire `tasks` : Checkpoints et Métadonnées

Chaque répertoire de tâche (`<task_id>`) contient deux catégories de fichiers :

-   **Métadonnées Essentielles (JSON) :** Ce sont les fichiers `api_conversation_history.json`, `ui_messages.json`, et `task_metadata.json`. Ils sont légers et contiennent la logique de la conversation. Ils sont indispensables à la restauration et au fonctionnement de Roo.
-   **Checkpoints de Contexte :** Ce sont des fichiers (potentiellement volumineux, avec des extensions comme `.json.gz`, `.bin`, etc.) qui représentent des "instantanés" du contexte d'un modèle à un moment donné. Historiquement utilisés pour la reprise rapide de tâches, beaucoup peuvent être obsolètes si la logique de l'extension a changé ou si les tâches sont terminées. C'est l'accumulation de ces checkpoints qui est la cause principale de la taille excessive du répertoire `tasks`.


### 2.5. Mécanisme de Checkpointing (Shadow Repository)

En complément des métadonnées, Roo implémente un mécanisme de checkpointing sophistiqué pour assurer l'intégrité et la réversibilité des modifications effectuées par les modes "code". Ce système repose sur l'utilisation de dépôts Git miroirs, aussi appelés "shadow repositories".

-   **Principe :** Pour chaque tâche qui implique des modifications de fichiers, un dépôt Git miroir est créé, isolé du dépôt de travail de l'utilisateur.
-   **Emplacement :** Ces dépôts sont stockés dans un sous-répertoire spécifique de la tâche : `{globalStorageDir}/tasks/{taskId}/checkpoints/`.
-   **Fonctionnement :** Avant toute modification d'un fichier par un agent Roo, un "checkpoint" est créé. Ce checkpoint est en réalité un **commit** dans le dépôt miroir, capturant l'état exact du fichier avant l'altération.
-   **Gestion :** Ce processus est entièrement automatisé et géré par le `ShadowCheckpointService` ([`roo-code/src/services/checkpoints/ShadowCheckpointService.ts`](roo-code/src/services/checkpoints/ShadowCheckpointService.ts)), qui est lui-même orchestré par la classe `Task` ([`roo-code/src/core/task/Task.ts`](roo-code/src/core/task/Task.ts)) lorsqu'une opération sur un fichier est demandée.
-   **Objectif :** L'objectif principal de ce mécanisme est de fournir un filet de sécurité robuste. Si une opération de modification de fichier échoue ou produit un résultat indésirable, Roo peut utiliser ce dépôt miroir pour effectuer un retour en arrière atomique et sécurisé via une commande `git reset --hard`, restaurant ainsi le fichier à son état d'origine sans aucun risque de corruption.

## 3. Proposition d'Architecture Cible

L'architecture proposée vise à découpler le stockage des tâches du mécanisme de `globalState` de VS Code, tout en garantissant la portabilité, la performance et la résilience des données.

### 3.1. Principe Fondamental : Externalisation via `globalStorageUri`

Le cœur de la solution est l'adoption de l'API `globalStorageUri` fournie par VS Code.

-   **`globalStorageUri` :** L'extension, à son activation, demandera à VS Code un URI (`vscode.Uri`) pointant vers un répertoire de stockage qui lui est dédié. Cet emplacement est géré par VS Code, garantissant un chemin valide et propre à l'extension sur n'importe quel système d'exploitation.
-   **Déplacement des données :** Le répertoire `tasks` ne sera plus stocké dans le `globalStorage` par défaut, mais directement à la racine de l'emplacement fourni par `globalStorageUri`.
-   **Avantages :**
    -   **Résolution du "Large State" :** Le `globalState` (`state.vscdb`) ne contiendra plus qu'une seule information : le chemin d'accès au stockage externe. La taille des données de tâches n'a plus d'impact sur la stabilité de VS Code.
    -   **Gestion Explicite :** L'extension devient entièrement responsable de la gestion (lecture, écriture, listing) de son propre stockage, offrant un contrôle total sur l'organisation des données.
    -   **Portabilité :** Le chemin étant fourni par l'API, l'architecture est naturellement compatible avec toutes les plateformes (Windows, macOS, Linux, Codespaces).

### 3.2. Schéma de la Nouvelle Architecture

```mermaid
graph TD
    subgraph VSCode Process
        A[Extension Roo] -- activate() --> B{ExtensionContext};
        B -- .globalStorageUri --> C[URI: /path/to/globalStorage/publisher.extension/];
        B -- .globalState --> D[state.vscdb (quasi-vide)];
    end

    subgraph File System
        C -- points vers --> E[Répertoire de Stockage Géré];
        E -- contient --> F[tasks/];
        F -- contient --> G[task_id_1/...];
        F -- contient --> H[task_id_2/...];
    end

    I[MCP roo-state-manager] -- lit depuis --> F;

    A -- informe --> I;
```

### 3.3. Cycle de Vie des Données

1.  **Première Activation de l'Extension (ou après mise à jour) :**
    -   Au démarrage, l'extension vérifie automatiquement la présence d'un ancien répertoire de tâches.
    -   Si un ancien répertoire est trouvé et que le nouveau (dans `globalStorageUri`) n'existe pas, elle déplace atomiquement le contenu.
    -   Un flag `is_migrated_to_globalStorageUri: true` est ensuite stocké dans le `globalState` pour empêcher de futures migrations.
2.  **Activation Normale :**
    -   L'extension récupère l'URI via `context.globalStorageUri`.
    -   Toutes les opérations de lecture/écriture de tâches se font désormais dans ce répertoire.
    -   L'extension passe le chemin de ce répertoire au `roo-state-manager` lors de son démarrage.
3.  **Désinstallation de l'Extension :**
    -   VS Code est responsable de la suppression du répertoire pointé par `globalStorageUri`, assurant un nettoyage complet.

## 4. Protocole de Restauration et de Résilience

Ce protocole est la pierre angulaire de la fiabilité du nouveau système. Il doit permettre à un utilisateur de restaurer un état de Roo pleinement fonctionnel en utilisant uniquement une sauvegarde de son répertoire `tasks`.

### 4.1. Scénario de Déclenchement

Le protocole de restauration est activé dans les cas suivants :
-   Corruption ou perte du `state.vscdb` de VSCode.
-   Changement de machine par l'utilisateur (migration manuelle).
-   Erreur inattendue au démarrage de l'extension, suggérant un état incohérent.

### 4.2. Processus de Reconstruction Pas-à-Pas

La restauration est orchestrée par le `roo-state-manager` via un nouvel outil.

1.  **Étape 1 : Initialisation**
    -   L'utilisateur place sa sauvegarde du répertoire `tasks` à l'emplacement pointé par `context.globalStorageUri`.
    -   L'utilisateur lance la commande de reconstruction.
2.  **Étape 2 : Scan et Indexation**
    -   Le `roo-state-manager` scanne l'intégralité de l'arborescence `tasks` fournie.
    -   Pour chaque `task_id` trouvé, il lit le `task_metadata.json` pour en extraire les informations essentielles (date de création, titre, etc.).
3.  **Étape 3 : Reconstruction du Cache d'Index**
    -   Le MCP nettoie son propre cache (`.cache/roo-state-manager/`).
    -   Il reconstruit l'arborescence complète des workspaces, projets et clusters de tâches en se basant sur les métadonnées scannées, en utilisant les mêmes algorithmes que ceux définis dans l'architecture `roo-state-manager` existante.
4.  **Étape 4 : Validation et Rapport**
    -   Le MCP effectue un comptage des tâches et workspaces détectés.
    -   Il retourne un rapport à l'utilisateur, confirmant le succès de l'opération et affichant un résumé de l'état reconstruit.

### 4.3. Validation de l'État Reconstruit

L'état est considéré comme valide si :
-   Le `roo-state-manager` démarre sans erreur.
-   L'outil `browse_task_tree` retourne une arborescence cohérente.
-   L'utilisateur peut naviguer dans ses anciennes conversations.

## 5. Spécification des Outils de Maintien en Condition Opérationnelle (MCO)

Ces outils seront exposés via le MCP `roo-state-manager` et permettront à l'utilisateur (ou à un script de maintenance) de gérer le cycle de vie de l'état de Roo.

### 5.1. Outil de Diagnostic (`diagnose_roo_state`)

-   **Objectif :** Fournir un bilan de santé complet de l'état de Roo.
-   **Actions :**
    -   Vérifie l'existence et l'accès au répertoire `globalStorageUri`.
    -   Compte le nombre total de tâches dans le répertoire `tasks`.
    -   Valide la structure des 10 tâches les plus récentes (présence des 3 fichiers JSON).
    -   Mesure la taille totale du répertoire `tasks`.
    -   **Distingue et mesure séparément la taille cumulée des métadonnées JSON et la taille cumulée des checkpoints.**
    -   Tente d'extraire des métriques de base du fichier `state.vscdb` (par exemple, nombre de clés stockées pour l'extension Roo), si l'accès en lecture seule est possible sans perturber VSCode.
    -   Vérifie l'état du cache du `roo-state-manager` (existence, date de dernière mise à jour).
-   **Output :** Un rapport JSON enrichi avec un statut global (`OK`, `WARNING`, `ERROR`), des métriques détaillées sur la composition du stockage et l'état du `state.vscdb`.

### 5.2. Logique de Migration Automatique

-   **Objectif :** Assurer la transition transparente de l'ancien système de stockage vers le nouveau, sans aucune action de l'utilisateur.
-   **Implémentation :** La logique de migration est directement intégrée dans la méthode d'initialisation de l'extension (`ContextProxy.initialize`).
-   **Actions au démarrage :**
    1.  Détecte l'ancien emplacement de stockage en se basant sur le chemin relatif par rapport au `globalStorageUri` parent.
    2.  Récupère le nouvel emplacement via `globalStorageUri`.
    3.  Si l'ancien répertoire existe et le nouveau non, déplace (`fs.rename`) l'intégralité du répertoire `tasks`.
    4.  Met à jour le `globalState` de VSCode avec la clé `is_migrated_to_globalStorageUri: true` pour garantir que la migration ne s'exécute qu'une seule fois.

### 5.3. Outil de Restauration (`rebuild_roo_state_from_tasks`)

-   **Objectif :** Implémenter le protocole de restauration décrit dans la section 4.
-   **Actions :**
    -   Prend en paramètre optionnel un chemin vers une sauvegarde externe du répertoire `tasks`. Si non fourni, utilise le répertoire `tasks` actuel.
    -   Exécute les étapes de Scan, d'Indexation et de Reconstruction du cache.
    -   Nettoie les anciens index et caches avant de reconstruire.
-   **Output :** Un résumé de l'état reconstruit (nombre de tâches, workspaces, etc.).

### 5.4. Outil de Nettoyage des Checkpoints (`cleanup_obsolete_checkpoints`)

-   **Objectif :** Libérer de l'espace disque en supprimant les checkpoints de contexte qui ne sont plus nécessaires, sans perdre aucune donnée de conversation.
-   **Actions :**
    -   Parcourt l'ensemble des répertoires `tasks`.
    -   Pour chaque tâche, identifie les fichiers de checkpoint en se basant sur une nomenclature définie (par ex., tout ce qui n'est pas les trois fichiers JSON essentiels).
    -   Applique une stratégie de nettoyage configurable (par ex., supprimer les checkpoints des tâches terminées depuis plus de X jours, ou ne garder que le dernier checkpoint).
    -   Fournit un mode "dry-run" pour simuler les suppressions et estimer l'espace qui serait libéré.
-   **Output :** Un rapport détaillant les fichiers supprimés et l'espace total récupéré.

## 6. Conclusion

Cette architecture répond de manière robuste et complète à la problématique du "large extension state". En externalisant le stockage des tâches via `globalStorageUri`, nous découplons la durée de vie et le volume des données de Roo du mécanisme interne de gestion d'état de VS Code, garantissant ainsi stabilité et performance.

De plus, l'introduction d'un protocole de restauration clair et d'outils de maintenance dédiés confère au système une résilience accrue, permettant aux utilisateurs de sauvegarder, migrer et restaurer leur historique de tâches en toute confiance. Cette approche, alignée sur les meilleures pratiques de développement d'extensions VS Code, pérennise l'un des atouts les plus précieux de Roo : sa mémoire conversationnelle.
