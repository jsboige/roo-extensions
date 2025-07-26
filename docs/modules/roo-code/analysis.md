# Analyse des mécanismes internes de roo-code

Ce document détaille le fonctionnement de deux mécanismes clés du sous-module `roo-code` : le filtrage de l'historique et l'indexation sémantique.

## 1. Filtrage de l'historique

Le mécanisme de filtrage de l'historique des tâches de `roo-code` repose sur une architecture simple et efficace, où la logique est principalement déportée côté client (dans l'interface React).

### Flux de données

1.  **Génération des métadonnées :** Chaque action au sein d'une tâche (envoi de message, utilisation d'un outil, etc.) déclenche la sauvegarde de l'état de la conversation. Cette sauvegarde s'opère dans la méthode `saveClineMessages` de la classe `Task` ([`roo-code/src/core/task/Task.ts`](roo-code/src/core/task/Task.ts:334)).

2.  **Calcul de `HistoryItem` :** Lors de la sauvegarde, la méthode `taskMetadata` ([`roo-code/src/core/task-persistence/taskMetadata.ts`](roo-code/src/core/task-persistence/taskMetadata.ts:22)) est appelée. Elle agrège une série d'informations pour créer un objet `HistoryItem`. Cet objet contient toutes les données nécessaires à l'affichage et au filtrage :

    ```typescript
    export type HistoryItem = {
    	id: string,
    	number: number,
    	ts: number, // timestamp pour le tri
    	task: string, // texte de la tâche pour la recherche
    	tokensIn: number,
    	tokensOut: number,
    	cacheWrites: number,
    	cacheReads: number,
    	totalCost: number,
    	size: number,
    	workspace: string, // pour le filtrage par espace de travail
    }
    ```

3.  **Mise à jour de l'historique :** L'objet `historyItem` est ensuite transmis au `ClineProvider` via la méthode `updateTaskHistory` ([`roo-code/src/core/task/Task.ts:352`](roo-code/src/core/task/Task.ts:352)).

    ```typescript
    await this.providerRef.deref()?.updateTaskHistory(historyItem)
    ```

4.  **Affichage et filtrage dans l'interface :** Le `ClineProvider` maintient une liste à jour de tous les `HistoryItem` et la communique à l'interface React (la *webview*). Le filtrage par texte libre (sur le champ `task`) et par espace de travail (sur le champ `workspace`) est donc entièrement géré par la logique de l'interface, qui opère sur la collection complète des métadonnées des tâches.

Ce design permet de centraliser la logique de persistance et de calcul des métadonnées dans le *backend* de l'extension, tout en laissant à l'interface la flexibilité de gérer l'affichage et le filtrage de manière réactive.

## 2. Indexation sémantique

Le mécanisme d'indexation sémantique est plus complexe et repose sur une chaîne d'outils pour transformer le code source en vecteurs sémantiques pesquisables.

### Flux de données (hypothèse)

1.  **Déclenchement de l'indexation :** Une action de l'utilisateur (probablement via la palette de commandes de VS Code) lance le processus d'indexation sur un répertoire de travail.

2.  **Extraction des définitions de code :** Le système fait appel à l'outil `listCodeDefinitionNamesTool` ([`roo-code/src/core/tools/listCodeDefinitionNamesTool.ts`](roo-code/src/core/tools/listCodeDefinitionNamesTool.ts:11)). Cet outil est au cœur du processus d'extraction.

3.  **Parsing avec `tree-sitter` :** L'outil `listCodeDefinitionNamesTool` utilise le service `tree-sitter` ([`roo-code/src/services/tree-sitter/index.ts`](roo-code/src/services/tree-sitter/index.ts:148)) pour analyser le code source. Pour chaque fichier, il construit un Arbre Syntaxique Abstrait (AST) et y applique des requêtes spécifiques à chaque langage (définies dans [`roo-code/src/services/tree-sitter/queries/`](roo-code/src/services/tree-sitter/queries/)) pour en extraire les "définitions" (fonctions, classes, méthodes, etc.).

    ```typescript
    // Extrait de roo-code/src/services/tree-sitter/index.ts
    const tree = parser.parse(fileContent)
    const captures = query.captures(tree.rootNode)
    ```

4.  **Génération des *embeddings* :** Les définitions de code extraites, qui représentent les "morceaux" sémantiques du code, sont ensuite envoyées à un service externe pour être converties en vecteurs (*embeddings*). D'après l'analyse du code, ce service est très probablement **l'API d'OpenAI**, bien que l'appel explicite à une API d'*embedding* ne soit pas directement visible. Le projet intègre de nombreux fournisseurs, dont OpenAI ([`roo-code/src/api/providers/openai.ts`](roo-code/src/api/providers/openai.ts:12)).

5.  **Stockage des vecteurs :** Les *embeddings* et les métadonnées associées (chemin du fichier, nom de la fonction, etc.) sont stockés dans une base de données vectorielle. La technologie exacte de cette base de données n'a pas pu être identifiée lors de cette analyse (aucune référence à `qdrant`, `pinecone`, `chroma`, etc. n'a été trouvée). Il est possible qu'une solution locale et légère, comme une base de données SQLite avec une extension (par exemple, `sqlite-vss`), ou un simple stockage de fichiers plats, soit utilisée.

6.  **Recherche sémantique :** Quand l'utilisateur effectue une recherche, le texte de sa requête est à son tour converti en *embedding* via le même service (OpenAI). Ce vecteur est ensuite utilisé pour trouver les vecteurs les plus similaires dans la base de données, retournant ainsi les extraits de code les plus pertinents sémantiquement.
