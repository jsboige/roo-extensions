# Résolution des problèmes du MCP SearXNG

<!-- START_SECTION: introduction -->
## Introduction

Ce document fournit des solutions aux problèmes courants rencontrés lors de l'utilisation du MCP SearXNG avec Roo. Si vous rencontrez des difficultés, consultez les sections ci-dessous pour trouver des solutions.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: installation_issues -->
## Problèmes d'installation

### Le serveur ne démarre pas

**Symptôme**: Le serveur MCP SearXNG ne démarre pas ou se termine immédiatement après le démarrage.

**Solutions possibles**:

1. **Vérifiez que Node.js est correctement installé**:
   ```bash
   node --version
   ```
   Assurez-vous d'utiliser Node.js v16.0.0 ou supérieur.

2. **Vérifiez que npm est correctement installé**:
   ```bash
   npm --version
   ```

3. **Problèmes avec les scripts de lancement**:
   Les scripts de lancement (`mcp-searxng`, `mcp-searxng.cmd`, `mcp-searxng.ps1`) peuvent être corrompus ou vides. Dans ce cas, utilisez la méthode d'exécution directe avec Node.js:
   ```bash
   # Sur Windows
   node "%APPDATA%\npm\node_modules\mcp-searxng\dist\index.js"
   
   # Sur macOS/Linux
   node "$(npm root -g)/mcp-searxng/dist/index.js"
   ```

4. **Réinstallez le package**:
   ```bash
   npm uninstall -g mcp-searxng
   npm cache clean --force
   npm install -g mcp-searxng
   ```

5. **Vérifiez les permissions**:
   - Sur Linux/macOS, vous devrez peut-être utiliser `sudo` pour l'installation globale
   - Sur Windows, exécutez PowerShell ou CMD en tant qu'administrateur

### Erreurs lors de l'installation

**Symptôme**: Erreurs lors de l'installation du package `mcp-searxng`.

**Solutions possibles**:

1. **Erreurs de dépendances**:
   ```bash
   npm cache clean --force
   npm install -g mcp-searxng
   ```

2. **Problèmes de réseau**:
   - Vérifiez votre connexion Internet
   - Si vous êtes derrière un proxy, configurez npm pour l'utiliser:
     ```bash
     npm config set proxy http://proxy.example.com:8080
     npm config set https-proxy http://proxy.example.com:8080
     ```

3. **Problèmes de permissions**:
   - Sur Linux/macOS:
     ```bash
     sudo npm install -g mcp-searxng
     ```
   - Sur Windows, exécutez PowerShell ou CMD en tant qu'administrateur
<!-- END_SECTION: installation_issues -->

<!-- START_SECTION: configuration_issues -->
## Problèmes de configuration

### Le serveur n'est pas détecté par Roo

**Symptôme**: Le serveur MCP SearXNG démarre mais n'est pas détecté par Roo.

**Solutions possibles**:

1. **Vérifiez la configuration dans Roo**:
   - Assurez-vous que le nom du serveur est correctement défini comme `searxng`
   - Vérifiez que la commande et les arguments sont corrects
   - Assurez-vous que le serveur est activé (`enabled: true`)

2. **Problèmes de chemin**:
   - Assurez-vous que les chemins dans la configuration sont absolus et corrects
   - Sur Windows, n'utilisez pas la variable `%APPDATA%` car elle n'est pas interprétée correctement
   - Utilisez des doubles barres obliques inverses (`\\`) ou des barres obliques simples (`/`) dans les chemins Windows

3. **Redémarrez VS Code**:
   - Fermez et redémarrez VS Code pour recharger la configuration MCP

4. **Vérifiez les journaux de Roo**:
   - Examinez les journaux de Roo pour voir s'il y a des erreurs de connexion au serveur MCP

### Problèmes avec le fichier de configuration personnalisé

**Symptôme**: Le serveur ne prend pas en compte votre configuration personnalisée.

**Solutions possibles**:

1. **Vérifiez le chemin du fichier de configuration**:
   - Assurez-vous que le fichier est à l'emplacement correct:
     - Windows: `%USERPROFILE%\.mcp-searxng\config.json`
     - macOS/Linux: `~/.mcp-searxng/config.json`

2. **Vérifiez la syntaxe JSON**:
   - Assurez-vous que votre fichier JSON est valide
   - Utilisez un validateur JSON en ligne pour vérifier la syntaxe

3. **Spécifiez explicitement le fichier de configuration**:
   ```bash
   mcp-searxng --config /chemin/vers/votre/config.json
   ```

4. **Créez le répertoire parent si nécessaire**:
   ```bash
   # Sur Windows
   mkdir "%USERPROFILE%\.mcp-searxng"
   
   # Sur macOS/Linux
   mkdir -p ~/.mcp-searxng
   ```
