# Guide d'utilisation du MCP GitHub Projects avec Roo

Ce guide explique comment installer, configurer et utiliser le MCP GitHub Projects avec VSCode Roo pour interagir avec les projets GitHub.

## Prérequis

- VSCode avec l'extension Roo installée
- Node.js (version 14 ou supérieure)
- Un compte GitHub avec des projets
- Un token GitHub avec les permissions nécessaires

## Installation

1. **Vérifiez que le MCP GitHub Projects est installé**

   Le MCP GitHub Projects devrait être installé dans le répertoire suivant :
   ```
   D:\roo-extensions\mcps\internal\servers\github-projects-mcp
   ```

   Si ce n'est pas le cas, vous pouvez le cloner depuis le dépôt GitHub ou le télécharger depuis le site officiel.

2. **Installez les dépendances**

   Ouvrez un terminal et naviguez vers le répertoire du MCP GitHub Projects :
   ```
   cd D:\roo-extensions\mcps\internal\servers\github-projects-mcp
   ```

   Installez les dépendances :
   ```
   npm install
   ```

3. **Compilez le serveur**

   Compilez le serveur pour générer les fichiers JavaScript dans le dossier `dist/` :
   ```
   npm run build
   ```

## Configuration

1. **Créez un token GitHub**

   - Allez sur [GitHub Developer Settings](https://github.com/settings/tokens)
   - Cliquez sur "Generate new token"
   - Donnez un nom à votre token (par exemple, "Roo MCP GitHub Projects")
   - Sélectionnez les permissions suivantes :
     - `repo` (accès complet aux dépôts)
     - `project` (accès complet aux projets)
   - Cliquez sur "Generate token"
   - Copiez le token généré (vous ne pourrez plus le voir après avoir quitté la page)

2. **Configurez le token GitHub**

   Créez un fichier `.env` dans le répertoire du MCP GitHub Projects avec le contenu suivant :
   ```
   GITHUB_TOKEN=votre_token_github
   ```

   Remplacez `votre_token_github` par le token que vous avez généré.

3. **Configurez le MCP dans Roo**

   Ouvrez VSCode et accédez aux paramètres de Roo :
   - Ouvrez la palette de commandes (Ctrl+Shift+P)
   - Tapez "Roo: Open Settings" et sélectionnez cette option

   Dans le fichier `mcp_settings.json`, ajoutez ou modifiez la configuration du MCP GitHub Projects :
   ```json
   {
     "mcpServers": {
       "github-projects": {
         "command": "node D:\\roo-extensions\\mcps\\internal\\servers\\github-projects-mcp\\dist\\index.js",
         "env": {
           "GITHUB_TOKEN": "votre_token_github"
         },
         "autoStart": true,
         "enabled": true
       }
     }
   }
   ```

   Remplacez `votre_token_github` par le token que vous avez généré.

4. **Synchronisez le token GitHub**

   Pour vous assurer que le token GitHub est correctement configuré, exécutez le script de synchronisation :
   ```
   node D:\roo-extensions\mcps\tests\github-projects\fix-github-token.js
   ```

   Ce script copie le token GitHub depuis la configuration de Roo vers le fichier `.env` du serveur MCP GitHub Projects.

## Utilisation

Le MCP GitHub Projects fournit plusieurs outils pour interagir avec les projets GitHub depuis Roo. Voici comment les utiliser :

### 1. Lister les projets GitHub

Pour lister les projets GitHub d'un utilisateur ou d'une organisation, utilisez l'outil `list_projects` :

```
Utilisez l'outil MCP "list_projects" du serveur "github-projects" avec les arguments suivants :
{
  "owner": "nom_utilisateur",
  "type": "user",
  "state": "open"
}
```

Remplacez `nom_utilisateur` par votre nom d'utilisateur GitHub ou le nom de l'organisation.

Options disponibles :
- `type` : `user` (utilisateur) ou `org` (organisation)
- `state` : `open`, `closed` ou `all`

### 2. Obtenir les détails d'un projet

Pour obtenir les détails d'un projet spécifique, utilisez l'outil `get_project` :

```
Utilisez l'outil MCP "get_project" du serveur "github-projects" avec les arguments suivants :
{
  "owner": "nom_utilisateur",
  "project_number": 1
}
```

Remplacez `nom_utilisateur` par votre nom d'utilisateur GitHub ou le nom de l'organisation, et `project_number` par le numéro du projet.

### 3. Ajouter un élément à un projet

Pour ajouter un élément (issue, pull request ou note) à un projet, utilisez l'outil `add_item_to_project` :

```
Utilisez l'outil MCP "add_item_to_project" du serveur "github-projects" avec les arguments suivants :
{
  "project_id": "id_projet",
  "content_id": "id_element",
  "content_type": "issue"
}
```

Options disponibles pour `content_type` :
- `issue` : pour ajouter une issue
- `pull_request` : pour ajouter une pull request
- `draft_issue` : pour ajouter une note

Pour ajouter une note, utilisez les paramètres `draft_title` et `draft_body` au lieu de `content_id` :

```
{
  "project_id": "id_projet",
  "content_type": "draft_issue",
  "draft_title": "Titre de la note",
  "draft_body": "Corps de la note"
}
```

### 4. Mettre à jour un champ d'un élément

Pour mettre à jour la valeur d'un champ pour un élément dans un projet, utilisez l'outil `update_project_item_field` :

```
Utilisez l'outil MCP "update_project_item_field" du serveur "github-projects" avec les arguments suivants :
{
  "project_id": "id_projet",
  "item_id": "id_element",
  "field_id": "id_champ",
  "field_type": "text",
  "value": "nouvelle_valeur"
}
```

Options disponibles pour `field_type` :
- `text` : pour les champs de texte
- `date` : pour les champs de date
- `single_select` : pour les champs de sélection unique
- `number` : pour les champs numériques

Pour les champs de type `single_select`, vous pouvez utiliser le paramètre `option_id` au lieu de `value` :

```
{
  "project_id": "id_projet",
  "item_id": "id_element",
  "field_id": "id_champ",
  "field_type": "single_select",
  "option_id": "id_option"
}
```

## Dépannage

### Le serveur affiche "Token GitHub non défini"

Si le serveur affiche un avertissement indiquant que le token GitHub n'est pas défini, vérifiez que :
1. Le token GitHub est correctement configuré dans le fichier `.env`
2. Le token GitHub est correctement configuré dans le fichier `mcp_settings.json`
3. Le serveur a été redémarré après la modification du fichier `.env`

Vous pouvez exécuter le script de synchronisation pour vous assurer que le token est correctement configuré :
```
node D:\roo-extensions\mcps\tests\github-projects\fix-github-token.js
```

### Erreurs de parsing JSON

Si vous rencontrez des erreurs de parsing JSON lors de l'utilisation des outils MCP, vous pouvez utiliser l'utilitaire de filtrage JSON pour traiter les réponses :

```javascript
const { parseJsonWithFiltering } = require('./utils/json-utils');
const jsonString = '...'; // Votre chaîne JSON avec des messages non-JSON
const jsonObject = parseJsonWithFiltering(jsonString);
```

### Méthodes non reconnues

Si vous rencontrez des erreurs indiquant que les méthodes ne sont pas reconnues, vérifiez que vous utilisez les bonnes méthodes pour interagir avec le serveur. Le MCP GitHub Projects utilise le protocole MCP standard, qui inclut les méthodes suivantes :
- `mcp/list-tools`
- `mcp/list-resources`
- `mcp/invoke-tool`
- `mcp/access-resource`

## Ressources supplémentaires

- [Documentation de l'API GitHub Projects](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-api-to-manage-projects)
- [Documentation du protocole MCP](https://github.com/microsoft/modelcontextprotocol)
- [Documentation de Roo](https://github.com/rooveterinaryinc/roo-cline)

## Support

Si vous rencontrez des problèmes avec le MCP GitHub Projects, vous pouvez :
1. Consulter les rapports de test dans le répertoire `D:\roo-extensions\mcps\tests\github-projects\`
2. Exécuter les scripts de test pour vérifier que le serveur fonctionne correctement
3. Contacter l'équipe de support de Roo pour obtenir de l'aide