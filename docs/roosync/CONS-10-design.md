# CONS-10 Phase 2: Design - Consolidation Export (6→2 outils)

**Issue:** #376 - Consolidation Export
**Date:** 2026-02-04
**Auteur:** Roo Code (Phase 2 - Design)

---

## 1. Vue d'ensemble

### Objectif
Consolider 6 outils d'export en 2 outils unifiés :
- **`roosync_export`** - Export unifié (task/conversation/project, xml/json/csv)
- **`roosync_export_config`** - Configuration des exports

### État AVANT (6 outils)
1. `export_tasks_xml` - Task individuelle → XML
2. `export_conversation_xml` - Conversation → XML
3. `export_project_xml` - Projet complet → XML
4. `export_conversation_json` - Conversation → JSON light/full
5. `export_conversation_csv` - Conversation → CSV conv/msg/tools
6. `configure_xml_export` - Config get/set/reset

### État APRÈS (2 outils)
1. **`roosync_export`** - Action-based API unifiée
2. **`roosync_export_config`** - Configuration (get/set/reset)

---

## 2. Schema Zod Complet pour `roosync_export`

### 2.1 Structure Générale

```typescript
import { z } from 'zod';

/**
 * Actions d'export disponibles
 */
export const ExportAction = z.enum(['task', 'conversation', 'project']);

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
 * Schema principal pour roosync_export
 * 
 * Design decision: Action-based API avec discriminated union
 * - L'action détermine les paramètres requis
 * - Le format détermine les options spécifiques
 */
export const RoosyncExportSchema = z.discriminatedUnion('action', [
  // Action: task
  z.object({
    action: z.literal('task'),
    format: ExportFormat,
    taskId: z.string().min(1),
    filePath: z.string().optional(),
    prettyPrint: z.boolean().optional().default(true),
    truncationChars: z.number().int().min(0).optional().default(0),
    // XML-specific
    includeContent: z.boolean().optional().default(false),
    // JSON-specific
    jsonVariant: JsonVariant.optional().default('light'),
    startIndex: z.number().int().min(1).optional(),
    endIndex: z.number().int().min(1).optional(),
  }),
  
  // Action: conversation
  z.object({
    action: z.literal('conversation'),
    format: ExportFormat,
    conversationId: z.string().min(1),
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
  
  // Action: project
  z.object({
    action: z.literal('project'),
    format: z.literal('xml'), // Project export only supports XML
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
export type RoosyncExportInput = z.infer<typeof RoosyncExportSchema>;
export type ExportActionType = z.infer<typeof ExportAction>;
export type ExportFormatType = z.infer<typeof ExportFormat>;
export type JsonVariantType = z.infer<typeof JsonVariant>;
export type CsvVariantType = z.infer<typeof CsvVariant>;
```

### 2.2 Exemples d'Utilisation

```typescript
// Export task → XML
{
  action: 'task',
  format: 'xml',
  taskId: 'task-123',
  includeContent: true,
  prettyPrint: true
}

// Export conversation → JSON (full)
{
  action: 'conversation',
  format: 'json',
  conversationId: 'conv-456',
  jsonVariant: 'full',
  truncationChars: 10000
}

// Export conversation → CSV (messages)
{
  action: 'conversation',
  format: 'csv',
  conversationId: 'conv-456',
  csvVariant: 'messages',
  startIndex: 1,
  endIndex: 50
}

// Export project → XML
{
  action: 'project',
  format: 'xml',
  projectPath: '/path/to/project',
  startDate: '2026-01-01T00:00:00Z',
  endDate: '2026-01-31T23:59:59Z'
}
```

---

## 3. Schema Zod pour `roosync_export_config`

```typescript
/**
 * Actions de configuration
 */
export const ConfigAction = z.enum(['get', 'set', 'reset']);

/**
 * Schema pour roosync_export_config
 */
export const RoosyncExportConfigSchema = z.discriminatedUnion('action', [
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

export type RoosyncExportConfigInput = z.infer<typeof RoosyncExportConfigSchema>;
```

---

## 4. Tests Unitaires Requis (TDD)

### 4.1 Tests de Validation Zod

**Fichier:** `src/tools/export/__tests__/roosync-export-schema.test.ts`

