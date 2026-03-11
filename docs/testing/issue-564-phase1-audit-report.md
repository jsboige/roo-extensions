# Issue #564 - Audit Phase 1 : Inventaire des outils MCP

**Date:** 2026-03-11
**Machine:** myia-ai-01
**Agent:** Roo Code (code-complex)

---

## Résumé Exécutif

| Métrique | Valeur |
|----------|--------|
| **Outils MCP exposés** | 32 |
| **Fichiers de tests** | 154 |
| **Tests unitaires** | 120 |
| **Tests d'intégration** | 34 |
| **Ratio tests intégration** | 22% |

---

## 1. Inventaire des Outils MCP

### 1.1 Outils de base (12 outils)

| # | Nom de l'outil | Description | Tests unit. | Tests intégr. |
|---|----------------|-------------|-------------|---------------|
| 1 | `conversation_browser` | CONS-X: Navigation unifiée (list/tree/view/summarize) | ✅ | ✅ |
| 2 | `task_export` | Export d'arbre en markdown/ASCII | ✅ | ✅ |
| 3 | `roosync_search` | CONS-11: Recherche unifiée (texte + sémantique) | ✅ | ✅ |
| 4 | `roosync_indexing` | CONS-11: Indexation unifiée | ✅ | ❌ |
| 5 | `codebase_search` | Recherche sémantique dans le code | ✅ | ❌ |
| 6 | `read_vscode_logs` | Lecture des logs VS Code | ✅ | ✅ |
| 7 | `get_mcp_best_practices` | Guide des bonnes pratiques MCP | ✅ | ❌ |
| 8 | `export_data` | CONS-10: Export unifié (XML/JSON/CSV) | ✅ | ✅ |
| 9 | `export_config` | CONS-10: Configuration des exports | ✅ | ✅ |
| 10 | `view_task_details` | Détails techniques d'une tâche | ✅ | ✅ |
| 11 | `get_raw_conversation` | Contenu brut d'une conversation | ✅ | ✅ |
| 12 | `analyze_roosync_problems` | Analyse des problèmes RooSync | ✅ | ✅ |

### 1.2 Outils RooSync (20 outils)

| # | Nom de l'outil | Description | Tests unit. | Tests intégr. |
|---|----------------|-------------|-------------|---------------|
| 1 | `roosync_init` | Initialisation RooSync | ✅ | ❌ |
| 2 | `roosync_get_status` | État de synchronisation | ✅ | ❌ |
| 3 | `roosync_compare_config` | Comparaison de configurations | ✅ | ✅ |
| 4 | `roosync_list_diffs` | Liste des différences | ✅ | ❌ |
| 5 | `roosync_decision` | CONS-5: Workflow de décision | ✅ | ✅ |
| 6 | `roosync_decision_info` | CONS-5: Infos de décision | ✅ | ❌ |
| 7 | `roosync_baseline` | CONS-4: Gestion des baselines | ✅ | ✅ |
| 8 | `roosync_config` | CONS-3: Gestion de configuration | ✅ | ✅ |
| 9 | `roosync_inventory` | CONS-6: Inventaire machine | ✅ | ✅ |
| 10 | `roosync_machines` | CONS-6: Machines offline/warning | ✅ | ❌ |
| 11 | `roosync_heartbeat` | CONS-#443 G1: Heartbeat unifié | ✅ | ✅ |
| 12 | `roosync_mcp_management` | CONS-#443 G3: Gestion MCP | ✅ | ✅ |
| 13 | `roosync_storage_management` | CONS-#443 G4: Gestion stockage | ✅ | ❌ |
| 14 | `roosync_diagnose` | CONS-#443 G5: Diagnostic | ✅ | ✅ |
| 15 | `roosync_refresh_dashboard` | Rafraîchissement dashboard | ✅ | ✅ |
| 16 | `roosync_update_dashboard` | Mise à jour dashboard | ✅ | ✅ |
| 17 | `roosync_send` | CONS-1: Envoi de messages | ✅ | ❌ |
| 18 | `roosync_read` | CONS-1: Lecture des messages | ✅ | ✅ |
| 19 | `roosync_manage` | CONS-1: Gestion des messages | ✅ | ✅ |
| 20 | `roosync_cleanup_messages` | #613 ISS-1: Cleanup en masse | ✅ | ❌ |

---

## 2. Analyse de la Couverture

### 2.1 Outils AVEC tests d'intégration (22/32 = 69%)

Ces outils ont une couverture d'intégration validant l'interaction avec le filesystem/réseau :

- ✅ `conversation_browser`
- ✅ `task_export`
- ✅ `roosync_search`
- ✅ `read_vscode_logs`
- ✅ `export_data`
- ✅ `export_config`
- ✅ `view_task_details`
- ✅ `get_raw_conversation`
- ✅ `analyze_roosync_problems`
- ✅ `roosync_compare_config`
- ✅ `roosync_decision`
- ✅ `roosync_baseline`
- ✅ `roosync_config`
- ✅ `roosync_inventory`
- ✅ `roosync_heartbeat`
- ✅ `roosync_mcp_management`
- ✅ `roosync_diagnose`
- ✅ `roosync_refresh_dashboard`
- ✅ `roosync_update_dashboard`
- ✅ `roosync_read`
- ✅ `roosync_manage`

