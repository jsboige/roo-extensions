# Roo State Manager MCP

Serveur MCP (Model Context Protocol) unifié pour la gestion des conversations et configurations Roo.

## 🎯 Objectif

Le Roo State Manager résout les problèmes de perte de conversations Roo en fournissant :
- Détection automatique du stockage Roo existant
- Gestion unifiée des conversations et configurations
- Sauvegarde et restauration des données
- Interface MCP pour l'intégration avec d'autres outils

## 📁 Structure du Projet

```
roo-state-manager/
├── src/
│   ├── types/
│   │   └── conversation.ts      # Interfaces TypeScript
│   ├── utils/
│   │   └── roo-storage-detector.ts  # Détecteur de stockage
│   └── index.ts                 # Serveur MCP principal
├── tests/
│   └── test-storage-detector.js # Tests de validation
├── package.json
├── tsconfig.json
└── README.md
```

## 🚀 Installation

```bash
# Installation des dépendances
npm install

# Compilation TypeScript
npm run build

# Test du détecteur de stockage
npm run test:detector
```

## 🔍 Fonctionnalités

### Détection Automatique du Stockage Roo

Le détecteur recherche automatiquement les emplacements de stockage Roo dans :
- `~/.vscode/extensions/*/globalStorage/`
- `~/AppData/Roaming/Code/User/globalStorage/` (Windows)
- `~/.config/Code/User/globalStorage/` (Linux)
- `~/Library/Application Support/Code/User/globalStorage/` (macOS)

### Outils MCP Disponibles

#### `detect_roo_storage`
Détecte automatiquement les emplacements de stockage Roo et scanne les conversations existantes.

```json
{
  "found": true,
  "locations": [...],
  "conversations": [...],
  "totalConversations": 42,
  "totalSize": 1048576,
  "errors": []
}
```

#### `get_storage_stats`
Obtient les statistiques globales du stockage Roo.

```json
{
  "totalLocations": 1,
  "totalConversations": 42,
  "totalSize": 1048576,
  "oldestConversation": "task-123",
  "newestConversation": "task-456"
}
```

#### `find_conversation`
Recherche une conversation spécifique par son ID de tâche.

```json
{
  "taskId": "task-123",
  "path": "/path/to/conversation",
  "metadata": {...},
  "messageCount": 15,
  "lastActivity": "2025-05-26T10:00:00Z",
  "hasApiHistory": true,
  "hasUiMessages": true,
  "size": 2048
}
```

#### `list_conversations`
Liste toutes les conversations avec filtres et tri.

Paramètres :
- `limit` : Nombre maximum de résultats (défaut: 50)
- `sortBy` : Critère de tri (`lastActivity`, `messageCount`, `size`)
- `sortOrder` : Ordre de tri (`asc`, `desc`)
- `hasApiHistory` : Filtrer par présence d'historique API
- `hasUiMessages` : Filtrer par présence de messages UI

#### `validate_custom_path`
Valide un chemin de stockage Roo personnalisé.

## 📊 Format des Données Roo

### Structure de Stockage Détectée

```
{globalStoragePath}/
├── tasks/
│   └── {taskId}/
│       ├── api_conversation_history.json  # Messages API (format Anthropic)
│       ├── ui_messages.json              # Messages UI (ClineMessage)
│       └── task_metadata.json            # Métadonnées de la tâche
└── settings/                             # Configurations Roo
```

### Types de Messages

#### Messages API (Anthropic)
```typescript
interface ApiMessage {
  role: 'user' | 'assistant';
  content: string | Array<{
    type: 'text' | 'image';
    text?: string;
    source?: {...};
  }>;
  timestamp?: string;
}
```

#### Messages UI (Cline)
```typescript
interface ClineMessage {
  id: string;
  type: 'ask' | 'say' | 'completion_result' | 'tool_use' | 'tool_result';
  text?: string;
  tool?: string;
  toolInput?: any;
  toolResult?: any;
  timestamp: string;
  isError?: boolean;
}
```

## 🧪 Tests

### Test du Détecteur de Stockage

```bash
npm run test:detector
```

Ce test :
1. Détecte automatiquement le stockage Roo
2. Affiche les emplacements trouvés
3. Liste les conversations récentes
4. Calcule les statistiques globales
5. Teste la recherche de conversations
6. Valide des chemins personnalisés

### Exemple de Sortie

```
🔍 Test du détecteur de stockage Roo

📍 Test 1: Détection automatique du stockage Roo...
✅ Détection terminée:
   - Stockage trouvé: OUI
   - Emplacements détectés: 1
   - Conversations trouvées: 15
   - Taille totale: 2.5 MB

📂 Emplacements de stockage détectés:
   1. C:\Users\User\AppData\Roaming\Code\User\globalStorage\saoudrizwan.claude-dev-1.0.0
      - Tasks: ...\tasks
      - Settings: ...\settings

💬 Conversations récentes (5 dernières):
   1. task-abc123
      - Messages: 25
      - Dernière activité: 26/05/2025 10:30:00
      - Taille: 512 KB
      - API: ✅ | UI: ✅
```

## 🔧 Configuration

### Intégration MCP

Ajoutez le serveur à votre configuration MCP :

```json
{
  "mcpServers": {
    "roo-state-manager": {
      "command": "node",
      "args": ["path/to/roo-state-manager/build/index.js"]
    }
  }
}
```

### Variables d'Environnement

- `ROO_STORAGE_PATH` : Chemin personnalisé vers le stockage Roo
- `ROO_DEBUG` : Active les logs de débogage

## 🛠️ Développement

### Scripts Disponibles

- `npm run build` : Compilation TypeScript
- `npm run dev` : Compilation en mode watch
- `npm run test` : Tests Jest
- `npm run test:detector` : Test du détecteur de stockage
- `npm run start` : Démarrage du serveur MCP

### Architecture

Le projet suit l'architecture MCP standard avec :
- **Types** : Interfaces TypeScript pour la cohérence des données
- **Utils** : Utilitaires de détection et manipulation du stockage
- **Server** : Serveur MCP principal avec gestion des outils

## 📝 Roadmap

- [ ] Sauvegarde automatique des conversations
- [ ] Restauration sélective de conversations
- [ ] Synchronisation entre machines
- [ ] Interface web de gestion
- [ ] Export vers formats standards
- [ ] Compression et archivage automatique

## 🤝 Contribution

1. Fork le projet
2. Créez une branche feature (`git checkout -b feature/nouvelle-fonctionnalite`)
3. Committez vos changements (`git commit -am 'Ajout nouvelle fonctionnalité'`)
4. Push vers la branche (`git push origin feature/nouvelle-fonctionnalite`)
5. Créez une Pull Request

## 📄 Licence

MIT License - voir le fichier LICENSE pour plus de détails.