# Guide de dépannage du serveur MCP JinaNavigator

<!-- START_SECTION: introduction -->
Ce guide de dépannage vous aidera à résoudre les problèmes courants rencontrés lors de l'utilisation du serveur MCP JinaNavigator. Il couvre les problèmes d'installation, de configuration, de connexion, et d'utilisation des différents outils.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: installation_issues -->
## Problèmes d'installation

### Erreur "Module not found"

**Symptôme** : Lors du démarrage du serveur, vous obtenez une erreur indiquant qu'un module n'a pas été trouvé.

```
Error: Cannot find module '@modelcontextprotocol/sdk'
```

**Causes possibles** :
- Les dépendances n'ont pas été installées correctement
- Le projet n'a pas été compilé après l'installation
- Le module est manquant dans le fichier package.json

**Solutions** :
1. Réinstallez les dépendances :
   ```bash
   npm ci
   ```

2. Si cela ne résout pas le problème, essayez une installation propre :
   ```bash
   rm -rf node_modules package-lock.json
   npm install
   ```

3. Vérifiez que le module est bien listé dans les dépendances du fichier package.json et ajoutez-le si nécessaire :
   ```bash
   npm install --save @modelcontextprotocol/sdk
   ```

4. Compilez le projet :
   ```bash
   npm run build
   ```

### Erreur de compilation TypeScript

**Symptôme** : Erreurs lors de la compilation du projet avec `npm run build`.

```
error TS2307: Cannot find module '@modelcontextprotocol/sdk' or its corresponding type declarations.
```

**Causes possibles** :
- Types TypeScript manquants
- Version incompatible de TypeScript
- Erreurs dans le code source

**Solutions** :
1. Installez les types manquants :
   ```bash
   npm install --save-dev @types/node
   ```

2. Vérifiez la version de TypeScript et mettez-la à jour si nécessaire :
   ```bash
   npm install --save-dev typescript@latest
   ```

3. Vérifiez les erreurs dans le code source et corrigez-les.

4. Si les erreurs persistent, essayez de réinitialiser la configuration TypeScript :
   ```bash
   rm tsconfig.json
   npx tsc --init
   ```
   Puis ajoutez les options nécessaires au nouveau fichier tsconfig.json.
<!-- END_SECTION: installation_issues -->

<!-- START_SECTION: startup_issues -->
## Problèmes de démarrage

### Le serveur ne démarre pas

**Symptôme** : Le serveur ne démarre pas ou se termine immédiatement après le démarrage.

**Causes possibles** :
- Port déjà utilisé
- Configuration incorrecte
- Erreurs dans le code

**Solutions** :
1. Vérifiez si le port est déjà utilisé :
   ```bash
   # Sur Windows
   netstat -ano | findstr :3000
   
   # Sur Linux/macOS
   lsof -i :3000
   ```
   Si le port est utilisé, changez le port dans la configuration ou arrêtez l'application qui l'utilise.

2. Vérifiez le fichier de configuration :
   ```bash
   cat config.json
   ```
   Assurez-vous que le format JSON est valide et que les options sont correctes.

3. Exécutez le serveur en mode debug pour voir les erreurs détaillées :
   ```bash
   node --inspect dist/index.js
   ```

4. Vérifiez les journaux pour plus de détails sur l'erreur :
   ```bash
   cat jinavigator.log
   ```

### Erreur "Address already in use"

**Symptôme** : Le serveur ne peut pas démarrer car le port est déjà utilisé.

```
Error: listen EADDRINUSE: address already in use :::3000
```

**Causes possibles** :
- Une autre instance du serveur est déjà en cours d'exécution
- Une autre application utilise le même port

**Solutions** :
1. Arrêtez l'application qui utilise le port :
   ```bash
   # Sur Windows
   FOR /F "tokens=5" %P IN ('netstat -ano ^| findstr :3000') DO taskkill /F /PID %P
   
   # Sur Linux/macOS
   kill $(lsof -t -i:3000)
   ```

2. Changez le port dans la configuration :
   ```json
   {
     "server": {
       "port": 3001
     }
   }
   ```

3. Démarrez le serveur avec un port différent :
   ```bash
   npm start -- --port 3001
   ```

