# Utilisation du MCP Git

<!-- START_SECTION: introduction -->
## Introduction

Ce document détaille comment utiliser le MCP Git avec Roo. Le MCP Git permet à Roo d'interagir avec des dépôts Git locaux et distants pour effectuer des opérations comme l'initialisation de dépôts, la gestion des commits, des branches, des tags, et bien plus encore.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: available_tools -->
## Outils disponibles

Le MCP Git expose les outils suivants:

| Outil | Description |
|-------|-------------|
| `init` | Initialise un nouveau dépôt Git |
| `clone` | Clone un dépôt existant |
| `status` | Obtient l'état du dépôt |
| `add` | Ajoute des fichiers à l'index |
| `commit` | Crée un commit |
| `push` | Pousse les commits vers un dépôt distant |
| `pull` | Récupère les modifications d'un dépôt distant |
| `branch_list` | Liste les branches |
| `branch_create` | Crée une nouvelle branche |
| `branch_delete` | Supprime une branche |
| `checkout` | Change de branche ou restaure des fichiers |
| `tag_list` | Liste les tags |
| `tag_create` | Crée un tag |
| `tag_delete` | Supprime un tag |
| `remote_list` | Liste les dépôts distants |
| `remote_add` | Ajoute un dépôt distant |
| `remote_remove` | Supprime un dépôt distant |
| `stash_list` | Liste les stash |
| `stash_save` | Sauvegarde les modifications dans un stash |
| `stash_pop` | Applique et supprime un stash |
| `bulk_action` | Exécute plusieurs opérations Git en séquence |
<!-- END_SECTION: available_tools -->

<!-- START_SECTION: basic_usage -->
## Utilisation de base

### Initialiser un dépôt

Pour initialiser un nouveau dépôt Git:

```
Outil: init
Arguments:
{
  "path": "/chemin/vers/nouveau/depot"
}
```

### Cloner un dépôt

Pour cloner un dépôt existant:

```
Outil: clone
Arguments:
{
  "url": "https://github.com/utilisateur/depot.git",
  "path": "/chemin/vers/destination"
}
```

### Vérifier l'état du dépôt

Pour obtenir l'état actuel d'un dépôt:

```
Outil: status
Arguments:
{
  "path": "/chemin/vers/depot"
}
```

### Ajouter des fichiers à l'index

Pour ajouter des fichiers à l'index Git:

```
Outil: add
Arguments:
{
  "path": "/chemin/vers/depot",
  "files": [
    "/chemin/vers/depot/fichier1.txt",
    "/chemin/vers/depot/fichier2.txt"
  ]
}
```

### Créer un commit

Pour créer un nouveau commit:

```
Outil: commit
Arguments:
{
  "path": "/chemin/vers/depot",
  "message": "Ajout de nouvelles fonctionnalités"
}
```

### Pousser des commits vers un dépôt distant

Pour pousser des commits vers un dépôt distant:

```
Outil: push
Arguments:
{
  "path": "/chemin/vers/depot",
  "remote": "origin",
  "branch": "main"
}
```

### Récupérer des modifications d'un dépôt distant

Pour récupérer des modifications d'un dépôt distant:

```
Outil: pull
Arguments:
{
  "path": "/chemin/vers/depot",
  "remote": "origin",
  "branch": "main"
}
```
<!-- END_SECTION: basic_usage -->

<!-- START_SECTION: branch_management -->
## Gestion des branches

### Lister les branches

Pour lister toutes les branches d'un dépôt:

```
Outil: branch_list
Arguments:
{
  "path": "/chemin/vers/depot"
}
```

### Créer une nouvelle branche

Pour créer une nouvelle branche:

```
Outil: branch_create
Arguments:
{
  "path": "/chemin/vers/depot",
  "name": "nouvelle-fonctionnalite",
  "force": false,
  "track": true
}
```

### Supprimer une branche

Pour supprimer une branche:

