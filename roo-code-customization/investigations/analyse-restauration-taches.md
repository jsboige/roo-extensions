# Analyse de la Restauration des Tâches Roo

Ce document détaille le mécanisme de persistance de l'historique des tâches de l'extension Roo et propose des stratégies pour leur restauration après une perte de données.

## Résumé du Mécanisme de Persistance

L'extension Roo utilise un mécanisme de persistance à deux niveaux pour gérer les tâches :

1.  **Fichiers de Tâches Individuels :** Chaque tâche créée par l'utilisateur est sauvegardée sous forme d'un fichier JSON individuel. Par défaut, ces fichiers sont stockés dans le répertoire `C:\Users\<UserProfile>\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks`. Chaque fichier contient l'intégralité du contexte de la tâche (messages, état, etc.).

2.  **Index de l'Historique des Tâches (`taskHistory`) :** Pour afficher rapidement la liste des tâches dans l'interface de Roo sans avoir à lire chaque fichier individuellement, l'extension maintient un index appelé `taskHistory`. Cet index est une liste de métadonnées sur chaque tâche (ID, titre, date, etc.).

Cet index `taskHistory` **n'est pas stocké dans un fichier séparé géré par l'extension**, mais est persisté via l'API de VS Code dans ce qu'on appelle le **"global state"** de l'extension. L'extension ne reconstruit pas cet index à partir des fichiers de tâches au démarrage ; elle se fie entièrement à la version stockée dans le "global state" de VS Code.

C'est pourquoi la simple restauration des fichiers de tâches dans le répertoire `tasks/` n'est pas suffisante pour qu'elles réapparaissent dans l'interface.

## Emplacement Physique de l'Index `taskHistory`

Le "global state" de toutes les extensions VS Code est centralisé et stocké sur le disque dans un fichier de base de données SQLite3.

*   **Chemin du Fichier :** `C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\state.vscdb`
*   **Nom du Fichier :** `state.vscdb`

À l'intérieur de cette base de données SQLite, il existe une table (généralement nommée `ItemTable`) qui stocke les paires clé-valeur. La clé pour l'historique des tâches de Roo est construite en utilisant l'identifiant de l'extension, soit `rooveterinaryinc.roo-cline.taskHistory`.

## Stratégies de Restauration

Basé sur cette analyse, voici les stratégies recommandées pour restaurer l'historique des tâches.

### Stratégie A : Restauration du Fichier d'État Global (Recommandée)