```typescript
describe('RoosyncExportSchema Validation', () => {
  describe('Action: task', () => {
    it('should validate task → XML export', () => {
      const input = {
        action: 'task',
        format: 'xml',
        taskId: 'task-123',
        includeContent: true
      };
      expect(() => RoosyncExportSchema.parse(input)).not.toThrow();
    });

    it('should validate task → JSON export with variant', () => {
      const input = {
        action: 'task',
        format: 'json',
        taskId: 'task-123',
        jsonVariant: 'full'
      };
      expect(() => RoosyncExportSchema.parse(input)).not.toThrow();
    });

    it('should reject task export without taskId', () => {
      const input = {
        action: 'task',
        format: 'xml'
      };
      expect(() => RoosyncExportSchema.parse(input)).toThrow();
    });

    it('should reject task export with invalid format', () => {
      const input = {
        action: 'task',
        format: 'invalid',
        taskId: 'task-123'
      };
      expect(() => RoosyncExportSchema.parse(input)).toThrow();
    });
  });

  describe('Action: conversation', () => {
    it('should validate conversation → XML export with maxDepth', () => {
      const input = {
        action: 'conversation',
        format: 'xml',
        conversationId: 'conv-456',
        maxDepth: 5
      };
      expect(() => RoosyncExportSchema.parse(input)).not.toThrow();
    });

    it('should validate conversation → CSV export with variant', () => {
      const input = {
        action: 'conversation',
        format: 'csv',
        conversationId: 'conv-456',
        csvVariant: 'messages'
      };
      expect(() => RoosyncExportSchema.parse(input)).not.toThrow();
    });

    it('should validate conversation → JSON with range', () => {
      const input = {
        action: 'conversation',
        format: 'json',
        conversationId: 'conv-456',
        startIndex: 1,
        endIndex: 50
      };
      expect(() => RoosyncExportSchema.parse(input)).not.toThrow();
    });

    it('should reject conversation export without conversationId', () => {
      const input = {
        action: 'conversation',
        format: 'xml'
      };
      expect(() => RoosyncExportSchema.parse(input)).toThrow();
    });
  });

  describe('Action: project', () => {
    it('should validate project → XML export', () => {
      const input = {
        action: 'project',
        format: 'xml',
        projectPath: '/path/to/project'
      };
      expect(() => RoosyncExportSchema.parse(input)).not.toThrow();
    });

    it('should validate project export with date filters', () => {
      const input = {
        action: 'project',
        format: 'xml',
        projectPath: '/path/to/project',
        startDate: '2026-01-01T00:00:00Z',
        endDate: '2026-01-31T23:59:59Z'
      };
      expect(() => RoosyncExportSchema.parse(input)).not.toThrow();
    });

    it('should reject project export with non-XML format', () => {
      const input = {
        action: 'project',
        format: 'json',
        projectPath: '/path/to/project'
      };
      expect(() => RoosyncExportSchema.parse(input)).toThrow();
    });

    it('should reject project export without projectPath', () => {
      const input = {
        action: 'project',
        format: 'xml'
      };
      expect(() => RoosyncExportSchema.parse(input)).toThrow();
    });
  });

  describe('Common options', () => {
    it('should validate truncationChars', () => {
      const input = {
        action: 'task',
        format: 'json',
        taskId: 'task-123',
        truncationChars: 10000
      };
      expect(() => RoosyncExportSchema.parse(input)).not.toThrow();
    });

    it('should reject negative truncationChars', () => {
      const input = {
        action: 'task',
        format: 'json',
        taskId: 'task-123',
        truncationChars: -1
      };
      expect(() => RoosyncExportSchema.parse(input)).toThrow();
    });

    it('should validate prettyPrint', () => {
      const input = {
        action: 'task',
        format: 'xml',
        taskId: 'task-123',
        prettyPrint: false
      };
      expect(() => RoosyncExportSchema.parse(input)).not.toThrow();
    });
  });
});
```

### 4.2 Tests d'Intégration

**Fichier:** `src/tools/export/__tests__/roosync-export-integration.test.ts`

