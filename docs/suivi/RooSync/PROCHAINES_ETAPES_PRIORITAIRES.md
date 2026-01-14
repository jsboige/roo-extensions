# Prochaines Étapes Prioritaires - RooSync

**Date:** 2026-01-14
**Coordinateur:** Claude Code (myia-ai-01)
**Progression:** 29/77 DONE (37.7%)

---

## 📊 État Actuel

### ✅ Ce qui fonctionne

| Composant | Statut | Détails |
|-----------|--------|---------|
| **RooSync Core** | ✅ STABLE | Error Handling: 20/20, Workflow: 8/8 |
| **Tests E2E** | ✅ 38/40 PASS | Smoke test validé (T3.3) |
| **Tests Unitaires** | ✅ 1045/1076 PASS | 97.1% de réussite |
| **Bugs critiques** | ✅ 0 ouverts | Tous les bugs HIGH/MEDIUM fixés |

### ⚠️ Ce qui bloque

| Problème | Impact | Solution |
|----------|--------|----------|
| **myia-po-2026 HS** | Smoke Test inter-machines | Reboot manuel requis |
| **Tests flaky** | 6 fichiers échouent | FileLockManager Windows, BaselineLoader |
| **Inventaires** | Smoke test bloqué | Toutes les machines doivent lancer `roosync_get_machine_inventory` |

---

## 🎯 Tâches Prioritaires (sans myia-po-2026)

### Priority 1 - Stabilisation

#### T2.6 - Améliorer gestion du cache
- **Fichier:** `CacheManager.ts`
- **Action:** Augmenter TTL par défaut + invalider intelligemment
- **Impact:** Performance globale

#### T2.8 - Améliorer gestion des erreurs
- **Action:** Propager les erreurs de manière explicite
- **Ajouter:** Codes d'erreur structurés
- **Impact:** Meilleur diagnostic

### Priority 2 - Corrections

#### T2.16 - Corriger InventoryCollector incohérence
- **Fichier:** `InventoryCollector.ts`
- **Problème:** `applyConfig()` n'utilise pas les mêmes chemins que la collecte
- **Solution:** Harmoniser les chemins

#### Tests - Corriger les 6 fichiers échouants
- `task-indexer.test.ts` (5 tests)
- `BaselineLoader.test.ts` (fichiers de test manquants)

---

## 🚀 Smoke Test Inter-Machines (après retour myia-po-2026)

### Pré-requis

Chaque machine doit créer son inventaire :
```bash
roosync_get_machine_inventory
```

### Validation

Une fois les inventaires créés :
```bash
# Sur une machine, comparer avec une autre
roosync_compare_config --source myia-ai-01 --target myia-po-2023
```

### Critère de succès

- Un diff réel est généré entre 2 machines
- Les décisions de synchronisation sont visibles
- Une capture d'écran du système en action

---

## 📋 Pour les Agents Roo

### myia-po-2023, myia-po-2024, myia-web-01

**Tâches disponibles:**
1. Prendre une tâche dans la liste Priority 1 ou 2
2. Créer une GitHub issue pour tracabilité
3. Travailler et committer quand c'est prêt
4. Annoncer via RooSync quand c'est fait

**Exemple de workflow:**
```bash
# 1. Prendre T2.6
# 2. Lire CacheManager.ts
# 3. Implémenter les améliorations
# 4. Tester: npm test
# 5. Commit: git commit -m "feat(cache): Increase TTL and add smart invalidation"
# 6. Message RooSync avec bilan
```

### myia-po-2026 (après reboot)

**Priorité immédiate:**
1. Lancer `roosync_get_machine_inventory`
2. Annoncer retour via RooSync
3. Reprendre les corrections de tests en cours

---

## 🔧 Références Techniques

### Fichiers clés

| Fichier | Usage |
|---------|-------|
| `CacheManager.ts` | Gestion du cache (T2.6) |
| `InventoryCollector.ts` | Collecte inventaire (T2.16) |
| `MessageManager.ts` | Messages RooSync (erreurs) |
| `NonNominativeBaselineService.ts` | Baselines non-nominatives |

### Documentation

- `SUIVI_ACTIF.md` - Historique des progrès
- `INDEX.md` - Navigation documentation
- `T3_3_RAPPORT_SMOKE_TEST_E2E.md` - Résultats smoke test

---

## 💡 Conseils

1. **Commencer petit:** Prendre une tâche à la fois
2. **Tester souvent:** `npm test` avant de committer
3. **Communiquer:** Annoncer les progrès via RooSync
4. **Demander de l'aide:** INTERCOM ou RooSync si bloqué

---

**Coordinateur:** Claude Code (myia-ai-01)
**Mis à jour:** 2026-01-14
