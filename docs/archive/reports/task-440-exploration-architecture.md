# Tâche #440 - Exploration Architecture Listage/Affichage Tâches

**Date :** 2026-02-11
**Machine :** myia-po-2025
**Agent :** Claude Code (Opus 4.6)
**Statut :** EN COURS

---

## 📋 Contexte

Tâche exploratoire pour évaluer les outils de listage et affichage des tâches/conversations. L'architecture a été développée de manière itérative et laborieuse avec une intention ambitieuse :
- Raccrocher ensemble les grappes et clusters de tâches
- Différentier le traitement : **messages** (conservés) vs **outils/résultats** (filtrés/tronqués)
- Compacification optimale

**Problème :** Une partie de l'intention originale s'est potentiellement perdue lors de refactoring et MAJ API Roo.

---

## 🏗️ Architecture Actuelle - Vue d'Ensemble

### 3 Outils Principaux

| Outil | Type | Rôle | Consolidation |
|-------|------|------|---------------|
| **`task_browse`** | Navigation | Arbre hiérarchique parent-enfant | CONS-9 (2→1) |
| **`view_conversation_tree`** | Visualisation | Affichage structuré avec troncature intelligente | Standalone |
| **`roosync_summarize`** | Documentation | Génération rapports/synthèses | CONS-12 (3→1) |

---

## 🔍 Analyse Détaillée

### 1. `task_browse` (CONS-9)

**Fichier :** `src/tools/task/browse.ts`
**Consolidation :** `get_task_tree` + `get_current_task` → `task_browse`

**Actions disponibles :**
- **`action: 'tree'`** → Arbre hiérarchique des tâches (délègue à `handleGetTaskTree`)
- **`action: 'current'`** → Tâche actuellement active (délègue à `getCurrentTaskTool`)

**Paramètres clés (action='tree') :**
```typescript
{
  conversation_id: string,        // ID conversation (requis)
  max_depth?: number,             // Profondeur max arbre
  include_siblings?: boolean,     // Inclure tâches sœurs (défaut: true)
  output_format?: 'json' | 'markdown' | 'ascii-tree' | 'hierarchical',
  current_task_id?: string,       // Marquer tâche actuelle
  truncate_instruction?: number,  // Troncature instruction (défaut: 80)
  show_metadata?: boolean         // Métadonnées détaillées (défaut: false)
}
```

**Intention originale (juillet 2025) :**
Proposée dans `docs/mcp/roo-state-manager/features/task-tree-navigation.md` :
- 3 méthodes : `get_task_parent`, `get_task_children`, `get_task_tree`
- Besoin de modifier `roo-code` pour persister filiation dans `task_metadata.json`
- 901+ tâches sans info de filiation → stratégie heuristique (workspace, proximité temporelle)

**Validation (décembre 2025) :**
Document `docs/architecture/task-hierarchy-analysis-20251203.md` confirme :
- ✅ Bug affichage tronqué corrigé
- ✅ Test sur grappe complexe : 69 tâches, 4 niveaux
- ✅ `get_task_tree` fiable et robuste
- 📊 Statistiques : 5% tâches avec enfants, 95% orphelines (usage "one-shot")

---

### 2. `view_conversation_tree`

**Fichier :** `src/tools/view-conversation-tree.ts`
**Rôle :** Visualisation structurée avec compacification intelligente

**3 Modes d'affichage :**

| Mode | Logique | Usage |
|------|---------|-------|
| **`single`** | Juste la tâche demandée | Consultation isolée |
| **`chain`** | Chaîne parent → enfant (récursif) | Traçabilité linéaire |
| **`cluster`** | Parent + tous ses enfants (siblings) | Vision grappe |

**3 Niveaux de détail :**

| Niveau | Messages | Actions | Usage |
|--------|----------|---------|-------|
| **`skeleton`** | Tronqués (3 lignes) | Nom + statut + timestamp | Navigation rapide |
| **`summary`** | Tronqués (10 lignes) | + Params tronqués | Exploration moyenne |
| **`full`** | Complets | + Params complets + sizes | Investigation profonde |

**Innovation majeure : Smart Truncation (ligne 220-227)**
```typescript
if (args.smart_truncation === true) {
    // ✨ NOUVEAU : Algorithme de troncature intelligente avec gradient
    return handleSmartTruncationAsync(...);
} else {
    // 🔄 LEGACY : Comportement original préservé (par défaut)
    return handleLegacyTruncationAsync(...);
}
```

