# Utilisation du serveur MCP JinaNavigator

<!-- START_SECTION: introduction -->
Ce document fournit des exemples détaillés d'utilisation et des bonnes pratiques pour le serveur MCP JinaNavigator. Vous y trouverez des exemples concrets pour chaque outil exposé par le serveur, ainsi que des scénarios d'utilisation avancés.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: getting_started -->
## Démarrage du serveur

### Démarrage standard

Pour démarrer le serveur JinaNavigator avec la configuration par défaut :

```bash
cd servers/jinavigator-server
npm start
```

### Démarrage avec options

Pour démarrer le serveur avec des options spécifiques :

```bash
# Spécifier un port différent
npm start -- --port 4000

# Spécifier un fichier de configuration personnalisé
npm start -- --config ./config/production.json

# Spécifier une clé API Jina
npm start -- --api-key votre_clé_api_ici
```

### Démarrage en mode développement

Pour démarrer le serveur en mode développement avec rechargement automatique :

```bash
npm run dev
```

### Vérification du fonctionnement

Une fois le serveur démarré, vous pouvez vérifier qu'il fonctionne correctement en exécutant le script de test :

```bash
npm run test:simple
```

Vous devriez voir une sortie confirmant que le serveur est opérationnel et que les outils fonctionnent correctement.
<!-- END_SECTION: getting_started -->

<!-- START_SECTION: client_connection -->
## Connexion d'un client MCP

Pour utiliser le serveur JinaNavigator, vous devez le connecter à un client MCP. Voici comment procéder avec différents clients :

### Connexion avec le client MCP JavaScript

```javascript
const { MCPClient } = require('@modelcontextprotocol/client');

async function connectToJinaNavigator() {
  const client = new MCPClient();
  
  // Connexion au serveur JinaNavigator
  await client.connect('http://localhost:3000');
  
  // Vérification des outils disponibles
  const tools = await client.listTools();
  console.log('Outils disponibles:', tools);
  
  return client;
}

// Utilisation
connectToJinaNavigator().then(client => {
  // Utiliser le client pour appeler les outils JinaNavigator
});
```

### Connexion avec Roo

Dans la configuration de Roo, ajoutez le serveur JinaNavigator dans la section des serveurs MCP :

```json
{
  "servers": [
    {
      "name": "jinavigator",
      "url": "http://localhost:3000",
      "type": "mcp"
    }
  ]
}
```

### Connexion avec d'autres clients MCP

Pour d'autres clients MCP, consultez la documentation spécifique du client. En général, vous devrez fournir l'URL du serveur JinaNavigator (par défaut `http://localhost:3000`).
<!-- END_SECTION: client_connection -->

<!-- START_SECTION: tool_convert_web_to_markdown -->
## Utilisation de l'outil `convert_web_to_markdown`

L'outil `convert_web_to_markdown` permet de convertir une page web en format Markdown.

### Conversion simple d'une page web

```javascript
const result = await client.callTool('jinavigator', 'convert_web_to_markdown', {
  url: 'https://github.com/github/github-mcp-server'
});

console.log(result.result);  // Contenu Markdown de la page
```

### Conversion avec filtrage par lignes

```javascript
const result = await client.callTool('jinavigator', 'convert_web_to_markdown', {
  url: 'https://github.com/github/github-mcp-server',
  start_line: 10,
  end_line: 20
});

console.log(result.result);  // Lignes 10 à 20 du contenu Markdown
```

### Bonnes pratiques pour la conversion de pages web

- Utilisez les paramètres `start_line` et `end_line` pour extraire uniquement les parties pertinentes des pages volumineuses
- Évitez de convertir des pages web très volumineuses en une seule requête
- Tenez compte des limitations de l'API Jina en termes de taux de requêtes
- Utilisez le cache pour éviter de reconvertir fréquemment les mêmes pages
<!-- END_SECTION: tool_convert_web_to_markdown -->

<!-- START_SECTION: tool_access_jina_resource -->
## Utilisation de l'outil `access_jina_resource`

L'outil `access_jina_resource` permet d'accéder au contenu Markdown d'une page web via un URI standardisé au format `jina://{url}`.

### Accès à une ressource Jina

```javascript
const result = await client.callTool('jinavigator', 'access_jina_resource', {
  uri: 'jina://https://github.com/github/github-mcp-server'
});

console.log(result.result.content);  // Contenu Markdown de la page
```

### Accès avec filtrage par lignes

```javascript
const result = await client.callTool('jinavigator', 'access_jina_resource', {
  uri: 'jina://https://github.com/github/github-mcp-server',
  start_line: 10,
  end_line: 20
});

console.log(result.result.content);  // Lignes 10 à 20 du contenu Markdown
```

