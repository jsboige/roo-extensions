# Utilisation du MCP GitHub

<!-- START_SECTION: introduction -->
## Introduction

Ce document détaille comment utiliser le MCP GitHub avec Roo. Le MCP GitHub permet à Roo d'interagir avec l'API GitHub pour gérer des dépôts, des issues, des pull requests et bien plus encore, directement depuis l'interface de conversation.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: available_tools -->
## Outils disponibles

Le MCP GitHub expose les outils suivants:

| Outil | Description |
|-------|-------------|
| `create_or_update_file` | Crée ou met à jour un fichier dans un dépôt |
| `search_repositories` | Recherche des dépôts GitHub |
| `create_repository` | Crée un nouveau dépôt dans votre compte |
| `get_file_contents` | Obtient le contenu d'un fichier ou d'un répertoire |
| `push_files` | Pousse plusieurs fichiers dans un dépôt en un seul commit |
| `create_issue` | Crée une nouvelle issue dans un dépôt |
| `create_pull_request` | Crée une pull request |
| `fork_repository` | Fork un dépôt vers votre compte |
| `create_branch` | Crée une nouvelle branche dans un dépôt |
| `list_commits` | Liste les commits d'une branche |
| `list_issues` | Liste les issues d'un dépôt |
| `update_issue` | Met à jour une issue existante |
| `add_issue_comment` | Ajoute un commentaire à une issue |
| `search_code` | Recherche du code dans les dépôts GitHub |
| `search_issues` | Recherche des issues et des pull requests |
| `search_users` | Recherche des utilisateurs GitHub |
| `get_issue` | Obtient les détails d'une issue spécifique |
| `get_pull_request` | Obtient les détails d'une pull request |
| `list_pull_requests` | Liste les pull requests d'un dépôt |
| `create_pull_request_review` | Crée une revue sur une pull request |
| `merge_pull_request` | Fusionne une pull request |
| `get_pull_request_files` | Obtient la liste des fichiers modifiés dans une pull request |
| `get_pull_request_status` | Obtient le statut des vérifications d'une pull request |
| `update_pull_request_branch` | Met à jour une branche de pull request |
| `get_pull_request_comments` | Obtient les commentaires d'une pull request |
| `get_pull_request_reviews` | Obtient les revues d'une pull request |
<!-- END_SECTION: available_tools -->

<!-- START_SECTION: repository_management -->
## Gestion des dépôts

### Rechercher des dépôts

Pour rechercher des dépôts sur GitHub:

```
Outil: search_repositories
Arguments:
{
  "query": "language:javascript stars:>1000"
}
```