### Erreur de connexion à l'API Jina

**Symptôme** : Le serveur démarre mais les outils ne fonctionnent pas, avec des erreurs de connexion à l'API Jina.

```
Error: Failed to connect to Jina API: connect ETIMEDOUT
```

**Causes possibles** :
- Problèmes de connexion Internet
- L'API Jina est indisponible
- Configuration incorrecte du proxy

**Solutions** :
1. Vérifiez votre connexion Internet.

2. Vérifiez si l'API Jina est accessible :
   ```bash
   curl -I https://r.jina.ai/
   ```

3. Si vous êtes derrière un proxy, configurez-le correctement :
   ```bash
   # Sur Linux/macOS
   export HTTP_PROXY=http://proxy.example.com:8080
   export HTTPS_PROXY=http://proxy.example.com:8080
   
   # Sur Windows
   set HTTP_PROXY=http://proxy.example.com:8080
   set HTTPS_PROXY=http://proxy.example.com:8080
   ```

4. Augmentez le timeout dans la configuration :
   ```json
   {
     "jina": {
       "timeout": 60000
     }
   }
   ```
<!-- END_SECTION: startup_issues -->

<!-- START_SECTION: connection_issues -->
## Problèmes de connexion

### Impossible de se connecter au serveur

**Symptôme** : Le client MCP ne peut pas se connecter au serveur JinaNavigator.

**Causes possibles** :
- Le serveur n'est pas en cours d'exécution
- Le serveur écoute sur une interface réseau différente
- Problèmes de réseau ou de pare-feu

**Solutions** :
1. Vérifiez que le serveur est en cours d'exécution :
   ```bash
   # Sur Windows
   netstat -ano | findstr :3000
   
   # Sur Linux/macOS
   lsof -i :3000
   ```

2. Assurez-vous que le serveur écoute sur la bonne interface :
   ```json
   {
     "server": {
       "host": "0.0.0.0",  // Écoute sur toutes les interfaces
       "port": 3000
     }
   }
   ```

3. Vérifiez les règles de pare-feu et assurez-vous que le port est ouvert :
   ```bash
   # Sur Windows
   netsh advfirewall firewall add rule name="JinaNavigator MCP" dir=in action=allow protocol=TCP localport=3000
   
   # Sur Linux
   sudo ufw allow 3000/tcp
   ```

4. Testez la connexion avec curl :
   ```bash
   curl -X POST http://localhost:3000/mcp -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"mcp.discover","params":{},"id":1}'
   ```

### Erreur CORS

**Symptôme** : Erreurs CORS dans la console du navigateur lors de la connexion au serveur.

```
Access to fetch at 'http://localhost:3000/mcp' from origin 'http://localhost:8080' has been blocked by CORS policy
```

**Causes possibles** :
- Configuration CORS incorrecte ou manquante
- Origine non autorisée

**Solutions** :
1. Activez CORS dans la configuration du serveur :
   ```json
   {
     "server": {
       "cors": {
         "enabled": true,
         "origins": ["*"]
       }
     }
   }
   ```

2. Pour une configuration plus sécurisée, spécifiez les origines exactes :
   ```json
   {
     "server": {
       "cors": {
         "enabled": true,
         "origins": ["http://localhost:8080", "https://votre-application.com"]
       }
     }
   }
   ```

3. Redémarrez le serveur après avoir modifié la configuration.
<!-- END_SECTION: connection_issues -->

<!-- START_SECTION: tool_issues -->
## Problèmes avec les outils

### Problèmes avec `convert_web_to_markdown`

#### Erreur "URL invalide"

**Symptôme** : L'outil renvoie une erreur indiquant que l'URL est invalide.

```
Erreur lors de la conversion: URL invalide
```

**Causes possibles** :
- L'URL n'est pas correctement formatée
- L'URL n'est pas accessible
- L'URL contient des caractères spéciaux non encodés

**Solutions** :
1. Vérifiez que l'URL est correctement formatée (commence par http:// ou https://).

2. Assurez-vous que l'URL est accessible en la testant dans un navigateur.

3. Encodez les caractères spéciaux dans l'URL :
   ```javascript
   const url = encodeURI('https://example.com/page with spaces');
   ```