**Paramètres smart truncation :**
```typescript
{
  smart_truncation?: boolean,             // Activer algo gradient
  smart_truncation_config?: {
    gradientStrength?: number,            // Force gradient (défaut: 2.0)
    maxTruncationRate?: number,           // Taux max centre (défaut: 0.7)
    minPreservationRate?: number          // Taux min extrêmes (défaut: 0.9)
  },
  max_output_length?: number              // Limite sortie (défaut: 300K)
}
```

**Différentiation traitement (INTENTION ORIGINALE PRÉSENTE) :**
- **Messages user/assistant** (lignes 129-133) : Conservés avec troncature configurable
- **Actions/outils** (lignes 134-167) : Filtrage selon `detail_level`
  - `skeleton` : Métadonnées seulement
  - `summary` : Params tronqués
  - `full` : Params complets

**Auto-détection tâche courante :**
- Priorité 1 : `current_task_id` explicite (fiable)
- Priorité 2 : Auto-détection par `lastActivity` (peu fiable car tâche en cours non encore timestampée)

---

### 3. `roosync_summarize` (CONS-12)

**Fichier :** `src/tools/summary/roosync-summarize.tool.ts`
**Consolidation :** 3→1 outils
- `generate_trace_summary` → **`type: 'trace'`**
- `generate_cluster_summary` → **`type: 'cluster'`**
- `get_conversation_synthesis` → **`type: 'synthesis'`**

**3 Types d'opération :**

| Type | Handler | Output | Usage |
|------|---------|--------|-------|
| **`trace`** | `handleGenerateTraceSummary` | markdown/html | Rapport simple conversation |
| **`cluster`** | `handleGenerateClusterSummary` | markdown/html | Rapport grappe multi-tâches |
| **`synthesis`** | `handleGetConversationSynthesis` | json/markdown | Synthèse LLM sémantique |

**Support multi-source :**
```typescript
source?: 'roo' | 'claude'  // Roo Code (défaut) ou Claude Code
```

**Paramètres avancés cluster :**
```typescript
{
  clusterMode?: 'aggregated' | 'detailed' | 'comparative',
  includeClusterStats?: boolean,
  crossTaskAnalysis?: boolean,
  maxClusterDepth?: number,
  clusterSortBy?: 'chronological' | 'size' | 'activity' | 'alphabetical',
  includeClusterTimeline?: boolean,
  clusterTruncationChars?: number,
  showTaskRelationships?: boolean
}
```

---

## 🎯 Différences Clés entre Outils

### `task_browse` vs `view_conversation_tree`

| Aspect | `task_browse` (tree) | `view_conversation_tree` |
|--------|---------------------|--------------------------|
| **Focus** | Hiérarchie parent-enfant | Affichage conversationnel |
| **Format** | json, markdown, ascii-tree, hierarchical | Texte structuré avec emojis |
| **Modes** | 1 seul (arbre) | 3 modes (single/chain/cluster) |
| **Détail** | 1 niveau (metadata on/off) | 3 niveaux (skeleton/summary/full) |
| **Troncature** | Instruction seulement | Smart truncation avec gradient |
| **Usage** | Navigation structurelle | Exploration conversationnelle |

### `view_conversation_tree` vs `roosync_summarize`

| Aspect | `view_conversation_tree` | `roosync_summarize` |
|--------|--------------------------|---------------------|
| **Objectif** | Affichage interactif | Génération rapports |
| **Output** | Texte structuré inline | Fichiers markdown/html/json |
| **Cluster** | Mode cluster intégré | Type cluster dédié |
| **Synthèse LLM** | ❌ Non | ✅ Oui (type: synthesis) |
| **CSS embarqué** | ❌ Non | ✅ Oui (pour HTML) |
| **TOC** | ❌ Non | ✅ Oui (generateToc) |
| **Usage** | Exploration temps réel | Documentation/archivage |

---

## 🔄 Évolution Historique

### Juillet 2025 - Proposition Initiale
- Document : `task-tree-navigation.md`
- **Intention :** Gestion relations parent-enfant persistées
- **Problème :** Filiation en mémoire, pas dans `task_metadata.json`
- **Solution proposée :** Modifier `roo-code` pour ajouter `parentTaskId` + `rootTaskId`
- **Contournement :** Heuristique (workspace, proximité temporelle, sémantique)

