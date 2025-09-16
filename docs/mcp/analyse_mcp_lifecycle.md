# Analyse Approfondie du Cycle de Vie des MCPs dans roo-code

Ce rapport détaille le fonctionnement interne du `McpHub` et le cycle de vie des serveurs MCP, basé sur l'analyse du code source de `roo-code/src/services/mcp/McpHub.ts`.

## 1. Processus de Démarrage Initial (Global et Projet)

Le démarrage est initié dans le constructeur de la classe `McpHub` et suit un processus clair pour les serveurs globaux et ceux définis au niveau du projet.

1.  **Initialisation Concurrente :** Le constructeur appelle `initializeGlobalMcpServers()` et `initializeProjectMcpServers()`.
2.  **Lecture de la Configuration :**
    *   **Global :** `initializeGlobalMcpServers` lit le fichier `mcp_settings.json` depuis le répertoire de configuration global de l'extension.
    *   **Projet :** `initializeProjectMcpServers` lit le fichier `.roo/mcp.json` à la racine du workspace. S'il n'existe pas, aucune action n'est entreprise.
3.  **Mise à Jour des Connexions :** Les deux chemins mènent à `updateServerConnections(servers, source)`. Cette fonction centrale compare la nouvelle configuration à l'état actuel :
    *   Les serveurs absents de la nouvelle configuration sont proprement arrêtés et supprimés via `deleteConnection`.
    *   Les nouveaux serveurs et ceux dont la configuration a changé sont connectés.
4.  **Connexion d'un Serveur (`connectToServer`) :**
    *   Le système vérifie si les MCPs sont activés globalement via `isMcpEnabled()`.
    *   Si un serveur est marqué comme `"disabled": true`, une connexion "placeholder" est créée pour le suivre dans l'interface, mais aucun processus n'est lancé.
    *   Pour les serveurs actifs, un `Client` du SDK MCP est créé avec le `transport` adéquat (`Stdio`, `SSE`, etc.).
    *   Pour les serveurs `stdio`, des listeners sont attachés aux événements `onerror`, `onclose`, et au flux `stderr` pour une capture d'erreur détaillée.
    *   L'appel à `client.connect(transport)` lance effectivement le processus serveur.

## 2. Mécanisme de Surveillance (`watchPaths`) et Déclenchement du Redémarrage

Deux mécanismes de surveillance coexistent :

1.  **Surveillance des Fichiers de Configuration (`mcp.json`) :**
    *   `watchMcpSettingsFile()` (global) et `watchProjectMcpFile()` (projet) utilisent l'API `vscode.workspace.createFileSystemWatcher`.
    *   Toute modification de ces fichiers déclenche une relecture complète et un appel à `updateServerConnections`, ce qui peut entraîner le redémarrage de multiples serveurs.

2.  **Surveillance de Fichiers Spécifiques (`watchPaths`) :**
    *   Ce mécanisme, configuré dans `setupFileWatcher`, **s'applique uniquement aux serveurs de type `stdio`**.
    *   Si la configuration d'un serveur `stdio` contient la propriété `watchPaths`, un *watcher* `chokidar` est initialisé pour ces chemins.
    *   Lorsqu'un changement est détecté, la fonction `restartConnection(serverName, source)` est appelée **uniquement pour ce serveur spécifique**.

## 3. Logique Exacte de la Fonction `restartConnection`

Il s'agit d'un redémarrage complet ("hard restart") qui suit des étapes précises :

1.  Passe le hub en état `isConnecting` pour bloquer d'autres opérations.
2.  Affiche une notification à l'utilisateur (`Server restarting...`).
3.  Appelle `await this.deleteConnection(serverName, source)`, qui est une étape clé :
    *   Arrête et supprime les `watchers` `chokidar` pour ce serveur.
    *   Appelle `transport.close()`, ce qui termine le processus `stdio` sous-jacent.
    *   Retire la connexion de l'état interne (`this.connections`).
4.  Récupère la configuration stockée de l'ancienne connexion.
5.  Appelle `await this.connectToServer(...)` avec cette configuration pour recréer une instance entièrement nouvelle du serveur.
6.  Notifie l'interface du résultat.

## 4. Gestion des Erreurs

Le système intègre une gestion robuste des erreurs à plusieurs niveaux :

*   **Validation de Schéma (Zod) :** La configuration est validée via `ServerConfigSchema` avant toute tentative de connexion, fournissant des retours clairs en cas de format invalide.
*   **Erreurs de Connexion :** Un bloc `try...catch` dans `connectToServer` capture les échecs lors de l'établissement de la connexion (`client.connect()`).
*   **Erreurs de Transport :** Les événements `onerror` et `onclose` des transports permettent de détecter les déconnexions inattendues.
*   **Capture `stderr` (pour `stdio`) :** Le flux `stderr` des processus `stdio` est écouté en continu. Toute sortie est enregistrée dans l'historique des erreurs du serveur, ce qui est essentiel pour le diagnostic.
*   **Historique d'Erreurs :** `appendErrorMessage` conserve les 100 derniers messages d'erreur pour chaque serveur, accessibles depuis l'interface utilisateur.

## 5. Points de Défaillance Potentiels pour le Rechargement de `roo-state-manager`

Basé sur cette analyse, voici les causes les plus probables du problème de non-rechargement :

1.  **Cause la Plus Probable : Type de Serveur Incorrect.** Si `roo-state-manager` n'est pas configuré avec `"type": "stdio"` dans `mcp_settings.json`, la logique de `setupFileWatcher` qui gère les `watchPaths` est **totalement ignorée**. Le rechargement automatique ne peut donc pas fonctionner.
2.  **Chemins `watchPaths` Incorrects :** Les chemins spécifiés dans `watchPaths` pourraient être invalides ou mal résolus, empêchant `chokidar` de surveiller les bons fichiers.
3.  **Processus Orphelin ("Zombie") :** Il est possible que `transport.close()` ne termine pas correctement le processus `roo-state-manager` (par exemple, à cause du wrapper `cmd.exe` sous Windows). Un processus orphelin pourrait empêcher le nouveau processus de démarrer correctement.
4.  **Délais de Build et Détection de Changement :** Le watcher (`chokidar`) peut déclencher le redémarrage dès la détection d'un changement. Si le build du serveur prend un certain temps, le redémarrage pourrait être tenté sur un fichier `build/index.js` incomplet ou corrompu. Les options comme `awaitWriteFinish` sont présentes mais commentées dans le code, ce qui pourrait être une piste d'amélioration.
5.  **Erreur Silencieuse au Redémarrage :** Une erreur non capturée pourrait se produire dans la logique de `restartConnection`. Il serait judicieux d'inspecter les logs de l'hôte d'extension de VS Code pour des indices.