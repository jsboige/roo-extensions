# Serveur MCP JinaNavigator

Ce serveur MCP utilise l'API Jina pour convertir des pages web en Markdown, offrant un accès facile et formaté au contenu web pour les modèles d'IA.

## Fonctionnalités

- **Conversion web vers Markdown** : convertit n'importe quelle page web en format Markdown propre
- **Filtrage par lignes** : permet d'extraire uniquement des portions spécifiques du contenu par numéros de ligne
- **Accès via URI** : accès au contenu web via un URI standardisé au format `jina://{url}`
- **Conversion multiple** : traitement de plusieurs URLs en parallèle en une seule requête
- **Gestion d'erreurs robuste** : traitement élégant des URLs invalides, timeouts et erreurs réseau

## Outils MCP exposés

1. `convert_web_to_markdown` : Convertit une page web en Markdown en utilisant l'API Jina
2. `access_jina_resource` : Accède au contenu Markdown d'une page web via un URI au format jina://{url}
3. `multi_convert` : Convertit plusieurs pages web en Markdown en une seule requête

## Prérequis

- Node.js (v14 ou supérieur)
- npm (v6 ou supérieur)

## Installation

1. Clonez ce dépôt
2. Installez les dépendances :

```bash
cd servers/jinavigator-server
npm install
```

3. Compilez le projet :

```bash
npm run build
```

## Utilisation

Pour démarrer le serveur MCP JinaNavigator :

```bash
npm start
```

Pour exécuter les tests :

```bash
# Exécuter tous les tests
npm test

# Exécuter uniquement les tests unitaires
npm run test:unit

# Exécuter uniquement les tests de gestion d'erreurs
npm run test:error

# Exécuter uniquement les tests de performance
npm run test:perf

# Exécuter les tests avec couverture
npm run test:coverage
```

## Exemples d'utilisation

### Conversion d'une page web en Markdown

```javascript
// Exemple d'appel à l'outil convert_web_to_markdown
const result = await client.callTool('jinavigator', 'convert_web_to_markdown', {
  url: 'https://github.com/github/github-mcp-server',
  start_line: 10,
  end_line: 20
});
```

### Accès via URI Jina

```javascript
// Exemple d'appel à l'outil access_jina_resource
const result = await client.callTool('jinavigator', 'access_jina_resource', {
  uri: 'jina://https://github.com/github/github-mcp-server',
  start_line: 10,
  end_line: 20
});
```

### Conversion de plusieurs URLs en parallèle

```javascript
// Exemple d'appel à l'outil multi_convert
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
```

## Schémas d'entrée/sortie détaillés

### convert_web_to_markdown

#### Schéma d'entrée

```json
{
  "type": "object",
  "properties": {
    "url": {
      "type": "string",
      "description": "URL de la page web à convertir en Markdown"
    },
    "start_line": {
      "type": "number",
      "description": "Ligne de début pour extraire une partie spécifique du contenu (optionnel)"
    },
    "end_line": {
      "type": "number",
      "description": "Ligne de fin pour extraire une partie spécifique du contenu (optionnel)"
    }
  },
  "required": ["url"]
}
```

#### Schéma de sortie

```json
{
  "type": "object",
  "properties": {
    "result": {
      "type": "string",
      "description": "Contenu Markdown de la page web"
    },
    "content": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "type": {
            "type": "string",
            "enum": ["text"]
          },
          "text": {
            "type": "string",
            "description": "Contenu Markdown de la page web"
          },
          "mime": {
            "type": "string",
            "enum": ["text/markdown"]
          }
        },
        "required": ["type", "text", "mime"]
      }
    }
  },
  "required": ["result", "content"]
}
```

### access_jina_resource

#### Schéma d'entrée

```json
{
  "type": "object",
  "properties": {
    "uri": {
      "type": "string",
      "description": "URI au format jina://{url} pour accéder au contenu Markdown d'une page web"
    },
    "start_line": {
      "type": "number",
      "description": "Ligne de début pour extraire une partie spécifique du contenu (optionnel)"
    },
    "end_line": {
      "type": "number",
      "description": "Ligne de fin pour extraire une partie spécifique du contenu (optionnel)"
    }
  },
  "required": ["uri"]
}
```

#### Schéma de sortie

```json
{
  "type": "object",
  "properties": {
    "result": {
      "type": "object",
      "properties": {
        "content": {
          "type": "string",
          "description": "Contenu Markdown de la page web"
        },
        "contentType": {
          "type": "string",
          "enum": ["text/markdown"]
        }
      },
      "required": ["content", "contentType"]
    },
    "content": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "type": {
            "type": "string",
            "enum": ["text"]
          },
          "text": {
            "type": "string",
            "description": "Contenu Markdown de la page web"
          },
          "mime": {
            "type": "string",
            "enum": ["text/markdown"]
          }
        },
        "required": ["type", "text", "mime"]
      }
    }
  },
  "required": ["result", "content"]
}
```

### multi_convert

#### Schéma d'entrée

```json
{
  "type": "object",
  "properties": {
    "urls": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "url": {
            "type": "string",
            "description": "URL de la page web à convertir en Markdown"
          },
          "start_line": {
            "type": "number",
            "description": "Ligne de début pour extraire une partie spécifique du contenu (optionnel)"
          },
          "end_line": {
            "type": "number",
            "description": "Ligne de fin pour extraire une partie spécifique du contenu (optionnel)"
          }
        },
        "required": ["url"]
      },
      "description": "Liste des URLs à convertir en Markdown avec leurs paramètres de bornage"
    }
  },
  "required": ["urls"]
}
```

