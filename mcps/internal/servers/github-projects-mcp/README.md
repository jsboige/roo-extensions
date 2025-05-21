# MCP Gestionnaire de Projet pour GitHub Projects

Ce MCP (Model Context Protocol) permet d'intégrer GitHub Projects avec VSCode Roo, offrant une interface pour interagir avec les projets GitHub directement depuis Roo.

## Fonctionnalités

- Lister les projets d'un utilisateur ou d'une organisation
- Créer de nouveaux projets
- Obtenir les détails d'un projet spécifique
- Ajouter des éléments (issues, pull requests, notes) à un projet
- Mettre à jour les champs des éléments dans un projet

## Prérequis

- Node.js 14.x ou supérieur
- npm 6.x ou supérieur
- Un token d'accès personnel GitHub avec les permissions nécessaires pour GitHub Projects

## Installation

1. Le MCP GitHub Projects est déjà intégré dans le sous-module `mcps/mcp-servers`.

2. Installez les dépendances :
   ```bash
   cd mcps/mcp-servers/servers/github-projects-mcp
   npm install
   ```

3. Créez un fichier `.env` à partir du modèle `.env.example` :
   ```bash
   cp .env.example .env
   ```

4. Modifiez le fichier `.env` pour ajouter votre token GitHub :
   ```
   GITHUB_TOKEN=votre_token_github_ici
   ```

5. Compilez le projet :
   ```bash
   npm run build
   ```

## Configuration dans Roo

Pour utiliser ce MCP avec Roo, ajoutez la configuration suivante à votre fichier `servers.json` :

```json
{
  "servers": [
    {
      "name": "github-projects",
      "command": "cmd /c \"cd /d %~dp0\\..\\mcps\\mcp-servers\\servers\\github-projects-mcp && run-github-projects.bat\"",
      "autostart": true
    }
  ]
}
```

Vous pouvez également utiliser le script batch fourni :
```
mcps/mcp-servers/servers/github-projects-mcp/run-github-projects.bat
```

## Utilisation

Une fois le MCP configuré et démarré, vous pouvez l'utiliser dans vos conversations avec Roo. Voici quelques exemples d'utilisation :

### Lister les projets d'un utilisateur

```
Utilisateur: Peux-tu me lister mes projets GitHub?

Roo: Je vais lister vos projets GitHub.
[Utilisation de l'outil github-projects.list_projects]
Voici la liste de vos projets GitHub...
```

### Créer un nouveau projet

```
Utilisateur: Crée un nouveau projet GitHub pour mon application web.

Roo: Je vais créer un nouveau projet pour vous.
[Utilisation de l'outil github-projects.create_project]
J'ai créé un nouveau projet intitulé "Application Web"...
```

### Obtenir les détails d'un projet

```
Utilisateur: Montre-moi les détails de mon projet numéro 1.

Roo: Je vais récupérer les détails de ce projet.
[Utilisation de l'outil github-projects.get_project]
Voici les détails du projet...
```

### Ajouter une issue à un projet

```
Utilisateur: Ajoute l'issue #42 à mon projet "Application Web".

Roo: Je vais ajouter cette issue à votre projet.
[Utilisation de l'outil github-projects.add_item_to_project]
J'ai ajouté l'issue #42 à votre projet...
```

## Outils disponibles

### list_projects

Liste les projets GitHub d'un utilisateur ou d'une organisation.

**Paramètres :**
- `owner` : Nom d'utilisateur ou d'organisation
- `type` : Type de propriétaire (`user` ou `org`, par défaut : `user`)
- `state` : État des projets à récupérer (`open`, `closed` ou `all`, par défaut : `open`)

### create_project

Crée un nouveau projet GitHub.

**Paramètres :**
- `owner` : Nom d'utilisateur ou d'organisation
- `title` : Titre du projet
- `description` : Description du projet (optionnel)
- `type` : Type de propriétaire (`user` ou `org`, par défaut : `user`)

### get_project

Récupère les détails d'un projet GitHub.

**Paramètres :**
- `owner` : Nom d'utilisateur ou d'organisation
- `project_number` : Numéro du projet

### add_item_to_project

Ajoute un élément (issue, pull request ou note) à un projet GitHub.

**Paramètres :**
- `project_id` : ID du projet
- `content_id` : ID de l'élément à ajouter (issue ou pull request)
- `content_type` : Type de contenu à ajouter (`issue`, `pull_request` ou `draft_issue`, par défaut : `issue`)
- `draft_title` : Titre de la note (uniquement pour les notes)
- `draft_body` : Corps de la note (uniquement pour les notes)

### update_project_item_field

Met à jour la valeur d'un champ pour un élément dans un projet GitHub.

**Paramètres :**
- `project_id` : ID du projet
- `item_id` : ID de l'élément dans le projet
- `field_id` : ID du champ à mettre à jour
- `field_type` : Type de champ (`text`, `date`, `single_select` ou `number`)
- `value` : Nouvelle valeur pour le champ
- `option_id` : ID de l'option pour les champs de type `single_select`

## Ressources disponibles

### projects

Accès aux projets GitHub d'un utilisateur ou d'une organisation.

**URI Schema :** `github-projects://{owner}/{type}?state={state}`

### project

Accès à un projet GitHub spécifique.

**URI Schema :** `github-project://{owner}/{project_number}`

## Dépannage

Si vous rencontrez des problèmes avec ce MCP, vérifiez les points suivants :

1. Assurez-vous que votre token GitHub est valide et dispose des permissions nécessaires.
2. Vérifiez que le MCP est correctement configuré dans `servers.json`.
3. Consultez les logs du serveur MCP pour plus d'informations sur les erreurs.

## Développement

### Structure du projet

```
mcps/mcp-servers/servers/github-projects-mcp/
├── src/
│   ├── index.ts           # Point d'entrée du serveur MCP
│   ├── tools.ts           # Définition des outils MCP
│   ├── resources.ts       # Définition des ressources MCP
│   └── utils/
│       ├── github.ts      # Fonctions utilitaires pour l'API GitHub
│       └── errorHandlers.ts # Gestionnaires d'erreurs
├── docs/                  # Documentation supplémentaire
├── .env.example           # Modèle de fichier d'environnement
├── package.json           # Dépendances et scripts
├── tsconfig.json          # Configuration TypeScript
├── run-github-projects.bat # Script de démarrage
└── README.md              # Documentation
```

### Scripts disponibles

- `npm run build` : Compile le projet
- `npm run start` : Démarre le serveur MCP
- `npm run dev` : Démarre le serveur en mode développement
- `npm run test` : Exécute les tests

## Licence

MIT