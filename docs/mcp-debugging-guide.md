# Guide de Débogage pour les Serveurs MCP

Ce guide fournit des stratégies et des explications techniques pour déboguer efficacement les serveurs MCP (Model Context Protocol) lancés par l'extension Roo.

## Comprendre le Pipeline de Lancement `stdio`

Il est essentiel de comprendre que Roo ne lance pas les serveurs MCP `stdio` via un shell système (comme Bash, PowerShell ou cmd). À la place, il utilise directement le module `child_process` de Node.js pour créer un processus enfant.

Cette approche a une implication majeure : **les redirections de flux standards (`>`, `2>&1`, etc.) configurées dans `mcp_settings.json` sont inefficaces**. Le processus est invoqué directement, comme on peut le voir dans la configuration du transporteur `StdioClientTransport` dans [`roo-code/src/services/mcp/McpHub.ts:447-456`](roo-code/src/services/mcp/McpHub.ts:447-456).

### La Capture de `stderr`

Pour intercepter les erreurs du serveur MCP, Roo configure le flux `stderr` pour qu'il soit "pipé". L'option [`stderr: "pipe"`](roo-code/src/services/mcp/McpHub.ts:455) dans la configuration du transporteur permet à l'extension de lire directement tout ce que le serveur MCP écrit sur sa sortie d'erreur standard.

### Le Filtrage des Logs

Toute sortie sur `stderr` n'est pas systématiquement traitée comme une erreur fatale. Roo applique une règle de filtrage simple : si une ligne de sortie sur `stderr` contient le mot `"INFO"` (insensible à la casse), elle est considérée comme un message d'information et est simplement journalisée dans la console de débogage de VS Code. Toute autre sortie est traitée comme une erreur et affichée dans l'interface de Roo.

Cette logique est visible ici : [`roo-code/src/services/mcp/McpHub.ts:482-501`](roo-code/src/services/mcp/McpHub.ts:482-501).

## Stratégies de Débogage

### 1. Méthode Principale : Écrire sur `console.error`

La manière la plus fiable de signaler une erreur depuis un serveur MCP est d'écrire directement sur le flux d'erreur standard. En Node.js, cela se fait via :

- `console.error("Mon message d'erreur");`
- `process.stderr.write("Mon message d'erreur\n");`

Ces appels envoient le message à travers le `pipe` `stderr` que Roo écoute, ce qui affichera l'erreur dans l'interface utilisateur.

### 2. Méthode Secondaire : Journalisation dans un Fichier

Dans certains cas, un serveur MCP peut planter très tôt dans son cycle de vie, avant même que la journalisation `stderr` ne soit correctement établie. Pour ces situations, la meilleure approche est de rediriger les logs vers un fichier.

Cette technique a été utilisée avec succès pour le `roo-state-manager`. Elle consiste à :
1.  Créer un module de journalisation qui écrit dans un fichier (par exemple, `debug-logger.ts`).
2.  Importer et initialiser ce module **à la toute première ligne** du fichier d'entrée de votre serveur MCP (ex: `index.ts`).

Cela garantit que même les erreurs les plus précoces sont capturées.

### Ce qu'il faut éviter

- **N'utilisez pas les redirections shell** dans les `args` de votre `mcp_settings.json` (ex: `["-c", "mon_script.js 2> log.txt"]`). Elles ne fonctionneront pas.
- **N'utilisez pas `console.log()` pour signaler des erreurs**. `console.log` écrit sur `stdout`, qui est utilisé pour le protocole de communication MCP. Envoyer des données non-MCP sur `stdout` corrompra la communication.

En suivant ce guide, vous devriez être en mesure de diagnostiquer et de résoudre les problèmes de vos serveurs MCP plus efficacement.

### Étude de Cas : Le Crash Silencieux

Un problème particulièrement instructif est survenu avec le serveur `roo-state-manager`, qui refusait de démarrer sans générer la moindre erreur visible dans l'interface de Roo.

**Symptômes :**
*   Le serveur `roo-state-manager` ne démarrait pas et son statut restait inactif.
*   Aucun message d'erreur n'apparaissait dans les notifications ou les logs de Roo.
*   Une tentative de journalisation dans un fichier (comme décrit dans la méthode secondaire) ne produisait aucun fichier de log, indiquant que le processus plantait avant même l'exécution de la première ligne de code applicatif.

**Cause Racine :**
L'enquête a révélé que le problème provenait de la configuration de lancement dans `mcp_settings.json`. La commande était définie comme suit :
```json
"command": "cmd",
"args": ["/c", "node", "mcps/internal/servers/roo-state-manager/build/index.js"]
```
Le problème de cette approche est que Roo écoute le `stderr` du processus qu'il lance directement, c'est-à-dire `cmd.exe`. Or, `cmd.exe` lance à son tour `node.exe` comme un processus enfant distinct. Si `node.exe` échoue immédiatement (par exemple, à cause d'un module manquant ou d'une erreur de syntaxe précoce), son `stderr` est envoyé à `cmd.exe`, mais `cmd.exe` peut se terminer sans propager cette erreur à son propre `stderr`. Roo n'entend donc jamais l'erreur.

**Solution :**
La solution consiste à éliminer l'intermédiaire `cmd.exe` et à laisser Roo lancer directement le processus Node.js. La configuration a été corrigée comme suit :
```json
"command": "node",
"args": ["mcps/internal/servers/roo-state-manager/build/index.js"]
```
Avec cette configuration, Roo est directement connecté au `stderr` du processus `node`. Toute erreur de démarrage, même la plus précoce, est maintenant capturée et affichée correctement dans l'interface, permettant un débogage efficace.