```
Outil: branch_delete
Arguments:
{
  "path": "/chemin/vers/depot",
  "name": "ancienne-fonctionnalite"
}
```

### Changer de branche

Pour basculer vers une autre branche:

```
Outil: checkout
Arguments:
{
  "path": "/chemin/vers/depot",
  "target": "autre-branche"
}
```
<!-- END_SECTION: branch_management -->

<!-- START_SECTION: tag_management -->
## Gestion des tags

### Lister les tags

Pour lister tous les tags d'un dépôt:

```
Outil: tag_list
Arguments:
{
  "path": "/chemin/vers/depot"
}
```

### Créer un tag

Pour créer un nouveau tag:

```
Outil: tag_create
Arguments:
{
  "path": "/chemin/vers/depot",
  "name": "v1.0.0",
  "message": "Version 1.0.0",
  "annotated": true
}
```

### Supprimer un tag

Pour supprimer un tag:

```
Outil: tag_delete
Arguments:
{
  "path": "/chemin/vers/depot",
  "name": "v0.9.0"
}
```
<!-- END_SECTION: tag_management -->

<!-- START_SECTION: remote_management -->
## Gestion des dépôts distants

### Lister les dépôts distants

Pour lister tous les dépôts distants:

```
Outil: remote_list
Arguments:
{
  "path": "/chemin/vers/depot"
}
```

### Ajouter un dépôt distant

Pour ajouter un nouveau dépôt distant:

```
Outil: remote_add
Arguments:
{
  "path": "/chemin/vers/depot",
  "name": "upstream",
  "url": "https://github.com/organisation/depot.git"
}
```

### Supprimer un dépôt distant

Pour supprimer un dépôt distant:

```
Outil: remote_remove
Arguments:
{
  "path": "/chemin/vers/depot",
  "name": "upstream"
}
```
<!-- END_SECTION: remote_management -->

<!-- START_SECTION: stash_management -->
## Gestion des stash

### Lister les stash

Pour lister tous les stash:

```
Outil: stash_list
Arguments:
{
  "path": "/chemin/vers/depot"
}
```

### Sauvegarder des modifications dans un stash

Pour sauvegarder des modifications dans un stash:

```
Outil: stash_save
Arguments:
{
  "path": "/chemin/vers/depot",
  "message": "Modifications en cours",
  "includeUntracked": true
}
```

### Appliquer et supprimer un stash

Pour appliquer et supprimer un stash:

```
Outil: stash_pop
Arguments:
{
  "path": "/chemin/vers/depot",
  "index": 0
}
```
<!-- END_SECTION: stash_management -->

<!-- START_SECTION: bulk_actions -->
## Actions en masse

Le MCP Git permet d'exécuter plusieurs opérations Git en séquence avec l'outil `bulk_action`. C'est particulièrement utile pour des workflows courants comme "stage, commit, push".

### Exemple: Stage et commit

Pour ajouter des fichiers à l'index et créer un commit en une seule opération:

```
Outil: bulk_action
Arguments:
{
  "path": "/chemin/vers/depot",
  "actions": [
    {
      "type": "stage",
      "files": [
        "/chemin/vers/depot/fichier1.txt",
        "/chemin/vers/depot/fichier2.txt"
      ]
    },
    {
      "type": "commit",
      "message": "Ajout de nouvelles fonctionnalités"
    }
  ]
}
```

### Exemple: Stage, commit et push

Pour ajouter des fichiers, créer un commit et pousser vers un dépôt distant en une seule opération:

```
Outil: bulk_action
Arguments:
{
  "path": "/chemin/vers/depot",
  "actions": [
    {
      "type": "stage",
      "files": [
        "/chemin/vers/depot/fichier1.txt",
        "/chemin/vers/depot/fichier2.txt"
      ]
    },
    {
      "type": "commit",
      "message": "Ajout de nouvelles fonctionnalités"
    },
    {
      "type": "push",
      "remote": "origin",
      "branch": "main"
    }
  ]
}
```

