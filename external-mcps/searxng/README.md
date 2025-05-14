# SearXNG MCP pour Roo

Ce dossier contient la documentation et les instructions pour l'installation et la configuration du serveur MCP SearXNG utilisé avec Roo.

## Qu'est-ce que SearXNG ?

SearXNG est un métamoteur de recherche libre et open source qui agrège les résultats de plus de 70 services de recherche différents. Il respecte la vie privée des utilisateurs en ne stockant pas d'informations personnelles et en ne partageant pas les requêtes avec les moteurs de recherche tiers.

Le serveur MCP SearXNG permet à Roo d'effectuer des recherches web et d'accéder aux résultats directement depuis l'interface de conversation.

## Fonctionnalités principales

- Recherche web via de nombreux moteurs de recherche
- Respect de la vie privée (pas de suivi, pas de publicités)
- Filtrage des résultats par date, langue, etc.
- Lecture du contenu des URLs trouvées

## Outils disponibles

Le serveur MCP SearXNG fournit les outils suivants :

1. **searxng_web_search** - Effectue une recherche web et renvoie les résultats
2. **web_url_read** - Lit le contenu d'une URL spécifique

## Prérequis

- Node.js (version 16 ou supérieure)
- npm (généralement installé avec Node.js)
- Une connexion Internet

## Installation

Consultez le fichier [installation.md](./installation.md) pour les instructions détaillées d'installation.

## Structure du dossier

- `README.md` - Ce fichier d'introduction
- `installation.md` - Guide d'installation du serveur MCP SearXNG
- `configuration.md` - Guide de configuration du serveur MCP SearXNG
- `exemples.md` - Exemples d'utilisation du serveur MCP SearXNG
- `run-searxng.bat` - Script batch pour lancer facilement le serveur MCP SearXNG sous Windows
- `mcp-config-example.json` - Exemple de configuration MCP pour Roo

## Configuration dans Roo

### ⚠️ Points importants à noter

1. **Nom du serveur** : Utilisez un nom simple comme "searxng" plutôt qu'un chemin GitHub complet comme "github.com/ihor-sokoliuk/mcp-searxng" pour éviter les problèmes de configuration.
2. **Évitez le suffixe "-global"** : N'ajoutez pas "-global" au nom du serveur, car cela peut causer des problèmes de reconnaissance.
3. **Chemins absolus** : Utilisez des chemins absolus pour les fichiers, pas des variables d'environnement comme `%APPDATA%`.
4. **Problèmes avec les scripts de lancement** : Les scripts de lancement (`mcp-searxng`, `mcp-searxng.cmd`, `mcp-searxng.ps1`) peuvent être corrompus ou vides. Utilisez la méthode d'exécution directe avec Node.js comme décrit ci-dessous.

### Configuration recommandée (utilisant le script batch)

```json
{
  "searxng": {
    "command": "cmd",
    "args": [
      "/c",
      "D:\\chemin\\vers\\external-mcps\\searxng\\run-searxng.bat"
    ],
    "env": {
      "SEARXNG_URL": "https://search.example.com/"
    },
    "disabled": false,
    "autoApprove": [],
    "alwaysAllow": [
      "searxng_web_search",
      "web_url_read"
    ],
    "transportType": "stdio"
  }
}
```

### Configuration alternative (exécution directe)

Si vous rencontrez des problèmes avec le script batch, vous pouvez utiliser cette configuration alternative qui exécute directement le fichier JavaScript du serveur :

```json
{
  "searxng": {
    "command": "cmd",
    "args": [
      "/c",
      "node",
      "C:\\Users\\<username>\\AppData\\Roaming\\npm\\node_modules\\mcp-searxng\\dist\\index.js"
    ],
    "env": {
      "SEARXNG_URL": "https://search.example.com/"
    },
    "disabled": false,
    "autoApprove": [],
    "alwaysAllow": [
      "searxng_web_search",
      "web_url_read"
    ],
    "transportType": "stdio"
  }
}
```

> **Important** : Remplacez `<username>` par votre nom d'utilisateur Windows et `https://search.example.com/` par l'URL de l'instance SearXNG que vous souhaitez utiliser.

## Utilisation

Consultez le fichier [exemples.md](./exemples.md) pour des exemples concrets d'utilisation du serveur MCP SearXNG avec Roo.

### Exemples rapides

#### Effectuer une recherche web

```
use_mcp_tool
server_name: searxng
tool_name: searxng_web_search
arguments: {
  "query": "intelligence artificielle actualités",
  "language": "fr",
  "time_range": "month"
}
```

#### Lire le contenu d'une URL

```
use_mcp_tool
server_name: searxng
tool_name: web_url_read
arguments: {
  "url": "https://example.com/article"
}
```

## Résolution des problèmes

### Le serveur ne démarre pas

- Vérifiez que Node.js est correctement installé : `node --version`
- Vérifiez que npm est correctement installé : `npm --version`
- Essayez d'installer le package globalement : `npm install -g mcp-searxng`
- Vérifiez les journaux d'erreur dans la console
- **Solution au problème courant** : Utilisez la méthode d'exécution directe avec Node.js comme décrit dans la section "Configuration alternative".

### Problèmes de configuration dans Roo

1. **Problème** : Erreur "Server not found" ou "Tool not found"
   **Solution** : Assurez-vous que le nom du serveur dans la configuration est simple (ex: "searxng") et non un chemin complet.

2. **Problème** : Erreur "Command not found"
   **Solution** : Utilisez la configuration alternative avec le chemin complet vers le fichier JavaScript.

### Les recherches échouent

- Vérifiez votre connexion Internet
- Assurez-vous que l'instance SearXNG est accessible (essayez d'y accéder directement dans votre navigateur)
- Essayez une autre instance SearXNG en modifiant la variable d'environnement `SEARXNG_URL`
- Augmentez la valeur de timeout dans la configuration

## Liens utiles

- [Dépôt GitHub de SearXNG](https://github.com/searxng/searxng)
- [Documentation officielle de SearXNG](https://docs.searxng.org/)
- [Liste d'instances SearXNG publiques](https://searx.space/)