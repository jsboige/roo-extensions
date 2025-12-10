# 🚀 VENTILATION IMMÉDIATE AUX AGENTS
**Date :** 2025-11-13 00:55:12  
**Urgence :** CRITIQUE - Mission RooSync bloquée

---

## 📊 ÉTAT ACTUEL DES TESTS
- **68 tests échoués / 665 total** (82.7% de réussite)
- **RooSync Core :** 12/68 échecs (priorité CRITIQUE)
- **Vector Validation :** 10/68 échecs (priorité HAUTE)
- **Hierarchy Engine :** 8/68 échecs (priorité MOYENNE)
- **Utils & Outils :** 8/68 échecs (priorité FAIBLE)

---

## 🎯 AFFECTATION IMMÉDIATE

### **🔥 AGENT 1 : myia-po-2023** - **ROOSYNC CORE (CRITIQUE)**
**Mission :** Débloquer le cœur fonctionnel RooSync

#### **TÂCHES JOUR 1 (IMMÉDIAT) :**
1. **CRÉER FICHIER MANQUANT :**
   ```bash
   # Créer le fichier critique
   mkdir -p tests/fixtures/roosync-approve-test
   echo '{"version": "2.1.0", "baseline": "test-machine"}' > tests/fixtures/roosync-approve-test/sync-config.ref.json
   ```

2. **CORRIGER VERSIONS :**
   - Modifier tests attendus de '2.0.0' → '2.1.0'
   - Fichiers : `tests/unit/services/RooSyncService.test.ts`

3. **DIAGNOSTIC CACHE :**
   - Investiger `clearCache()` qui retourne 'synced' au lieu de 'diverged'
   - Fichier : `src/services/RooSyncService.ts`

**DELAI :** 24h maximum  
**CONTACT :** Roo Manager si blocage

---

### **⚡ AGENT 2 : myia-po-2024** - **TASK INDEXING (HAUTE)**
**Mission :** Réparer le système d'indexation vectorielle

#### **TÂCHES JOUR 1 (IMMÉDIAT) :**
1. **DIAGNOSTIC STOCKAGE :**
   - Investiger erreur : `Task ${taskId} not found in any storage location`
   - Vérifier chemins dans `src/services/task-indexer.ts:1049`

2. **CRÉER FIXTURES MANQUANTS :**
   - Tests de validation vectorielle sans données
   - Créer squelettes de test pour les vecteurs

3. **VALIDATION DIMENSIONS :**
   - Tests : dimensions, NaN, Infinity
   - Fichier : `tests/unit/services/task-indexer-vector-validation.test.ts`

**DELAI :** 24h maximum  
**CONTACT :** myia-po-2023 pour coordination RooSync

---

### **🔧 AGENT 3 : myia-po-2026** - **HIERARCHY ENGINE (MOYENNE)**
**Mission :** Reconstruire l'engine de hiérarchie

#### **TÂCHES JOUR 1 (IMMÉDIAT) :**
1. **CORRIGER EXTRACTION :**
   - Fixer : `Cannot read properties of undefined (reading 'includes')`
   - Fichier : `src/services/hierarchy-reconstruction-engine.ts`

2. **DATASET TEST-HIERARCHY :**
   - Reconstruction à 0% au lieu de 100%
   - Vérifier les données de test contrôlées

3. **PROFONDEURS HIÉRARCHIQUES :**
   - Arbre plat (depth=0) au lieu de hiérarchique
   - Fichier : `tests/unit/utils/controlled-hierarchy-reconstruction.test.ts`

**DELAI :** 48h maximum  
**CONTACT :** myia-po-2024 pour intégration vectorielle

---

### **🛠️ AGENT 4 : myia-web-01** - **UTILS & OUTILS (FAIBLE)**
**Mission :** Stabiliser les outils et utilitaires

#### **TÂCHES JOUR 1 (IMMÉDIAT) :**
1. **CRÉER RÉPERTOIRES FIXTURES :**
   ```bash
   mkdir -p tests/fixtures/roosync-list-diffs-test/inventories
   echo '{}' > tests/fixtures/roosync-list-diffs-test/inventories/PC-PRINCIPAL.json
   ```

2. **GET TREE ASCII :**
   - Arbre vide au lieu de contenu hiérarchique
   - Fichier : `src/tools/task/get-tree-ascii.ts`

3. **HOST IDENTIFIER :**
   - Ajouter `host_id` manquant dans résultats de recherche
   - Fichier : `src/tools/search/search-by-content.ts`

**DELAI :** 72h maximum  
**CONTACT :** myia-po-2026 pour intégration hiérarchie

---

## 📋 PROTOCOLE DE DÉMARRAGE

### **POUR CHAQUE AGENT :**
1. **CLONER & BRANCHER :**
   ```bash
   git clone <repo>
   git checkout -b fix/agent-nom-tache-2025-11-13
   ```

2. **INSTALLER :**
   ```bash
   cd mcps/internal/servers/roo-state-manager
   npm install
   ```

3. **TESTER CIBLÉ :**
   ```bash
   # Lancer seulement les tests critiques
   npx vitest run --grep="BaselineService\|RooSyncService\|task-indexer-vector"
   ```

4. **COMMENCER PAR LES FIXES CRITIQUES** listés ci-dessus

---

## 🔄 COORDINATION JOURNALIÈRE

### **SYNC 09:00 CHAQUE JOUR :**
- **myia-po-2023 :** État RooSync Core
- **myia-po-2024 :** État Task Indexing  
- **myia-po-2026 :** État Hierarchy Engine
- **myia-web-01 :** État Utils & Outils

### **POINTS DE BLOCAGE :**
- **Roo Manager :** Coordination générale et déblocage
- **Code Review :** Croisé entre agents après chaque phase
- **Tests Intégration :** Validation commune des fixes

---

## 🎯 OBJECTIFS 24H

### **CRITIQUES (À 100%) :**
- ✅ Fichiers de test manquants créés
- ✅ Tests RooSync qui compilent
- ✅ Diagnostic stockage tâches complété

### **IMPORTANTS (À 50%) :**
- 🔄 Premiers fixes vectoriels appliqués
- 🔄 Extraction hiérarchie fonctionnelle
- 🔄 Outils de base stabilisés

### **VALIDATION FINALE JOUR 1 :**
```bash
npx vitest run --reporter=verbose --grep="BaselineService\|RooSyncService\|task-indexer-vector"
```

---

## 📞 URGENCES & CONTACTS

### **IMMÉDIAT (Si blocage < 2h) :**
1. **Roo Manager** : Coordination et déblocage
2. **myia-po-2023** : Expert RooSync Core
3. **myia-po-2024** : Expert Task Indexing

### **SI PROBLÈMES TECHNIQUES :**
- **Environment :** Vérifier Node.js, npm, accès disque
- **Permissions :** Vérifier droits écriture tests/fixtures/
- **Dépendances :** `npm ls` pour vérifier les packages

---

**Démarrage immédiat recommandé :** Maintenant  
**Premier sync :** 2025-11-13 09:00  
**Rapport de progression :** Fin de journée J1  
**Mission critique :** Débloquer RooSync pour la suite du projet