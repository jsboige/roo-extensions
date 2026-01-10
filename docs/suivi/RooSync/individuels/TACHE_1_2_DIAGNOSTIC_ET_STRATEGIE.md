# Tâche 1.2 - Diagnostic et Stratégie de Stabilisation du MCP roo-state-manager

**Machine :** myia-po-2026  
**Projet GitHub :** #67 "RooSync Multi-Agent Tasks"  
**Priorité :** HIGH  
**Date :** 2026-01-05  
**Agent responsable :** Roo (technique)  
**Agent de support :** Claude Code (documentation/coordination)

---

## 1. État Actuel du MCP sur myia-po-2026

### 1.1 Architecture du MCP roo-state-manager

**Version :** 1.0.14  
**Type :** Module ESM (ECMAScript Modules)  
**Point d'entrée :** `build/index.js`

**Structure modulaire :**
```
roo-state-manager/
├── src/
│   ├── types/           # Interfaces TypeScript
│   ├── utils/           # Utilitaires (détecteur stockage)
│   ├── services/        # Services métier (30+ services)
│   └── tools/           # 42 outils MCP
├── tests/
│   ├── unit/            # Tests unitaires
│   ├── integration/     # Tests d'intégration
│   └── e2e/            # Tests end-to-end
└── package.json
```

**Outils MCP (42 outils organisés en 11 catégories) :**
- Stockage & Détection (2 outils)
- Conversations & Navigation (4 outils)
- Debug & Analyse (3 outils)
- Recherche & Indexation (2 outils)
- Cache & Performance (2 outils)
- Exports XML (4 outils)
- Exports Autres Formats (3 outils)
- Résumés & Synthèse (3 outils)
- Réparation & Maintenance (3 outils)
- Outils VSCode & MCP (5 outils)
- RooSync v2.1 Baseline-Driven (12 outils)

### 1.2 Configuration Actuelle

**Fichier `.env` :**
```env
# Qdrant
QDRANT_URL=https://qdrant.myia.io
QDRANT_API_KEY=<REDACTED>
QDRANT_COLLECTION_NAME=roo_tasks_semantic_index

# OpenAI
OPENAI_API_KEY=<REDACTED>
OPENAI_CHAT_MODEL_ID=gpt-5-mini

# RooSync
ROOSYNC_SHARED_PATH=G:/Mon Drive/Synchronisation/RooSync/.shared-state
ROOSYNC_MACHINE_ID=myia-po-2026
ROOSYNC_AUTO_SYNC=false
ROOSYNC_CONFLICT_STRATEGY=manual
ROOSYNC_LOG_LEVEL=info
```

**Baseline RooSync :**
- Fichier : `config/baselines/sync-config.ref.json`
- Machine ID : myia-po-2026
- Timestamp : 2025-11-28T14:00:00Z

### 1.3 Scripts de Build et Tests

**Build :**
```bash
npm run build          # Compilation TypeScript (tsc)
npm run dev            # Watch mode
```

**Tests :**
```bash
npm test               # Vitest
npm run test:unit      # Tests unitaires
npm run test:integration # Tests d'intégration
npm run test:e2e       # Tests end-to-end
```

---

## 2. Problèmes Identifiés

### 2.1 Problèmes Critiques (URGENT)

#### 2.1.1 Parsing XML
**Source :** Rapport d'analyse `2025-11-30_RAPPORT-CYCLE2-ANALYSE.md`

**Problème :**
- Erreurs de parsing XML dans les utilitaires
- Problèmes de normalisation HTML entities
- Array format et Truncation incorrects

**Impact :**
- 15 erreurs liées au parsing XML
- Fonctionnalité centrale affectée

**Fichiers concernés :**
- `src/services/reporting/strategies/NoResultsReportingStrategy.ts`
- `src/types/enhanced-conversation.ts`
- `src/services/trace-summary/ContentClassifier.ts`

#### 2.1.2 Hierarchy Pipeline
**Source :** Tests unitaires `hierarchy-pipeline.test.ts`

**Problème :**
- Normalisation HTML entities incorrecte
- Résolution stricte de hiérarchie défaillante
- Gestion des préfixes problématique

