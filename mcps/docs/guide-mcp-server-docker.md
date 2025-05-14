# Guide d'Installation et d'Utilisation du MCP Server Docker

## 1. Introduction et présentation du MCP Server Docker

Le MCP Server Docker est une approche d'installation et d'exécution des serveurs MCP (Model Context Protocol) à l'aide de conteneurs Docker. Cette méthode offre une solution encapsulée, portable et facile à déployer pour les serveurs MCP utilisés avec Roo.

Le Model Context Protocol (MCP) est un protocole qui permet à Roo de communiquer avec des serveurs externes pour étendre ses capacités. Ces serveurs MCP fournissent des outils et des ressources supplémentaires qui permettent à Roo d'interagir avec différentes API et services, comme GitHub, Git, ou des moteurs de recherche comme SearXNG.

L'utilisation de Docker pour exécuter ces serveurs MCP présente plusieurs avantages :
- Isolation des dépendances et de l'environnement d'exécution
- Facilité de déploiement et de mise à jour
- Portabilité entre différents systèmes d'exploitation
- Standardisation de l'environnement d'exécution

## 2. Fonctionnalités principales

Le MCP Server Docker offre les fonctionnalités suivantes :

- **Exécution isolée** : Les serveurs MCP s'exécutent dans des conteneurs Docker isolés, ce qui évite les conflits de dépendances avec le système hôte.
- **Configuration via variables d'environnement** : Les serveurs MCP Docker peuvent être configurés à l'aide de variables d'environnement passées au conteneur.
- **Persistance des données** : Possibilité de monter des volumes pour persister les données entre les exécutions du conteneur.
- **Mise à jour simplifiée** : Les mises à jour des serveurs MCP se font simplement en tirant la dernière version de l'image Docker.
- **Compatibilité multiplateforme** : Les conteneurs Docker fonctionnent de manière cohérente sur différents systèmes d'exploitation.
- **Sécurité renforcée** : L'isolation des conteneurs Docker ajoute une couche de sécurité supplémentaire.

## 3. Prérequis et environnement nécessaire

Pour utiliser les serveurs MCP avec Docker, vous aurez besoin des éléments suivants :

### Prérequis logiciels
- **Docker** : Installé et en cours d'exécution sur votre système. Vous pouvez télécharger Docker depuis [le site officiel de Docker](https://docs.docker.com/get-docker/).
- **Roo** : L'extension Roo pour VS Code doit être installée et configurée.

### Prérequis matériels
- **Ressources système** : Docker nécessite des ressources système adéquates pour fonctionner correctement. Assurez-vous que votre système dispose d'au moins :
  - 4 Go de RAM
  - 10 Go d'espace disque libre
  - Un processeur multi-cœur

### Prérequis réseau
- **Accès Internet** : Nécessaire pour télécharger les images Docker des serveurs MCP.
- **Accès aux registres Docker** : Votre système doit pouvoir accéder aux registres Docker comme Docker Hub ou GitHub Container Registry (ghcr.io).

### Prérequis spécifiques aux serveurs MCP
- **GitHub MCP Server** : Un token d'accès personnel GitHub (PAT) avec les permissions appropriées.
- **Autres serveurs MCP** : Consultez la documentation spécifique à chaque serveur MCP pour connaître les prérequis supplémentaires.

## 4. Guide d'installation pas à pas

### Méthode 1 : Installation avec Docker (recommandée)

Cette méthode utilise directement les images Docker précompilées des serveurs MCP.

#### Installation du GitHub MCP Server

1. **Vérifiez que Docker est installé et en cours d'exécution** :
   ```bash
   docker --version
   ```

2. **Configurez le serveur MCP dans votre fichier de configuration Roo** :
   
   Ajoutez la configuration suivante à votre fichier `servers.json` :
   ```json
   {
     "github": {
       "command": "docker",
       "args": [
         "run",
         "-i",
         "--rm",
         "-e",
         "GITHUB_PERSONAL_ACCESS_TOKEN",
         "ghcr.io/github/github-mcp-server"
       ],
       "env": {
         "GITHUB_PERSONAL_ACCESS_TOKEN": "votre_token_github"
       }
     }
   }
   ```