4. Essayez avec une URL plus simple pour vérifier si le problème est spécifique à cette URL.

#### Erreur "Timeout de requête dépassé"

**Symptôme** : L'outil renvoie une erreur de timeout lors de la conversion d'une page web.

```
Erreur lors de la conversion: Timeout de requête dépassé
```

**Causes possibles** :
- La page web est trop volumineuse
- Le serveur web cible est lent
- Problèmes de connexion Internet
- Timeout configuré trop court

**Solutions** :
1. Augmentez le timeout dans la configuration :
   ```json
   {
     "jina": {
       "timeout": 60000  // 60 secondes
     }
   }
   ```

2. Essayez avec une page web plus légère.

3. Vérifiez votre connexion Internet.

4. Le site web cible peut être lent ou temporairement indisponible, réessayez plus tard.

#### Contenu Markdown incorrect ou incomplet

**Symptôme** : Le contenu Markdown généré ne correspond pas à ce qui est attendu.

**Causes possibles** :
- La page web utilise du contenu dynamique (JavaScript)
- La page web a une structure complexe
- La page web utilise des techniques anti-scraping

**Solutions** :
1. Certaines pages web complexes peuvent ne pas être correctement converties. Essayez avec une page plus simple.

2. Utilisez les paramètres `start_line` et `end_line` pour extraire uniquement les parties pertinentes.

3. Vérifiez si la page web fonctionne correctement sans JavaScript dans un navigateur.

4. Essayez d'utiliser un autre outil pour convertir la page web en Markdown.

### Problèmes avec `multi_convert`

#### Certaines URLs échouent

**Symptôme** : Lors de l'utilisation de `multi_convert`, certaines URLs sont converties avec succès tandis que d'autres échouent.

**Causes possibles** :
- Certaines URLs sont invalides ou inaccessibles
- Trop d'URLs sont traitées simultanément
- Timeout atteint pour certaines URLs

**Solutions** :
1. Vérifiez que toutes les URLs sont valides et accessibles.

2. Réduisez le nombre d'URLs par requête :
   ```json
   {
     "performance": {
       "maxUrlsPerRequest": 10
     }
   }
   ```

3. Augmentez le timeout :
   ```json
   {
     "jina": {
       "timeout": 60000  // 60 secondes
     }
   }
   ```

4. Traitez séparément les URLs qui échouent systématiquement.

#### Erreur "Trop d'URLs"

**Symptôme** : L'outil renvoie une erreur indiquant qu'il y a trop d'URLs.

```
Erreur: Le nombre d'URLs dépasse la limite maximale (50)
```

**Causes possibles** :
- Le nombre d'URLs dépasse la limite configurée

**Solutions** :
1. Réduisez le nombre d'URLs par requête.

2. Augmentez la limite dans la configuration :
   ```json
   {
     "performance": {
       "maxUrlsPerRequest": 100
     }
   }
   ```

3. Divisez la requête en plusieurs requêtes plus petites.

### Problèmes avec `access_jina_resource`

#### Erreur "URI invalide"

**Symptôme** : L'outil renvoie une erreur indiquant que l'URI est invalide.

```
URI invalide. L'URI doit être au format jina://{url}
```

**Causes possibles** :
- L'URI ne commence pas par `jina://`
- L'URL après le préfixe `jina://` est invalide

**Solutions** :
1. Assurez-vous que l'URI commence par `jina://` :
   ```javascript
   const uri = 'jina://https://example.com';
   ```

2. Vérifiez que l'URL après le préfixe `jina://` est une URL valide (commence par http:// ou https://).