**Impact :**
- 4 erreurs dans les tests
- Reconstruction hiérarchique incorrecte

**Fichiers concernés :**
- `tests/unit/services/hierarchy-pipeline.test.ts`
- `src/services/hierarchy/HierarchyPipeline.ts`

### 2.2 Problèmes Importants (HAUT)

#### 2.2.1 Tests d'Intégration
**Source :** `tests/integration/hierarchy-real-data.test.ts`

**Problème :**
- Taux de reconstruction incorrect (16% vs 100% attendu)
- Profondeur de hiérarchie incorrecte

**Impact :**
- 2 erreurs dans les tests
- Validation sur données réelles échoue

#### 2.2.2 Tests E2E
**Source :** `tests/e2e/synthesis.e2e.test.ts`

**Problème :**
- Modèles LLM incorrects (`gpt-5-mini` vs `gpt-4o-mini`)
- Versions incorrectes dans les attentes

**Impact :**
- 2 erreurs dans les tests
- Tests de synthèse non validés

### 2.3 Problèmes Modérés (MOYEN)

#### 2.3.1 Task Tree Integration
**Source :** `tests/integration/task-tree-integration.test.js`

**Problème :**
- `analyze relationships` échoue

**Impact :**
- 1 erreur dans les tests
- Intégration arbre des tâches défaillante

#### 2.3.2 Message Extraction Coordinator
**Source :** `tests/unit/utils/message-extraction-coordinator.test.ts`

**Problème :**
- Nombre d'extracteurs incorrect (7 vs 6 attendus)

**Impact :**
- 1 erreur dans les tests
- Coordination d'extraction défaillante

---

## 3. Stratégie de Stabilisation

### 3.1 Phase 1 : Diagnostic Approfondi (30 min)

**Objectif :** Valider l'état actuel du MCP

**Actions :**
1. ✅ Analyser l'architecture du MCP (Semantic Grounding)
2. ⏳ Vérifier la configuration `.env`
3. ⏳ Tester les outils MCP critiques
4. ⏳ Exécuter les tests unitaires
5. ⏳ Identifier les erreurs de parsing XML

**Critères de succès :**
- Configuration `.env` valide
- Outils MCP critiques fonctionnels
- Liste complète des erreurs identifiées

### 3.2 Phase 2 : Correction des Problèmes Critiques (2h)

**Objectif :** Résoudre les problèmes bloquants

**Actions :**
1. ⏳ Corriger le parsing XML
   - Normaliser les HTML entities
   - Corriger l'Array format
   - Corriger la Truncation
2. ⏳ Corriger le Hierarchy Pipeline
   - Normaliser les HTML entities
   - Corriger la résolution stricte
   - Corriger la gestion des préfixes
3. ⏳ Valider les corrections avec les tests

**Critères de succès :**
- Tests `hierarchy-pipeline.test.ts` passent
- Parsing XML fonctionnel
- 0 erreur critique

### 3.3 Phase 3 : Correction des Problèmes Importants (1h)

**Objectif :** Résoudre les problèmes non bloquants

**Actions :**
1. ⏳ Corriger les tests d'intégration
   - Taux de reconstruction
   - Profondeur de hiérarchie
2. ⏳ Corriger les tests E2E
   - Modèles LLM
   - Versions
3. ⏳ Valider les corrections

**Critères de succès :**
- Tests d'intégration passent
- Tests E2E passent
- 0 erreur importante

### 3.4 Phase 4 : Validation Finale (30 min)

**Objectif :** Valider la stabilité globale

**Actions :**
1. ⏳ Exécuter tous les tests
2. ⏳ Valider les outils MCP
3. ⏳ Vérifier la configuration RooSync
4. ⏳ Documenter les changements

**Critères de succès :**
- Tous les tests passent
- Outils MCP fonctionnels
- Configuration RooSync valide

---

## 4. Tests à Effectuer

### 4.1 Tests Unitaires

```bash
# Tests de parsing XML
npm run test:unit -- hierarchy-pipeline.test.ts

# Tests de hiérarchie
npm run test:unit -- hierarchy-reconstruction-engine.test.ts

# Tests de reporting
npm run test:unit -- NoResultsReportingStrategy.test.ts
```