3. **Remplacez `votre_token_github` par votre token d'accès personnel GitHub**.

#### Installation d'autres serveurs MCP avec Docker

Pour installer d'autres serveurs MCP avec Docker, suivez un processus similaire en adaptant la configuration selon les besoins spécifiques du serveur MCP.

### Méthode 2 : Installation à partir des sources

Cette méthode consiste à compiler le serveur MCP à partir des sources et à l'exécuter sans Docker.

#### Installation du GitHub MCP Server à partir des sources

1. **Clonez le dépôt** :
   ```bash
   git clone https://github.com/github/github-mcp-server
   cd github-mcp-server
   ```

2. **Compilez le binaire** :
   ```bash
   go build -o github-mcp-server ./cmd/github-mcp-server
   ```

3. **Configurez le serveur MCP dans votre fichier de configuration Roo** :
   
   Ajoutez la configuration suivante à votre fichier `servers.json` :
   ```json
   {
     "github": {
       "command": "chemin/vers/github-mcp-server",
       "args": ["stdio"],
       "env": {
         "GITHUB_PERSONAL_ACCESS_TOKEN": "votre_token_github"
       }
     }
   }
   ```

4. **Remplacez `chemin/vers/github-mcp-server` par le chemin absolu vers le binaire compilé**.
5. **Remplacez `votre_token_github` par votre token d'accès personnel GitHub**.

## 5. Configuration et paramétrage

### Configuration des serveurs MCP Docker

Les serveurs MCP Docker peuvent être configurés de plusieurs façons :

#### Variables d'environnement

Les variables d'environnement sont le moyen principal de configurer les serveurs MCP Docker. Elles peuvent être passées au conteneur Docker via l'option `-e` ou la section `env` dans la configuration Roo.

Exemple pour le GitHub MCP Server :
```json
{
  "github": {
    "command": "docker",
    "args": [
      "run",
      "-i",
      "--rm",
      "-e",
      "GITHUB_PERSONAL_ACCESS_TOKEN",
      "-e",
      "GITHUB_TOOLSETS=repos,issues,pull_requests",
      "ghcr.io/github/github-mcp-server"
    ],
    "env": {
      "GITHUB_PERSONAL_ACCESS_TOKEN": "votre_token_github"
    }
  }
}
```

#### Fichiers de configuration

Certains serveurs MCP permettent d'utiliser des fichiers de configuration externes. Ces fichiers peuvent être montés dans le conteneur Docker à l'aide de l'option `-v`.

Exemple :
```json
{
  "github": {
    "command": "docker",
    "args": [
      "run",
      "-i",
      "--rm",
      "-e",
      "GITHUB_PERSONAL_ACCESS_TOKEN",
      "-v",
      "/chemin/vers/config:/app/config",
      "ghcr.io/github/github-mcp-server"
    ],
    "env": {
      "GITHUB_PERSONAL_ACCESS_TOKEN": "votre_token_github"
    }
  }
}
```

### Configuration spécifique au GitHub MCP Server

#### Ensembles d'outils (Toolsets)

Le GitHub MCP Server permet d'activer ou désactiver des groupes spécifiques de fonctionnalités via l'option `--toolsets` ou la variable d'environnement `GITHUB_TOOLSETS`.

Ensembles d'outils disponibles :
- `repos` : Outils liés aux dépôts (opérations sur les fichiers, branches, commits)
- `issues` : Outils liés aux issues (création, lecture, mise à jour, commentaires)
- `users` : Outils liés aux utilisateurs GitHub
- `pull_requests` : Opérations sur les pull requests (création, fusion, révision)
- `code_security` : Alertes de scan de code et fonctionnalités de sécurité
- `experiments` : Fonctionnalités expérimentales (non considérées comme stables)

Exemple de configuration avec des ensembles d'outils spécifiques :
```json
{
  "github": {
    "command": "docker",
    "args": [
      "run",
      "-i",
      "--rm",
      "-e",
      "GITHUB_PERSONAL_ACCESS_TOKEN",
      "-e",
      "GITHUB_TOOLSETS=repos,issues,pull_requests",
      "ghcr.io/github/github-mcp-server"
    ],
    "env": {
      "GITHUB_PERSONAL_ACCESS_TOKEN": "votre_token_github"
    }
  }
}
```