### Bonnes pratiques pour l'accès aux ressources Jina

- Utilisez toujours le préfixe `jina://` suivi de l'URL complète (avec `http://` ou `https://`)
- Utilisez les paramètres `start_line` et `end_line` pour extraire uniquement les parties pertinentes
- Assurez-vous que l'URL est accessible publiquement
<!-- END_SECTION: tool_access_jina_resource -->

<!-- START_SECTION: tool_multi_convert -->
## Utilisation de l'outil `multi_convert`

L'outil `multi_convert` permet de convertir plusieurs pages web en Markdown en une seule requête.

### Conversion de plusieurs URLs

```javascript
const result = await client.callTool('jinavigator', 'multi_convert', {
  urls: [
    { 
      url: "https://en.wikipedia.org/wiki/JavaScript", 
      start_line: 5, 
      end_line: 15 
    },
    { 
      url: "https://en.wikipedia.org/wiki/TypeScript", 
      start_line: 20, 
      end_line: 30 
    },
    { 
      url: "https://en.wikipedia.org/wiki/Node.js", 
      start_line: 15, 
      end_line: 25 
    }
  ]
});

// Accès aux résultats
result.result.forEach(item => {
  console.log(`URL: ${item.url}`);
  console.log(`Succès: ${item.success}`);
  if (item.success) {
    console.log(`Contenu: ${item.content}`);
  } else {
    console.log(`Erreur: ${item.error}`);
  }
});
```

### Conversion de plusieurs URLs sans filtrage

```javascript
const result = await client.callTool('jinavigator', 'multi_convert', {
  urls: [
    { url: "https://en.wikipedia.org/wiki/JavaScript" },
    { url: "https://en.wikipedia.org/wiki/TypeScript" },
    { url: "https://en.wikipedia.org/wiki/Node.js" }
  ]
});

// Traitement des résultats
const successfulConversions = result.result.filter(item => item.success);
console.log(`${successfulConversions.length} conversions réussies sur ${result.result.length}`);
```

### Bonnes pratiques pour la conversion multiple

- Limitez le nombre d'URLs par requête (idéalement moins de 50)
- Regroupez les URLs connexes dans une même requête
- Utilisez les paramètres `start_line` et `end_line` pour limiter la taille des résultats
- Gérez correctement les erreurs, car certaines URLs peuvent échouer même si d'autres réussissent
<!-- END_SECTION: tool_multi_convert -->

<!-- START_SECTION: tool_extract_markdown_outline -->
## Utilisation de l'outil `extract_markdown_outline`

L'outil `extract_markdown_outline` permet d'extraire le plan hiérarchique des titres markdown avec numéros de ligne à partir d'une liste d'URLs.

### Extraction du plan d'une page web

```javascript
const result = await client.callTool('jinavigator', 'extract_markdown_outline', {
  urls: [
    { url: "https://en.wikipedia.org/wiki/JavaScript" }
  ],
  max_depth: 3  // Extraire les titres jusqu'au niveau h3
});

console.log(result.outlines[0]);  // Plan de la première URL
```

### Extraction du plan de plusieurs pages web

```javascript
const result = await client.callTool('jinavigator', 'extract_markdown_outline', {
  urls: [
    { url: "https://en.wikipedia.org/wiki/JavaScript" },
    { url: "https://en.wikipedia.org/wiki/TypeScript" }
  ],
  max_depth: 2  // Extraire uniquement les titres h1 et h2
});

// Traitement des résultats
result.outlines.forEach((outline, index) => {
  console.log(`Plan de ${result.urls[index].url}:`);
  console.log(outline);
});
```

### Bonnes pratiques pour l'extraction de plans

- Utilisez `max_depth` pour limiter la profondeur des titres extraits
- Limitez le nombre d'URLs par requête pour éviter les timeouts
- Utilisez les plans extraits pour naviguer efficacement dans le contenu des pages web
<!-- END_SECTION: tool_extract_markdown_outline -->

<!-- START_SECTION: advanced_usage -->
## Utilisations avancées

### Analyse de contenu web

JinaNavigator peut être utilisé pour analyser le contenu de plusieurs pages web et extraire des informations pertinentes :

