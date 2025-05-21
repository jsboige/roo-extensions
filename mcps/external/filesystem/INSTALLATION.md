# Installation du MCP Filesystem

<!-- START_SECTION: prerequisites -->
## Prérequis

Avant d'installer le MCP Filesystem, assurez-vous que les éléments suivants sont installés et configurés sur votre système:

- **Node.js**: Version 14.0.0 ou supérieure
- **npm**: Version 6.0.0 ou supérieure
- **Roo**: Version compatible avec les MCPs externes
<!-- END_SECTION: prerequisites -->

<!-- START_SECTION: installation_methods -->
## Méthodes d'installation

Il existe plusieurs méthodes pour installer le MCP Filesystem:

1. [Installation globale via npm](#installation-globale)
2. [Installation locale dans un projet](#installation-locale)
3. [Installation depuis les sources](#installation-depuis-les-sources)
<!-- END_SECTION: installation_methods -->

<!-- START_SECTION: global_installation -->
## Installation globale

La méthode la plus simple pour installer le MCP Filesystem est de l'installer globalement via npm:

```bash
npm install -g @modelcontextprotocol/server-filesystem
```

Cette commande installe le serveur MCP Filesystem globalement sur votre système, le rendant disponible pour tous les projets.

Après l'installation, vous pouvez vérifier que le serveur est correctement installé en exécutant:

```bash
npx @modelcontextprotocol/server-filesystem --version
```

Vous devriez voir la version du serveur MCP Filesystem s'afficher.
<!-- END_SECTION: global_installation -->

<!-- START_SECTION: local_installation -->
## Installation locale

Si vous préférez installer le MCP Filesystem localement dans un projet spécifique:

1. Naviguez vers le répertoire de votre projet:

```bash
cd /chemin/vers/votre/projet
```

2. Installez le package localement:

```bash
npm install @modelcontextprotocol/server-filesystem
```

3. Vous pouvez maintenant exécuter le serveur MCP Filesystem depuis le répertoire de votre projet:

```bash
npx @modelcontextprotocol/server-filesystem
```

Cette approche est utile si vous souhaitez utiliser une version spécifique du MCP Filesystem pour un projet particulier.
<!-- END_SECTION: local_installation -->

<!-- START_SECTION: source_installation -->
## Installation depuis les sources

Pour les utilisateurs avancés qui souhaitent personnaliser l'installation ou contribuer au développement:

1. Clonez le dépôt GitHub:

```bash
git clone https://github.com/modelcontextprotocol/servers.git
cd servers/src/filesystem
```

2. Installez les dépendances:

```bash
npm install
```

3. Compilez le code source:

```bash
npm run build
```

4. Exécutez le serveur:

```bash
node dist/index.js
```

Cette méthode vous permet de modifier le code source et de personnaliser le serveur MCP Filesystem selon vos besoins.
<!-- END_SECTION: source_installation -->

<!-- START_SECTION: verification -->
## Vérification de l'installation

Pour vérifier que le MCP Filesystem est correctement installé:

1. Exécutez le serveur MCP Filesystem avec l'option `--help`:

```bash
npx @modelcontextprotocol/server-filesystem --help
```

Vous devriez voir s'afficher les options disponibles pour le serveur.

2. Testez le serveur en le démarrant avec un répertoire autorisé:

```bash
npx @modelcontextprotocol/server-filesystem /chemin/vers/repertoire/autorise
```

Le serveur devrait démarrer et afficher un message indiquant qu'il est en attente de connexions.
<!-- END_SECTION: verification -->

<!-- START_SECTION: troubleshooting -->
## Résolution des problèmes d'installation

Si vous rencontrez des problèmes lors de l'installation:

- **Erreur de version Node.js**: Assurez-vous d'utiliser une version compatible de Node.js
  ```bash
  node --version
  ```

- **Erreur de permissions npm**: Sur Linux/macOS, vous devrez peut-être utiliser `sudo` pour l'installation globale
  ```bash
  sudo npm install -g @modelcontextprotocol/server-filesystem
  ```

- **Erreur de dépendances**: Mettez à jour npm à la dernière version
  ```bash
  npm install -g npm@latest
  ```

- **Erreur de compilation**: Assurez-vous d'avoir les outils de développement nécessaires installés
  ```bash
  # Sur Ubuntu/Debian
  sudo apt-get install build-essential
  # Sur Windows
  npm install --global --production windows-build-tools
  ```

Pour plus de détails sur la résolution des problèmes, consultez le fichier [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: next_steps -->
## Prochaines étapes

Maintenant que vous avez installé le MCP Filesystem, vous pouvez:

1. [Configurer le MCP Filesystem](./CONFIGURATION.md)
2. [Apprendre à utiliser le MCP Filesystem](./USAGE.md)
3. [Explorer les cas d'utilisation avancés](./USAGE.md#cas-dutilisation-avancés)
<!-- END_SECTION: next_steps -->