### 4.2 Tests d'Intégration

```bash
# Tests de hiérarchie sur données réelles
npm run test:integration -- hierarchy-real-data.test.ts

# Tests d'intégration arbre des tâches
npm run test:integration -- task-tree-integration.test.js
```

### 4.3 Tests E2E

```bash
# Tests de synthèse
npm run test:e2e -- synthesis.e2e.test.ts

# Tests RooSync
npm run test:e2e -- roosync-workflow.test.ts
```

### 4.4 Tests MCP

```bash
# Test des outils MCP critiques
node tests/manual/test-mcp-tools.js

# Test de la configuration RooSync
node tests/manual/test-roosync-config.js
```

---

## 5. Plan d'Action

### 5.1 Actions Immédiates (Aujourd'hui)

1. ✅ **Semantic Grounding** - Analyse de l'architecture
2. ⏳ **Documentation** - Création de ce document
3. ⏳ **GitHub** - Conversion du draft en issue
4. ⏳ **Diagnostic** - Exécution des tests
5. ⏳ **Correction** - Résolution des problèmes critiques

### 5.2 Actions Suivantes (Demain)

1. ⏳ **Correction** - Résolution des problèmes importants
2. ⏳ **Validation** - Tests complets
3. ⏳ **Git** - Commit et push
4. ⏳ **Communication** - Message RooSync et INTERCOM

### 5.3 Actions de Suivi (Cette semaine)

1. ⏳ **Monitoring** - Surveillance des erreurs
2. ⏳ **Documentation** - Mise à jour des guides
3. ⏳ **Optimisation** - Amélioration des performances

---

## 6. Risques et Mitigations

### 6.1 Risques Identifiés

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|---------|------------|
| Parsing XML complexe | Élevée | Critique | Tests unitaires approfondis |
| Dépendances externes (Qdrant, OpenAI) | Moyenne | Élevée | Mocking dans les tests |
| Configuration RooSync | Faible | Critique | Validation automatique |
| Performance des tests | Moyenne | Moyenne | Optimisation du cache |

### 6.2 Plan de Contingence

**Si les corrections prennent plus de temps que prévu :**
1. Prioriser les problèmes critiques
2. Documenter les problèmes non résolus
3. Créer des issues GitHub pour le suivi

**Si les tests échouent après correction :**
1. Revenir à la version précédente
2. Analyser les logs d'erreur
3. Consulter Claude Code via INTERCOM

---

## 7. Métriques de Succès

### 7.1 Métriques Techniques

| Métrique | Valeur Actuelle | Objectif | Statut |
|----------|-----------------|----------|---------|
| Tests unitaires passants | ? | 100% | ⏳ À mesurer |
| Tests d'intégration passants | ? | 100% | ⏳ À mesurer |
| Tests E2E passants | ? | 100% | ⏳ À mesurer |
| Outils MCP fonctionnels | ? | 42/42 | ⏳ À mesurer |
| Erreurs parsing XML | 15 | 0 | ⏳ À corriger |

### 7.2 Métriques de Processus

| Métrique | Objectif | Statut |
|----------|----------|---------|
| Temps de stabilisation | < 4h | ⏳ En cours |
| Documentation complète | 100% | ✅ Ce document |
| Communication GitHub | 100% | ⏳ À faire |
| Communication RooSync | 100% | ⏳ À faire |

---

## 8. Conclusion

Le MCP roo-state-manager sur myia-po-2026 présente des problèmes identifiés dans les domaines suivants :

1. **Parsing XML** - Problème critique affectant 15 tests
2. **Hierarchy Pipeline** - Problème important affectant 4 tests
3. **Tests d'intégration** - Problème important affectant 2 tests
4. **Tests E2E** - Problème modéré affectant 2 tests

La stratégie de stabilisation proposée en 4 phases permet de résoudre ces problèmes de manière structurée et priorisée. Les corrections seront validées par des tests unitaires, d'intégration et E2E.

**Prochaine étape :** Exécuter les tests pour valider l'état actuel et commencer les corrections.

---

**Document créé le :** 2026-01-05  
**Dernière mise à jour :** 2026-01-05  
**Statut :** En cours