```typescript
describe('RoosyncExport Integration', () => {
  describe('Action: task', () => {
    it('should export task to XML and return content', async () => {
      const result = await handleRoosyncExport({
        action: 'task',
        format: 'xml',
        taskId: 'test-task-id'
      }, mockServices);
      
      expect(result.success).toBe(true);
      expect(result.content).toContain('<?xml');
    });

    it('should export task to XML and save to file', async () => {
      const result = await handleRoosyncExport({
        action: 'task',
        format: 'xml',
        taskId: 'test-task-id',
        filePath: '/tmp/test.xml'
      }, mockServices);
      
      expect(result.success).toBe(true);
      expect(result.message).toContain('sauvegardé');
    });

    it('should export task to JSON (light variant)', async () => {
      const result = await handleRoosyncExport({
        action: 'task',
        format: 'json',
        taskId: 'test-task-id',
        jsonVariant: 'light'
      }, mockServices);
      
      expect(result.success).toBe(true);
      expect(result.content).toContain('"taskId"');
    });

    it('should export task to JSON (full variant)', async () => {
      const result = await handleRoosyncExport({
        action: 'task',
        format: 'json',
        taskId: 'test-task-id',
        jsonVariant: 'full'
      }, mockServices);
      
      expect(result.success).toBe(true);
      expect(result.content).toContain('"messages"');
    });
  });

  describe('Action: conversation', () => {
    it('should export conversation to XML with maxDepth', async () => {
      const result = await handleRoosyncExport({
        action: 'conversation',
        format: 'xml',
        conversationId: 'test-conv-id',
        maxDepth: 3
      }, mockServices);
      
      expect(result.success).toBe(true);
      expect(result.content).toContain('<?xml');
    });

    it('should export conversation to CSV (conversations variant)', async () => {
      const result = await handleRoosyncExport({
        action: 'conversation',
        format: 'csv',
        conversationId: 'test-conv-id',
        csvVariant: 'conversations'
      }, mockServices);
      
      expect(result.success).toBe(true);
      expect(result.content).toContain('taskId,');
    });

    it('should export conversation to CSV (messages variant)', async () => {
      const result = await handleRoosyncExport({
        action: 'conversation',
        format: 'csv',
        conversationId: 'test-conv-id',
        csvVariant: 'messages'
      }, mockServices);
      
      expect(result.success).toBe(true);
      expect(result.content).toContain('messageId,');
    });

    it('should export conversation to CSV (tools variant)', async () => {
      const result = await handleRoosyncExport({
        action: 'conversation',
        format: 'csv',
        conversationId: 'test-conv-id',
        csvVariant: 'tools'
      }, mockServices);
      
      expect(result.success).toBe(true);
      expect(result.content).toContain('toolName,');
    });

    it('should export conversation with message range', async () => {
      const result = await handleRoosyncExport({
        action: 'conversation',
        format: 'json',
        conversationId: 'test-conv-id',
        startIndex: 1,
        endIndex: 10
      }, mockServices);
      
      expect(result.success).toBe(true);
    });
  });

  describe('Action: project', () => {
    it('should export project to XML', async () => {
      const result = await handleRoosyncExport({
        action: 'project',
        format: 'xml',
        projectPath: '/test/project'
      }, mockServices);
      
      expect(result.success).toBe(true);
      expect(result.content).toContain('<?xml');
    });

    it('should export project with date filters', async () => {
      const result = await handleRoosyncExport({
        action: 'project',
        format: 'xml',
        projectPath: '/test/project',
        startDate: '2026-01-01T00:00:00Z',
        endDate: '2026-01-31T23:59:59Z'
      }, mockServices);
      
      expect(result.success).toBe(true);
    });
  });

  describe('Error handling', () => {
    it('should handle task not found', async () => {
      const result = await handleRoosyncExport({
        action: 'task',
        format: 'xml',
        taskId: 'non-existent-task'
      }, mockServices);
      
      expect(result.success).toBe(false);
      expect(result.error).toContain('non trouvée');
    });

    it('should handle conversation not found', async () => {
      const result = await handleRoosyncExport({
        action: 'conversation',
        format: 'xml',
        conversationId: 'non-existent-conv'
      }, mockServices);
      
      expect(result.success).toBe(false);
      expect(result.error).toContain('non trouvée');
    });

    it('should handle file write error', async () => {
      const result = await handleRoosyncExport({
        action: 'task',
        format: 'xml',
        taskId: 'test-task-id',
        filePath: '/invalid/path/test.xml'
      }, mockServices);
      
      expect(result.success).toBe(false);
      expect(result.error).toContain('Erreur');
    });
  });
});
```

### 4.3 Tests de Configuration

**Fichier:** `src/tools/export/__tests__/roosync-export-config.test.ts`

