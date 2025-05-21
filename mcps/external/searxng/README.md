# MCP SearXNG pour Roo

<!-- START_SECTION: introduction -->
## Introduction

Le MCP SearXNG permet à Roo d'effectuer des recherches web et d'accéder au contenu des pages via le protocole MCP (Model Context Protocol). Il utilise SearXNG, un métamoteur de recherche libre et open source qui agrège les résultats de plus de 70 services de recherche différents tout en respectant la vie privée des utilisateurs.

Ce MCP est essentiel pour permettre à Roo d'accéder à des informations en ligne à jour, de faire des recherches sur divers sujets et d'analyser le contenu des pages web, le tout directement depuis l'interface de conversation.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: features -->
## Fonctionnalités principales

- **Recherche web privée**: Effectue des recherches sans suivre l'utilisateur ni partager ses requêtes
- **Agrégation de résultats**: Combine les résultats de nombreux moteurs de recherche
- **Filtrage des résultats**: Filtre par date, langue, SafeSearch et autres critères
- **Lecture de contenu**: Accède au contenu des pages web trouvées
- **Personnalisation**: Utilise différentes instances SearXNG selon vos préférences
- **Respect de la vie privée**: Ne stocke pas d'informations personnelles
<!-- END_SECTION: features -->

<!-- START_SECTION: tools -->
## Outils disponibles

Le MCP SearXNG expose les outils suivants:

| Outil | Description |
|-------|-------------|
| `searxng_web_search` | Effectue une recherche web et renvoie les résultats |
| `web_url_read` | Lit le contenu d'une URL spécifique |

Pour une description détaillée de chaque outil et des exemples d'utilisation, consultez le fichier [USAGE.md](./USAGE.md).
<!-- END_SECTION: tools -->

<!-- START_SECTION: structure -->
## Structure de la documentation

- [README.md](./README.md) - Ce fichier d'introduction
- [INSTALLATION.md](./INSTALLATION.md) - Guide d'installation du MCP SearXNG
- [CONFIGURATION.md](./CONFIGURATION.md) - Guide de configuration du MCP SearXNG
- [USAGE.md](./USAGE.md) - Exemples d'utilisation et bonnes pratiques
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - Résolution des problèmes courants
- [run-searxng.bat](./run-searxng.bat) - Script batch pour lancer facilement le serveur MCP SearXNG sous Windows
- [mcp-config-example.json](./mcp-config-example.json) - Exemple de configuration MCP pour Roo
<!-- END_SECTION: structure -->

<!-- START_SECTION: quick_start -->
## Démarrage rapide

1. **Installation**:
   ```bash
   # Via NPX (recommandé)
   npx mcp-searxng
   
   # Ou installation globale
   npm install -g mcp-searxng
   ```

2. **Configuration**:
   Ajoutez la configuration suivante à votre fichier `mcp_settings.json`:
   ```json
   {
     "mcpServers": [
       {
         "name": "searxng",
         "type": "stdio",
         "command": "cmd",
         "args": ["/c", "mcp-searxng"],
         "enabled": true,
         "autoStart": true,
         "description": "Serveur MCP SearXNG pour les recherches web"
       }
     ]
   }
   ```

3. **Utilisation**:
   Redémarrez VS Code et commencez à utiliser les outils de recherche dans Roo.

Pour des instructions détaillées, consultez les fichiers [INSTALLATION.md](./INSTALLATION.md) et [CONFIGURATION.md](./CONFIGURATION.md).
<!-- END_SECTION: quick_start -->

<!-- START_SECTION: use_cases -->
## Cas d'utilisation

Le MCP SearXNG est particulièrement utile pour:

- **Recherche d'informations**: Trouver rapidement des informations sur divers sujets
- **Veille technologique**: Suivre les dernières actualités et tendances
- **Recherche académique**: Trouver des articles scientifiques et des publications
- **Analyse de contenu**: Extraire et analyser le contenu de pages web
- **Vérification de faits**: Rechercher des sources pour vérifier des informations
- **Exploration de sujets**: Découvrir de nouvelles ressources sur un sujet d'intérêt

