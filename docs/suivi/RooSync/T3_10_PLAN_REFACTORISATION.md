# T3.10 - Plan de Refactorisation : Élimination de la Duplication

**Date :** 2026-01-15
**Auteur :** Claude Code (myia-ai-01)
**Statut :** Plan préparé - En attente d'implémentation
**Basé sur :** T3.9 - Analyse et Recommandation : Modèle de Baseline Unique

---

## 1. Résumé Exécutif

Ce document détaille le plan de refactorisation pour éliminer la duplication entre les services de baseline nominative (v2.1) et non-nominative (v3.0), conformément à la recommandation de T3.9.

**Décision T3.9 :** Adopter le modèle **Non-Nominatif v3.0** comme baseline unique (score 4-2).

---

## 2. Architecture Actuelle

### 2.1 Services en Parallèle

| Service | Version | Fichier | Lignes | Statut |
|---------|---------|---------|--------|--------|
| BaselineService | v2.1 | `src/services/BaselineService.ts` | 769 | Legacy |
| NonNominativeBaselineService | v3.0 | `src/services/roosync/NonNominativeBaselineService.ts` | 949 | Cible |

### 2.2 Duplications Identifiées

#### 2.2.1 Double Instanciation dans RooSyncService

```typescript
// RooSyncService.ts - Lignes 84, 90
private baselineService: BaselineService;
private nonNominativeBaselineService: NonNominativeBaselineService;
```

**Impact :** Les deux services sont instanciés et maintenus en parallèle, créant une double source de vérité.

#### 2.2.2 Duplications de Types

| Interface | Occurrences | Fichiers |
|-----------|-------------|----------|
| MachineInventory | 3 | baseline.ts, non-nominative-baseline.ts, non-nominative-baseline-v3.ts |
| ConfigurationProfile | 2 | non-nominative-baseline.ts, non-nominative-baseline-v3.ts |

#### 2.2.3 Stubs d'Agrégation

```typescript
// NonNominativeBaselineService.ts - Lignes 302-313
private aggregateByMajority(data: any[]): any {
  return data[0]; // Stub!
}

private aggregateByWeightedAverage(data: any[]): any {
  return data[0]; // Stub!
}
```

#### 2.2.4 Migration Incomplète

`migrateFromLegacy()` n'extrait que 2 catégories sur 11 (roo-core, hardware-cpu).

---

## 3. Architecture Cible

### 3.1 Service Unique

```
┌─────────────────────────────────────────────────────────────┐
│                    RooSyncService                          │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  BaselineManager (Orchestrateur)                    │  │
│  │                                                      │  │
│  │  ┌──────────────────────────────────────────────┐   │  │
│  │  │  NonNominativeBaselineService (v3.0)       │   │  │
│  │  │  - createBaseline()                         │   │  │
│  │  │  - aggregateBaseline()                       │   │  │
│  │  │  - mapMachineToBaseline()                   │   │  │
│  │  │  - compareMachines()                        │   │  │
│  │  │  - migrateFromLegacy()                      │   │  │
│  │  └──────────────────────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  BaselineService (v2.1) - @deprecated (backward compat)     │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Types Unifiés

```
types/
├── baseline-unified.ts          [NOUVEAU] Types canoniques
├── baseline.ts                 [DEPRECATED] Legacy types
├── non-nominative-baseline.ts   [DEPRECATED] Anciens types
└── non-nominative-baseline-v3.ts [RÉFÉRENCE] Types v3.0
```

---

## 4. Plan de Refactorisation

### Phase 1 : Consolidation des Types (T3.10a)

**Objectif :** Créer une source unique de vérité pour les types.

#### 1.1 Créer `types/baseline-unified.ts`

```typescript
/**
 * Types unifiés pour le système de baseline v3.0
 * Source unique de vérité pour tous les services de baseline
 */

export interface UnifiedBaseline {
  baselineId: string;
  version: string;
  name: string;
  description: string;
  profiles: ConfigurationProfile[];
  aggregationRules: AggregationRules;
  metadata: BaselineMetadata;
}

export interface ConfigurationProfile {
  profileId: string;
  category: ConfigurationCategory;
  name: string;
  description: string;
  configuration: any;
  priority: number;
  compatibility: ProfileCompatibility;
  metadata: ProfileMetadata;
}

