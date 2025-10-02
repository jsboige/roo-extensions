# 🔄 Mécaniques d'Escalade - Architecture Révisée v3.0

**Version :** 3.0.0  
**Date :** 01 Octobre 2025  
**Statut :** ✅ Spécification consolidée post-feedback utilisateur  
**Révision majeure** : Clarification définition stricte escalade vs autres mécanismes

---

## 📖 Table des Matières

1. [Définitions Fondamentales](#-1-définitions-fondamentales)
2. [Les 3 Formes d'Escalade](#-2-les-3-formes-descalade)
3. [Exception Contexte Saturé](#-3-exception-contexte-saturé)
4. [Principe Général : Privilégier new_task()](#-4-principe-général--privilégier-new_task)
5. [Anti-Patterns](#-5-anti-patterns)
6. [Critères par Domaine](#-6-critères-par-domaine)
7. [Tableaux Comparatifs](#-7-tableaux-comparatifs)
8. [Ressources Complémentaires](#-8-ressources-complémentaires)

---

## 📖 1. Définitions Fondamentales

### 1.1 Définition Stricte : Escalade

> **ESCALADE** = Phénomène précis où un mode **MANQUE DE COMPÉTENCES/CAPACITÉS** pour accomplir une tâche → besoin d'un mode **PLUS CAPABLE**

**Signature unique** : **Simple → Complex** (montée en compétence)

#### Caractéristiques Essentielles

```
┌─────────────────────────────────────────────────┐
│  ESCALADE = TOUJOURS Simple → Complex          │
│                                                 │
│  ✅ Mode simple identifie insuffisance          │
│  ✅ Besoin compétences/capacités supérieures    │
│  ✅ Transition vers mode complex équivalent     │
│                                                 │
│  Direction : code-simple → code-complex        │
│             debug-simple → debug-complex       │
│             architect-simple → architect-complex│
│             ask-simple → ask-complex           │
└─────────────────────────────────────────────────┘
```

### 1.2 Ce qui N'EST PAS une Escalade

Il est **critique** de distinguer l'escalade d'autres mécanismes légitimes :

#### ❌ DÉCOMPOSITION (Économie Contexte)

```markdown
**Définition** : Déléguer actions lourdes pour préserver contexte

Direction : Any → Any (souvent Same → Same)
Raison : Économie tokens, pas manque compétences
Outil : new_task()

Exemple :
- code-simple → code-simple (lecture batch 15 fichiers)
- architect-complex → architect-complex (sous-tâches parallèles)

⚠️ CE N'EST PAS UNE ESCALADE
```

#### ❌ DÉLÉGATION (Spécialisation)

```markdown
**Définition** : Confier tâche à mode spécialisé

Direction : Any → Specialist (pas nécessairement complex)
Raison : Expertise domaine spécifique, pas manque compétences générales
Outil : new_task()

Exemple :
- orchestrator → code-simple (implémentation feature définie)
- architect → code-simple (tests unitaires planifiés)

⚠️ CE N'EST PAS UNE ESCALADE
```

#### ❌ ORCHESTRATION (Coordination)

```markdown
**Définition** : Coordonner workflow multi-étapes/multi-modes

Direction : Any → orchestrator
Raison : Complexité coordination, pas manque compétences techniques
Outil : new_task()

Exemple :
- code-complex → orchestrator (workflow 8 étapes interdépendantes)
- architect → orchestrator (intégration multi-systèmes)

⚠️ CE N'EST PAS UNE ESCALADE
```

### 1.3 Tableau Comparatif : Escalade vs Autres Mécanismes

| Critère | Escalade | Décomposition | Délégation | Orchestration |
|---------|----------|---------------|------------|---------------|
| **Raison** | Manque compétences | Économie contexte | Spécialisation | Coordination |
| **Direction** | Simple → Complex | Any → Any | Any → Specialist | Any → Orchestrator |
| **Signature** | Montée compétence | Atomisation | Expertise ciblée | Workflow multi-étapes |
| **Contexte hérité** | Partiel ou Complet | Minimal | Complet | Synthèse |
| **Outils** | switch_mode ou new_task | new_task | new_task | new_task |
| **Quand utiliser** | Tâche dépasse capacités | Contexte >50% | Besoin expert | >5 étapes |

---

## 🎯 2. Les 3 Formes d'Escalade

### Vue d'Ensemble

```
┌──────────────────────────────────────────────────────────────┐
│ FORME 1 : ESCALADE INTERNE (Rare)                           │
│ ─────────────────────────────────────────                   │
│ switch_mode au sein de la même tâche                        │
│ Simple → Complex sans créer sous-tâche                      │
│ ⚠️ À ÉVITER : Risque incompatibilité contexte               │
└──────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────┐
│ FORME 2 : ESCALADE EXTERNE-COMPÉTENTE (Privilégiée)        │
│ ────────────────────────────────────────────────            │
│ new_task vers mode Complex "Oracle"                         │
│ Mode simple a TOUTES les infos, manque compétence          │
│ ✅ Sous-tâche autonome avec contexte complet                │
└──────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────┐
│ FORME 3 : ESCALADE EXTERNE-CONTEXTUELLE                     │
│ ───────────────────────────────────────────                 │
│ Terminaison en échec avec rapport détaillé                  │
│ Mode manque contexte frais (même complex échouerait)       │
│ Orchestrateur parent mobilise contexte additionnel         │
└──────────────────────────────────────────────────────────────┘
```

---

### 2.1 ESCALADE INTERNE (switch_mode - RARE)

#### Principe

Le mode **simple** reconnaît qu'il manque de compétences pour continuer et **bascule explicitement** vers le mode **complex** équivalent **au sein de la même tâche**.

#### ⚠️ Pourquoi C'est RARE

```markdown
PROBLÈME : Risque incompatibilité contexte après switch
─────────────────────────────────────────────────────

Quand un mode simple switch vers complex :
1. Contexte actuel transféré (parfois incomplet)
2. Mode complex hérite historique conversations
3. Potentiel perte informations critiques
4. Difficulté reprendre contexte en cours

PRINCIPE GÉNÉRAL :
✅ Privilégier new_task() (Escalade Externe-Compétente)
❌ Éviter switch_mode sauf cas limites
```

#### Cas Limites Justifiant switch_mode

**Exception 1 : Trop d'informations à passer**

```markdown
Situation : Contexte dense impossible à résumer pour sous-tâche
- Historique 40+ messages avec dépendances complexes
- État intermédiaire critique difficilement transmissible
- Coût réécriture contexte > coût switch

Format :
<switch_mode>
<mode_slug>code-complex</mode_slug>
<reason>[ESCALADE INTERNE] Contexte trop dense pour sous-tâche :
- 45 messages contexte architectural critique
- État intermédiaire 8 fichiers modifiés partiellement
- Switch préférable à réécriture complète contexte
</reason>
</switch_mode>
```

**Exception 2 : Contexte saturé (voir section 3)**

#### Critères par Domaine

##### 💻 CODE (code-simple → code-complex)

**Seuils déclenchement** :
- ✅ Modifications > 50 lignes de code
- ✅ Refactorings architecture (>3 fichiers liés)
- ✅ Conception patterns avancés requis
- ✅ Optimisations performance complexes

**Format standardisé** :
```xml
<switch_mode>
<mode_slug>code-complex</mode_slug>
<reason>[ESCALADE INTERNE] Tâche dépasse capacités code-simple :
- Refactorisation architecture 65 lignes
- 4 composants interdépendants à restructurer
- Pattern Observer à implémenter
- Contexte 42k/60k impossible à résumer en sous-tâche
</reason>
</switch_mode>
```

##### 🪲 DEBUG (debug-simple → debug-complex)

**Seuils déclenchement** :
- ✅ Bugs système (race conditions, deadlocks)
- ✅ Problèmes performance nécessitant profiling
- ✅ Investigation multi-threads/async complexe
- ✅ Analyse mémoire (heap dumps)

**Format standardisé** :
```xml
<switch_mode>
<mode_slug>debug-complex</mode_slug>
<reason>[ESCALADE INTERNE] Debugging complexe requis :
- Race condition identifiée dans EventEmitter
- Investigation profiling 5+ composants concurrents
- Analyse thread-safe patterns nécessaire
- Contexte investigation 38k tokens dense
</reason>
</switch_mode>
```

##### 🏗️ ARCHITECT (architect-simple → architect-complex)

**Seuils déclenchement** :
- ✅ Architecture système complète multi-couches
- ✅ Patterns avancés (CQRS, Event Sourcing, DDD)
- ✅ Décisions architecturales majeures impact global
- ✅ Diagrammes UML complexes (séquence, état, collaboration)

**Format standardisé** :
```xml
<switch_mode>
<mode_slug>architect-complex</mode_slug>
<reason>[ESCALADE INTERNE] Architecture complexe nécessaire :
- Conception microservices 6 services interdépendants
- Patterns CQRS + Event Sourcing à intégrer
- Décisions impact global (choice messaging bus)
- Contexte architectural 40k tokens critique
</reason>
</switch_mode>
```

##### ❓ ASK (ask-simple → ask-complex)

**Seuils déclenchement** :
- ✅ Recherches approfondies multi-sources (>5 sources)
- ✅ Analyses comparatives techniques complexes
- ✅ Expertise domaine spécialisé requise
- ✅ Synthèses longues (>500 lignes)

**Format standardisé** :
```xml
<switch_mode>
<mode_slug>ask-complex</mode_slug>
<reason>[ESCALADE INTERNE] Recherche approfondie requise :
- Analyse comparative 12 frameworks ML
- Synthèse 8 sources académiques
- Expertise deep learning spécialisée nécessaire
- Contexte recherche 35k tokens accumulé
</reason>
</switch_mode>
```

---

### 2.2 ESCALADE EXTERNE-COMPÉTENTE (new_task mode Complex "Oracle")

#### Principe

Le mode **simple** possède **TOUTES les informations** nécessaires MAIS **manque de compétences techniques** pour les exploiter → Crée sous-tâche vers mode **complex** qui agira comme **"Oracle/Référent"** plus compétent.

#### Avantages Majeurs

```markdown
✅ Évite incompatibilité contexte (nouvelle tâche fraîche)
✅ Instructions complètes + autonomie sous-tâche
✅ Traçabilité améliorée (todo lists SDDD)
✅ Grounding sémantique optimisé
```

#### Format Standardisé

```xml
<new_task>
<mode>code-complex</mode>
<message>🎯 **Sous-tâche 1.2 : Implémentation Pattern Observer Complex**

**Contexte Escalade** : code-simple identifie besoin expertise patterns avancés.

**Situation Actuelle** :
- Système événements simple implémenté (EventEmitter basique)
- Besoin Observer pattern avec features avancées :
  * Gestion priorités événements
  * Filtrage dynamique observateurs
  * Weak references pour éviter memory leaks
  * Support async handlers

**Informations Complètes Disponibles** :
- Architecture actuelle : [diagramme classes]
- API publique définie : subscribe(), unsubscribe(), notify()
- Tests unitaires existants : 12 tests à adapter
- Performance requirements : <10ms latency

**Besoin Compétence Complex** :
- Conception pattern Observer avancé
- Gestion weak references TypeScript
- Optimisations performance événements
- Architecture extensible futures évolutions

**Livrables Attendus** :
1. ObserverPattern.ts implémenté
2. Tests unitaires 100% coverage
3. Documentation patterns utilisés
4. Benchmarks performance

**Fichiers Concernés** :
- src/events/ObserverPattern.ts (création)
- src/tests/ObserverPattern.test.ts (création)
- src/events/EventEmitter.ts (migration)

[ESCALADE EXTERNE-COMPÉTENTE] Mode simple a toutes infos, manque expertise patterns avancés.
</message>
</new_task>
```

#### Critères par Domaine

##### 💻 CODE

**Situations typiques** :
- Architecture complexe à concevoir (>3 couches)
- Patterns avancés (Factory, Strategy, Observer, etc.)
- Optimisations algorithmes (complexité O(n²) → O(n log n))
- Intégrations systèmes externes sophistiquées

**Exemple** :
```xml
<new_task>
<mode>code-complex</mode>
<message>🎯 **Sous-tâche 2.1 : Optimisation Algorithme Recherche**

**Contexte** : Recherche linéaire O(n) identifiée comme bottleneck.

**Informations Disponibles** :
- Dataset : 100k+ éléments
- Pattern accès : 80% recherches répétées
- Contraintes : Insertion occasionnelle (5% ops)
- Mesures actuelles : 850ms moyenne recherche

**Besoin Expertise** :
- Choisir structure données optimale (B-Tree, Hash, Trie?)
- Implémenter algorithme O(log n)
- Gérer cache recherches fréquentes
- Benchmarks comparatifs

[ESCALADE EXTERNE-COMPÉTENTE] Besoin expertise algorithmes + structures données.
</message>
</new_task>
```

##### 🪲 DEBUG

**Situations typiques** :
- Debugging système concurrent (race conditions)
- Investigation memory leaks profiling
- Analyse performance critique
- Problèmes réseau/sécurité complexes

**Exemple** :
```xml
<new_task>
<mode>debug-complex</mode>
<message>🎯 **Sous-tâche 1.3 : Investigation Race Condition Worker Pool**

**Symptôme Identifié** :
- Tests flaky (3/50 échecs aléatoires)
- Deadlock sporadique worker pool
- Logs : "Promise never resolved" (5% des cas)

**Contexte Complet** :
- Worker pool : 4 threads, queue 1000 items
- Pattern : Promise.all() avec timeout 30s
- Repro : Charge >500 requêtes/s

**Besoin Expertise Debug Complex** :
- Analyse concurrence thread-safe
- Profiling race conditions
- Solutions synchronisation avancées
- Tests reproductibilité

[ESCALADE EXTERNE-COMPÉTENTE] Besoin expertise debugging concurrent.
</message>
</new_task>
```

##### 🏗️ ARCHITECT

**Situations typiques** :
- Décisions architecturales majeures (choix tech stack)
- Conception systèmes distribués
- Patterns architecturaux avancés (CQRS, Event Sourcing)
- Diagrammes UML complexes multi-vues

**Exemple** :
```xml
<new_task>
<mode>architect-complex</mode>
<message>🎯 **Sous-tâche 3.1 : Architecture Microservices Scaling**

**Contexte** : Monolithe atteint limites (500k users).

**Informations Architecture Actuelle** :
- Stack : Node.js, PostgreSQL, Redis
- Bottlenecks : Auth service (80% CPU), DB writes
- Requirements : 2M users, 5k req/s, 99.9% uptime

**Besoin Expertise Architecture** :
- Décomposition microservices (6-8 services)
- Stratégie communication (REST, gRPC, Events?)
- Patterns resilience (Circuit Breaker, Bulkhead)
- Data consistency (Saga pattern?)

**Livrables** :
- Architecture diagram C4 (Context, Container, Component)
- Décisions architecturales documentées (ADRs)
- Migration plan phased

[ESCALADE EXTERNE-COMPÉTENTE] Besoin expertise architecture distribuée.
</message>
</new_task>
```

##### ❓ ASK

**Situations typiques** :
- Recherche approfondie multi-sources académiques
- Analyse comparative technologies complexe
- Expertise domaine spécialisé (ML, crypto, etc.)
- Synthèse documentaire longue

**Exemple** :
```xml
<new_task>
<mode>ask-complex</mode>
<message>🎯 **Sous-tâche 4.1 : Analyse Comparative Frameworks ML Production**

**Contexte** : Choix framework ML pour déploiement production.

**Critères Évaluation** :
- Performance inference (<100ms)
- Scalability (>10k req/s)
- Ecosystem (pre-trained models)
- Coût infrastructure

**Candidats** : TensorFlow Serving, TorchServe, ONNX Runtime, Triton

**Besoin Expertise** :
- Analyse benchmarks multi-sources
- Expertise ML ops
- Trade-offs architecturaux
- Retours expérience production

**Livrable** : Rapport comparatif 500+ lignes avec recommandation argumentée.

[ESCALADE EXTERNE-COMPÉTENTE] Besoin expertise ML production.
</message>
</new_task>
```

---

### 2.3 ESCALADE EXTERNE-CONTEXTUELLE (Terminaison en Échec + Rapport)

#### Principe

La tâche **dépasse la capacité contextuelle** du mode actuel. Même un mode **complex** échouerait avec le niveau de contexte disponible. Le mode termine en **échec contrôlé** avec un **rapport détaillé** permettant à l'**orchestrateur parent** de mobiliser son **contexte additionnel** ou d'**escalader lui-même** pour décision stratégique avec retour utilisateur.

#### Caractéristiques

```markdown
✅ Mode manque contexte frais (pas compétences)
✅ Même mode complex échouerait
✅ Orchestrateur parent a vue d'ensemble
✅ Besoin décision stratégique utilisateur possible
```

#### Format Standardisé : Terminaison avec Rapport

```markdown
## 🚨 ESCALADE EXTERNE-CONTEXTUELLE : Terminaison Tâche

**Statut** : ⚠️ Semi-Échec - Nécessite Intervention Orchestrateur Parent

### Situation

La tâche actuelle a atteint ses limites contextuelles. Les informations disponibles sont insuffisantes pour décider de la meilleure approche, même avec un mode complex.

### Travaux Réalisés

[Liste actions accomplies avant échec]
1. Analyse architecture actuelle complète
2. Identification 3 options architecturales possibles
3. Recherche patterns similaires (5 projets analysés)

### Point de Blocage

**Décision Stratégique Requise** :
- Choix entre Option A (microservices) vs Option B (modular monolith)
- Impact global système non évaluable avec contexte actuel
- Trade-offs nécessitent contexte business additionnel

### Informations Manquantes (Contexte Frais Requis)

1. **Budget Infrastructure** : Cloud costs microservices vs monolith
2. **Timeline** : Contraintes déploiement Q2/Q3
3. **Équipe** : Compétences DevOps disponibles
4. **Stratégie Business** : Roadmap produit 12 mois

### Options Architecturales Identifiées

**Option A : Microservices (6 services)**
- Pros : Scalability, isolation, tech diversity
- Cons : Complexité ops, coûts infra +40%
- Effort : 3 mois, 2 DevOps requis

**Option B : Modular Monolith**
- Pros : Simplicité ops, migration progressive
- Cons : Scaling limité, couplage modéré
- Effort : 1.5 mois, équipe actuelle suffit

**Option C : Hybrid (Core monolith + 2 microservices critiques)**
- Pros : Compromis pragmatique
- Cons : Complexité architecture mixte
- Effort : 2 mois

### Instructions pour Orchestrateur Parent

**Action Recommandée** :
1. Mobiliser contexte business additionnel (budget, timeline, équipe)
2. Consulter utilisateur pour décision stratégique
3. Réinstruire architect-complex avec :
   - Option choisie
   - Contraintes validées
   - Priorisation features impactées

**Ou Alternative** :
- Escalader vers utilisateur pour décision executive
- Créer task ask-complex pour analyse coûts détaillée
- Workshop équipe technique pour consensus

### Fichiers de Contexte

- `docs/architecture-analysis.md` (analyse complète)
- `docs/options-comparison.md` (matrice décision)
- `docs/research-patterns.md` (patterns similaires analysés)

---

**[ESCALADE EXTERNE-CONTEXTUELLE]** Cette tâche nécessite contexte additionnel et décision stratégique que seul orchestrateur parent ou utilisateur peut fournir.
```

#### Quand Utiliser

**Situations typiques** :
- ✅ Décisions business impactant architecture
- ✅ Contraintes externes inconnues (budget, timeline, équipe)
- ✅ Trade-offs nécessitant arbitrage utilisateur
- ✅ Contexte multi-projets (orchestrateur a vue globale)
- ✅ Investigation révèle problème systémique hors scope

**Critères déclenchement** :
```markdown
SI (
  informations_disponibles < informations_requises_décision
  OU
  décision_impacte_hors_scope_tâche
  OU
  arbitrage_utilisateur_nécessaire
)
ALORS → Escalade Externe-Contextuelle
```

---

## 🚨 3. Exception Contexte Saturé

### Règle Critique

```markdown
🔴 RÈGLE : Contexte > 80% (SEUIL_AJUSTABLE)
───────────────────────────────────────────

Action : Switch vers orchestrateur MÊME NIVEAU
- orchestrator si mode simple
- orchestrator si mode complex

Justification :
- Éviter création sous-tâche héritant contexte saturé
- Orchestrateur décompose avec contexte frais
- Prévenir dépassement limite tokens
```

### Format Standardisé

```xml
<switch_mode>
<mode_slug>orchestrator</mode_slug>
<reason>[CONTEXTE SATURÉ 82%] Switch orchestrateur pour décomposition :
- Contexte actuel : 49.2k/60k tokens (82%)
- Tâche restante décomposable en 4 sous-tâches
- Orchestrateur gérera avec contexte frais
- Prévention dépassement limite tokens
</reason>
</switch_mode>
```

### Seuil Ajustable

```markdown
**Configuration** :
const CONTEXT_SATURATION_THRESHOLD = 0.80; // 80% par défaut

**Ajustements possibles** :
- 0.75 (75%) : Conservative, early orchestration
- 0.80 (80%) : Balanced (défaut)
- 0.85 (85%) : Aggressive, maximize context use

**Détection** :
current_tokens / max_tokens >= CONTEXT_SATURATION_THRESHOLD
```

### Pourquoi Orchestrateur MÊME NIVEAU

```markdown
Cas 1 : Mode Simple Sature
──────────────────────────
code-simple (48k/60k) → orchestrator (pas orchestrator-complex)
Raison : Décomposition tâches simples suffit

Cas 2 : Mode Complex Sature
────────────────────────────
architect-complex (55k/60k) → orchestrator (pas orchestrator-simple)
Raison : Coordination tâches complexes requise

Principe : Orchestrateur adapte niveau complexité sous-tâches
```

---

## ✅ 4. Principe Général : Privilégier new_task()

### Règle d'Or

```markdown
╔════════════════════════════════════════════════════════════╗
║  TOUJOURS PRIVILÉGIER new_task() PLUTÔT QUE switch_mode() ║
╚════════════════════════════════════════════════════════════╝

Raisons :
1. ✅ Éviter incompatibilités contexte
2. ✅ Agrandir todo lists (essentielles grounding SDDD)
3. ✅ Instructions guidées traçables
4. ✅ Atomisation tâches simples primitives
5. ✅ Permet décomposition, pas juste escalade
```

### Bénéfices Grounding SDDD

#### Todo Lists Agrandies

```markdown
PROBLÈME switch_mode :
─────────────────────
- Pas de todo list créée
- Pas d'étape intermédiaire tracée
- Grounding sémantique appauvri
- Historique conversations confus

SOLUTION new_task() :
─────────────────────
✅ Nouvelle entrée todo list Roo
✅ Grounding sémantique renforcé
✅ Traçabilité complète workflow
✅ Reprises conversations facilitées
```

#### Instructions Guidées Complètes

```markdown
new_task() force à :
───────────────────
1. Documenter contexte hérité
2. Spécifier objectif précis
3. Lister fichiers concernés
4. Définir critères validation
5. Préciser livrables attendus

→ Sous-tâche autonome + SDDD compatible
```

### Quand switch_mode Est Justifié (Rare)

**Exception 1 : Contexte trop dense**
```markdown
Situation : 40+ messages contexte architectural critique
Coût : Réécriture complète contexte > Switch
Action : switch_mode avec justification explicite
```

**Exception 2 : Contexte saturé >80%**
```markdown
Situation : 49k/60k tokens, tâche continue
Risque : Sous-tâche hériterait contexte saturé
Action : switch_mode vers orchestrateur même niveau
```

**Exception 3 : État intermédiaire critique**
```markdown
Situation : 8 fichiers modifiés partiellement, état transitoire
Risque : Perte cohérence si transmission partielle
Action : switch_mode pour préserver état complet
```

---

## 🚫 5. Anti-Patterns

### 5.1 Confusion Escalade vs Décomposition

#### ❌ Anti-Pattern : Appeler "escalade" la décomposition

```markdown
ERREUR :
───────
"J'escalade cette lecture de 15 fichiers vers code-simple"

PROBLÈME :
- code-complex → code-simple n'est PAS une escalade
- Raison : économie contexte, pas manque compétences
- Mécanisme correct : DÉCOMPOSITION

CORRECT :
────────
"Je décompose cette lecture batch en sous-tâche pour économiser contexte"
```

#### ✅ Pattern Correct

```xml
<new_task>
<mode>code-simple</mode>
<message>🎯 **Sous-tâche 1.4 : Lecture Batch Configuration Files**

[DÉCOMPOSITION ÉCONOMIE CONTEXTE] Délégation lecture lourde pour préserver contexte analysis.

**Objectif** : Lire 15 fichiers JSON configurations.
**Utiliser** : quickfiles MCP pour efficacité
**Livrable** : JSON agrégé configurations

[CE N'EST PAS UNE ESCALADE - DÉCOMPOSITION]
</message>
</new_task>
```

### 5.2 Confusion Escalade vs Délégation

#### ❌ Anti-Pattern : Appeler "escalade" la délégation

```markdown
ERREUR :
───────
"J'escalade l'implémentation des tests vers code-simple"

PROBLÈME :
- orchestrator → code-simple n'est PAS une escalade
- orchestrator n'est pas "simple", code n'est pas "complex"
- Raison : spécialisation, pas manque compétences orchestrator
- Mécanisme correct : DÉLÉGATION

CORRECT :
────────
"Je délègue l'implémentation des tests au mode code spécialisé"
```

#### ✅ Pattern Correct

```xml
<new_task>
<mode>code-simple</mode>
<message>🎯 **Sous-tâche 2.3 : Implémentation Tests Unitaires AuthService**

[DÉLÉGATION SPÉCIALISATION] Orchestrateur délègue implémentation au mode code spécialisé.

**Contexte** : Architecture AuthService définie
**Spécification Tests** :
- Test 1 : login() success case
- Test 2 : login() invalid credentials
- Test 3 : refreshToken() valid
- Test 4 : logout() cleanup

[CE N'EST PAS UNE ESCALADE - DÉLÉGATION]
</message>
</new_task>
```

### 5.3 Switch_mode Systématique

#### ❌ Anti-Pattern : Switch au lieu de new_task

```markdown
ERREUR :
───────
<switch_mode>
<mode_slug>code-complex</mode_slug>
<reason>Cette tâche est complexe</reason>
</switch_mode>

PROBLÈME :
- Perte contexte potentielle
- Pas de todo list créée
- Grounding SDDD appauvri
- Traçabilité réduite

CORRECT (sauf exceptions) :
───────────────────────────
<new_task>
<mode>code-complex</mode>
<message>[Instructions complètes + contexte]</message>
</new_task>
```

### 5.4 Sous-tâche Sans Instructions SDDD

#### ❌ Anti-Pattern : Instructions incomplètes

```markdown
ERREUR :
───────
<new_task>
<mode>code-complex</mode>
<message>Implémente le pattern Observer</message>
</new_task>

PROBLÈME :
- Pas de contexte hérité
- Objectif flou
- Pas de critères validation
- Mode enfant perdu
```

#### ✅ Pattern Correct SDDD

```xml
<new_task>
<mode>code-complex</mode>
<message>🎯 **Sous-tâche 1.2 : Implémentation Pattern Observer**

**Contexte Hérité** :
- EventEmitter basique existant
- API publique définie
- 12 tests unitaires à adapter

**Objectif Précis** :
Observer pattern avec :
1. Gestion priorités
2. Filtrage dynamique
3. Weak references
4. Async handlers support

**Critères Validation** :
- Tests 100% coverage
- Benchmarks <10ms latency
- Documentation patterns

**Fichiers** :
- src/events/ObserverPattern.ts (création)
- src/tests/ObserverPattern.test.ts (création)

**Grounding SDDD** :
1. codebase_search "observer pattern implementation"
2. Checkpoint 50k tokens
3. Documentation décisions design
</message>
</new_task>
```

### 5.5 Quand Utiliser Chaque Mécanisme

```markdown
╔═══════════════════════════════════════════════════════════╗
║  DÉCISION TREE : Quel Mécanisme Utiliser ?              ║
╚═══════════════════════════════════════════════════════════╝

Question 1 : Manque de COMPÉTENCES pour continuer ?
├─ OUI → C'est une ESCALADE
│  ├─ Contexte >80% ? → switch_mode orchestrateur
│  ├─ Contexte dense impossible résumer ? → switch_mode complex
│  └─ Sinon → new_task mode complex (privilégié)
│
└─ NON → Ce N'EST PAS une escalade
   │
   Question 2 : Pourquoi créer sous-tâche ?
   ├─ Économie contexte → DÉCOMPOSITION (new_task)
   ├─ Besoin expertise → DÉLÉGATION (new_task)
   ├─ Coordination multi-étapes → ORCHESTRATION (new_task)
   └─ Tâche simple atomique → DÉLÉGATION (new_task)
```

---

## 📊 6. Critères par Domaine

### Vue d'Ensemble Critères Escalade

| Domaine | Seuil Quantitatif | Seuil Qualitatif | Indicateur Clé |
|---------|-------------------|------------------|----------------|
| **CODE** | >50 lignes | Architecture majeure | Patterns avancés requis |
| **DEBUG** | >3 fichiers | Race conditions | Profiling nécessaire |
| **ARCHITECT** | >4 composants | Décision stratégique | Patterns distribués |
| **ASK** | >5 sources | Expertise domaine | Recherche académique |

### 6.1 CODE : Critères Détaillés

#### Escalade code-simple → code-complex

**Critères Quantitatifs** :
```markdown
✅ Modifications > 50 lignes code
✅ Refactorings > 3 fichiers liés
✅ Création > 5 nouvelles classes/modules
✅ Tests > 20 cas tests complexes
```

**Critères Qualitatifs** :
```markdown
✅ Architecture nouvelle à concevoir
✅ Patterns avancés (Factory, Strategy, Observer, Builder, etc.)
✅ Optimisations algorithmes (O(n²) → O(n log n))
✅ Intégrations systèmes externes sophistiquées
✅ Gestion états complexes (FSM, workflows)
```

**Exemples Situations** :
```markdown
Escalade Justifiée :
──────────────────
- Refactorisation architecture MVC → MVVM (65 lignes, 4 fichiers)
- Implémentation cache LRU multi-niveaux (algorithme O(1))
- Système plugins dynamiques avec dépendances
- Migration async/await avec gestion erreurs sophistiquée

Décomposition (PAS escalade) :
──────────────────────────────
- Lecture batch 15 fichiers (économie contexte)
- Formatage code 10 fichiers (tâche répétitive)
- Tests unitaires basiques (spécialisation simple)
```

### 6.2 DEBUG : Critères Détaillés

#### Escalade debug-simple → debug-complex

**Critères Quantitatifs** :
```markdown
✅ Investigation > 3 fichiers impactés
✅ Reproduction nécessite > 5 étapes
✅ Logs à analyser > 1000 lignes
✅ Profiling > 3 composants concurrents
```

**Critères Qualitatifs** :
```markdown
✅ Race conditions, deadlocks système
✅ Memory leaks nécessitant heap dump analysis
✅ Performance bottlenecks complexes
✅ Bugs concurrence (multi-threads, async)
✅ Problèmes réseau/sécurité sophistiqués
```

**Exemples Situations** :
```markdown
Escalade Justifiée :
──────────────────
- Deadlock worker pool (4 threads, investigation concurrence)
- Memory leak croissance linéaire (profiling V8 heap)
- Performance dégradation 10x charge (analyse multi-composants)
- Bug sporadique tests flaky (race condition 5% repro)

Décomposition (PAS escalade) :
──────────────────────────────
- Typo variable name (bug évident)
- Import manquant (1 ligne fix)
- Validation input manquante (pattern simple)
```

### 6.3 ARCHITECT : Critères Détaillés

#### Escalade architect-simple → architect-complex

**Critères Quantitatifs** :
```markdown
✅ Architecture > 4 composants interdépendants
✅ Diagrammes UML > 3 vues (class, sequence, deployment)
✅ Décisions impactant > 5 modules
✅ Documentation > 200 lignes ADRs
```

**Critères Qualitatifs** :
```markdown
✅ Architecture système complète (microservices, distributed)
✅ Patterns avancés (CQRS, Event Sourcing, Saga, DDD)
✅ Décisions stratégiques impact global
✅ Conceptions haute disponibilité (99.9%+ uptime)
✅ Intégrations multi-systèmes complexes
```

**Exemples Situations** :
```markdown
Escalade Justifiée :
──────────────────
- Architecture microservices 6 services (communication, data consistency)
- Système distribué event-driven (CQRS + Event Sourcing)
- Migration monolith → modular architecture (ADRs multiples)
- Conception haute dispo (Circuit Breaker, Bulkhead, Retry)

Décomposition (PAS escalade) :
──────────────────────────────
- Diagramme classe simple (3 classes)
- Documentation API endpoints (tâche documentaire)
- Revue code architecture existante (analyse)
```

### 6.4 ASK : Critères Détaillés

#### Escalade ask-simple → ask-complex

**Critères Quantitatifs** :
```markdown
✅ Recherche > 5 sources distinctes
✅ Analyse comparative > 10 solutions
✅ Synthèse > 500 lignes documentation
✅ Vérifications croisées > 3 domaines
```

**Critères Qualitatifs** :
```markdown
✅ Recherche académique approfondie
✅ Expertise domaine spécialisé (ML, crypto, quantum, etc.)
✅ Analyses comparatives techniques complexes
✅ Synthèses multi-sources avec contradictions
✅ Questions nécessitant état de l'art complet
```

**Exemples Situations** :
```markdown
Escalade Justifiée :
──────────────────
- Analyse comparative 12 frameworks ML production
- Recherche état de l'art quantum computing applications
- Synthèse sécurité blockchain (académique + industry)
- Expertise domain-specific (genomics algorithms)

Décomposition (PAS escalade) :
──────────────────────────────
- Recherche documentation API unique
- Explication concept simple (REST, JSON)
- Synthèse article unique (résumé)
```

---

## 📋 7. Tableaux Comparatifs

### 7.1 Tableau Récapitulatif : 3 Formes Escalade

| Forme | Direction | Mécanisme | Mode a Infos? | Contexte Hérité | Quand Utiliser |
|-------|-----------|-----------|---------------|-----------------|----------------|
| **Interne** | Simple → Complex | `switch_mode` (rare) | ✅ Oui (dense) | Complet (même tâche) | Contexte impossible résumer |
| **Externe-Compétente** | Simple → Complex | `new_task` Oracle | ✅ Oui (toutes) | Complet (instructions) | Manque compétence technique |
| **Externe-Contextuelle** | Échec → Parent | Terminaison + Rapport | ❌ Non (manque) | Synthèse + Lacunes | Manque contexte frais |

### 7.2 Matrice Décision : Mécanisme à Utiliser

| Situation | Mécanisme | Direction | Outil | Justification |
|-----------|-----------|-----------|-------|---------------|
| Manque compétences + Infos complètes | **Escalade Externe-Compétente** | Simple → Complex | `new_task` | Mode complex "Oracle" autonome |
| Manque compétences + Contexte dense | **Escalade Interne** | Simple → Complex | `switch_mode` | Coût réécriture > switch |
| Manque contexte frais | **Escalade Externe-Contextuelle** | Échec → Parent | Terminaison | Orchestrateur mobilise contexte |
| Économie contexte | **Décomposition** | Any → Any | `new_task` | Atomisation tâches |
| Besoin expertise | **Délégation** | Any → Specialist | `new_task` | Spécialisation domaine |
| Coordination multi-étapes | **Orchestration** | Any → Orchestrator | `new_task` | Workflow complexe |
| Contexte >80% saturé | **Exception Saturation** | Any → Orchestrator | `switch_mode` | Prévention dépassement |

### 7.3 Comparaison Escalade vs Autres Mécanismes

| Critère | Escalade | Décomposition | Délégation | Orchestration |
|---------|----------|---------------|------------|---------------|
| **Définition** | Manque compétences | Économie contexte | Spécialisation | Coordination |
| **Trigger** | Tâche dépasse capacités | Contexte >50% | Besoin expert | Workflow >5 étapes |
| **Direction** | Simple → Complex | Any → Any (souvent Same) | Any → Specialist | Any → Orchestrator |
| **Signature** | Montée compétence | Atomisation | Expertise ciblée | Multi-étapes |
| **Contexte hérité** | Partiel/Complet | Minimal | Complet | Synthèse |
| **Todo List** | ✅ Si new_task | ✅ Toujours | ✅ Toujours | ✅ Toujours |
| **Grounding SDDD** | ✅ Si new_task | ✅ Renforcé | ✅ Renforcé | ✅ Renforcé |
| **Fréquence** | 10-20% cas | 40-50% cas | 30-40% cas | 5-10% cas |

### 7.4 Critères Déclenchement par Domaine

| Domaine | Escalade Interne (Rare) | Escalade Externe-Compétente (Privilégié) | Escalade Externe-Contextuelle |
|---------|------------------------|------------------------------------------|-------------------------------|
| **CODE** | >50 lignes + contexte dense | Architecture majeure, patterns avancés | Décision tech stack, contraintes externes |
| **DEBUG** | Bugs <3 fichiers + investigation dense | Race conditions, profiling complexe | Problème systémique hors scope |
| **ARCHITECT** | Diagrammes simples + historique riche | Patterns distribués, décisions stratégiques | Contraintes business, arbitrage utilisateur |
| **ASK** | Synthèse <300 lignes + recherche dense | Expertise domaine, recherche académique | Décision impact global, consensus équipe |

---

## 📚 8. Ressources Complémentaires

### Documents de Référence

#### Mécanismes Connexes

- **[`context-economy-patterns.md`](context-economy-patterns.md)** : Patterns décomposition et économie contexte
  * Stratégies atomisation tâches
  * Utilisation MCPs pour efficacité
  * Délégation vs Escalade

- **[`hierarchie-numerotee-subtasks.md`](hierarchie-numerotee-subtasks.md)** : Système numérotation sous-tâches
  * Format : `1` (racine), `1.1`, `1.1.1` (descendants)
  * `new_task()` universel (tous modes)
  * Traçabilité arborescente

#### Protocoles SDDD

- **[`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md)** : Grounding sémantique obligatoire
  * Phase 1 : `codebase_search` AVANT toute exploration
  * Phase 2 : Checkpoints 50k tokens (critère escalade contextuelle)
  * Phase 3 : Validation sémantique finale

#### Intégrations Techniques

- **[`mcp-integrations-priority.md`](mcp-integrations-priority.md)** : Utilisation MCPs pour efficacité
  * quickfiles : Lectures batch optimisées
  * roo-state-manager : Contexte historique tâches
  * jinavigator : Extraction web markdown
  * Patterns usage dans sous-tâches

### Factorisation Commons

- **[`factorisation-commons.md`](factorisation-commons.md)** : Sections communes modes
  * Templates mécaniques escalade par famille
  * Intégration instructions modes
  * Critères spécifiques CODE, DEBUG, ARCHITECT, ASK

---

## 🎯 Synthèse Finale

### Principes Directeurs

```markdown
╔═══════════════════════════════════════════════════════════════╗
║  LES 5 PRINCIPES D'OR DES MÉCANIQUES D'ESCALADE             ║
╚═══════════════════════════════════════════════════════════════╝

1. DÉFINITION STRICTE
   Escalade = Simple → Complex (manque compétences)
   Ce n'est PAS décomposition/délégation/orchestration

2. PRIVILÉGIER new_task()
   Toujours préférer sous-tâches à switch_mode
   Sauf : Contexte >80% OU Contexte trop dense

3. 3 FORMES UNIQUEMENT
   - Interne : switch_mode (rare)
   - Externe-Compétente : new_task Oracle (privilégié)
   - Externe-Contextuelle : Terminaison échec + rapport

4. GROUNDING SDDD ESSENTIEL
   new_task() agrandit todo lists Roo
   Instructions complètes SDDD-compatibles
   Traçabilité + reprises facilitées

5. EXCEPTION CONTEXTE SATURÉ
   >80% tokens → switch_mode orchestrateur même niveau
   Prévenir héritage contexte saturé
```

### Checklist Décision Escalade

```markdown
AVANT DE DÉCIDER DU MÉCANISME :
─────────────────────────────────

□ Est-ce vraiment un manque de COMPÉTENCES ?
  └─ NON → Ce n'est PAS une escalade (décomposition/délégation)
  └─ OUI → Continue checklist

□ Le mode simple a-t-il TOUTES les informations ?
  └─ OUI → Escalade Externe-Compétente (new_task complex)
  └─ NON → Escalade Externe-Contextuelle (terminaison rapport)

□ Le contexte est-il >80% saturé ?
  └─ OUI → Exception : switch_mode orchestrateur
  └─ NON → Continue checklist

□ Le contexte est-il impossible à résumer ?
  └─ OUI → Exception : switch_mode complex (justifié)
  └─ NON → Utiliser new_task() (privilégié)

□ Instructions SDDD complètes préparées ?
  └─ Contexte hérité, objectif, critères, fichiers, grounding
```

---

**Version** : 3.0.0  
**Dernière mise à jour** : 01 Octobre 2025  
**Révision majeure** : Clarification définition stricte escalade vs autres mécanismes suite feedbacks utilisateur  
**Statut** : ✅ Validé - Prêt pour intégration instructions modes