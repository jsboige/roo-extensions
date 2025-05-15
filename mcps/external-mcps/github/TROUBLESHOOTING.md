# Résolution des problèmes du MCP GitHub

<!-- START_SECTION: introduction -->
## Introduction

Ce document fournit des solutions aux problèmes courants rencontrés lors de l'utilisation du MCP GitHub avec Roo. Si vous rencontrez des difficultés, consultez les sections ci-dessous pour trouver des solutions.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: installation_issues -->
## Problèmes d'installation

### Le package ne s'installe pas correctement

**Symptôme**: Erreurs lors de l'installation du package `@modelcontextprotocol/server-github`.

**Solutions possibles**:

1. **Vérifiez la version de Node.js**:
   ```bash
   node --version
   ```
   Assurez-vous d'utiliser Node.js v14.0.0 ou supérieur.

2. **Mettez à jour npm**:
   ```bash
   npm install -g npm@latest
   ```

3. **Problèmes de permissions**:
   - Sur Linux/macOS:
     ```bash
     sudo npm install -g @modelcontextprotocol/server-github
     ```
   - Sur Windows, exécutez PowerShell en tant qu'administrateur

4. **Problèmes de dépendances**:
   ```bash
   npm cache clean --force
   npm install -g @modelcontextprotocol/server-github
   ```

5. **Erreurs de compilation**:
   - Sur Linux/macOS:
     ```bash
     sudo apt-get install build-essential  # Pour Ubuntu/Debian
     ```
   - Sur Windows:
     ```bash
     npm install --global --production windows-build-tools
     ```

### Le serveur MCP ne se lance pas après l'installation

**Symptôme**: Le serveur MCP GitHub ne démarre pas après l'installation.

**Solutions possibles**:

1. **Vérifiez l'installation**:
   ```bash
   npx @modelcontextprotocol/server-github --version
   ```

2. **Installez localement dans le projet**:
   ```bash
   cd /chemin/vers/votre/projet
   npm install @modelcontextprotocol/server-github
   npx @modelcontextprotocol/server-github
   ```

3. **Vérifiez les conflits de version**:
   ```bash
   npm list -g | grep modelcontextprotocol
   ```
   Désinstallez les versions conflictuelles si nécessaire.
<!-- END_SECTION: installation_issues -->

<!-- START_SECTION: authentication_issues -->
## Problèmes d'authentification

### Erreur "Bad credentials"

**Symptôme**: Erreur "Bad credentials" lors de l'utilisation du MCP GitHub.

**Solutions possibles**:

1. **Vérifiez que votre token est valide**:
   ```bash
   curl -H "Authorization: token votre_token_github" https://api.github.com/user
   ```
   Vous devriez recevoir vos informations utilisateur si le token est valide.

2. **Vérifiez que le token est correctement configuré**:
   - Assurez-vous que le token est correctement spécifié dans la configuration
   - Vérifiez qu'il n'y a pas d'espaces ou de caractères supplémentaires

3. **Renouvelez votre token**:
   - Accédez à GitHub > Settings > Developer settings > Personal access tokens
   - Révoquez l'ancien token et créez-en un nouveau
   - Mettez à jour la configuration avec le nouveau token

4. **Vérifiez les permissions du token**:
   - Assurez-vous que le token a les permissions nécessaires pour les opérations que vous essayez d'effectuer
   - Pour les opérations sur les dépôts privés, le token doit avoir la permission `repo`

### Erreur "Token scopes required"

**Symptôme**: Erreur indiquant que le token ne dispose pas des permissions nécessaires.

**Solutions possibles**:

1. **Vérifiez les permissions requises**:
   - Pour les opérations sur les dépôts privés: `repo`
   - Pour les opérations sur les gists: `gist`
   - Pour les opérations sur les organisations: `read:org`, `admin:org`, etc.
   - Pour les opérations sur les workflows: `workflow`

2. **Créez un nouveau token avec les permissions appropriées**:
   - Accédez à GitHub > Settings > Developer settings > Personal access tokens
   - Cliquez sur "Generate new token"
   - Sélectionnez toutes les permissions nécessaires
   - Mettez à jour la configuration avec le nouveau token

3. **Utilisez un token différent pour différentes opérations**:
   - Créez plusieurs instances du MCP GitHub avec des tokens différents
   - Utilisez le token approprié pour chaque type d'opération
<!-- END_SECTION: authentication_issues -->

<!-- START_SECTION: rate_limit_issues -->
## Problèmes de limites de taux

### Erreur "API rate limit exceeded"

**Symptôme**: Erreur indiquant que vous avez dépassé la limite de taux de l'API GitHub.

**Solutions possibles**:

1. **Vérifiez votre statut de limite de taux**:
   ```bash
   curl -H "Authorization: token votre_token_github" https://api.github.com/rate_limit
   ```
   Cette commande affiche vos limites actuelles et le temps restant avant réinitialisation.

2. **Utilisez un token authentifié**:
   - Les requêtes authentifiées ont des limites plus élevées (5000 requêtes par heure) que les requêtes non authentifiées (60 requêtes par heure)
   - Assurez-vous que votre token est correctement configuré

3. **Optimisez vos requêtes**:
   - Regroupez plusieurs opérations en une seule requête lorsque c'est possible
   - Mettez en cache les résultats pour éviter des requêtes répétées
   - Utilisez des requêtes conditionnelles avec `If-None-Match` et `If-Modified-Since`

4. **Utilisez la stratégie de recul exponentiel**:
   - Configurez le MCP GitHub pour utiliser une stratégie de recul exponentiel:
     ```json
     "args": [
       "-y",
       "@modelcontextprotocol/server-github",
       "--token",
       "votre_token_github",
       "--rate-limit-strategy=exponential-backoff"
     ]
     ```

5. **Attendez la réinitialisation des limites**:
   - Les limites de taux sont réinitialisées toutes les heures
   - Vous pouvez voir le temps restant avant réinitialisation dans la réponse à `/rate_limit`
<!-- END_SECTION: rate_limit_issues -->

<!-- START_SECTION: operation_issues -->
## Problèmes d'opérations GitHub

### Erreur lors de la création ou mise à jour de fichiers

**Symptôme**: Erreur lors de l'utilisation de `create_or_update_file` ou `push_files`.

**Solutions possibles**:

1. **Vérifiez les permissions du token**:
   - Le token doit avoir la permission `repo` pour les dépôts privés
   - Pour les dépôts publics, `public_repo` peut suffire

2. **Vérifiez que le dépôt existe**:
   ```bash
   curl -H "Authorization: token votre_token_github" https://api.github.com/repos/owner/repo
   ```

3. **Vérifiez que la branche existe**:
   ```bash
   curl -H "Authorization: token votre_token_github" https://api.github.com/repos/owner/repo/branches/branch
   ```

4. **Pour la mise à jour, fournissez le SHA correct**:
   - Obtenez d'abord le SHA du fichier existant:
     ```bash
     curl -H "Authorization: token votre_token_github" https://api.github.com/repos/owner/repo/contents/path/to/file
     ```
   - Utilisez ce SHA dans votre requête de mise à jour

5. **Vérifiez le format du contenu**:
   - Le contenu doit être encodé en Base64 (le MCP GitHub le fait automatiquement)
   - Assurez-vous que le contenu est valide

### Erreur lors de la création d'issues ou de pull requests

**Symptôme**: Erreur lors de l'utilisation de `create_issue` ou `create_pull_request`.

**Solutions possibles**:

1. **Vérifiez que le dépôt existe et que vous avez les permissions**:
   ```bash
   curl -H "Authorization: token votre_token_github" https://api.github.com/repos/owner/repo
   ```

2. **Pour les pull requests, vérifiez que les branches existent**:
   ```bash
   curl -H "Authorization: token votre_token_github" https://api.github.com/repos/owner/repo/branches/head
   curl -H "Authorization: token votre_token_github" https://api.github.com/repos/owner/repo/branches/base
   ```

3. **Vérifiez que les branches sont différentes**:
   - La branche `head` et la branche `base` doivent être différentes
   - Assurez-vous qu'il y a des commits différents entre les deux branches

4. **Vérifiez le format des arguments**:
   - Assurez-vous que tous les champs requis sont fournis
   - Vérifiez que les valeurs sont du bon type (chaînes, nombres, etc.)

### Erreur "Not Found" pour les ressources

**Symptôme**: Erreur 404 "Not Found" lors de l'accès à des ressources GitHub.

**Solutions possibles**:

1. **Vérifiez l'orthographe du propriétaire et du dépôt**:
   - Les noms sont sensibles à la casse
   - Assurez-vous qu'il n'y a pas de fautes de frappe

2. **Vérifiez que la ressource existe**:
   - Pour les fichiers: utilisez `get_file_contents` pour vérifier l'existence
   - Pour les issues/PR: utilisez `get_issue` ou `get_pull_request` pour vérifier l'existence

3. **Vérifiez les permissions**:
   - Assurez-vous que votre token a accès à la ressource
   - Pour les dépôts privés, le token doit avoir la permission `repo`

4. **Vérifiez que vous êtes connecté au bon compte**:
   ```bash
   curl -H "Authorization: token votre_token_github" https://api.github.com/user
   ```
   Vérifiez que le compte retourné est celui qui a accès à la ressource.
<!-- END_SECTION: operation_issues -->

