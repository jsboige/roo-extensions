# CONS-10 Phase 4.2 : Guide de Migration

**Issue:** #376 - Consolidation Export
**Date:** 2026-02-06
**Auteur:** Roo Code (Phase 4.2 - Guide de Migration)

---

## 1. Vue d'ensemble

### Objectif

Ce guide facilite la migration des 6 anciens outils d'export vers les 2 nouveaux outils unifiés.

### Résumé de la Consolidation

| Aspect | Avant (6 outils) | Après (2 outils) |
|--------|------------------|------------------|
| **Outils** | 6 outils séparés | 2 outils unifiés |
| **API** | 6 endpoints distincts | 2 endpoints action-based |
| **Formats** | XML, JSON, CSV séparés | Formats paramétrables |
| **Configuration** | `configure_xml_export` | `roosync_export_config` |

---

## 2. Mapping Ancien → Nouveau

### Tableau de Correspondance

| Ancien Outil | Nouvel Outil | Action | Format | Paramètres Clés |
|--------------|--------------|--------|--------|-----------------|
| `export_tasks_xml` | `roosync_export` | `task` | `xml` | `taskId`, `includeContent` |
| `export_conversation_xml` | `roosync_export` | `conversation` | `xml` | `conversationId`, `maxDepth`, `includeContent` |
| `export_project_xml` | `roosync_export` | `project` | `xml` | `projectPath`, `startDate`, `endDate` |
| `export_conversation_json` | `roosync_export` | `conversation` | `json` | `conversationId`, `jsonVariant` |
| `export_conversation_csv` | `roosync_export` | `conversation` | `csv` | `conversationId`, `csvVariant` |
| `configure_xml_export` | `roosync_export_config` | `get`/`set`/`reset` | - | `config` |

### Mapping Détaillé par Ancien Outil

#### 2.1 `export_tasks_xml` → `roosync_export`

**Ancien appel :**
```typescript
{
  taskId: "task-123",
  includeContent: true,
  prettyPrint: true
}
```

**Nouvel appel :**
```typescript
{
  action: "task",
  format: "xml",
  taskId: "task-123",
  includeContent: true,
  prettyPrint: true
}
```

**Changements :**
- Ajout de `action: "task"`
- Ajout de `format: "xml"`

---

#### 2.2 `export_conversation_xml` → `roosync_export`

**Ancien appel :**
```typescript
{
  conversationId: "conv-456",
  maxDepth: 5,
  includeContent: false,
  prettyPrint: true
}
```

**Nouvel appel :**
```typescript
{
  action: "conversation",
  format: "xml",
  conversationId: "conv-456",
  maxDepth: 5,
  includeContent: false,
  prettyPrint: true
}
```

**Changements :**
- Ajout de `action: "conversation"`
- Ajout de `format: "xml"`

---

#### 2.3 `export_project_xml` → `roosync_export`

**Ancien appel :**
```typescript
{
  projectPath: "/path/to/project",
  startDate: "2026-01-01T00:00:00Z",
  endDate: "2026-01-31T23:59:59Z",
  prettyPrint: true
}
```

**Nouvel appel :**
```typescript
{
  action: "project",
  format: "xml",
  projectPath: "/path/to/project",
  startDate: "2026-01-01T00:00:00Z",
  endDate: "2026-01-31T23:59:59Z",
  prettyPrint: true
}
```

**Changements :**
- Ajout de `action: "project"`
- Ajout de `format: "xml"` (obligatoire, seul format supporté)

---

#### 2.4 `export_conversation_json` → `roosync_export`

**Ancien appel (light) :**
```typescript
{
  conversationId: "conv-456",
  variant: "light",
  truncationChars: 10000
}
```

**Nouvel appel (light) :**
```typescript
{
  action: "conversation",
  format: "json",
  conversationId: "conv-456",
  jsonVariant: "light",
  truncationChars: 10000
}
```

**Ancien appel (full) :**
```typescript
{
  conversationId: "conv-456",
  variant: "full"
}
```

**Nouvel appel (full) :**
```typescript
{
  action: "conversation",
  format: "json",
  conversationId: "conv-456",
  jsonVariant: "full"
}
```

**Changements :**
- Ajout de `action: "conversation"`
- Ajout de `format: "json"`
- `variant` → `jsonVariant`

---

#### 2.5 `export_conversation_csv` → `roosync_export`

**Ancien appel (conversations) :**
```typescript
{
  conversationId: "conv-456",
  variant: "conversations"
}
```