### 2.2 Outils SANS tests d'intégration (10/32 = 31%)

**⚠️ Ces outils sont à risque de bugs silencieux comme #562 :**

| Outil | Risque | Priorité |
|-------|--------|----------|
| `roosync_indexing` | Moyen - Interaction Qdrant | Haute |
| `codebase_search` | Moyen - Indexation code | Haute |
| `get_mcp_best_practices` | Bas - Pas de données dynamiques | Basse |
| `roosync_init` | Moyen - Création fichiers | Moyenne |
| `roosync_get_status` | Haut - Lecture GDrive/état | Haute |
| `roosync_list_diffs` | Moyen - Comparaison configs | Moyenne |
| `roosync_decision_info` | Bas - Lecture seule | Basse |
| `roosync_machines` | Moyen - Heartbeat monitoring | Moyenne |
| `roosync_storage_management` | Haut - Opérations disque | Haute |
| `roosync_send` | Haut - Écriture GDrive | Haute |
| `roosync_cleanup_messages` | Moyen - Opérations bulk | Moyenne |

---

## 3. Classification des Tests

### 3.1 Tests unitaires (120 fichiers)

Tests validant le comportement interne des outils avec mocks :
- Validation des schémas d'entrée
- Formatage des résultats
- Logique métier isolée
- Gestion des erreurs

### 3.2 Tests d'intégration (34 fichiers)

Tests validant l'interaction avec les systèmes externes :
- **Filesystem** : Lecture/écriture des tâches, cache
- **GDrive** : Synchronisation RooSync
- **Qdrant** : Recherche sémantique
- **VS Code** : Logs, configuration

---

## 4. Lacunes Identifiées

### 4.1 Bugs Silencieux Potentiels (Pattern #562)

Les outils suivants pourraient retourner des données partielles/stale sans erreur :

1. **`roosync_get_status`** : Si le cache n'est pas invalidé, peut retourner un état obsolète
2. **`roosync_storage_management`** : Opérations disque sans vérification de fraîcheur
3. **`roosync_send`** : Écriture GDrive sans confirmation de synchronisation
4. **`codebase_search`** : Index code peut être désynchronisé du filesystem

### 4.2 Tests Manquants par Catégorie

| Catégorie | Tests manquants |
|-----------|-----------------|
| **Cache stale** | Aucun outil n'a de test vérifiant que le cache n'empêche pas de voir les nouvelles données |
| **Concurrence** | Seulement 1 test (`concurrent-send.test.ts`) pour les opérations parallèles |
| **Edge cases GDrive** | Tests d'intégration GDrive exclus de CI (`vitest.config.ci.ts`) |

---

## 5. Recommandations Phase 2

### 5.1 Priorité Haute - Tests de fumée immédiats

Pour chaque outil SANS test d'intégration, créer un test de fumée :

```typescript
// Pattern de test de fumée
describe('SMOKE: roosync_get_status', () => {
  it('should return fresh data after cache invalidation', async () => {
    // 1. Appel initial
    const result1 = await roosyncGetStatus({});
    // 2. Modifier l'état (créer un fichier, etc.)
    // 3. Invalider le cache
    // 4. Appel suivant
    const result2 = await roosyncGetStatus({});
    // 5. Vérifier que result2 reflète le changement
    expect(result2).not.toEqual(result1);
  });
});
```

### 5.2 Tests de données stale (CRITIQUE)

Ajouter pour TOUS les outils avec cache :

```typescript
it('should detect stale cache and refresh from disk', async () => {
  // Ce test aurait attrapé le bug #562
});
```

### 5.3 Outils à auditer en priorité

1. `conversation_browser` - Déjà eu des bugs (commit 96014f99)
2. `roosync_get_status` - Central pour la coordination
3. `roosync_storage_management` - Opérations disque critiques
4. `codebase_search` - Indexation peut dériver

---

## 6. Métriques de Suivi

| Métrique | Actuel | Cible Phase 2 |
|----------|--------|---------------|
| Outils avec tests intégration | 69% (22/32) | 100% (32/32) |
| Outils avec tests stale cache | 0% (0/32) | 100% (32/32) |
| Ratio tests intégration/unitaires | 22% | 35% |

---

## 7. Prochaines Étapes

- [ ] **Phase 2** : Tests de fumée sur toutes les machines
- [ ] Créer les tests d'intégration manquants (10 outils)
- [ ] Ajouter tests de données stale pour tous les outils avec cache
- [ ] Intégrer tests de fumée dans le CI

---

*Rapport généré par Roo Code - Issue #564 Phase 1*
