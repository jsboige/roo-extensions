# Installation du MCP Git

<!-- START_SECTION: prerequisites -->
## Prérequis

Avant d'installer le MCP Git, assurez-vous que les éléments suivants sont installés et configurés sur votre système:

- **Git**: Version 2.20.0 ou supérieure - [Installation officielle de Git](https://git-scm.com/downloads)
- **Node.js**: Version 14.0.0 ou supérieure - [Installation officielle de Node.js](https://nodejs.org/)
- **npm**: Version 6.0.0 ou supérieure (généralement installé avec Node.js)
- **Roo**: Version compatible avec les MCPs externes
<!-- END_SECTION: prerequisites -->

<!-- START_SECTION: installation_methods -->
## Méthodes d'installation

Il existe plusieurs méthodes pour installer le MCP Git:

1. [Installation globale via npm](#installation-globale)
2. [Installation locale dans un projet](#installation-locale)
3. [Installation depuis les sources](#installation-depuis-les-sources)
<!-- END_SECTION: installation_methods -->

<!-- START_SECTION: global_installation -->
## Installation globale

La méthode la plus simple pour installer le MCP Git est de l'installer globalement via npm:

```bash
npm install -g @modelcontextprotocol/server-git
```

Cette commande installe le serveur MCP Git globalement sur votre système, le rendant disponible pour tous les projets.

Après l'installation, vous pouvez vérifier que le serveur est correctement installé en exécutant:

```bash
npx @modelcontextprotocol/server-git --version
```

Vous devriez voir la version du serveur MCP Git s'afficher.
<!-- END_SECTION: global_installation -->

<!-- START_SECTION: local_installation -->
## Installation locale

Si vous préférez installer le MCP Git localement dans un projet spécifique:

1. Naviguez vers le répertoire de votre projet:

```bash
cd /chemin/vers/votre/projet
```

2. Installez le package localement:

```bash
npm install @modelcontextprotocol/server-git
```

3. Vous pouvez maintenant exécuter le serveur MCP Git depuis le répertoire de votre projet:

```bash
npx @modelcontextprotocol/server-git
```

Cette approche est utile si vous souhaitez utiliser une version spécifique du MCP Git pour un projet particulier.
<!-- END_SECTION: local_installation -->

<!-- START_SECTION: source_installation -->
## Installation depuis les sources

Pour les utilisateurs avancés qui souhaitent personnaliser l'installation ou contribuer au développement:

1. Clonez le dépôt GitHub:

```bash
git clone https://github.com/modelcontextprotocol/servers.git
cd servers/src/git
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

Cette méthode vous permet de modifier le code source et de personnaliser le serveur MCP Git selon vos besoins.
<!-- END_SECTION: source_installation -->

<!-- START_SECTION: git_configuration -->
## Configuration de Git

Le MCP Git utilise la configuration Git de votre système. Assurez-vous que Git est correctement configuré:

1. Configurez votre identité Git si ce n'est pas déjà fait:

```bash
git config --global user.name "Votre Nom"
git config --global user.email "votre.email@exemple.com"
```

2. Configurez l'authentification pour les dépôts distants:

   - **HTTPS**: Configurez un gestionnaire d'informations d'identification pour stocker vos identifiants:
     ```bash
     # Sur Windows
     git config --global credential.helper wincred
     
     # Sur macOS
     git config --global credential.helper osxkeychain
     
     # Sur Linux
     git config --global credential.helper store
     ```

   - **SSH**: Générez et configurez des clés SSH:
     ```bash
     ssh-keygen -t ed25519 -C "votre.email@exemple.com"
     # Suivez les instructions pour générer la clé
     # Ajoutez la clé à votre agent SSH
     ssh-add ~/.ssh/id_ed25519
     ```

3. Vérifiez votre configuration Git:

```bash
git config --list
```
<!-- END_SECTION: git_configuration -->

<!-- START_SECTION: verification -->
## Vérification de l'installation

Pour vérifier que le MCP Git est correctement installé:

1. Exécutez le serveur MCP Git avec l'option `--help`:

```bash
npx @modelcontextprotocol/server-git --help
```

Vous devriez voir s'afficher les options disponibles pour le serveur.

2. Testez le serveur en le démarrant:

```bash
npx @modelcontextprotocol/server-git
```

Le serveur devrait démarrer et afficher un message indiquant qu'il est en attente de connexions.

3. Vérifiez que Git est accessible depuis le MCP:

```bash
git --version
```

Cette commande devrait afficher la version de Git installée sur votre système.
<!-- END_SECTION: verification -->

<!-- START_SECTION: troubleshooting -->
## Résolution des problèmes d'installation

Si vous rencontrez des problèmes lors de l'installation:

- **Erreur de version Node.js**: Assurez-vous d'utiliser une version compatible de Node.js
  ```bash
  node --version
  ```

- **Erreur de version Git**: Assurez-vous d'utiliser une version compatible de Git
  ```bash
  git --version
  ```

- **Erreur de permissions npm**: Sur Linux/macOS, vous devrez peut-être utiliser `sudo` pour l'installation globale
  ```bash
  sudo npm install -g @modelcontextprotocol/server-git
  ```

- **Erreur de dépendances**: Mettez à jour npm à la dernière version
  ```bash
  npm install -g npm@latest
  ```

- **Git non trouvé dans le PATH**: Assurez-vous que Git est correctement installé et accessible dans le PATH
  ```bash
  # Vérifiez le chemin de Git
  which git  # Sur Linux/macOS
  where git  # Sur Windows
  ```

Pour plus de détails sur la résolution des problèmes, consultez le fichier [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: next_steps -->
## Prochaines étapes

Maintenant que vous avez installé le MCP Git, vous pouvez:

1. [Configurer le MCP Git](./CONFIGURATION.md)
2. [Apprendre à utiliser le MCP Git](./USAGE.md)
3. [Explorer les cas d'utilisation avancés](./USAGE.md#cas-dutilisation-avancés)
<!-- END_SECTION: next_steps -->