export type ConfigurationCategory =
  | 'roo-core'
  | 'roo-advanced'
  | 'hardware-cpu'
  | 'hardware-memory'
  | 'hardware-storage'
  | 'hardware-gpu'
  | 'software-powershell'
  | 'software-node'
  | 'software-python'
  | 'system-os'
  | 'system-architecture';

export interface AggregationRules {
  defaultPriority: number;
  conflictResolution: 'highest_priority' | 'most_recent' | 'manual';
  autoMergeCategories: ConfigurationCategory[];
}

export interface BaselineMetadata {
  createdAt: string;
  updatedAt: string;
  createdBy: string;
  lastModifiedBy: string;
  tags: string[];
  status: 'draft' | 'active' | 'deprecated' | 'archived';
}

export interface ProfileMetadata {
  createdAt: string;
  updatedAt: string;
  version: string;
  tags: string[];
  stability: 'stable' | 'experimental' | 'deprecated';
}

export interface ProfileCompatibility {
  requiredProfiles: string[];
  conflictingProfiles: string[];
  optionalProfiles: string[];
}

export interface MachineInventory {
  machineId: string;
  timestamp: string;
  config: {
    roo: {
      modes: any[];
      mcpSettings: Record<string, any>;
      userSettings: Record<string, any>;
    };
    hardware: {
      cpu: any;
      memory: any;
      disks: any[];
      gpu?: any;
    };
    software: {
      powershell: string;
      node: string;
      python: string;
    };
    system: {
      os: string;
      architecture: string;
    };
  };
  metadata: {
    collectionDuration: number;
    source: string;
    collectorVersion: string;
  };
}

export interface MachineConfigurationMapping {
  mappingId: string;
  machineHash: string;
  baselineId: string;
  appliedProfiles: Array<{
    profileId: string;
    category: ConfigurationCategory;
    appliedAt: string;
    source: 'auto' | 'manual' | 'inherited';
  }>;
  deviations: Array<{
    category: ConfigurationCategory;
    expectedValue: any;
    actualValue: any;
    severity: 'CRITICAL' | 'IMPORTANT' | 'WARNING' | 'INFO';
    detectedAt: string;
  }>;
  metadata: {
    firstSeen: string;
    lastSeen: string;
    lastUpdated: string;
    confidence: number;
  };
}

export interface NonNominativeBaselineState {
  activeBaseline?: UnifiedBaseline;
  machineMappings: MachineConfigurationMapping[];
  statistics: {
    totalBaselines: number;
    totalProfiles: number;
    totalMachines: number;
    averageCompliance: number;
    lastUpdated: string;
  };
  lastComparison?: any;
}
```

#### 1.2 Marquer les anciens types comme deprecated

```typescript
// baseline.ts
/**
 * @deprecated Use types/baseline-unified.ts instead
 * This file is kept for backward compatibility only
 */
export interface BaselineConfig { ... }

// non-nominative-baseline.ts
/**
 * @deprecated Use types/baseline-unified.ts instead
 * This file is kept for backward compatibility only
 */
export interface NonNominativeBaseline { ... }
```

#### 1.3 Mettre à jour les imports

Fichiers à modifier :
- `src/services/roosync/NonNominativeBaselineService.ts`
- `src/services/roosync/BaselineManager.ts`
- `src/tools/roosync/*.ts`

---

### Phase 2 : Compléter les Stubs (T3.10b)

**Objectif :** Implémenter les fonctions d'agrégation manquantes.

#### 2.1 Implémenter `aggregateByMajority()`

```typescript
/**
 * Agrège par majorité (valeur la plus fréquente)
 */
private aggregateByMajority(data: any[]): any {
  if (data.length === 0) return null;

  // Pour les objets, on agrège par propriété
  if (typeof data[0] === 'object' && data[0] !== null) {
    const result: any = {};
    const keys = Object.keys(data[0]);

    for (const key of keys) {
      const values = data.map(item => item[key]);
      result[key] = this.getMostFrequentValue(values);
    }

    return result;
  }

  // Pour les valeurs primitives, retourner la plus fréquente
  return this.getMostFrequentValue(data);
}

/**
 * Retourne la valeur la plus fréquente dans un tableau
 */
