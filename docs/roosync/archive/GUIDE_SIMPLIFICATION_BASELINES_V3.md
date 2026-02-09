# Guide de Simplification des Baselines Non-Nominatives v3

**Version:** 3.0.0
**Date:** 2026-01-12
**Tâche:** 2.7 - Simplifier l'architecture des baselines non-nominatives
**Responsable:** myia-ai-01

---

## 1. Vue d'Ensemble

Ce guide documente la simplification de l'architecture des baselines non-nominatives de RooSync v2.3. L'objectif est de réduire la complexité tout en préservant les fonctionnalités essentielles.

### 1.1 Objectifs de la Simplification

- **Réduire le nombre de fichiers de stockage** (4 → 2)
- **Réduire le nombre d'interfaces** (11 → 9)
- **Simplifier les structures de données** (moins d'imbrication)
- **Améliorer la maintenabilité** (code plus clair)
- **Faciliter la compréhension** (documentation améliorée)

---

## 2. Changements Principaux

### 2.1 Fichiers de Stockage

#### Avant (v2.2)

| Fichier | Description | Contenu |
|---------|-------------|---------|
| `non-nominative-baseline.json` | Baseline active | `NonNominativeBaseline` |
| `configuration-profiles.json` | Profils de configuration | `ConfigurationProfile[]` |
| `machine-mappings.json` | Mappings machine → baseline | `MachineConfigurationMapping[]` |
| `non-nominative-state.json` | État du service | `NonNominativeBaselineState` |

#### Après (v3.0)

| Fichier | Description | Contenu |
|---------|-------------|---------|
| `baseline.json` | Baseline active (inclut les profils) | `NonNominativeBaseline` |
| `state.json` | État du service (inclut les mappings) | `NonNominativeBaselineState` |

**Avantages:**
- Moins de fichiers à gérer
- Cohérence accrue (les profils sont dans la baseline)
- Opérations atomiques plus simples

### 2.2 Types et Interfaces

#### Interfaces Supprimées

| Interface | Raison |
|-----------|---------|
| `BaselineVersion` | Fusionnée dans `NonNominativeBaseline.metadata.versionHistory` |

#### Interfaces Simplifiées

| Interface | Changements |
|-----------|-------------|
| `ConfigurationProfile` | Suppression du champ `compatibility` |
| `NonNominativeBaseline` | Fusion de `BaselineVersion` dans `metadata.versionHistory` |
| `MachineConfigurationMapping` | Suppression des champs `source`, `severity`, `confidence` |
| `NonNominativeComparisonReport` | Suppression du champ `differencesBySeverity` |
| `AggregationConfig` | Suppression de la stratégie `weighted_average` |
| `MigrationOptions` | Suppression des champs `keepLegacyReferences`, `machineMappingStrategy`, `autoValidate` |
| `MigrationResult` | Suppression du champ `deviationsDetected` |

### 2.3 Stratégies d'Agrégation

#### Avant (v2.2)

| Stratégie | Description |
|-----------|-------------|
| `majority` | Valeur la plus fréquente |
| `latest` | Dernière valeur |
| `weighted_average` | Moyenne pondérée |

#### Après (v3.0)

| Stratégie | Description |
|-----------|-------------|
| `majority` | Valeur la plus fréquente |
| `latest` | Dernière valeur |

**Raison:** La stratégie `weighted_average` était complexe et peu utilisée.

### 2.4 Système de Mapping

#### Avant (v2.2)

```typescript
{
  appliedProfiles: [{
    profileId: string;
    category: ConfigurationCategory;
    appliedAt: string;
    source: 'auto' | 'manual' | 'inherited';  // Supprimé
  }],
  deviations: [{
    category: ConfigurationCategory;
    expectedValue: any;
    actualValue: any;
    severity: 'CRITICAL' | 'IMPORTANT' | 'WARNING' | 'INFO';  // Supprimé
    detectedAt: string;
  }],
  metadata: {
    firstSeen: string;
    lastSeen: string;
    lastUpdated: string;
    confidence: number;  // Supprimé
  };
}
```

#### Après (v3.0)

```typescript
{
  appliedProfiles: [{
    profileId: string;
    category: ConfigurationCategory;
    appliedAt: string;
  }],
  deviations: [{
    category: ConfigurationCategory;
    expectedValue: any;
    actualValue: any;
    detectedAt: string;
  }],
  metadata: {
    firstSeen: string;
    lastSeen: string;
    lastUpdated: string;
  };
}
```

**Raison:** Les champs `source`, `severity`, et `confidence` ajoutaient de la complexité sans apporter de valeur significative.

---

## 3. Migration vers v3.0

### 3.1 Pré-requis

- Backup de tous les fichiers existants
- Compréhension de l'architecture actuelle
- Accès aux fichiers de configuration

### 3.2 Étapes de Migration

#### Étape 1: Backup

```bash
# Créer un répertoire de backup
mkdir -p .roosync/backup-v2.2

# Copier tous les fichiers existants
cp .roosync/non-nominative-baseline.json .roosync/backup-v2.2/
cp .roosync/configuration-profiles.json .roosync/backup-v2.2/
cp .roosync/machine-mappings.json .roosync/backup-v2.2/
cp .roosync/non-nominative-state.json .roosync/backup-v2.2/
```

#### Étape 2: Fusionner les Profils dans la Baseline

```typescript
// Charger la baseline existante
const baseline = JSON.parse(fs.readFileSync('.roosync/non-nominative-baseline.json', 'utf-8'));

// Charger les profils existants
const profiles = JSON.parse(fs.readFileSync('.roosync/configuration-profiles.json', 'utf-8'));

// Fusionner les profils dans la baseline
baseline.profiles = [...baseline.profiles, ...profiles];

// Sauvegarder la nouvelle baseline
fs.writeFileSync('.roosync/baseline.json', JSON.stringify(baseline, null, 2));
```

#### Étape 3: Fusionner les Mappings dans l'État

```typescript
// Charger l'état existant
const state = JSON.parse(fs.readFileSync('.roosync/non-nominative-state.json', 'utf-8'));

// Charger les mappings existants
const mappings = JSON.parse(fs.readFileSync('.roosync/machine-mappings.json', 'utf-8'));

// Fusionner les mappings dans l'état
state.machineMappings = [...state.machineMappings, ...mappings];

// Sauvegarder le nouvel état
fs.writeFileSync('.roosync/state.json', JSON.stringify(state, null, 2));
```

#### Étape 4: Nettoyer les Anciens Fichiers

```bash
# Supprimer les anciens fichiers (après vérification)
rm .roosync/non-nominative-baseline.json
rm .roosync/configuration-profiles.json
rm .roosync/machine-mappings.json
rm .roosync/non-nominative-state.json
```

#### Étape 5: Mettre à Jour le Code

```typescript
// Avant (v2.2)
import { NonNominativeBaseline, BaselineVersion } from './types/non-nominative-baseline.js';

// Après (v3.0)
import { NonNominativeBaseline } from './types/non-nominative-baseline-v3.js';
```

### 3.3 Validation

```bash
# Vérifier que les nouveaux fichiers existent
ls -la .roosync/baseline.json
ls -la .roosync/state.json

# Vérifier que les anciens fichiers n'existent plus
ls -la .roosync/non-nominative-baseline.json  # Doit échouer
ls -la .roosync/configuration-profiles.json  # Doit échouer
ls -la .roosync/machine-mappings.json  # Doit échouer
ls -la .roosync/non-nominative-state.json  # Doit échouer
```

---

## 4. Utilisation de la Nouvelle Architecture

### 4.1 Créer une Baseline

```typescript
import { NonNominativeBaselineService } from './services/roosync/NonNominativeBaselineService.js';

const service = new NonNominativeBaselineService('.roosync');

const baseline = await service.createBaseline(
  'Ma Baseline',
  'Description de ma baseline',
  [
    {
      profileId: 'profile-roo-core-001',
      category: 'roo-core',
      name: 'Profil Roo Core',
      description: 'Configuration Roo de base',
      configuration: {
        modes: ['code', 'ask', 'architect'],
        mcpSettings: {}
      },
      priority: 100,
      metadata: {
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        version: '1.0.0',
        tags: ['stable'],
        stability: 'stable'
      }
    }
  ]
);
```

### 4.2 Agréger une Baseline

```typescript
const inventories = [
  {
    machineId: 'myia-ai-01',
    config: {
      roo: {
        modes: ['code', 'ask'],
        mcpSettings: {}
      },
      hardware: {
        cpu: { model: 'Intel i7', cores: 8 },
        memory: { total: 32000000000 }
      },
      software: {
        powershell: '7.2.0',
        node: '24.6.0',
        python: '3.13.7'
      },
      system: {
        os: 'Windows 11',
        architecture: 'x64'
      }
    },
    metadata: {
      lastSeen: new Date().toISOString(),
      version: '2.3.0',
      source: 'inventory'
    }
  }
];

const config = {
  sources: [
    { type: 'machine_inventory', weight: 1.0, enabled: true }
  ],
  categoryRules: {
    'roo-core': { strategy: 'majority', autoApply: true },
    'hardware-cpu': { strategy: 'latest', autoApply: true }
  },
  thresholds: {
    deviationThreshold: 0.1,
    complianceThreshold: 0.9
  }
};

const baseline = await service.aggregateBaseline(inventories, config);
```

### 4.3 Mapper une Machine à la Baseline

```typescript
const mapping = await service.mapMachineToBaseline(
  'myia-ai-01',
  {
    machineId: 'myia-ai-01',
    config: {
      roo: {
        modes: ['code', 'ask'],
        mcpSettings: {}
      },
      hardware: {
        cpu: { model: 'Intel i7', cores: 8 },
        memory: { total: 32000000000 }
      },
      software: {
        powershell: '7.2.0',
        node: '24.6.0',
        python: '3.13.7'
      },
      system: {
        os: 'Windows 11',
        architecture: 'x64'
      }
    },
    metadata: {
      lastSeen: new Date().toISOString(),
      version: '2.3.0',
      source: 'inventory'
    }
  }
);
```

### 4.4 Comparer des Machines

```typescript
const report = await service.compareMachines([
  service.generateMachineHash('myia-ai-01'),
  service.generateMachineHash('myia-po-2024')
]);

console.log(`Taux de conformité: ${report.statistics.complianceRate * 100}%`);
console.log(`Nombre de différences: ${report.statistics.totalDifferences}`);
```

---

## 5. Avantages de la Simplification

### 5.1 Moins de Fichiers

- **Avant:** 4 fichiers à gérer
- **Après:** 2 fichiers à gérer
- **Gain:** 50% de réduction

### 5.2 Moins d'Interfaces

- **Avant:** 11 interfaces
- **Après:** 9 interfaces
- **Gain:** 18% de réduction

### 5.3 Moins de Complexité

- **Avant:** 948 lignes, 25 méthodes
- **Après:** ~600 lignes, ~18 méthodes (estimation)
- **Gain:** ~37% de réduction

### 5.4 Meilleure Compréhension

- **Avant:** Structures complexes et imbriquées
- **Après:** Structures simples et claires
- **Gain:** Facilite l'onboarding des nouveaux développeurs

---

## 6. Questions Fréquentes

### Q1: Pourquoi avoir supprimé la stratégie `weighted_average` ?

**R:** La stratégie `weighted_average` était complexe à implémenter et peu utilisée en pratique. Les stratégies `majority` et `latest` couvrent la plupart des cas d'utilisation.

### Q2: Pourquoi avoir supprimé le champ `severity` des déviations ?

**R:** Le champ `severity` ajoutait de la complexité sans apporter de valeur significative. Les déviations sont maintenant simplement détectées sans classification de sévérité.

### Q3: Pourquoi avoir supprimé le champ `confidence` des métadonnées ?

**R:** Le champ `confidence` était difficile à calculer de manière fiable et peu utilisé en pratique. Les déviations sont maintenant simplement détectées sans score de confiance.

### Q4: Comment migrer depuis v2.2 vers v3.0 ?

**R:** Suivez les étapes de migration décrites dans la section 3. Assurez-vous de faire un backup avant de commencer.

### Q5: Est-ce que la migration est réversible ?

**R:** Oui, si vous avez fait un backup des fichiers v2.2, vous pouvez restaurer les anciens fichiers et revenir à la version précédente.

---

## 7. Support

Pour toute question ou problème lié à la simplification des baselines non-nominatives, veuillez :

1. Consulter ce guide
2. Vérifier la documentation technique
3. Ouvrir une issue sur GitHub

---

**Document généré automatiquement par Roo Code**
**Tâche:** 2.7 - Simplifier l'architecture des baselines non-nominatives
**Date:** 2026-01-12
**Version:** 3.0.0