Pour des exemples détaillés, consultez le fichier [USAGE.md](./USAGE.md#cas-dutilisation).
<!-- END_SECTION: use_cases -->

<!-- START_SECTION: integration -->
## Intégration avec Roo

Le MCP SearXNG s'intègre parfaitement avec Roo, permettant des interactions naturelles en langage courant. Voici quelques exemples de demandes que vous pouvez faire à Roo:

- "Recherche des informations sur l'intelligence artificielle"
- "Trouve des articles récents sur le changement climatique"
- "Cherche des tutoriels Python sur GitHub"
- "Lis le contenu de cette page web: https://example.com/article"
- "Trouve des articles scientifiques sur la fusion nucléaire publiés cette année"

Roo traduira automatiquement ces demandes en appels aux outils appropriés du MCP SearXNG.
<!-- END_SECTION: integration -->

<!-- START_SECTION: privacy -->
## Respect de la vie privée

SearXNG est conçu pour respecter la vie privée des utilisateurs:

- **Pas de suivi**: SearXNG ne stocke pas d'informations personnelles
- **Pas de partage**: Les requêtes ne sont pas partagées avec les moteurs de recherche tiers
- **Pas de publicités**: Aucune publicité ciblée basée sur vos recherches
- **Chiffrement**: Utilisation de HTTPS pour sécuriser les communications
- **Instances multiples**: Possibilité d'utiliser différentes instances SearXNG, y compris les vôtres

Ces caractéristiques font du MCP SearXNG une solution idéale pour effectuer des recherches web tout en préservant votre confidentialité.
<!-- END_SECTION: privacy -->

<!-- START_SECTION: configuration_alternative -->
## Configuration alternative

Si vous rencontrez des problèmes avec la commande `mcp-searxng`, vous pouvez utiliser la configuration alternative suivante:

1. Ouvrez le fichier de configuration MCP de Roo situé à:
   - Windows: `C:\Users\<username>\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json` (remplacez `<username>` par votre nom d'utilisateur Windows)
   - macOS/Linux: `~/.config/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json`

2. Remplacez la configuration du serveur "searxng" par celle fournie dans le fichier `mcp-config-example.json`

3. Redémarrez VS Code pour appliquer les changements

Cette configuration exécute directement le fichier JavaScript du serveur MCP SearXNG avec Node.js, contournant ainsi les problèmes potentiels avec les scripts de lancement.

> **Important**: N'utilisez pas la variable d'environnement `%APPDATA%` dans les chemins de configuration MCP car elle n'est pas interprétée correctement dans ce contexte. Utilisez toujours le chemin absolu complet (par exemple `C:\Users\<username>\AppData\Roaming\...`).
<!-- END_SECTION: configuration_alternative -->

<!-- START_SECTION: troubleshooting -->
## Résolution des problèmes

Si vous rencontrez des problèmes avec le MCP SearXNG:

- **Le serveur ne démarre pas**: Vérifiez l'installation de Node.js et npm
- **Erreurs de recherche**: Essayez une autre instance SearXNG
- **Résultats non pertinents**: Affinez votre requête avec des termes plus spécifiques
- **Problèmes de lecture d'URL**: Certains sites peuvent bloquer les requêtes automatisées

Pour une résolution plus détaillée des problèmes, consultez le fichier [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: links -->
## Liens utiles

- [Dépôt GitHub de SearXNG](https://github.com/searxng/searxng)
- [Documentation officielle de SearXNG](https://docs.searxng.org/)
- [Liste d'instances SearXNG publiques](https://searx.space/)
- [Spécification du Model Context Protocol](https://github.com/modelcontextprotocol/mcp)
- [Documentation de Roo](https://docs.roo.ai)
<!-- END_SECTION: links -->