```javascript
// Convertir plusieurs pages web en Markdown
const result = await client.callTool('jinavigator', 'multi_convert', {
  urls: [
    { url: "https://en.wikipedia.org/wiki/JavaScript" },
    { url: "https://en.wikipedia.org/wiki/TypeScript" },
    { url: "https://en.wikipedia.org/wiki/Node.js" }
  ]
});

// Analyser le contenu pour trouver des informations spécifiques
const successfulResults = result.result.filter(item => item.success);
const mentions = {};

successfulResults.forEach(item => {
  const content = item.content;
  
  // Compter les mentions de termes spécifiques
  const terms = ["ECMAScript", "Microsoft", "Ryan Dahl", "npm"];
  terms.forEach(term => {
    const regex = new RegExp(term, 'gi');
    const count = (content.match(regex) || []).length;
    
    if (!mentions[term]) mentions[term] = {};
    mentions[term][item.url] = count;
  });
});

console.log('Analyse des mentions:', mentions);
```

### Génération de documentation

JinaNavigator peut être utilisé pour générer de la documentation à partir de pages web :

```javascript
// Extraire le plan d'une page web
const outlineResult = await client.callTool('jinavigator', 'extract_markdown_outline', {
  urls: [{ url: "https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide" }],
  max_depth: 2
});

// Convertir la page en Markdown
const contentResult = await client.callTool('jinavigator', 'convert_web_to_markdown', {
  url: "https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide"
});

// Générer une table des matières
const toc = outlineResult.outlines[0].map(heading => {
  const indent = '  '.repeat(heading.level - 1);
  return `${indent}- [${heading.text}](#${heading.text.toLowerCase().replace(/\s+/g, '-')})`;
}).join('\n');

// Générer le document final
const documentation = `# Guide JavaScript

## Table des matières
${toc}

## Contenu
${contentResult.result}
`;

console.log(documentation);
```

### Veille technologique

JinaNavigator peut être utilisé pour effectuer une veille technologique en analysant régulièrement des sites web :

```javascript
// Liste des sites à surveiller
const sitesToMonitor = [
  "https://github.blog/",
  "https://blog.nodejs.org/",
  "https://developer.mozilla.org/en-US/blog/"
];

// Convertir les sites en Markdown
const result = await client.callTool('jinavigator', 'multi_convert', {
  urls: sitesToMonitor.map(url => ({ url }))
});

// Extraire les articles récents
const recentArticles = [];
result.result.forEach((item, index) => {
  if (!item.success) return;
  
  // Rechercher des dates récentes (format: YYYY-MM-DD)
  const dateRegex = /\b(202\d)[-\/](0[1-9]|1[0-2])[-\/](0[1-9]|[12][0-9]|3[01])\b/g;
  const dates = item.content.match(dateRegex) || [];
  
  // Rechercher des titres d'articles
  const titleRegex = /^#+\s+(.+)$/gm;
  const titles = [];
  let match;
  while ((match = titleRegex.exec(item.content)) !== null) {
    titles.push(match[1]);
  }
  
  // Ajouter les articles avec leurs dates
  titles.slice(0, 5).forEach((title, i) => {
    recentArticles.push({
      site: sitesToMonitor[index],
      title,
      date: dates[i] || 'Date inconnue'
    });
  });
});

console.log('Articles récents:', recentArticles);
```
<!-- END_SECTION: advanced_usage -->

<!-- START_SECTION: integration_with_roo -->
## Intégration avec Roo

JinaNavigator s'intègre parfaitement avec Roo, permettant à l'assistant IA d'accéder et d'analyser du contenu web.

### Configuration de Roo pour utiliser JinaNavigator

1. Assurez-vous que le serveur JinaNavigator est en cours d'exécution
2. Dans la configuration de Roo, ajoutez le serveur JinaNavigator dans la section des serveurs MCP

```json
{
  "servers": [
    {
      "name": "jinavigator",
      "url": "http://localhost:3000",
      "type": "mcp"
    }
  ]
}
```

### Exemples d'utilisation avec Roo

#### Conversion d'une page web

```
Utilisateur: Peux-tu me résumer la page d'accueil de GitHub?

