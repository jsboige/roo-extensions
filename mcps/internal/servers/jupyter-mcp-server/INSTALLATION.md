# Installation du serveur MCP Jupyter

<!-- START_SECTION: prerequisites -->
## Prérequis

Avant d'installer le serveur MCP Jupyter, assurez-vous que votre système répond aux exigences suivantes :

- **Node.js** : Version 14.x ou supérieure
- **npm** : Version 6.x ou supérieure
- **Python** : Version 3.6 ou supérieure
- **Jupyter Notebook ou JupyterLab** : Installé et fonctionnel
- **Espace disque** : Au moins 200 Mo d'espace libre
- **Mémoire** : Au moins 512 Mo de RAM disponible
- **Système d'exploitation** : Windows, macOS ou Linux
<!-- END_SECTION: prerequisites -->

<!-- START_SECTION: jupyter_installation -->
## Installation de Jupyter

Pour utiliser le serveur MCP Jupyter, vous devez d'abord installer Jupyter Notebook ou JupyterLab.

### Installation de Jupyter sous Windows

1. Installez Python depuis [python.org](https://www.python.org/downloads/)

2. Ouvrez une invite de commande et créez un environnement virtuel :
   ```bash
   python -m venv jupyter-env
   ```

3. Activez l'environnement virtuel :
   ```bash
   jupyter-env\Scripts\activate
   ```

4. Installez Jupyter :
   ```bash
   pip install jupyter
   ```

5. Créez un script `start-jupyter.bat` avec le contenu suivant :
   ```batch
   @echo off
   call jupyter-env\Scripts\activate
   jupyter notebook --NotebookApp.token=test_token --NotebookApp.allow_origin='*' --no-browser
   ```

6. Exécutez le script pour démarrer Jupyter :
   ```bash
   start-jupyter.bat
   ```

### Installation de Jupyter sous macOS/Linux

1. Ouvrez un terminal et créez un environnement virtuel :
   ```bash
   python3 -m venv jupyter-env
   ```

2. Activez l'environnement virtuel :
   ```bash
   source jupyter-env/bin/activate
   ```

3. Installez Jupyter :
   ```bash
   pip install jupyter
   ```

4. Créez un script `start-jupyter.sh` avec le contenu suivant :
   ```bash
   #!/bin/bash
   source jupyter-env/bin/activate
   jupyter notebook --NotebookApp.token=test_token --NotebookApp.allow_origin='*' --no-browser
   ```

5. Rendez le script exécutable :
   ```bash
   chmod +x start-jupyter.sh
   ```

6. Exécutez le script pour démarrer Jupyter :
   ```bash
   ./start-jupyter.sh
   ```

Le serveur Jupyter démarrera sans ouvrir de navigateur. Il sera accessible à l'adresse http://localhost:8888.

> **Note importante** : L'option `--NotebookApp.allow_origin='*'` est nécessaire pour permettre au serveur MCP Jupyter de se connecter au serveur Jupyter. L'option `--NotebookApp.token=test_token` définit un token d'authentification simple pour le serveur Jupyter. En production, utilisez un token plus sécurisé.
<!-- END_SECTION: jupyter_installation -->

<!-- START_SECTION: installation_steps -->
## Étapes d'installation du serveur MCP Jupyter

### 1. Clonage du dépôt

Si vous n'avez pas encore cloné le dépôt principal, faites-le avec la commande suivante :

```bash
git clone https://github.com/jsboige/jsboige-mcp-servers.git
cd jsboige-mcp-servers
```

### 2. Installation des dépendances

Naviguez vers le répertoire du serveur MCP Jupyter et installez les dépendances :

```bash
cd servers/jupyter-mcp-server
npm install
```

### 3. Compilation du projet

Compilez le projet TypeScript en JavaScript :

```bash
npm run build
```

Cette commande génère les fichiers JavaScript dans le répertoire `dist/`.

### 4. Configuration

Créez un fichier `config.json` dans le répertoire du serveur MCP Jupyter avec le contenu suivant :

```json
{
  "jupyterServer": {
    "baseUrl": "http://localhost:8888",
    "token": "test_token"
  }
}
```

Assurez-vous que le token correspond à celui utilisé pour démarrer le serveur Jupyter.
<!-- END_SECTION: installation_steps -->

<!-- START_SECTION: installation_methods -->
## Méthodes d'installation alternatives

### Installation via npm

Vous pouvez également installer le serveur MCP Jupyter directement via npm :

```bash
npm install @modelcontextprotocol/server-jupyter
```

### Installation avec Docker

Une image Docker est disponible pour faciliter le déploiement :

```bash
# Construire l'image Docker
docker build -t jupyter-mcp-server .

# Exécuter le conteneur
docker run -p 3000:3000 -v /chemin/vers/notebooks:/notebooks jupyter-mcp-server
```

### Installation automatisée avec script

Pour Windows, vous pouvez utiliser le script d'installation automatisée :

```batch
run-node-fixed.bat
```

Ce script téléchargera Node.js si nécessaire, installera les dépendances et démarrera le serveur.
<!-- END_SECTION: installation_methods -->

<!-- START_SECTION: verification -->
## Vérification de l'installation

Pour vérifier que l'installation s'est déroulée correctement, suivez ces étapes :

### 1. Démarrer le serveur Jupyter

Assurez-vous que le serveur Jupyter est en cours d'exécution avec les options recommandées :

```bash
jupyter notebook --NotebookApp.token=test_token --NotebookApp.allow_origin='*' --no-browser
```

### 2. Démarrer le serveur MCP Jupyter

Dans un autre terminal, démarrez le serveur MCP Jupyter :

```bash
cd servers/jupyter-mcp-server
npm start
```

### 3. Exécuter le script de test

Dans un troisième terminal, exécutez le script de test :

```bash
cd mcps/mcp-servers/tests
node test-jupyter-connection.js
```

Vous devriez voir une sortie similaire à celle-ci :

```
Jupyter MCP Server - Test de connexion
✓ Connexion au serveur MCP établie
✓ Liste des outils disponibles récupérée
✓ Connexion au serveur Jupyter établie
✓ Création d'un notebook réussie
✓ Lecture d'un notebook réussie
✓ Ajout d'une cellule réussie
Test terminé avec succès!
```

Si vous voyez cette sortie, le serveur MCP Jupyter est correctement installé et fonctionnel.
<!-- END_SECTION: verification -->

<!-- START_SECTION: architecture -->
## Architecture du système

Le serveur MCP Jupyter fonctionne comme un intermédiaire entre les clients MCP (comme Roo) et le serveur Jupyter. Voici comment les composants interagissent :

```
+-------------+         +-------------------+         +----------------+
|             |         |                   |         |                |
| Client MCP  | <-----> | Serveur MCP       | <-----> | Serveur        |
| (ex: Roo)   |         | Jupyter           |         | Jupyter        |
|             |         |                   |         |                |
+-------------+         +-------------------+         +----------------+
                                 ^
                                 |
                                 v
                        +-------------------+
                        |                   |
                        | Système de        |
                        | fichiers local    |
                        |                   |
                        +-------------------+
```

- Le **Client MCP** (comme Roo) envoie des requêtes au serveur MCP Jupyter pour manipuler des notebooks Jupyter.
- Le **Serveur MCP Jupyter** traduit ces requêtes en appels à l'API Jupyter et au système de fichiers local.
- Le **Serveur Jupyter** exécute les opérations sur les notebooks et les kernels.
- Le **Système de fichiers local** stocke les fichiers notebook (.ipynb).

Cette architecture découplée permet au serveur MCP Jupyter de fonctionner avec n'importe quel serveur Jupyter existant, qu'il soit local ou distant.
<!-- END_SECTION: architecture -->

<!-- START_SECTION: post_installation -->
## Configuration post-installation

### Mode hors ligne

Par défaut, le serveur MCP Jupyter démarre en mode hors ligne pour éviter les erreurs de connexion au démarrage. Dans ce mode, aucune tentative de connexion à un serveur Jupyter n'est effectuée.

Pour activer la connexion au serveur Jupyter, vous pouvez :

1. Utiliser l'option de ligne de commande `--offline false` :
   ```bash
   npm start -- --offline false
   ```

2. Définir la variable d'environnement `JUPYTER_MCP_OFFLINE` à `false` :
   ```bash
   # Sur Linux/macOS
   export JUPYTER_MCP_OFFLINE=false
   npm start
   
   # Sur Windows
   set JUPYTER_MCP_OFFLINE=false
   npm start
   ```

3. Modifier le fichier `config.json` :
   ```json
   {
     "offline": false,
     "jupyterServer": {
       "baseUrl": "http://localhost:8888",
       "token": "test_token"
     }
   }
   ```

### Configuration du pare-feu

Si vous prévoyez d'accéder au serveur MCP Jupyter depuis d'autres machines, assurez-vous que les ports utilisés (par défaut 3000 pour le serveur MCP et 8888 pour le serveur Jupyter) sont ouverts dans votre pare-feu.

### Configuration de l'environnement de production

Pour un environnement de production, il est recommandé de :

1. Utiliser un token d'authentification fort pour le serveur Jupyter
2. Configurer HTTPS pour le serveur Jupyter
3. Limiter l'accès au serveur MCP Jupyter aux utilisateurs autorisés
4. Mettre en place un proxy inverse (comme Nginx ou Apache) devant le serveur MCP Jupyter
5. Configurer des limites de ressources appropriées
6. Mettre en place une surveillance et des alertes
<!-- END_SECTION: post_installation -->

<!-- START_SECTION: troubleshooting -->
## Dépannage de l'installation

### Problèmes courants

#### Erreur "Cannot connect to Jupyter server"

**Problème** : Le serveur MCP Jupyter ne peut pas se connecter au serveur Jupyter.

**Solutions** :
- Vérifiez que le serveur Jupyter est en cours d'exécution
- Vérifiez que l'URL et le token dans `config.json` sont corrects
- Assurez-vous que le serveur Jupyter est démarré avec `--NotebookApp.allow_origin='*'`
- Vérifiez qu'aucun pare-feu ne bloque la connexion

#### Erreur "403 Forbidden"

**Problème** : Le serveur MCP Jupyter reçoit une erreur 403 Forbidden lors de la connexion au serveur Jupyter.

**Solutions** :
- Vérifiez que le token dans `config.json` correspond exactement au token du serveur Jupyter
- Assurez-vous que le serveur Jupyter est démarré avec `--NotebookApp.allow_origin='*'`
- Redémarrez le serveur Jupyter et le serveur MCP Jupyter

#### Erreur "Module not found"

**Problème** : Erreur indiquant qu'un module n'a pas été trouvé lors de l'exécution.

**Solutions** :
- Vérifiez que toutes les dépendances ont été installées avec `npm install`
- Vérifiez que le projet a été compilé avec `npm run build`
- Essayez de supprimer le répertoire `node_modules` et le fichier `package-lock.json`, puis réinstallez les dépendances

#### Erreur de port déjà utilisé

**Problème** : Le port 3000 est déjà utilisé par une autre application.

**Solutions** :
- Modifiez le port utilisé par le serveur MCP Jupyter dans le fichier de configuration
- Arrêtez l'application qui utilise déjà le port 3000
- Utilisez la commande `netstat -ano | findstr :3000` (Windows) ou `lsof -i :3000` (Linux/macOS) pour identifier l'application qui utilise le port
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: next_steps -->
## Prochaines étapes

Maintenant que vous avez installé le serveur MCP Jupyter, vous pouvez :

1. [Configurer le serveur](CONFIGURATION.md) selon vos besoins
2. [Apprendre à utiliser le serveur](USAGE.md) avec des exemples pratiques
3. [Consulter le guide de dépannage](TROUBLESHOOTING.md) en cas de problèmes
4. [Explorer les cas d'utilisation avancés](../docs/jupyter-mcp-use-cases.md) pour tirer le meilleur parti du serveur
<!-- END_SECTION: next_steps -->