<!-- END_SECTION: configuration_issues -->

<!-- START_SECTION: search_issues -->
## Problèmes de recherche

### Les recherches échouent

**Symptôme**: Les recherches avec `searxng_web_search` échouent ou ne renvoient pas de résultats.

**Solutions possibles**:

1. **Vérifiez votre connexion Internet**:
   - Assurez-vous que vous êtes connecté à Internet
   - Essayez d'accéder à l'instance SearXNG directement dans votre navigateur

2. **Problèmes d'accès à l'instance SearXNG**:
   - Certaines instances SearXNG peuvent être temporairement indisponibles
   - Essayez une autre instance dans votre configuration:
     ```json
     {
       "searxng": {
         "instance": "https://search.mdosch.de"
       }
     }
     ```

3. **Problèmes de proxy ou de pare-feu**:
   - Certains réseaux peuvent bloquer l'accès aux instances SearXNG
   - Configurez un proxy si nécessaire:
     ```json
     {
       "proxy": {
         "url": "http://proxy.example.com:8080"
       }
     }
     ```

4. **Augmentez le timeout**:
   - Si l'instance est lente, augmentez la valeur de timeout:
     ```json
     {
       "searxng": {
         "timeout": 20000
       }
     }
     ```

### Résultats non pertinents

**Symptôme**: Les résultats de recherche ne sont pas pertinents ou ne correspondent pas à ce que vous cherchez.

**Solutions possibles**:

1. **Affinez votre requête**:
   - Utilisez des termes plus spécifiques
   - Utilisez des guillemets pour les expressions exactes: `"expression exacte"`
   - Utilisez des opérateurs comme `site:`, `intitle:`, etc.

2. **Utilisez des filtres**:
   - Spécifiez une langue: `language: "fr"`
   - Limitez la période: `time_range: "month"`
   - Ajustez le niveau de SafeSearch: `safesearch: "0"`

3. **Essayez une autre instance SearXNG**:
   - Différentes instances peuvent avoir des configurations différentes
   - Certaines instances peuvent avoir des moteurs de recherche différents activés
<!-- END_SECTION: search_issues -->

<!-- START_SECTION: content_issues -->
## Problèmes de lecture de contenu

### Erreurs lors de la lecture d'URL

**Symptôme**: L'outil `web_url_read` échoue ou renvoie des erreurs.

**Solutions possibles**:

1. **Vérifiez que l'URL est accessible**:
   - Essayez d'ouvrir l'URL dans votre navigateur
   - Certains sites peuvent bloquer les requêtes automatisées

2. **Problèmes de contenu dynamique**:
   - Certains sites utilisent JavaScript pour charger le contenu
   - Le MCP SearXNG ne peut pas exécuter JavaScript, donc le contenu peut être incomplet

3. **Problèmes de blocage**:
   - Certains sites bloquent les requêtes en fonction du User-Agent
   - Essayez de modifier le User-Agent dans la configuration:
     ```json
     {
       "searxng": {
         "userAgent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
       }
     }
     ```

4. **Problèmes de timeout**:
   - Si le site est lent, augmentez la valeur de timeout:
     ```json
     {
       "searxng": {
         "timeout": 20000
       }
     }
     ```

### Contenu incomplet ou mal formaté

**Symptôme**: Le contenu renvoyé par `web_url_read` est incomplet ou mal formaté.

**Solutions possibles**:

1. **Limitations du parser HTML**:
   - Le MCP SearXNG utilise un parser HTML simple qui peut avoir des difficultés avec certains sites
   - Essayez une autre URL avec un contenu similaire

2. **Sites avec protection anti-bot**:
   - Certains sites utilisent des techniques pour détecter et bloquer les bots
   - Ces sites peuvent renvoyer un contenu différent ou incomplet

3. **Contenu derrière un paywall ou une connexion**:
   - Certains sites nécessitent une connexion ou un abonnement
   - Le MCP SearXNG ne peut pas accéder à ce contenu
<!-- END_SECTION: content_issues -->

<!-- START_SECTION: performance_issues -->
## Problèmes de performance

### Recherches lentes

**Symptôme**: Les recherches prennent beaucoup de temps à s'exécuter.

**Solutions possibles**:

1. **Instance SearXNG surchargée**:
   - Essayez une autre instance SearXNG
   - Utilisez la rotation d'instances:
     ```json
     {
       "searxng": {
         "instances": [
           "https://searx.be",
           "https://search.mdosch.de",
           "https://search.disroot.org"
         ],
         "rotationStrategy": "round-robin"
       }
     }
     ```

2. **Problèmes de connexion Internet**:
   - Vérifiez votre connexion Internet
   - Si vous êtes sur un réseau lent, augmentez le timeout