private getMostFrequentValue(values: any[]): any {
  const frequency: Map<any, number> = new Map();

  for (const value of values) {
    const key = JSON.stringify(value);
    frequency.set(key, (frequency.get(key) || 0) + 1);
  }

  let maxFrequency = 0;
  let mostFrequent: any = null;

  for (const [key, freq] of frequency.entries()) {
    if (freq > maxFrequency) {
      maxFrequency = freq;
      mostFrequent = JSON.parse(key);
    }
  }

  return mostFrequent;
}
```

#### 2.2 Implémenter `aggregateByWeightedAverage()`

```typescript
/**
 * Agrège par moyenne pondérée
 */
private aggregateByWeightedAverage(data: any[]): any {
  if (data.length === 0) return null;

  // Pour les nombres, calculer la moyenne
  if (typeof data[0] === 'number') {
    const sum = data.reduce((acc, val) => acc + val, 0);
    return sum / data.length;
  }

  // Pour les objets avec des propriétés numériques
  if (typeof data[0] === 'object' && data[0] !== null) {
    const result: any = {};
    const keys = Object.keys(data[0]);

    for (const key of keys) {
      const values = data.map(item => item[key]);

      if (typeof values[0] === 'number') {
        result[key] = values.reduce((acc: number, val: number) => acc + val, 0) / values.length;
      } else {
        // Pour les non-numériques, utiliser la majorité
        result[key] = this.getMostFrequentValue(values);
      }
    }

    return result;
  }

  // Fallback : retourner la première valeur
  return data[0];
}
```

#### 2.3 Compléter `extractProfilesFromLegacy()`

```typescript
/**
 * Extrait les profils depuis une baseline legacy
 */