3. Encodez les caractères spéciaux dans l'URL :
   ```javascript
   const url = `jina://${encodeURI('https://example.com/page with spaces')}`;
   ```
<!-- END_SECTION: tool_issues -->

<!-- START_SECTION: api_issues -->
## Problèmes avec l'API Jina

### Erreur "Request failed with status code 429"

**Symptôme** : L'outil renvoie une erreur avec le code d'état HTTP 429.

```
Erreur lors de la conversion: Request failed with status code 429
```

**Causes possibles** :
- Trop de requêtes ont été envoyées à l'API Jina dans un court laps de temps
- Limite de taux de requêtes atteinte

**Solutions** :
1. Réduisez le nombre de requêtes envoyées à l'API Jina.

2. Implémentez une logique de nouvelle tentative avec backoff exponentiel :
   ```javascript
   async function convertWithRetry(url, maxRetries = 3, initialDelay = 1000) {
     let retries = 0;
     while (retries < maxRetries) {
       try {
         return await client.callTool('jinavigator', 'convert_web_to_markdown', { url });
       } catch (error) {
         if (error.message.includes('status code 429') && retries < maxRetries - 1) {
           const delay = initialDelay * Math.pow(2, retries);
           console.log(`Rate limited. Retrying in ${delay}ms...`);
           await new Promise(resolve => setTimeout(resolve, delay));
           retries++;
         } else {
           throw error;
         }
       }
     }
   }
   ```

3. Utilisez le cache pour éviter de reconvertir fréquemment les mêmes pages :
   ```json
   {
     "performance": {
       "cacheEnabled": true,
       "cacheMaxAge": 3600
     }
   }
   ```

### Erreur "Request failed with status code 5xx"

**Symptôme** : L'outil renvoie une erreur avec un code d'état HTTP 5xx.

```
Erreur lors de la conversion: Request failed with status code 502
```

**Causes possibles** :
- L'API Jina rencontre des problèmes techniques
- L'API Jina est temporairement indisponible

**Solutions** :
1. Attendez quelques minutes et réessayez.

2. Vérifiez le statut de l'API Jina.

3. Implémentez une logique de nouvelle tentative :
   ```javascript
   async function convertWithRetry(url, maxRetries = 3, initialDelay = 1000) {
     let retries = 0;
     while (retries < maxRetries) {
       try {
         return await client.callTool('jinavigator', 'convert_web_to_markdown', { url });
       } catch (error) {
         if (error.message.includes('status code 5') && retries < maxRetries - 1) {
           const delay = initialDelay * Math.pow(2, retries);
           console.log(`Server error. Retrying in ${delay}ms...`);
           await new Promise(resolve => setTimeout(resolve, delay));
           retries++;
         } else {
           throw error;
         }
       }
     }
   }
   ```

### Erreur "Network Error"

**Symptôme** : L'outil renvoie une erreur de réseau.

```
Erreur lors de la conversion: Network Error
```

**Causes possibles** :
- Problèmes de connexion Internet
- L'API Jina est inaccessible
- Problèmes de DNS

**Solutions** :
1. Vérifiez votre connexion Internet.

2. Vérifiez si l'API Jina est accessible :
   ```bash
   curl -I https://r.jina.ai/
   ```

3. Vérifiez la configuration du proxy si vous êtes derrière un proxy.

4. Essayez de changer de réseau ou de serveur DNS.
<!-- END_SECTION: api_issues -->

<!-- START_SECTION: performance_issues -->
## Problèmes de performance

### Lenteur générale

**Symptôme** : Le serveur répond lentement à toutes les requêtes.

**Causes possibles** :
- Ressources système insuffisantes
- Trop de requêtes simultanées
- Problèmes de configuration

**Solutions** :
1. Vérifiez l'utilisation des ressources système :
   ```bash
   # Sur Linux
   top
   
   # Sur Windows
   taskmgr
   ```

2. Limitez le nombre de requêtes concurrentes dans la configuration :
   ```json
   {
     "jina": {
       "concurrentRequests": 5
     }
   }
   ```

3. Activez le cache pour améliorer les performances des opérations répétées :
   ```json
   {
     "performance": {
       "cacheEnabled": true,
       "cacheMaxAge": 3600
     }
   }
   ```

4. Augmentez les ressources allouées au serveur (mémoire, CPU).

### Lenteur lors de la conversion de pages web volumineuses

**Symptôme** : Les opérations de conversion de pages web volumineuses sont très lentes ou provoquent des timeouts.

**Causes possibles** :
- Pages web trop volumineuses
- Limitations de l'API Jina
- Connexion Internet lente

**Solutions** :
1. Utilisez les paramètres `start_line` et `end_line` pour extraire uniquement les parties nécessaires :
   ```javascript
   const result = await client.callTool('jinavigator', 'convert_web_to_markdown', {
     url: 'https://example.com',
     start_line: 1,
     end_line: 100  // Lire uniquement les 100 premières lignes
   });
   ```

2. Divisez les pages web volumineuses en plusieurs requêtes plus petites.

3. Utilisez l'outil `extract_markdown_outline` pour obtenir la structure de la page, puis convertissez uniquement les sections pertinentes.

4. Augmentez le timeout dans la configuration :
   ```json
   {
     "jina": {
       "timeout": 60000  // 60 secondes
     }
   }
   ```

### Problèmes de mémoire

**Symptôme** : Le serveur consomme beaucoup de mémoire ou se bloque avec des erreurs de mémoire insuffisante.

```
FATAL ERROR: JavaScript heap out of memory
```

**Causes possibles** :
- Traitement de pages web trop volumineuses
- Trop de requêtes simultanées
- Fuites de mémoire

**Solutions** :
1. Augmentez la mémoire disponible pour Node.js :
   ```bash
   export NODE_OPTIONS="--max-old-space-size=4096"
   npm start
   ```

2. Limitez le nombre de requêtes concurrentes :
   ```json
   {
     "jina": {
       "concurrentRequests": 3
     }
   }
   ```

3. Utilisez les paramètres `start_line` et `end_line` pour limiter la taille des résultats.

4. Mettez à jour régulièrement le serveur pour bénéficier des corrections de fuites de mémoire.
<!-- END_SECTION: performance_issues -->

<!-- START_SECTION: advanced_troubleshooting -->
## Dépannage avancé

### Analyse des journaux

Les journaux du serveur JinaNavigator peuvent fournir des informations précieuses pour diagnostiquer les problèmes. Par défaut, les journaux sont écrits dans le fichier `jinavigator.log` dans le répertoire du serveur.

1. Augmentez le niveau de détail des journaux pour le débogage :
   ```json
   {
     "logging": {
       "level": "debug",
       "file": "jinavigator-debug.log",
       "console": true
     }
   }
   ```

2. Analysez les journaux pour identifier les erreurs :
   ```bash
   grep "ERROR" jinavigator.log
   ```

3. Suivez les journaux en temps réel pendant l'exécution :
   ```bash
   tail -f jinavigator.log
   ```

4. Utilisez des outils comme `logrotate` pour gérer les fichiers de journaux volumineux.

### Débogage avec Node.js Inspector

Pour un débogage plus approfondi, vous pouvez utiliser l'inspecteur de Node.js :

1. Démarrez le serveur en mode débogage :
   ```bash
   node --inspect dist/index.js
   ```

2. Ouvrez Chrome et accédez à `chrome://inspect`.