#### Découverte dynamique d'outils

Au lieu de démarrer avec tous les outils activés, vous pouvez activer la découverte dynamique des ensembles d'outils :

```json
{
  "github": {
    "command": "docker",
    "args": [
      "run",
      "-i",
      "--rm",
      "-e",
      "GITHUB_PERSONAL_ACCESS_TOKEN",
      "-e",
      "GITHUB_DYNAMIC_TOOLSETS=1",
      "ghcr.io/github/github-mcp-server"
    ],
    "env": {
      "GITHUB_PERSONAL_ACCESS_TOKEN": "votre_token_github"
    }
  }
}
```

#### GitHub Enterprise Server

Si vous utilisez GitHub Enterprise Server, vous pouvez spécifier l'hôte avec la variable d'environnement `GITHUB_HOST` :

```json
{
  "github": {
    "command": "docker",
    "args": [
      "run",
      "-i",
      "--rm",
      "-e",
      "GITHUB_PERSONAL_ACCESS_TOKEN",
      "-e",
      "GITHUB_HOST=github.entreprise.com",
      "ghcr.io/github/github-mcp-server"
    ],
    "env": {
      "GITHUB_PERSONAL_ACCESS_TOKEN": "votre_token_github"
    }
  }
}
```

## 6. Considérations de sécurité

L'utilisation de serveurs MCP Docker présente certaines considérations de sécurité importantes :

### Gestion des secrets

- **Tokens d'accès** : Les tokens d'accès (comme le GitHub PAT) sont des informations sensibles. Évitez de les stocker en clair dans vos fichiers de configuration.
- **Variables d'environnement** : Préférez l'utilisation de variables d'environnement pour passer des secrets aux conteneurs Docker.
- **Gestionnaires de secrets** : Envisagez d'utiliser un gestionnaire de secrets pour stocker et gérer vos tokens d'accès.

### Isolation des conteneurs

- **Privilèges minimaux** : Exécutez les conteneurs Docker avec les privilèges minimaux nécessaires.
- **Utilisateur non-root** : Préférez l'exécution des conteneurs avec un utilisateur non-root.
- **Volumes en lecture seule** : Montez les volumes en lecture seule lorsque c'est possible.

### Mise à jour des images

- **Images officielles** : Utilisez uniquement des images Docker officielles ou provenant de sources fiables.
- **Mises à jour régulières** : Mettez régulièrement à jour vos images Docker pour bénéficier des dernières corrections de sécurité.
- **Scan de vulnérabilités** : Utilisez des outils de scan de vulnérabilités pour vérifier la sécurité de vos images Docker.

### Réseau

- **Exposition minimale** : Limitez l'exposition des ports réseau au strict nécessaire.
- **Réseau isolé** : Utilisez des réseaux Docker isolés pour limiter la communication entre les conteneurs.
- **Pare-feu** : Configurez votre pare-feu pour limiter l'accès aux ports exposés par Docker.

## 7. Limitations connues

L'utilisation de serveurs MCP Docker présente certaines limitations :

### Performances

- **Overhead de virtualisation** : L'exécution dans un conteneur Docker peut introduire un léger overhead de performance par rapport à une exécution native.
- **Démarrage à froid** : Le premier démarrage d'un conteneur Docker peut prendre plus de temps que les démarrages suivants.

### Compatibilité

- **Architecture système** : Les images Docker sont spécifiques à une architecture système (x86_64, ARM, etc.). Assurez-vous que l'image Docker est compatible avec votre architecture.
- **Système d'exploitation hôte** : Bien que Docker soit multiplateforme, certaines fonctionnalités peuvent varier selon le système d'exploitation hôte.

### Ressources

- **Consommation mémoire** : Les conteneurs Docker consomment de la mémoire supplémentaire par rapport à une exécution native.
- **Espace disque** : Les images Docker peuvent occuper un espace disque significatif.

### Spécifiques aux serveurs MCP