private async extractProfilesFromLegacy(
  legacyBaseline: BaselineConfig | BaselineFileConfig,
  options: MigrationOptions
): Promise<ConfigurationProfile[]> {
  const profiles: ConfigurationProfile[] = [];

  if ('config' in legacyBaseline) {
    const config = legacyBaseline as BaselineConfig;

    // Profil Roo Core
    profiles.push({
      profileId: `profile-roo-core-${Date.now()}`,
      category: 'roo-core',
      name: 'Profil Roo Core (migré)',
      description: 'Profil Roo de base migré depuis l\'ancien système',
      configuration: {
        modes: config.config.roo.modes,
        mcpSettings: config.config.roo.mcpSettings
      },
      priority: 100,
      compatibility: {
        requiredProfiles: [],
        conflictingProfiles: [],
        optionalProfiles: []
      },
      metadata: {
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        version: '1.0.0',
        tags: ['migrated', 'legacy'],
        stability: 'stable'
      }
    });

    // Profil Roo Advanced
    profiles.push({
      profileId: `profile-roo-advanced-${Date.now()}`,
      category: 'roo-advanced',
      name: 'Profil Roo Advanced (migré)',
      description: 'Profil Roo avancé migré depuis l\'ancien système',
      configuration: {
        userSettings: config.config.roo.userSettings
      },
      priority: 100,
      compatibility: {
        requiredProfiles: [],
        conflictingProfiles: [],
        optionalProfiles: []
      },
      metadata: {
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        version: '1.0.0',
        tags: ['migrated', 'legacy'],
        stability: 'stable'
      }
    });

    // Profil Hardware CPU
    profiles.push({
      profileId: `profile-hardware-cpu-${Date.now()}`,
      category: 'hardware-cpu',
      name: 'Profil CPU (migré)',
      description: 'Profil CPU migré depuis l\'ancien système',
      configuration: config.config.hardware.cpu,
      priority: 100,
      compatibility: {
        requiredProfiles: [],
        conflictingProfiles: [],
        optionalProfiles: []
      },
      metadata: {
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        version: '1.0.0',
        tags: ['migrated', 'legacy'],
        stability: 'stable'
      }
    });

    // Profil Hardware Memory
    profiles.push({
      profileId: `profile-hardware-memory-${Date.now()}`,
      category: 'hardware-memory',
      name: 'Profil Memory (migré)',
      description: 'Profil Memory migré depuis l\'ancien système',
      configuration: config.config.hardware.memory,
      priority: 100,
      compatibility: {
        requiredProfiles: [],
        conflictingProfiles: [],
        optionalProfiles: []
      },
      metadata: {
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        version: '1.0.0',
        tags: ['migrated', 'legacy'],
        stability: 'stable'
      }
    });

    // Profil Hardware Storage
    profiles.push({
      profileId: `profile-hardware-storage-${Date.now()}`,
      category: 'hardware-storage',
      name: 'Profil Storage (migré)',
      description: 'Profil Storage migré depuis l\'ancien système',
      configuration: config.config.hardware.disks,
      priority: 100,
      compatibility: {
        requiredProfiles: [],
        conflictingProfiles: [],
        optionalProfiles: []
      },
      metadata: {
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        version: '1.0.0',
        tags: ['migrated', 'legacy'],
        stability: 'stable'
      }
    });

    // Profil Software PowerShell
    profiles.push({
      profileId: `profile-software-powershell-${Date.now()}`,
      category: 'software-powershell',
      name: 'Profil PowerShell (migré)',
      description: 'Profil PowerShell migré depuis l\'ancien système',
      configuration: { version: config.config.software.powershell },
      priority: 100,
      compatibility: {
        requiredProfiles: [],
        conflictingProfiles: [],
        optionalProfiles: []
      },
      metadata: {
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        version: '1.0.0',
        tags: ['migrated', 'legacy'],
        stability: 'stable'
      }
    });

    // Profil Software Node
    profiles.push({
      profileId: `profile-software-node-${Date.now()}`,
      category: 'software-node',
      name: 'Profil Node (migré)',
      description: 'Profil Node migré depuis l\'ancien système',
      configuration: { version: config.config.software.node },
      priority: 100,
      compatibility: {
        requiredProfiles: [],
        conflictingProfiles: [],
        optionalProfiles: []
      },
      metadata: {
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        version: '1.0.0',
        tags: ['migrated', 'legacy'],
        stability: 'stable'
      }
    });

    // Profil Software Python
    profiles.push({
      profileId: `profile-software-python-${Date.now()}`,
      category: 'software-python',
      name: 'Profil Python (migré)',
      description: 'Profil Python migré depuis l\'ancien système',
      configuration: { version: config.config.software.python },
      priority: 100,
      compatibility: {
        requiredProfiles: [],
        conflictingProfiles: [],
        optionalProfiles: []
      },
      metadata: {
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        version: '1.0.0',
        tags: ['migrated', 'legacy'],
        stability: 'stable'
      }
    });

    // Profil System OS
    profiles.push({
      profileId: `profile-system-os-${Date.now()}`,
      category: 'system-os',
      name: 'Profil OS (migré)',
      description: 'Profil OS migré depuis l\'ancien système',
      configuration: { os: config.config.system.os },
      priority: 100,
      compatibility: {
        requiredProfiles: [],
        conflictingProfiles: [],
        optionalProfiles: []
      },
      metadata: {
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        version: '1.0.0',
        tags: ['migrated', 'legacy'],
        stability: 'stable'
      }
    });

    // Profil System Architecture
    profiles.push({
      profileId: `profile-system-architecture-${Date.now()}`,
      category: 'system-architecture',
      name: 'Profil Architecture (migré)',
      description: 'Profil Architecture migré depuis l\'ancien système',
      configuration: { arch: config.config.system.architecture },
      priority: 100,
      compatibility: {
        requiredProfiles: [],
        conflictingProfiles: [],
        optionalProfiles: []
      },
      metadata: {
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        version: '1.0.0',
        tags: ['migrated', 'legacy'],
        stability: 'stable'
      }
    });
  }

  return profiles;
}
```

---

### Phase 3 : Migration des Services (T3.10c)

**Objectif :** Éliminer la double instanciation et utiliser uniquement NonNominativeBaselineService.

#### 3.1 Modifier RooSyncService

```typescript
// Avant
private baselineService: BaselineService;
private nonNominativeBaselineService: NonNominativeBaselineService;