**Nouvel appel (conversations) :**
```typescript
{
  action: "conversation",
  format: "csv",
  conversationId: "conv-456",
  csvVariant: "conversations"
}
```

**Ancien appel (messages) :**
```typescript
{
  conversationId: "conv-456",
  variant: "messages",
  startIndex: 1,
  endIndex: 50
}
```

**Nouvel appel (messages) :**
```typescript
{
  action: "conversation",
  format: "csv",
  conversationId: "conv-456",
  csvVariant: "messages",
  startIndex: 1,
  endIndex: 50
}
```

**Ancien appel (tools) :**
```typescript
{
  conversationId: "conv-456",
  variant: "tools"
}
```

**Nouvel appel (tools) :**
```typescript
{
  action: "conversation",
  format: "csv",
  conversationId: "conv-456",
  csvVariant: "tools"
}
```

**Changements :**
- Ajout de `action: "conversation"`
- Ajout de `format: "csv"`
- `variant` → `csvVariant`

---

#### 2.6 `configure_xml_export` → `roosync_export_config`

**Ancien appel (get) :**
```typescript
{
  action: "get"
}
```

**Nouvel appel (get) :**
```typescript
{
  action: "get"
}
```

**Ancien appel (set) :**
```typescript
{
  action: "set",
  config: {
    prettyPrint: false,
    includeContent: true,
    truncationChars: 5000
  }
}
```

**Nouvel appel (set) :**
```typescript
{
  action: "set",
  config: {
    prettyPrint: false,
    includeContent: true,
    truncationChars: 5000
  }
}
```

**Ancien appel (reset) :**
```typescript
{
  action: "reset"
}
```

**Nouvel appel (reset) :**
```typescript
{
  action: "reset"
}
```

**Changements :**
- Aucun changement significatif
- L'API reste identique pour la configuration

---

## 3. Breaking Changes

### 3.1 Changements Obligatoires

| Changement | Impact | Migration |
|------------|--------|-----------|
| **Ajout de `action`** | Tous les appels d'export | Ajouter `action: "task"|"conversation"|"project"` |
| **Ajout de `format`** | Tous les appels d'export | Ajouter `format: "xml"|"json"|"csv"` |
| **`variant` → `jsonVariant`** | Exports JSON | Renommer le paramètre |
| **`variant` → `csvVariant`** | Exports CSV | Renommer le paramètre |

### 3.2 Nouvelles Restrictions

| Restriction | Description | Exemple |
|------------|-------------|---------|
| **Project → XML uniquement** | L'action `project` ne supporte que le format XML | `format: "json"` sera rejeté |
| **startIndex/endIndex exclus pour XML** | Les plages de messages ne s'appliquent qu'à JSON/CSV | `startIndex` ignoré pour XML |

### 3.3 Paramètres Supprimés

| Ancien Paramètre | Nouveau Paramètre | Notes |
|------------------|-------------------|-------|
| N/A | N/A | Aucun paramètre supprimé, tous sont conservés |

---

## 4. Backward Compatibility

### 4.1 Période de Transition

Les 6 anciens outils restent **fonctionnels** pendant la période de transition :
- Pas de breaking change immédiat
- Les utilisateurs peuvent migrer progressivement
- Documentation de migration fournie (ce document)

### 4.2 Support des Anciens Outils

| Outil | Statut | Date de Dépréciation | Date de Suppression |
|-------|---------|----------------------|---------------------|
| `export_tasks_xml` | Fonctionnel | 2026-02-06 | TBD |
| `export_conversation_xml` | Fonctionnel | 2026-02-06 | TBD |
| `export_project_xml` | Fonctionnel | 2026-02-06 | TBD |
| `export_conversation_json` | Fonctionnel | 2026-02-06 | TBD |
| `export_conversation_csv` | Fonctionnel | 2026-02-06 | TBD |
| `configure_xml_export` | Fonctionnel | 2026-02-06 | TBD |

### 4.3 Recommandations

1. **Immédiat :** Commencer à utiliser les nouveaux outils pour les nouveaux développements
2. **Court terme (1-2 semaines) :** Migrer les scripts critiques
3. **Moyen terme (1 mois) :** Migrer tous les scripts existants
4. **Long terme :** Supprimer les anciens outils après validation complète

---

## 5. Checklist de Migration

### 5.1 Préparation

- [ ] Lire ce guide de migration en entier
- [ ] Identifier tous les scripts utilisant les anciens outils
- [ ] Créer une branche de migration
- [ ] Sauvegarder les configurations existantes

### 5.2 Migration par Script

Pour chaque script utilisant les anciens outils :