### Exemple: Stage tous les fichiers modifiés

Pour ajouter tous les fichiers modifiés à l'index:

```
Outil: bulk_action
Arguments:
{
  "path": "/chemin/vers/depot",
  "actions": [
    {
      "type": "stage"
    }
  ]
}
```
<!-- END_SECTION: bulk_actions -->

<!-- START_SECTION: use_cases -->
## Cas d'utilisation

### Initialisation d'un nouveau projet

Pour initialiser un nouveau projet avec Git:

1. Créer un nouveau dépôt:

```
Outil: init
Arguments:
{
  "path": "/chemin/vers/nouveau/projet"
}
```

2. Ajouter un fichier README:

```
# Utiliser un autre MCP comme le MCP Filesystem pour créer le fichier README.md
```

3. Ajouter le fichier à l'index et créer un commit:

```
Outil: bulk_action
Arguments:
{
  "path": "/chemin/vers/nouveau/projet",
  "actions": [
    {
      "type": "stage",
      "files": [
        "/chemin/vers/nouveau/projet/README.md"
      ]
    },
    {
      "type": "commit",
      "message": "Initial commit"
    }
  ]
}
```

4. Ajouter un dépôt distant et pousser:

```
Outil: remote_add
Arguments:
{
  "path": "/chemin/vers/nouveau/projet",
  "name": "origin",
  "url": "https://github.com/utilisateur/nouveau-projet.git"
}
```

```
Outil: push
Arguments:
{
  "path": "/chemin/vers/nouveau/projet",
  "remote": "origin",
  "branch": "main"
}
```

### Développement de fonctionnalités

Pour développer une nouvelle fonctionnalité:

1. Créer une nouvelle branche:

```
Outil: branch_create
Arguments:
{
  "path": "/chemin/vers/depot",
  "name": "nouvelle-fonctionnalite"
}
```

2. Basculer vers la nouvelle branche:

```
Outil: checkout
Arguments:
{
  "path": "/chemin/vers/depot",
  "target": "nouvelle-fonctionnalite"
}
```

3. Développer la fonctionnalité (ajouter/modifier des fichiers)

4. Ajouter les modifications, créer un commit et pousser:

```
Outil: bulk_action
Arguments:
{
  "path": "/chemin/vers/depot",
  "actions": [
    {
      "type": "stage"
    },
    {
      "type": "commit",
      "message": "Implémentation de la nouvelle fonctionnalité"
    },
    {
      "type": "push",
      "remote": "origin",
      "branch": "nouvelle-fonctionnalite"
    }
  ]
}
```

### Gestion des versions

Pour créer une nouvelle version:

1. S'assurer d'être sur la branche principale:

```
Outil: checkout
Arguments:
{
  "path": "/chemin/vers/depot",
  "target": "main"
}
```

2. Créer un tag pour la nouvelle version:

```
Outil: tag_create
Arguments:
{
  "path": "/chemin/vers/depot",
  "name": "v1.0.0",
  "message": "Version 1.0.0",
  "annotated": true
}
```

3. Pousser le tag vers le dépôt distant:

```
Outil: push
Arguments:
{
  "path": "/chemin/vers/depot",
  "remote": "origin",
  "branch": "main",
  "tags": true
}
```
<!-- END_SECTION: use_cases -->

<!-- START_SECTION: best_practices -->
## Bonnes pratiques

### Messages de commit

