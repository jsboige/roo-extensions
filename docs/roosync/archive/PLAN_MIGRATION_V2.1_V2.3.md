# Plan de Migration RooSync v2.1 → v2.3

**Date:** 2026-01-04T01:35:00Z
**Tâche:** 2.1 - Compléter la transition v2.1→v2.3
**Responsable:** myia-po-2024 (Coordinateur Technique)
**Priorité:** HIGH

---

## 1. Résumé Exécutif

Ce document définit le plan de migration complet de RooSync v2.1 vers v2.3. La migration est nécessaire pour résoudre la dualité architecturale actuelle qui cause l'instabilité du système.

### Objectifs
- Éliminer la dualité architecturale entre `BaselineService` (v2.1) et `NonNominativeBaselineService` (v2.3)
- Standardiser tous les outils sur l'architecture v2.3
- Assurer la compatibilité ascendante
- Documenter et tester la migration

### Statut Actuel
- ✅ Fichier de configuration mis à jour vers v2.3.0
- ✅ Backup créé (`sync-config.ref.backup.v2.1-*.json`)
- ⏳ Migration des outils en cours
- ⏳ Tests de migration à implémenter

---

## 2. Architecture v2.1 vs v2.3

### 2.1 Architecture v2.1 (Legacy)

**Service Principal:** `BaselineService`
**Approche:** Nominative (basée sur `machineId`)
**Structure:** Monolithique

**Caractéristiques:**
- Baseline unique par machine
- Comparaison directe avec la baseline
- Structure de configuration simple
- Mapping direct machine → baseline

**Outils utilisant v2.1:**
1. `manage-baseline.ts` - Ligne 140, 340
2. `update-baseline.ts` - Ligne 150
3. `export-baseline.ts` - Ligne 68

### 2.2 Architecture v2.3 (Cible)

**Service Principal:** `NonNominativeBaselineService`
**Approche:** Non-nominative (basée sur des profils)
**Structure:** Modulaire

**Caractéristiques:**
- Baselines par catégories de configuration
- Mapping anonymisé des machines (hash SHA256)
- Profils réutilisables
- Agrégation automatique

**Outils utilisant v2.3:**
- Tous les autres outils RooSync (16 outils consolidés)

---

## 3. Plan de Migration

### Étape 1: Migration des Outils (Critique)

#### 1.1 Migrer `manage-baseline.ts`

**Fichier:** `mcps/internal/servers/roo-state-manager/src/tools/roosync/manage-baseline.ts`

**Modifications requises:**
1. Remplacer `BaselineService` par `NonNominativeBaselineService`
2. Adapter les méthodes pour utiliser l'API v2.3
3. Mettre à jour les types TypeScript
4. Tester les fonctionnalités version et restore

**Code à modifier:**
```typescript
// Avant (v2.1)
import { BaselineService } from '../../services/BaselineService.js';
const baselineService = new BaselineService(configService, {} as any, {} as any);

// Après (v2.3)
import { NonNominativeBaselineService } from '../../services/roosync/NonNominativeBaselineService.js';
const baselineService = new NonNominativeBaselineService(config.sharedPath);
```

#### 1.2 Migrer `update-baseline.ts`

**Fichier:** `mcps/internal/servers/roo-state-manager/src/tools/roosync/update-baseline.ts`

**Modifications requises:**
1. Remplacer `BaselineService` par `NonNominativeBaselineService`
2. Adapter la logique de création de baseline
3. Utiliser `createBaseline()` ou `aggregateBaseline()` selon le mode
4. Mettre à jour les types TypeScript

**Code à modifier:**
```typescript
// Avant (v2.1)
import { BaselineService } from '../../services/BaselineService.js';
const baselineService = new BaselineService(configService, inventoryCollector as any, diffDetector);

// Après (v2.3)
import { NonNominativeBaselineService } from '../../services/roosync/NonNominativeBaselineService.js';
const baselineService = new NonNominativeBaselineService(config.sharedPath);
```

#### 1.3 Migrer `export-baseline.ts`

**Fichier:** `mcps/internal/servers/roo-state-manager/src/tools/roosync/export-baseline.ts`

**Modifications requises:**
1. Remplacer `BaselineService` par `NonNominativeBaselineService`
2. Adapter les méthodes d'export pour le nouveau format
3. Mettre à jour les types TypeScript

**Code à modifier:**
```typescript
// Avant (v2.1)
import { BaselineService } from '../../services/BaselineService.js';
const baselineService = new BaselineService({} as any, {} as any, {} as any);

// Après (v2.3)
import { NonNominativeBaselineService } from '../../services/roosync/NonNominativeBaselineService.js';
const baselineService = new NonNominativeBaselineService(sharedPath);
```

### Étape 2: Tests de Migration (Critique)

#### 2.1 Tests Unitaires

**Fichiers à créer:**
- `mcps/internal/servers/roo-state-manager/tests/tools/roosync/manage-baseline.test.ts`
- `mcps/internal/servers/roo-state-manager/tests/tools/roosync/update-baseline.test.ts`
- `mcps/internal/servers/roo-state-manager/tests/tools/roosync/export-baseline.test.ts`

**Tests à implémenter:**
1. Test de création de baseline v2.3
2. Test de versioning de baseline
3. Test de restauration de baseline
4. Test d'export de baseline
5. Test de migration v2.1 → v2.3

#### 2.2 Tests d'Intégration

**Scénarios à tester:**
1. Migration d'une configuration v2.1 existante
2. Création d'une nouvelle baseline v2.3
3. Comparaison de configurations avec baseline v2.3
4. Application de décisions avec baseline v2.3
5. Rollback de baseline v2.3

