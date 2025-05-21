# Analyse technique du MCP GitHub Projects

## Architecture du serveur

Le MCP GitHub Projects est un serveur qui implémente le protocole Model Context Protocol (MCP) pour permettre l'intégration des projets GitHub avec VSCode Roo. Il est écrit en TypeScript et utilise l'API GraphQL de GitHub pour interagir avec les projets GitHub.

### Structure du code

Le serveur est organisé en plusieurs fichiers :

- `index.ts` : Point d'entrée du serveur, configure et démarre le serveur MCP
- `types.ts` : Définit les interfaces et classes pour le serveur MCP
- `tools.ts` : Définit les outils MCP exposés par le serveur
- `resources.ts` : Définit les ressources MCP exposées par le serveur
- `utils/github.ts` : Fonctions utilitaires pour interagir avec l'API GitHub
- `utils/errorHandlers.ts` : Fonctions et classes pour gérer les erreurs

### Outils MCP

Le serveur expose les outils MCP suivants :

1. `list_projects` : Liste les projets GitHub d'un utilisateur ou d'une organisation
2. `create_project` : Crée un nouveau projet GitHub
3. `get_project` : Récupère les détails d'un projet GitHub
4. `add_item_to_project` : Ajoute un élément (issue, pull request ou note) à un projet GitHub
5. `update_project_item_field` : Met à jour la valeur d'un champ pour un élément dans un projet GitHub

### Ressources MCP

Le serveur expose les ressources MCP suivantes :

1. `projects` : Accès aux projets GitHub d'un utilisateur ou d'une organisation
   - URI Schema : `github-projects://{owner}/{type}?state={state}`
2. `project` : Accès à un projet GitHub spécifique
   - URI Schema : `github-project://{owner}/{project_number}`

## Configuration

Le serveur est configuré via des variables d'environnement :

- `GITHUB_TOKEN` : Token d'authentification GitHub
- `MCP_PORT` : Port sur lequel le serveur écoute (par défaut : 3000)
- `MCP_HOST` : Hôte sur lequel le serveur écoute (par défaut : localhost)

Ces variables peuvent être définies dans un fichier `.env` ou directement dans l'environnement.

## Problèmes identifiés lors des tests

### 1. Conflit de port

Le port 3000 est utilisé par un autre serveur (Open WebUI), ce qui empêche le MCP GitHub Projects de fonctionner correctement. Lors des tests, nous avons constaté que le serveur qui écoute sur le port 3000 n'est pas le serveur MCP GitHub Projects, mais un autre serveur qui renvoie du HTML.

### 2. Problèmes d'authentification

Le token GitHub est configuré dans le fichier `mcp_settings.json`, mais il n'est pas correctement transmis au serveur MCP GitHub Projects. Lors du démarrage du serveur, un avertissement est affiché :

```
AVERTISSEMENT: Token GitHub non défini. Les requêtes seront limitées et certaines fonctionnalités ne seront pas disponibles.
```

### 3. Problèmes de communication

Les tentatives de communication avec le serveur MCP GitHub Projects via curl et Invoke-RestMethod ont échoué avec des erreurs "Method Not Allowed". Cela suggère que le serveur qui écoute sur le port 3000 n'est pas configuré pour accepter les requêtes MCP.

### 4. MCP CLI non disponible

L'outil MCP CLI n'a pas été trouvé à l'emplacement attendu (`C:\Users\MYIA\AppData\Local\Programs\Roo\resources\app\out\mcp-cli\mcp-cli.exe`), ce qui limite les possibilités de test.

## Recommandations

### 1. Résoudre le conflit de port

- Arrêter le serveur Open WebUI qui utilise actuellement le port 3000
- Configurer le MCP GitHub Projects pour utiliser un port différent dans le fichier `mcp_settings.json`
- Redémarrer le serveur MCP GitHub Projects

### 2. Corriger la configuration du token GitHub

- Vérifier que le token GitHub est correctement défini dans le fichier `.env` du serveur MCP GitHub Projects
- S'assurer que le token a les permissions nécessaires pour accéder aux projets GitHub

### 3. Vérifier l'installation du MCP CLI

- Vérifier l'installation de Roo pour s'assurer que le MCP CLI est correctement installé
- Rechercher le MCP CLI dans d'autres emplacements potentiels
- Réinstaller le MCP CLI si nécessaire

### 4. Tester avec une approche alternative

- Utiliser directement l'API GitHub pour accéder aux projets, sans passer par le MCP
- Créer un script PowerShell qui utilise l'API GitHub directement avec le token configuré

## Conclusion

Le MCP GitHub Projects est correctement configuré dans le fichier `mcp_settings.json`, mais des problèmes empêchent son fonctionnement normal. Les principales causes semblent être un conflit de port avec un autre serveur, des problèmes d'authentification et l'absence de l'outil MCP CLI. En résolvant ces problèmes, il devrait être possible de faire fonctionner correctement le MCP GitHub Projects.