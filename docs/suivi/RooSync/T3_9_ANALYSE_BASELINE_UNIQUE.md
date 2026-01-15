# T3.9 - Analyse et Recommandation : Modèle de Baseline Unique

**Date :** 2026-01-15
**Auteur :** Claude Code (myia-po-2023)
**Statut :** Analyse complétée - Recommandation émise

---

## 1. Contexte

Le système RooSync maintient actuellement **deux systèmes de baseline en parallèle**, créant une "double source de vérité" identifiée comme un risque architectural.

### Systèmes en place

| Système | Version | Service | Fichier principal |
|---------|---------|---------|-------------------|
| Nominatif | v2.1 | `BaselineService.ts` | `sync-config.ref.json` |
| Non-nominatif | v2.2-v3.0 | `NonNominativeBaselineService.ts` | Multiple (profiles, mappings) |

---

## 2. Analyse des Deux Approches

### 2.1 Baseline Nominative (v2.1 - Legacy)

**Philosophie :** Approche machine-centrique, basée sur l'identité explicite.

| Aspect | Détail |
|--------|--------|
| **Identification** | `machineId` explicite (ex: "myia-ai-01") |
| **Structure** | Fichier JSON monolithique par machine |
| **Comparaison** | Directe baseline → machine cible |
| **Catégories** | 4 (roo, hardware, software, system) |
| **Scalabilité** | Une baseline par machine de référence |

**Avantages :**
- Simple à comprendre et debugger
- Traçabilité claire (quelle machine = quelle config)
- Implémentation mature (769 lignes, testée)

**Inconvénients :**
- Pas de réutilisation des configurations
- Exposition des noms de machines
- Difficile à étendre à N machines

### 2.2 Baseline Non-Nominative (v2.2-v3.0 - Modern)

**Philosophie :** Approche configuration-centrique, anonymisée et modulaire.

| Aspect | Détail |
|--------|--------|
| **Identification** | Hash SHA256 anonymisé (16 chars) |
| **Structure** | Profiles modulaires + mappings séparés |
| **Comparaison** | Par profile et catégorie |
| **Catégories** | 11 (roo-core, roo-advanced, hardware-*, software-*, system-*) |
| **Scalabilité** | Profiles partagés, mappings multiples |

**Avantages :**
- Modularité et réutilisation des configurations
- Anonymisation (privacy by design)
- Granularité fine (11 catégories)
- Agrégation automatique (majority, weighted, latest)

**Inconvénients :**
- Plus complexe à comprendre
- Implémentation incomplète (stubs d'agrégation)
- Migration legacy incomplète

---

## 3. Problèmes Identifiés

### 3.1 Duplications de Types

| Interface | Occurrences | Fichiers |
|-----------|-------------|----------|
| `MachineInventory` | 3 | baseline.ts, non-nominative-baseline.ts, non-nominative-baseline-v3.ts |
| `ConfigurationProfile` | 2 | non-nominative-baseline.ts, non-nominative-baseline-v3.ts |

### 3.2 Double Instanciation

```typescript
// RooSyncService.ts - Lignes 80-91
private baselineService: BaselineService;
private nonNominativeBaselineService: NonNominativeBaselineService;
// Les deux sont instanciés et maintenus en parallèle
```

### 3.3 Stubs d'Agrégation

```typescript
// NonNominativeBaselineService.ts - Lignes 247-297
aggregateByMajority(data) { return data[0]; }  // Stub!
aggregateByWeightedAverage(data) { return data[0]; }  // Stub!
```

### 3.4 Migration Incomplète

`migrateFromLegacy()` n'extrait que 2 catégories sur 11 (roo-core, hardware-cpu).

---

## 4. Recommandation

### Choix : **Non-Nominatif v3.0** comme modèle unique

| Critère | Nominatif v2.1 | Non-Nominatif v3.0 | Gagnant |
|---------|----------------|-------------------|---------|
| Modularité | Monolithique | Profiles composables | v3.0 |
| Privacy | Noms exposés | Hashes anonymes | v3.0 |
| Scalabilité | 1 baseline/machine | Profiles partagés | v3.0 |
| Granularité | 4 catégories | 11 catégories | v3.0 |
| Maturité | Stable, testée | Stubs incomplets | v2.1 |
| Simplicité | Simple | Plus complexe | v2.1 |

**Score : v3.0 gagne 4-2**

### Justification

1. **Architecture future-proof** : La modularité permet d'ajouter des machines sans dupliquer les configurations
2. **Privacy compliance** : L'anonymisation évite l'exposition des noms de machines
3. **Réutilisation** : Un profile "roo-core" peut être partagé entre 5 machines identiques
4. **Catégorisation fine** : 11 catégories permettent une synchronisation sélective

---

## 5. Plan de Transition

### Phase 1 : Consolidation des Types (T3.10a)
- [ ] Créer `types/baseline-unified.ts` avec types canoniques
- [ ] Marquer `baseline.ts` et `non-nominative-baseline.ts` comme `@deprecated`
- [ ] Conserver `non-nominative-baseline-v3.ts` comme référence

### Phase 2 : Compléter les Stubs (T3.10b)
- [ ] Implémenter `aggregateByMajority()` (vote majoritaire réel)
- [ ] Implémenter `aggregateByWeightedAverage()` (moyenne pondérée)
- [ ] Compléter `extractProfilesFromLegacy()` pour les 11 catégories

### Phase 3 : Migration des Services (T3.10c)
- [ ] Modifier `RooSyncService` pour utiliser uniquement `NonNominativeBaselineService`
- [ ] Ajouter méthode `migrateLegacyBaseline()` dans les outils MCP
- [ ] Supprimer `BaselineService` après validation

### Phase 4 : Documentation (T3.11)
- [ ] Mettre à jour `docs/roosync/GUIDE-TECHNIQUE-v2.3.md`
- [ ] Documenter le nouveau schéma de baseline
- [ ] Créer guide de migration pour utilisateurs existants

---

## 6. Risques et Mitigations

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|
| Régression lors de la migration | Medium | High | Tests E2E complets avant migration |
| Perte de données legacy | Low | Critical | Backup + rollback automatique |
| Incompatibilité avec outils existants | Medium | Medium | Période de coexistence v2.1/v3.0 |

---

## 7. Prochaines Étapes

1. **Valider cette recommandation** avec l'équipe (myia-ai-01)
2. **Créer les issues GitHub** pour T3.10a, T3.10b, T3.10c
3. **Assigner les tâches** aux agents appropriés
4. **Commencer Phase 1** (consolidation types)

---

## 8. Fichiers Analysés

- `src/types/baseline.ts` (380 lignes)
- `src/types/non-nominative-baseline.ts` (348 lignes)
- `src/types/non-nominative-baseline-v3.ts` (309 lignes)
- `src/services/BaselineService.ts` (769 lignes)
- `src/services/roosync/NonNominativeBaselineService.ts` (949 lignes)
- `src/services/roosync/BaselineManager.ts` (1181 lignes)

---

**Rapport généré par Claude Code (myia-po-2023)**
**Date :** 2026-01-15T00:45:00Z