### Étape 3: Documentation (Important)

#### 3.1 Mise à jour de la Documentation Technique

**Documents à mettre à jour:**
1. `docs/roosync/GUIDE-TECHNIQUE-v2.3.md`
   - Ajouter section sur la migration v2.1→v2.3
   - Documenter les changements de rupture
   - Ajouter exemples de migration

2. `docs/roosync/ARCHITECTURE_ROOSYNC.md`
   - Mettre à jour la section sur la dualité architecturale
   - Documenter l'architecture finale v2.3

3. `docs/roosync/GUIDE-UTILISATION_ROOSYNC.md`
   - Mettre à jour les exemples d'utilisation
   - Documenter les nouveaux workflows

#### 3.2 Création du Guide de Migration

**Document à créer:** `docs/roosync/GUIDE-MIGRATION-V2.1-V2.3.md`

**Contenu:**
1. Introduction et objectifs
2. Prérequis
3. Étapes de migration
4. Validation post-migration
5. Rollback en cas d'erreur
6. FAQ

### Étape 4: Nettoyage (Amélioration)

#### 4.1 Suppression de l'Ancien Code

**Fichiers à supprimer:**
1. `mcps/internal/servers/roo-state-manager/src/services/BaselineService.ts`
2. `mcps/internal/servers/roo-state-manager/src/services/baseline/` (si existe)

**Conditions de suppression:**
- Tous les outils migrés vers v2.3
- Tests validés
- Documentation mise à jour
- Aucune référence à `BaselineService` dans le codebase

#### 4.2 Nettoyage des Fichiers Obsolètes

**Fichiers à nettoyer:**
1. Backups v2.1 obsolètes
2. Fichiers de configuration temporaires
3. Logs de migration

---

## 4. Validation Post-Migration

### 4.1 Checklist de Validation

- [ ] Tous les outils utilisent `NonNominativeBaselineService`
- [ ] Aucune référence à `BaselineService` dans le codebase
- [ ] Fichier de configuration en version 2.3.0
- [ ] Tests unitaires passants
- [ ] Tests d'intégration passants
- [ ] Documentation mise à jour
- [ ] Guide de migration créé
- [ ] Backup v2.1 conservé

### 4.2 Tests Fonctionnels

**Scénarios à valider:**
1. Création d'une baseline v2.3
2. Versioning d'une baseline v2.3
3. Restauration d'une baseline v2.3
4. Export d'une baseline v2.3
5. Comparaison avec baseline v2.3
6. Application de décisions avec baseline v2.3

### 4.3 Tests de Performance

**Métriques à mesurer:**
- Temps de création de baseline
- Temps de comparaison
- Temps d'export
- Utilisation mémoire
- Taille des fichiers de configuration

---

## 5. Rollback Plan

### 5.1 Conditions de Rollback

Le rollback doit être effectué si:
- Tests échouent de manière critique
- Performance dégradée significative
- Perte de fonctionnalités essentielles
- Erreurs inattendues non résolubles

### 5.2 Procédure de Rollback

1. Restaurer le backup v2.1:
   ```bash
   Copy-Item 'roo-config/backups/sync-config.ref.backup.v2.1-*.json' 'roo-config/sync-config.ref.json'
   ```

2. Restaurer les fichiers de code:
   ```bash
   git checkout HEAD~1 -- mcps/internal/servers/roo-state-manager/src/tools/roosync/
   ```

3. Redémarrer le serveur MCP:
   ```bash
   npx roo-state-manager restart
   ```

4. Valider le rollback:
   - Vérifier que le système fonctionne
   - Exécuter les tests v2.1
   - Documenter les raisons du rollback

---

## 6. Timeline Estimée

| Étape | Durée Estimée | Priorité |
|--------|----------------|----------|
| Migration des outils | 4-6 heures | Critique |
| Tests de migration | 2-3 heures | Critique |
| Documentation | 2-3 heures | Important |
| Nettoyage | 1-2 heures | Amélioration |
| Validation | 1-2 heures | Critique |
| **Total** | **10-16 heures** | - |

---

## 7. Risques et Mitigations

### 7.1 Risques Identifiés

| Risque | Impact | Probabilité | Mitigation |
|--------|---------|--------------|------------|
| Perte de données pendant migration | Critique | Faible | Backup automatique avant migration |
| Incompatibilité avec machines existantes | Élevé | Moyenne | Tests d'intégration complets |
| Performance dégradée | Moyen | Moyenne | Tests de performance |
| Erreurs de migration non détectées | Élevé | Faible | Tests unitaires et d'intégration |

### 7.2 Plan de Contingence

1. **Backup automatique:** Créer un backup avant chaque étape de migration
2. **Tests progressifs:** Valider chaque étape avant de passer à la suivante
3. **Rollback rapide:** Avoir une procédure de rollback documentée et testée
4. **Monitoring:** Surveiller les logs et les métriques pendant la migration

---

## 8. Conclusion

La migration v2.1→v2.3 est une étape critique pour stabiliser RooSync. En suivant ce plan de manière méthodique, nous pouvons éliminer la dualité architecturale actuelle et assurer la stabilité du système.

**Prochaine étape:** Commencer la migration des outils en commençant par `manage-baseline.ts`

---

**Rédigé par:** Roo Code (Mode Code)
**Approuvé par:** myia-po-2024 (Coordinateur Technique)
**Date de révision:** 2026-01-04T01:35:00Z