- Utilisez des messages de commit clairs et descriptifs
- Suivez une convention comme [Conventional Commits](https://www.conventionalcommits.org/)
- Incluez un résumé concis sur la première ligne
- Ajoutez des détails supplémentaires après une ligne vide

Exemple:
```
Outil: commit
Arguments:
{
  "path": "/chemin/vers/depot",
  "message": "feat: ajouter la fonctionnalité de recherche\n\nCette fonctionnalité permet aux utilisateurs de rechercher des produits par nom, catégorie et prix."
}
```

### Gestion des branches

- Utilisez des branches pour isoler le développement de fonctionnalités
- Nommez les branches de manière descriptive (ex: `feature/search`, `bugfix/login-issue`)
- Fusionnez régulièrement la branche principale dans vos branches de fonctionnalités
- Supprimez les branches après leur fusion

### Utilisation des stash

- Utilisez les stash pour sauvegarder temporairement des modifications non terminées
- Donnez des noms descriptifs à vos stash
- Nettoyez régulièrement les stash inutilisés

```
Outil: stash_save
Arguments:
{
  "path": "/chemin/vers/depot",
  "message": "Implémentation partielle de la recherche",
  "includeUntracked": true
}
```

### Actions en masse

- Utilisez `bulk_action` pour les opérations courantes
- Regroupez les opérations logiquement liées
- Vérifiez l'état du dépôt avant et après les actions en masse

```
Outil: bulk_action
Arguments:
{
  "path": "/chemin/vers/depot",
  "actions": [
    {
      "type": "stage"
    },
    {
      "type": "commit",
      "message": "fix: corriger le bug d'authentification"
    },
    {
      "type": "push",
      "remote": "origin",
      "branch": "bugfix/auth"
    }
  ]
}
```
<!-- END_SECTION: best_practices -->

<!-- START_SECTION: error_handling -->
## Gestion des erreurs

Le MCP Git peut renvoyer différentes erreurs. Voici comment les gérer:

### Erreurs courantes

| Erreur | Description | Solution |
|--------|-------------|----------|
| `RepositoryNotFoundError` | Le dépôt spécifié n'existe pas | Vérifiez le chemin du dépôt |
| `BranchNotFoundError` | La branche spécifiée n'existe pas | Vérifiez le nom de la branche |
| `MergeConflictError` | Conflit de fusion | Résolvez les conflits manuellement |
| `RemoteNotFoundError` | Le dépôt distant spécifié n'existe pas | Vérifiez le nom du dépôt distant |
| `AuthenticationError` | Erreur d'authentification | Vérifiez vos informations d'identification |

### Stratégies de gestion des erreurs

1. **Vérification préalable**:
   - Vérifiez l'état du dépôt avec `status` avant d'effectuer des opérations
   - Vérifiez l'existence des branches avec `branch_list` avant de les utiliser

2. **Gestion des conflits**:
   - En cas de conflit lors d'un `pull` ou d'un `merge`, utilisez `status` pour identifier les fichiers en conflit
   - Résolvez les conflits manuellement, puis utilisez `add` et `commit` pour finaliser la résolution

3. **Récupération après erreur**:
   - Utilisez `stash_save` pour sauvegarder les modifications non commitées en cas de problème
   - Utilisez `checkout` pour restaurer des fichiers à leur état précédent
<!-- END_SECTION: error_handling -->

<!-- START_SECTION: integration_with_roo -->
## Intégration avec Roo

Le MCP Git s'intègre parfaitement avec Roo, permettant des interactions naturelles en langage courant. Voici quelques exemples de demandes que vous pouvez faire à Roo:

- "Clone le dépôt https://github.com/utilisateur/depot.git"
- "Crée une nouvelle branche appelée feature/search"
- "Ajoute tous les fichiers modifiés et crée un commit avec le message 'Ajout de la fonctionnalité de recherche'"
- "Pousse mes modifications vers origin"
- "Montre-moi l'état actuel du dépôt"
- "Liste toutes les branches du projet"

Roo traduira automatiquement ces demandes en appels aux outils appropriés du MCP Git.
<!-- END_SECTION: integration_with_roo -->

<!-- START_SECTION: performance_optimization -->
## Optimisation des performances

### Clonage efficace

Pour cloner efficacement de grands dépôts:

```
Outil: clone
Arguments:
{
  "url": "https://github.com/utilisateur/grand-depot.git",
  "path": "/chemin/vers/destination",
  "depth": 1,
  "single-branch": true,
  "branch": "main"
}
```

L'option `depth: 1` crée un clone superficiel qui ne contient que le commit le plus récent, ce qui réduit considérablement la taille du dépôt cloné.

### Utilisation de bulk_action

Utilisez `bulk_action` pour réduire le nombre d'appels au MCP Git:

```
Outil: bulk_action
Arguments:
{
  "path": "/chemin/vers/depot",
  "actions": [
    {
      "type": "stage"
    },
    {
      "type": "commit",
      "message": "Modifications multiples"
    },
    {
      "type": "push",
      "remote": "origin",
      "branch": "main"
    }
  ]
}
```

### Optimisation des dépôts

Pour optimiser les performances d'un dépôt Git:

1. Nettoyez régulièrement votre dépôt:
   ```bash
   git gc --aggressive
   ```

2. Utilisez des sous-modules pour les grands projets:
   ```bash
   git submodule add https://github.com/utilisateur/sous-module.git chemin/vers/sous-module
   ```

3. Utilisez des fichiers `.gitignore` appropriés pour éviter de suivre des fichiers inutiles
<!-- END_SECTION: performance_optimization -->

<!-- START_SECTION: security_considerations -->
## Considérations de sécurité

### Authentification sécurisée

- Utilisez SSH plutôt que HTTPS lorsque c'est possible
- Utilisez des jetons d'accès personnels avec des permissions limitées plutôt que des mots de passe
- Évitez de stocker des informations d'identification en texte clair dans les dépôts

### Protection des branches

- Protégez les branches importantes comme `main` ou `production`
- Utilisez des règles de protection de branche sur GitHub/GitLab/Bitbucket
- Exigez des revues de code avant la fusion

### Informations sensibles

- Évitez de committer des informations sensibles (mots de passe, clés API, etc.)
- Utilisez des outils comme `.gitignore` pour éviter de committer accidentellement des fichiers sensibles
- Utilisez des outils comme `git-crypt` ou `git-secret` pour chiffrer les fichiers sensibles

### Audit et traçabilité

- Signez vos commits pour garantir leur authenticité:
  ```bash
  git config --global commit.gpgsign true
  ```

- Utilisez des hooks Git pour appliquer des politiques de sécurité:
  ```bash
  # Exemple de pre-commit hook pour vérifier les fuites de secrets
  git secrets --install
  ```
<!-- END_SECTION: security_considerations -->

<!-- START_SECTION: troubleshooting -->
## Résolution des problèmes

### Problèmes d'authentification

Si vous rencontrez des problèmes d'authentification:

1. **Vérifiez vos informations d'identification**:
   ```bash
   git config --list | grep credential
   ```

2. **Réinitialisez vos informations d'identification**:
   ```bash
   git credential reject
   ```

3. **Utilisez SSH au lieu de HTTPS**:
   ```bash
   git remote set-url origin git@github.com:utilisateur/depot.git
   ```

### Problèmes de fusion

Si vous rencontrez des conflits lors d'une fusion:

1. **Identifiez les fichiers en conflit**:
   ```
   Outil: status
   Arguments:
   {
     "path": "/chemin/vers/depot"
   }
   ```

2. **Résolvez les conflits manuellement** en éditant les fichiers

3. **Marquez les conflits comme résolus**:
   ```
   Outil: add
   Arguments:
   {
     "path": "/chemin/vers/depot",
     "files": [
       "/chemin/vers/depot/fichier_en_conflit.txt"
     ]
   }
   ```

4. **Terminez la fusion**:
   ```
   Outil: commit
   Arguments:
   {
     "path": "/chemin/vers/depot",
     "message": "Résolution des conflits de fusion"
   }
   ```

Pour plus de détails sur la résolution des problèmes, consultez le fichier [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).
<!-- END_SECTION: troubleshooting -->