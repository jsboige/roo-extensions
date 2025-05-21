# Installation du MCP Docker

<!-- START_SECTION: prerequisites -->
## Prérequis

Avant d'installer le MCP Docker, assurez-vous que les éléments suivants sont installés et configurés sur votre système:

- **Docker**: [Installation officielle de Docker](https://docs.docker.com/get-docker/)
- **Git**: [Installation officielle de Git](https://git-scm.com/downloads)
- **Node.js**: Version 14.0.0 ou supérieure
- **PowerShell**: Version 5.1 ou supérieure (pour Windows)
<!-- END_SECTION: prerequisites -->

<!-- START_SECTION: installation_methods -->
## Méthodes d'installation

Il existe plusieurs méthodes pour installer le MCP Docker:

1. [Installation automatisée avec le script PowerShell](#installation-automatisée)
2. [Installation manuelle](#installation-manuelle)
3. [Installation depuis les sources](#installation-depuis-les-sources)
<!-- END_SECTION: installation_methods -->

<!-- START_SECTION: automated_installation -->
## Installation automatisée

Le moyen le plus simple d'installer le MCP Docker est d'utiliser le script PowerShell fourni:

1. Ouvrez PowerShell en tant qu'administrateur
2. Naviguez vers le répertoire contenant le script
3. Exécutez le script:

```powershell
.\build-mcp-server-docker.ps1
```

4. Suivez les instructions à l'écran

Le script effectuera automatiquement les opérations suivantes:
- Vérification des prérequis
- Clonage du dépôt GitHub de ckreiling/mcp-server-docker
- Construction de l'image Docker localement
- Vérification de l'image
- Mise à jour de la configuration MCP (si vous le souhaitez)
<!-- END_SECTION: automated_installation -->

<!-- START_SECTION: manual_installation -->
## Installation manuelle

Si vous préférez installer manuellement le MCP Docker:

1. Clonez le dépôt GitHub:

```bash
git clone https://github.com/ckreiling/mcp-server-docker.git
cd mcp-server-docker
```

2. Construisez l'image Docker:

```bash
docker build -t mcp-server:local .
```

3. Vérifiez que l'image a été correctement construite:

```bash
docker images | grep mcp-server
```

4. Configurez le MCP dans votre configuration Roo (voir [Configuration](./CONFIGURATION.md))
<!-- END_SECTION: manual_installation -->

<!-- START_SECTION: source_installation -->
## Installation depuis les sources

Pour les utilisateurs avancés qui souhaitent personnaliser l'installation:

1. Clonez le dépôt GitHub:

```bash
git clone https://github.com/ckreiling/mcp-server-docker.git
cd mcp-server-docker
```

2. Modifiez le Dockerfile selon vos besoins

3. Construisez l'image Docker avec un tag personnalisé:

```bash
docker build -t mcp-server:custom .
```

4. Configurez le MCP dans votre configuration Roo en utilisant votre tag personnalisé
<!-- END_SECTION: source_installation -->

<!-- START_SECTION: verification -->
## Vérification de l'installation

Pour vérifier que le MCP Docker est correctement installé:

1. Vérifiez que l'image Docker est présente:

```bash
docker images | grep mcp-server
```

2. Testez le serveur MCP en le démarrant manuellement:

```bash
docker run -i --rm -v /var/run/docker.sock:/var/run/docker.sock mcp-server:local
```

Vous devriez voir un message indiquant que le serveur MCP est en cours d'exécution.

3. Dans Roo, vérifiez que le serveur MCP est connecté en exécutant une commande Docker simple.
<!-- END_SECTION: verification -->

<!-- START_SECTION: troubleshooting -->
## Résolution des problèmes d'installation

Si vous rencontrez des problèmes lors de l'installation:

- **Docker n'est pas en cours d'exécution**: Démarrez Docker Desktop ou le service Docker
- **Erreur de clonage du dépôt**: Vérifiez votre connexion Internet et que l'URL du dépôt est correcte
- **Erreur de construction de l'image**: Vérifiez que Docker a suffisamment de ressources (mémoire, espace disque)
- **Erreur de mise à jour de la configuration**: Vérifiez que le chemin vers le fichier de configuration MCP est correct

Pour plus de détails sur la résolution des problèmes, consultez le fichier [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: next_steps -->
## Prochaines étapes

Maintenant que vous avez installé le MCP Docker, vous pouvez:

1. [Configurer le MCP Docker](./CONFIGURATION.md)
2. [Apprendre à utiliser le MCP Docker](./USAGE.md)
3. [Explorer les cas d'utilisation avancés](./USAGE.md#cas-dutilisation-avancés)
<!-- END_SECTION: next_steps -->