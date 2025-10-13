<!-- START: GUIDE_INSTALLATION_MCP -->

# Guide d'Installation des MCPs (Model Context Protocol)

<!-- START: TABLE_OF_CONTENTS -->
## Sommaire

- [Guide d'Installation des MCPs (Model Context Protocol)](#guide-dinstallation-des-mcps-model-context-protocol)
  - [Sommaire](#sommaire)
  - [Introduction](#introduction)
  - [Prérequis Système](#prérequis-système)
    - [Systèmes d'exploitation supportés](#systèmes-dexploitation-supportés)
    - [Logiciels requis](#logiciels-requis)
    - [Configuration matérielle recommandée](#configuration-matérielle-recommandée)
  - [Vue d'ensemble du processus d'installation](#vue-densemble-du-processus-dinstallation)
  - [Installation de base commune](#installation-de-base-commune)
    - [Préparation de l'environnement](#préparation-de-lenvironnement)
      - [Installation de Node.js et npm](#installation-de-nodejs-et-npm)
      - [Installation de Git](#installation-de-git)
      - [Installation de Python (si nécessaire)](#installation-de-python-si-nécessaire)
    - [Clonage du dépôt](#clonage-du-dépôt)
    - [Installation des dépendances principales](#installation-des-dépendances-principales)
  - [Installation des MCPs spécifiques](#installation-des-mcps-spécifiques)
    - [MCPs Internes](#mcps-internes)
      - [QuickFiles Server](#quickfiles-server)
      - [JinaNavigator Server](#jinanavigator-server)
      - [Jupyter MCP Server](#jupyter-mcp-server)
    - [MCPs Externes](#mcps-externes)
      - [Docker](#docker)
      - [Filesystem](#filesystem)
      - [Git](#git)
      - [GitHub](#github)
      - [SearXNG](#searxng)
      - [Win-CLI](#win-cli)
      - [Markitdown](#markitdown)
  - [Configuration dans Roo](#configuration-dans-roo)
  - [Vérification post-installation](#vérification-post-installation)
    - [Tests de base](#tests-de-base)
    - [Résolution des problèmes courants](#résolution-des-problèmes-courants)
  - [Ressources supplémentaires](#ressources-supplémentaires)
<!-- END: TABLE_OF_CONTENTS -->

<!-- START: INTRODUCTION -->
## Introduction

Ce guide d'installation a pour objectif de vous accompagner dans le déploiement complet des serveurs MCP (Model Context Protocol) utilisés pour étendre les capacités des modèles de langage (LLM) dans le projet Roo. Il couvre l'installation et la configuration de tous les MCPs disponibles, qu'ils soient internes ou externes.

Le Model Context Protocol (MCP) est un protocole qui permet aux modèles de langage d'interagir avec des outils et des ressources externes, leur donnant accès à des fonctionnalités comme la recherche d'informations en temps réel, l'accès à des API, la manipulation de fichiers, l'analyse de code, et bien plus encore.

Ce guide est conçu pour être exhaustif et accessible, que vous soyez un développeur expérimenté ou un nouvel utilisateur des technologies MCP. Chaque étape est détaillée avec des exemples concrets et des solutions aux problèmes courants.
<!-- END: INTRODUCTION -->

<!-- START: PREREQUISITES -->
## Prérequis Système

Avant de commencer l'installation des MCPs, assurez-vous que votre système répond aux exigences suivantes.

### Systèmes d'exploitation supportés

Les MCPs peuvent être installés sur les systèmes d'exploitation suivants :

- **Windows** : Windows 10 ou Windows 11 (64 bits)
- **macOS** : macOS 10.15 (Catalina) ou supérieur
- **Linux** : Ubuntu 20.04 LTS ou supérieur, Debian 10 ou supérieur, CentOS 8 ou supérieur

### Logiciels requis

Les logiciels suivants sont nécessaires pour l'installation et le fonctionnement des MCPs :

- **Node.js** : Version 14.x ou supérieure
- **npm** : Version 6.x ou supérieure
- **Git** : Version 2.x ou supérieure
- **Python** : Version 3.6 ou supérieure (requis pour certains MCPs comme Jupyter)
- **Docker** : Version 20.x ou supérieure (requis uniquement pour le MCP Docker)

### Configuration matérielle recommandée

Pour des performances optimales, nous recommandons la configuration matérielle suivante :

- **Processeur** : 4 cœurs ou plus
- **Mémoire RAM** : 8 Go minimum, 16 Go recommandé
- **Espace disque** : 10 Go minimum d'espace libre
- **Connexion Internet** : Connexion haut débit pour le téléchargement des dépendances et l'accès aux services en ligne
<!-- END: PREREQUISITES -->

<!-- START: INSTALLATION_OVERVIEW -->
## Vue d'ensemble du processus d'installation

Le processus d'installation des MCPs se déroule en plusieurs étapes :

1. **Préparation de l'environnement** : Installation des logiciels prérequis
2. **Clonage du dépôt** : Récupération du code source des MCPs
3. **Installation des dépendances principales** : Installation des bibliothèques communes
4. **Installation des MCPs spécifiques** : Configuration et installation de chaque MCP
5. **Configuration dans Roo** : Intégration des MCPs dans l'environnement Roo
6. **Vérification post-installation** : Tests pour s'assurer que tout fonctionne correctement

Ce guide vous accompagnera à travers chacune de ces étapes en détail.
<!-- END: INSTALLATION_OVERVIEW -->

<!-- START: COMMON_INSTALLATION -->
## Installation de base commune

### Préparation de l'environnement

#### Installation de Node.js et npm

1. Téléchargez et installez Node.js depuis [le site officiel](https://nodejs.org/)
2. Vérifiez l'installation avec les commandes suivantes :

```bash
node --version
npm --version
```

#### Installation de Git

1. Téléchargez et installez Git depuis [le site officiel](https://git-scm.com/)
2. Vérifiez l'installation avec la commande :

```bash
git --version
```

#### Installation de Python (si nécessaire)

1. Téléchargez et installez Python depuis [le site officiel](https://www.python.org/)
2. Vérifiez l'installation avec la commande :

```bash
python --version
```

### Clonage du dépôt

Pour obtenir le code source des MCPs, clonez le dépôt principal et ses sous-modules :

```bash
# Cloner le dépôt principal
git clone https://github.com/votre-organisation/roo-extensions.git

# Accéder au répertoire des MCPs
cd roo-extensions/mcps

# Initialiser et mettre à jour les sous-modules
git submodule update --init --recursive
```

### Installation des dépendances principales

Installez les dépendances communes à tous les MCPs :

```bash
# Accéder au répertoire des MCPs internes
cd mcp-servers

# Installer les dépendances
npm install

# Installer tous les serveurs MCP
npm run install-all

# Configurer les serveurs
npm run setup-config
```
<!-- END: COMMON_INSTALLATION -->

<!-- START: SPECIFIC_INSTALLATIONS -->
## Installation des MCPs spécifiques

### MCPs Internes

Les MCPs internes sont développés et maintenus dans le cadre du projet. Ils sont conçus pour être légers, performants et faciles à utiliser.

#### QuickFiles Server

Le QuickFiles Server permet la manipulation rapide et efficace de fichiers multiples.

```bash
# Accéder au répertoire du serveur
cd mcp-servers/servers/quickfiles-server

# Installer les dépendances spécifiques
npm install

# Compiler le serveur
npm run build
```

Pour plus de détails, consultez la [documentation QuickFiles](./mcp-servers/servers/quickfiles-server/README.md).

#### JinaNavigator Server

Le JinaNavigator Server permet de convertir des pages web en Markdown.

```bash
# Accéder au répertoire du serveur
cd mcp-servers/servers/jinavigator-server

# Installer les dépendances spécifiques
npm install

# Compiler le serveur
npm run build
```

Pour plus de détails, consultez la [documentation JinaNavigator](./mcp-servers/servers/jinavigator-server/README.md).

#### Jupyter MCP Server

Le Jupyter MCP Server permet d'interagir avec des notebooks Jupyter.

1. **Installation de Jupyter**

   **Sous Windows :**
   ```bash
   # Créer un environnement virtuel
   python -m venv jupyter-env

   # Activer l'environnement virtuel
   jupyter-env\Scripts\activate

   # Installer Jupyter
   pip install jupyter
   ```

   **Sous macOS/Linux :**
   ```bash
   # Créer un environnement virtuel
   python3 -m venv jupyter-env

   # Activer l'environnement virtuel
   source jupyter-env/bin/activate

   # Installer Jupyter
   pip install jupyter
   ```

2. **Installation du serveur MCP Jupyter**

   ```bash
   # Accéder au répertoire du serveur
   cd mcp-servers/servers/jupyter-mcp-server

   # Installer les dépendances spécifiques
   npm install

   # Compiler le serveur
   npm run build
   ```

Pour plus de détails, consultez la [documentation Jupyter MCP](./mcp-servers/servers/jupyter-mcp-server/README.md).

### MCPs Externes

Les MCPs externes fournissent des fonctionnalités supplémentaires pour interagir avec divers systèmes et services.

#### Docker

Le MCP Docker permet d'interagir avec Docker via le protocole MCP.

```bash
# Installation globale
npm install -g @modelcontextprotocol/server-docker

# Vérification de l'installation
docker-mcp-server --version
```

Pour plus de détails, consultez la [documentation Docker MCP](./external/docker/README.md).

#### Filesystem

Le MCP Filesystem permet d'interagir avec le système de fichiers local.

```bash
# Installation globale
npm install -g @modelcontextprotocol/server-filesystem

# Vérification de l'installation
filesystem-mcp-server --version
```

Pour plus de détails, consultez la [documentation Filesystem MCP](./external/filesystem/README.md).

#### Git

Le MCP Git permet d'interagir avec des dépôts Git.

```bash
# Installation globale
npm install -g @modelcontextprotocol/server-git

# Vérification de l'installation
git-mcp-server --version
```

Pour plus de détails, consultez la [documentation Git MCP](./external/git/README.md).

#### GitHub

Le MCP GitHub permet d'interagir avec l'API GitHub.

```bash
# Installation globale
npm install -g @modelcontextprotocol/server-github

# Vérification de l'installation
github-mcp-server --version
```

Pour plus de détails, consultez la [documentation GitHub MCP](./external/github/README.md).

#### SearXNG

Le MCP SearXNG permet d'interagir avec le moteur de recherche SearXNG.

```bash
# Installation globale
npm install -g mcp-searxng

# Vérification de l'installation
searxng-mcp-server --version
```

Pour plus de détails, consultez la [documentation SearXNG MCP](./external/searxng/README.md).

#### Win-CLI

Le MCP Win-CLI permet d'exécuter des commandes dans le terminal Windows.

**Installation locale (recommandée)**

```bash
# Naviguer vers le répertoire du serveur
cd mcps/external/win-cli/server/

# Installer les dépendances
npm install

# La compilation est automatique via le script 'prepare'
# Vérifier la génération du fichier
Test-Path dist/index.js  # Doit retourner True
```

**Installation globale (alternative)**

```bash
# Installation globale
npm install -g @simonb97/server-win-cli

# Vérification de l'installation
win-cli-mcp-server --version
```

**Configuration dans mcp_settings.json**

```json
{
  "win-cli": {
    "command": "npm",
    "args": ["start", "--", "--debug"],
    "cwd": "c:\\dev\\roo-extensions\\mcps\\external\\win-cli\\server",
    "transportType": "stdio",
    "autoStart": true,
    "disabled": false,
    "description": "MCP for executing CLI commands on Windows"
  }
}
```

Pour plus de détails, consultez la [documentation Win-CLI MCP](./external/win-cli/README.md).

#### Markitdown

Le MCP Markitdown permet de convertir divers formats de documents en Markdown.

**Prérequis**
- Python ≥3.8 (recommandé : Python 3.13 LTS)
- pip (gestionnaire de paquets Python)

**Installation de Python (si nécessaire)**

```powershell
# Via winget (Windows)
winget install Python.Python.3.13 --silent

# Vérification
python --version  # Doit afficher Python 3.13.x
pip --version     # Doit afficher la version pip
```

**Note** : Après installation de Python, vous devrez peut-être redémarrer le terminal ou VSCode pour que le PATH soit mis à jour.

**Installation de uv**

```powershell
# Installer uv via pip
pip install uv

# Vérification
uv --version   # Doit afficher la version uv
uvx --version  # Doit afficher la version uvx
```

**Configuration dans mcp_settings.json**

```json
{
  "markitdown": {
    "command": "uvx",
    "args": ["markitdown-mcp"],
    "env": {}
  }
}
```

**Test de fonctionnement**

```powershell
# Tester le démarrage du serveur MCP
uvx markitdown-mcp
# Le serveur démarre et attend des connexions (Ctrl+C pour arrêter)
```

**Troubleshooting**

Si `uvx` n'est pas reconnu après installation :
1. Redémarrer le terminal PowerShell
2. Redémarrer VSCode
3. Vérifier le PATH système inclut `%LOCALAPPDATA%\Programs\Python\Python313\Scripts`

Pour plus de détails, consultez la [documentation officielle uv](https://docs.astral.sh/uv/).
<!-- END: SPECIFIC_INSTALLATIONS -->

<!-- START: ROO_CONFIGURATION -->
## Configuration dans Roo

Pour configurer les MCPs dans Roo, vous devez ajouter leur configuration dans le fichier `servers.json` de Roo. Voici un exemple de configuration :

```json
{
  "servers": [
    {
      "name": "quickfiles",
      "command": "cmd /c node D:\\chemin\\vers\\mcps\\mcp-servers\\servers\\quickfiles-server\\build\\index.js",
      "autostart": true
    },
    {
      "name": "jinavigator",
      "command": "cmd /c node D:\\chemin\\vers\\mcps\\mcp-servers\\servers\\jinavigator-server\\dist\\index.js",
      "autostart": true
    },
    {
      "name": "jupyter",
      "command": "cmd /c node D:\\chemin\\vers\\mcps\\mcp-servers\\servers\\jupyter-mcp-server\\dist\\index.js",
      "autostart": true
    },
    {
      "name": "searxng",
      "command": "cmd /c npx -y mcp-searxng",
      "autostart": true
    },
    {
      "name": "git",
      "command": "cmd /c npx -y @modelcontextprotocol/server-git",
      "autostart": true
    },
    {
      "name": "github",
      "command": "cmd /c npx -y @modelcontextprotocol/server-github",
      "autostart": true
    },
    {
      "name": "filesystem",
      "command": "cmd /c npx -y @modelcontextprotocol/server-filesystem D:\\chemin\\vers\\roo-extensions d:\\roo-extensions",
      "autostart": true
    },
    {
      "name": "docker",
      "command": "cmd /c npx -y @modelcontextprotocol/server-docker",
      "autostart": true
    },
    {
      "name": "win-cli",
      "command": "cmd /c npx -y @simonb97/server-win-cli",
      "autostart": true
    }
  ]
}
```

Remplacez `D:\\chemin\\vers\\` par le chemin absolu vers votre installation.

Pour les utilisateurs de macOS/Linux, remplacez `cmd /c` par `bash -c` et ajustez les chemins en conséquence.
<!-- END: ROO_CONFIGURATION -->

<!-- START: POST_INSTALLATION -->
## Vérification post-installation

Après avoir installé et configuré tous les MCPs, il est important de vérifier que tout fonctionne correctement.

### Tests de base

1. **Vérification des serveurs MCP**

   Exécutez la commande suivante pour vérifier que tous les serveurs MCP sont correctement installés et accessibles :

   ```bash
   # Depuis le répertoire racine du projet
   cd mcps/mcp-servers
   npm run test-all
   ```

2. **Utilisation des scripts de test automatisés**

   Des scripts de test dédiés sont disponibles pour vérifier le bon fonctionnement de chaque MCP :

   ```bash
   # Accéder au répertoire des tests
   cd mcps/tests

   # Exécuter tous les tests
   ./run-all-tests.ps1

   # Ou exécuter un test spécifique
   node test-quickfiles.js
   node test-jinavigator.js
   node test-jupyter.js
   ```

   Ces scripts vérifient :
   - L'installation correcte du MCP
   - Les fonctionnalités de base
   - L'intégration avec Roo
   - Et génèrent un rapport détaillé dans le répertoire `reports/`

   Pour plus d'informations sur les tests, consultez la [documentation des tests](./tests/README.md).

3. **Test de connexion à Roo**

   Assurez-vous que Roo peut se connecter aux serveurs MCP en vérifiant les logs de démarrage de Roo.

4. **Test fonctionnel manuel**

   Testez chaque MCP individuellement pour vérifier qu'il fonctionne correctement :

   - **QuickFiles** : Testez la lecture de fichiers multiples
   - **JinaNavigator** : Testez la conversion d'une page web en Markdown
   - **Jupyter** : Testez la création et l'exécution d'un notebook
   - **Git** : Testez la récupération du statut d'un dépôt
   - **GitHub** : Testez la recherche de dépôts
   - **Filesystem** : Testez la lecture d'un fichier
   - **Docker** : Testez la liste des conteneurs
   - **SearXNG** : Testez une recherche simple
   - **Win-CLI** : Testez l'exécution d'une commande simple

### Résolution des problèmes courants

Si vous rencontrez des problèmes lors de l'installation ou de l'utilisation des MCPs, voici quelques solutions aux problèmes les plus courants :

1. **Problème de connexion à un serveur MCP**
   - Vérifiez que le serveur est bien démarré
   - Vérifiez que le chemin dans `servers.json` est correct
   - Vérifiez les logs du serveur pour identifier d'éventuelles erreurs

2. **Erreurs de dépendances**
   - Assurez-vous que toutes les dépendances sont installées avec la bonne version
   - Essayez de réinstaller les dépendances avec `npm ci` au lieu de `npm install`

3. **Problèmes de permissions**
   - Vérifiez que vous avez les droits d'accès nécessaires aux répertoires et fichiers
   - Sous Windows, essayez d'exécuter en tant qu'administrateur
   - Sous Linux/macOS, vérifiez les permissions avec `ls -la`

4. **Problèmes spécifiques à Jupyter**
   - Assurez-vous que le serveur Jupyter est en cours d'exécution
   - Vérifiez que le token d'authentification est correct

Pour une aide plus détaillée sur le dépannage, consultez :
- [Guide de dépannage général](./internal/docs/troubleshooting.md)
- [Guide de dépannage du MCP Jupyter](./internal/docs/jupyter-mcp-troubleshooting.md)
<!-- END: POST_INSTALLATION -->

<!-- START: ADDITIONAL_RESOURCES -->
## Ressources supplémentaires

Pour approfondir vos connaissances sur les MCPs et leur utilisation, voici quelques ressources utiles :

- [Spécification MCP officielle](https://github.com/microsoft/mcp)
- [Documentation sur l'architecture MCP](./internal/docs/architecture.md)
- [Guide de contribution](./mcp-servers/CONTRIBUTING.md)
- [Exemples d'utilisation des MCPs](./mcp-servers/examples/)
- [Forum de support](https://github.com/votre-organisation/roo-extensions/discussions)

---

Ce guide est maintenu par l'équipe de développement Roo. Pour toute question ou suggestion d'amélioration, n'hésitez pas à ouvrir une issue sur le dépôt GitHub.

<!-- END: ADDITIONAL_RESOURCES -->