- [ ] Identifier l'ancien outil utilisé
- [ ] Consulter le mapping correspondant (section 2)
- [ ] Mettre à jour l'appel avec les nouveaux paramètres
- [ ] Tester le nouvel appel
- [ ] Vérifier que le résultat est identique
- [ ] Committer les changements

### 5.3 Validation

- [ ] Tous les tests passent
- [ ] Les exports produisent les mêmes résultats
- [ ] Aucune régression détectée
- [ ] Documentation mise à jour

### 5.4 Nettoyage

- [ ] Supprimer les références aux anciens outils
- [ ] Mettre à jour la documentation interne
- [ ] Former l'équipe aux nouveaux outils
- [ ] Marquer les anciens outils comme [DEPRECATED]

---

## 6. Exemples Concrets de Migration

### Exemple 1 : Export de Tâche en XML

**Scénario :** Un script exporte une tâche individuelle en XML pour archivage.

**Ancien code :**
```typescript
// Ancien outil : export_tasks_xml
const result = await mcp__roo_state_manager__export_tasks_xml({
  taskId: "task-abc-123",
  includeContent: true,
  prettyPrint: true
});
```

**Nouveau code :**
```typescript
// Nouvel outil : roosync_export
const result = await mcp__roo_state_manager__roosync_export({
  action: "task",
  format: "xml",
  taskId: "task-abc-123",
  includeContent: true,
  prettyPrint: true
});
```

**Différences :**
- Ajout de `action: "task"`
- Ajout de `format: "xml"`

---

### Exemple 2 : Export de Conversation en JSON Full

**Scénario :** Un script exporte une conversation complète en JSON pour analyse.

**Ancien code :**
```typescript
// Ancien outil : export_conversation_json
const result = await mcp__roo_state_manager__export_conversation_json({
  conversationId: "conv-xyz-456",
  variant: "full",
  truncationChars: 0
});
```

**Nouveau code :**
```typescript
// Nouvel outil : roosync_export
const result = await mcp__roo_state_manager__roosync_export({
  action: "conversation",
  format: "json",
  conversationId: "conv-xyz-456",
  jsonVariant: "full",
  truncationChars: 0
});
```

**Différences :**
- Ajout de `action: "conversation"`
- Ajout de `format: "json"`
- `variant` → `jsonVariant`

---

### Exemple 3 : Export de Conversation en CSV (Messages)

**Scénario :** Un script exporte les messages d'une conversation en CSV pour analyse de données.

**Ancien code :**
```typescript
// Ancien outil : export_conversation_csv
const result = await mcp__roo_state_manager__export_conversation_csv({
  conversationId: "conv-def-789",
  variant: "messages",
  startIndex: 1,
  endIndex: 100
});
```

**Nouveau code :**
```typescript
// Nouvel outil : roosync_export
const result = await mcp__roo_state_manager__roosync_export({
  action: "conversation",
  format: "csv",
  conversationId: "conv-def-789",
  csvVariant: "messages",
  startIndex: 1,
  endIndex: 100
});
```

**Différences :**
- Ajout de `action: "conversation"`
- Ajout de `format: "csv"`
- `variant` → `csvVariant`

---

### Exemple 4 : Export de Projet Complet en XML

**Scénario :** Un script exporte un projet complet avec filtre de dates pour reporting mensuel.

**Ancien code :**
```typescript
// Ancien outil : export_project_xml
const result = await mcp__roo_state_manager__export_project_xml({
  projectPath: "/projects/myia-ai-01",
  startDate: "2026-01-01T00:00:00Z",
  endDate: "2026-01-31T23:59:59Z",
  prettyPrint: true
});
```

**Nouveau code :**
```typescript
// Nouvel outil : roosync_export
const result = await mcp__roo_state_manager__roosync_export({
  action: "project",
  format: "xml",
  projectPath: "/projects/myia-ai-01",
  startDate: "2026-01-01T00:00:00Z",
  endDate: "2026-01-31T23:59:59Z",
  prettyPrint: true
});
```

**Différences :**
- Ajout de `action: "project"`
- Ajout de `format: "xml"` (obligatoire)

---

### Exemple 5 : Configuration d'Export

**Scénario :** Un script configure les paramètres par défaut pour les exports.

**Ancien code :**
```typescript
// Ancien outil : configure_xml_export
const result = await mcp__roo_state_manager__configure_xml_export({
  action: "set",
  config: {
    prettyPrint: false,
    includeContent: true,
    truncationChars: 5000
  }
});
```

