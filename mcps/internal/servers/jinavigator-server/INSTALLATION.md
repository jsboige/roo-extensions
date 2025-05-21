# Installation du serveur MCP JinaNavigator

<!-- START_SECTION: prerequisites -->
## Prérequis

Avant d'installer le serveur MCP JinaNavigator, assurez-vous que votre système répond aux exigences suivantes :

- **Node.js** : Version 14.x ou supérieure
- **npm** : Version 6.x ou supérieure
- **Connexion Internet** : Nécessaire pour accéder à l'API Jina
- **Espace disque** : Au moins 100 Mo d'espace libre
- **Mémoire** : Au moins 512 Mo de RAM disponible
- **Système d'exploitation** : Windows, macOS ou Linux
<!-- END_SECTION: prerequisites -->

<!-- START_SECTION: installation_steps -->
## Étapes d'installation

### 1. Clonage du dépôt

Si vous n'avez pas encore cloné le dépôt principal, faites-le avec la commande suivante :

```bash
git clone https://github.com/jsboige/jsboige-mcp-servers.git
cd jsboige-mcp-servers
```

### 2. Installation des dépendances

Naviguez vers le répertoire du serveur JinaNavigator et installez les dépendances :

```bash
cd servers/jinavigator-server
npm install
```

### 3. Compilation du projet

Compilez le projet TypeScript en JavaScript :

```bash
npm run build
```

Cette commande génère les fichiers JavaScript dans le répertoire `dist/`.
<!-- END_SECTION: installation_steps -->

<!-- START_SECTION: installation_methods -->
## Méthodes d'installation alternatives

### Installation via npm

Vous pouvez également installer le serveur JinaNavigator directement via npm :

```bash
npm install @modelcontextprotocol/server-jinavigator
```

### Installation avec Docker

Une image Docker est disponible pour faciliter le déploiement :

```bash
# Construire l'image Docker
docker build -t jinavigator-mcp-server .

# Exécuter le conteneur
docker run -p 3000:3000 jinavigator-mcp-server
```

### Installation automatisée avec script

Pour Windows, vous pouvez utiliser le script d'installation automatisée :

```batch
run-node-portable.bat
```

Ce script téléchargera Node.js si nécessaire, installera les dépendances et démarrera le serveur.
<!-- END_SECTION: installation_methods -->

<!-- START_SECTION: verification -->
## Vérification de l'installation

Pour vérifier que l'installation s'est déroulée correctement, exécutez le script de test :

```bash
npm run test:simple
```

Vous devriez voir une sortie similaire à celle-ci :

```
JinaNavigator MCP Server - Test de connexion
✓ Connexion au serveur MCP établie
✓ Liste des outils disponibles récupérée
✓ Conversion d'URL en Markdown réussie
Test terminé avec succès!
```

Si vous voyez cette sortie, le serveur JinaNavigator est correctement installé et fonctionnel.
<!-- END_SECTION: verification -->

<!-- START_SECTION: post_installation -->
## Configuration post-installation

### Configuration de l'API Jina

Le serveur JinaNavigator utilise l'API Jina (`https://r.jina.ai/`) pour convertir des pages web en Markdown. Par défaut, aucune configuration supplémentaire n'est nécessaire pour utiliser cette API.

Cependant, si vous souhaitez utiliser une clé API personnalisée ou configurer des options spécifiques, vous pouvez créer un fichier `config.json` dans le répertoire racine du serveur :

```json
{
  "jina": {
    "apiKey": "votre_clé_api_ici",
    "timeout": 30000,
    "maxRetries": 3
  }
}
```

### Configuration du proxy

Si vous êtes derrière un proxy, vous devez configurer les variables d'environnement HTTP_PROXY et HTTPS_PROXY :

```bash
# Sur Linux/macOS
export HTTP_PROXY=http://proxy.example.com:8080
export HTTPS_PROXY=http://proxy.example.com:8080

# Sur Windows
set HTTP_PROXY=http://proxy.example.com:8080
set HTTPS_PROXY=http://proxy.example.com:8080
```

### Configuration du pare-feu

Si vous prévoyez d'accéder au serveur JinaNavigator depuis d'autres machines, assurez-vous que le port utilisé (par défaut 3000) est ouvert dans votre pare-feu.

### Configuration de l'environnement de production

Pour un environnement de production, il est recommandé de :

1. Configurer un proxy inverse (comme Nginx ou Apache) devant le serveur JinaNavigator
2. Mettre en place HTTPS pour sécuriser les communications
3. Configurer des limites de ressources appropriées
4. Mettre en place une surveillance et des alertes
<!-- END_SECTION: post_installation -->

<!-- START_SECTION: troubleshooting -->
## Dépannage de l'installation

### Problèmes courants

#### Erreur "Module not found"

**Problème** : Erreur indiquant qu'un module n'a pas été trouvé lors de l'exécution.

**Solution** :
- Vérifiez que toutes les dépendances ont été installées avec `npm install`
- Vérifiez que le projet a été compilé avec `npm run build`
- Essayez de supprimer le répertoire `node_modules` et le fichier `package-lock.json`, puis réinstallez les dépendances

#### Erreur de connexion à l'API Jina

**Problème** : Le serveur ne peut pas se connecter à l'API Jina.

**Solution** :
- Vérifiez votre connexion Internet
- Vérifiez que l'API Jina est accessible depuis votre réseau
- Configurez un proxy si nécessaire
- Augmentez le timeout dans la configuration

#### Erreur de port déjà utilisé

**Problème** : Le port 3000 est déjà utilisé par une autre application.

**Solution** :
- Modifiez le port utilisé par le serveur JinaNavigator dans le fichier de configuration
- Arrêtez l'application qui utilise déjà le port 3000
- Utilisez la commande `netstat -ano | findstr :3000` (Windows) ou `lsof -i :3000` (Linux/macOS) pour identifier l'application qui utilise le port
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: next_steps -->
## Prochaines étapes

Maintenant que vous avez installé le serveur JinaNavigator, vous pouvez :

1. [Configurer le serveur](CONFIGURATION.md) selon vos besoins
2. [Apprendre à utiliser le serveur](USAGE.md) avec des exemples pratiques
3. [Consulter le guide de dépannage](TROUBLESHOOTING.md) en cas de problèmes
4. [Explorer les cas d'utilisation avancés](../docs/jinavigator-use-cases.md) pour tirer le meilleur parti du serveur
<!-- END_SECTION: next_steps -->