#### Schéma de sortie

```json
{
  "type": "object",
  "properties": {
    "result": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "url": {
            "type": "string",
            "description": "URL de la page web convertie"
          },
          "success": {
            "type": "boolean",
            "description": "Indique si la conversion a réussi"
          },
          "content": {
            "type": "string",
            "description": "Contenu Markdown de la page web (présent si success=true)"
          },
          "error": {
            "type": "string",
            "description": "Message d'erreur (présent si success=false)"
          }
        },
        "required": ["url", "success"]
      }
    },
    "content": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "type": {
            "type": "string",
            "enum": ["text"]
          },
          "text": {
            "type": "string",
            "description": "Résultats formatés en JSON"
          },
          "mime": {
            "type": "string",
            "enum": ["application/json"]
          }
        },
        "required": ["type", "text", "mime"]
      }
    }
  },
  "required": ["result", "content"]
}
```

## Codes d'erreur

Le serveur JinaNavigator utilise les codes d'erreur standard du protocole MCP :

| Code | Nom | Description |
|------|-----|-------------|
| -32700 | ParseError | Erreur d'analyse JSON |
| -32600 | InvalidRequest | La requête n'est pas valide |
| -32601 | MethodNotFound | La méthode demandée n'existe pas |
| -32602 | InvalidParams | Les paramètres fournis sont invalides |
| -32603 | InternalError | Erreur interne du serveur |
| -32000 | ServerError | Erreur générique du serveur |

### Erreurs spécifiques à JinaNavigator

En plus des codes d'erreur standard, les messages d'erreur suivants peuvent être retournés :

| Situation | Message d'erreur |
|-----------|-----------------|
| URL invalide | `Erreur lors de la conversion: URL invalide` |
| Timeout de requête | `Erreur lors de la conversion: Timeout de requête dépassé` |
| Erreur réseau | `Erreur lors de la conversion: Erreur réseau` |
| Erreur HTTP | `Erreur lors de la conversion: Request failed with status code XXX` |
| URI invalide | `URI invalide. L'URI doit être au format jina://{url}` |

## Guide de dépannage

### Problèmes courants et solutions

#### Erreur "URL invalide"

**Problème** : L'URL fournie n'est pas valide ou ne peut pas être traitée par l'API Jina.

**Solution** :
- Vérifiez que l'URL est correctement formatée (commence par http:// ou https://)
- Assurez-vous que l'URL est accessible publiquement
- Essayez d'accéder à l'URL dans un navigateur pour vérifier qu'elle fonctionne

#### Erreur "Timeout de requête dépassé"

**Problème** : La requête a pris trop de temps et a été interrompue.

**Solution** :
- Essayez avec une page web plus légère
- Vérifiez votre connexion internet
- Le site web cible peut être lent ou temporairement indisponible, réessayez plus tard

#### Erreur "URI invalide"

**Problème** : L'URI fourni n'est pas au format attendu `jina://{url}`.

**Solution** :
- Assurez-vous que l'URI commence par `jina://`
- Vérifiez que l'URL après le préfixe `jina://` est une URL valide

#### Problèmes de performance avec de nombreuses URLs

**Problème** : Lenteur ou timeouts lors de la conversion de nombreuses URLs en parallèle.

**Solution** :
- Réduisez le nombre d'URLs traitées en une seule requête
- Divisez les URLs en plusieurs requêtes plus petites
- Évitez de convertir des pages web très volumineuses en parallèle

#### Contenu Markdown incorrect ou incomplet

**Problème** : Le contenu Markdown généré ne correspond pas à ce qui est attendu.

**Solution** :
- Certaines pages web complexes peuvent ne pas être correctement converties
- Vérifiez que la page web cible ne bloque pas les robots ou les requêtes automatisées
- Essayez d'utiliser les paramètres `start_line` et `end_line` pour extraire uniquement les parties pertinentes

## Limitations

- **Taille des pages** : Les pages web très volumineuses (plus de 10 Mo) peuvent entraîner des timeouts ou des erreurs de mémoire.
- **Types de contenu** : Certains types de contenu dynamique (JavaScript, Canvas, WebGL) ne peuvent pas être correctement convertis en Markdown.
- **Sites protégés** : Les sites web qui utilisent des protections contre le scraping peuvent bloquer les requêtes de l'API Jina.
- **Contenu privé** : Le contenu nécessitant une authentification n'est pas accessible.
- **Taux de requêtes** : L'API Jina peut avoir des limites de taux de requêtes qui, si dépassées, peuvent entraîner des erreurs temporaires.

## Remarques importantes

- Ce serveur MCP utilise l'API Jina (`https://r.jina.ai/`) pour convertir des pages web en Markdown. Il est soumis aux conditions d'utilisation et aux limitations de cette API.
- Le serveur ne stocke aucun contenu web localement, il agit uniquement comme un intermédiaire entre l'API Jina et le client MCP.
- Pour des raisons de performance, il est recommandé de limiter le nombre d'URLs traitées en parallèle à moins de 50.
- Le filtrage par numéros de ligne est effectué côté serveur après la conversion, ce qui permet d'économiser de la bande passante en ne renvoyant que les parties pertinentes du contenu.
- L'API Jina peut ne pas fonctionner correctement avec tous les sites web, en particulier ceux qui utilisent des techniques avancées pour bloquer le scraping ou qui nécessitent une authentification.