3. Cliquez sur "Open dedicated DevTools for Node" pour ouvrir les outils de développement.

4. Utilisez les outils de développement pour définir des points d'arrêt, inspecter des variables et suivre l'exécution du code.

### Tests de diagnostic

Pour isoler les problèmes, vous pouvez exécuter des tests de diagnostic :

1. Testez la connexion à l'API Jina :
   ```bash
   curl -X POST https://r.jina.ai/ \
     -H "Content-Type: application/json" \
     -d '{"url": "https://example.com"}'
   ```

2. Testez les outils MCP individuellement :
   ```bash
   node tests/test-convert-web.js
   node tests/test-multi-convert.js
   node tests/test-access-resource.js
   ```

3. Vérifiez les performances avec différentes configurations :
   ```bash
   node tests/test-performance.js
   ```

### Contournements pour les problèmes courants

#### Contournement pour les timeouts fréquents

Si vous rencontrez fréquemment des timeouts avec l'API Jina, vous pouvez implémenter un système de mise en file d'attente pour limiter le nombre de requêtes simultanées :

```javascript
class RequestQueue {
  constructor(maxConcurrent = 3) {
    this.queue = [];
    this.running = 0;
    this.maxConcurrent = maxConcurrent;
  }

  async add(fn) {
    return new Promise((resolve, reject) => {
      this.queue.push({ fn, resolve, reject });
      this.processQueue();
    });
  }

  async processQueue() {
    if (this.running >= this.maxConcurrent || this.queue.length === 0) {
      return;
    }

    this.running++;
    const { fn, resolve, reject } = this.queue.shift();

    try {
      const result = await fn();
      resolve(result);
    } catch (error) {
      reject(error);
    } finally {
      this.running--;
      this.processQueue();
    }
  }
}

// Utilisation
const queue = new RequestQueue(3);
const urls = ['url1', 'url2', 'url3', 'url4', 'url5'];

const results = await Promise.all(urls.map(url => 
  queue.add(() => client.callTool('jinavigator', 'convert_web_to_markdown', { url }))
));
```