```typescript
describe('RoosyncExportConfig', () => {
  describe('Action: get', () => {
    it('should return current config', async () => {
      const result = await handleRoosyncExportConfig({
        action: 'get'
      }, mockConfigManager);
      
      expect(result.success).toBe(true);
      expect(result.config).toBeDefined();
    });
  });

  describe('Action: set', () => {
    it('should update config with valid values', async () => {
      const result = await handleRoosyncExportConfig({
        action: 'set',
        config: {
          prettyPrint: false,
          truncationChars: 5000
        }
      }, mockConfigManager);
      
      expect(result.success).toBe(true);
      expect(result.message).toContain('mise à jour');
    });

    it('should reject set without config', async () => {
      const result = await handleRoosyncExportConfig({
        action: 'set'
      }, mockConfigManager);
      
      expect(result.success).toBe(false);
    });
  });

  describe('Action: reset', () => {
    it('should reset config to defaults', async () => {
      const result = await handleRoosyncExportConfig({
        action: 'reset'
      }, mockConfigManager);
      
      expect(result.success).toBe(true);
      expect(result.message).toContain('remise aux valeurs par défaut');
    });
  });
});
```

---

## 5. Approche Technique

### 5.1 Architecture

```
roosync_export (unified tool)
├── Validation (Zod schemas)
│   ├── RoosyncExportSchema
│   └── RoosyncExportConfigSchema
├── Handler principal
│   ├── Action dispatcher
│   ├── Format dispatcher
│   └── Service delegation
└── Services existants (réutilisés)
    ├── XmlExporterService
    ├── TraceSummaryService (JSON/CSV)
    └── ExportConfigManager
```

### 5.2 Design Decisions

#### Decision 1: Action-based API vs Format-based API
**Choix:** Action-based API

**Raisons:**
- Plus naturel pour l'utilisateur : "je veux exporter une tâche" vs "je veux du XML"
- Permet des validations plus précises (taskId vs conversationId vs projectPath)
- Facilite l'extension future (nouvelles actions)

#### Decision 2: Discriminated Union vs Optional Parameters
**Choix:** Discriminated Union (Zod)

**Raisons:**
- Type safety maximale
- Validation explicite des paramètres requis par action
- Meilleure DX (autocomplétion précise)

#### Decision 3: Variantes (jsonVariant/csvVariant) vs Paramètres séparés
**Choix:** Paramètres séparés `jsonVariant` et `csvVariant`

**Raisons:**
- Plus explicite et lisible
- Évite la confusion entre variantes de formats différents
- Permet des validations spécifiques par format

#### Decision 4: maxDepth dans l'API unifiée
**Choix:** OUI, maxDepth est inclus dans l'API unifiée

**Raisons:**
- Utile pour conversation → XML (existant)
- Peut être étendu à d'autres formats si nécessaire
- Paramètre optionnel, donc pas de surcharge

#### Decision 5: startIndex/endIndex pour XML
**Choix:** NON, startIndex/endIndex sont exclus pour XML

**Raisons:**
- XML est un format structuré, pas linéaire comme JSON/CSV
- Les plages de messages n'ont pas de sens pour XML
- Simplifie l'API et évite la confusion

### 5.3 Migration Path

1. **Phase 2 (Design)** - Ce document
2. **Phase 3 (Implementation)** - Créer les nouveaux outils
3. **Phase 4 (Tests)** - Écrire les tests TDD
4. **Phase 5 (Validation)** - Tests passent, validation checklist
5. **Phase 6 (Deprecation)** - Marquer les 6 anciens outils comme [DEPRECATED]
6. **Phase 7 (Cleanup)** - Supprimer les 6 anciens outils

### 5.4 Backward Compatibility

Les 6 anciens outils restent fonctionnels pendant la transition :
- Pas de breaking change immédiat
- Les utilisateurs peuvent migrer progressivement
- Documentation de migration fournie

---

## 6. Checklist de Validation

### Avant Implementation
- [x] Schema Zod complet défini
- [x] Tests unitaires identifiés
- [x] Design decisions documentées
- [ ] Review par Claude Code

### Pendant Implementation
- [ ] Créer `roosync-export.ts` avec schema Zod
- [ ] Créer `roosync-export-config.ts` avec schema Zod
- [ ] Écrire les tests TDD
- [ ] Tous les tests passent

### Après Implementation
- [ ] Validation checklist (voir `.roo/rules/validation.md`)
- [ ] Décompte outils : 6 → 2 (-4)
- [ ] Commit avec message conventionnel
- [ ] Message INTERCOM type DONE

---

## 7. Références

- **Issue #376:** https://github.com/jsboige/roo-extensions/issues/376
- **Validation Rules:** `.roo/rules/validation.md`
- **SDDD Protocol:** `docs/roosync/PROTOCOLE_SDDD.md`
- **Export Tools Actuels:** `mcps/internal/servers/roo-state-manager/src/tools/export/`

---

*Document créé le 2026-02-04 par Roo Code (Phase 2 - Design)*