### Décembre 2025 - Validation Implémentation
- Document : `task-hierarchy-analysis-20251203.md`
- **Résultat :** Bug affichage tronqué résolu
- **Test complexe :** Tâche `18141742` → 69 tâches, 4 niveaux
- **Conclusion :** Moteur de reconstruction robuste et fiable

### 2025-2026 - Consolidations
- **CONS-9 :** `get_task_tree` + `get_current_task` → `task_browse` (2→1)
- **CONS-12 :** 3 outils summary → `roosync_summarize` (3→1)
- **Innovation :** Smart truncation avec gradient dans `view_conversation_tree`

---

## 💡 État de l'Intention Originale

### ✅ Réalisé

1. **Grappes et clusters** :
   - ✅ `view_conversation_tree` mode `cluster` (parent + siblings)
   - ✅ `roosync_summarize` type `cluster` avec modes avancés
   - ✅ Relations parent-enfant reconstruites (heuristique efficace)

2. **Différentiation traitement** :
   - ✅ **Messages conservés** avec troncature configurable
   - ✅ **Outils/résultats filtrés** selon niveau de détail (skeleton/summary/full)
   - ✅ Distinction claire dans `view_conversation_tree` (lignes 129-167)

3. **Compacification optimale** :
   - ✅ Smart truncation avec gradient (innovation majeure)
   - ✅ Estimation taille sortie (ligne 173-186)
   - ✅ Limite `max_output_length` (défaut 300K)
   - ✅ Troncature paramétrable par niveau

### ⚠️ Potentiellement Perdu/Incomplet

1. **Analyse sémantique pour filiation** :
   - 📝 Mentionnée dans proposition juillet 2025 (ligne 39)
   - ❓ Implémentation actuelle basée sur métadonnées + timestamps
   - ❓ Pas d'embeddings visibles dans le code actuel

2. **Persistance filiation dans `roo-code`** :
   - 📝 Recommandation stratégique (lignes 24-32 de task-tree-navigation.md)
   - ❓ Statut inconnu - nécessite vérification dans `roo-code`
   - 📊 Statistiques montrent 95% tâches orphelines (usage one-shot dominant)

3. **Raccordement grappes entre elles** :
   - ❓ Intention originale peut-être plus ambitieuse ?
   - ✅ Actuellement : cluster = parent + enfants directs
   - ❓ Vision originale : graphe complet de grappes interconnectées ?

---

## 🧪 Tests à Effectuer (Prochaine Phase)

### 1. `task_browse` (action: 'tree')
- [ ] Tester sur conversation avec sous-tâches multiples
- [ ] Vérifier formats de sortie (json, markdown, ascii-tree, hierarchical)
- [ ] Tester `include_siblings: true/false`
- [ ] Valider marquage `current_task_id`

### 2. `view_conversation_tree`
- [ ] Tester les 3 modes (single, chain, cluster) sur grappe complexe
- [ ] Comparer les 3 niveaux de détail (skeleton, summary, full)
- [ ] Activer `smart_truncation: true` et comparer avec legacy
- [ ] Tester auto-détection tâche courante

### 3. `roosync_summarize`
- [ ] Générer rapport `type: 'trace'` (markdown + html)
- [ ] Générer rapport `type: 'cluster'` avec modes (aggregated, detailed, comparative)
- [ ] Tester `type: 'synthesis'` (synthèse LLM)
- [ ] Vérifier support `source: 'claude'` vs `source: 'roo'`

---

## 📊 Métriques à Collecter

- Temps d'exécution par outil sur grappe 50+ tâches
- Taille sortie vs `max_output_length` avec smart truncation
- Précision auto-détection filiation (heuristique vs réalité)
- Différence taille legacy vs smart truncation

---

**Prochaine étape :** Phase de tests pratiques avec collecte métriques.

---

## ✅ PHASE 2 - RÉSULTATS DES TESTS PRATIQUES

**Date :** 2026-02-11 22:00
**Machine :** myia-po-2025
**Agent :** Claude Code (Opus 4.6)

### Tests Effectués

#### 1. `task_browse` (action: 'tree')

**Test :** Conversation simple sans sous-tâches (`5d775623-2561-4d83-a0e7-65278c1ce9d1`)