// Après
private baselineService?: BaselineService; // @deprecated - pour backward compat
private nonNominativeBaselineService: NonNominativeBaselineService;
```

#### 3.2 Mettre à jour les méthodes utilisant BaselineService

Méthodes à migrer :
- `updateBaseline()` - Mode 'legacy' → utiliser NonNominativeBaselineService
- `compareWithBaseline()` → utiliser `compareMachinesNonNominative()`
- `createSyncDecisions()` → adapter pour NonNominativeBaselineService

#### 3.3 Ajouter méthode de migration dans les outils MCP

```typescript
// src/tools/roosync/migrate-baseline.ts
export async function migrateLegacyBaseline(args: {
  createBackup?: boolean;
  dryRun?: boolean;
}): Promise<MigrationResult> {
  const service = RooSyncService.getInstance();
  return await service.migrateToNonNominative(args);
}
```

#### 3.4 Supprimer BaselineService après validation

Une fois tous les tests passés et la migration validée :
- Supprimer `src/services/BaselineService.ts`
- Supprimer `src/services/baseline/` (sous-modules)
- Mettre à jour tous les imports

---

### Phase 4 : Documentation (T3.11)

**Objectif :** Documenter la nouvelle architecture et guider les utilisateurs.

#### 4.1 Mettre à jour `docs/roosync/GUIDE-TECHNIQUE-v2.3.md`

Ajouter une section sur l'architecture unifiée :
- Description du modèle Non-Nominatif v3.0
- Schéma de la nouvelle architecture
- Guide d'utilisation des profils

#### 4.2 Documenter le nouveau schéma de baseline

Créer `docs/roosync/BASELINE_SCHEMA_V3.md` :
- Structure complète de `UnifiedBaseline`
- Description des 11 catégories
- Exemples de profils

#### 4.3 Créer guide de migration

Créer `docs/roosync/MIGRATION_V2_TO_V3.md` :
- Étapes pour migrer depuis v2.1
- Commandes MCP à utiliser
- Gestion des backups et rollbacks

---

## 5. Risques et Mitigations

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|
| Régression lors de la migration | Medium | High | Tests E2E complets avant migration |
| Perte de données legacy | Low | Critical | Backup + rollback automatique |
| Incompatibilité avec outils existants | Medium | Medium | Période de coexistence v2.1/v3.0 |
| Performance dégradée | Low | Medium | Benchmark avant/après refactorisation |
| Erreurs de type TypeScript | Medium | Medium | Tests de compilation stricts |

---

## 6. Ordre d'Exécution

1. **Phase 1** (T3.10a) - Consolidation des Types
   - Créer `types/baseline-unified.ts`
   - Marquer les anciens types comme deprecated
   - Mettre à jour les imports
   - Tests de compilation

2. **Phase 2** (T3.10b) - Compléter les Stubs
   - Implémenter `aggregateByMajority()`
   - Implémenter `aggregateByWeightedAverage()`
   - Compléter `extractProfilesFromLegacy()`
   - Tests unitaires pour les nouvelles fonctions

3. **Phase 3** (T3.10c) - Migration des Services
   - Modifier RooSyncService
   - Mettre à jour les méthodes
   - Ajouter outil de migration MCP
   - Tests E2E complets
   - Supprimer BaselineService après validation

4. **Phase 4** (T3.11) - Documentation
   - Mettre à jour GUIDE-TECHNIQUE-v2.3.md
   - Documenter le schéma v3
   - Créer guide de migration

---

## 7. Critères de Validation

### Phase 1
- [ ] `types/baseline-unified.ts` créé et compilé
- [ ] Anciens types marqués comme `@deprecated`
- [ ] Tous les imports mis à jour
- [ ] `npm run build` réussi

### Phase 2
- [ ] `aggregateByMajority()` implémenté et testé
- [ ] `aggregateByWeightedAverage()` implémenté et testé
- [ ] `extractProfilesFromLegacy()` extrait 11 catégories
- [ ] Tests unitaires passent

### Phase 3
- [ ] RooSyncService utilise uniquement NonNominativeBaselineService
- [ ] Outil de migration MCP fonctionnel
- [ ] Tests E2E passent
- [ ] BaselineService supprimé

### Phase 4
- [ ] Documentation mise à jour
- [ ] Guide de migration créé
- [ ] Exemples d'utilisation fournis

---

## 8. Prochaines Étapes

1. **Valider ce plan** avec l'équipe
2. **Créer les issues GitHub** pour chaque phase
3. **Commencer Phase 1** (consolidation types)
4. **Exécuter les tests** après chaque phase
5. **Documenter les résultats** dans le rapport final

---

**Document généré par Claude Code (myia-ai-01)**
**Date :** 2026-01-15T13:00:00Z
**Basé sur :** T3.9 - Analyse et Recommandation : Modèle de Baseline Unique
