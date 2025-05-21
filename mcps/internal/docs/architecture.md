# Architecture MCP (Model Context Protocol)

Ce document décrit l'architecture du protocole MCP (Model Context Protocol) et comment les serveurs MCP sont structurés dans ce dépôt.

## Qu'est-ce que MCP?

Le Model Context Protocol (MCP) est un protocole qui permet aux modèles de langage (LLM) d'interagir avec des outils et des ressources externes. Il définit un format standard pour:

1. La découverte d'outils et de ressources
2. L'invocation d'outils
3. L'accès aux ressources
4. La gestion des erreurs et des résultats

## Architecture générale

```
┌─────────────┐      ┌───────────────┐      ┌───────────────┐
│             │      │               │      │               │
│     LLM     │◄────►│  MCP Server   │◄────►│ External APIs │
│             │      │               │      │               │
└─────────────┘      └───────────────┘      └───────────────┘
                            ▲
                            │
                            ▼
                     ┌─────────────┐
                     │             │
                     │  Resources  │
                     │             │
                     └─────────────┘
```

## Composants clés

### 1. Serveur MCP

Un serveur MCP est un service qui implémente le protocole MCP et expose des outils et des ressources aux LLM. Chaque serveur MCP peut fournir plusieurs outils et ressources.

#### Types de serveurs MCP

Dans ce dépôt, les serveurs MCP sont placés directement dans le répertoire `servers/`. Voici quelques exemples des serveurs disponibles:

- **QuickFiles Server**: Serveur pour lire rapidement le contenu de répertoires et fichiers multiples
- **Jupyter MCP Server**: Serveur pour interagir avec des notebooks Jupyter

### 2. Outils (Tools)

Les outils sont des fonctions que le LLM peut invoquer pour effectuer des actions spécifiques. Chaque outil a:

- Un nom unique
- Une description
- Un schéma d'entrée (paramètres attendus)
- Un schéma de sortie (format du résultat)

Exemple de définition d'outil:

```json
{
  "name": "get_weather",
  "description": "Obtient les informations météorologiques pour une ville donnée",
  "input_schema": {
    "type": "object",
    "properties": {
      "city": {
        "type": "string",
        "description": "Nom de la ville"
      },
      "country": {
        "type": "string",
        "description": "Code pays ISO à 2 lettres"
      }
    },
    "required": ["city"]
  },
  "output_schema": {
    "type": "object",
    "properties": {
      "temperature": {
        "type": "number",
        "description": "Température en degrés Celsius"
      },
      "conditions": {
        "type": "string",
        "description": "Description des conditions météorologiques"
      }
    }
  }
}
```

### 3. Ressources (Resources)

Les ressources sont des sources de données que le LLM peut consulter. Chaque ressource a:

- Un URI unique
- Un type de contenu
- Des métadonnées

Exemple de ressource:

```
weather://paris/current
```

### 4. Protocole de communication

Le protocole MCP utilise deux méthodes principales de communication:

#### Stdio-based (Local)

Pour les serveurs locaux, la communication se fait via stdin/stdout:

```
LLM -> stdin -> MCP Server -> stdout -> LLM
```

#### SSE-based (Remote)

Pour les serveurs distants, la communication se fait via Server-Sent Events (SSE) sur HTTP/HTTPS:

```
LLM -> HTTP Request -> MCP Server -> SSE -> LLM
```

## Structure d'un serveur MCP

Chaque serveur MCP dans ce dépôt suit cette structure:

```
servers/
└── server-name/
    ├── README.md           # Documentation du serveur
    ├── package.json        # Dépendances et scripts
    ├── server.js ou index.ts # Point d'entrée du serveur
    ├── config.example.json # Configuration d'exemple (si nécessaire)
    ├── config.json         # Configuration réelle (ignorée par git)
    ├── src/                # Code source
    │   ├── tools/          # Implémentation des outils
    │   ├── resources/      # Implémentation des ressources
    │   └── utils/          # Utilitaires
    └── tests/              # Tests
```

## Cycle de vie d'une requête MCP

1. **Découverte**: Le LLM découvre les outils et ressources disponibles sur le serveur MCP
2. **Sélection**: Le LLM sélectionne un outil ou une ressource à utiliser
3. **Invocation/Accès**: Le LLM invoque l'outil ou accède à la ressource
4. **Traitement**: Le serveur MCP traite la requête
5. **Réponse**: Le serveur MCP renvoie le résultat au LLM
6. **Intégration**: Le LLM intègre le résultat dans sa réponse

## Sécurité

Les serveurs MCP peuvent implémenter différentes mesures de sécurité:

- Authentification par clé API
- Limitation de débit
- Validation des entrées
- Isolation des processus
- Journalisation et audit

## Pour en savoir plus

- [Spécification MCP officielle](https://github.com/microsoft/mcp)
- [Guide de démarrage](getting-started.md)
- [Guide de dépannage](troubleshooting.md)