- **GitHub MCP Server** : Limité par les quotas et les limitations de l'API GitHub.
- **Autres serveurs MCP** : Consultez la documentation spécifique à chaque serveur MCP pour connaître les limitations supplémentaires.

## 8. Cas d'usage et exemples d'utilisation

### Interaction avec GitHub

#### Obtenir des informations sur l'utilisateur authentifié

```
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>get_me</tool_name>
<arguments>
{}
</arguments>
</use_mcp_tool>
```

#### Lister les branches d'un dépôt

```
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>list_branches</tool_name>
<arguments>
{
  "owner": "nom_utilisateur",
  "repo": "nom_depot"
}
</arguments>
</use_mcp_tool>
```

#### Créer une nouvelle branche

```
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>create_branch</tool_name>
<arguments>
{
  "owner": "nom_utilisateur",
  "repo": "nom_depot",
  "branch": "nouvelle-branche",
  "sha": "sha_du_commit_de_base"
}
</arguments>
</use_mcp_tool>
```

### Scénarios d'utilisation avancés

#### Automatisation de la création d'une issue avec analyse de code

```
# 1. Rechercher du code potentiellement problématique
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>search_code</tool_name>
<arguments>
{
  "query": "repo:nom_utilisateur/nom_depot language:javascript TODO"
}
</arguments>
</use_mcp_tool>

# 2. Créer une issue pour chaque TODO trouvé
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>create_issue</tool_name>
<arguments>
{
  "owner": "nom_utilisateur",
  "repo": "nom_depot",
  "title": "Résoudre les TODOs dans le code",
  "body": "J'ai trouvé des TODOs dans le code qui doivent être résolus:\n\n- TODO dans fichier.js ligne 42\n- TODO dans autre_fichier.js ligne 17",
  "labels": ["tech-debt"]
}
</arguments>
</use_mcp_tool>
```

#### Création d'une PR avec plusieurs modifications

```
# 1. Créer une nouvelle branche
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>create_branch</tool_name>
<arguments>
{
  "owner": "nom_utilisateur",
  "repo": "nom_depot",
  "branch": "feature/nouvelle-fonctionnalite",
  "sha": "sha_du_commit_main"
}
</arguments>
</use_mcp_tool>

# 2. Pousser plusieurs fichiers
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>push_files</tool_name>
<arguments>
{
  "owner": "nom_utilisateur",
  "repo": "nom_depot",
  "branch": "feature/nouvelle-fonctionnalite",
  "message": "Ajout de la nouvelle fonctionnalité",
  "files": [
    {
      "path": "src/nouvelle_fonctionnalite.js",
      "content": "// Code de la nouvelle fonctionnalité"
    },
    {
      "path": "test/nouvelle_fonctionnalite.test.js",
      "content": "// Tests pour la nouvelle fonctionnalité"
    }
  ]
}
</arguments>
</use_mcp_tool>

# 3. Créer une pull request
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>create_pull_request</tool_name>
<arguments>
{
  "owner": "nom_utilisateur",
  "repo": "nom_depot",
  "title": "Ajout de la nouvelle fonctionnalité",
  "body": "Cette PR ajoute la nouvelle fonctionnalité X avec ses tests",
  "head": "feature/nouvelle-fonctionnalite",
  "base": "main"
}
</arguments>
</use_mcp_tool>
```

### Utilisation des ressources

#### Accéder au contenu d'un dépôt

```
<access_mcp_resource>
<server_name>github</server_name>
<uri>repo://nom_utilisateur/nom_depot/contents/chemin/vers/fichier.txt</uri>
</access_mcp_resource>
```

#### Accéder au contenu d'un dépôt sur une branche spécifique

```
<access_mcp_resource>
<server_name>github</server_name>
<uri>repo://nom_utilisateur/nom_depot/refs/heads/nom_branche/contents/chemin/vers/fichier.txt</uri>
</access_mcp_resource>
```

---

Ce guide vous a présenté les principales informations pour installer, configurer et utiliser les serveurs MCP avec Docker. Pour des informations plus détaillées sur chaque serveur MCP spécifique, consultez la documentation correspondante.