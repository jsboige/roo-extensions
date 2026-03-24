# 🤖 Mapping LLMs et Modes - Architecture 2-Niveaux

**Version :** 1.0.0  
**Date :** 02 Octobre 2025  
**Architecture :** 2-Niveaux (Simple/Complex)  
**Statut :** ✅ Spécification technique formelle  
**Objectif :** Définir le mapping formel entre types de LLMs et modes Roo avec critères d'escalade

---

## 📖 Table des Matières

1. [Taxonomie LLMs](#-1-taxonomie-llms)
2. [Mapping Modes → LLMs](#-2-mapping-modes--llms)
3. [Critères Escalade Simple → Complex](#-3-critères-escalade-simple--complex)
4. [Patterns d'Usage par Cas](#-4-patterns-dusage-par-cas)
5. [Configuration Recommandée](#-5-configuration-recommandée)
6. [Optimisation Budget Tokens](#-6-optimisation-budget-tokens)
7. [Monitoring et Métriques](#-7-monitoring-et-métriques)

---

## 🏷️ 1. Taxonomie LLMs

### Vue d'Ensemble des Tiers

```
┌─────────────────────────────────────────────────────────────────┐
│ TIER FLASH : Ultra-rapides, coût minimal                       │
│ • Vitesse : <500ms latence moyenne                             │
│ • Coût : 0.25-0.50 $/MTok input, 0.75-1.25 $/MTok output      │
│ • Budget tokens recommandé : 50k-100k (fenêtre contexte)       │
│ • Use case : Tâches répétitives, validations rapides           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ TIER MINI : Rapides, bon compromis performance/coût            │
│ • Vitesse : 500-1000ms latence moyenne                         │
│ • Coût : 0.50-1.00 $/MTok input, 1.50-2.50 $/MTok output      │
│ • Budget tokens recommandé : 100k-200k                         │
│ • Use case : Développement standard, bugs simples              │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ TIER STANDARD : Équilibrés, usage général                      │
│ • Vitesse : 1000-2000ms latence moyenne                        │
│ • Coût : 2.50-5.00 $/MTok input, 7.50-15.00 $/MTok output     │
│ • Budget tokens recommandé : 200k-500k                         │
│ • Use case : Analyses complexes, architectures moyennes        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ TIER SOTA (State Of The Art) : Meilleurs modèles               │
│ • Vitesse : 2000-5000ms latence moyenne                        │
│ • Coût : 3.00-15.00 $/MTok input, 15.00-75.00 $/MTok output   │
│ • Budget tokens recommandé : Illimité (fenêtre 200k+)          │
│ • Use case : Architecture distribuée, raisonnement profond     │
└─────────────────────────────────────────────────────────────────┘
```

### 1.1 Tier Flash : Ultra-Rapides

**Caractéristiques** :
- **Vitesse** : <500ms latence moyenne
- **Coût** : 0.25-0.50 $/MTok input, 0.75-1.25 $/MTok output
- **Fenêtre contexte** : 50k-100k tokens
- **Capacités** : Raisonnement basique, patterns standards

**Modèles Représentatifs** :
- **Claude 3.5 Haiku** (Anthropic) : 0.25/1.25 $/MTok, 200k contexte
- **GPT-4o-mini** (OpenAI) : 0.15/0.60 $/MTok, 128k contexte
- **Gemini 2.0 Flash** (Google) : 0.075/0.30 $/MTok, 1M contexte

**Use Cases Optimaux** :
- Corrections syntaxe simples
- Validations code standards
- Réponses factuelles directes
- Refactorings mineurs (<50 lignes)

### 1.2 Tier Mini : Compromis Performance/Coût

**Caractéristiques** :
- **Vitesse** : 500-1000ms latence moyenne
- **Coût** : 0.50-1.00 $/MTok input, 1.50-2.50 $/MTok output
- **Fenêtre contexte** : 100k-200k tokens
- **Capacités** : Raisonnement intermédiaire, patterns courants

**Modèles Représentatifs** :
- **Claude 3 Haiku** (Anthropic) : 0.80/4.00 $/MTok, 200k contexte
- **GPT-3.5-turbo** (OpenAI) : 0.50/1.50 $/MTok, 16k contexte
- **Qwen 3 32B** (Alibaba) : Variable selon provider

**Use Cases Optimaux** :
- Développement features isolées
- Debugging bugs reproductibles
- Documentation technique basique
- Architecture composants simples

### 1.3 Tier Standard : Usage Général

**Caractéristiques** :
- **Vitesse** : 1000-2000ms latence moyenne
- **Coût** : 2.50-5.00 $/MTok input, 7.50-15.00 $/MTok output
- **Fenêtre contexte** : 200k-500k tokens
- **Capacités** : Raisonnement avancé, patterns sophistiqués

**Modèles Représentatifs** :
- **GPT-4** (OpenAI) : 5.00/15.00 $/MTok, 128k contexte
- **Claude 3 Opus** (Anthropic) : 15.00/75.00 $/MTok, 200k contexte
- **Gemini 1.5 Pro** (Google) : 1.25/5.00 $/MTok, 2M contexte

**Use Cases Optimaux** :
- Refactorings majeurs
- Analyses performance
- Architecture systèmes multi-composants
- Synthèses documentaires complexes

### 1.4 Tier SOTA : Raisonnement Maximal

**Caractéristiques** :
- **Vitesse** : 2000-5000ms latence moyenne
- **Coût** : 3.00-15.00 $/MTok input, 15.00-75.00 $/MTok output
- **Fenêtre contexte** : 200k+ tokens (illimité pratique)
- **Capacités** : Raisonnement profond, créativité, architecture complexe

**Modèles Représentatifs** :
- **Claude Sonnet 4** (Anthropic) : 3.00/15.00 $/MTok, 200k contexte
- **GPT-4o** (OpenAI) : 2.50/10.00 $/MTok, 128k contexte
- **o1-preview** (OpenAI) : 15.00/60.00 $/MTok, 128k contexte (raisonnement extended)
- **Gemini 2.0 Flash Thinking** (Google) : Raisonnement avancé expérimental

**Use Cases Optimaux** :
- Architecture distribuée complexe
- Optimisations algorithmes avancées
- Debugging concurrence/race conditions
- Décisions architecturales stratégiques

---

## 🗺️ 2. Mapping Modes → LLMs

### 2.1 Tableau de Mapping Complet

| Famille Mode | Mode Simple | LLM Recommandé Simple | Tier | Mode Complex | LLM Recommandé Complex | Tier |
|--------------|-------------|----------------------|------|--------------|------------------------|------|
| **Code** | `code-simple` | Claude 3.5 Haiku<br>GPT-4o-mini<br>Gemini 2.0 Flash | Flash/Mini | `code-complex` | Claude Sonnet 4<br>GPT-4o<br>o1-preview | SOTA |
| **Debug** | `debug-simple` | Claude 3.5 Haiku<br>GPT-4o-mini | Flash/Mini | `debug-complex` | Claude Sonnet 4<br>GPT-4o<br>o1-preview | SOTA |
| **Architect** | `architect-simple` | Claude 3 Haiku<br>Qwen 3 32B | Mini | `architect-complex` | Claude Sonnet 4<br>GPT-4o<br>Gemini 1.5 Pro | SOTA/Standard |
| **Ask** | `ask-simple` | Claude 3.5 Haiku<br>GPT-4o-mini<br>Gemini 2.0 Flash | Flash/Mini | `ask-complex` | Claude Sonnet 4<br>GPT-4o<br>Gemini 1.5 Pro | SOTA/Standard |
| **Orchestrator** | `orchestrator-simple` | Claude 3 Haiku<br>Qwen 3 32B | Mini | `orchestrator-complex` | Claude Sonnet 4<br>GPT-4o | SOTA |

### 2.2 Modes Spéciaux

| Mode | LLM Recommandé | Tier | Justification |
|------|----------------|------|---------------|
| **manager** | Claude Sonnet 4<br>GPT-4o | SOTA | Décisions stratégiques critiques, décomposition workflows complexes, coordination multi-modes |
| **mode-family-validator** | Claude Sonnet 4<br>GPT-4o | SOTA | Validation cohérence architecture, détection incohérences subtiles, analyse cross-modes |

### 2.3 Rationale par Famille

#### 💻 Famille CODE

**Modes Simples (Flash/Mini)** :
- Tâches : Modifications <50 lignes, fonctions isolées, refactorings mineurs
- Justification : Latence critique pour feedback rapide, coût optimisé pour itérations fréquentes
- Modèles : Claude 3.5 Haiku (meilleur équilibre qualité/coût)

**Modes Complex (SOTA)** :
- Tâches : Refactorings majeurs, architecture multi-composants, patterns avancés
- Justification : Raisonnement profond requis, compréhension contexte étendu
- Modèles : Claude Sonnet 4 (meilleur raisonnement architectural), o1-preview (optimisations algorithmes)

#### 🪲 Famille DEBUG

**Modes Simples (Flash/Mini)** :
- Tâches : Bugs syntaxe, erreurs configuration, problèmes reproductibles
- Justification : Identification rapide problèmes évidents, validations iteratives
- Modèles : Claude 3.5 Haiku (diagnostic efficace)

**Modes Complex (SOTA)** :
- Tâches : Race conditions, memory leaks, problèmes performance, bugs systèmes
- Justification : Investigation profonde, analyse multi-niveaux, profiling complexe
- Modèles : Claude Sonnet 4 (meilleure analyse systémique), o1-preview (debugging algorithmique)

#### 🏗️ Famille ARCHITECT

**Modes Simples (Mini)** :
- Tâches : Documentation composants, diagrammes simples, plans features isolées
- Justification : Génération documentation structurée, compréhension patterns standards
- Modèles : Qwen 3 32B (bon compromis), Claude 3 Haiku

**Modes Complex (SOTA/Standard)** :
- Tâches : Architecture distribuée, patterns avancés (CQRS, Event Sourcing), décisions stratégiques
- Justification : Raisonnement architectural profond, trade-offs complexes
- Modèles : Claude Sonnet 4 (meilleur architecte), Gemini 1.5 Pro (contexte 2M tokens pour large codebases)

#### ❓ Famille ASK

**Modes Simples (Flash/Mini)** :
- Tâches : Questions factuelles, concepts basiques, résumés concis
- Justification : Réponses rapides, coût minimal pour queries fréquentes
- Modèles : Claude 3.5 Haiku, Gemini 2.0 Flash (ultra-rapide)

**Modes Complex (SOTA/Standard)** :
- Tâches : Recherches approfondies, analyses comparatives, synthèses complexes
- Justification : Compréhension nuancée, synthèse multi-sources
- Modèles : Claude Sonnet 4 (meilleur synthétiseur), Gemini 1.5 Pro (contexte étendu)

#### 🎭 Famille ORCHESTRATOR

**Modes Simples (Mini)** :
- Tâches : Coordination <3 sous-tâches, workflows linéaires
- Justification : Décomposition basique, gestion simple dépendances
- Modèles : Qwen 3 32B, Claude 3 Haiku

**Modes Complex (SOTA)** :
- Tâches : Workflows multi-étapes, coordination >5 modes, dépendances complexes
- Justification : Planification stratégique, gestion états complexes
- Modèles : Claude Sonnet 4 (meilleur planificateur), GPT-4o

---

## ⚡ 3. Critères Escalade Simple → Complex

### 3.1 Seuils Quantitatifs

#### Critère 1 : Tokens Consommés

```
┌─────────────────────────────────────────────────────────────┐
│ SEUIL TOKENS : Escalade si consommation > seuil            │
├─────────────────────────────────────────────────────────────┤
│ Mode Simple :                                               │
│ • ⚠️ Alerte précoce : 25k tokens (25% fenêtre)            │
│ • 🔔 Recommandation escalade : 40k tokens (40% fenêtre)    │
│ • 🚨 Escalade OBLIGATOIRE : 50k tokens (50% fenêtre)       │
│                                                             │
│ Raison : Préserver budget contexte, éviter saturation      │
│ Action : Escalade vers mode complex OU délégation          │
└─────────────────────────────────────────────────────────────┘
```

**Format détection** :
```markdown
[SEUIL TOKENS ATTEINT] 
Consommation actuelle : 42k/50k tokens (84%)
Recommandation : Escalade vers {mode}-complex
Raison : Préservation budget contexte pour finalisation
```

#### Critère 2 : Sous-Tâches Créées

```
┌─────────────────────────────────────────────────────────────┐
│ SEUIL SOUS-TÂCHES : Escalade si création > 3 sous-tâches   │
├─────────────────────────────────────────────────────────────┤
│ Mode Simple :                                               │
│ • ✅ 1-2 sous-tâches : Normal (décomposition atomique)     │
│ • ⚠️ 3 sous-tâches : Limite, évaluer escalade              │
│ • 🚨 >3 sous-tâches : Escalade OBLIGATOIRE                 │
│                                                             │
│ Raison : Complexité coordination dépasse capacité simple   │
│ Action : Escalade vers orchestrator-complex                │
└─────────────────────────────────────────────────────────────┘
```

**Format détection** :
```markdown
[SEUIL SOUS-TÂCHES DÉPASSÉ]
Sous-tâches créées : 4 (seuil max : 3)
Recommandation : Escalade vers orchestrator-complex
Raison : Coordination multi-modes complexe requise
```

#### Critère 3 : Fichiers Manipulés

```
┌─────────────────────────────────────────────────────────────┐
│ SEUIL FICHIERS : Escalade si manipulation > 10 fichiers    │
├─────────────────────────────────────────────────────────────┤
│ Mode Simple (code/debug) :                                  │
│ • ✅ 1-5 fichiers : Normal (tâche focalisée)               │
│ • ⚠️ 6-10 fichiers : Limite, évaluer escalade              │
│ • 🚨 >10 fichiers : Escalade OBLIGATOIRE                   │
│                                                             │
│ Raison : Impact architectural global, refactoring majeur   │
│ Action : Escalade vers mode complex équivalent             │
└─────────────────────────────────────────────────────────────┘
```

**Format détection** :
```markdown
[SEUIL FICHIERS DÉPASSÉ]
Fichiers à modifier : 12 (seuil max : 10)
Recommandation : Escalade vers code-complex
Raison : Refactoring architectural multi-composants
```

#### Critère 4 : Durée Tâche

```
┌─────────────────────────────────────────────────────────────┐
│ SEUIL DURÉE : Escalade si durée > 15 minutes               │
├─────────────────────────────────────────────────────────────┤
│ Mode Simple :                                               │
│ • ✅ <10 minutes : Normal (tâche ciblée)                   │
│ • ⚠️ 10-15 minutes : Limite, évaluer escalade              │
│ • 🚨 >15 minutes : Escalade RECOMMANDÉE                    │
│                                                             │
│ Raison : Complexité sous-estimée, investigations longues   │
│ Action : Checkpoint ou escalade vers mode complex          │
└─────────────────────────────────────────────────────────────┘
```

**Format détection** :
```markdown
[DURÉE TÂCHE EXCESSIVE]
Temps écoulé : 18 minutes (seuil max : 15)
Recommandation : Escalade vers {mode}-complex OU checkpoint
Raison : Tâche plus complexe que prévu, investigations étendues
```

#### Critère 5 : Complexité Raisonnement

```
┌─────────────────────────────────────────────────────────────┐
│ PATTERNS COMPLEXITÉ : Détection patterns raisonnement      │
├─────────────────────────────────────────────────────────────┤
│ Indicateurs Escalade :                                      │
│ • 🚨 Multi-étapes dépendantes (>3 niveaux)                 │
│ • 🚨 Décisions trade-offs complexes                        │
│ • 🚨 Patterns avancés (CQRS, Event Sourcing, DDD)         │
│ • 🚨 Analyses performance multi-dimensions                 │
│ • 🚨 Architecture distribuée                               │
│                                                             │
│ Action : Escalade immédiate vers mode complex              │
└─────────────────────────────────────────────────────────────┘
```

**Exemples patterns** :
- **Architecture** : Conception microservices, choix messaging bus
- **Performance** : Profiling multi-threads, optimisations algorithmes
- **Code** : Refactorings patterns (Singleton → Factory → Strategy)
- **Debug** : Race conditions, deadlocks, memory leaks

### 3.2 Mécaniques Escalade (Référence)

Le document [`escalade-mechanisms-revised.md`](escalade-mechanisms-revised.md) définit 3 formes d'escalade :

#### Forme 1 : Escalade Interne (switch_mode)

**Caractéristiques** :
- **Direction** : Simple → Complex au sein de la même tâche
- **Quand** : Contexte trop dense pour sous-tâche (>40 messages)
- **Risque** : Incompatibilité contexte après switch
- **Recommandation** : RARE, privilégier Forme 2

**Exemple** :
```xml
<switch_mode>
<mode_slug>code-complex</mode_slug>
<reason>[ESCALADE INTERNE] Refactorisation architecture 65 lignes,
4 composants interdépendants, contexte 42k/60k impossible à résumer
</reason>
</switch_mode>
```

#### Forme 2 : Escalade Externe-Compétente (new_task)

**Caractéristiques** :
- **Direction** : Simple → Complex via sous-tâche "Oracle"
- **Quand** : Mode a toutes infos MAIS manque compétences techniques
- **Avantages** : Évite incompatibilité contexte, traçabilité SDDD
- **Recommandation** : PRIVILÉGIÉE (90% des cas)

**Exemple** :
```xml
<new_task>
<mode>code-complex</mode>
<message>🎯 **Sous-tâche 1.2 : Implémentation Pattern Observer Complex**

**Contexte Escalade** : code-simple identifie besoin expertise patterns avancés.

**Informations Complètes Disponibles** :
- Architecture actuelle : EventEmitter basique
- API publique définie : subscribe(), unsubscribe(), notify()
- Performance requirements : <10ms latency

**Besoin Compétence Complex** :
- Conception pattern Observer avancé
- Gestion weak references TypeScript
- Optimisations performance événements

[ESCALADE EXTERNE-COMPÉTENTE] Mode simple a toutes infos, manque expertise patterns.
</message>
</new_task>
```

#### Forme 3 : Escalade Externe-Contextuelle (Terminaison Échec)

**Caractéristiques** :
- **Direction** : Terminaison avec rapport détaillé
- **Quand** : Mode manque contexte frais (même complex échouerait)
- **Action** : Orchestrateur parent mobilise contexte additionnel
- **Recommandation** : Situations exceptionnelles

**Exemple** :
```xml
<attempt_completion>
<result>❌ [ESCALADE EXTERNE-CONTEXTUELLE]

**Impossibilité Complétude** :
Tâche nécessite décisions architecturales sur choix messaging bus,
mais contexte frais insuffisant (spécifications techniques absentes).

**Rapport Détaillé** :
- Options identifiées : RabbitMQ, Kafka, Redis Streams
- Critères manquants : Latence acceptable, volume messages, budget infra
- Impact global : Migration complète système événements

**Action Requise Orchestrateur** :
1. Obtenir specs techniques auprès utilisateur
2. Analyser contraintes infrastructure
3. Créer sous-tâche architect-complex avec contexte complet
</result>
</attempt_completion>
```

### 3.3 Exemples Tokens et Escalade

**Scénario 1 : Mode Simple Approche Seuil**
```markdown
**Situation** : code-simple à 42k/50k tokens (84% contexte)

**Détection** :
[SEUIL TOKENS ATTEINT]
Consommation : 42k/50k tokens
Restant : 8k tokens (insuffisant pour finalisation)

**Actions Possibles** :
1. ✅ PRIVILÉGIÉ : Créer sous-tâche code-complex pour implémentation complexe
2. ✅ ALTERNATIF : Décomposer en 2 sous-tâches code-simple atomiques
3. ❌ DÉCONSEILLÉ : Continuer en mode simple (risque saturation)

**Exemple Délégation** :
<new_task>
<mode>code-complex</mode>
<message>[ESCALADE SEUIL TOKENS] 42k/50k tokens consommés.
Délégation implémentation patterns avancés pour préserver budget finalisation.
</message>
</new_task>
```

**Scénario 2 : Escalade Tokens + Complexité Combinée**
```markdown
**Situation** : debug-simple face à race condition + 38k tokens

**Détection Multi-Critères** :
• ⚠️ Tokens : 38k/50k (76%, proche seuil 40k)
• 🚨 Complexité : Race condition (pattern complexe)
• 🚨 Durée : 12 minutes (proche seuil 15min)

**Décision** : Escalade IMMÉDIATE (combinaison critères)

**Exemple** :
<new_task>
<mode>debug-complex</mode>
<message>[ESCALADE MULTI-CRITÈRES]
• Tokens : 38k/50k (préservation budget)
• Complexité : Race condition EventEmitter (expertise concurrence)
• Durée : 12min (investigation longue prévue)

[ESCALADE EXTERNE-COMPÉTENTE] Besoin expertise debugging concurrent.
</message>
</new_task>
```

---

## 📊 4. Patterns d'Usage par Cas

### Cas 1 : Correction Bug Simple

**Contexte** :
- Bug syntaxe TypeScript identifié par linter
- Fichier unique concerné (<50 lignes)
- Correction évidente (typo, type incorrect)

**Pattern Recommandé** :
```
Mode : code-simple
LLM : Claude 3.5 Haiku (Flash)
Budget : 5k-10k tokens
Durée : 2-5 minutes
```

**Workflow** :
1. Grounding sémantique : `codebase_search("typescript linter error fix")`
2. Lecture fichier : `read_file("src/utils.ts")`
3. Correction ciblée : `apply_diff` ou `write_to_file`
4. Validation : Relecture + tests unitaires

**Justification Tier Flash** :
- Tâche répétitive standard
- Pas de raisonnement complexe requis
- Latence <500ms critique pour itérations rapides
- Coût optimisé pour corrections fréquentes

### Cas 2 : Refactorisation Architecture Complexe

**Contexte** :
- Migration monolithe → microservices (6 services)
- 15 fichiers à refactoriser
- Patterns CQRS + Event Sourcing à implémenter

**Pattern Recommandé** :
```
Mode : code-complex
LLM : Claude Sonnet 4 (SOTA)
Budget : 100k-150k tokens
Durée : 45-90 minutes
```

**Workflow** :
1. Grounding sémantique approfondi :
   ```xml
   <codebase_search>
   <query>architecture monolithe services communication patterns CQRS</query>
   </codebase_search>
   ```
2. Analyse architecture actuelle (quickfiles batch 15 fichiers)
3. Conception architecture cible (diagrammes C4)
4. Décomposition en sous-tâches code-simple pour implémentation
5. Validation intégration

**Justification Tier SOTA** :
- Raisonnement architectural profond requis
- Trade-offs complexes (performance, scalabilité, complexité)
- Patterns avancés nécessitant expertise
- Coût justifié par impact projet majeur

### Cas 3 : Question Technique Ponctuelle

**Contexte** :
- Utilisateur demande : "Comment fonctionne async/await en JavaScript ?"
- Réponse factuelle attendue
- Exemple code simple requis

**Pattern Recommandé** :
```
Mode : ask-simple
LLM : Gemini 2.0 Flash (Flash)
Budget : 2k-5k tokens
Durée : <1 minute
```

**Workflow** :
1. Pas de grounding nécessaire (connaissance générale)
2. Réponse directe avec exemple
3. Validation cohérence

**Justification Tier Flash** :
- Question factuelle standard
- Pas de recherche approfondie requise
- Latence ultra-rapide prioritaire (UX)
- Coût minimal pour queries fréquentes

### Cas 4 : Analyse Approfondie Multi-Documents

**Contexte** :
- Analyse comparative 8 frameworks ML production
- Synthèse académique + benchmarks + retours expérience
- Rapport 500+ lignes attendu

**Pattern Recommandé** :
```
Mode : ask-complex
LLM : Claude Sonnet 4 (SOTA)
Budget : 80k-120k tokens
Durée : 30-60 minutes
```

**Workflow** :
1. Recherches web (MCP searxng) : 
   ```xml
   <use_mcp_tool>
   <server_name>searxng</server_name>
   <tool_name>searxng_web_search</tool_name>
   <arguments>{"query": "ML frameworks production comparison TensorFlow Serving TorchServe"}</arguments>
   </use_mcp_tool>
   ```
2. Extraction contenu (MCP jinavigator multi_convert)
3. Analyse comparative multi-dimensions
4. Synthèse structurée avec recommandations

**Justification Tier SOTA** :
- Synthèse complexe multi-sources
- Analyse nuancée trade-offs
- Expertise domaine ML ops requise
- Qualité synthèse critique pour décision stratégique

### Cas 5 : Orchestration Projet Multi-Phases

**Contexte** :
- Projet migration base de données (6 phases)
- 12 sous-tâches interdépendantes
- Coordination 4 modes différents (code, debug, architect, ask)

**Pattern Recommandé** :
```
Mode : orchestrator-complex
LLM : Claude Sonnet 4 (SOTA)
Budget : 150k-200k tokens
Durée : 2-4 heures (workflow complet)
```

**Workflow** :
1. Grounding conversationnel (roo-state-manager) :
   ```xml
   <use_mcp_tool>
   <server_name>roo-state-manager</server_name>
   <tool_name>conversation_browser</tool_name>
   <arguments>{"action": "view", "workspace": "c:/dev/project", "view_mode": "chain"}</arguments>
   </use_mcp_tool>
   ```
2. Analyse dépendances et phases
3. Création sous-tâches séquentielles/parallèles :
   - Phase 1 : architect-complex (conception migration)
   - Phase 2 : code-simple (scripts migration batch 1-3)
   - Phase 3 : debug-complex (validation intégrité données)
   - Phase 4 : ask-complex (documentation procédures)
4. Synthèse résultats et validation globale

**Justification Tier SOTA** :
- Planification stratégique complexe
- Gestion états multi-modes
- Coordination dépendances circulaires
- Décisions architecture critiques impact global

---

## ⚙️ 5. Configuration Recommandée

### 5.1 Structure `custom_modes.json`

**Template Configuration Mode Simple** :
```json
{
  "slug": "code-simple",
  "name": "💻 Code Simple",
  "source": "global",
  "groups": ["read", "edit", "browser", "command", "mcp"],
  "model": "anthropic/claude-3-5-haiku-20241022",
  "roleDefinition": "You are Roo Code (version simple), specialized in minor code modifications, simple bug fixes, code formatting and documentation, and basic feature implementation.",
  "customInstructions": "FOCUS AREAS:\n- Modifications de code < 50 lignes\n- Fonctions isolées\n- Bugs simples\n- Patterns standards\n- Documentation basique\n\nMÉCHANISME D'ESCALADE:\nVous DEVEZ escalader toute tâche dépassant :\n- Modifications > 50 lignes\n- Refactorisations majeures\n- Architecture complexe\n- Optimisations performance\n\nGESTION DES TOKENS:\n- ⚠️ Alerte : 25k tokens\n- 🔔 Escalade recommandée : 40k tokens\n- 🚨 Escalade OBLIGATOIRE : 50k tokens"
}
```

**Template Configuration Mode Complex** :
```json
{
  "slug": "code-complex",
  "name": "💻 Code Complex",
  "source": "global",
  "groups": ["read", "edit", "browser", "command", "mcp"],
  "model": "anthropic/claude-sonnet-4-20250514",
  "roleDefinition": "You are Roo, a highly skilled software engineer with extensive knowledge in many programming languages, frameworks, design patterns, and best practices.",
  "customInstructions": "FOCUS AREAS:\n- Major refactoring\n- Architecture design\n- Performance optimization\n- Complex algorithms\n- System integration\n\nDÉLÉGATION SYSTÉMATIQUE:\nVous DEVEZ déléguer vers modes simples dès que possible :\n- Finalisation (tests, documentation)\n- Implémentations atomiques post-conception\n- Coordination multi-tâches\n\nGESTION DES TOKENS:\n- Budget étendu (100k+ tokens)\n- Checkpoint conversationnel : 50k tokens (roo-state-manager)\n- Escalade orchestrator-complex : >100k tokens"
}
```

### 5.2 Recommandations par Provider

#### Anthropic (Recommandé Principal)

**Avantages** :
- Meilleur raisonnement architectural (Claude Sonnet 4)
- Fenêtre contexte 200k tokens (stable)
- Support tool use natif excellent
- Pricing compétitif tier Flash (Haiku 3.5)

**Configuration Optimale** :
```json
{
  "modes_simples": {
    "model": "anthropic/claude-3-5-haiku-20241022",
    "cost_input": 0.25,
    "cost_output": 1.25,
    "context_window": 200000
  },
  "modes_complex": {
    "model": "anthropic/claude-sonnet-4-20250514",
    "cost_input": 3.00,
    "cost_output": 15.00,
    "context_window": 200000
  },
  "modes_speciaux": {
    "model": "anthropic/claude-sonnet-4-20250514",
    "cost_input": 3.00,
    "cost_output": 15.00,
    "context_window": 200000
  }
}
```

#### OpenAI (Alternative Performance)

**Avantages** :
- GPT-4o excellent équilibre vitesse/qualité
- o1-preview pour raisonnement extended
- GPT-4o-mini très économique tier Flash

**Configuration Optimale** :
```json
{
  "modes_simples": {
    "model": "openai/gpt-4o-mini",
    "cost_input": 0.15,
    "cost_output": 0.60,
    "context_window": 128000
  },
  "modes_complex": {
    "model": "openai/gpt-4o",
    "cost_input": 2.50,
    "cost_output": 10.00,
    "context_window": 128000
  },
  "modes_raisonnement_profond": {
    "model": "openai/o1-preview",
    "cost_input": 15.00,
    "cost_output": 60.00,
    "context_window": 128000
  }
}
```

#### Google (Alternative Contexte Étendu)

**Avantages** :
- Gemini 2.0 Flash ultra-rapide
- Gemini 1.5 Pro : 2M tokens contexte
- Pricing agressif tier Flash

**Configuration Optimale** :
```json
{
  "modes_simples": {
    "model": "google/gemini-2.0-flash-exp",
    "cost_input": 0.075,
    "cost_output": 0.30,
    "context_window": 1048576
  },
  "modes_complex_contexte_large": {
    "model": "google/gemini-1.5-pro-002",
    "cost_input": 1.25,
    "cost_output": 5.00,
    "context_window": 2097152
  }
}
```

### 5.3 Configuration Hybride Recommandée

**Stratégie "Best of Breed"** :
```json
{
  "code-simple": "anthropic/claude-3-5-haiku-20241022",
  "code-complex": "anthropic/claude-sonnet-4-20250514",
  "debug-simple": "anthropic/claude-3-5-haiku-20241022",
  "debug-complex": "openai/o1-preview",
  "architect-simple": "anthropic/claude-3-5-haiku-20241022",
  "architect-complex": "anthropic/claude-sonnet-4-20250514",
  "ask-simple": "google/gemini-2.0-flash-exp",
  "ask-complex": "anthropic/claude-sonnet-4-20250514",
  "orchestrator-simple": "anthropic/claude-3-5-haiku-20241022",
  "orchestrator-complex": "anthropic/claude-sonnet-4-20250514",
  "manager": "anthropic/claude-sonnet-4-20250514",
  "mode-family-validator": "anthropic/claude-sonnet-4-20250514"
}
```

**Justification Hybride** :
- **Claude Sonnet 4** : Meilleur all-around (architecture, coordination)
- **Claude 3.5 Haiku** : Meilleur Flash tier (équilibre qualité/coût)
- **Gemini 2.0 Flash** : Ultra-rapide ask-simple (latence <300ms)
- **o1-preview** : Debugging algorithmes complexes (raisonnement extended)

---

## 💰 6. Optimisation Budget Tokens

### 6.1 Stratégies Économie Contexte

Le document [`context-economy-patterns.md`](context-economy-patterns.md) définit les principes d'optimisation. Voici l'adaptation par tier LLM.

#### Modes Simples (Flash/Mini) : Grounding Minimal

**Principe** : Économie tokens MAIS pas au détriment qualité.

**Pattern Recommandé** :
```markdown
Phase 1 : Grounding Initial
├─ ✅ Grounding Sémantique (codebase_search) - 1-2 requêtes ciblées
├─ ✅ Grounding Fichier (read_file) - Lecture complète fichiers pertinents
└─ ❌ Grounding Conversationnel - Uniquement si reprise >24h

Phase 2 : Exécution
├─ ✅ Délégation prioritaire (si >3 actions token-heavy)
├─ ✅ MCP Batch (quickfiles.read_multiple_files pour ≥3 fichiers)
└─ ❌ Lectures fragmentées (anti-pattern angles morts)

Checkpoint 50k : ❌ Inaccessible (escalade AVANT seuil)
```

**Règle Critique** : Modes simples ne doivent JAMAIS approcher 50k tokens. Escalade OBLIGATOIRE à 40k.

#### Modes Complex (SOTA) : Grounding Complet

**Principe** : Budget tokens élevé permet grounding exhaustif.

**Pattern Recommandé** :
```markdown
Phase 1 : Grounding Initial (4 Niveaux SDDD)
├─ ✅ Niveau 1 : Fichier (read_file, list_code_definition_names)
├─ ✅ Niveau 2 : Sémantique (codebase_search multi-requêtes)
├─ ✅ Niveau 3 : Conversationnel (roo-state-manager si reprise)
└─ ⏳ Niveau 4 : Projet (github-projects - Roadmap Q4 2025)

Phase 2 : Exécution avec Délégation
├─ ✅ Délégation systématique implémentations → code-simple
├─ ✅ Délégation finalisation → orchestrator-simple
└─ ✅ Lecture complète fichiers (principe anti-angles-morts)

Checkpoint 50k : ✅ OBLIGATOIRE (roo-state-manager)
├─ Validation cohérence objectif conversationnel
├─ Détection dérive cognitive
└─ Décision : Continuer vs Décomposer
```

**Règle Critique** : Modes complex DOIVENT faire checkpoint 50k via `roo-state-manager` pour prévenir dérive.

### 6.2 Délégation Lecture Fichiers Volumineux

**Problème** : Lecture massive fichiers sature contexte rapidement.

**Solution** : Délégation sous-tâche spécialisée.

**Exemple** :
```xml
<!-- Mode Complex AVANT saturation contexte -->
<new_task>
<mode>code-simple</mode>
<message>🎯 **Sous-tâche Délégation : Lecture Batch Architecture**

**Contexte** : Analyse architecture nécessite lecture 15 fichiers (estimation 40k tokens).

**Action Requise** :
1. Utiliser quickfiles.read_multiple_files :
   - src/core/*.ts (8 fichiers)
   - src/services/*.ts (7 fichiers)
2. Extraire :
   - Structure classes principales
   - Dépendances entre modules
   - Patterns architecturaux utilisés
3. Synthèse condensée :
   - Diagramme classes simplifié
   - Liste dépendances critiques
   - Patterns identifiés

**Livrable** : Synthèse 2-3k tokens (vs 40k lecture brute).

[DÉLÉGATION ÉCONOMIE CONTEXTE] Préservation budget mode complex pour analyse.
</message>
</new_task>
```

**Gain** : 40k tokens lecture → 2-3k tokens synthèse = **93% économie**.

### 6.3 Compression Contexte Historique

**Problème** : Conversations longues (>100 messages) saturent contexte.

**Solution** : Checkpoint SDDD avec synthèse.

**Workflow** :
```markdown
1. Détection Seuil :
   - 50k tokens : Checkpoint conversationnel OBLIGATOIRE
   - 100k tokens : Décomposition en sous-tâches

2. Checkpoint via roo-state-manager :
   ```xml
   <use_mcp_tool>
   <server_name>roo-state-manager</server_name>
   <tool_name>conversation_browser</tool_name>
   <arguments>
   {
     "action": "view",
     "workspace": "c:/dev/project",
     "view_mode": "chain",
     "detail_level": "summary"
   }
   </arguments>
   </use_mcp_tool>
   ```

3. Validation Cohérence :
   - Objectif initial vs travail actuel
   - Détection dérives
   - Décision : Continuer vs Escalade orchestrator

4. Synthèse Mental Model :
   - État actuel projet
   - Décisions architecturales
   - Todo restantes
```

### 6.4 ROI Patterns Économie

Le document [`context-economy-patterns.md`](context-economy-patterns.md#roi-patterns) documente le ROI de chaque pattern :

| Pattern | Coût Implémentation | Économie Générée | ROI | Tier Optimal |
|---------|---------------------|------------------|-----|--------------|
| **Délégation** | Faible (planning) | **Très élevée** (parallélisation) | **500%** | Simple → Simple |
| **Lecture Complète** | Moyen (tokens) | **Élevée** (évite re-travail) | **300%** | Tous tiers |
| **MCP Batch** | Faible (setup) | Moyenne (overhead) | 200% | Flash/Mini |
| **Checkpoint 50k** | Moyen (grounding) | **Très élevée** (prévention dérive) | **400%** | SOTA |

**Conclusion** : Les patterns "économes en tokens" mal appliqués (lecture fragmentée) ont un ROI **NÉGATIF** (-150%) quand re-travail inclus.

---

## 📈 7. Monitoring et Métriques

### 7.1 Métriques à Tracker

#### Métrique 1 : Coût Moyen par Mode

**Objectif** : Identifier modes coûteux et optimiser allocation LLM.

**Tracking** :
```json
{
  "mode": "code-complex",
  "period": "2025-Q4",
  "metrics": {
    "total_tasks": 142,
    "total_cost": 84.50,
    "avg_cost_per_task": 0.595,
    "cost_distribution": {
      "input_tokens": 48.20,
      "output_tokens": 36.30
    },
    "avg_tokens_per_task": {
      "input": 25430,
      "output": 8720
    }
  },
  "recommendations": [
    "✅ Coût aligné budget (target: <$1.00/task)",
    "⚠️ 18% tâches >50k tokens → Évaluer escalade précoce"
  ]
}
```

**Seuils Alertes** :
- 🟢 <$0.50/task : Optimal
- 🟡 $0.50-$1.00/task : Normal
- 🔴 >$1.00/task : Investigation requise

#### Métrique 2 : Taux Escalade Simple → Complex

**Objectif** : Valider adéquation modes simples vs tâches réelles.

**Tracking** :
```json
{
  "period": "2025-Q4",
  "total_simple_tasks": 587,
  "escalations": {
    "total": 94,
    "rate": 0.16,
    "breakdown": {
      "tokens_threshold": 42,
      "complexity_detected": 38,
      "files_threshold": 8,
      "subtasks_threshold": 6
    }
  },
  "analysis": {
    "healthy_rate": "10-20%",
    "current_rate": "16%",
    "assessment": "✅ Normal - Modes simples bien calibrés"
  },
  "recommendations": [
    "✅ Taux escalade sain (16% dans range 10-20%)",
    "💡 45% escalades tokens → Renforcer pattern délégation"
  ]
}
```

**Seuils Optimaux** :
- 🟢 10-20% : Modes bien calibrés
- 🟡 20-30% : Modes simples potentiellement trop limités
- 🔴 >30% : Revoir critères escalade

#### Métrique 3 : Temps Moyen Résolution par Tier

**Objectif** : Valider gains performance tiers Flash/Mini.

**Tracking** :
```json
{
  "period": "2025-Q4",
  "tier_performance": {
    "flash": {
      "avg_latency_ms": 420,
      "avg_resolution_time_min": 3.2,
      "task_types": ["bug_syntax", "formatting", "simple_refactor"],
      "success_rate": 0.94
    },
    "mini": {
      "avg_latency_ms": 780,
      "avg_resolution_time_min": 8.5,
      "task_types": ["feature_isolated", "debug_simple", "doc_technical"],
      "success_rate": 0.91
    },
    "sota": {
      "avg_latency_ms": 3200,
      "avg_resolution_time_min": 42.0,
      "task_types": ["architecture", "refactor_major", "debug_complex"],
      "success_rate": 0.97
    }
  },
  "analysis": {
    "flash_advantage": "7.4x faster than SOTA for simple tasks",
    "cost_benefit": "$0.15 Flash vs $3.50 SOTA for equivalent simple task",
    "quality_trade_off": "3% lower success rate acceptable for speed"
  }
}
```

**Insights** :
- Flash tier : Latence <500ms critique UX tâches simples
- SOTA tier : Temps résolution 10x+ mais success rate supérieur (97%)
- ROI Flash : Économie $3.35/task pour bugs simples

#### Métrique 4 : Satisfaction Utilisateur par Mode

**Objectif** : Valider qualité output vs coût LLM.

**Tracking** :
```json
{
  "period": "2025-Q4",
  "user_satisfaction": {
    "code-simple_flash": {
      "avg_rating": 4.2,
      "total_ratings": 214,
      "feedback_themes": [
        "✅ Très rapide",
        "✅ Corrections précises",
        "⚠️ Parfois manque contexte global"
      ]
    },
    "code-complex_sota": {
      "avg_rating": 4.7,
      "total_ratings": 89,
      "feedback_themes": [
        "✅ Excellente compréhension architecture",
        "✅ Solutions élégantes",
        "⚠️ Latence parfois notable"
      ]
    }
  },
  "correlation_cost_satisfaction": {
    "flash_tier": "4.2 rating @ $0.15/task = 28.0 rating/dollar",
    "sota_tier": "4.7 rating @ $3.50/task = 1.34 rating/dollar",
    "insight": "Flash tier meilleur ROI satisfaction pour tâches simples"
  }
}
```

**Seuils Qualité** :
- 🟢 >4.5 : Excellent
- 🟡 4.0-4.5 : Bon
- 🔴 <4.0 : Amélioration requise

### 7.2 Dashboards Monitoring

#### Dashboard 1 : Vue Temps Réel

**Métriques Affichées** :
```markdown
┌─────────────────────────────────────────────────────────┐
│ 🎯 MONITORING TEMPS RÉEL - Modes Roo                   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Tâches Actives : 12                                    │
│ ├─ code-simple (Flash) : 7 tâches                      │
│ ├─ code-complex (SOTA) : 3 tâches                      │
│ ├─ debug-simple (Flash) : 1 tâche                      │
│ └─ architect-complex (SOTA) : 1 tâche                  │
│                                                         │
│ Consommation Tokens (30 dernières minutes) :           │
│ ├─ Input : 142k tokens ($0.68)                         │
│ └─ Output : 48k tokens ($1.92)                         │
│                                                         │
│ Alertes Actives :                                       │
│ ├─ ⚠️ code-simple task_8742 : 42k/50k tokens (84%)    │
│ └─ 🔔 debug-complex task_8739 : 18min (seuil 15min)   │
│                                                         │
│ Escalades (dernière heure) : 3                         │
│ ├─ code-simple → code-complex : 2                      │
│ └─ orchestrator-simple → orchestrator-complex : 1      │
└─────────────────────────────────────────────────────────┘
```

#### Dashboard 2 : Vue Historique

**Métriques Mensuelles** :
```markdown
┌─────────────────────────────────────────────────────────┐
│ 📊 RAPPORT MENSUEL - Octobre 2025                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Volume Tâches : 1,247                                   │
│ ├─ Modes Simples (Flash/Mini) : 894 (71.7%)           │
│ └─ Modes Complex (SOTA) : 353 (28.3%)                 │
│                                                         │
│ Coût Total : $1,284.50                                  │
│ ├─ Flash/Mini : $187.20 (14.6%)                        │
│ └─ SOTA : $1,097.30 (85.4%)                            │
│                                                         │
│ Coût Moyen par Tâche :                                  │
│ ├─ Flash/Mini : $0.21/task                             │
│ └─ SOTA : $3.11/task                                   │
│                                                         │
│ Taux Escalade : 16.2% (✅ Normal 10-20%)               │
│                                                         │
│ Temps Résolution Moyen :                                │
│ ├─ Flash : 3.4 minutes                                 │
│ ├─ Mini : 9.1 minutes                                  │
│ └─ SOTA : 43.7 minutes                                 │
│                                                         │
│ Satisfaction Utilisateur : 4.4/5.0 (✅ Bon)            │
│                                                         │
│ Recommandations :                                       │
│ ✅ Distribution tiers optimale (72% Flash/Mini)        │
│ ✅ Coût SOTA justifié (success rate 97% vs 92%)       │
│ 💡 Potentiel délégation +15% tâches complex → simple  │
└─────────────────────────────────────────────────────────┘
```

### 7.3 Alertes Automatiques

**Configuration Alertes** :
```json
{
  "alerts": [
    {
      "name": "tokens_threshold_warning",
      "condition": "mode_simple_tokens > 40k",
      "severity": "warning",
      "action": "Suggest escalation to user",
      "message": "⚠️ Task approaching token limit. Consider escalation to {mode}-complex."
    },
    {
      "name": "tokens_threshold_critical",
      "condition": "mode_simple_tokens > 50k",
      "severity": "critical",
      "action": "Force escalation",
      "message": "🚨 Token limit exceeded. Escalation to {mode}-complex REQUIRED."
    },
    {
      "name": "cost_anomaly",
      "condition": "daily_cost > 2x avg_daily_cost",
      "severity": "warning",
      "action": "Notify admin + audit high-cost tasks",
      "message": "💰 Daily cost anomaly detected: ${current_cost} vs ${avg_cost} average."
    },
    {
      "name": "escalation_rate_high",
      "condition": "monthly_escalation_rate > 0.30",
      "severity": "info",
      "action": "Review mode calibration",
      "message": "📊 High escalation rate (>30%). Consider reviewing simple mode thresholds."
    }
  ]
}
```

---

## 🔗 Ressources Complémentaires

### Spécifications Liées

- [`escalade-mechanisms-revised.md`](escalade-mechanisms-revised.md) : Mécanismes d'escalade détaillés
- [`context-economy-patterns.md`](context-economy-patterns.md) : Optimisation tokens par tier LLM
- [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md) : Grounding adaptatif par tier
- [`hierarchie-numerotee-subtasks.md`](hierarchie-numerotee-subtasks.md) : Décomposition atomique optimale

### Configuration Modes

- [`custom_modes.json`](../../Users/jsboi/AppData/Roaming/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/custom_modes.json) : Configuration modes actuelle

### MCPs Critiques

- **quickfiles** : Lecture batch optimisée (économie contexte)
- **roo-state-manager** : Grounding conversationnel checkpoint 50k
- **github-projects** : Niveau 4 SDDD (Roadmap Q4 2025)

---

## 📝 Notes Implémentation

### Phase Actuelle : Spécification Formelle

Cette spécification définit le **cadre théorique** du mapping LLMs-Modes. L'implémentation pratique nécessitera :

1. **Détection Automatique Seuils** :
   - Instrumentation tracking tokens par mode
   - Alertes automatiques approche seuils
   - Logs escalades pour analytics

2. **Configuration Dynamique** :
   - Templates génération automatique `custom_modes.json`
   - Validation cohérence tier LLM vs mode
   - Migration assistée configurations existantes

3. **Monitoring Production** :
   - Dashboards temps réel Grafana/Prometheus
   - Métriques coût par mode/tier
   - Alertes anomalies coût/performance

4. **Optimisation Continue** :
   - A/B testing tiers LLM alternatifs
   - Ajustement seuils escalade data-driven
   - Feedback loop satisfaction utilisateur

### Roadmap Implémentation

**Q4 2025** :
- ✅ Spécification formelle (ce document)
- ⏳ Instrumentation tracking tokens
- ⏳ Alertes seuils automatiques

**Q1 2026** :
- ⏳ Configuration dynamique modes
- ⏳ Dashboards monitoring production
- ⏳ A/B testing tiers LLM

**Q2 2026** :
- ⏳ Optimisation data-driven seuils
- ⏳ Feedback loop utilisateur
- ⏳ Documentation retours expérience

---

**Version :** 1.0.0  
**Dernière mise à jour :** 02 Octobre 2025  
**Prochaine révision :** Q1 2026 (post-implémentation Phase 5)