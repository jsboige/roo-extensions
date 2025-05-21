# Installation du MCP GitHub

<!-- START_SECTION: prerequisites -->
## Prérequis

Avant d'installer le MCP GitHub, assurez-vous que les éléments suivants sont installés et configurés sur votre système:

- **Node.js**: Version 14.0.0 ou supérieure - [Installation officielle de Node.js](https://nodejs.org/)
- **npm**: Version 6.0.0 ou supérieure (généralement installé avec Node.js)
- **Roo**: Version compatible avec les MCPs externes
- **Compte GitHub**: Un compte GitHub actif avec un token d'accès personnel (PAT)
<!-- END_SECTION: prerequisites -->

<!-- START_SECTION: installation_methods -->
## Méthodes d'installation

Il existe plusieurs méthodes pour installer le MCP GitHub:

1. [Installation globale via npm](#installation-globale)
2. [Installation locale dans un projet](#installation-locale)
3. [Installation depuis les sources](#installation-depuis-les-sources)
<!-- END_SECTION: installation_methods -->

<!-- START_SECTION: global_installation -->
## Installation globale

La méthode la plus simple pour installer le MCP GitHub est de l'installer globalement via npm:

```bash
npm install -g @modelcontextprotocol/server-github
```

Cette commande installe le serveur MCP GitHub globalement sur votre système, le rendant disponible pour tous les projets.

Après l'installation, vous pouvez vérifier que le serveur est correctement installé en exécutant:

```bash
npx @modelcontextprotocol/server-github --version
```

Vous devriez voir la version du serveur MCP GitHub s'afficher.
<!-- END_SECTION: global_installation -->

<!-- START_SECTION: local_installation -->
## Installation locale

Si vous préférez installer le MCP GitHub localement dans un projet spécifique:

1. Naviguez vers le répertoire de votre projet:

```bash
cd /chemin/vers/votre/projet
```

2. Installez le package localement:

```bash
npm install @modelcontextprotocol/server-github
```

3. Vous pouvez maintenant exécuter le serveur MCP GitHub depuis le répertoire de votre projet:

```bash
npx @modelcontextprotocol/server-github
```

Cette approche est utile si vous souhaitez utiliser une version spécifique du MCP GitHub pour un projet particulier.
<!-- END_SECTION: local_installation -->

<!-- START_SECTION: source_installation -->
## Installation depuis les sources

Pour les utilisateurs avancés qui souhaitent personnaliser l'installation ou contribuer au développement:

1. Clonez le dépôt GitHub:

```bash
git clone https://github.com/modelcontextprotocol/servers.git
cd servers/src/github
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

Cette méthode vous permet de modifier le code source et de personnaliser le serveur MCP GitHub selon vos besoins.
<!-- END_SECTION: source_installation -->

<!-- START_SECTION: github_token -->
## Création d'un token d'accès personnel GitHub

Le MCP GitHub nécessite un token d'accès personnel (PAT) GitHub pour interagir avec l'API GitHub. Voici comment en créer un:

1. Connectez-vous à votre compte GitHub

2. Accédez aux paramètres de votre compte en cliquant sur votre photo de profil en haut à droite, puis sur "Settings"

3. Dans le menu de gauche, cliquez sur "Developer settings"

4. Cliquez sur "Personal access tokens", puis sur "Tokens (classic)"

5. Cliquez sur "Generate new token", puis sur "Generate new token (classic)"

6. Donnez un nom descriptif à votre token, par exemple "Roo MCP GitHub"

7. Sélectionnez les autorisations (scopes) nécessaires:
   - `repo`: Accès complet aux dépôts publics et privés
   - `workflow`: Accès aux actions GitHub (si nécessaire)
   - `read:org`: Lecture des informations sur les organisations (si nécessaire)
   - `gist`: Accès aux gists (si nécessaire)

8. Cliquez sur "Generate token"

9. **Important**: Copiez le token généré et conservez-le en lieu sûr. Vous ne pourrez plus le voir après avoir quitté cette page.

> **Note**: Accordez uniquement les permissions minimales nécessaires pour des raisons de sécurité. Si vous n'avez besoin que d'accéder à des dépôts publics, vous pouvez limiter les autorisations en conséquence.
<!-- END_SECTION: github_token -->

<!-- START_SECTION: verification -->
## Vérification de l'installation

Pour vérifier que le MCP GitHub est correctement installé:

1. Exécutez le serveur MCP GitHub avec l'option `--help`:

```bash
npx @modelcontextprotocol/server-github --help
```

Vous devriez voir s'afficher les options disponibles pour le serveur.

2. Testez le serveur en le démarrant avec votre token GitHub:

```bash
npx @modelcontextprotocol/server-github --token votre_token_github
```

Le serveur devrait démarrer et afficher un message indiquant qu'il est en attente de connexions.

3. Vérifiez que le serveur peut se connecter à l'API GitHub:

```bash
# Dans un autre terminal
curl -X POST http://localhost:3000/mcp/v1/tools/search_repositories -H "Content-Type: application/json" -d '{"query": "modelcontextprotocol"}'
```

Si tout est correctement configuré, vous devriez recevoir une réponse JSON contenant les résultats de la recherche.
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
  sudo npm install -g @modelcontextprotocol/server-github
  ```

- **Erreur de dépendances**: Mettez à jour npm à la dernière version
  ```bash
  npm install -g npm@latest
  ```

- **Erreur d'authentification GitHub**: Vérifiez que votre token d'accès personnel est valide et dispose des autorisations nécessaires
  ```bash
  curl -H "Authorization: token votre_token_github" https://api.github.com/user
  ```

- **Erreur de connexion à l'API GitHub**: Vérifiez votre connexion Internet et les éventuelles restrictions de pare-feu

Pour plus de détails sur la résolution des problèmes, consultez le fichier [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: next_steps -->
## Prochaines étapes

Maintenant que vous avez installé le MCP GitHub, vous pouvez:

1. [Configurer le MCP GitHub](./CONFIGURATION.md)
2. [Apprendre à utiliser le MCP GitHub](./USAGE.md)
3. [Explorer les cas d'utilisation avancés](./USAGE.md#cas-dutilisation-avancés)
<!-- END_SECTION: next_steps -->