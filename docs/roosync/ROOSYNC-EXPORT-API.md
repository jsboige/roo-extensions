# RooSync Export API Documentation

**Version:** 1.0.0  
**Issue:** #376 - CONS-10 Consolidation Export  
**Date:** 2026-02-06  
**Auteur:** Roo Code (Phase 4.3 - Documentation API)

---

## Table des Matières

1. [Vue d'ensemble](#vue-densemble)
2. [Outil `export_data`](#outil-export_data)
3. [Outil `export_config`](#outil-export_config)
4. [Architecture](#architecture)
5. [Schema Zod](#schema-zod)
6. [Exemples d'usage](#exemples-dusage)
7. [Migration depuis les anciens outils](#migration-depuis-les-anciens-outils)

---

## Vue d'ensemble

### Consolidation CONS-10

Les outils d'export ont été consolidés de **6 outils séparés** à **2 outils unifiés** :

| Aspect | Avant (6 outils) | Après (2 outils) |
|--------|------------------|------------------|
| **Outils** | `export_tasks_xml`, `export_conversation_xml`, `export_project_xml`, `export_conversation_json`, `export_conversation_csv`, `configure_xml_export` | `export_data`, `export_config` |
| **API** | 6 endpoints distincts | 2 endpoints action-based |
| **Formats** | XML, JSON, CSV séparés | Formats paramétrables |
| **Configuration** | `configure_xml_export` | `export_config` (get/set/reset) |

### Outils Disponibles

#### 1. `export_data`
Outil consolidé pour exporter des données au format XML, JSON ou CSV.

**Cibles supportées :**
- `task` : Export d'une tâche individuelle (XML uniquement)
- `conversation` : Export d'une conversation complète (tous formats)
- `project` : Export d'un projet entier (XML uniquement)

**Formats supportés :**
- `xml` : Format XML structuré
- `json` : Format JSON avec variantes light/full
- `csv` : Format CSV avec variantes conversations/messages/tools

#### 2. `export_config`
Gère les paramètres de configuration des exports.

**Actions supportées :**
- `get` : Récupère la configuration actuelle
- `set` : Met à jour la configuration
- `reset` : Remet la configuration aux valeurs par défaut

---

## Outil `export_data`

### Description

Outil consolidé pour exporter des données au format XML, JSON ou CSV.

**Nom du tool :** `export_data`  
**Module :** `tools/export/export-data.ts`  
**Version :** 1.0.0 (CONS-10)

### Paramètres

#### Paramètres Requis

| Paramètre | Type | Description |
|-----------|-------|-------------|
| `target` | `string` | Cible de l'export : `task`, `conversation`, ou `project` |
| `format` | `string` | Format de sortie : `xml`, `json`, ou `csv` |

#### Paramètres Optionnels

| Paramètre | Type | Description | Défaut |
|-----------|-------|-------------|----------|
| `taskId` | `string` | ID de la tâche (requis pour target=task, ou conversation avec json/csv) | - |
| `conversationId` | `string` | ID de la conversation racine (requis pour target=conversation avec xml) | - |
| `projectPath` | `string` | Chemin du projet (requis pour target=project) | - |
| `filePath` | `string` | Chemin de sortie pour le fichier. Si non fourni, retourne le contenu. | - |

#### Options XML

| Paramètre | Type | Description | Défaut |
|-----------|-------|-------------|----------|
| `includeContent` | `boolean` | Inclure le contenu complet des messages (XML) | `false` |
| `prettyPrint` | `boolean` | Indenter pour lisibilité (XML) | `true` |
| `maxDepth` | `number` | Profondeur max de l'arbre de tâches (XML conversation) | - |
| `startDate` | `string` | Date de début ISO 8601 pour filtrer (XML project) | - |
| `endDate` | `string` | Date de fin ISO 8601 pour filtrer (XML project) | - |

#### Options JSON

| Paramètre | Type | Description | Défaut |
|-----------|-------|-------------|----------|
| `jsonVariant` | `string` | Variante JSON : `light` (squelette) ou `full` (détail complet) | `light` |

#### Options CSV

| Paramètre | Type | Description | Défaut |
|-----------|-------|-------------|----------|
| `csvVariant` | `string` | Variante CSV : `conversations`, `messages`, ou `tools` | `conversations` |

#### Options Communes JSON/CSV

| Paramètre | Type | Description | Défaut |
|-----------|-------|-------------|----------|
| `truncationChars` | `number` | Max caractères avant troncature (0 = pas de troncature) | `0` |
| `startIndex` | `number` | Index de début (1-based) pour plage de messages | - |
| `endIndex` | `number` | Index de fin (1-based) pour plage de messages | - |

### Combinaisons Target/Format Supportées

| Target | Formats Supportés |
|--------|-------------------|
| `task` | `xml` |
| `conversation` | `xml`, `json`, `csv` |
| `project` | `xml` |

### Valeurs de Retour

**Succès :**
```json
{
  "content": [
    {
      "type": "text",
      "text": "Contenu de l'export ou message de confirmation"
    }
  ]
}
```

**Erreur :**
```json
{
  "isError": true,
  "content": [
    {
      "type": "text",
      "text": "Erreur: description de l'erreur"
    }
  ]
}
```

### Codes d'Erreur

| Code | Description |
|-------|-------------|
| `INVALID_TARGET_FORMAT_COMBINATION` | Combinaison target/format non supportée |
| `MISSING_REQUIRED_PARAM` | Paramètre requis manquant |
| `TASK_NOT_FOUND` | Tâche non trouvée dans le cache |
| `CONVERSATION_NOT_FOUND` | Conversation non trouvée |
| `PROJECT_NOT_FOUND` | Projet non trouvé |

---

## Outil `export_config`

### Description

Gère les paramètres de configuration des exports.

**Nom du tool :** `export_config`  
**Module :** `tools/export/export-config.ts`  
**Version :** 1.0.0 (CONS-10)

### Paramètres

#### Paramètres Requis

| Paramètre | Type | Description |
|-----------|-------|-------------|
| `action` | `string` | Action à effectuer : `get`, `set`, ou `reset` |

#### Paramètres Optionnels

| Paramètre | Type | Description |
|-----------|-------|-------------|
| `config` | `object` | Objet de configuration pour l'action `set` |

### Actions

#### Action `get`

Récupère la configuration actuelle des exports.

**Paramètres :**
```json
{
  "action": "get"
}
```

**Retour :**
```json
{
  "content": [
    {
      "type": "text",
      "text": "{\n  \"prettyPrint\": true,\n  \"includeContent\": false,\n  \"truncationChars\": 0,\n  \"jsonVariant\": \"light\",\n  \"csvVariant\": \"conversations\",\n  \"maxDepth\": 10\n}"
    }
  ]
}
```

#### Action `set`

Met à jour la configuration des exports.

**Paramètres :**
```json
{
  "action": "set",
  "config": {
    "prettyPrint": false,
    "includeContent": true,
    "truncationChars": 10000,
    "jsonVariant": "full",
    "csvVariant": "messages",
    "maxDepth": 5
  }
}
```

**Retour :**
```json
{
  "content": [
    {
      "type": "text",
      "text": "Configuration mise à jour avec succès."
    }
  ]
}
```

#### Action `reset`

Remet la configuration aux valeurs par défaut.

**Paramètres :**
```json
{
  "action": "reset"
}
```

**Retour :**
```json
{
  "content": [
    {
      "type": "text",
      "text": "Configuration remise aux valeurs par défaut."
    }
  ]
}
```

### Configuration Supportée

| Propriété | Type | Description | Défaut |
|-----------|-------|-------------|----------|
| `prettyPrint` | `boolean` | Indenter pour lisibilité (XML/JSON) | `true` |
| `includeContent` | `boolean` | Inclure le contenu complet des messages (XML) | `false` |
| `truncationChars` | `number` | Max caractères avant troncature | `0` |
| `jsonVariant` | `string` | Variante JSON : `light` ou `full` | `light` |
| `csvVariant` | `string` | Variante CSV : `conversations`, `messages`, ou `tools` | `conversations` |
| `maxDepth` | `number` | Profondeur max de l'arbre de tâches (XML conversation) | `10` |

### Codes d'Erreur

| Code | Description |
|-------|-------------|
| `VALIDATION_FAILED` | Paramètre de configuration manquant pour l'action `set` |
| `INVALID_ACTION` | Action invalide |

---

## Architecture

### Structure des Modules

```
tools/export/
├── export-data.ts          # Outil consolidé export_data
├── export-config.ts        # Outil export_config
├── export-tasks-xml.ts    # Legacy (remplacé par export-data)
├── export-conversation-xml.ts  # Legacy (remplacé par export-data)
├── export-project-xml.ts  # Legacy (remplacé par export-data)
├── export-conversation-json.ts  # Legacy (remplacé par export-data)
├── export-conversation-csv.ts   # Legacy (remplacé par export-data)
├── configure-xml-export.ts # Legacy (remplacé par export-config)
└── index.ts              # Export centralisé
```

### Services Utilisés

#### XmlExporterService
Service pour générer et sauvegarder des exports XML.

**Méthodes :**
- `generateTaskXml(skeleton, options)` : Génère XML pour une tâche
- `generateConversationXml(tasks, options)` : Génère XML pour une conversation
- `generateProjectXml(tasks, options)` : Génère XML pour un projet
- `saveXmlToFile(content, filePath)` : Sauvegarde XML dans un fichier

#### TraceSummaryService
Service pour générer des résumés de traces (JSON/CSV).

**Méthodes :**
- `generateSummary(conversation, options)` : Génère résumé avec options de format

#### ExportConfigManager
Service pour gérer la configuration des exports.

**Méthodes :**
- `getConfig()` : Récupère la configuration actuelle
- `updateConfig(config)` : Met à jour la configuration
- `resetConfig()` : Remet la configuration aux valeurs par défaut

### Flux de Traitement

```
┌─────────────────┐
│  export_data    │
│  (MCP Tool)    │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────┐
│  Validation Target/Format      │
│  - Vérifie combinaison valide  │
│  - Vérifie paramètres requis  │
└────────┬────────────────────────┘
         │
         ▼
┌─────────────────────────────────┐
│  Dispatch par Target/Format    │
└────────┬────────────────────────┘
         │
    ┌────┴────┬────────────┬────────────┐
    ▼         ▼            ▼            ▼
┌──────┐ ┌──────┐   ┌──────┐   ┌──────┐
│Task  │ │Conv  │   │Conv  │   │Proj  │
│XML   │ │XML   │   │JSON  │   │XML   │
└───┬──┘ └───┬──┘   └───┬──┘   └───┬──┘
    │         │           │           │
    ▼         ▼           ▼           ▼
┌─────────────────────────────────────────┐
│  Services (XmlExporter,             │
│  TraceSummary, ExportConfigManager)  │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────┐
│  Retour/Save   │
│  - Contenu     │
│  - Fichier     │
└─────────────────┘
```

---

## Schema Zod

### Schema pour `export_data`

```typescript
import { z } from 'zod';

/**
 * Types d'export supportés
 */
export const ExportTarget = z.enum(['task', 'conversation', 'project']);

/**
 * Formats d'export disponibles
 */
export const ExportFormat = z.enum(['xml', 'json', 'csv']);

/**
 * Variantes JSON
 */
export const JsonVariant = z.enum(['light', 'full']);

/**
 * Variantes CSV
 */
export const CsvVariant = z.enum(['conversations', 'messages', 'tools']);

/**
 * Options communes à tous les exports
 */
export const CommonExportOptions = z.object({
  /** Chemin de sortie pour le fichier (optionnel) */
  filePath: z.string().optional(),
  /** Indenter le format pour une meilleure lisibilité (XML/JSON) */
  prettyPrint: z.boolean().optional().default(true),
  /** Nombre max de caractères avant troncature (0 = pas de troncature) */
  truncationChars: z.number().int().min(0).optional().default(0),
});

/**
 * Options spécifiques à l'action 'task'
 */
export const TaskExportOptions = z.object({
  /** Identifiant unique de la tâche à exporter */
  taskId: z.string().min(1),
  /** Inclure le contenu complet des messages (XML) */
  includeContent: z.boolean().optional().default(false),
});

/**
 * Options spécifiques à l'action 'conversation'
 */
export const ConversationExportOptions = z.object({
  /** Identifiant de la tâche racine de la conversation */
  conversationId: z.string().min(1),
  /** Profondeur maximale de l'arbre de tâches (XML) */
  maxDepth: z.number().int().min(1).optional(),
  /** Inclure le contenu complet des messages (XML) */
  includeContent: z.boolean().optional().default(false),
});

/**
 * Options spécifiques à l'action 'project'
 */
export const ProjectExportOptions = z.object({
  /** Chemin du workspace/projet à analyser */
  projectPath: z.string().min(1),
  /** Date de début (ISO 8601) pour filtrer les conversations */
  startDate: z.string().datetime().optional(),
  /** Date de fin (ISO 8601) pour filtrer les conversations */
  endDate: z.string().datetime().optional(),
});

/**
 * Options spécifiques au format JSON
 */
export const JsonFormatOptions = z.object({
  /** Variante JSON : light (squelette) ou full (détail complet) */
  jsonVariant: JsonVariant.optional().default('light'),
  /** Index de début (1-based) pour traiter une plage de messages */
  startIndex: z.number().int().min(1).optional(),
  /** Index de fin (1-based) pour traiter une plage de messages */
  endIndex: z.number().int().min(1).optional(),
});

/**
 * Options spécifiques au format CSV
 */
export const CsvFormatOptions = z.object({
  /** Variante CSV : conversations, messages, ou tools */
  csvVariant: CsvVariant.optional().default('conversations'),
  /** Index de début (1-based) pour traiter une plage de messages */
  startIndex: z.number().int().min(1).optional(),
  /** Index de fin (1-based) pour traiter une plage de messages */
  endIndex: z.number().int().min(1).optional(),
});

/**
 * Schema principal pour export_data
 * 
 * Design decision: Target-based API avec discriminated union
 * - La cible détermine les paramètres requis
 * - Le format détermine les options spécifiques
 */
export const ExportDataSchema = z.discriminatedUnion('target', [
  // Target: task
  z.object({
    target: z.literal('task'),
    format: z.literal('xml'), // Task only supports XML
    taskId: z.string().min(1),
    filePath: z.string().optional(),
    prettyPrint: z.boolean().optional().default(true),
    truncationChars: z.number().int().min(0).optional().default(0),
    includeContent: z.boolean().optional().default(false),
  }),
  
  // Target: conversation
  z.object({
    target: z.literal('conversation'),
    format: ExportFormat,
    taskId: z.string().min(1), // Required for JSON/CSV
    conversationId: z.string().min(1).optional(), // Required for XML
    filePath: z.string().optional(),
    prettyPrint: z.boolean().optional().default(true),
    truncationChars: z.number().int().min(0).optional().default(0),
    // XML-specific
    maxDepth: z.number().int().min(1).optional(),
    includeContent: z.boolean().optional().default(false),
    // JSON-specific
    jsonVariant: JsonVariant.optional().default('light'),
    // CSV-specific
    csvVariant: CsvVariant.optional().default('conversations'),
    startIndex: z.number().int().min(1).optional(),
    endIndex: z.number().int().min(1).optional(),
  }),
  
  // Target: project
  z.object({
    target: z.literal('project'),
    format: z.literal('xml'), // Project only supports XML
    projectPath: z.string().min(1),
    filePath: z.string().optional(),
    prettyPrint: z.boolean().optional().default(true),
    startDate: z.string().datetime().optional(),
    endDate: z.string().datetime().optional(),
  }),
]);

/**
 * Types TypeScript dérivés du schema Zod
 */
export type ExportDataInput = z.infer<typeof ExportDataSchema>;
export type ExportTargetType = z.infer<typeof ExportTarget>;
export type ExportFormatType = z.infer<typeof ExportFormat>;
export type JsonVariantType = z.infer<typeof JsonVariant>;
export type CsvVariantType = z.infer<typeof CsvVariant>;
```

### Schema pour `export_config`

```typescript
/**
 * Actions de configuration
 */
export const ConfigAction = z.enum(['get', 'set', 'reset']);

/**
 * Schema pour export_config
 */
export const ExportConfigSchema = z.discriminatedUnion('action', [
  // Action: get
  z.object({
    action: z.literal('get'),
  }),
  
  // Action: set
  z.object({
    action: z.literal('set'),
    config: z.object({
      prettyPrint: z.boolean().optional(),
      includeContent: z.boolean().optional(),
      truncationChars: z.number().int().min(0).optional(),
      jsonVariant: JsonVariant.optional(),
      csvVariant: CsvVariant.optional(),
      maxDepth: z.number().int().min(1).optional(),
    }),
  }),
  
  // Action: reset
  z.object({
    action: z.literal('reset'),
  }),
]);

export type ExportConfigInput = z.infer<typeof ExportConfigSchema>;
```

---

## Exemples d'Usage

### Exemple 1 : Export Task → XML (basique)

```json
{
  "target": "task",
  "format": "xml",
  "taskId": "task-123"
}
```

**Résultat :** Retourne le XML de la tâche `task-123`.

---

### Exemple 2 : Export Task → XML (avec contenu)

```json
{
  "target": "task",
  "format": "xml",
  "taskId": "task-123",
  "includeContent": true,
  "prettyPrint": true
}
```

**Résultat :** Retourne le XML de la tâche avec le contenu complet des messages.

---

### Exemple 3 : Export Task → XML (vers fichier)

```json
{
  "target": "task",
  "format": "xml",
  "taskId": "task-123",
  "filePath": "/tmp/task-123.xml"
}
```

**Résultat :** Sauvegarde le XML dans `/tmp/task-123.xml` et retourne un message de confirmation.

---

### Exemple 4 : Export Conversation → XML (basique)

```json
{
  "target": "conversation",
  "format": "xml",
  "conversationId": "conv-456"
}
```

**Résultat :** Retourne le XML de la conversation racine `conv-456`.

---

### Exemple 5 : Export Conversation → XML (avec maxDepth)

```json
{
  "target": "conversation",
  "format": "xml",
  "conversationId": "conv-456",
  "maxDepth": 5,
  "includeContent": false
}
```

**Résultat :** Retourne le XML de la conversation limité à une profondeur de 5 niveaux.

---

### Exemple 6 : Export Conversation → JSON (light)

```json
{
  "target": "conversation",
  "format": "json",
  "taskId": "conv-456",
  "jsonVariant": "light"
}
```

**Résultat :** Retourne le JSON light (squelette) de la conversation.

---

### Exemple 7 : Export Conversation → JSON (full)

```json
{
  "target": "conversation",
  "format": "json",
  "taskId": "conv-456",
  "jsonVariant": "full",
  "truncationChars": 10000
}
```

**Résultat :** Retourne le JSON full (détail complet) avec troncature à 10000 caractères.

---

### Exemple 8 : Export Conversation → JSON (plage de messages)

```json
{
  "target": "conversation",
  "format": "json",
  "taskId": "conv-456",
  "startIndex": 1,
  "endIndex": 50
}
```

**Résultat :** Retourne le JSON des messages 1 à 50 de la conversation.

---

### Exemple 9 : Export Conversation → CSV (conversations)

```json
{
  "target": "conversation",
  "format": "csv",
  "taskId": "conv-456",
  "csvVariant": "conversations"
}
```

**Résultat :** Retourne le CSV avec les métadonnées des conversations.

---

### Exemple 10 : Export Conversation → CSV (messages)

```json
{
  "target": "conversation",
  "format": "csv",
  "taskId": "conv-456",
  "csvVariant": "messages",
  "startIndex": 1,
  "endIndex": 100
}
```

**Résultat :** Retourne le CSV des messages 1 à 100 de la conversation.

---

### Exemple 11 : Export Conversation → CSV (tools)

```json
{
  "target": "conversation",
  "format": "csv",
  "taskId": "conv-456",
  "csvVariant": "tools"
}
```

**Résultat :** Retourne le CSV des appels d'outils de la conversation.

---

### Exemple 12 : Export Project → XML (basique)

```json
{
  "target": "project",
  "format": "xml",
  "projectPath": "/path/to/project"
}
```

**Résultat :** Retourne le XML de toutes les conversations du projet.

---

### Exemple 13 : Export Project → XML (avec filtre de dates)

```json
{
  "target": "project",
  "format": "xml",
  "projectPath": "/path/to/project",
  "startDate": "2026-01-01T00:00:00Z",
  "endDate": "2026-01-31T23:59:59Z"
}
```

**Résultat :** Retourne le XML des conversations du projet pour janvier 2026.

---

### Exemple 14 : Export Config → Get

```json
{
  "action": "get"
}
```

**Résultat :** Retourne la configuration actuelle des exports.

---

### Exemple 15 : Export Config → Set

```json
{
  "action": "set",
  "config": {
    "prettyPrint": false,
    "includeContent": true,
    "truncationChars": 5000,
    "jsonVariant": "full",
    "csvVariant": "messages",
    "maxDepth": 10
  }
}
```

**Résultat :** Met à jour la configuration et retourne un message de confirmation.

---

### Exemple 16 : Export Config → Reset

```json
{
  "action": "reset"
}
```

**Résultat :** Remet la configuration aux valeurs par défaut.

---

### Exemple 17 : Export Conversation → JSON (vers fichier)

```json
{
  "target": "conversation",
  "format": "json",
  "taskId": "conv-456",
  "jsonVariant": "full",
  "filePath": "/tmp/conversation-456.json"
}
```

**Résultat :** Sauvegarde le JSON dans `/tmp/conversation-456.json`.

---

### Exemple 18 : Export Project → XML (vers fichier)

```json
{
  "target": "project",
  "format": "xml",
  "projectPath": "/path/to/project",
  "filePath": "/tmp/project-export.xml",
  "prettyPrint": true
}
```

**Résultat :** Sauvegarde le XML du projet dans `/tmp/project-export.xml`.

---

### Exemple 19 : Export Conversation → CSV (avec troncature)

```json
{
  "target": "conversation",
  "format": "csv",
  "taskId": "conv-456",
  "csvVariant": "messages",
  "truncationChars": 5000
}
```

**Résultat :** Retourne le CSV des messages avec troncature à 5000 caractères.

---

### Exemple 20 : Export Task → XML (sans indentation)

```json
{
  "target": "task",
  "format": "xml",
  "taskId": "task-123",
  "prettyPrint": false
}
```

**Résultat :** Retourne le XML compact sans indentation.

---

## Migration depuis les Anciens Outils

### Mapping Ancien → Nouveau

| Ancien Outil | Nouvel Outil | Target | Format | Paramètres Clés |
|--------------|--------------|---------|--------|-----------------|
| `export_tasks_xml` | `export_data` | `task` | `xml` | `taskId`, `includeContent` |
| `export_conversation_xml` | `export_data` | `conversation` | `xml` | `conversationId`, `maxDepth`, `includeContent` |
| `export_project_xml` | `export_data` | `project` | `xml` | `projectPath`, `startDate`, `endDate` |
| `export_conversation_json` | `export_data` | `conversation` | `json` | `taskId`, `jsonVariant` |
| `export_conversation_csv` | `export_data` | `conversation` | `csv` | `taskId`, `csvVariant` |
| `configure_xml_export` | `export_config` | - | - | `action`, `config` |

### Exemples de Migration

#### Migration `export_tasks_xml` → `export_data`

**Ancien appel :**
```json
{
  "taskId": "task-123",
  "includeContent": true,
  "prettyPrint": true
}
```

**Nouvel appel :**
```json
{
  "target": "task",
  "format": "xml",
  "taskId": "task-123",
  "includeContent": true,
  "prettyPrint": true
}
```

**Changements :**
- Ajout de `target: "task"`
- Ajout de `format: "xml"`

---

#### Migration `export_conversation_xml` → `export_data`

**Ancien appel :**
```json
{
  "conversationId": "conv-456",
  "maxDepth": 5,
  "includeContent": false,
  "prettyPrint": true
}
```

**Nouvel appel :**
```json
{
  "target": "conversation",
  "format": "xml",
  "conversationId": "conv-456",
  "maxDepth": 5,
  "includeContent": false,
  "prettyPrint": true
}
```

**Changements :**
- Ajout de `target: "conversation"`
- Ajout de `format: "xml"`

---

#### Migration `export_project_xml` → `export_data`

**Ancien appel :**
```json
{
  "projectPath": "/path/to/project",
  "startDate": "2026-01-01T00:00:00Z",
  "endDate": "2026-01-31T23:59:59Z",
  "prettyPrint": true
}
```

**Nouvel appel :**
```json
{
  "target": "project",
  "format": "xml",
  "projectPath": "/path/to/project",
  "startDate": "2026-01-01T00:00:00Z",
  "endDate": "2026-01-31T23:59:59Z",
  "prettyPrint": true
}
```

**Changements :**
- Ajout de `target: "project"`
- Ajout de `format: "xml"` (obligatoire, seul format supporté)

---

#### Migration `export_conversation_json` → `export_data`

**Ancien appel (light) :**
```json
{
  "conversationId": "conv-456",
  "variant": "light",
  "truncationChars": 10000
}
```

**Nouvel appel (light) :**
```json
{
  "target": "conversation",
  "format": "json",
  "taskId": "conv-456",
  "jsonVariant": "light",
  "truncationChars": 10000
}
```

**Ancien appel (full) :**
```json
{
  "conversationId": "conv-456",
  "variant": "full"
}
```

**Nouvel appel (full) :**
```json
{
  "target": "conversation",
  "format": "json",
  "taskId": "conv-456",
  "jsonVariant": "full"
}
```

**Changements :**
- Ajout de `target: "conversation"`
- Ajout de `format: "json"`
- `conversationId` → `taskId` (pour JSON)
- `variant` → `jsonVariant`

---

#### Migration `export_conversation_csv` → `export_data`

**Ancien appel (conversations) :**
```json
{
  "conversationId": "conv-456",
  "variant": "conversations"
}
```

**Nouvel appel (conversations) :**
```json
{
  "target": "conversation",
  "format": "csv",
  "taskId": "conv-456",
  "csvVariant": "conversations"
}
```

**Ancien appel (messages) :**
```json
{
  "conversationId": "conv-456",
  "variant": "messages",
  "startIndex": 1,
  "endIndex": 50
}
```

**Nouvel appel (messages) :**
```json
{
  "target": "conversation",
  "format": "csv",
  "taskId": "conv-456",
  "csvVariant": "messages",
  "startIndex": 1,
  "endIndex": 50
}
```

**Changements :**
- Ajout de `target: "conversation"`
- Ajout de `format: "csv"`
- `conversationId` → `taskId` (pour CSV)
- `variant` → `csvVariant`

---

#### Migration `configure_xml_export` → `export_config`

**Ancien appel (get) :**
```json
{}
```

**Nouvel appel (get) :**
```json
{
  "action": "get"
}
```

**Ancien appel (set) :**
```json
{
  "prettyPrint": false,
  "includeContent": true
}
```

**Nouvel appel (set) :**
```json
{
  "action": "set",
  "config": {
    "prettyPrint": false,
    "includeContent": true
  }
}
```

**Ancien appel (reset) :**
```json
{
  "reset": true
}
```

**Nouvel appel (reset) :**
```json
{
  "action": "reset"
}
```

**Changements :**
- Ajout de `action` explicite (`get`, `set`, `reset`)
- Pour `set`, les paramètres sont encapsulés dans `config`

---

## Références

- **Issue #376 :** https://github.com/jsboige/roo-extensions/issues/376
- **Guide de Migration :** [`CONS-10-MIGRATION-GUIDE.md`](CONS-10-MIGRATION-GUIDE.md)
- **Design Document :** [`CONS-10-design.md`](CONS-10-design.md)
- **Tests E2E :** `tests/e2e/tools/export.test.ts`

---

**Document généré automatiquement par Roo Code (Phase 4.3 - Documentation API)**
