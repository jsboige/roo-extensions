# Architecture Unifiée d'Extraction de Tâches Roo + Claude

**Version:** 1.0.0
**Date:** 2026-04-15
**Issue Parente:** #1360
**Phases:** #1391, #1392, #1393, #1394, #1395
**Chemin:** `docs/architecture/unified-task-extraction-architecture.md` (note: issues référencent `docs/roosync/...` mais ce chemin est ignoré par git)

---

## Table des Matières

1. [Vue d'Ensemble](#vue-densemble)
2. [Problème à Résoudre](#problème-à-résoudre)
3. [Architecture Actuelle](#architecture-actuelle)
4. [Architecture Cible](#architecture-cible)
5. [Schéma UnifiedTask](#schéma-unifiedtask)
6. [Stratégie de Stockage GDrive](#stratégie-de-stockage-gdrive)
7. [Plan de Migration](#plan-de-migration)
8. [Contraintes et Risques](#contraintes-et-risques)
9. [Métriques de Succès](#métriques-de-succès)

---

## Vue d'Ensemble

Ce document décrit l'architecture pour unifier les systèmes d'extraction de tâches Roo et Claude Code actuellement duplicés. L'objectif est de créer **un seul système d'extraction** capable de lire les deux formats sources et de produire une représentation unifiée accessible à toutes les machines du cluster via GDrive.

### Motivation

Le système actuel contient **deux pipelines de reconstruction complets** :
- Pipeline Roo : squelettes reconstruits depuis `ui_messages.json` + `task_metadata.json`
- Pipeline Claude : archives reconstruites depuis `*.jsonl`

Cette duplication représente une **dette technique** : lorsque la demande "rendre le système cross-plateforme" est arrivée, l'implémentation a **dupliqué** le système d'extraction au lieu de **l'étendre**.

### Bénéfices Attendus

- **Elimination de duplication** : Un seul code d'extraction au lieu de deux
- **Accès cross-machine** : Toutes les machines peuvent accéder aux tâches de toutes les autres
- **Indexation centralisée** : Qdrant indexe une seule fois sur le coordinateur
- **Maintenance simplifiée** : Un seul format à maintenir lors d'évolutions

---

## Problème à Résoudre

### Ce que ce N'EST PAS

❌ Duplication de métadonnées entre squelettes Roo et tâches Claude natives
❌ Simple synchronisation de fichiers

### Ce que c'EST

✅ **Deux pipelines complets faisant le même travail de récupération** :
- Extraction du contenu complet (messages, outils, timestamps)
- Reconstruction de l'historique conversationnel
- Parsing et validation des données

✅ **Problème d'architecture** : duplication au lieu d'extension

---

## Architecture Actuelle

### Pipeline 1 : Extraction Roo

**Source :** `<VSCode storage>/tasks/<taskId>/`
- `ui_messages.json` (messages complets)
- `task_metadata.json` (metadata)

**Code :**
- `src/services/storage/RooStorageDetector.ts`
- `src/services/skeletons/ConversationSkeletonService.ts`

**Output :** `ConversationSkeleton` (format Roo-spécifique)

### Pipeline 2 : Extraction Claude

**Source :** `~/.claude/projects/<hash>/*.jsonl`

**Code :**
- `src/services/storage/ClaudeStorageDetector.ts`
- Parsing custom dans divers outils

**Output :** Structures ad-hoc (pas de format unifié)

### Problèmes

1. **Duplication de code** : 2 parsers, 2 systèmes de cache, 2 validateurs
2. **Incohérence** : Formats différents pour même information
3. **Maintenance** : Changement de format nécessite 2 updates
4. **Isolation** : Chaque machine ne voit que ses propres tâches

---

## Architecture Cible

### Composants

```
┌─────────────────────────────────────────────────────────────┐
│                   UnifiedTaskExtractor                       │
│  (Orchestrateur principal - détection format automatique)   │
└────────────────┬────────────────────────────────────────────┘
                 │
        ┌────────┴────────┐
        │                 │
┌───────▼──────┐  ┌──────▼────────┐
│ RooTask      │  │ ClaudeTask    │
│ Extractor    │  │ Extractor     │
└───────┬──────┘  └──────┬────────┘
        │                │
        │                │
        └────────┬───────┘
                 │
         ┌───────▼────────┐
         │  UnifiedTask   │
         │  (Schema JSON) │
         └───────┬────────┘
                 │
    ┌────────────┴────────────┐
    │                         │
┌───▼────────┐      ┌────────▼──────┐
│ Local      │      │ Shared        │
│ Cache      │      │ Storage       │
│ (Hot Tier) │      │ (GDrive)      │
└────────────┘      └───────────────┘
                    Hot/Warm/Cold
```

### Flux de Données

1. **Détection** : `UnifiedTaskExtractor` détecte le format source (Roo vs Claude)
2. **Extraction** : Délègue au `RooTaskExtractor` ou `ClaudeTaskExtractor`
3. **Normalisation** : Conversion vers `UnifiedTask` (schéma JSON)
4. **Stockage** :
   - Cache local (hot tier, < 100ms)
   - GDrive partagé (warm/cold tiers, < 1s)
5. **Consommation** : Tous les outils downstream utilisent `UnifiedTask`

---

## Schéma UnifiedTask

### Structure TypeScript

```typescript
interface UnifiedTask {
  // Identification
  id: string;                    // UUID unique
  source: 'roo' | 'claude';      // Format source
  version: string;               // Version du schéma (ex: "1.0.0")

  // Metadata
  metadata: {
    createdAt: string;           // ISO 8601
    lastActivity: string;        // ISO 8601
    workspace: string;           // Chemin absolu
    workspaceShort: string;      // Nom court
    machineId: string;           // ID de la machine
    mode?: string;               // Mode Roo (si applicable)
  };

  // Contenu conversationnel
  messages: UnifiedMessage[];

  // Hiérarchie
  parentTaskId?: string;
  childTaskIds: string[];

  // Statistiques
  stats: {
    messageCount: number;
    userMessageCount: number;
    assistantMessageCount: number;
    toolCallCount: number;
    totalSize: number;           // Bytes
  };

  // Extraction metadata
  extraction: {
    extractedAt: string;         // ISO 8601
    extractorVersion: string;
    sourceFormat: 'roo-ui-messages' | 'claude-jsonl';
    sourcePath: string;          // Chemin du fichier source
  };
}

interface UnifiedMessage {
  id: string;
  role: 'user' | 'assistant';
  timestamp: string;             // ISO 8601
  content: string;
  toolCalls?: UnifiedToolCall[];
}

interface UnifiedToolCall {
  id: string;
  name: string;
  parameters: Record<string, unknown>;
  result?: {
    success: boolean;
    output?: unknown;
    error?: string;
  };
  timestamp: string;
}
```

### JSON Schema

Le JSON Schema complet sera défini dans `schemas/unified-task.json` (Phase 1, #1391).

**Validation obligatoire :**
- Tous les champs requis présents
- Types corrects
- Timestamps valides (ISO 8601)
- Relations parent-enfant cohérentes

---

## Stratégie de Stockage GDrive

### Problème de Volumétrie

**Données actuelles :**
- ~8000 tâches Roo × ~100 MB/tâche = ~800 GB
- Outliers : jusqu'à 270 MB par tâche
- ~30 sessions Claude × 60K messages = plusieurs GB

**Contraintes GDrive :**
- Espace limité
- Latence élevée (rclone mount)
- Quota API

### Solution : Tiered Storage (Hot/Warm/Cold)

#### Tier HOT (Local Cache)

**Emplacement :** Local disk (ex: `~/.cache/unified-tasks/`)
**Contenu :** Tâches récentes (< 7 jours) + fréquemment accédées
**Performance :** < 100ms
**TTL :** 7 jours ou LRU eviction

**Critères d'entrée :**
- Tâche créée < 7 jours
- Accédée dans les dernières 24h
- Taille < 10 MB

#### Tier WARM (GDrive Active)

**Emplacement :** `$ROOSYNC_SHARED_PATH/.shared-tasks/warm/`
**Contenu :** Tâches moyennement récentes (7-90 jours)
**Performance :** < 1s
**Format :** JSON compressé (gzip)

**Structure :**
```
.shared-tasks/warm/
  ├── 2026-04/                   # Par mois
  │   ├── myia-ai-01/            # Par machine
  │   │   ├── <taskId>.json.gz
  │   │   └── ...
  │   ├── myia-po-2023/
  │   └── ...
  └── index.json.gz              # Index global
```

#### Tier COLD (GDrive Archive)

**Emplacement :** `$ROOSYNC_SHARED_PATH/.shared-tasks/cold/`
**Contenu :** Tâches anciennes (> 90 jours) ou volumineuses
**Performance :** 1-5s
**Format :** Tar.gz par période

**Structure :**
```
.shared-tasks/cold/
  ├── 2025-Q4.tar.gz             # Par trimestre
  ├── 2026-Q1.tar.gz
  └── index.json.gz
```

### Verrouillage Cross-Machine

**Problème :** Plusieurs machines peuvent écrire simultanément la même tâche.

**Solution :** Lock files atomiques

```typescript
// Exemple de lock
interface TaskLock {
  taskId: string;
  machineId: string;
  acquiredAt: string;
  expiresAt: string;             // TTL : 5 minutes
  operation: 'read' | 'write';
}

// Chemin du lock
$ROOSYNC_SHARED_PATH/.shared-tasks/locks/<taskId>.lock
```

**Protocole :**
1. Tenter création atomique du fichier lock (O_EXCL)
2. Si succès : procéder
3. Si échec : vérifier expiration, retry avec backoff
4. Cleanup du lock après opération

**Timeout :** 5 minutes (après quoi le lock est considéré stale)

---

## Plan de Migration

### Phase 1 : Foundation (#1391)

**Durée :** 1-2 semaines

**Livrables :**
- [ ] `src/types/unified-task.ts` - Types TypeScript complets
- [ ] `schemas/unified-task.json` - JSON Schema
- [ ] Tests unitaires de validation
- [ ] Documentation JSDoc

**Critères d'acceptation :**
- JSON schema valide tous les exemples Roo + Claude existants
- Tests passent à 100%
- Code review approuvé

### Phase 2 : Extracteurs (#1392)

**Durée :** 2-3 semaines

**Livrables :**
- [ ] `src/services/extraction/UnifiedTaskExtractor.ts`
- [ ] `src/services/extraction/RooTaskExtractor.ts`
- [ ] `src/services/extraction/ClaudeTaskExtractor.ts`
- [ ] Tests d'intégration

**Critères d'acceptation :**
- Support des deux formats (Roo + Claude)
- Performance ≥ système actuel
- Détection automatique du format
- Tests passent à 100%

### Phase 3 : Stockage Partagé (#1393)

**Durée :** 2-3 semaines

**Livrables :**
- [ ] `src/services/shared-storage/SharedTaskStorage.ts`
- [ ] `src/services/shared-storage/SharedStorageLock.ts`
- [ ] `src/services/shared-storage/LocalCache.ts`
- [ ] `scripts/migrate-to-shared-storage.ps1`

**Critères d'acceptation :**
- Structure hot/warm/cold fonctionnelle
- Verrouillage cross-machine testé (6 machines en parallèle)
- Performance : < 100ms hot, < 1s warm
- Migration réussie des tâches existantes

### Phase 4 : Migration Downstream (#1394)

**Durée :** 3-4 semaines

**Livrables :**
- [ ] Migration `conversation_browser`
- [ ] Migration `codebase_search` (indexation)
- [ ] Migration `view_task_details`
- [ ] Migration meta-analystes
- [ ] Tests de régression

**Critères d'acceptation :**
- Tous les outils downstream utilisent `UnifiedTask`
- Aucune régression de fonctionnalité
- Performance maintenue ou améliorée

### Phase 5 : Déprécation (#1395)

**Durée :** 1-2 semaines

**Livrables :**
- [ ] Marquer `ConversationSkeleton` deprecated
- [ ] Supprimer code mort (après 30 jours de grace)
- [ ] Mise à jour documentation
- [ ] Post-mortem et retour d'expérience

**Critères d'acceptation :**
- Aucun code actif n'utilise l'ancien système
- Documentation à jour
- Retour d'expérience documenté

### Timeline Globale

**Estimation totale :** 9-14 semaines

**Parallélisation possible :**
- Phase 4 peut commencer dès que Phase 3 a un prototype stable
- Différentes machines peuvent travailler sur différents outils downstream

---

## Contraintes et Risques

### Contraintes Techniques

| Contrainte | Impact | Mitigation |
|------------|--------|------------|
| **Volumétrie GDrive** | Limite ~15 GB quota free | Tiered storage + compression + archival |
| **Latence rclone** | 500ms-2s pour accès GDrive | Cache local (hot tier) |
| **Conflits cross-machine** | Corruption de données | Lock files atomiques + retry logic |
| **Formats évolutifs** | Breaking changes | Versioning du schéma + migration scripts |

### Risques

| Risque | Probabilité | Sévérité | Mitigation |
|--------|-------------|----------|------------|
| **Régression de performance** | Moyenne | Haute | Benchmarks avant/après, cache local |
| **Perte de données pendant migration** | Faible | Critique | Backup complet avant, migration incrémentale |
| **Incompatibilité format** | Moyenne | Moyenne | Tests exhaustifs, validation JSON schema |
| **Quota GDrive dépassé** | Haute | Moyenne | Monitoring, archival automatique |

### Dépendances Externes

- **rclone** : Mount GDrive stable et performant
- **GDrive API** : Disponibilité et quotas
- **Format Roo** : Stabilité de `ui_messages.json`
- **Format Claude** : Stabilité de `*.jsonl`

---

## Métriques de Succès

### Performance

| Métrique | Avant | Cible | Mesure |
|----------|-------|-------|--------|
| **Extraction Roo** | ~200ms | ≤ 200ms | Benchmark 1000 tâches |
| **Extraction Claude** | ~300ms | ≤ 300ms | Benchmark 30 sessions |
| **Cache hit (hot)** | N/A | < 100ms | p95 latency |
| **GDrive access (warm)** | N/A | < 1s | p95 latency |

### Qualité

- **Couverture tests** : > 90%
- **Régression bugs** : 0 bugs critiques post-migration
- **Validation schema** : 100% des tâches existantes valident

### Volumétrie

- **Tâches migrées** : 100% (8000 Roo + 30 Claude)
- **Espace GDrive utilisé** : < 5 GB (compression)
- **Cache local** : < 500 MB par machine

### Adoption

- **Outils downstream migrés** : 100% (conversation_browser, codebase_search, etc.)
- **Ancien code supprimé** : 100% après 30 jours de grace
- **Documentation à jour** : 100%

---

## Références

### Issues

- **Parente :** #1360 - Unifier systèmes d'extraction
- **Phase 1 :** #1391 - Design schéma unifié
- **Phase 2 :** #1392 - Extracteur cross-format
- **Phase 3 :** #1393 - Stockage partagé GDrive
- **Phase 4 :** #1394 - Migration downstream
- **Phase 5 :** #1395 - Déprécation ancien système

### Documents

- `CLAUDE.md` - Guide projet
- `docs/roosync/GUIDE-TECHNIQUE-v2.3.md` - Guide RooSync
- `docs/knowledge/WORKSPACE_KNOWLEDGE.md` - Base de connaissance

### Code Existant

- `src/services/storage/RooStorageDetector.ts` - À refactorer
- `src/services/storage/ClaudeStorageDetector.ts` - À refactorer
- `src/services/skeletons/ConversationSkeletonService.ts` - À déprécier

---

**Auteurs :** Claude Sonnet 4.5
**Dernière MAJ :** 2026-04-15
**Statut :** Draft v1.0.0 - En attente de review