Vous pouvez utiliser la [syntaxe de recherche GitHub](https://docs.github.com/en/search-github/searching-on-github/searching-for-repositories) pour affiner votre recherche.

### Créer un dépôt

Pour créer un nouveau dépôt dans votre compte:

```
Outil: create_repository
Arguments:
{
  "name": "mon-nouveau-projet",
  "description": "Un projet créé via le MCP GitHub",
  "private": true,
  "autoInit": true
}
```

### Forker un dépôt

Pour forker un dépôt existant vers votre compte:

```
Outil: fork_repository
Arguments:
{
  "owner": "octocat",
  "repo": "hello-world"
}
```

Pour forker vers une organisation:

```
Outil: fork_repository
Arguments:
{
  "owner": "octocat",
  "repo": "hello-world",
  "organization": "mon-organisation"
}
```
<!-- END_SECTION: repository_management -->

<!-- START_SECTION: file_management -->
## Gestion des fichiers

### Obtenir le contenu d'un fichier

Pour obtenir le contenu d'un fichier:

```
Outil: get_file_contents
Arguments:
{
  "owner": "octocat",
  "repo": "hello-world",
  "path": "README.md"
}
```

Pour obtenir le contenu d'un répertoire:

```
Outil: get_file_contents
Arguments:
{
  "owner": "octocat",
  "repo": "hello-world",
  "path": "src"
}
```

### Créer ou mettre à jour un fichier

Pour créer un nouveau fichier ou mettre à jour un fichier existant:

```
Outil: create_or_update_file
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "path": "docs/guide.md",
  "content": "# Guide d'utilisation\n\nCe guide explique comment utiliser notre projet.",
  "message": "Ajout du guide d'utilisation",
  "branch": "main"
}
```

Pour mettre à jour un fichier existant, vous devez également fournir le SHA du fichier:

```
Outil: create_or_update_file
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "path": "docs/guide.md",
  "content": "# Guide d'utilisation mis à jour\n\nCe guide explique comment utiliser notre projet.",
  "message": "Mise à jour du guide d'utilisation",
  "branch": "main",
  "sha": "abc123def456"
}
```

### Pousser plusieurs fichiers

Pour pousser plusieurs fichiers en un seul commit:

```
Outil: push_files
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "branch": "main",
  "message": "Ajout de plusieurs fichiers",
  "files": [
    {
      "path": "docs/guide.md",
      "content": "# Guide d'utilisation\n\nCe guide explique comment utiliser notre projet."
    },
    {
      "path": "docs/api.md",
      "content": "# Documentation API\n\nCette documentation décrit notre API."
    }
  ]
}
```
<!-- END_SECTION: file_management -->

<!-- START_SECTION: branch_management -->
## Gestion des branches

### Créer une branche

Pour créer une nouvelle branche:

```
Outil: create_branch
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "branch": "feature/nouvelle-fonctionnalite",
  "from_branch": "main"
}
```

### Lister les commits d'une branche

Pour lister les commits d'une branche:

```
Outil: list_commits
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "sha": "main"
}
```

Pour paginer les résultats:

```
Outil: list_commits
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "sha": "main",
  "page": 2,
  "perPage": 30
}
```
<!-- END_SECTION: branch_management -->

<!-- START_SECTION: issue_management -->
## Gestion des issues

### Créer une issue

Pour créer une nouvelle issue:

```
Outil: create_issue
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "title": "Bug dans la fonction de recherche",
  "body": "La fonction de recherche ne fonctionne pas correctement lorsqu'on utilise des caractères spéciaux."
}
```

Avec des assignés et des labels:

```
Outil: create_issue
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "title": "Bug dans la fonction de recherche",
  "body": "La fonction de recherche ne fonctionne pas correctement lorsqu'on utilise des caractères spéciaux.",
  "assignees": ["collaborateur1", "collaborateur2"],
  "labels": ["bug", "priority-high"]
}
```

### Lister les issues

Pour lister les issues d'un dépôt:

```
Outil: list_issues
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet"
}
```

Avec filtrage:

```
Outil: list_issues
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "state": "open",
  "labels": ["bug"],
  "sort": "created",
  "direction": "desc"
}
```

### Mettre à jour une issue

Pour mettre à jour une issue existante:

```
Outil: update_issue
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "issue_number": 42,
  "title": "Bug corrigé dans la fonction de recherche",
  "state": "closed"
}
```

### Ajouter un commentaire à une issue

Pour ajouter un commentaire à une issue:

```
Outil: add_issue_comment
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "issue_number": 42,
  "body": "J'ai identifié la cause du problème. Je vais proposer un correctif."
}
```

### Rechercher des issues

Pour rechercher des issues dans tous les dépôts:

```
Outil: search_issues
Arguments:
{
  "q": "is:issue is:open label:bug author:votre-nom-utilisateur"
}
```
<!-- END_SECTION: issue_management -->

<!-- START_SECTION: pull_request_management -->
## Gestion des pull requests

### Créer une pull request

Pour créer une nouvelle pull request:

```
Outil: create_pull_request
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "title": "Ajout de la fonctionnalité de recherche avancée",
  "body": "Cette PR ajoute une fonctionnalité de recherche avancée avec filtres.",
  "head": "feature/recherche-avancee",
  "base": "main"
}
```

Pour créer une pull request en mode brouillon:

```
Outil: create_pull_request
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "title": "WIP: Ajout de la fonctionnalité de recherche avancée",
  "body": "Cette PR est en cours de développement.",
  "head": "feature/recherche-avancee",
  "base": "main",
  "draft": true
}
```

### Lister les pull requests

Pour lister les pull requests d'un dépôt:

```
Outil: list_pull_requests
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet"
}
```

Avec filtrage:

```
Outil: list_pull_requests
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "state": "open",
  "sort": "updated",
  "direction": "desc"
}
```

### Obtenir les détails d'une pull request

Pour obtenir les détails d'une pull request:

```
Outil: get_pull_request
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "pull_number": 42
}
```

### Obtenir les fichiers modifiés dans une pull request

Pour obtenir la liste des fichiers modifiés dans une pull request:

```
Outil: get_pull_request_files
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "pull_number": 42
}
```

### Créer une revue sur une pull request

Pour créer une revue sur une pull request:

```
Outil: create_pull_request_review
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "pull_number": 42,
  "body": "Le code semble bon, mais il manque des tests.",
  "event": "COMMENT"
}
```

Pour approuver une pull request:

```
Outil: create_pull_request_review
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "pull_number": 42,
  "body": "Le code est bien écrit et les tests sont complets.",
  "event": "APPROVE"
}
```

Pour demander des modifications:

```
Outil: create_pull_request_review
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "pull_number": 42,
  "body": "Quelques problèmes à corriger avant de fusionner.",
  "event": "REQUEST_CHANGES",
  "comments": [
    {
      "path": "src/main.js",
      "line": 42,
      "body": "Cette fonction devrait gérer le cas où l'entrée est null."
    }
  ]
}
```

### Fusionner une pull request

Pour fusionner une pull request:

```
Outil: merge_pull_request
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "pull_number": 42,
  "commit_title": "Fusion de la fonctionnalité de recherche avancée",
  "merge_method": "merge"
}
```

Méthodes de fusion disponibles:
- `merge`: Crée un commit de fusion
- `squash`: Combine tous les commits en un seul
- `rebase`: Rebase les commits sur la branche de base
<!-- END_SECTION: pull_request_management -->

<!-- START_SECTION: search -->
## Recherche

### Rechercher du code

Pour rechercher du code dans les dépôts GitHub:

```
Outil: search_code
Arguments:
{
  "q": "function getUserData language:javascript repo:votre-nom-utilisateur/mon-projet"
}
```

### Rechercher des utilisateurs

Pour rechercher des utilisateurs GitHub:

```
Outil: search_users
Arguments:
{
  "q": "location:Paris language:javascript",
  "sort": "followers",
  "order": "desc"
}
```
<!-- END_SECTION: search -->

<!-- START_SECTION: use_cases -->
## Cas d'utilisation

### Création d'un nouveau projet

Pour créer un nouveau projet avec une structure de base:

1. Créer un nouveau dépôt:

```
Outil: create_repository
Arguments:
{
  "name": "mon-nouveau-projet",
  "description": "Un projet créé via le MCP GitHub",
  "private": true,
  "autoInit": true
}
```

2. Créer une branche de développement:

```
Outil: create_branch
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-nouveau-projet",
  "branch": "develop",
  "from_branch": "main"
}
```

3. Ajouter des fichiers de base:

```
Outil: push_files
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-nouveau-projet",
  "branch": "develop",
  "message": "Ajout de la structure de base du projet",
  "files": [
    {
      "path": "src/index.js",
      "content": "console.log('Hello, world!');"
    },
    {
      "path": "package.json",
      "content": "{\n  \"name\": \"mon-nouveau-projet\",\n  \"version\": \"1.0.0\",\n  \"description\": \"Un projet créé via le MCP GitHub\",\n  \"main\": \"src/index.js\",\n  \"scripts\": {\n    \"start\": \"node src/index.js\"\n  }\n}"
    },
    {
      "path": ".gitignore",
      "content": "node_modules/\n.env\n.DS_Store"
    }
  ]
}
```

### Gestion d'un bug

Pour gérer un bug signalé par un utilisateur:

1. Créer une issue pour le bug:

```
Outil: create_issue
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "title": "Bug dans la fonction de recherche",
  "body": "La fonction de recherche ne fonctionne pas correctement lorsqu'on utilise des caractères spéciaux.",
  "labels": ["bug", "priority-high"]
}
```

2. Créer une branche pour corriger le bug:

```
Outil: create_branch
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "branch": "fix/recherche-caracteres-speciaux",
  "from_branch": "main"
}
```

3. Mettre à jour le fichier contenant le bug:

```
Outil: create_or_update_file
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "path": "src/search.js",
  "content": "// Code corrigé pour gérer les caractères spéciaux",
  "message": "Correction du bug de recherche avec caractères spéciaux",
  "branch": "fix/recherche-caracteres-speciaux"
}
```

4. Créer une pull request:

```
Outil: create_pull_request
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "title": "Correction du bug de recherche avec caractères spéciaux",
  "body": "Cette PR corrige le bug signalé dans l'issue #42.\n\nFixes #42",
  "head": "fix/recherche-caracteres-speciaux",
  "base": "main"
}
```

### Revue de code collaborative

Pour faciliter une revue de code collaborative:

1. Obtenir les détails d'une pull request:

```
Outil: get_pull_request
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "pull_number": 42
}
```

2. Obtenir les fichiers modifiés:

```
Outil: get_pull_request_files
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "pull_number": 42
}
```

3. Examiner le contenu des fichiers modifiés:

```
Outil: get_file_contents
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "path": "src/search.js",
  "branch": "fix/recherche-caracteres-speciaux"
}
```

4. Ajouter des commentaires de revue:

```
Outil: create_pull_request_review
Arguments:
{
  "owner": "votre-nom-utilisateur",
  "repo": "mon-projet",
  "pull_number": 42,
  "body": "J'ai examiné les modifications et j'ai quelques suggestions.",
  "event": "COMMENT",
  "comments": [
    {
      "path": "src/search.js",
      "line": 42,
      "body": "Vous pourriez utiliser une expression régulière pour simplifier cette logique."
    }
  ]
}
```
<!-- END_SECTION: use_cases -->

<!-- START_SECTION: best_practices -->
## Bonnes pratiques

### Gestion des tokens

- **Utilisez des tokens avec les permissions minimales nécessaires**
- **Renouvelez régulièrement vos tokens**
- **Ne partagez jamais vos tokens**

### Messages de commit

- **Utilisez des messages de commit clairs et descriptifs**
- **Suivez une convention comme [Conventional Commits](https://www.conventionalcommits.org/)**
- **Référencez les issues dans les messages de commit avec `Fixes #42` ou `Closes #42`**

### Gestion des branches

- **Utilisez des branches pour isoler le développement de fonctionnalités**
- **Nommez les branches de manière descriptive (ex: `feature/search`, `bugfix/login-issue`)**
- **Fusionnez régulièrement la branche principale dans vos branches de fonctionnalités**
- **Supprimez les branches après leur fusion**

### Pull requests

- **Créez des pull requests de taille raisonnable**
- **Incluez une description claire de ce que fait la pull request**
- **Référencez les issues liées**
- **Demandez des revues à des collaborateurs pertinents**
- **Répondez aux commentaires de revue**

### Issues

- **Utilisez des titres clairs et descriptifs**
- **Incluez des étapes pour reproduire les bugs**
- **Utilisez des labels pour catégoriser les issues**
- **Assignez les issues aux personnes appropriées**
<!-- END_SECTION: best_practices -->

<!-- START_SECTION: error_handling -->
## Gestion des erreurs

Le MCP GitHub peut renvoyer différentes erreurs. Voici comment les gérer:

### Erreurs courantes

| Erreur | Description | Solution |
|--------|-------------|----------|
| `401 Unauthorized` | Token invalide ou expiré | Vérifiez ou renouvelez votre token |
| `403 Forbidden` | Permissions insuffisantes | Vérifiez les permissions de votre token |
| `404 Not Found` | Ressource non trouvée | Vérifiez le propriétaire, le dépôt ou le chemin |
| `422 Unprocessable Entity` | Données invalides | Vérifiez les arguments fournis |
| `429 Too Many Requests` | Limite de taux dépassée | Attendez avant de réessayer |

### Stratégies de gestion des erreurs

1. **Vérification préalable**:
   - Vérifiez l'existence des dépôts, branches, fichiers avant de les manipuler
   - Validez les données avant de les envoyer

2. **Gestion des limites de taux**:
   - Espacez les requêtes pour éviter de dépasser les limites
   - Utilisez un token authentifié pour bénéficier de limites plus élevées

3. **Récupération après erreur**:
   - En cas d'erreur, attendez et réessayez avec une stratégie de recul exponentiel
   - Enregistrez les opérations pour pouvoir les reprendre en cas d'échec
<!-- END_SECTION: error_handling -->

<!-- START_SECTION: integration_with_roo -->
## Intégration avec Roo

Le MCP GitHub s'intègre parfaitement avec Roo, permettant des interactions naturelles en langage courant. Voici quelques exemples de demandes que vous pouvez faire à Roo:

- "Crée un nouveau dépôt GitHub appelé mon-projet"
- "Recherche des dépôts JavaScript avec plus de 1000 étoiles"
- "Crée une issue dans mon-projet pour signaler un bug dans la fonction de recherche"
- "Crée une pull request pour fusionner ma branche feature/search dans main"
- "Montre-moi les derniers commits dans mon-projet"
- "Liste les issues ouvertes dans mon-projet avec le label bug"

Roo traduira automatiquement ces demandes en appels aux outils appropriés du MCP GitHub.
<!-- END_SECTION: integration_with_roo -->

<!-- START_SECTION: performance_optimization -->
## Optimisation des performances

### Minimiser les requêtes API

Pour éviter de dépasser les limites de taux de l'API GitHub:

- **Utilisez `push_files` au lieu de multiples `create_or_update_file`** pour pousser plusieurs fichiers en un seul commit
- **Utilisez les paramètres de pagination** pour récupérer uniquement les données nécessaires
- **Mettez en cache les résultats** lorsque c'est possible

### Optimisation des recherches

Pour optimiser les recherches:

- **Utilisez des requêtes de recherche spécifiques** pour limiter le nombre de résultats
- **Utilisez les qualificateurs de recherche** comme `language:`, `user:`, `repo:`, etc.
- **Limitez les résultats par page** avec les paramètres `page` et `perPage`

### Traitement par lots

Pour les opérations en masse:

- **Utilisez `push_files` pour pousser plusieurs fichiers** en un seul commit
- **Créez des issues ou des pull requests par lots** lorsque c'est possible
- **Utilisez des scripts GitHub Actions** pour les opérations répétitives
<!-- END_SECTION: performance_optimization -->

<!-- START_SECTION: security_considerations -->
## Considérations de sécurité

### Protection des tokens

- **Ne partagez jamais votre token** dans des dépôts publics, des messages, etc.
- **Utilisez des variables d'environnement** plutôt que d'inclure le token directement dans les fichiers de configuration
- **Stockez le token de manière sécurisée**, par exemple dans un gestionnaire de mots de passe ou un coffre-fort de secrets

### Limitation des permissions

- **Accordez uniquement les permissions nécessaires** à votre token
- **Évitez les permissions d'écriture** si vous n'avez besoin que de lire des données
- **Limitez l'accès aux dépôts** si possible, plutôt que d'accorder l'accès à tous les dépôts

### Validation des entrées

- **Validez toutes les entrées utilisateur** avant de les envoyer à l'API GitHub
- **Évitez d'exécuter du code arbitraire** provenant de sources non fiables
- **Échappez correctement les caractères spéciaux** dans les chaînes de recherche

### Audit et surveillance

- **Surveillez l'utilisation de votre token** pour détecter toute activité suspecte
- **Révoquez immédiatement les tokens compromis**
- **Examinez régulièrement les webhooks et les applications installées** sur vos dépôts
<!-- END_SECTION: security_considerations -->

<!-- START_SECTION: troubleshooting -->
## Résolution des problèmes

### Problèmes d'authentification

Si vous rencontrez des problèmes d'authentification:

1. **Vérifiez que votre token est valide**:
   ```bash
   curl -H "Authorization: token votre_token_github" https://api.github.com/user
   ```

2. **Vérifiez les permissions de votre token** dans les paramètres de votre compte GitHub

3. **Renouvelez votre token** si nécessaire

### Problèmes de limites de taux

Si vous atteignez les limites de taux de l'API GitHub:

1. **Vérifiez votre statut de limite de taux**:
   ```bash
   curl -H "Authorization: token votre_token_github" https://api.github.com/rate_limit
   ```

2. **Utilisez un token authentifié** pour bénéficier de limites plus élevées

3. **Espacez vos requêtes** ou utilisez une stratégie de recul exponentiel

Pour plus de détails sur la résolution des problèmes, consultez le fichier [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).
<!-- END_SECTION: troubleshooting -->