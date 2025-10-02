# 🔢 Hiérarchie Numérotée Systématique - Traçabilité Sous-tâches

**Version :** 2.0.0  
**Date :** 02 Octobre 2025  
**Architecture :** 2-Niveaux (Simple/Complex)  
**Statut :** ✅ Spécification consolidée post-feedback FB-03  
**Révision majeure** : Universalisation `new_task()` + Format numérotation simplifié

---

## 📖 Table des Matières

1. [Objectif du Système](#-objectif-du-système)
2. [Universalité de new_task()](#-universalité-de-new_task---tous-les-modes)
3. [Format Standard de Numérotation](#-format-standard-de-numérotation)
4. [Cas d'Usage new_task() par Mode](#-cas-dusage-new_task-par-mode)
5. [Conventions de Présentation](#-conventions-de-présentation)
6. [Intégration avec new_task()](#-intégration-avec-new_task)
7. [Synchronisation avec roo-state-manager](#-synchronisation-avec-roo-state-manager)
8. [Patterns d'Orchestration](#-patterns-dorchestration)
9. [Templates Instructions Modes](#-templates-instructions-modes)
10. [Recherche et Navigation](#-recherche-et-navigation)
11. [Métriques et Reporting](#-métriques-et-reporting)
12. [Anti-Patterns à Éviter](#️-anti-patterns-à-éviter)
13. [Bénéfices du Système](#-bénéfices-du-système)
14. [Ressources Complémentaires](#-ressources-complémentaires)

---

## 🎯 Objectif du Système

Le système de hiérarchie numérotée garantit :
1. **Traçabilité complète** : Chaque sous-tâche identifiable uniquement
2. **Navigation intuitive** : Compréhension structure arborescente immédiate
3. **Synchronisation MCP** : Correspondance avec [`roo-state-manager`](../../../mcps/internal/servers/roo-state-manager/) tree
4. **Orchestration efficace** : Gestion dépendances et parallélisation

---

## 🔓 Universalité de new_task() - Tous les Modes

### Principe Fondamental

> **TOUS les modes** ont accès à l'outil `new_task()` pour créer des sous-tâches, **pas seulement les orchestrateurs**.

Cette universalité permet :
- ✅ **Décomposition** : Économie contexte (atomisation tâches lourdes)
- ✅ **Escalade** : Manque compétences (délégation mode plus capable)
- ✅ **Spécialisation** : Délégation expertise (tâche nécessite mode spécialisé)
- ✅ **Parallélisation** : Coordination (orchestration multi-domaines)

### Distinction Usage : Orchestrateurs vs Modes Simples

```
┌─────────────────────────────────────────────────────────────────┐
│ ORCHESTRATEURS (architect, orchestrator)                       │
│ ───────────────────────────────────────────                    │
│ Usage PRINCIPAL : Coordination multi-domaines                  │
│ - Décomposition systématique tâches complexes                  │
│ - Coordination parallèle sous-tâches                           │
│ - Grounding délégué (cf. SDDD protocol)                        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ MODES SIMPLES (code, debug, ask)                               │
│ ─────────────────────────────                                  │
│ Usage TACTIQUE : Cas d'usage spécifiques                       │
│ - Économie contexte (actions lourdes)                          │
│ - Escalade (manque compétences)                                │
│ - Spécialisation (délégation expertise)                        │
└─────────────────────────────────────────────────────────────────┘
```

### Justification Universalisation

**Pourquoi restreindre `new_task()` serait contre-productif :**

1. **Mode simple saturé en contexte** → Besoin créer sous-tâche légère
2. **Mode simple manque compétences** → Besoin escalader vers mode complex
3. **Tâche nécessite expertise** → Besoin déléguer à mode spécialisé (ex: architect → code pour tests)
4. **Action consommatrice tokens** → Besoin décomposer pour économie contexte

**Exemples concrets** :
- [`code-simple`](code-simple) crée sous-tâche [`code-complex`](code-complex) pour architecture avancée (**escalade**)
- [`debug-simple`](debug-simple) crée sous-tâche [`debug-simple`](debug-simple) pour profiling lourd (**décomposition**)
- [`architect-simple`](architect-simple) crée sous-tâche [`code-simple`](code-simple) pour prototypage (**spécialisation**)
- [`ask-simple`](ask-simple) crée sous-tâche [`ask-complex`](ask-complex) pour recherche approfondie (**escalade**)

---

## 📐 Format Standard de Numérotation

### Structure de Base

```
[TÂCHE_PRINCIPALE].[NIVEAU_1].[NIVEAU_2].[NIVEAU_3]

Exemples :
1           → Tâche principale (racine)
1.1         → Première sous-tâche niveau 1
1.1.1       → Première sous-tâche niveau 2 de 1.1
1.1.1.1     → Première sous-tâche niveau 3 de 1.1.1
1.2         → Deuxième sous-tâche niveau 1
1.2.1       → Première sous-tâche niveau 2 de 1.2
```

### Règles de Composition

**Tâche Principale** : `X`
- X = Numéro séquentiel projet (1, 2, 3, ...)
- **Pas de `.0`** : Redondant, évident que c'est la racine

**Sous-tâches Niveau 1** : `X.Y`
- X = Numéro tâche principale
- Y = Incrémentation sous-tâche (1, 2, 3, ...)

**Sous-tâches Niveau 2** : `X.Y.Z`
- Z = Incrémentation sous-sous-tâche

**Sous-tâches Niveau 3+** : `X.Y.Z.A.B...`
- Continuation incrémentation pour profondeur >3

### Exemples Arborescences

```
1           Mission principale
├── 1.1     Phase préparation
├── 1.2     Phase implémentation
│   ├── 1.2.1   Module A
│   └── 1.2.2   Module B
└── 1.3     Phase validation
```

---

## 🎨 Cas d'Usage new_task() par Mode

### Vue d'Ensemble par Famille

| Famille | Usage Principal | Fréquence | Cas Typiques |
|---------|----------------|-----------|--------------|
| **ORCHESTRATOR** | Coordination multi-domaines | 80-90% | Décomposition systématique, workflows complexes |
| **CODE** | Économie contexte + Escalade | 40-50% | Implémentations lourdes, architectures avancées |
| **DEBUG** | Spécialisation + Économie | 30-40% | Profiling, investigation multi-fichiers |
| **ARCHITECT** | Spécialisation + Validation | 50-60% | Prototypage, implémentation déléguée |
| **ASK** | Escalade + Recherche approfondie | 20-30% | Expertise domaine, recherches académiques |

---

### 1️⃣ MODE CODE : Implémentation et Refactoring

#### Cas d'Usage A : Économie Contexte (Décomposition)

**Situation** : [`code-simple`](code-simple) atteint 45k tokens avec lecture 15 fichiers → Besoin déléguer actions lourdes

```xml
<new_task>
<mode>code-simple</mode>
<message>🎯 **Sous-tâche 1.2.1 : Implémentation Tests Unitaires Module Auth**

**[DÉCOMPOSITION - Économie Contexte]**

**Contexte Synthétique** :
- Module AuthService implémenté (lignes 45-230)
- 4 méthodes publiques : login(), logout(), refreshToken(), validateToken()
- Dépendances : JWT library, UserRepository

**Objectif Atomique** :
Créer tests unitaires complets pour AuthService

**Livrables** :
- [ ] __tests__/auth.service.spec.ts
- [ ] 12 tests unitaires minimum (3 par méthode)
- [ ] Coverage >80%

**Estimation** : 15k tokens, 2h
</message>
</new_task>
```

#### Cas d'Usage B : Escalade Compétences (Simple → Complex)

**Situation** : [`code-simple`](code-simple) identifie besoin architecture avancée (patterns distribués)

```xml
<new_task>
<mode>code-complex</mode>
<message>🎯 **Sous-tâche 1.3 : Architecture Pattern Observer pour Event System**

**[ESCALADE EXTERNE-COMPÉTENTE]**

**Contexte Escalade** :
code-simple identifie besoin pattern Observer pour système événementiel, mais manque compétences patterns avancés.

**Situation Actuelle** :
- Event emitters basiques implémentés (simples callbacks)
- Besoin découplage publishers/subscribers
- Gestion lifecycle complexe (unsubscribe, memory leaks)

**Objectif** :
Concevoir et implémenter architecture Pattern Observer robuste avec :
- Interface Publisher/Subscriber découplée
- Gestion automatique unsubscribe
- Type-safety TypeScript complet

**Compétences Requises** :
- Patterns GoF (Observer, Mediator)
- TypeScript generics avancés
- Memory management JavaScript

**Livrables** :
- [ ] Architecture détaillée (diagramme classes)
- [ ] Implémentation complète pattern
- [ ] Tests unitaires pattern
- [ ] Documentation usage

**Estimation** : 25k tokens, 4h
</message>
</new_task>
```

#### Cas d'Usage C : Spécialisation (Délégation Debug)

**Situation** : [`code-simple`](code-simple) implémente feature mais rencontre bug performance → Délégation [`debug-simple`](debug-simple)

```xml
<new_task>
<mode>debug-simple</mode>
<message>🎯 **Sous-tâche 1.4.1 : Investigation Performance Lenteur Requêtes API**

**[DÉLÉGATION SPÉCIALISATION]**

**Contexte Délégation** :
code-simple a implémenté endpoint GET /api/users mais observe lenteur ~3s par requête (cible <500ms).

**Observations** :
- Endpoint [`src/api/users.controller.ts`](src/api/users.controller.ts:45-89)
- Database queries multiples (N+1 suspectée)
- Pas de caching actif

**Objectif Investigation** :
Diagnostiquer cause lenteur et proposer optimisations

**Actions Debug** :
- Profiling temps exécution requêtes DB
- Analyse queries SQL générées
- Identification N+1 queries
- Mesure impact caching

**Livrable** :
Rapport diagnostic avec :
- [ ] Cause racine identifiée
- [ ] Métriques avant/après
- [ ] Recommandations optimisation (priorisées)

**Estimation** : 12k tokens, 1.5h
</message>
</new_task>
```

---

### 2️⃣ MODE DEBUG : Investigation et Résolution

#### Cas d'Usage A : Économie Contexte (Profiling Lourd)

**Situation** : [`debug-simple`](debug-simple) analyse bug complexe nécessitant profiling CPU/mémoire lourd

```xml
<new_task>
<mode>debug-simple</mode>
<message>🎯 **Sous-tâche 2.1.1 : Profiling CPU Memory Leak Processus Background**

**[DÉCOMPOSITION - Économie Contexte]**

**Contexte Investigation** :
- Processus background job consomme mémoire croissante (~500MB/h)
- Crash après 6h d'exécution
- Fichier cible : [`src/jobs/data-processor.ts`](src/jobs/data-processor.ts)

**Objectif Profiling** :
Utiliser outils profiling pour identifier memory leak

**Actions Techniques** :
- Activer Node.js --inspect avec heap snapshots
- Comparer snapshots t=0, t=1h, t=2h
- Identifier objets non garbage-collected
- Générer flame graphs CPU

**Livrables** :
- [ ] 3 heap snapshots (.heapsnapshot)
- [ ] Rapport objets suspects (tableau croissance)
- [ ] Flame graph CPU
- [ ] Hypothèse cause (objet/closure suspect)

**Estimation** : 18k tokens, 2.5h
</message>
</new_task>
```

#### Cas d'Usage B : Escalade Compétences (Simple → Complex)

**Situation** : [`debug-simple`](debug-simple) rencontre race condition multi-threads nécessitant expertise avancée

```xml
<new_task>
<mode>debug-complex</mode>
<message>🎯 **Sous-tâche 2.2 : Résolution Race Condition Worker Threads Pool**

**[ESCALADE EXTERNE-COMPÉTENTE]**

**Contexte Escalade** :
debug-simple identifie race condition dans pool worker threads, mais manque expertise concurrence avancée.

**Symptômes Observés** :
- Corruption données sporadique (1 fois/100 exécutions)
- Fichiers [`src/workers/pool-manager.ts`](src/workers/pool-manager.ts), [`src/workers/task-queue.ts`](src/workers/task-queue.ts)
- Shared state entre workers sans synchronisation

**Hypothèse Initiale** :
Race condition sur queue.shift() + worker.postMessage() non atomique

**Compétences Requises** :
- Concurrence/parallélisme JavaScript
- Worker threads API avancée
- Patterns synchronisation (mutex, semaphores)
- Debugging multi-threads

**Objectif** :
Diagnostiquer race condition précise et implémenter synchronisation robuste

**Livrables** :
- [ ] Analyse détaillée race condition (séquence événements)
- [ ] Solution synchronisation (Atomics/SharedArrayBuffer si nécessaire)
- [ ] Tests stress (1000 exécutions parallèles)
- [ ] Documentation patterns concurrence

**Estimation** : 30k tokens, 5h
</message>
</new_task>
```

#### Cas d'Usage C : Spécialisation (Délégation Code pour Fix)

**Situation** : [`debug-simple`](debug-simple) identifie bug → Délégation [`code-simple`](code-simple) pour correction

```xml
<new_task>
<mode>code-simple</mode>
<message>🎯 **Sous-tâche 2.3.1 : Correction Bug Validation Email Regex**

**[DÉLÉGATION SPÉCIALISATION]**

**Contexte Investigation** :
debug-simple a identifié bug validation email permettant emails malformés.

**Bug Identifié** :
- Fichier : [`src/validators/email.validator.ts:12`](src/validators/email.validator.ts:12)
- Regex actuelle : `/^[a-zA-Z0-9]+@[a-zA-Z0-9]+\.[a-zA-Z]+$/`
- Problème : N'accepte pas caractères spéciaux légitimes (., _, -, +)

**Objectif Correction** :
Corriger regex validation email selon RFC 5322 (simplifié)

**Spécifications** :
- Accepter : user+tag@example.co.uk, first.last@example.com
- Rejeter : user@@example.com, @example.com, user@.com
- Ajouter tests unitaires (10 cas minimum)

**Livrables** :
- [ ] Regex corrigée (ligne 12)
- [ ] Tests unitaires ajoutés
- [ ] Documentation regex (commentaires)

**Estimation** : 8k tokens, 1h
</message>
</new_task>
```

---

### 3️⃣ MODE ARCHITECT : Conception et Planification

#### Cas d'Usage A : Spécialisation (Prototypage Validation)

**Situation** : [`architect-simple`](architect-simple) conçoit architecture → Besoin prototypage rapide pour validation

```xml
<new_task>
<mode>code-simple</mode>
<message>🎯 **Sous-tâche 3.1.1 : Prototypage Proof-of-Concept API Gateway Pattern**

**[DÉLÉGATION SPÉCIALISATION]**

**Contexte Architecture** :
architect-simple a conçu architecture API Gateway pour microservices, besoin prototype pour valider faisabilité.

**Architecture Proposée** :
```
Client → API Gateway (Express) → [Service A, Service B, Service C]
         ↓ Routing
         ↓ Auth middleware
         ↓ Rate limiting
```

**Objectif Prototype** :
Implémenter PoC minimal API Gateway avec routing basique

**Spécifications Prototype** :
- Express.js gateway simple
- Routing vers 2 services simulés (mock)
- Middleware auth basique (Bearer token)
- Tests manuel via curl

**Livrables** :
- [ ] src/gateway/server.ts (Express app)
- [ ] src/gateway/routes.ts (routing config)
- [ ] README_PROTOTYPE.md (instructions test)

**Critères Validation** :
- Routing fonctionnel (2 services)
- Auth middleware bloque requêtes non authentifiées
- Temps implémentation <2h (prototype rapide)

**Estimation** : 12k tokens, 1.5h
</message>
</new_task>
```

#### Cas d'Usage B : Escalade Compétences (Décision Architecturale Complexe)

**Situation** : [`architect-simple`](architect-simple) rencontre décision architecture nécessitant patterns distribués

```xml
<new_task>
<mode>architect-complex</mode>
<message>🎯 **Sous-tâche 3.2 : Architecture Système Distribué Event-Driven**

**[ESCALADE EXTERNE-COMPÉTENTE]**

**Contexte Escalade** :
architect-simple identifie besoin système event-driven pour découplage microservices, mais manque expertise patterns distribués.

**Situation Actuelle** :
- 5 microservices interdépendants (couplage fort HTTP)
- Besoin découplage via events
- Volume estimé : 10k events/min
- Exigences : At-least-once delivery, ordering partiel

**Décisions Architecturales Requises** :
1. **Message broker** : RabbitMQ vs Kafka vs Redis Streams ?
2. **Pattern communication** : Pub/Sub vs Event Sourcing vs CQRS ?
3. **Gestion failures** : Dead letter queues, retry policies ?
4. **Monitoring** : Métriques, tracing distribué ?

**Compétences Requises** :
- Patterns architecturaux distribués (Saga, Event Sourcing, CQRS)
- Message brokers (RabbitMQ, Kafka, Redis)
- CAP theorem, consistency models
- Observability systèmes distribués

**Livrables** :
- [ ] Document architecture détaillé (20-30 pages)
- [ ] Matrice comparaison message brokers (critères techniques)
- [ ] Diagrammes séquence événements critiques
- [ ] Stratégie migration progressive (étapes)
- [ ] Recommandations monitoring/observability

**Estimation** : 40k tokens, 6h
</message>
</new_task>
```

#### Cas d'Usage C : Escalade Orchestrateur (Multi-Domaines)

**Situation** : [`architect-complex`](architect-complex) conçoit projet multi-domaines nécessitant coordination

```xml
<new_task>
<mode>orchestrator</mode>
<message>🎯 **Sous-tâche 3.3 : Orchestration Migration Monolithe → Microservices**

**[ORCHESTRATION - Coordination Multi-Domaines]**

**Contexte Orchestration** :
architect-complex a conçu architecture cible microservices, nécessite coordination implémentation multi-équipes.

**Architecture Cible** :
- 8 microservices identifiés
- 3 domaines techniques : Backend (5 services), Frontend (2 SPAs), Infra (K8s)
- 12 semaines migration progressive

**Objectif Orchestration** :
Coordonner implémentation migration complète avec sous-tâches par domaine

**Phases Planifiées** :
1. Phase 1 (S1-S4) : Extraction services Backend
2. Phase 2 (S5-S8) : Migration Frontends
3. Phase 3 (S9-S12) : Infrastructure K8s + CI/CD

**Sous-tâches Prévues** :
- 3.3.1 : Extraction Service Auth (code-complex)
- 3.3.2 : Extraction Service Users (code-complex)
- 3.3.3 : Setup Infrastructure K8s (devops-focused mode)
- 3.3.4 : Migration Frontend Admin (code-simple)
- [...]

**Coordination Requise** :
- Synchronisation dépendances inter-services
- Gestion versions APIs compatibles
- Tests intégration progressifs
- Rollback strategy

**Estimation** : Orchestration 15k tokens, 12 semaines implémentation totale
</message>
</new_task>
```

---

### 4️⃣ MODE ASK : Recherche et Documentation

#### Cas d'Usage A : Économie Contexte (Recherche Approfondie)

**Situation** : [`ask-simple`](ask-simple) répond question nécessitant recherche web extensive

```xml
<new_task>
<mode>ask-simple</mode>
<message>🎯 **Sous-tâche 4.1.1 : Recherche Comparative Frameworks Machine Learning Python**

**[DÉCOMPOSITION - Économie Contexte]**

**Contexte Recherche** :
ask-simple répond question "Quel framework ML choisir ?", nécessite recherche web extensive déléguée.

**Objectif Recherche** :
Comparer 5 frameworks ML Python populaires selon critères techniques

**Frameworks Cibles** :
- TensorFlow
- PyTorch
- Scikit-learn
- XGBoost
- Keras

**Critères Comparaison** :
- Performance (benchmarks)
- Facilité apprentissage
- Communauté/documentation
- Cas d'usage typiques
- Support production

**MCPs Utilisables** :
- searxng : Recherche articles comparatifs récents
- jinavigator : Extraction contenu documentation officielle

**Livrables** :
- [ ] Tableau comparatif (5 frameworks × 5 critères)
- [ ] Sources bibliographiques (10 articles minimum)
- [ ] Recommandation contextualisée

**Estimation** : 20k tokens, 3h
</message>
</new_task>
```

#### Cas d'Usage B : Escalade Compétences (Expertise Domaine)

**Situation** : [`ask-simple`](ask-simple) reçoit question nécessitant expertise académique approfondie

```xml
<new_task>
<mode>ask-complex</mode>
<message>🎯 **Sous-tâche 4.2 : Analyse Approfondie Algorithmes Consensus Distribués**

**[ESCALADE EXTERNE-COMPÉTENTE]**

**Contexte Escalade** :
ask-simple identifie question nécessitant expertise académique approfondie en systèmes distribués.

**Question Utilisateur** :
"Expliquer différences Paxos, Raft, Byzantine Fault Tolerance pour système bancaire haute disponibilité ?"

**Compétences Requises** :
- Théorie systèmes distribués (consensus, CAP theorem)
- Algorithmes Paxos, Raft, PBFT
- Garanties safety/liveness
- Trade-offs performance/résilience

**Objectif Analyse** :
Fournir analyse académique détaillée avec recommandation contextualisée

**Structure Attendue** :
1. **Fondamentaux théoriques** : Consensus problem, FLP impossibility
2. **Paxos** : Mécanisme, garanties, complexité
3. **Raft** : Différences Paxos, avantages pédagogiques
4. **BFT** : Byzantine failures, use cases blockchain
5. **Comparaison tableau** : Safety, Liveness, Performance, Complexité
6. **Recommandation** : Pour système bancaire (critères spécifiques)

**Sources Académiques** :
- Papers originaux (Lamport, Ongaro, Castro)
- Références bibliographiques complètes
- Benchmarks comparatifs récents

**Livrables** :
- [ ] Document analyse (15-20 pages)
- [ ] Diagrammes protocoles
- [ ] Tableau comparatif
- [ ] Recommandation argumentée

**Estimation** : 35k tokens, 5h
</message>
</new_task>
```

#### Cas d'Usage C : Spécialisation (Délégation Code Exemples)

**Situation** : [`ask-simple`](ask-simple) explique concept → Besoin exemples code concrets

```xml
<new_task>
<mode>code-simple</mode>
<message>🎯 **Sous-tâche 4.3.1 : Exemples Code Pattern Repository TypeScript**

**[DÉLÉGATION SPÉCIALISATION]**

**Contexte Pédagogique** :
ask-simple explique pattern Repository, besoin exemples code TypeScript concrets pour illustration.

**Concept Expliqué** :
Pattern Repository abstrait accès données (DB, API, cache) derrière interface commune.

**Objectif Exemples** :
Créer exemples code TypeScript démonstratifs pattern Repository

**Spécifications Exemples** :
- Interface `IUserRepository` (CRUD basique)
- Implémentation `PostgresUserRepository`
- Implémentation `InMemoryUserRepository` (tests)
- Usage dans service (injection dépendances)

**Livrables** :
- [ ] src/repositories/interfaces/IUserRepository.ts
- [ ] src/repositories/PostgresUserRepository.ts
- [ ] src/repositories/InMemoryUserRepository.ts
- [ ] src/services/UserService.ts (exemple usage)
- [ ] Commentaires pédagogiques inline

**Critères Qualité** :
- Code type-safe TypeScript
- Patterns modernes (async/await)
- Commentaires explicatifs abondants
- Exemples simples (<100 lignes total)

**Estimation** : 10k tokens, 1.5h
</message>
</new_task>
```

---

### 5️⃣ MODE ORCHESTRATOR : Coordination Multi-Domaines

#### Cas d'Usage A : Décomposition Systématique (Usage Principal)

**Situation** : [`orchestrator`](orchestrator) reçoit projet complexe nécessitant coordination multi-étapes

```xml
<new_task>
<mode>architect-simple</mode>
<message>🎯 **Sous-tâche 5.1.1 : Grounding Sémantique Initial Projet Refactoring**

**[GROUNDING DÉLÉGUÉ - Pattern SDDD Orchestrateur]**

**Contexte Orchestration** :
orchestrator démarre projet "Refactoring Architecture Modes Roo", nécessite grounding sémantique initial avant décomposition.

**Objectif Grounding** :
Effectuer recherche sémantique exhaustive et analyse codebase pour identifier :
- Architecture actuelle modes Roo
- Redondances et patterns factorisation
- Contraintes techniques et dépendances
- Documentation existante pertinente

**Actions Requises** :
1. **codebase_search** : "architecture modes roo custom_modes escalade"
2. **codebase_search** : "mode instructions system prompt templates"
3. **Analyse fichiers** : custom_modes.json, mode-*.md existants
4. **Identification patterns** : Instructions communes (>80% similarité)

**MCPs Obligatoires** :
- codebase_search (grounding sémantique)
- quickfiles (lecture batch fichiers)
- roo-state-manager (historique conversationnel si applicable)

**Livrables Synthèse** :
- [ ] Rapport architecture actuelle (3-5 pages)
- [ ] Liste redondances identifiées (tableau)
- [ ] Patterns factorisation proposés
- [ ] Contraintes techniques documentées
- [ ] Recommandations décomposition sous-tâches

**Format Rapport** :
Document markdown structuré pour réutilisation orchestrateur dans planification sous-tâches suivantes.

**Estimation** : 25k tokens, 3h
</message>
</new_task>
```

#### Cas d'Usage B : Coordination Parallèle

**Situation** : [`orchestrator`](orchestrator) identifie sous-tâches indépendantes parallélisables

```xml
<!-- Création 3 sous-tâches parallèles -->
<new_task>
<mode>code-simple</mode>
<message>🎯 **Sous-tâche 5.2.1 : Implémentation Module Auth (PARALLÈLE)**

**[PARALLÉLISATION - Sous-tâche Indépendante]**

**Contexte Parallélisation** :
Cette sous-tâche est INDÉPENDANTE de 5.2.2 et 5.2.3, peut être exécutée en parallèle.

**Isolation Garantie** :
- Fichiers isolés : src/auth/* (pas de conflits)
- Aucune dépendance sur autres modules
- Tests isolés : __tests__/auth/*

**Objectif** :
Implémenter module authentification complet

**Livrables** :
- [ ] src/auth/auth.service.ts
- [ ] src/auth/auth.controller.ts
- [ ] __tests__/auth/*.spec.ts

**Synchronisation** :
Résultats consolidés dans sous-tâche 5.3 (intégration finale)

**Estimation** : 18k tokens, 2.5h
</message>
</new_task>

<new_task>
<mode>code-simple</mode>
<message>🎯 **Sous-tâche 5.2.2 : Implémentation Module Users (PARALLÈLE)**

**[PARALLÉLISATION - Sous-tâche Indépendante]**

[Structure identique avec fichiers src/users/*, indépendant de 5.2.1 et 5.2.3]

**Estimation** : 16k tokens, 2h
</message>
</new_task>

<new_task>
<mode>code-simple</mode>
<message>🎯 **Sous-tâche 5.2.3 : Implémentation Module Products (PARALLÈLE)**

**[PARALLÉLISATION - Sous-tâche Indépendante]**

[Structure identique avec fichiers src/products/*, indépendant de 5.2.1 et 5.2.2]

**Estimation** : 20k tokens, 3h
</message>
</new_task>
```

#### Cas d'Usage C : Grounding Périodique

**Situation** : [`orchestrator`](orchestrator) après 3-4 sous-tâches, besoin checkpoint grounding

```xml
<new_task>
<mode>architect-simple</mode>
<message>🎯 **Sous-tâche 5.4.1 : Checkpoint Grounding Sémantique (Périodique)**

**[GROUNDING PÉRIODIQUE - Pattern SDDD Orchestrateur]**

**Contexte Checkpoint** :
orchestrator a complété 4 sous-tâches (5.2.1, 5.2.2, 5.2.3, 5.3), nécessite checkpoint grounding avant continuer.

**Objectif Checkpoint** :
Vérifier cohérence implémentation actuelle avec architecture cible et découvrabilité sémantique.

**Actions Vérification** :
1. **codebase_search** : Vérifier nouvelles implémentations découvrables
2. **Analyse cohérence** : Patterns utilisés conformes spécifications
3. **Détection dérives** : Redondances non prévues, incohérences
4. **Recommandations** : Ajustements nécessaires sous-tâches restantes

**Livrables** :
- [ ] Rapport checkpoint (2-3 pages)
- [ ] Liste problèmes détectés (si applicable)
- [ ] Recommandations ajustement plan
- [ ] Validation poursuite ou pivot

**Critère GO/NO-GO** :
Si problèmes majeurs détectés → Recommandation pause orchestration pour corrections.

**Estimation** : 15k tokens, 2h
</message>
</new_task>
```

---

## 🎨 Conventions de Présentation

### Format Titre Sous-tâche

```markdown
🎯 **Sous-tâche [NUMERO] : [Titre Descriptif]**

Exemples :
🎯 **Sous-tâche 1.2.3 : Rédaction Mécaniques Escalade Révisées**
🎯 **Sous-tâche 1.3.2.1 : Template Famille CODE Simple/Complex**
```

### Format Corps de Sous-tâche

```markdown
🎯 **Sous-tâche [NUMERO] : [Titre]**

**Contexte hérité** :
- Information 1 de la tâche parent
- Information 2 de la tâche parent
- Décisions architecturales prises

**Objectif spécifique** :
[Description précise de ce qui doit être accompli]

**Livrables attendus** :
- [ ] Livrable 1
- [ ] Livrable 2
- [ ] Livrable 3

**Critères de validation** :
- ✅ Critère 1 : Description
- ✅ Critère 2 : Description

**Dépendances** :
- Requiert : [Tâches dont dépend cette sous-tâche]
- Bloque : [Tâches qui attendent cette sous-tâche]

**Ressources** :
- Fichiers concernés : [Liste]
- Documentation : [Références]
- MCPs utilisables : [Liste]

**Estimation** :
- Complexité : [Simple/Modérée/Élevée]
- Durée estimée : [Temps]
- Tokens estimés : [Quantité]
```

---

## 🔄 Intégration avec new_task()

### Template Complet new_task()

```xml
<new_task>
<mode>[mode-approprié]</mode>
<message>🎯 **Sous-tâche [NUMERO] : [Titre Descriptif]**

**Contexte hérité** :
[Informations essentielles de la tâche parent]

**Objectif spécifique** :
[Description précise et actionable]

**Livrables attendus** :
- [ ] Livrable 1
- [ ] Livrable 2

**Critères de validation** :
- ✅ Critère 1
- ✅ Critère 2

**Fichiers concernés** :
[Liste des fichiers à créer/modifier]

**Dépendances** :
- Requiert : [Tâches préalables si applicable]

**Mode recommandé** : [Justification du choix de mode]
</message>
</new_task>
```

### Exemple Concret

```xml
<new_task>
<mode>code-simple</mode>
<message>🎯 **Sous-tâche 1.3.2.1 : Template Famille CODE Simple/Complex**

**Contexte hérité** :
- Architecture 2-niveaux validée (code-simple / code-complex)
- Redondances identifiées : mécanismes escalade, gestion tokens, MCPs
- Factorisation cible : 85% instructions communes

**Objectif spécifique** :
Créer template réutilisable pour la famille CODE avec :
1. Section COMMUNES (escalade, tokens, MCPs) factorisée
2. Section SIMPLE spécifique (focus areas < 50 lignes)
3. Section COMPLEX spécifique (focus areas architecture)
4. Variables paramétrables pour personnalisation

**Livrables attendus** :
- [ ] roo-config/specifications/templates/code-family-template.md
- [ ] Variables : {{MODE_SLUG}}, {{MODE_LEVEL}}, {{MAX_LINES}}
- [ ] Documentation assemblage automatique

**Critères de validation** :
- ✅ Template génère instructions complètes code-simple
- ✅ Template génère instructions complètes code-complex
- ✅ Réduction >80% caractères dupliqués
- ✅ Cohérence avec spécifications existantes

**Fichiers concernés** :
- roo-config/specifications/templates/code-family-template.md (création)

**Dépendances** :
- Requiert : 1.3.1 (Extraction instructions communes complétée)

**Mode recommandé** : code-simple (création fichier template standard)
</message>
</new_task>
```

---

## 📊 Synchronisation avec roo-state-manager

### Correspondance Hiérarchie

Le système de numérotation **correspond exactement** à la structure [`view_conversation_tree`](../../../mcps/internal/servers/roo-state-manager/src/tools/view_conversation_tree.ts) de roo-state-manager :

```json
{
  "taskId": "uuid-tache-1",
  "title": "Mission : Refactoring Architecture Modes",
  "hierarchy": "1",
  "children": [
    {
      "taskId": "uuid-tache-1.1",
      "title": "Phase Analyse & Grounding",
      "hierarchy": "1.1",
      "parentId": "uuid-tache-1",
      "children": [
        {
          "taskId": "uuid-tache-1.1.1",
          "title": "Recherche sémantique architecture",
          "hierarchy": "1.1.1",
          "parentId": "uuid-tache-1.1"
        }
      ]
    }
  ]
}
```

### Requêtes de Navigation

**Voir arbre complet** :
```xml
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>view_conversation_tree</tool_name>
<arguments>
{
  "task_id": "uuid-tache-1",
  "view_mode": "chain",
  "detail_level": "skeleton"
}
</arguments>
</use_mcp_tool>
```

**Rechercher sous-tâche spécifique** :
```xml
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>search_tasks_semantic</tool_name>
<arguments>
{
  "search_query": "sous-tâche 1.3.2 template famille CODE",
  "workspace": "c:/dev/roo-extensions"
}
</arguments>
</use_mcp_tool>
```

**Navigation avec parentTaskId** :
```xml
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>get_task_tree</tool_name>
<arguments>
{
  "conversation_id": "uuid-tache-principale",
  "max_depth": 3,
  "include_siblings": true
}
</arguments>
</use_mcp_tool>
```

**Liste conversations workspace** :
```xml
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>list_conversations</tool_name>
<arguments>
{
  "workspace": "c:/dev/roo-extensions",
  "sortBy": "lastActivity",
  "hasApiHistory": true
}
</arguments>
</use_mcp_tool>
```

### Intégration Workflow Typique

```markdown
**Workflow Orchestrateur avec roo-state-manager** :

1. **Démarrage tâche** : Créer tâche racine (numéro `1`)
2. **Grounding initial** : 
   - `codebase_search` pour contexte code
   - `search_tasks_semantic` pour historique conversationnel
3. **Planification** : Créer todo list avec numéros (1.1, 1.2, 1.3, ...)
4. **Création sous-tâches** : `new_task()` avec numéros hiérarchiques
5. **Checkpoints réguliers** : `view_conversation_tree` pour position
6. **Finalisation** : `attempt_completion` avec référence numéros complétés
```

---

## 🎯 Patterns d'Orchestration

### Pattern 1 : Décomposition Séquentielle

**Tâche complexe → N sous-tâches séquentielles**

```markdown
1       Tâche Principale
├── 1.1 Sous-tâche 1 (DOIT être complétée avant 1.2)
├── 1.2 Sous-tâche 2 (DÉPEND de 1.1)
└── 1.3 Sous-tâche 3 (DÉPEND de 1.2)
```

**Instructions new_task()** :
```xml
<new_task>
<mode>code-complex</mode>
<message>🎯 **Sous-tâche 1.2 : [Titre]**

**Dépendances** :
- Requiert : 1.1 (DOIT être complétée et validée)
- Utilise résultats de : 1.1
- Bloque : 1.3 (attend cette sous-tâche)

[Reste des instructions...]
</message>
</new_task>
```

### Pattern 2 : Décomposition Parallèle

**Tâche complexe → N sous-tâches parallélisables**

```markdown
1       Tâche Principale
├── 1.1 Sous-tâche 1 (INDÉPENDANTE)
├── 1.2 Sous-tâche 2 (INDÉPENDANTE)
├── 1.3 Sous-tâche 3 (INDÉPENDANTE)
└── 1.4 Consolidation (DÉPEND de 1.1, 1.2, 1.3)
```

**Instructions new_task()** :
```xml
<new_task>
<mode>code-simple</mode>
<message>🎯 **Sous-tâche 1.1 : [Titre]**

**Parallélisation** :
- Cette tâche est INDÉPENDANTE des autres sous-tâches
- Peut être exécutée en parallèle avec 1.2, 1.3
- Résultats consolidés dans 1.4

**Isolation** :
- Aucune dépendance sur autres sous-tâches
- Modifications isolées (pas de conflits)

[Reste des instructions...]
</message>
</new_task>
```

### Pattern 3 : Décomposition Mixte

**Tâche complexe → Mix séquentiel/parallèle**

```markdown
1       Tâche Principale
├── 1.1 Phase Préparation (SÉQUENTIEL - fondation)
│   ├── 1.1.1 Analyse
│   └── 1.1.2 Conception
│
├── 1.2 Phase Implémentation (PARALLÈLE - après 1.1)
│   ├── 1.2.1 Module A (indépendant)
│   ├── 1.2.2 Module B (indépendant)
│   └── 1.2.3 Module C (indépendant)
│
└── 1.3 Phase Intégration (SÉQUENTIEL - après 1.2)
    ├── 1.3.1 Tests intégration
    └── 1.3.2 Validation complète
```

---

## 📋 Templates Instructions Modes

### Template Mode Orchestrateur

```markdown
## HIÉRARCHIE NUMÉROTÉE SYSTÉMATIQUE

### Règles de Numérotation
- Tâche principale : X (sans .0)
- Sous-tâches niveau 1 : X.1, X.2, X.3, ...
- Sous-tâches niveau 2 : X.Y.1, X.Y.2, ...
- Sous-tâches niveau 3 : X.Y.Z.1, X.Y.Z.2, ...

### Format new_task() Standard
```xml
<new_task>
<mode>[mode-approprié]</mode>
<message>🎯 **Sous-tâche [NUMERO] : [Titre]**

**Contexte hérité** :
[Informations essentielles parent]

**Objectif spécifique** :
[Description précise]

**Livrables attendus** :
- [ ] Livrable 1
- [ ] Livrable 2

**Critères de validation** :
- ✅ Critère 1
- ✅ Critère 2

**Dépendances** :
- Requiert : [Tâches préalables]
- Bloque : [Tâches dépendantes]
</message>
</new_task>
```

### Synchronisation roo-state-manager
Utiliser `view_conversation_tree` pour navigation hiérarchie :
```xml
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>view_conversation_tree</tool_name>
<arguments>
{
  "task_id": "[taskId-actuelle]",
  "view_mode": "chain",
  "detail_level": "summary"
}
</arguments>
</use_mcp_tool>
```
```

### Template Mode Exécutant

```markdown
## TRAÇABILITÉ SOUS-TÂCHE

### Identification
Votre tâche actuelle : **[NUMERO] - [Titre]**

### Contexte Parent
- Tâche principale : [X]
- Tâche parent immédiate : [X.Y]
- Position dans hiérarchie : [Description]

### Rapport Final
À la fin de votre tâche, utiliser `attempt_completion` avec :
- Confirmation numéro sous-tâche : [NUMERO]
- Livrables complétés : [Liste]
- Critères validation atteints : [Liste]
- Fichiers modifiés/créés : [Liste]
- Prochaine sous-tâche suggérée : [NUMERO+1] si applicable
```

---

## 🔍 Recherche et Navigation

### Recherche par Numéro

```xml
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>search_tasks_semantic</tool_name>
<arguments>
{
  "search_query": "sous-tâche 1.2.3",
  "workspace": "c:/dev/roo-extensions"
}
</arguments>
</use_mcp_tool>
```

### Navigation Arbre Complet

```xml
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>get_task_tree</tool_name>
<arguments>
{
  "conversation_id": "uuid-tache-principale",
  "max_depth": 3,
  "include_siblings": true
}
</arguments>
</use_mcp_tool>
```

### Filtrage par Niveau

```xml
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>list_conversations</tool_name>
<arguments>
{
  "workspace": "c:/dev/roo-extensions",
  "sortBy": "lastActivity"
}
</arguments>
</use_mcp_tool>
```

---

## 📊 Métriques et Reporting

### Métriques par Projet

```markdown
## Rapport Hiérarchie - Projet 1

### Structure
- Profondeur maximale : 3 niveaux
- Sous-tâches niveau 1 : 5
- Sous-tâches niveau 2 : 12
- Sous-tâches niveau 3 : 8
- **Total sous-tâches : 25**

### Avancement
- Complétées : 18 (72%)
- En cours : 2 (8%)
- Planifiées : 5 (20%)

### Dépendances
- Bloqueurs actifs : 1
- Parallélisation : 40% sous-tâches
- Séquentiel : 60% sous-tâches
```

### Export Hiérarchie

**Format Markdown** :
```markdown
1       Tâche Principale ✅
├── 1.1 Phase 1 ✅
│   ├── 1.1.1 Sous-tâche A ✅
│   └── 1.1.2 Sous-tâche B ✅
├── 1.2 Phase 2 🔄
│   ├── 1.2.1 Sous-tâche C ✅
│   └── 1.2.2 Sous-tâche D 🔄
└── 1.3 Phase 3 ⏳
    └── 1.3.1 Sous-tâche E ⏳
```

**Légende** :
- ✅ Complétée
- 🔄 En cours
- ⏳ Planifiée
- ❌ Bloquée

---

## ⚠️ Anti-Patterns à Éviter

### ❌ Numérotation Incohérente
```markdown
1       Tâche
├── 1.1 Sous-tâche
├── 1.3 Sous-tâche (❌ manque 1.2)
└── 1.2 Sous-tâche (❌ ordre incorrect)
```

### ✅ Numérotation Cohérente
```markdown
1       Tâche
├── 1.1 Sous-tâche
├── 1.2 Sous-tâche
└── 1.3 Sous-tâche
```

### ❌ Format Ancien (Redondant)
```markdown
1.0         → Tâche principale (❌ .0 redondant)
1.1.0       → Sous-tâche niveau 1 (❌ .0 inutile)
```

### ✅ Format Simplifié (Correct)
```markdown
1           → Tâche principale (✅ évident racine)
1.1         → Sous-tâche niveau 1 (✅ clair)
1.1.1       → Sous-tâche niveau 2 (✅ hiérarchie nette)
```

### ❌ Profondeur Excessive
```markdown
1.1.1.1.1.1.1 (❌ 7 niveaux illisible)
```

### ✅ Profondeur Raisonnable
```markdown
1.1.1 ou 1.1.1.1 (✅ 3-4 niveaux maximum)
```

### ❌ new_task() Sans Numéro
```xml
<new_task>
<mode>code-simple</mode>
<message>Implémenter feature X</message> <!-- ❌ Pas de numéro -->
</new_task>
```

### ✅ new_task() Avec Numéro
```xml
<new_task>
<mode>code-simple</mode>
<message>🎯 **Sous-tâche 1.2.3 : Implémenter Feature X**</message> <!-- ✅ -->
</new_task>
```

---

## 🚀 Bénéfices du Système

1. **Traçabilité parfaite** : Chaque sous-tâche identifiable uniquement
2. **Navigation intuitive** : Structure arborescente claire
3. **Orchestration facilitée** : Gestion dépendances automatisée
4. **Reporting automatique** : Métriques et dashboards générables
5. **Collaboration améliorée** : Compréhension structure projet immédiate
6. **Flexibilité universelle** : Tous modes peuvent créer sous-tâches selon besoins

---

## 📚 Ressources Complémentaires

### Documents de Référence

#### Mécanismes Connexes

- **[`escalade-mechanisms-revised.md`](escalade-mechanisms-revised.md)** : Intégration escalade par approfondissement
  * Escalade vs Décomposition vs Délégation
  * Format `1` (racine) cohérent avec hiérarchie numérotée
  * `new_task()` privilégié sur `switch_mode()`

- **[`context-economy-patterns.md`](context-economy-patterns.md)** : Optimisation décomposition tâches
  * Patterns délégation intelligente (Complex → Simple)
  * Décomposition atomique pour économie tokens
  * Checkpoints réguliers (30k, 50k, 70k tokens)

- **[`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md)** : Documentation continue et checkpoints
  * Grounding sémantique obligatoire (`codebase_search` AVANT exploration)
  * Todo lists essentielles coordination parent-enfant
  * Grounding délégué pour orchestrateurs (limitation read_file)

#### Intégrations Techniques

- **[`mcp-integrations-priority.md`](mcp-integrations-priority.md)** : Utilisation MCPs pour efficacité
  * [`roo-state-manager`](../../../mcps/internal/servers/roo-state-manager/) : Tier 1, grounding conversationnel obligatoire
  * [`quickfiles`](../../../mcps/internal/servers/quickfiles-server/) : Tier 1, lectures batch optimisées
  * Patterns usage dans sous-tâches (grounding, checkpoints)

### Factorisation Commons

- **[`factorisation-commons.md`](factorisation-commons.md)** : Sections communes modes
  * Templates hiérarchie numérotée par famille modes
  * Intégration instructions modes (CODE, DEBUG, ARCHITECT, ASK, ORCHESTRATOR)
  * Format `X` (racine) standardisé

---

## 🌳 Exemple Complet Hiérarchie

### Projet : Refactoring Architecture Modes

```
1       Mission : Refactoring Architecture Modes Roo
│
├── 1.1 Phase Analyse & Grounding
│   ├── 1.1.1 Recherche sémantique architecture existante
│   ├── 1.1.2 Analyse custom_modes.json redondances
│   ├── 1.1.3 Identification patterns factorisation
│   └── 1.1.4 Validation utilisateur stratégie
│
├── 1.2 Phase Création Spécifications
│   ├── 1.2.1 Création structure roo-config/specifications/
│   ├── 1.2.2 Rédaction sddd-protocol-4-niveaux.md
│   ├── 1.2.3 Rédaction escalade-mechanisms-revised.md
│   ├── 1.2.4 Rédaction hierarchie-numerotee-subtasks.md
│   ├── 1.2.5 Rédaction mcp-integrations-priority.md
│   ├── 1.2.6 Rédaction factorisation-commons.md
│   └── 1.2.7 Rédaction context-economy-patterns.md
│
├── 1.3 Phase Templates & Factorisation
│   ├── 1.3.1 Extraction instructions communes (85% redondances)
│   ├── 1.3.2 Création templates par famille modes
│   │   ├── 1.3.2.1 Template famille CODE
│   │   ├── 1.3.2.2 Template famille DEBUG
│   │   ├── 1.3.2.3 Template famille ARCHITECT
│   │   ├── 1.3.2.4 Template famille ASK
│   │   └── 1.3.2.5 Template famille ORCHESTRATOR
│   └── 1.3.3 Système assemblage automatique
│
├── 1.4 Phase Validation & Tests
│   ├── 1.4.1 Validation cohérence architecture 2-niveaux
│   ├── 1.4.2 Tests compatibilité modes existants
│   ├── 1.4.3 Checkpoint sémantique découvrabilité
│   └── 1.4.4 Rapport final consolidation
│
└── 1.5 Phase Implémentation (Future)
    ├── 1.5.1 Application templates custom_modes.json
    ├── 1.5.2 Validation déploiement
    └── 1.5.3 Documentation migration
```

---

**Note :** Ce système est conçu pour l'architecture 2-niveaux (Simple/Complex) et s'intègre parfaitement avec [`roo-state-manager`](../../../mcps/internal/servers/roo-state-manager/) pour une traçabilité complète des projets complexes. La **version 2.0.0** intègre les décisions utilisateur critiques : format simplifié `1` (pas `1.0`) et universalité `new_task()` pour tous les modes.