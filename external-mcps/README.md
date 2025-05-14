# MCPs Externes pour Roo

Ce dossier contient la documentation et les instructions pour l'installation et la configuration des serveurs MCP (Model Context Protocol) externes utilisés avec Roo.

## Qu'est-ce qu'un MCP ?

Le Model Context Protocol (MCP) est un protocole qui permet à Roo de communiquer avec des serveurs externes pour étendre ses capacités. Ces serveurs peuvent fournir des outils supplémentaires et des ressources qui ne sont pas disponibles nativement dans Roo.

## MCPs Externes vs MCPs Internes

Les MCPs externes sont des outils tiers qui ont été adaptés pour fonctionner avec Roo. Ils nécessitent une installation et une configuration spécifiques, généralement via npm ou d'autres gestionnaires de paquets. Contrairement aux [MCPs internes](../internal-mcps/README.md) qui sont développés spécifiquement pour Roo dans des dépôts dédiés, les MCPs externes sont maintenus par des tiers et peuvent être utilisés indépendamment de Roo.

## Structure du dossier

Ce dossier est organisé par serveur MCP externe :

- `git-mcp/` - Documentation pour le serveur MCP Git (opérations Git locales)
- `github-mcp/` - Documentation pour le serveur MCP GitHub (API GitHub)
- `searxng/` - Documentation pour le serveur MCP SearXNG (recherche web)
- `win-cli/` - Documentation pour le serveur MCP Win-CLI (commandes Windows)

Chaque sous-dossier contient :
- Un guide d'installation
- Un guide de configuration
- Des exemples d'utilisation
- Des notes sur les personnalisations spécifiques

## Pièges courants à éviter lors de la configuration des MCPs

### 1. Problèmes de nommage des serveurs

#### ⚠️ Évitez les noms de serveurs avec chemins complets

**Problème** : Utiliser des noms de serveurs avec des chemins GitHub complets comme `github.com/modelcontextprotocol/servers/tree/main/src/git` au lieu de noms simples comme `git`.

**Solution** : Utilisez toujours des noms simples et descriptifs pour vos serveurs MCP dans la configuration de Roo. Par exemple, utilisez `git`, `github`, `searxng`, `win-cli`, etc.

#### ⚠️ Évitez le suffixe "-global"

**Problème** : Ajouter le suffixe "-global" aux noms des serveurs MCP (par exemple, `git-global` au lieu de `git`).

**Solution** : N'ajoutez jamais le suffixe "-global" aux noms des serveurs MCP, car cela peut causer des problèmes de reconnaissance par Roo.

### 2. Problèmes de chemins

#### ⚠️ Évitez les variables d'environnement dans les chemins

**Problème** : Utiliser des variables d'environnement comme `%APPDATA%` dans les chemins de configuration MCP.

**Solution** : Utilisez toujours des chemins absolus complets (par exemple, `C:\Users\username\AppData\Roaming\...`).

#### ⚠️ Attention aux barres obliques dans les chemins Windows

**Problème** : Utiliser des barres obliques simples (`\`) dans les chemins Windows, ce qui peut causer des problèmes d'échappement.

**Solution** : Doublez toujours les barres obliques inverses (`\\`) dans les chemins Windows ou utilisez des barres obliques normales (`/`).

### 3. Problèmes d'installation

#### ⚠️ Scripts de lancement corrompus ou vides

**Problème** : Les scripts de lancement (`mcp-searxng`, `git-mcp-server`, etc.) peuvent être corrompus ou vides après l'installation.

**Solution** : Utilisez la méthode d'exécution directe avec Node.js en spécifiant le chemin complet vers le fichier JavaScript du serveur.

#### ⚠️ Dépendances manquantes

**Problème** : Certaines dépendances peuvent ne pas être installées automatiquement.

**Solution** : Vérifiez les prérequis dans la documentation de chaque MCP et installez manuellement les dépendances manquantes.

### 4. Problèmes de sécurité

#### ⚠️ Tokens et informations sensibles exposés

**Problème** : Stocker des tokens d'API et autres informations sensibles en clair dans les fichiers de configuration.

**Solution** : Utilisez des variables d'environnement ou des fichiers de configuration séparés pour les informations sensibles, et ne les partagez jamais dans des dépôts publics.

## Serveurs MCP disponibles

### Git MCP

Git MCP est un serveur MCP qui permet à Roo d'interagir avec des dépôts Git locaux. Il offre des fonctionnalités pour effectuer des opérations Git courantes comme commit, push, pull, branch, status, diff, etc. Ce serveur est particulièrement utile pour automatiser les workflows Git et intégrer la gestion de version dans les tâches de développement.

### GitHub MCP

GitHub MCP est un serveur MCP qui permet à Roo d'interagir avec l'API GitHub. Il offre des fonctionnalités pour la gestion des dépôts, des issues, des pull requests, et d'autres ressources GitHub. Ce serveur est utile pour automatiser les workflows GitHub et intégrer GitHub dans les tâches de développement.

### SearXNG

SearXNG est un métamoteur de recherche qui permet d'effectuer des recherches web via différents moteurs de recherche. Le serveur MCP SearXNG permet à Roo d'effectuer des recherches web et d'accéder aux résultats.

### Win-CLI

Win-CLI est un serveur MCP qui permet à Roo d'exécuter des commandes dans différents shells Windows (PowerShell, CMD, Git Bash). Il offre également des fonctionnalités pour la gestion des connexions SSH.

## Guide rapide de configuration

### 1. Installation des serveurs MCP

Consultez les guides d'installation spécifiques dans chaque sous-dossier pour des instructions détaillées.

### 2. Configuration dans Roo

1. Ouvrez le fichier de configuration MCP de Roo situé à :
   - Windows : `C:\Users\<username>\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`
   - macOS/Linux : `~/.config/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json`

2. Ajoutez ou modifiez les configurations des serveurs MCP en suivant les exemples fournis dans chaque sous-dossier.

3. Redémarrez VS Code pour appliquer les changements.

### 3. Vérification de la configuration

Pour vérifier que vos serveurs MCP sont correctement configurés, ouvrez Roo et utilisez la commande suivante :

```
Quels serveurs MCP sont actuellement connectés ?
```

Roo devrait lister tous les serveurs MCP configurés et leur état de connexion.

## Comment ajouter un nouveau serveur MCP

Pour ajouter un nouveau serveur MCP à cette documentation :

1. Créez un nouveau sous-dossier avec le nom du serveur MCP
2. Ajoutez un fichier `README.md` décrivant le serveur MCP
3. Ajoutez un guide d'installation (`installation.md`)
4. Ajoutez un guide de configuration (`configuration.md`)
5. Ajoutez des exemples d'utilisation (`exemples.md`)
6. Mettez à jour ce fichier README.md pour inclure le nouveau serveur MCP

## Contribution

N'hésitez pas à contribuer à cette documentation en ajoutant de nouveaux serveurs MCP ou en améliorant la documentation existante.