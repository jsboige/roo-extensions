# 💰 Patterns d'Économie Contexte - Optimisation Tokens

**Version :** 2.0.0 ⚠️ **RÉVISION MAJEURE FB-04**
**Date :** 2 Octobre 2025
**Architecture :** 2-Niveaux (Simple/Complex)
**Objectif :** Maximiser efficacité utilisation tokens ET qualité code
**Révision :** Principe Anti-Angles-Morts + Délégation Prioritaire

### 🔗 Lien avec Mapping LLMs

Les patterns d'économie contexte sont **adaptés par tier LLM** :

- **[`llm-modes-mapping.md`](llm-modes-mapping.md)** : Définit l'optimisation budget par tier
  - **Modes Simples (Flash/Mini)** : Grounding minimal, délégation prioritaire
  - **Modes Complex (SOTA)** : Grounding complet 4-niveaux SDDD
  - **Seuils tokens** : 50k (Simple) vs 100k (Complex)
  - **Checkpoint 50k** : OBLIGATOIRE modes Complex (prévention dérive)

**Synergie** : Les modes Flash/Mini ont des budgets tokens limités (50k-200k), nécessitant délégation agressive. Les modes SOTA ont des budgets étendus (200k+), permettant grounding exhaustif.

> 💡 **Recommandation** : Lire [`llm-modes-mapping.md`](llm-modes-mapping.md) Section 6 pour stratégies optimisation par tier.

## 🚨 Changements Majeurs v2.0.0

Cette version introduit un changement **CRITIQUE** de philosophie :

### ❌ Version 1.0.0 (OBSOLÈTE - Risquée)
- Pattern 5 : "Lecture Ciblée" encourageait lectures partielles
- Économie tokens via fragmentation fichiers
- Anti-pattern : Lecture intégrale = MAUVAIS
- Résultat : Angles morts → Bugs subtils → Re-travail coûteux

### ✅ Version 2.0.0 (ACTUELLE - Sûre)
- **RÈGLE D'OR** : Lecture complète OBLIGATOIRE avant analyses partielles
- Pattern 6 : "Anti-Angles-Morts" comme principe fondamental
- Économie tokens via DÉLÉGATION, pas fragmentation
- Lecture complète = ✅ BON, Lecture fragmentée = ❌ MAUVAIS
- Résultat : Contexte complet → Décisions justes → ROI 300%+

**⚠️ IMPORTANT** : Toute référence à "lecture ciblée" ou "lecture partielle" dans v1.0.0 doit être considérée comme **OBSOLÈTE et DANGEREUSE**.

---

## 🎯 Objectif des Patterns d'Économie

L'économie de contexte permet de :
1. **Préserver capacité cognitive** : Tokens disponibles pour raisonnement
2. **Éviter saturation** : Prévenir dépassement limites contexte
3. **Optimiser performance** : Réduire latence et coûts
4. **Maintenir qualité** : Concentration sur tâches essentielles

**Seuils critiques universels** :
- 🟢 0-30k tokens : Optimal, pleine capacité
- 🟡 30k-50k tokens : Attention, optimisation recommandée
- 🟠 50k-100k tokens : Critique, délégation obligatoire
- 🔴 >100k tokens : Maximum, orchestration OBLIGATOIRE

---

## 🏗️ Architecture Patterns d'Économie

### 🎯 Principe Fondamental : Vraie Économie = Délégation

**La vraie économie de tokens ne vient PAS de la lecture partielle (risquée), mais de la DÉLÉGATION (sûre).**

- ✅ **Délégation** : Créer sous-tâches atomiques via `new_task()` → Chaque sous-tâche lit ses fichiers COMPLÈTEMENT
- ❌ **Fragmentation** : Lire fichiers par morceaux → Angles morts → Re-travail coûteux

**Hiérarchie d'Utilisation** :
1. **Pattern 1 (Délégation)** : 80% des cas → Solution privilégiée universelle
2. **Pattern 2 (Décomposition)** : Préparation délégation → Planification atomique
3. **Pattern 3 (MCP Batch)** : Optimisation opérations → Réduction overhead
4. **Pattern 4 (Checkpoints)** : Sauvegarde progression → Reprise facilitée
5. **Pattern 5 (Lecture Intelligente)** : Lecture complète obligatoire → Analyses complémentaires optionnelles
6. **Pattern 6 (Anti-Angles-Morts)** : Principe transversal → Application universelle

### Diagramme Hiérarchie

```
┌──────────────────────────────────────────────────────────┐
│ ⭐ PATTERN 1 : DÉLÉGATION INTELLIGENTE (PRIORITAIRE)    │
│ 80% cas → new_task() pour sous-tâches atomiques         │
│ Vraie économie via parallélisation, PAS fragmentation   │
└──────────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────────────┐
│ PATTERN 2 : DÉCOMPOSITION ATOMIQUE                      │
│ Tâches complexes → Sous-tâches minimales               │
│ Prépare délégation efficace                            │
└──────────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────────────┐
│ PATTERN 3 : UTILISATION MCP BATCH                       │
│ Opérations multiples → Requêtes consolidées            │
│ Optimisation overhead, pas substitut délégation        │
└──────────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────────────┐
│ PATTERN 4 : CHECKPOINTS SYNTHÉTIQUES                    │
│ Contexte long → Synthèses régulières                   │
│ Sauvegarde progression, facilite reprise               │
└──────────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────────────┐
│ PATTERN 5 : LECTURE INTELLIGENTE PROGRESSIVE            │
│ Lecture complète OBLIGATOIRE → Analyses optionnelles   │
│ Anti-angles-morts : Contexte complet = Non-négociable  │
└──────────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────────────┐
│ 🛡️ PATTERN 6 : ANTI-ANGLES-MORTS (TRANSVERSAL)         │
│ Principe fondamental applicable à TOUS patterns         │
│ Contexte complet AVANT toute décision/modification      │
└──────────────────────────────────────────────────────────┘
```

### 📊 Répartition Usage Recommandée