**Nouveau code :**
```typescript
// Nouvel outil : roosync_export_config
const result = await mcp__roo_state_manager__roosync_export_config({
  action: "set",
  config: {
    prettyPrint: false,
    includeContent: true,
    truncationChars: 5000
  }
});
```

**Différences :**
- Aucune différence significative
- L'API reste identique

---

### Exemple 6 : Export de Conversation en XML avec Profondeur

**Scénario :** Un script exporte une conversation en XML avec une profondeur limitée pour éviter les exports trop volumineux.

**Ancien code :**
```typescript
// Ancien outil : export_conversation_xml
const result = await mcp__roo_state_manager__export_conversation_xml({
  conversationId: "conv-ghi-012",
  maxDepth: 3,
  includeContent: false,
  prettyPrint: true
});
```

**Nouveau code :**
```typescript
// Nouvel outil : roosync_export
const result = await mcp__roo_state_manager__roosync_export({
  action: "conversation",
  format: "xml",
  conversationId: "conv-ghi-012",
  maxDepth: 3,
  includeContent: false,
  prettyPrint: true
});
```

**Différences :**
- Ajout de `action: "conversation"`
- Ajout de `format: "xml"`

---

### Exemple 7 : Export de Conversation en JSON Light avec Plage

**Scénario :** Un script exporte une plage de messages en JSON light pour analyse rapide.

**Ancien code :**
```typescript
// Ancien outil : export_conversation_json
const result = await mcp__roo_state_manager__export_conversation_json({
  conversationId: "conv-jkl-345",
  variant: "light",
  startIndex: 10,
  endIndex: 50,
  truncationChars: 1000
});
```

**Nouveau code :**
```typescript
// Nouvel outil : roosync_export
const result = await mcp__roo_state_manager__roosync_export({
  action: "conversation",
  format: "json",
  conversationId: "conv-jkl-345",
  jsonVariant: "light",
  startIndex: 10,
  endIndex: 50,
  truncationChars: 1000
});
```

**Différences :**
- Ajout de `action: "conversation"`
- Ajout de `format: "json"`
- `variant` → `jsonVariant`

---

## 7. Référence Rapide

### 7.1 Nouveaux Outils

| Outil | Description |
|-------|-------------|
| `roosync_export` | Export unifié (task/conversation/project, xml/json/csv) |
| `roosync_export_config` | Configuration des exports (get/set/reset) |

### 7.2 Actions Disponibles

| Action | Formats Supportés | Paramètre Requis |
|--------|-------------------|------------------|
| `task` | xml, json | `taskId` |
| `conversation` | xml, json, csv | `conversationId` |
| `project` | xml | `projectPath` |

### 7.3 Formats Disponibles

| Format | Actions Supportées | Variantes |
|--------|-------------------|-----------|
| `xml` | task, conversation, project | - |
| `json` | task, conversation | light, full |
| `csv` | conversation | conversations, messages, tools |

### 7.4 Actions de Configuration

| Action | Description |
|--------|-------------|
| `get` | Récupérer la configuration actuelle |
| `set` | Mettre à jour la configuration |
| `reset` | Remettre aux valeurs par défaut |

---

## 8. Support et Ressources

### 8.1 Documentation

- **Design Document :** `docs/roosync/CONS-10-design.md`
- **SDDD Protocol :** `docs/roosync/PROTOCOLE_SDDD.md`
- **Validation Rules :** `.roo/rules/validation.md`

### 8.2 Issues GitHub

- **Issue #376 :** https://github.com/jsboige/roo-extensions/issues/376

### 8.3 Contact

Pour toute question ou problème lors de la migration :
1. Consulter ce guide
2. Vérifier les exemples concrets (section 6)
3. Contacter l'équipe via INTERCOM

---

## 9. Annexe : Schéma de Migration

```
┌─────────────────────────────────────────────────────────────┐
│                    Anciens Outils (6)                        │
├─────────────────────────────────────────────────────────────┤
│  export_tasks_xml         →  roosync_export (task, xml)      │
│  export_conversation_xml  →  roosync_export (conv, xml)      │
│  export_project_xml       →  roosync_export (proj, xml)     │
│  export_conversation_json →  roosync_export (conv, json)    │
│  export_conversation_csv  →  roosync_export (conv, csv)     │
│  configure_xml_export     →  roosync_export_config          │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    Nouveaux Outils (2)                       │
├─────────────────────────────────────────────────────────────┤
│  roosync_export           →  Export unifié                  │
│  roosync_export_config    →  Configuration                 │
└─────────────────────────────────────────────────────────────┘
```

---

*Document créé le 2026-02-06 par Roo Code (Phase 4.2 - Guide de Migration)*