3. **Trop de résultats demandés**:
   - Limitez le nombre de résultats par page:
     ```json
     {
       "limits": {
         "resultsPerPage": 5
       }
     }
     ```

### Consommation excessive de ressources

**Symptôme**: Le serveur MCP SearXNG consomme beaucoup de CPU ou de mémoire.

**Solutions possibles**:

1. **Limitez les requêtes concurrentes**:
   ```json
   {
     "limits": {
       "concurrentRequests": 1
     }
   }
   ```

2. **Limitez le taux de requêtes**:
   ```json
   {
     "limits": {
       "requestsPerMinute": 5
     }
   }
   ```

3. **Redémarrez régulièrement le serveur**:
   - Si le serveur est utilisé pendant de longues périodes, redémarrez-le périodiquement
<!-- END_SECTION: performance_issues -->

<!-- START_SECTION: advanced_troubleshooting -->
## Dépannage avancé

### Journalisation détaillée

Pour obtenir plus d'informations sur les problèmes, activez la journalisation détaillée:

```json
{
  "logging": {
    "level": "debug",
    "file": "searxng-mcp.log"
  }
}
```

Cela créera un fichier journal détaillé que vous pourrez consulter pour diagnostiquer les problèmes.

### Débogage des requêtes

Pour déboguer les requêtes envoyées à l'instance SearXNG:

1. **Activez le mode débogage**:
   ```bash
   mcp-searxng --debug
   ```

2. **Examinez les requêtes HTTP**:
   - Utilisez un proxy de débogage comme [Fiddler](https://www.telerik.com/fiddler) ou [Charles](https://www.charlesproxy.com/)
   - Configurez le proxy dans la configuration:
     ```json
     {
       "proxy": {
         "url": "http://localhost:8888"
       }
     }
     ```

3. **Testez directement l'API SearXNG**:
   - Utilisez un outil comme curl ou Postman pour tester directement l'API SearXNG
   - Comparez les résultats avec ceux du MCP SearXNG

### Problèmes avec des instances spécifiques

Si vous rencontrez des problèmes avec une instance SearXNG spécifique:

1. **Vérifiez le statut de l'instance**:
   - Certaines instances peuvent être temporairement indisponibles
   - Consultez la page d'état de l'instance si disponible

2. **Vérifiez les limitations de l'instance**:
   - Certaines instances peuvent avoir des limitations de taux ou d'autres restrictions
   - Consultez la documentation de l'instance pour plus d'informations

3. **Hébergez votre propre instance**:
   - Si vous avez besoin d'une instance fiable, envisagez d'héberger votre propre instance SearXNG
   - Configurez le MCP SearXNG pour utiliser votre instance locale
<!-- END_SECTION: advanced_troubleshooting -->

<!-- START_SECTION: common_errors -->
## Erreurs courantes

### "Cannot connect to SearXNG instance"

**Cause**: Le serveur MCP SearXNG ne peut pas se connecter à l'instance SearXNG spécifiée.

**Solutions**:
- Vérifiez que l'instance est accessible dans votre navigateur
- Essayez une autre instance
- Vérifiez votre connexion Internet
- Vérifiez les paramètres de proxy de votre réseau

### "Request timed out"

**Cause**: La requête à l'instance SearXNG a pris trop de temps.

**Solutions**:
- Augmentez la valeur de timeout dans la configuration
- Essayez une autre instance qui pourrait être plus rapide
- Vérifiez votre connexion Internet

### "No results found"

**Cause**: L'instance SearXNG n'a pas trouvé de résultats pour votre requête.

**Solutions**:
- Simplifiez votre requête
- Essayez des termes de recherche différents
- Essayez une autre instance qui pourrait avoir accès à plus de moteurs de recherche

### "Invalid configuration"

**Cause**: Le fichier de configuration contient des erreurs.

**Solutions**:
- Vérifiez la syntaxe JSON de votre fichier de configuration
- Assurez-vous que toutes les valeurs sont du bon type
- Consultez la documentation pour les options de configuration valides
<!-- END_SECTION: common_errors -->

<!-- START_SECTION: getting_help -->
## Obtenir de l'aide

Si vous ne parvenez pas à résoudre votre problème avec les solutions ci-dessus:

1. **Consultez la documentation officielle**:
   - [Documentation officielle de SearXNG](https://docs.searxng.org/)
   - [Dépôt GitHub de SearXNG](https://github.com/searxng/searxng)

2. **Communauté et forums**:
   - [Forum de la communauté Roo](https://community.roo.ai)
   - [GitHub Issues de SearXNG](https://github.com/searxng/searxng/issues)

3. **Signaler un bug**:
   - Ouvrez une issue sur le dépôt GitHub du MCP SearXNG
   - Incluez des informations détaillées sur le problème, les étapes pour le reproduire et les logs pertinents
<!-- END_SECTION: getting_help -->