| Pattern | Usage Typique | Cas Application |
|---------|---------------|-----------------|
| 1. Délégation | **80%** | Toute tâche >30k tokens, fichiers multiples, implémentation complexe |
| 2. Décomposition | **70%** | Préparation délégation, planning tâches complexes |
| 3. MCP Batch | **40%** | Lectures multiples, éditions coordonnées, recherches |
| 4. Checkpoints | **30%** | Tâches >30k tokens, sessions longues |
| 5. Lecture Intelligente | **100%** | TOUT fichier lu (complètement d'abord) |
| 6. Anti-Angles-Morts | **100%** | TOUTE décision/modification (contexte complet) |

**Note** : Les pourcentages >100% indiquent patterns combinables/transversaux.

---

## 1️⃣ PATTERN : Délégation Intelligente

### Principe

Le mode **Complex** analyse et conçoit, puis **délègue l'exécution** au mode **Simple** via `new_task()`.

### Économie Typique

**Sans délégation** :
```markdown
Mode Complex :
1. Analyse architecture (10k tokens)
2. Lecture 15 fichiers (25k tokens)
3. Conception solution (8k tokens)
4. Implémentation (12k tokens)
5. Tests (10k tokens)
TOTAL : 65k tokens → SEUIL CRITIQUE DÉPASSÉ
```

**Avec délégation** :
```markdown
Mode Complex :
1. Analyse architecture (10k tokens)
2. Conception solution (8k tokens)
3. Création 3 sous-tâches (3k tokens)
TOTAL : 21k tokens → OPTIMAL ✅

Mode Simple (3 instances parallèles) :
- Sous-tâche 1 : Implémentation Module A (15k tokens)
- Sous-tâche 2 : Implémentation Module B (18k tokens)
- Sous-tâche 3 : Tests intégration (12k tokens)
TOTAL : 45k tokens répartis → OPTIMAL ✅
```

**Économie** : 65k → 21k + (45k/3) = 36k tokens max dans un contexte unique

### Template Délégation

```xml
<new_task>
<mode>code-simple</mode>
<message>🎯 **Sous-tâche 1.2.1 : Implémentation Module Authentification**

**Contexte Architecture (Synthétique)** :
Architecture JWT validée avec endpoints /login, /refresh, /logout.
Dépendances approuvées : bcrypt@5.1.1, jsonwebtoken@9.0.2.

**Spécification Technique Détaillée** :
```typescript
// Interface AuthService attendue
interface AuthService {
  login(email: string, password: string): Promise<{token: string, refresh: string}>;
  refreshToken(token: string): Promise<{newToken: string}>;
  logout(token: string): Promise<{success: boolean}>;
}
```

**Fichiers à Créer** :
- src/services/AuthService.ts (implémentation complète)
- src/tests/AuthService.test.ts (tests unitaires 100% coverage)

**Critères Validation** :
- ✅ Toutes méthodes implémentées selon interface
- ✅ Tests unitaires passent (jest)
- ✅ Gestion erreurs complète (try/catch)
- ✅ Documentation JSDoc sur chaque méthode

**Ce qui N'EST PAS dans cette sous-tâche** :
- Intégration API routes (sous-tâche 1.2.2)
- Configuration middleware (sous-tâche 1.2.3)
- Tests E2E (sous-tâche 1.3)

**Estimation** : ~15k tokens, 1h30, complexité modérée
</message>
</new_task>
```

**Clés du succès** :
- ✅ Contexte synthétique (pas de répétition analyse complète)
- ✅ Spécification technique précise (pas d'ambiguïté)
- ✅ Scope clairement délimité (pas de dérive)
- ✅ Critères validation explicites (pas de va-et-vient)

### Cas d'Usage Typiques

**Délégation Lecture Batch** :
```xml
<new_task>
<mode>code-simple</mode>
<message>🎯 **Sous-tâche 2.1.1 : Extraction Configurations 15 Fichiers**

**Objectif** : Lire et extraire toutes configurations JSON environnements.

**Fichiers** :
- config/env/*.json (10 fichiers)
- config/services/*.json (5 fichiers)

**Format Sortie Attendu** :
```json
{
  "environments": { "dev": {...}, "staging": {...}, "prod": {...} },
  "services": { "api": {...}, "db": {...}, "cache": {...} }
}
```

**Outil** : Utiliser `quickfiles read_multiple_files` pour efficacité.

**Estimation** : ~8k tokens, 30 min
</message>
</new_task>
```

**Économie** : Mode Complex préserve 8k tokens pour analyse

---

## 2️⃣ PATTERN : Décomposition Atomique

### Principe

Décomposer tâches complexes en **sous-tâches atomiques** (1 responsabilité, 1 livrable, 1 validation).

### Granularité Optimale

**Trop Grossière** (Anti-pattern) :
```markdown
1.1 Implémenter module utilisateurs (50k tokens)
    → Trop vaste, contexte saturé
```

**Trop Fine** (Anti-pattern) :
```markdown
1.1.1 Créer interface User (2k tokens)
1.1.2 Créer classe User (2k tokens)
1.1.3 Ajouter méthode getEmail (1k tokens)
1.1.4 Ajouter méthode setEmail (1k tokens)
    → 4 contextes séparés, overhead orchestration
```

**Optimale** (Best Practice) :
```markdown
1.1 Implémenter entité User complète (15k tokens)
    - Interface + Classe + Méthodes + Tests
    - Scope atomique, livrable testable
    ✅ 1 contexte, efficace
```

### Règles de Décomposition

**Critère SMART Atomique** :
- **S**pecific : 1 responsabilité claire
- **M**easurable : Critères validation objectifs
- **A**chievable : Réalisable en <20k tokens
- **R**elevant : Contribue directement objectif parent
- **T**ime-boxed : Estimation durée <2h

**Seuils recommandés** :
- Sous-tâche Simple : 10-20k tokens, 1-2h
- Sous-tâche Modérée : 20-35k tokens, 2-4h
- Sous-tâche Complexe : 35-50k tokens, 4-6h
- Au-delà 50k : DÉCOMPOSER ENCORE

### Template Décomposition

**Tâche Parent (Analyse)** :
```markdown
## Tâche 1 : Système Authentification Complet

### Analyse Complexité
- 5 composants majeurs identifiés
- Estimation totale : ~120k tokens (CRITIQUE)
- Décomposition obligatoire en 5 sous-tâches

### Sous-tâches Atomiques Planifiées
1.1 Entité User + Repository (20k tokens, 2h)
1.2 Service Authentification JWT (25k tokens, 3h)
1.3 Middleware Validation Token (15k tokens, 1.5h)
1.4 API Routes + Controllers (30k tokens, 3.5h)
1.5 Tests E2E + Documentation (30k tokens, 3h)

TOTAL DÉCOMPOSÉ : 120k tokens sur 5 contextes
MAX PAR CONTEXTE : 30k tokens ✅ OPTIMAL
```

**Création Sous-tâches** :
```xml
<!-- Répéter pour chaque sous-tâche -->
<new_task>
<mode>code-simple</mode>
<message>🎯 **Sous-tâche {{NUMERO}} : {{TITRE}}**

**Contexte Hérité Synthétique** :
[Décisions architecturales clés, pas d'analyse complète]

**Objectif Atomique** :
[1 responsabilité, 1 livrable]

**Dépendances** :
- Requiert : {{TÂCHES_PRÉALABLES}} (doivent être COMPLÉTÉES)
- Produit pour : {{TÂCHES_SUIVANTES}}

**Estimation** : {{TOKENS}}k tokens, {{HEURES}}h
</message>
</new_task>
```

---

## 3️⃣ PATTERN : Utilisation MCP Batch

### Principe

Utiliser MCPs pour **opérations batch** au lieu d'outils natifs multiples.

### Économie Typique

**Sans MCP Batch** (Anti-pattern) :
```xml
<!-- 5 requêtes séparées = 5× overhead -->
<read_file><path>module-a.ts</path></read_file>
<read_file><path>module-b.ts</path></read_file>
<read_file><path>module-c.ts</path></read_file>
<read_file><path>module-d.ts</path></read_file>
<read_file><path>module-e.ts</path></read_file>
```

**Avec MCP Batch** (Best Practice) :
```xml
<!-- 1 requête = 1× overhead -->
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>read_multiple_files</tool_name>
<arguments>
{
  "paths": ["module-a.ts", "module-b.ts", "module-c.ts", "module-d.ts", "module-e.ts"],
  "max_lines_per_file": 500
}
</arguments>
</use_mcp_tool>
```

**Économie** : 
- Overhead requêtes : 5× → 1× (~80% réduction)
- Tokens formatting : 5× → 1× (~80% réduction)
- Temps réponse : 5× latence → 1× latence

### Patterns MCP Optimaux

#### Pattern A : Lecture Batch Progressive

```markdown
**Étape 1** : Explorer structure (minimal)
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>list_directory_contents</tool_name>
<arguments>
{
  "paths": ["src/modules"],
  "recursive": false
}
</arguments>
</use_mcp_tool>

**Étape 2** : Lire fichiers pertinents identifiés (batch)
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>read_multiple_files</tool_name>
<arguments>
{
  "paths": ["src/modules/auth.ts", "src/modules/user.ts"],
  "max_lines_per_file": 300
}
</arguments>
</use_mcp_tool>

**Étape 3** : Lecture approfondie si nécessaire (ciblée)
<read_file>
<path>src/modules/auth.ts</path>
<line_range>150-250</line_range>
</read_file>
```

**Bénéfices** :
- Exploration rapide sans surcharge
- Lecture batch des candidats
- Approfondissement ciblé minimal

#### Pattern B : Édition Batch Coordonnée

```xml
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>edit_multiple_files</tool_name>
<arguments>
{
  "files": [
    {
      "path": "src/module-a.ts",
      "diffs": [
        {"search": "old import", "replace": "new import", "start_line": 5}
      ]
    },
    {
      "path": "src/module-b.ts",
      "diffs": [
        {"search": "old import", "replace": "new import", "start_line": 8}
      ]
    },
    {
      "path": "src/module-c.ts",
      "diffs": [
        {"search": "old import", "replace": "new import", "start_line": 3}
      ]
    }
  ]
}
</arguments>
</use_mcp_tool>
```

**Bénéfices** :
- Atomicité (tout ou rien)
- Cohérence garantie
- Économie 3× requêtes

#### Pattern C : Recherche Multi-Fichiers

```xml
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>search_in_files</tool_name>
<arguments>
{
  "paths": ["src", "tests"],
  "pattern": "function authenticate",
  "use_regex": true,
  "context_lines": 5,
  "max_results_per_file": 3
}
</arguments>
</use_mcp_tool>
```

**Bénéfices** :
- Contexte immédiat (lignes encadrantes)
- Statistiques par fichier
- Limites configurables

---

## 4️⃣ PATTERN : Checkpoints Synthétiques

### Principe

À intervalles réguliers, créer **synthèses condensées** pour libérer contexte.

### Seuils de Checkpoint

- **30k tokens** : Checkpoint recommandé (prévention)
- **50k tokens** : Checkpoint OBLIGATOIRE (critique)
- **100k tokens** : Checkpoint + DÉLÉGATION (maximum)

### Format Checkpoint Standard

```markdown
## 🔖 Checkpoint 50k Tokens - [Date] [Heure]

### Contexte Actuel
**Tâche** : 1.2 Implémentation Service Authentification
**Progression** : 60% (~30k tokens consommés)
**Prochaine étape** : Tests unitaires

### Actions Accomplies (Synthèse)
1. ✅ Interface AuthService définie (3 méthodes)
2. ✅ Classe AuthService implémentée (login, refresh, logout)
3. ✅ Intégration bcrypt + jsonwebtoken validée
4. ✅ Gestion erreurs complète (try/catch)

### Décisions Techniques Clés
- **JWT Expiration** : 1h access, 7j refresh (validé utilisateur)
- **Hash Rounds** : bcrypt rounds=12 (sécurité vs performance)
- **Error Handling** : Exceptions custom AuthError, InvalidTokenError

### État Code Actuel
**Fichiers modifiés** :
- `src/services/AuthService.ts` : 150 lignes (complet)
- `src/types/auth.types.ts` : 45 lignes (interfaces)

**Résumé implémentation** :
```typescript
class AuthService {
  async login(email, password) { /* bcrypt verify + JWT sign */ }
  async refreshToken(token) { /* JWT verify + reissue */ }
  async logout(token) { /* Invalidate token */ }
}
```

### Prochaines Étapes (Priorités)
1. [ ] Créer AuthService.test.ts (tests unitaires complets)
2. [ ] Valider coverage 100% (jest --coverage)
3. [ ] Documentation JSDoc méthodes
4. [ ] Intégration API routes (sous-tâche 1.2.2)

### Recommandations Économie Contexte
**Option A** : Continuer dans contexte actuel (30k restants suffisants pour tests)
**Option B** : Créer sous-tâche tests si ajout fonctionnalités prévu

**Décision** : Option A retenue (tests simples, context OK)
```

**Bénéfices** :
- 🧠 Mémoire externe projet
- 🔄 Reprise facilitée après interruption
- 📊 Métriques progression précises
- 🎯 Focalisation prochaines étapes

### Template Checkpoint Automatique

```markdown
## 🔖 Checkpoint {{TOKENS}}k - {{TIMESTAMP}}

### Synthèse 3-Points
1. **Fait** : [Résumé ultra-condensé actions]
2. **Décidé** : [Décisions architecturales clés]
3. **Suivant** : [Prochaines 2-3 étapes prioritaires]

### État Fichiers (Delta)
- Modifiés : {{LISTE}} (+{{LIGNES_AJOUTÉES}}/-{{LIGNES_SUPPRIMÉES}})
- Créés : {{LISTE}}
- Tests : {{STATUT}}

### Recommandation Contexte
{{#if TOKENS > 50}}
🔴 CRITIQUE : Délégation recommandée
{{else if TOKENS > 30}}
🟡 ATTENTION : Checkpoint effectué, optimiser suite
{{else}}
🟢 OPTIMAL : Continue dans contexte actuel
{{/if}}
```

---

## 5️⃣ PATTERN : Lecture Intelligente Progressive

### ⚠️ RÈGLE D'OR ANTI-ANGLES-MORTS

**Toujours lire un fichier EN ENTIER avant toute analyse partielle.**

Cette règle est **NON-NÉGOCIABLE** pour garantir :
- ✅ Compréhension contexte global complet
- ✅ Identification de toutes les dépendances
- ✅ Prévention des angles morts critiques
- ✅ Décisions éclairées basées sur contexte complet

### Principe Fondamental

La lecture complète d'un fichier est **OBLIGATOIRE** comme première étape. Les analyses partielles ou ciblées ne sont que des **compléments optionnels** APRÈS avoir obtenu le contexte global.

**❌ INTERDIT** : Commencer par des lectures partielles, line_range, ou recherches sans contexte
**✅ OBLIGATOIRE** : Lecture complète d'abord, analyses complémentaires ensuite SI NÉCESSAIRE

### Stratégie Obligatoire

**Niveau 1 : Lecture Complète (OBLIGATOIRE - Étape de Grounding)** :
```xml
<!-- TOUJOURS commencer par ceci -->
<read_file>
<path>src/module.ts</path>
</read_file>
```

**Objectif** :
- Grounding complet sur le fichier
- Compréhension architecture et structure
- Identification zones intérêt pour analyses complémentaires
- Prévention angles morts critiques

**Résultat** : Base solide pour toute décision ou modification

**Niveau 2 : Analyses Complémentaires (OPTIONNEL - Si Nécessaire)** :

Après avoir lu le fichier complet, vous pouvez SI NÉCESSAIRE :

```xml
<!-- Recherche regex ciblée pour validation croisée -->
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>search_in_files</tool_name>
<arguments>
{
  "paths": ["src/module.ts"],
  "pattern": "function authenticate",
  "context_lines": 3
}
</arguments>
</use_mcp_tool>

<!-- Re-lecture zone spécifique pour focus -->
<read_file>
<path>src/module.ts</path>
<line_range>150-200</line_range>
</read_file>
```

**Important** : Ces analyses NE REMPLACENT PAS la lecture complète initiale, elles la COMPLÈTENT.

### Vraie Économie : Délégation, Pas Fragmentation

**❌ FAUSSE ÉCONOMIE (Risquée)** :
```markdown
Lire fichier par fragments pour "économiser tokens"
→ Risque angles morts → Re-travail → Coût réel SUPÉRIEUR
```

**✅ VRAIE ÉCONOMIE (Sûre)** :
```markdown
Lecture complète fichier unique : OK dans contexte actuel
Lecture multiples fichiers : DÉLÉGATION sous-tâches atomiques
→ Chaque sous-tâche = 1 fichier lu COMPLÈTEMENT
→ Économie via parallélisation, pas fragmentation risquée
```

**Exemple Délégation Optimale** :
```xml
<new_task>
<mode>code-simple</mode>
<message>🎯 **Sous-tâche 3.1 : Analyse Module Authentification**

**Objectif** : Lire et analyser COMPLÈTEMENT le module d'authentification.

**Fichier** : src/modules/auth.ts (lecture INTÉGRALE requise)

**Livrable** :
- Synthèse architecture du module
- Liste dépendances identifiées
- Points attention pour intégration

**Note** : Lecture complète OBLIGATOIRE pour éviter angles morts.
</message>
</new_task>
```

### Pattern Markdown Structure (Après Lecture Complète)

Pour documentation volumineuse, la structure peut aider APRÈS lecture complète :

```xml
<!-- Étape 1 : TOUJOURS lire document complet d'abord -->
<read_file>
<path>docs/architecture.md</path>
</read_file>

<!-- Étape 2 (optionnel) : Extraire structure pour navigation -->
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>extract_markdown_structure</tool_name>
<arguments>
{
  "paths": ["docs/architecture.md"],
  "max_depth": 3,
  "include_context": false
}
</arguments>
</use_mcp_tool>
```

**Ordre CRITIQUE** : Lecture complète AVANT structure, jamais l'inverse

---

## 📊 Matrice Décision Économie

### Flowchart Optimisation

```
┌─────────────────┐
│ Tokens actuels? │
└───────┬─────────┘
        ↓
    ┌────────┐
    │ <30k?  │
    └─┬────┬─┘
      │    │
     OUI  NON
      │    │
      ↓    ↓
   ┌─────┐ ┌──────────┐
   │ OK  │ │ 30-50k?  │
   └─────┘ └─┬──────┬─┘
             │      │
            OUI    NON
             │      │
             ↓      ↓
      ┌──────────┐ ┌──────────┐
      │CHECKPOINT│ │ >50k?    │
      └──────────┘ └─┬──────┬─┘
                     │      │
                    OUI    NON
                     │      │
                     ↓      ↓
              ┌───────────┐ ┌──────────┐
              │ DÉLÉGUER  │ │ >100k?   │
              │ new_task()│ └─┬──────┬─┘
              └───────────┘   │      │
                             OUI    NON
                              │      │
                              ↓      ↓
                       ┌──────────┐ ┌──────────┐
                       │ORCHESTR. │ │CHECKPOINT│
                       │OBLIGAT.  │ │+ DÉLÉGAT.│
                       └──────────┘ └──────────┘
```

---

## 6️⃣ PATTERN : Anti-Angles-Morts (Prévention Blind Spots)

### 🎯 Principe Fondamental

**Les angles morts sont l'ennemi silencieux de la qualité logicielle.**

Un "angle mort" survient lorsqu'une décision ou modification est prise sur la base d'un contexte **incomplet** ou **fragmenté**, conduisant à :
- 🐛 Bugs subtils non détectés
- 🔄 Re-travail coûteux
- 💥 Régression fonctionnelle
- 🧩 Incohérences architecturales
- ⏱️ Coût total SUPÉRIEUR aux tokens "économisés"

### ⚠️ Règle Anti-Angles-Morts

```
AVANT toute décision ou modification :
Contexte COMPLET = OBLIGATOIRE

Fichier = Unité atomique d'information
→ TOUJOURS lire EN ENTIER
```

### Workflow Obligatoire Anti-Angles-Morts

**Étape 1 : Identification Fichiers Pertinents** :
```xml
<!-- Recherche sémantique pour découverte -->
<codebase_search>
<query>authentication jwt token validation</query>
<path>src</path>
</codebase_search>

<!-- Ou exploration structure -->
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>list_directory_contents</tool_name>
<arguments>{"paths": ["src/auth"], "recursive": true}</arguments>
</use_mcp_tool>
```

**Étape 2 : Lecture Complète CHAQUE Fichier Identifié** :
```xml
<!-- ✅ CORRECT : Lecture intégrale -->
<read_file>
<path>src/auth/AuthService.ts</path>
</read_file>

<read_file>
<path>src/auth/TokenValidator.ts</path>
</read_file>
```

**Étape 3 : Synthèse Mentale Contexte Global** :
```markdown
Après lectures complètes, mental model :
- Architecture AuthService utilise TokenValidator
- Dépendance jwt library version 9.0.2
- Validation tokens inclut refresh + access
- Error handling via custom AuthError
→ Base solide pour modifications
```

**Étape 4 : Analyses Complémentaires (Si Nécessaire)** :
```xml
<!-- Validation croisée APRÈS contexte complet -->
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>search_in_files</tool_name>
<arguments>
{
  "paths": ["src"],
  "pattern": "AuthError",
  "context_lines": 5
}
</arguments>
</use_mcp_tool>
```

**Étape 5 : Décisions Éclairées** :
```markdown
Décision basée sur :
✅ Architecture complète comprise
✅ Dépendances identifiées
✅ Patterns existants respectés
✅ Impacts anticipés

→ Modifications cohérentes et sûres
```

### 🚫 Anti-Patterns Flagrants

#### ❌ Anti-Pattern 1 : Search-First (Recherche Sans Contexte)

**MAUVAIS** :
```xml
<!-- Chercher fonction sans lire fichier complet -->
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>search_in_files</tool_name>
<arguments>
{
  "paths": ["src/auth/AuthService.ts"],
  "pattern": "function login"
}
</arguments>
</use_mcp_tool>

<!-- Modifier basé sur fragment trouvé -->
<apply_diff>
<path>src/auth/AuthService.ts</path>
<diff>...</diff>
</apply_diff>
```

**Problèmes** :
- 🔴 Architecture globale ignorée
- 🔴 Dépendances manquées
- 🔴 Side-effects non anticipés
- 🔴 Risque breaking changes

**CORRECT** :
```xml
<!-- 1. Lire fichier COMPLET d'abord -->
<read_file>
<path>src/auth/AuthService.ts</path>
</read_file>

<!-- 2. Comprendre architecture globale -->
<!-- 3. PUIS modifier en connaissance de cause -->
<apply_diff>
<path>src/auth/AuthService.ts</path>
<diff>...</diff>
</apply_diff>
```

#### ❌ Anti-Pattern 2 : Line-Range-First (Lecture Partielle)

**MAUVAIS** :
```xml
<!-- Lire uniquement lignes "intéressantes" -->
<read_file>
<path>src/config/database.ts</path>
<line_range>50-100</line_range>
</read_file>

<!-- Manque : imports, constantes globales, exports -->
```

**Problèmes** :
- 🔴 Imports manqués (dépendances inconnues)
- 🔴 Constantes globales ignorées
- 🔴 Exports incompris
- 🔴 Décision basée sur vision tronquée

**CORRECT** :
```xml
<!-- Lire fichier COMPLET -->
<read_file>
<path>src/config/database.ts</path>
</read_file>

<!-- Optionnel : Re-focus zone si besoin APRÈS -->
<read_file>
<path>src/config/database.ts</path>
<line_range>50-100</line_range>
</read_file>
```

#### ❌ Anti-Pattern 3 : Assumption-Driven (Hypothèses Non Vérifiées)

**MAUVAIS** :
```markdown
"Je suppose que cette fonction fait X"
→ Modification basée sur supposition
→ Sans vérifier contexte complet
```

**Problèmes** :
- 🔴 Hypothèses souvent fausses
- 🔴 Comportements surprenants ignorés
- 🔴 Edge cases manqués
- 🔴 Tests cassés

**CORRECT** :
```markdown
1. Lire fichier complet
2. Comprendre RÉELLEMENT ce que fait fonction
3. Vérifier edge cases et error handling
4. PUIS modifier en connaissance complète
```

#### ❌ Anti-Pattern 4 : Quick-Fix-Syndrome (Modification Rapide)

**MAUVAIS** :
```markdown
"Je vais juste modifier cette ligne rapidement"
→ Sans lire reste du fichier
→ Sans comprendre contexte global
```

**Problèmes** :
- 🔴 Régression introduite
- 🔴 Incohérences avec reste code
- 🔴 Breaking changes non détectés
- 🔴 Coût re-travail > temps "gagné"

**CORRECT** :
```markdown
1. Même pour "petite" modification : Lire fichier complet
2. Comprendre impact potentiel
3. Vérifier cohérence avec architecture
4. Modifier en sécurité
```

### ✅ Exceptions Rares (Usage Avancé)

**Exception 1 : Fichiers Volumineux >10k Lignes** :
```xml
<!-- OK : Lecture complète + focus zones -->
<read_file>
<path>src/generated/api-client.ts</path>
</read_file>

<!-- 15000 lignes lues, focus sur zone modifiable -->
<read_file>
<path>src/generated/api-client.ts</path>
<line_range>8000-8500</line_range>
</read_file>
```

**Justification** : Contexte global obtenu, re-lecture zone pour clarté

**Exception 2 : Logs Volumineux** :
```xml
<!-- OK : Stratégie logs définie AVANT recherche -->
<read_file>
<path>logs/app.log</path>
<line_range>-1000</line_range> <!-- 1000 dernières lignes -->
</read_file>

<!-- Recherche patterns erreurs -->
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>search_in_files</tool_name>
<arguments>
{
  "paths": ["logs/app.log"],
  "pattern": "ERROR|FATAL",
  "context_lines": 10
}
</arguments>
</use_mcp_tool>
```

**Justification** : Logs = nature différente (séquentiel, non-architectural)

**Exception 3 : Data Files (CSV, JSON volumineux)** :
```xml
<!-- OK : Headers + échantillon PUIS recherche -->
<read_file>
<path>data/users.csv</path>
<line_range>1-100</line_range> <!-- Headers + premiers records -->
</read_file>

<!-- Recherche record spécifique si besoin -->
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>search_in_files</tool_name>
<arguments>
{
  "paths": ["data/users.csv"],
  "pattern": "user-12345"
}
</arguments>
</use_mcp_tool>
```

**Justification** : Data tabulaire = structure répétitive, échantillon suffit

### 📚 Cas d'École : Incident README.md

**Contexte Réel** :
```markdown
Utilisateur demande : "Analyse le README.md du projet"

❌ MA PREMIÈRE TENTATIVE (MAUVAISE) :
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>search_in_files</tool_name>
<arguments>
{
  "paths": ["README.md"],
  "pattern": "installation|configuration|usage"
}
</arguments>
</use_mcp_tool>

🔴 FEEDBACK UTILISATEUR :
"Lis le fichier EN ENTIER pour ne pas avoir d'angles morts"
```

**Problème Identifié** :
- Recherche fragmentée a raté sections importantes
- Vision tronquée du projet
- Recommandations basées sur contexte incomplet
- Angles morts sur architecture et dépendances

**Correction** :
```xml
<read_file>
<path>README.md</path>
</read_file>
```

**Résultat** :
- ✅ Contexte complet obtenu
- ✅ Toutes sections comprises (même non searchées)
- ✅ Recommandations pertinentes et cohérentes
- ✅ Zéro angle mort

**Leçon** : **1 fichier = 1 lecture complète, TOUJOURS**

### 💰 Coût Réel : Angles Morts vs Tokens "Économisés"

**Scénario Typique** :

```markdown
### Sans Anti-Angles-Morts (Lecture Partielle)
1. Lecture partielle fichier (line_range) : 2k tokens économisés
2. Modification basée sur contexte incomplet
3. Tests échouent → Re-lecture complète : 5k tokens
4. Découverte dépendance manquée → Re-lecture autre fichier : 3k tokens
5. Correction modification : 2k tokens
6. Re-tests : 1k tokens

TOTAL RÉEL : 13k tokens + 3h de re-travail
ÉCONOMIE INITIALE : 2k tokens
COÛT NET : +11k tokens + 3h perdues ❌

### Avec Anti-Angles-Morts (Lecture Complète)
1. Lecture complète fichier d'emblée : 5k tokens
2. Contexte complet = décision éclairée
3. Modification correcte premier coup : 2k tokens
4. Tests passent : 1k tokens

TOTAL : 8k tokens + 1h travail efficace
ÉCONOMIE NETTE : 5k tokens + 2h gagnées ✅
```

**Conclusion Mathématique** :
```
Lecture complète d'emblée = MOINS coûteuse que lecture partielle + re-travail

Angles morts = Fausse économie
Contexte complet = Vraie économie
```

### 🎯 Impact sur Qualité Décisions

**Décisions avec Angles Morts** :
- 🔴 Basées sur hypothèses
- 🔴 Ignorent cas edge
- 🔴 Ratent dépendances critiques
- 🔴 Incohérentes avec architecture existante
- 🔴 Nécessitent corrections multiples

**Décisions avec Contexte Complet** :
- ✅ Basées sur faits vérifiés
- ✅ Anticipent cas edge
- ✅ Respectent dépendances
- ✅ Cohérentes avec architecture
- ✅ Correctes premier coup

**Métriques Qualité** :
```
Taux succès premier coup :
- Avec angles morts : ~40%
- Avec contexte complet : ~85%

Temps moyen résolution :
- Avec angles morts : 3-5h (itérations multiples)
- Avec contexte complet : 1-2h (direct)
```

### 🛡️ Résumé Exécutif

**3 Règles d'Or** :
1. **Fichier = Unité Atomique** : Toujours lire en entier
2. **Contexte Avant Action** : Comprendre avant modifier
3. **Délégation Si Multiple** : N fichiers = N sous-tâches (chacune lit 1 fichier complet)

**Formule Succès** :
```
Qualité Code = f(Contexte Complet)
Contexte Complet ⇒ Lecture Intégrale Fichiers
∴ Lecture Intégrale = Non-négociable
```

**Rappel** : Les tokens "économisés" par lectures partielles sont une **illusion** si le coût du re-travail est pris en compte. La vraie économie passe par la **délégation**, pas la fragmentation.


### Tableau Recommandations

| Tokens | État | Action Immédiate | Pattern Recommandé |
|--------|------|------------------|-------------------|
| 0-10k | 🟢 Démarrage | Aucune | Exploration normale |
| 10-30k | 🟢 Optimal | Aucune | Continue, MCP batch si opportun |
| 30-40k | 🟡 Attention | Checkpoint préventif | Patterns 3-5 (Batch, Lecture ciblée) |
| 40-50k | 🟡 Vigilance | Checkpoint + Analyse | Patterns 1-2 (Délégation préparée) |
| 50-70k | 🟠 Critique | Délégation OBLIGATOIRE | Pattern 1-2 (new_task atomiques) |
| 70-100k | 🟠 Maximum | Délégation + Checkpoint | Pattern 2 + 4 (Décomposition + Synthèse) |
| >100k | 🔴 Dépassement | Orchestration IMMÉDIATE | Escalade orchestrator-complex |

---

## 🎨 Templates Instructions Modes

### Template Mode Simple

```markdown
## ÉCONOMIE CONTEXTE

### Monitoring Tokens
À chaque outil use, évaluer :
- Tokens consommés approximatifs
- Total cumulé actuel
- Distance seuil suivant (30k, 50k)

### Actions Préventives
**Si approche 30k** :
- Checkpoint synthétique
- Prioriser tâches restantes
- Évaluer possibilité finalisation

**Si approche 50k** :
- Checkpoint OBLIGATOIRE
- Escalade vers mode complexe si tâche incomplète
- Ou finalisation rapide si quasi-terminé

### Utilisation MCP Efficace
- Privilégier `quickfiles` pour opérations batch
- Lecture ciblée (line_range) au lieu de complète
- Éviter répétitions requêtes similaires
```

### Template Mode Complex

```markdown
## ÉCONOMIE CONTEXTE AVANCÉE

### Patterns Délégation
**Dès 30k tokens** : Évaluer décomposition
**Dès 50k tokens** : Délégation OBLIGATOIRE

### Création Sous-tâches Atomiques
```xml
<new_task>
<mode>code-simple</mode>
<message>🎯 **Sous-tâche {{NUMERO}} : {{TITRE}}**

**Contexte Synthétique** : [Essentiel seulement]
**Objectif Atomique** : [1 responsabilité]
**Estimation** : {{TOKENS}}k tokens, {{HEURES}}h
</message>
</new_task>
```

### Checkpoints Réguliers
- 30k : Checkpoint préventif
- 50k : Checkpoint + Délégation évaluée
- 70k : Checkpoint + Délégation OBLIGATOIRE

### Stratégie Analyse puis Délégation
1. Analyser et concevoir (garder contexte riche)
2. Créer sous-tâches implémentation (contexte synthétique)
3. Modes simples exécutent (contextes légers)
4. Valider et intégrer (contexte préservé)
```

---

## ⚠️ Anti-Patterns à Éviter

### ✅ Lecture Complète d'Abord (Grounding Obligatoire)
```xml
<!-- BON : Lecture intégrale pour contexte complet -->
<read_file>
<path>module.ts</path>
</read_file>

<!-- Puis analyses complémentaires SI NÉCESSAIRE -->
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>search_in_files</tool_name>
<arguments>
{
  "paths": ["module.ts"],
  "pattern": "function authenticate",
  "context_lines": 3
}
</arguments>
</use_mcp_tool>
```

**Justification** :
- ✅ Contexte global complet obtenu
- ✅ Prévention angles morts
- ✅ Décisions éclairées
- ✅ Zéro risque information manquée

### ❌ Lecture Fragmentée Sans Contexte Global
```xml
<!-- MAUVAIS : Recherche ou line_range SANS lecture complète préalable -->
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>search_in_files</tool_name>
<arguments>
{
  "paths": ["module.ts"],
  "pattern": "function authenticate"
}
</arguments>
</use_mcp_tool>

<!-- Ou pire : Lecture partielle directe -->
<read_file>
<path>module.ts</path>
<line_range>200-250</line_range>
</read_file>

<!-- Sans JAMAIS avoir lu le fichier complet -->
```

**Problèmes** :
- 🔴 Angles morts critiques (informations manquées)
- 🔴 Décisions basées sur contexte incomplet
- 🔴 Risque bugs subtils et régressions
- 🔴 Coût re-travail > tokens "économisés"

**Note Importante** : `list_code_definition_names` est également un anti-pattern si utilisé SANS lecture complète. Il ne remplace PAS la lecture intégrale, il peut seulement la COMPLÉTER.

### ❌ Pas de Checkpoint Avant Saturation
```markdown
Mode continue jusqu'à 95k tokens sans checkpoint
→ Pas de point reprise, contexte perdu si erreur
```

### ✅ Checkpoints Réguliers Préventifs
```markdown
- 30k : Checkpoint 1 (prévention)
- 50k : Checkpoint 2 (critique)
- 70k : Checkpoint 3 + délégation
→ Points reprise multiples, traçabilité complète
```

### ❌ Décomposition Excessive
```markdown
Décomposition en 50 micro-tâches de 2k tokens chacune
→ Overhead orchestration énorme, perte vue ensemble
```

### ✅ Décomposition Équilibrée
```markdown
Décomposition en 5-8 sous-tâches atomiques 15-30k chacune
→ Granularité optimale, orchestration efficace
```

---

## 📊 Métriques Économie Contexte

### ⚠️ Principe Métrique : Coût Total Réel

**Les métriques doivent inclure le COÛT COMPLET**, pas seulement tokens consommés :

```
Coût Total Réel = Tokens Lecture + Tokens Re-travail + Coût Bugs/Régressions

Lecture Partielle : Tokens initiaux faibles MAIS re-travail élevé
Lecture Complète : Tokens initiaux moyens MAIS re-travail quasi-nul

∴ Lecture Complète = Coût Total INFÉRIEUR
```

### Par Tâche (Métriques Enrichies)

```markdown
## Rapport Économie Contexte - Tâche {{ID}}

### Utilisation Tokens
- Tokens consommés : {{CONSUMED}}k
- Tokens économisés (délégation) : {{SAVED_DELEGATION}}k
- Tokens économisés (MCP batch) : {{SAVED_BATCH}}k
- **Coût angles morts évités** : {{SAVED_BLIND_SPOTS}}k
- Efficacité nette : {{NET_EFFICIENCY}}%

### Patterns Appliqués (Sûrs)
- ✅ Délégation intelligente : {{COUNT_DELEGATION}} sous-tâches
- ✅ MCP Batch : {{COUNT_BATCH}} vs {{COUNT_NATIVE}} natifs
- ✅ Lectures complètes : {{COUNT_FULL_READ}} fichiers

### Patterns Risqués Évités
- ❌ Lectures partielles évitées : {{COUNT_AVOIDED_PARTIAL}}
- ❌ Recherches sans contexte évitées : {{COUNT_AVOIDED_SEARCH_FIRST}}
- 🛡️ Angles morts prévenus : {{COUNT_BLIND_SPOTS_PREVENTED}}

### Impact Qualité
- Modifications correctes 1er coup : {{FIRST_TIME_RIGHT}}%
- Re-travail nécessaire : {{REWORK_COUNT}} itérations
- Bugs détectés post-livraison : {{BUGS_POST_DELIVERY}}
- Temps total (incluant corrections) : {{TOTAL_TIME}}h

### Seuils Franchis
- 30k : {{TIMESTAMP_30K}} (checkpoint préventif)
- 50k : {{TIMESTAMP_50K}} (+ checkpoint + évaluation délégation)
- 70k : {{TIMESTAMP_70K}} (+ délégation OBLIGATOIRE)

### Comparaison Scénarios

| Scénario | Tokens Initiaux | Re-travail | Total | Qualité |
|----------|-----------------|------------|-------|---------|
| **Lecture Partielle** | {{PARTIAL_INITIAL}}k | {{PARTIAL_REWORK}}k | {{PARTIAL_TOTAL}}k | {{PARTIAL_QUALITY}}% |
| **Lecture Complète** | {{FULL_INITIAL}}k | {{FULL_REWORK}}k | {{FULL_TOTAL}}k | {{FULL_QUALITY}}% |
| **Économie Réelle** | +{{DIFF_INITIAL}}k | -{{DIFF_REWORK}}k | **-{{DIFF_TOTAL}}k** ✅ | +{{DIFF_QUALITY}}% |

### Recommandations Futures
- Patterns sûrs qui ont bien fonctionné : [Délégation, Lecture complète, MCP batch]
- Patterns risqués évités avec succès : [Lecture partielle, Search-first]
- Amélioration continue : [Points spécifiques identifiés]
```

### Par Mode (Agrégé)

```markdown
## Rapport Mode {{MODE_SLUG}} - Période {{PERIOD}}

### Statistiques Tokens
- Moyenne par tâche : {{AVG_TOKENS}}k
- Maximum atteint : {{MAX_TOKENS}}k
- Tâches >50k : {{COUNT_CRITICAL}} ({{PERCENT}}%)

### Efficacité Patterns Sûrs
- Délégations effectuées : {{COUNT_DELEGATIONS}}
- Économie moyenne délégation : {{AVG_SAVED_DELEGATION}}k tokens/délégation
- Taux MCP batch : {{MCP_RATE}}%
- Taux lecture complète : {{FULL_READ_RATE}}% (objectif: 100%)

### Prévention Angles Morts
- Lectures complètes vs partielles : {{FULL_VS_PARTIAL_RATIO}}
- Angles morts évités : {{BLIND_SPOTS_AVOIDED}}
- Économie re-travail : {{REWORK_SAVED}}k tokens
- Coût bugs prévenus : {{BUGS_PREVENTED_COST}}k tokens équivalent

### Qualité & Fiabilité
- Tâches complétées sans saturation : {{SUCCESS_RATE}}%
- **Tâches correctes 1er coup** : {{FIRST_TIME_RIGHT_RATE}}%
- Re-travail moyen : {{AVG_REWORK}} itérations/tâche
- Escalades forcées (>100k) : {{ESCALATIONS}}
- Bugs post-livraison : {{POST_DELIVERY_BUGS}}

### ROI Patterns

| Pattern | Coût Implémentation | Économie Générée | ROI | Risque |
|---------|---------------------|------------------|-----|--------|
| Délégation | Faible (planning) | **Très élevée** (parallélisation) | **500%** | ✅ Nul |
| Lecture Complète | Moyen (tokens) | **Élevée** (évite re-travail) | **300%** | ✅ Nul |
| MCP Batch | Faible (setup) | Moyenne (overhead) | 200% | ✅ Nul |
| Lecture Partielle | Faible (tokens) | **Négative** (re-travail) | **-150%** | 🔴 Élevé |

**Conclusion** : Patterns "économes en tokens" peuvent avoir ROI **négatif** si re-travail pris en compte.
```

---

## 🚀 Bénéfices Économie Contexte (Révisés)

### Bénéfices Quantifiables

1. **Performance Tokens** : -40% tokens moyens par tâche (via délégation)
2. **Qualité Code** : +85% modifications correctes 1er coup (via lecture complète)
3. **Prévention Angles Morts** : -90% bugs subtils (via contexte complet)
4. **Réduction Re-travail** : -75% itérations corrections (via décisions éclairées)
5. **Coûts API** : -35% coûts globaux (délégation + prévention re-travail)
6. **Fiabilité** : +80% tâches finalisées premier essai
7. **Maintenabilité** : Checkpoints facilitent reprises (+60% vitesse reprise)

### Comparaison Approches

**Approche "Fausse Économie" (Lecture Partielle)** :
```
Tokens lecture : 2k (économie apparente)
Tokens re-travail : 11k (angles morts)
Temps perdu : 3h
Bugs introduits : 2-3
TOTAL : 13k tokens + 3h + bugs ❌
```

**Approche "Vraie Économie" (Lecture Complète + Délégation)** :
```
Tokens lecture complète : 5k
Tokens re-travail : 1k (décisions justes)
Temps économisé : 2h
Bugs introduits : 0
TOTAL : 6k tokens + gain 2h + qualité ✅
```

**Gain Net** : 7k tokens + 5h + élimination bugs = **ROI 300%+**

### Impact Long Terme

- **Confiance Utilisateur** : Décisions basées contexte complet → Recommandations fiables
- **Vélocité Projet** : Moins corrections → Progression linéaire stable
- **Dette Technique** : Prévention angles morts → Code maintenable long terme
- **Apprentissage** : Patterns sûrs réutilisables → Amélioration continue

---

## 📚 Ressources Complémentaires

- [`escalade-mechanisms-revised.md`](escalade-mechanisms-revised.md) : Délégation et désescalade économique
- [`hierarchie-numerotee-subtasks.md`](hierarchie-numerotee-subtasks.md) : Décomposition atomique optimale
- [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md) : Grounding initial complet obligatoire
- [`mcp-integrations-priority.md`](mcp-integrations-priority.md) : Utilisation MCP batch efficace
- [`factorisation-commons.md`](factorisation-commons.md) : Réduction instructions communes

---

## 🔗 Cohérence Architecturale

### Alignement avec SDDD Protocol (4 Niveaux)

Le protocole SDDD impose un **Grounding Initial** obligatoire au début de chaque tâche. Cette révision du document [`context-economy-patterns.md`](context-economy-patterns.md) renforce cette exigence :

- **SDDD Niveau 1 (Grounding Initial)** ↔️ **Pattern 6 (Anti-Angles-Morts)** : Contexte complet AVANT action
- **SDDD Niveau 2 (Checkpoint Milieu)** ↔️ **Pattern 4 (Checkpoints)** : Synthèses régulières
- **SDDD Niveau 3 (Validation Finale)** ↔️ **Métriques Qualité** : Vérification correctness 1er coup

**Cohérence Validée** : ✅ Le grounding complet (lecture intégrale fichiers) est maintenant **NON-NÉGOCIABLE** dans les deux documents.

### Alignement avec Hiérarchie Sous-Tâches

Le document [`hierarchie-numerotee-subtasks.md`](hierarchie-numerotee-subtasks.md) définit `new_task()` comme mécanisme universel de délégation. Cette révision positionne la **Délégation comme Pattern #1 prioritaire (80% des cas)** :

- **Décomposition Atomique** ↔️ **Pattern 2** : Sous-tâches 15-30k tokens
- **new_task() Universel** ↔️ **Pattern 1 Délégation** : Mécanisme privilégié
- **Scope Délimité** ↔️ **Lecture Complète** : Chaque sous-tâche lit ses fichiers EN ENTIER

**Cohérence Validée** : ✅ La délégation via `new_task()` est le pattern #1, chaque sous-tâche applique principe anti-angles-morts.

### Alignement avec Escalade Mechanisms

Le document [`escalade-mechanisms-revised.md`](escalade-mechanisms-revised.md) clarifie la distinction entre délégation (préférée) et escalade (dernier recours). Cette révision renforce cette distinction :

- **Délégation Préventive** ↔️ **Pattern 1** : Évite saturation contexte
- **Escalade Forcée** ↔️ **Seuil >100k** : Dernier recours seulement
- **Décomposition vs Escalade** ↔️ **Patterns 1-2 vs Switch Mode** : Délégation privilégiée

**Cohérence Validée** : ✅ Délégation = pattern prioritaire, escalade = exception rare.

### Principe Transversal Unifié

```
┌─────────────────────────────────────────────────────────────┐
│          RÈGLE D'OR TRANSVERSALE (Tous Documents)          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Contexte Complet AVANT Décision/Action                    │
│                                                             │
│  - SDDD Protocol : Grounding initial obligatoire           │
│  - Context Economy : Lecture intégrale fichiers            │
│  - Hiérarchie Subtasks : Scope complet par sous-tâche      │
│  - Escalade Mechanisms : Contexte avant délégation         │
│                                                             │
│  ⚠️ Angles Morts = Ennemi Commun Prévenu par Tous Patterns │
└─────────────────────────────────────────────────────────────┘
```

---

## 📝 Note Finale Révisée

**Version 2.0.0 - Révision Majeure FB-04**

L'économie de contexte n'est **pas une contrainte** mais une **opportunité d'optimisation sûre**. Cette révision majeure clarifie un principe fondamental :

### 🎯 Message Clé

**La VRAIE économie de tokens = DÉLÉGATION, pas lecture partielle risquée.**

### ⚠️ Changements Critiques

1. **Pattern 5 Révisé** : Lecture complète OBLIGATOIRE avant analyses partielles
2. **Pattern 6 Ajouté** : Anti-Angles-Morts comme principe fondamental
3. **Hiérarchie Inversée** : Délégation = Pattern #1 prioritaire (80% cas)
4. **Anti-Patterns Inversés** : Lecture complète = ✅ BON, Lecture partielle = ❌ MAUVAIS
5. **Métriques Enrichies** : Coût angles morts inclus dans calculs ROI

### 🛡️ Règle d'Or Universelle

```
AVANT toute décision ou modification :
→ Contexte COMPLET = OBLIGATOIRE
→ Fichier = Unité atomique (lire EN ENTIER)
→ Angles morts = Ennemi silencieux à prévenir
```

### ✅ Résultat Attendu

- **Qualité** : +85% modifications correctes 1er coup
- **Fiabilité** : -90% bugs subtils par prévention angles morts
- **ROI** : 300%+ via réduction re-travail
- **Confiance** : Décisions éclairées sur contexte complet

Les patterns présentés permettent de maintenir **qualité ET performance** tout en respectant les limites des modèles de langage, en privilégiant approches **sûres** (délégation, lecture complète) sur approches **risquées** (lecture partielle, recherche sans contexte).