**Résultat :**
```
# Arbre de Tâches - 2026-02-11 21:47:25

**Conversation ID:** 5d775623
**Profondeur max:** 5
**Inclure siblings:** Oui
**Racine:** Task 5d775623

---

5d775623-2561-4d83-a0e7-65278c1ce9d1 - Task 5d775623 ⏳

---

**Statistiques:**
- Nombre total de tâches: 1
- Profondeur maximale atteinte: 0
- Généré le: 2026-02-11T21:47:25.377Z
```

**✅ Verdict :** Fonctionne correctement
- Format `ascii-tree` lisible et structuré
- Paramètres (`max_depth`, `include_siblings`) respectés
- Statistiques utiles en fin de rapport

---

#### 2. `view_conversation_tree` (modes et smart truncation)

**Test 1 :** Mode `single`, détail `skeleton`, troncature legacy (`truncate: 3`)

**Résultat :**
- **Volume de sortie :** ~76K tokens pour 82 messages (930 tokens/message)
- **Format :** Markdown structuré avec emojis (👤 User, 🤖 Assistant)
- **Troncature :** Fonctionne (lignes tronquées visibles avec `[...]`)

**⚠️ Problème :** Volume de sortie ÉNORME même pour conversation courante (82 messages → 76K tokens)

---

**Test 2 :** Mode `single`, détail `skeleton`, smart truncation activée

**Paramètres testés :**
1. `smart_truncation: true`, `max_output_length: 10000` (défaut)
2. `smart_truncation: true`, `max_output_length: 10000`, config aggressive (`gradientStrength: 3, maxTruncationRate: 0.9`)

**Résultat (les 2 tests) :**
```
🔍 Smart Truncation Diagnostics:
  • Taille totale: 36431 chars, Limite: 10000, Surplus: 26431
  • Compression: 0.0%, Taille finale: 36431
```

**❌ BUG CRITIQUE DÉTECTÉ :**
- **Smart truncation ne compresse RIEN** (0.0% compression)
- Limite `max_output_length` **totalement ignorée**
- Sortie 36K chars alors que limite était 10K chars (surplus détecté mais pas appliqué)
- Paramètres agressifs sans effet

**Impact :** L'outil est **inutilisable en pratique** pour conversations volumineuses (>50 messages)

---

#### 3. `roosync_summarize` (export markdown)

**Test :** Type `trace` avec export markdown, source Claude Code

**Résultat :**
```
Error: Conversation avec taskId 5d775623-2561-4d83-a0e7-65278c1ce9d1 introuvable
```

**⚠️ Limitation :** `roosync_summarize` avec `source: 'claude'` **ne fonctionne pas**
- L'outil semble uniquement compatible avec les conversations Roo Code
- Les conversations Claude Code ne sont pas indexées/accessibles
- Documentation incorrecte (mentionne support `source: 'claude'`)

---

### 🐛 BUGS ET PROBLÈMES CRITIQUES

| # | Outil | Problème | Sévérité |
|---|-------|----------|----------|
| **1** | `view_conversation_tree` | **Smart truncation ne fonctionne pas** (0% compression) | 🔴 CRITIQUE |
| **2** | `view_conversation_tree` | Volume de sortie énorme (76K tokens pour 82 messages) | 🟠 MAJEUR |
| **3** | `roosync_summarize` | `source: 'claude'` non fonctionnel (conversations Claude Code introuvables) | 🟠 MAJEUR |
| **4** | `view_conversation_tree` | `max_output_length` ignoré par smart truncation | 🔴 CRITIQUE |
| **5** | Documentation | Doc mentionne support `source: 'claude'` mais ne fonctionne pas | 🟡 MINEUR |

---

### 💡 AMÉLIORATIONS PRIORITAIRES

#### P0 - Critique (Bloquants pour usage quotidien)

1. **Réparer smart truncation** (view-conversation-tree.ts (`../mcps/internal/servers/roo-state-manager/src/tools/view-conversation-tree.ts`))
   - **Cause probable :** Bug dans `handleSmartTruncationAsync` (lignes 220-227)
   - **Test requis :** Vérifier l'algorithme de gradient (fonction `applyGradientTruncation`)
   - **Workaround temporaire :** Désactiver smart truncation par défaut et forcer troncature legacy

