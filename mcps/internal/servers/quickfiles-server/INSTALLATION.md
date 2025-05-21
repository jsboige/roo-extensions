<!-- START_SECTION: metadata -->
---
title: "Installation du serveur MCP QuickFiles"
description: "Guide d'installation complet pour le serveur MCP QuickFiles"
tags: #installation #quickfiles #mcp #guide
date_created: "2025-05-14"
date_updated: "2025-05-14"
version: "1.0.0"
author: "Équipe MCP"
---
<!-- END_SECTION: metadata -->

# Installation du serveur MCP QuickFiles

<!-- START_SECTION: prerequisites -->
## Prérequis

Avant d'installer le serveur MCP QuickFiles, assurez-vous que votre système répond aux exigences suivantes :

- **Node.js** : Version 14.x ou supérieure
- **npm** : Version 6.x ou supérieure
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

Naviguez vers le répertoire du serveur QuickFiles et installez les dépendances :

```bash
cd servers/quickfiles-server
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

Vous pouvez également installer le serveur QuickFiles directement via npm :

```bash
npm install @modelcontextprotocol/server-quickfiles
```

### Installation avec Docker

Une image Docker est disponible pour faciliter le déploiement :

```bash
# Construire l'image Docker
docker build -t quickfiles-mcp-server .

# Exécuter le conteneur
docker run -p 3000:3000 -v /chemin/vers/fichiers:/data quickfiles-mcp-server
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
QuickFiles MCP Server - Test de connexion
✓ Connexion au serveur MCP établie
✓ Liste des outils disponibles récupérée
✓ Lecture de fichiers multiples réussie
✓ Listage de répertoire réussi
Test terminé avec succès!
```

Si vous voyez cette sortie, le serveur QuickFiles est correctement installé et fonctionnel.
<!-- END_SECTION: verification -->

<!-- START_SECTION: post_installation -->
## Configuration post-installation

### Autorisations de fichiers

Le serveur QuickFiles nécessite des autorisations de lecture et d'écriture sur les répertoires qu'il doit manipuler. Assurez-vous que l'utilisateur qui exécute le serveur dispose des permissions nécessaires.

### Configuration du pare-feu

Si vous prévoyez d'accéder au serveur QuickFiles depuis d'autres machines, assurez-vous que le port utilisé (par défaut 3000) est ouvert dans votre pare-feu.

### Configuration de l'environnement de production

Pour un environnement de production, il est recommandé de :

1. Configurer un proxy inverse (comme Nginx ou Apache) devant le serveur QuickFiles
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

#### Erreur de port déjà utilisé

**Problème** : Le port 3000 est déjà utilisé par une autre application.

**Solution** :
- Modifiez le port utilisé par le serveur QuickFiles dans le fichier de configuration
- Arrêtez l'application qui utilise déjà le port 3000
- Utilisez la commande `netstat -ano | findstr :3000` (Windows) ou `lsof -i :3000` (Linux/macOS) pour identifier l'application qui utilise le port

#### Erreur de permissions

**Problème** : Erreurs liées aux permissions lors de l'accès aux fichiers.

**Solution** :
- Vérifiez que l'utilisateur qui exécute le serveur a les permissions nécessaires sur les répertoires concernés
- Exécutez le serveur avec des privilèges plus élevés si nécessaire (non recommandé pour la production)
- Modifiez les permissions des répertoires concernés
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: next_steps -->
## Prochaines étapes

Maintenant que vous avez installé le serveur QuickFiles, vous pouvez :

1. [Configurer le serveur](CONFIGURATION.md) selon vos besoins
2. [Apprendre à utiliser le serveur](USAGE.md) avec des exemples pratiques
3. [Consulter le guide de dépannage](TROUBLESHOOTING.md) en cas de problèmes
4. [Explorer les cas d'utilisation avancés](../docs/quickfiles-use-cases.md) pour tirer le meilleur parti du serveur
<!-- END_SECTION: next_steps -->

<!-- START_SECTION: navigation -->
## Navigation

- [Index principal](../../../INDEX.md)
- [Index des MCPs internes](../../INDEX.md)
- [Documentation QuickFiles](./README.md)
- [Configuration](./CONFIGURATION.md)
- [Utilisation](./USAGE.md)
- [Dépannage](./TROUBLESHOOTING.md)
- [Guide de recherche](../../../SEARCH.md)
<!-- END_SECTION: navigation -->