#### Contournement pour les problèmes de mémoire

Si vous rencontrez des problèmes de mémoire lors du traitement de pages web volumineuses, vous pouvez implémenter un système de traitement par lots :

```javascript
async function processInBatches(urls, batchSize = 5) {
  const results = [];
  
  for (let i = 0; i < urls.length; i += batchSize) {
    const batch = urls.slice(i, i + batchSize);
    console.log(`Processing batch ${i/batchSize + 1}/${Math.ceil(urls.length/batchSize)}`);
    
    const batchResults = await client.callTool('jinavigator', 'multi_convert', {
      urls: batch.map(url => ({ url }))
    });
    
    results.push(...batchResults.result);
    
    // Attendre un peu entre les lots pour libérer la mémoire
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
  
  return results;
}
```
<!-- END_SECTION: advanced_troubleshooting -->

<!-- START_SECTION: common_error_codes -->
## Codes d'erreur courants

### Codes d'erreur standard du protocole MCP

| Code | Nom | Description | Solution |
|------|-----|-------------|----------|
| -32700 | ParseError | Erreur d'analyse JSON | Vérifiez le format JSON de la requête |
| -32600 | InvalidRequest | La requête n'est pas valide | Vérifiez la structure de la requête MCP |
| -32601 | MethodNotFound | La méthode demandée n'existe pas | Vérifiez le nom de la méthode et les outils disponibles |
| -32602 | InvalidParams | Les paramètres fournis sont invalides | Vérifiez les paramètres de la requête |
| -32603 | InternalError | Erreur interne du serveur | Consultez les journaux pour plus de détails |
| -32000 | ServerError | Erreur générique du serveur | Consultez les journaux pour plus de détails |

### Codes d'erreur spécifiques à JinaNavigator

| Code | Description | Solution |
|------|-------------|----------|
| -32001 | InvalidURL | L'URL fournie n'est pas valide | Vérifiez le format de l'URL |
| -32002 | InvalidURI | L'URI fourni n'est pas au format jina://{url} | Vérifiez le format de l'URI |
| -32003 | RequestTimeout | La requête a dépassé le délai d'attente | Augmentez le timeout ou essayez avec une page plus légère |
| -32004 | APIError | Erreur renvoyée par l'API Jina | Vérifiez les détails de l'erreur dans les journaux |
| -32005 | TooManyURLs | Trop d'URLs dans une seule requête | Réduisez le nombre d'URLs ou augmentez la limite |
| -32006 | NetworkError | Erreur de réseau lors de la communication avec l'API Jina | Vérifiez votre connexion Internet |
| -32007 | RateLimitExceeded | Limite de taux de requêtes de l'API Jina dépassée | Réduisez le nombre de requêtes ou implémentez une logique de nouvelle tentative |
<!-- END_SECTION: common_error_codes -->

<!-- START_SECTION: next_steps -->
## Prochaines étapes

Si vous avez résolu votre problème, vous pouvez maintenant :

1. [Configurer le serveur](CONFIGURATION.md) selon vos besoins
2. [Apprendre à utiliser le serveur](USAGE.md) avec des exemples pratiques
3. [Explorer les cas d'utilisation avancés](../docs/jinavigator-use-cases.md) pour tirer le meilleur parti du serveur

Si vous n'avez pas pu résoudre votre problème :

1. Consultez les [issues GitHub](https://github.com/jsboige/jsboige-mcp-servers/issues) pour voir si d'autres utilisateurs ont rencontré le même problème
2. Ouvrez une nouvelle issue en fournissant des détails sur votre problème, les étapes pour le reproduire et les journaux pertinents
3. Contactez l'équipe de support pour obtenir de l'aide supplémentaire
<!-- END_SECTION: next_steps -->