2. **Réduire volume de sortie de `view_conversation_tree`**
   - Actuellement : 930 tokens/message en mode `skeleton` → **INACCEPTABLE**
   - Objectif : <100 tokens/message en mode `skeleton`
   - **Solution :** Filtrage plus agressif des métadonnées en mode skeleton

#### P1 - Important (Usage quotidien limité)

3. **Fixer support `source: 'claude'` dans `roosync_summarize`**
   - Soit implémenter réellement le support Claude Code
   - Soit retirer de la documentation et des paramètres

4. **Ajouter mode "ultra-compact" pour `view_conversation_tree`**
   - Détail : `ultra-skeleton` → uniquement timestamps + speakers + résumé 1 ligne
   - Usage : Quick scan rapide d'une conversation longue

#### P2 - Nice-to-have (Amélioration UX)

5. **Consolidation export markdown**
   - Actuellement : `view_conversation_tree` (texte inline) + `roosync_summarize` (fichiers markdown séparés)
   - Proposition : Ajouter `filePath` optionnel à `view_conversation_tree` pour export direct

6. **Auto-détection workspace dans `task_browse`**
   - Actuellement : Erreur si workspace non fourni
   - Proposition : Détecter automatiquement depuis chemin conversation

---

### 📋 OPPORTUNITÉS DE CONSOLIDATION

#### Analyse Redondance

| Fonctionnalité | `task_browse` | `view_conversation_tree` | `roosync_summarize` |
|----------------|---------------|--------------------------|---------------------|
| **Arbre hiérarchique** | ✅ (action: tree) | ✅ (mode: chain/cluster) | ✅ (type: cluster) |
| **Export fichier** | ❌ | ❌ (inline seulement) | ✅ (markdown/html/json) |
| **TOC génération** | ❌ | ❌ | ✅ (generateToc) |
| **Troncature intelligente** | ❌ (instruction seulement) | ✅ (bugué) | ✅ (truncationChars) |
| **Niveaux de détail** | show_metadata on/off | 3 niveaux (skeleton/summary/full) | 6 niveaux (detailLevel) |
| **Support Claude Code** | ❌ (Roo uniquement?) | ❌ (test non concluant) | ❌ (error confirmed) |

**Proposition CONS-X :** Unifier ces 3 outils en un seul outil `conversation_browser`

**Bénéfices :**
- Interface unifiée pour navigation + visualisation + export
- Réduction de 3 outils → 1 (simplification maintenance)
- Résolution des bugs de smart truncation en refactorisant
- Support unifié Roo + Claude Code

**Structure proposée :**
```typescript
interface ConversationBrowserArgs {
  taskId: string;
  source: 'roo' | 'claude';  // Source de données

  // Navigation
  mode?: 'single' | 'chain' | 'cluster' | 'tree';

  // Visualisation
  detailLevel?: 'ultra-skeleton' | 'skeleton' | 'summary' | 'full';
  truncationMode?: 'none' | 'fixed' | 'smart';
  truncationChars?: number;

  // Export (optionnel)
  export?: {
    filePath: string;
    format: 'markdown' | 'html' | 'json';
    includeToc?: boolean;
    includeCss?: boolean;
  };
}
```

---

### 🎯 RECOMMANDATIONS FINALES

**Pour usage immédiat (workarounds) :**

1. **NE PAS utiliser smart truncation** (bugué) → `smart_truncation: false`
2. **Limiter à conversations courtes** (<30 messages) pour `view_conversation_tree`
3. **Utiliser `task_browse` pour navigation structurelle** (fonctionne bien)
4. **NE PAS utiliser `roosync_summarize` avec Claude Code** (non supporté)

**Pour corrections prioritaires (P0) :**

1. **Réparer smart truncation** ou le désactiver complètement
2. **Réduire drastiquement volume de sortie** en mode skeleton (objectif: <100 tokens/msg)

**Pour évolution (P1-P2) :**

1. **Consolider les 3 outils** en un seul `conversation_browser` unifié
2. **Implémenter support réel Claude Code** ou retirer de la doc
3. **Ajouter mode ultra-compact** pour quick scan

---

**Conclusion Phase 2 :**

L'architecture est ambitieuse et l'intention originale est **partiellement préservée** (grappes, différentiation messages/outils, compacification). Cependant, **l'implémentation a des bugs critiques** qui rendent les outils difficilement utilisables au quotidien.

**Recommandation :** Prioriser correction des bugs P0 avant toute nouvelle fonctionnalité.
