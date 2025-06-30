# Tests du MCP GitHub Projects

Ce répertoire contient des scripts et de la documentation pour tester le MCP GitHub Projects.

## Configuration requise

- PowerShell 5.1 ou supérieur
- Accès au MCP CLI (généralement installé avec Roo)
- Token GitHub avec les permissions appropriées (déjà configuré dans `mcp_settings.json`)

## Structure des fichiers

- `test-github-projects.ps1` : Script principal de test des fonctionnalités du MCP GitHub Projects
- `README.md` : Documentation du processus de test
- `results.md` : Résultats des tests (généré après exécution)

## Démarrage et Arrêt du MCP GitHub Projects

Le MCP GitHub Projects est conçu pour fonctionner en mode **stdio** par défaut. Cela signifie qu'il communique via l'entrée et la sortie standard lorsqu'il est lancé directement.

**Démarrage pour les tests (mode stdio) :**

Le MCP est généralement démarré automatiquement par le système Roo s'il est configuré dans [`roo-config/settings/servers.json`](roo-config/settings/servers.json:1).
Si vous devez le démarrer manuellement pour des tests spécifiques en dehors de l'environnement Roo complet, vous pouvez utiliser la commande suivante depuis la racine du projet :

```bash
node mcps/internal/servers/github-projects-mcp/dist/index.js
```

**Vérification du démarrage :**

En mode stdio, le serveur affichera un message de type :
`Serveur MCP Gestionnaire de Projet démarré sur stdio`

Il n'écoutera pas sur un port réseau dans cette configuration.

**Arrêt du MCP :**

Si vous avez démarré le MCP manuellement dans un terminal, vous pouvez généralement l'arrêter en utilisant `Ctrl+C` dans ce terminal.
Si le MCP est géré par Roo, Roo s'occupera de son arrêt.

**Fonctionnement sur un port réseau (non supporté nativement) :**

Actuellement, le MCP GitHub Projects ne supporte pas nativement le démarrage sur un port réseau via une simple configuration ou des arguments de ligne de commande. Son code source ([`mcps/internal/servers/github-projects-mcp/dist/index.js`](mcps/internal/servers/github-projects-mcp/dist/index.js:1)) utilise `StdioServerTransport` par défaut.

Pour permettre au MCP d'écouter sur un port réseau (par exemple, pour des tests qui l'exigent), il serait nécessaire de **modifier son code source** pour :
1.  Lire une variable d'environnement (ex: `MCP_PORT` ou `GITHUB_PROJECTS_MCP_PORT`).
2.  Si cette variable est définie, instancier un transport réseau (comme `HttpServerTransport` fourni par `@modelcontextprotocol/sdk`) au lieu de `StdioServerTransport`, en utilisant la valeur du port spécifiée.
3.  Mettre à jour la documentation en conséquence avec la nouvelle variable d'environnement et la commande de démarrage.

Sans ces modifications, les tests qui s'attendent à ce que le MCP écoute sur un port réseau (comme le port 3002) ne fonctionneront pas comme prévu si le MCP est lancé dans sa configuration actuelle. Les tests doivent être adaptés pour communiquer avec le MCP via son interface stdio, généralement en utilisant le MCP CLI comme le fait le script `test-github-projects.ps1`.

## Fonctionnalités testées

Le script `test-github-projects.ps1` teste les fonctionnalités suivantes du MCP GitHub Projects via le MCP CLI (communication en stdio) :

1. **list_projects** : Liste les projets d'un utilisateur ou d'une organisation
   - Vérifie que la liste des projets est récupérée correctement
   - Affiche les informations de base sur chaque projet

2. **get_project** : Obtient les détails d'un projet spécifique
   - Vérifie que les détails du projet sont récupérés correctement
   - Affiche les informations détaillées du projet, y compris ses champs

## Utilisation

1. Ouvrir PowerShell
2. Naviguer vers le répertoire contenant le script
3. Modifier les paramètres de test dans le script si nécessaire (propriétaire, type de propriétaire)
4. Exécuter le script :

```powershell
.\test-github-projects.ps1
```

## Interprétation des résultats

- Les messages avec le niveau "SUCCESS" indiquent que le test a réussi
- Les messages avec le niveau "WARNING" indiquent un problème potentiel
- Les messages avec le niveau "ERROR" indiquent un échec du test

## Dépannage

Si vous rencontrez des erreurs lors de l'exécution des tests :

1.  **Vérifiez que le MCP GitHub Projects est en cours d'exécution** (soit automatiquement par Roo, soit manuellement comme décrit ci-dessus).
2.  Vérifiez que le MCP GitHub Projects est correctement configuré (par exemple, les tokens d'accès si nécessaire, bien que la configuration actuelle via `dotenv` et potentiellement des fichiers `.env` soit à vérifier).
3.  Assurez-vous que le token GitHub utilisé (implicitement par le serveur) est valide et dispose des permissions nécessaires pour les opérations testées.
4.  Vérifiez que le propriétaire (utilisateur ou organisation) spécifié dans le script de test existe et possède des projets accessibles par le token.
5.  Vérifiez que le MCP CLI est correctement installé et accessible à l'emplacement spécifié dans le script de test.

## Notes

- Le script `test-github-projects.ps1` utilise le MCP CLI pour communiquer avec le MCP GitHub Projects. Le CLI gère la communication stdio avec le serveur MCP.
- Les résultats des tests sont affichés dans la console et peuvent être redirigés vers un fichier si nécessaire.