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

## Structure du dossier

- `README.md` - Ce fichier d'introduction
- `installation.md` - Guide d'installation du serveur MCP SearXNG
- `configuration.md` - Guide de configuration du serveur MCP SearXNG
- `exemples.md` - Exemples d'utilisation du serveur MCP SearXNG
- `run-searxng.bat` - Script batch pour lancer facilement le serveur MCP SearXNG sous Windows
- `mcp-config-example.json` - Exemple de configuration MCP pour Roo

## Configuration rapide

Si vous rencontrez des problèmes avec la commande `mcp-searxng`, vous pouvez utiliser la configuration alternative suivante :

1. Ouvrez le fichier de configuration MCP de Roo situé à :
   - Windows : `C:\Users\<username>\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json` (remplacez `<username>` par votre nom d'utilisateur Windows)
   - macOS/Linux : `~/.config/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json`

2. Remplacez la configuration du serveur "searxng" par celle fournie dans le fichier `mcp-config-example.json`

3. Redémarrez VS Code pour appliquer les changements

Cette configuration exécute directement le fichier JavaScript du serveur MCP SearXNG avec Node.js, contournant ainsi les problèmes potentiels avec les scripts de lancement.

> **Important** : N'utilisez pas la variable d'environnement `%APPDATA%` dans les chemins de configuration MCP car elle n'est pas interprétée correctement dans ce contexte. Utilisez toujours le chemin absolu complet (par exemple `C:\Users\<username>\AppData\Roaming\...`).

## Liens utiles

- [Dépôt GitHub de SearXNG](https://github.com/searxng/searxng)
- [Documentation officielle de SearXNG](https://docs.searxng.org/)