Roo: Je vais convertir cette page en Markdown pour vous la résumer.
[Utilisation de l'outil jinavigator.convert_web_to_markdown]
Voici un résumé de la page d'accueil de GitHub:
...
```

#### Analyse de plusieurs pages web

```
Utilisateur: Compare les fonctionnalités de React, Vue et Angular.

Roo: Je vais analyser les sites officiels de ces frameworks.
[Utilisation de l'outil jinavigator.multi_convert]
Voici une comparaison des fonctionnalités de React, Vue et Angular:
...
```

#### Extraction du plan d'une documentation

```
Utilisateur: Montre-moi la structure de la documentation de Node.js.

Roo: Je vais extraire le plan de la documentation de Node.js.
[Utilisation de l'outil jinavigator.extract_markdown_outline]
Voici la structure de la documentation de Node.js:
...
```
<!-- END_SECTION: integration_with_roo -->

<!-- START_SECTION: troubleshooting -->
## Dépannage courant

### Problèmes de conversion de pages web

#### Erreur "URL invalide"

**Problème** : L'outil renvoie une erreur indiquant que l'URL est invalide.

**Solutions** :
- Vérifiez que l'URL est correctement formatée (commence par http:// ou https://)
- Assurez-vous que l'URL est accessible publiquement
- Essayez d'accéder à l'URL dans un navigateur pour vérifier qu'elle fonctionne

#### Erreur "Timeout de requête dépassé"

**Problème** : L'outil renvoie une erreur de timeout lors de la conversion d'une page web.

**Solutions** :
- Essayez avec une page web plus légère
- Augmentez la valeur de `jina.timeout` dans la configuration
- Vérifiez votre connexion internet
- Le site web cible peut être lent ou temporairement indisponible, réessayez plus tard

#### Contenu Markdown incorrect ou incomplet

**Problème** : Le contenu Markdown généré ne correspond pas à ce qui est attendu.

**Solutions** :
- Certaines pages web complexes peuvent ne pas être correctement converties
- Vérifiez que la page web cible ne bloque pas les robots ou les requêtes automatisées
- Essayez d'utiliser les paramètres `start_line` et `end_line` pour extraire uniquement les parties pertinentes

### Problèmes avec l'outil `multi_convert`

#### Certaines URLs échouent

**Problème** : Lors de l'utilisation de `multi_convert`, certaines URLs sont converties avec succès tandis que d'autres échouent.

**Solutions** :
- Vérifiez que toutes les URLs sont valides et accessibles
- Réduisez le nombre d'URLs par requête
- Augmentez la valeur de `jina.timeout` dans la configuration
- Traitez séparément les URLs qui échouent

#### Erreur "Trop d'URLs"

**Problème** : L'outil renvoie une erreur indiquant qu'il y a trop d'URLs.

**Solutions** :
- Réduisez le nombre d'URLs par requête
- Augmentez la valeur de `performance.maxUrlsPerRequest` dans la configuration
- Divisez la requête en plusieurs requêtes plus petites
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: performance_tips -->
## Conseils de performance

### Optimisation des conversions de pages web

- Utilisez les paramètres `start_line` et `end_line` pour extraire uniquement les parties nécessaires
- Activez le cache pour éviter de reconvertir fréquemment les mêmes pages
- Limitez le nombre d'URLs par requête avec `multi_convert`
- Utilisez `extract_markdown_outline` pour obtenir la structure d'une page avant de convertir des sections spécifiques

### Gestion des erreurs

- Implémentez une logique de nouvelle tentative pour les URLs qui échouent
- Traitez séparément les URLs qui échouent systématiquement
- Utilisez des timeouts appropriés en fonction de la complexité des pages web
- Surveillez les taux d'erreur pour détecter les problèmes potentiels

### Utilisation du cache

- Activez le cache avec `performance.cacheEnabled: true`
- Ajustez la durée de vie du cache avec `performance.cacheMaxAge` en fonction de la fréquence de mise à jour des pages web
- Utilisez des clés de cache spécifiques pour les extraits de pages web
<!-- END_SECTION: performance_tips -->

<!-- START_SECTION: security_considerations -->
## Considérations de sécurité

### Accès aux sites web

- Évitez de convertir des sites web contenant des informations sensibles
- N'utilisez pas JinaNavigator pour accéder à des sites web nécessitant une authentification
- Soyez conscient que l'API Jina peut stocker temporairement le contenu des pages web converties

### Validation des entrées

- Validez toujours les URLs fournies par les utilisateurs
- Méfiez-vous des URLs malveillantes qui pourraient tenter d'exploiter des vulnérabilités
- Limitez l'accès au serveur JinaNavigator aux utilisateurs de confiance

### Confidentialité

- Informez les utilisateurs que le contenu des pages web converties peut être envoyé à l'API Jina
- Ne stockez pas les résultats de conversion plus longtemps que nécessaire
- Respectez les conditions d'utilisation des sites web que vous convertissez
<!-- END_SECTION: security_considerations -->

<!-- START_SECTION: next_steps -->
## Prochaines étapes

Maintenant que vous savez comment utiliser le serveur JinaNavigator, vous pouvez :

1. [Consulter le guide de dépannage](TROUBLESHOOTING.md) pour résoudre les problèmes courants
2. [Explorer les cas d'utilisation avancés](../docs/jinavigator-use-cases.md) pour tirer le meilleur parti du serveur
3. [Contribuer au développement](../CONTRIBUTING.md) du serveur JinaNavigator
<!-- END_SECTION: next_steps -->