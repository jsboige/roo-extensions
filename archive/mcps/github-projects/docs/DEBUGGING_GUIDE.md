# Guide de Débogage pour les Problèmes d'Authentification du MCP `github-projects`

Ce document décrit la cause racine et la solution pour un problème d'authentification récurrent qui se manifestait par des erreurs de `rate limit` de l'API GitHub.

## 1. Symptômes

- Les appels aux outils du MCP `github-projects` (ex: `list_projects`) échouent avec une erreur du type `API rate limit exceeded`.
- L'erreur se produit même si un token GitHub semble correctement configuré dans `mcp_settings.json` ou dans le fichier `.env`.

## 2. Cause Racine

Le problème fondamental provenait de la manière dont les variables d'environnement (contenant le token GitHub) étaient configurées et interprétées.

Le serveur MCP, lors de la lecture de sa configuration, recevait la chaîne de caractères **littérale** de la variable d'environnement (ex: `"${env:GITHUB_TOKEN}"`) au lieu de sa **valeur résolue** (ex: `"ghp_..."`).

Par conséquent, le client Octokit était instancié avec un token invalide. Il effectuait alors des requêtes non authentifiées auprès de l'API GitHub. Ces requêtes sont soumises à des limites de taux très basses (environ 60 par heure), qui étaient rapidement épuisées, provoquant l'erreur observée.

Ce comportement pouvait être masqué par le fait que le code contenait une logique pour gérer plusieurs comptes, mais cette logique était inopérante si le tableau de comptes initial était populé avec des tokens non résolus.

## 3. Solution Apportée

Une correction a été implémentée dans la fonction `getGitHubClient` du fichier `src/utils/github.ts` pour rendre le serveur plus robuste face à ce problème de configuration.

La nouvelle logique inspecte le token reçu. Si le token ressemble à une chaîne de substitution de variable d'environnement (ex: `${env:NOM_VARIABLE}`), le code tente de résoudre cette variable en lisant `process.env[NOM_VARIABLE]`.

**Avantages de cette approche :**
1.  **Résilience :** Le serveur peut désormais fonctionner même si la substitution de variable n'a pas été correctement effectuée en amont.
2.  **Erreurs Claires :** Si une variable d'environnement est référencée mais n'est pas définie, le serveur lève maintenant une erreur de configuration explicite au lieu de continuer avec un token invalide. Cela facilite grandement le diagnostic.

## 4. Comment Prévenir ce Problème

Pour assurer une configuration correcte :

1.  **Privilégier le fichier `.env` :** La méthode la plus fiable est de définir les tokens directement dans un fichier `.env` à la racine du serveur MCP (`mcps/internal/servers/github-projects-mcp/.env`). Le serveur est configuré pour charger ce fichier au démarrage.
2.  **Vérifier les variables d'environnement :** Si vous utilisez `mcp_settings.json` pour définir les tokens via des variables, assurez-vous que ces variables sont bien présentes et accessibles dans l'environnement d'exécution de l'agent Roo / VS Code.