Si l'utilisateur dispose d'une sauvegarde complète de son profil VS Code (`C:\Users\jsboi\AppData\Roaming\Code\`), la solution la plus simple et la plus fiable est de restaurer le fichier de base de données.

**Action :**
1.  Fermer complètement VS Code.
2.  Remplacer le fichier `C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\state.vscdb` actuel par la version sauvegardée.
3.  Relancer VS Code.

Cette approche restaurera non seulement l'historique des tâches de Roo, mais aussi l'état global de toutes les autres extensions, ce qui peut être souhaitable ou non.

### Stratégie B : Reconstruction de l'Index par Script

Si la restauration du fichier `state.vscdb` complet n'est pas possible (par exemple, si la sauvegarde est corrompue ou si l'utilisateur ne souhaite pas affecter ses autres extensions), une approche alternative est de reconstruire l'index `taskHistory` à partir des fichiers de tâches JSON.

**Concept :**
Un script (par exemple, en PowerShell, Python ou Node.js) pourrait être développé pour :
1.  Parcourir le répertoire `C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks`.
2.  Pour chaque fichier de tâche `.json`, lire son contenu et extraire les métadonnées nécessaires (ID, `task`, `ts`, `mode`, `workspace`).
3.  Construire un tableau d'objets `HistoryItem` correspondant à la structure attendue par l'extension.
4.  **Important :** Corriger le chemin du `workspace` dans les métadonnées si les projets ont été restaurés à des emplacements différents de ceux d'origine.
5.  Injecter ce tableau reconstruit directement dans la base de données `state.vscdb` en utilisant un outil en ligne de commande SQLite, ou un script se connectant à la base de données, pour mettre à jour la valeur associée à la clé `rooveterinaryinc.roo-cline.taskHistory`.

Cette stratégie est plus complexe et plus risquée car elle implique de manipuler directement la base de données interne de VS Code, mais elle offre une restauration ciblée et permet de corriger les incohérences de chemins.

---

## Références au Code Source

Cette section détaille les emplacements spécifiques dans le code source de l'extension Roo (`roo-code/`) qui sont pertinents pour la persistance et la restauration des tâches.

### 1. Gestion de l'Index `taskHistory` (Global State)

La logique principale de gestion de l'index `taskHistory` dans l'état global de VS Code est centralisée dans la classe `ClineProvider`.

-   **Fichier clé :** [`roo-code/src/core/webview/ClineProvider.ts`](roo-code/src/core/webview/ClineProvider.ts)
-   **Classe :** `ClineProvider`

**Méthodes spécifiques :**

-   **Lecture de l'historique :** La lecture se fait via des appels à `this.getGlobalState("taskHistory")`. Bien que la méthode `getGlobalState` soit définie dans le `ContextProxy`, son utilisation la plus directe se trouve dans `ClineProvider`.
    -   Exemple à la ligne **1386** dans la méthode `getTaskWithId`.
    -   Exemple à la ligne **1496** dans la méthode `deleteTaskFromState`.

-   **Mise à jour de l'historique :** La méthode `updateTaskHistory` est le point d'entrée principal pour ajouter ou modifier un élément dans l'historique.
    -   **Fichier :** [`roo-code/src/core/webview/ClineProvider.ts`](roo-code/src/core/webview/ClineProvider.ts)
    -   **Méthode :** `async updateTaskHistory(item: HistoryItem): Promise<HistoryItem[]>`
    -   **Lignes :** **2024-2036**
    -   **Extrait de code :**
        ```typescript
        async updateTaskHistory(item: HistoryItem): Promise<HistoryItem[]> {
            const history = (this.getGlobalState("taskHistory") as HistoryItem[] | undefined) || []
            const existingItemIndex = history.findIndex((h) => h.id === item.id)

            if (existingItemIndex > -1) {
                history[existingItemIndex] = item
            } else {
                history.push(item)
            }

            await this.updateGlobalState("taskHistory", history)
            return history
        }
        ```

-   **Suppression de l'historique :** La suppression d'une tâche de l'index est gérée par `deleteTaskFromState`.
    -   **Fichier :** [`roo-code/src/core/webview/ClineProvider.ts`](roo-code/src/core/webview/ClineProvider.ts)
    -   **Méthode :** `async deleteTaskFromState(id: string)`
    -   **Lignes :** **1495-1500**

### 2. Lecture/Écriture des Fichiers de Tâches Individuels

La logique de lecture et d'écriture pour les fichiers JSON de chaque tâche est gérée par la classe `Task` qui s'appuie sur des fonctions utilitaires.

-   **Fichier orchestrateur :** [`roo-code/src/core/task/Task.ts`](roo-code/src/core/task/Task.ts)
-   **Classe :** `Task`

**Méthodes et fonctions clés :**

-   **Écriture sur le disque :** Les méthodes `saveApiConversationHistory` et `saveClineMessages` dans la classe `Task` sont responsables de la sauvegarde. Elles appellent des fonctions utilitaires qui gèrent l'écriture réelle.
    -   `saveApiConversationHistory` à la ligne **517**.
    -   `saveClineMessages` à la ligne **574**.

-   **Logique de bas niveau :** La lecture et l'écriture physique sont dans le module `task-persistence`. Les fonctions construisent le chemin du répertoire de la tâche et écrivent les fichiers `api_conversation_history.json` et `ui_messages.json`.
    -   **Module :** `roo-code/src/core/task-persistence/` (implicite depuis les imports `../task-persistence`)
    -   **Fonctions clés (à trouver dans ce module) :** `saveApiMessages`, `saveTaskMessages`, `readApiMessages`, `readTaskMessages`.

-   **Obtention du chemin du répertoire de la tâche :** La méthode `getTaskWithId` dans `ClineProvider` montre comment le chemin est obtenu.
    -   **Fichier :** [`roo-code/src/core/webview/ClineProvider.ts`](roo-code/src/core/webview/ClineProvider.ts)
    -   **Ligne d'appel pertinente :** **1390-1392**
        ```typescript
        const { getTaskDirectoryPath } = await import("../../utils/storage")
        const globalStoragePath = this.contextProxy.globalStorageUri.fsPath
        const taskDirPath = await getTaskDirectoryPath(globalStoragePath, id)
        ```

### 3. Structure de Données `HistoryItem`

La structure de l'objet qui est stocké dans le tableau `taskHistory` est définie à l'aide de `zod`. C'est cette structure qui doit être reconstruite par un script de migration.

-   **Fichier de définition :** [`roo-code/packages/types/src/history.ts`](roo-code/packages/types/src/history.ts)
-   **Schéma Zod :** `historyItemSchema`
-   **Lignes :** **7-20**
-   **Structure :**
    ```typescript
    export const historyItemSchema = z.object({
        id: z.string(),
        number: z.number(),
        ts: z.number(),
        task: z.string(),
        tokensIn: z.number(),
        tokensOut: z.number(),
        cacheWrites: z.number().optional(),
        cacheReads: z.number().optional(),
        totalCost: z.number(),
        size: z.number().optional(),
        workspace: z.string().optional(),
        mode: z.string().optional(),
    })
    ```