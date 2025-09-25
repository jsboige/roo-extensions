# Système de Logging Debug pour MCPs

## Vue d'ensemble

Le système de logging debug implémenté dans `github-projects-mcp` utilise Winston pour créer des fichiers de log persistants qui facilitent le diagnostic des problèmes depuis l'extérieur de l'environnement Roo.

## Architecture actuelle (github-projects-mcp)

### Fichiers générés
- `github-projects-mcp-error.log` : Erreurs uniquement (level: 'error')
- `github-projects-mcp-combined.log` : Tous les logs (debug, info, warn, error)

### Configuration Winston (`src/logger.ts`)

```typescript
import winston from 'winston';

const logger = winston.createLogger({
  level: 'debug',
  format: winston.format.combine(
    winston.format.timestamp({
      format: 'YYYY-MM-DD HH:mm:ss'
    }),
    winston.format.errors({ stack: true }),
    winston.format.splat(),
    winston.format.json()
  ),
  defaultMeta: { service: 'github-projects-mcp' },
  transports: [
    new winston.transports.File({ filename: 'github-projects-mcp-error.log', level: 'error' }),
    new winston.transports.File({ filename: 'github-projects-mcp-combined.log' }),
  ],
});

logger.debug("Winston logger a été initialisé.");

// Console uniquement en non-production
if (process.env.NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({
    format: winston.format.combine(
      winston.format.colorize(),
      winston.format.simple()
    )
  }));
}

export default logger;
```

### Utilisation dans le code

```typescript
// Import
import logger from './logger.js';

// Usage typique
try {
  // code...
} catch (error: any) {
  logger.error('Description de l\'erreur', { error });
  return { success: false, error: error.message };
}

// Info logging
logger.info('Information importante', { metadata });

// Debug logging
logger.debug('Détail de debug', { data });
```

## Avantages du système

1. **Diagnostic externe** : Les logs sont accessibles même quand Roo n'est pas ouvert
2. **Persistance** : Les logs survivent aux redémarrages du serveur
3. **Format structuré** : JSON avec timestamps, facilitant l'analyse
4. **Séparation des niveaux** : Fichier dédié aux erreurs
5. **Stack traces complètes** : Winston capture les stack traces des erreurs

## Problème identifié

⚠️ **Les fichiers de log sont créés systématiquement à la racine du workspace**, même en production, ce qui pollue l'environnement de travail.

## Solution recommandée

### Option 1 : Variable d'environnement (Recommandée)

```typescript
const logger = winston.createLogger({
  level: 'debug',
  format: winston.format.combine(
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.errors({ stack: true }),
    winston.format.splat(),
    winston.format.json()
  ),
  defaultMeta: { service: 'your-mcp-name' },
  transports: []
});

// Ajout conditionnel des transports de fichiers
if (process.env.MCP_DEBUG_LOGGING === 'true' || process.env.NODE_ENV === 'development') {
  logger.add(new winston.transports.File({ 
    filename: 'your-mcp-error.log', 
    level: 'error' 
  }));
  logger.add(new winston.transports.File({ 
    filename: 'your-mcp-combined.log' 
  }));
  logger.debug("File logging activé");
}

// Console en non-production
if (process.env.NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({
    format: winston.format.combine(
      winston.format.colorize(),
      winston.format.simple()
    )
  }));
}
```

### Option 2 : Dossier de logs dédié

```typescript
import fs from 'fs';
import path from 'path';

// Créer le dossier logs s'il n'existe pas
const logsDir = './logs';
if (!fs.existsSync(logsDir)) {
  fs.mkdirSync(logsDir, { recursive: true });
}

const transports = [];

if (process.env.MCP_DEBUG_LOGGING === 'true') {
  transports.push(
    new winston.transports.File({ 
      filename: path.join(logsDir, 'your-mcp-error.log'), 
      level: 'error' 
    }),
    new winston.transports.File({ 
      filename: path.join(logsDir, 'your-mcp-combined.log') 
    })
  );
}
```

## Implémentation pour roo-state-manager

### Étape 1 : Installation de Winston

```bash
npm install winston
npm install --save-dev @types/winston
```

### Étape 2 : Créer `src/logger.ts`

```typescript
import winston from 'winston';
import fs from 'fs';
import path from 'path';

// Créer le dossier logs seulement si le logging debug est activé
const createLoggerWithDebug = () => {
  const logger = winston.createLogger({
    level: 'debug',
    format: winston.format.combine(
      winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
      winston.format.errors({ stack: true }),
      winston.format.splat(),
      winston.format.json()
    ),
    defaultMeta: { service: 'roo-state-manager' },
    transports: []
  });

  // Logging debug activé ?
  if (process.env.MCP_DEBUG_LOGGING === 'true' || process.env.NODE_ENV === 'development') {
    const logsDir = './logs';
    if (!fs.existsSync(logsDir)) {
      fs.mkdirSync(logsDir, { recursive: true });
    }

    logger.add(new winston.transports.File({ 
      filename: path.join(logsDir, 'roo-state-manager-error.log'), 
      level: 'error' 
    }));
    logger.add(new winston.transports.File({ 
      filename: path.join(logsDir, 'roo-state-manager-combined.log') 
    }));
    
    logger.debug("File logging activé pour roo-state-manager");
  }

  // Console en développement
  if (process.env.NODE_ENV !== 'production') {
    logger.add(new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    }));
  }

  return logger;
};

const logger = createLoggerWithDebug();
export default logger;
```

### Étape 3 : Usage dans le code

```typescript
import logger from './logger.js';

// Dans les outils MCP
try {
  const result = await complexOperation();
  logger.info('Opération réussie', { result });
  return { success: true, data: result };
} catch (error: any) {
  logger.error('Erreur lors de l\'opération complexe', { 
    error: error.message, 
    stack: error.stack 
  });
  throw new Error(`Opération échouée: ${error.message}`);
}
```

## Activation du logging debug

### Pour développement local
```bash
export MCP_DEBUG_LOGGING=true
# ou dans .env
MCP_DEBUG_LOGGING=true
```

### Pour diagnostic en production
Temporairement activer la variable d'environnement, puis la désactiver après diagnostic.

## Gestion des fichiers de logs

### .gitignore
```gitignore
# MCP Debug logs
logs/
*.log
!.gitkeep
```

### Rotation des logs (optionnelle)
```typescript
// Pour éviter des fichiers trop volumineux
logger.add(new winston.transports.File({
  filename: 'combined.log',
  maxsize: 5242880, // 5MB
  maxFiles: 5,
}));
```

## Bonnes pratiques

1. **Logs structurés** : Utilisez des objets pour les métadonnées
2. **Niveaux appropriés** : debug < info < warn < error
3. **Context riche** : Incluez les paramètres et états pertinents
4. **Pas de données sensibles** : Évitez les tokens, mots de passe
5. **Messages descriptifs** : Facilitent le diagnostic
6. **Activation conditionnelle** : Ne pas polluer en production

## Exemple complet d'implémentation

Voir le code dans `mcps/internal/servers/github-projects-mcp/src/logger.ts` pour l'implémentation de référence avant modification.

---

**Note** : Ce système s'avère particulièrement utile lors des phases de développement et de débogage des serveurs MCP, car il permet de capturer les erreurs et le comportement même lorsque Roo n'est pas actif ou accessible.