<!-- START_SECTION: connection_issues -->
## Problèmes de connexion

### Erreur de connexion à l'API GitHub

**Symptôme**: Erreurs de connexion ou timeouts lors des requêtes à l'API GitHub.

**Solutions possibles**:

1. **Vérifiez votre connexion Internet**:
   ```bash
   ping api.github.com
   ```

2. **Vérifiez que l'API GitHub est opérationnelle**:
   - Consultez [GitHub Status](https://www.githubstatus.com/)
   - Vérifiez si d'autres services GitHub fonctionnent

3. **Problèmes de proxy ou de pare-feu**:
   - Si vous êtes derrière un proxy, configurez-le correctement:
     ```json
     "env": {
       "HTTP_PROXY": "http://proxy.exemple.com:8080",
       "HTTPS_PROXY": "http://proxy.exemple.com:8080"
     }
     ```
   - Vérifiez que votre pare-feu autorise les connexions à `api.github.com`

4. **Problèmes de DNS**:
   - Essayez d'utiliser un serveur DNS alternatif
   - Videz le cache DNS de votre système

5. **Utilisez une stratégie de retry**:
   - Configurez le MCP GitHub pour réessayer automatiquement en cas d'échec:
     ```json
     "args": [
       "-y",
       "@modelcontextprotocol/server-github",
       "--token",
       "votre_token_github",
       "--retry-count=3",
       "--retry-delay=1000"
     ]
     ```

### Erreur "Connection refused" ou "Connection timed out"

**Symptôme**: Erreur indiquant que la connexion a été refusée ou a expiré.

**Solutions possibles**:

1. **Vérifiez votre connexion Internet**:
   - Assurez-vous que vous êtes connecté à Internet
   - Essayez d'accéder à d'autres sites web

2. **Vérifiez les restrictions réseau**:
   - Certains réseaux d'entreprise bloquent l'accès à GitHub
   - Consultez votre administrateur réseau

3. **Utilisez un VPN** si nécessaire:
   - Si votre réseau bloque GitHub, essayez d'utiliser un VPN
   - Assurez-vous que le VPN est correctement configuré

4. **Augmentez le timeout**:
   ```json
   "args": [
     "-y",
     "@modelcontextprotocol/server-github",
     "--token",
     "votre_token_github",
     "--timeout=30000"
   ]
   ```
<!-- END_SECTION: connection_issues -->

<!-- START_SECTION: configuration_issues -->
## Problèmes de configuration

### Le serveur MCP ne démarre pas

**Symptôme**: Le serveur MCP GitHub ne démarre pas ou se termine immédiatement.

**Solutions possibles**:

1. **Vérifiez la configuration MCP**:
   - Assurez-vous que le fichier de configuration MCP contient l'entrée correcte pour le MCP GitHub
   - Vérifiez que le chemin vers le fichier de configuration est correct

2. **Vérifiez les arguments de ligne de commande**:
   - Assurez-vous que les arguments sont correctement formatés
   - Vérifiez qu'il n'y a pas d'arguments contradictoires

3. **Vérifiez les variables d'environnement**:
   - Assurez-vous que les variables d'environnement sont correctement définies
   - Vérifiez qu'il n'y a pas de conflits entre les variables d'environnement et les arguments

4. **Exécutez le serveur en mode débogage**:
   ```bash
   npx @modelcontextprotocol/server-github --debug --token votre_token_github
   ```
   Examinez les messages d'erreur pour identifier le problème.

### Erreur "Invalid token"

**Symptôme**: Erreur indiquant que le token GitHub est invalide.

**Solutions possibles**:

1. **Vérifiez le format du token**:
   - Les tokens GitHub commencent généralement par `ghp_`, `gho_`, `ghu_`, ou `ghs_`
   - Assurez-vous qu'il n'y a pas d'espaces ou de caractères supplémentaires

2. **Vérifiez que le token n'est pas expiré**:
   - Les tokens peuvent avoir une date d'expiration
   - Vérifiez la date d'expiration dans les paramètres GitHub

3. **Vérifiez que le token n'a pas été révoqué**:
   - Accédez à GitHub > Settings > Developer settings > Personal access tokens
   - Vérifiez que le token est toujours listé

4. **Créez un nouveau token** si nécessaire:
   - Accédez à GitHub > Settings > Developer settings > Personal access tokens
   - Cliquez sur "Generate new token"
   - Sélectionnez les permissions nécessaires
   - Mettez à jour la configuration avec le nouveau token
<!-- END_SECTION: configuration_issues -->

<!-- START_SECTION: advanced_troubleshooting -->
## Dépannage avancé

### Déboguer le serveur MCP GitHub

Pour déboguer le serveur MCP GitHub:

1. **Démarrez le serveur en mode débogage**:
   ```bash
   npx @modelcontextprotocol/server-github --debug --log-level=debug --token votre_token_github
   ```

2. **Examinez les logs**:
   - Les logs seront affichés dans la console
   - Recherchez les erreurs ou avertissements

3. **Utilisez des variables d'environnement de débogage**:
   ```bash
   export MCP_GITHUB_DEBUG=true
   export MCP_GITHUB_LOG_LEVEL=debug
   npx @modelcontextprotocol/server-github --token votre_token_github
   ```

### Déboguer les requêtes API

Pour déboguer les requêtes à l'API GitHub:

1. **Utilisez l'option `--verbose`**:
   ```bash
   npx @modelcontextprotocol/server-github --verbose --token votre_token_github
   ```
   Cette option affiche les détails des requêtes HTTP.

2. **Utilisez un proxy de débogage** comme [Fiddler](https://www.telerik.com/fiddler) ou [Charles](https://www.charlesproxy.com/):
   ```json
   "env": {
     "HTTP_PROXY": "http://localhost:8888",
     "HTTPS_PROXY": "http://localhost:8888"
   }
   ```
   Configurez le proxy pour intercepter les requêtes HTTP/HTTPS.

3. **Testez les requêtes manuellement** avec curl:
   ```bash
   curl -v -H "Authorization: token votre_token_github" https://api.github.com/user
   ```
   Comparez les résultats avec ceux du MCP GitHub.

### Analyser les problèmes de performance

Si le MCP GitHub est lent:

1. **Vérifiez les limites de taux**:
   ```bash
   curl -H "Authorization: token votre_token_github" https://api.github.com/rate_limit
   ```
   Si vous approchez de la limite, les requêtes peuvent être ralenties.

2. **Optimisez vos requêtes**:
   - Utilisez la pagination pour récupérer uniquement les données nécessaires
   - Mettez en cache les résultats fréquemment utilisés
   - Utilisez des requêtes conditionnelles avec `If-None-Match` et `If-Modified-Since`

3. **Vérifiez votre connexion réseau**:
   ```bash
   ping api.github.com
   traceroute api.github.com
   ```
   Des latences élevées peuvent affecter les performances.
<!-- END_SECTION: advanced_troubleshooting -->

<!-- START_SECTION: common_errors -->
## Erreurs courantes

### "Not Found"

**Cause**: La ressource demandée n'existe pas ou vous n'avez pas les permissions pour y accéder.

**Solutions**:
- Vérifiez l'orthographe du propriétaire et du dépôt
- Vérifiez que la ressource existe
- Vérifiez que votre token a les permissions nécessaires

### "Bad credentials"

**Cause**: Le token GitHub est invalide, expiré ou révoqué.

**Solutions**:
- Vérifiez que le token est correctement configuré
- Créez un nouveau token si nécessaire
- Vérifiez que le token a les permissions nécessaires

### "Validation Failed"

**Cause**: Les données fournies ne sont pas valides selon les règles de l'API GitHub.

**Solutions**:
- Vérifiez le format des arguments
- Assurez-vous que tous les champs requis sont fournis
- Vérifiez les contraintes spécifiques (longueur maximale, caractères autorisés, etc.)

### "API rate limit exceeded"

**Cause**: Vous avez dépassé la limite de taux de l'API GitHub.

**Solutions**:
- Attendez la réinitialisation des limites
- Utilisez un token authentifié pour bénéficier de limites plus élevées
- Optimisez vos requêtes pour en réduire le nombre

### "Resource not accessible by integration"

**Cause**: Le token n'a pas accès à la ressource demandée.

**Solutions**:
- Vérifiez les permissions du token
- Assurez-vous que le token appartient au bon compte
- Pour les organisations, vérifiez que le token a accès à l'organisation
<!-- END_SECTION: common_errors -->

<!-- START_SECTION: getting_help -->
## Obtenir de l'aide

Si vous ne parvenez pas à résoudre votre problème avec les solutions ci-dessus:

1. **Consultez la documentation officielle**:
   - [Documentation de l'API GitHub](https://docs.github.com/en/rest)
   - [Documentation du Model Context Protocol](https://github.com/modelcontextprotocol/mcp)
   - [Documentation de Roo](https://docs.roo.ai)

2. **Communauté et forums**:
   - [Forum de la communauté Roo](https://community.roo.ai)
   - [GitHub Community Forum](https://github.community/)
   - [Stack Overflow - Tag GitHub API](https://stackoverflow.com/questions/tagged/github-api)

3. **Signaler un bug**:
   - Ouvrez une issue sur le dépôt GitHub du MCP GitHub
   - Incluez des informations détaillées sur le problème, les étapes pour le reproduire et les logs pertinents
<!-- END_SECTION: getting_help -->