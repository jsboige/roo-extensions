# 📘 Protocole SDDD 4-Niveaux - Semantic Documentation Driven Design

**Version :** 2.0.0 🔴 **RÉVISION MAJEURE FB-05**  
**Date :** 02 Octobre 2025  
**Architecture :** 2-Niveaux (Simple/Complex)  
**Statut :** Spécification consolidée post-feedback grounding conversationnel  
**Révision :** Clarification checkpoint 50k = grounding conversationnel OBLIGATOIRE

---

## 🚨 Changements Majeurs v2.0.0

Cette version introduit une clarification **CRITIQUE** sur le checkpoint 50k tokens :

### ❌ Version 1.0.0 (OBSOLÈTE - Ambiguë)
- "Checkpoint tous les 50k tokens" sans préciser la nature
- Pas de lien explicite avec `roo-state-manager`
- Risque : Interprété comme simple synthèse documentation
- Résultat : Dérive cognitive non détectée, perte contexte conversationnel

### ✅ Version 2.0.0 (ACTUELLE - Explicite)
- **RÈGLE OBLIGATOIRE** : Checkpoint 50k = Grounding conversationnel via `roo-state-manager`
- 3 types de grounding clairement distingués :
  * **Sémantique** (codebase) - Phase 1
  * **Fichier** (quickfiles, read_file) - Phase 1
  * **Conversationnel** (roo-state-manager) - Phase 2 checkpoint 50k
- Exemples XML concrets de commandes `roo-state-manager`
- Scénarios avant/après par mode (Code, Orchestrateur)
- Résultat : Prévention dérive cognitive, validation cohérence objectif initial

**⚠️ IMPORTANT** : Le checkpoint 50k n'est PAS une suggestion documentation, c'est une **OBLIGATION PROTOCOLE** pour maintenir la cohérence conversationnelle.

---

## 🎯 Objectif du Protocole

Le protocole SDDD (Semantic Documentation Driven Design) établit une méthodologie systématique de **grounding multi-niveaux** pour garantir que tous les modes Roo :
1. Comprennent le contexte existant avant d'agir (grounding initial)
2. Maintiennent la cohérence avec l'objectif conversationnel (grounding périodique)
3. Documentent leur travail de manière découvrable (grounding final)
4. Facilitent la collaboration entre modes et sessions

---

## 🏗️ Architecture 4-Niveaux du Protocole

```
┌─────────────────────────────────────────────────────────────┐
│ NIVEAU 1 : GROUNDING FICHIER (Exploration locale)          │
│ • list_files, read_file, list_code_definition_names        │
│ • Compréhension structure projet immédiate                  │
│ Phase : Grounding Initial (Phase 1)                        │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ NIVEAU 2 : GROUNDING SÉMANTIQUE (Compréhension globale)    │
│ • codebase_search (OBLIGATOIRE en début de tâche)          │
│ • Découverte intentions et patterns architecturaux         │
│ • Fallback : quickfiles pour exploration rapide            │
│ Phase : Grounding Initial (Phase 1)                        │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ NIVEAU 3 : GROUNDING CONVERSATIONNEL (Contexte historique) │
│ • roo-state-manager : view_conversation_tree               │
│ • Compréhension décisions et évolutions projet             │
│ • Continuité entre sessions et modes                        │
│ Phase : Documentation Continue (Phase 2) - Checkpoint 50k  │
│ ⚠️ OBLIGATOIRE tous les 50k tokens (prévention dérive)    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ NIVEAU 4 : GROUNDING GITHUB (Documentation externe)        │
│ • github-projects-mcp : Issues, PR, Projects               │
│ • Synchronisation avec roadmap et équipe                   │
│ • Traçabilité complète (future implémentation)             │
│ Phase : GitHub Projects (Phase 4)                          │
└─────────────────────────────────────────────────────────────┘
```

**Note Architecture** : Les 4 niveaux correspondent à différentes **sources de contexte**, pas à une séquence stricte. Le Niveau 3 (Conversationnel) devient critique au checkpoint 50k tokens pour prévenir la dérive cognitive.

---

## 📋 Phase 1 : Grounding Initial (OBLIGATOIRE)

### 1.1 Grounding Sémantique Systématique

**RÈGLE CRITIQUE** : Au début de TOUTE tâche nécessitant exploration de code, le premier outil utilisé DOIT être `codebase_search`.

> **⚠️ Exception Orchestrateurs** : Les modes orchestrateurs ne disposent pas de `codebase_search`. Ils doivent utiliser le pattern **Grounding par Délégation** (voir [§1.4](#14-exception--orchestrateurs---grounding-par-délégation)).

```xml
<!-- EXEMPLE CORRECT -->
<codebase_search>
<query>architecture modes factorisation templates instructions communes</query>
</codebase_search>
```

**Cas d'usage :**
- ✅ Modifications de code existant
- ✅ Compréhension architecture système
- ✅ Recherche de patterns ou implémentations
- ✅ Analyse avant refactoring
- ❌ Création fichiers complètement nouveaux sans dépendances

### 1.2 Fallback Quickfiles MCP

Si `codebase_search` ne retourne pas de résultats pertinents ou pour exploration rapide :

```xml
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>read_multiple_files</tool_name>
<arguments>
{
  "paths": ["path/to/relevant/files.ts"],
  "max_lines_per_file": 500
}
</arguments>
</use_mcp_tool>
```

**Avantages quickfiles :**
- Lecture batch ultra-rapide (8 fichiers/requête)
- Extraction structures markdown automatique
- Recherche regex multi-fichiers performante

### 1.3 Grounding Conversationnel Initial

Pour tâches nécessitant contexte historique (reprise de session, analyse décisions passées) :

```xml
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>view_conversation_tree</tool_name>
<arguments>
{
  "workspace": "c:/dev/project-name",
  "view_mode": "chain",
  "detail_level": "summary"
}
</arguments>
</use_mcp_tool>
```

**Quand l'utiliser en Phase 1 :**
- Reprise de tâche après interruption (>24h)
- Compréhension décisions architecturales passées
- Identification patterns récurrents problèmes
- Coordination avec travail mode précédent

**Différence avec Checkpoint 50k** : Le grounding conversationnel initial est **optionnel** (selon besoin contexte historique), alors que le checkpoint 50k est **OBLIGATOIRE** (prévention dérive cognitive).

### 1.4 Exception : Orchestrateurs - Grounding par Délégation

**ANTI-SYMÉTRIE ARCHITECTURALE** : Le mode **orchestrateur** présente une particularité unique :
- ❌ **Aucun outil de grounding direct** (pas de `codebase_search`, `read_file`, ou `quickfiles`)
- ✅ **Seul outil disponible** : `new_task()` pour créer des sous-tâches
- 🎯 **Conséquence** : Le grounding doit être effectué **par délégation**

#### Pattern : Grounding par Délégation

L'orchestrateur effectue son grounding **indirectement** via ses sous-tâches selon ce workflow :

**Étapes du pattern :**
1. **Orchestrateur** : Crée une sous-tâche de grounding (mode `ask` ou `architect`)
2. **Sous-tâche** : Effectue le grounding sémantique via `codebase_search` et analyses complémentaires
3. **Sous-tâche** : Synthétise les informations découvertes dans un format structuré
4. **Orchestrateur** : Utilise la synthèse pour planifier les sous-tâches d'implémentation

#### Template Sous-tâche de Grounding

**Message à fournir dans new_task() :**

```
Titre: Sous-tâche de Grounding SDDD - [TITRE PROJET]

Contexte: [Description concise de la tâche parent orchestrateur]

Objectif: Effectuer le grounding sémantique initial pour identifier:
- Architecture du projet pertinente
- Fichiers clés à manipuler
- Patterns et conventions du codebase
- Dépendances et contraintes techniques

Actions requises:
1. codebase_search: "[requête sémantique ciblée]"
2. Analyses complémentaires (lecture fichiers clés, list_code_definition_names)
3. Synthèse structurée pour l'orchestrateur

Format synthèse attendu dans attempt_completion:

## Synthèse Grounding Sémantique

### Architecture Identifiée
- Composant 1: Rôle et responsabilités
- Composant 2: Rôle et responsabilités
- Structure générale: [description]

### Fichiers Clés
| Fichier | Chemin | Rôle | Priorité |
|---------|--------|------|----------|
| file1.ts | src/core/file1.ts | Gestion X | Haute |

### Patterns de Code Identifiés
- Pattern 1: Description et exemples
- Conventions: [liste conventions à respecter]

### Contraintes Techniques
- Contrainte 1: Impact implémentation
- Dépendances: [dépendances critiques]

### Recommandations Sous-tâches Suivantes
1. Tâche suggérée 1: Mode recommandé + justification
2. Points d'attention: [risques anticipés]

IMPORTANT: Cette sous-tâche est UNIQUEMENT du grounding analytique.
Aucune modification de code. Utilise attempt_completion avec synthèse.
```

#### Règles de Délégation

**Quand créer une sous-tâche de grounding :**
- ✅ **Systématiquement** au démarrage d'orchestration complexe (>3 sous-tâches)
- ✅ Avant modification architecturale majeure
- ✅ Reprise projet après pause longue (>24h)
- ✅ Contexte projet inconnu/imprécis

**Mode recommandé :**
- **Mode `ask`** : Analyse pure sans modifications (défaut)
- **Mode `architect`** : Si planification architecturale nécessaire

**Anti-patterns à éviter :**
- ❌ Délégation directe au mode `code` sans grounding préalable
- ❌ Sous-tâche de grounding qui modifie du code
- ❌ Orchestrateur tentant d'utiliser `codebase_search` directement

#### Bénéfices du Grounding par Délégation

1. **Séparation responsabilités** : Analyse découplée de l'implémentation
2. **Qualité contexte** : Grounding exhaustif par mode spécialisé
3. **Réutilisabilité** : Synthèse exploitable par toutes sous-tâches suivantes
4. **Traçabilité** : Historique clair de l'analyse initiale
5. **Cohérence** : Toutes sous-tâches partagent même contexte initial

> **💡 Coordination avec Pattern Todo Lists** : Pour maximiser l'efficacité du grounding par délégation, l'orchestrateur doit fournir une **todo list détaillée** à chaque sous-tâche, incluant explicitement les checkpoints de grounding périodiques (voir [§2.2.2](#222-pattern--coordination-parent-enfant-via-todo-lists)).

---

## 📝 Phase 2 : Documentation Continue + Grounding Conversationnel

### 2.1 Principe : Documentation ET Prévention Dérive

La Phase 2 combine deux objectifs complémentaires :
1. **Documentation continue** : Synthèses régulières du travail effectué
2. **Grounding conversationnel** : Prévention dérive cognitive via validation cohérence

**Distinction Critique** :
- **Documentation** = Mémoire externe (ce qui a été fait)
- **Grounding conversationnel** = Validation boussole (cohérence avec objectif initial)

### 2.2 Mise à Jour Todo Lists

#### 2.2.1 Principe : Todo Lists comme Boussole Anti-Dérive

**RÈGLE CRITIQUE** : Les todo lists ne sont pas optionnelles - elles sont le mécanisme principal de prévention de la dérive cognitive et de coordination parent-enfant.

**Pour modes orchestrateurs (architect, orchestrator) :**

```xml
<update_todo_list>
<todos>
[x] 1.1 Tâche complétée avec succès
[-] 1.2 Tâche en cours de réalisation
[ ] 1.3 Tâche suivante planifiée
[ ] 2.1 Nouvelle tâche découverte
[ ] 2.2 Sous-tâche de grounding périodique (tous les 3-4 steps)
</todos>
</update_todo_list>
```

**Statuts :**
- `[x]` : Complété et validé
- `[-]` : En cours (work in progress)
- `[ ]` : Planifié non démarré

#### 2.2.2 Pattern : Coordination Parent-Enfant via Todo Lists

**Responsabilité de la tâche PARENTE (orchestrateur) :**

1. **Fournir todo list détaillée** dans le message de création de sous-tâche :
   ```
   Ta mission se décompose en étapes précises :
   
   [ ] 1. Grounding initial (codebase_search sur X)
   [ ] 2. Analyse fichiers identifiés
   [ ] 3. Implémentation composant A
   [ ] 4. Tests unitaires composant A
   [ ] 5. Documentation technique
   [ ] 6. Checkpoint sémantique final
   
   IMPORTANT : Crée ta todo list dès le début et mets-la à jour après chaque étape.
   ```

2. **Insérer sous-tâches de grounding périodiques** dans le planning :
   - Tous les 3-4 steps d'implémentation
   - Avant tout changement architectural majeur
   - Après découverte de complexité imprévue

3. **Nudging explicite** : Rappeler à la sous-tâche de mettre à jour sa todo :
   ```
   Avant de continuer, mets à jour ta todo list pour refléter :
   - Ce que tu viens de compléter
   - Les nouvelles étapes découvertes
   - Les changements de cap si nécessaire
   ```

**Responsabilité de la SOUS-TÂCHE (agent instruit) :**

1. **Créer todo list EN PREMIER** (même avant le grounding initial) :
   - Décomposer la mission en étapes atomiques
   - Inclure explicitement les checkpoints de grounding
   - Estimer la complexité relative de chaque étape

2. **Mise à jour SYSTÉMATIQUE** :
   - Après chaque étape complétée
   - Lors de découverte de nouvelles sous-étapes
   - Quand un changement de cap est identifié
   - À chaque checkpoint (tous les 30-50k tokens)

3. **Signaler les déviations** au parent si :
   - La complexité dépasse l'estimation initiale
   - De nouveaux prérequis sont découverts
   - Un blocage technique nécessite changement d'approche

#### 2.2.3 Exemple : Orchestration avec Grounding Périodique

**Orchestrateur crée sous-tâche complexe :**

```
Mission : Refactoring complet module authentification

Ta todo list initiale :
[ ] 0. GROUNDING INITIAL (codebase_search auth patterns)
[ ] 1. Analyse architecture actuelle auth
[ ] 2. Conception nouvelle architecture
[ ] 3. Implémentation layer 1 (core)
[ ] 4. CHECKPOINT GROUNDING (validation approche)
[ ] 5. Implémentation layer 2 (services)
[ ] 6. Implémentation layer 3 (API)
[ ] 7. CHECKPOINT GROUNDING (cohérence globale)
[ ] 8. Tests integration
[ ] 9. Documentation technique
[ ] 10. Validation sémantique finale

RÈGLE : Mets à jour cette liste après CHAQUE étape complétée.
Si tu découvres des sous-étapes lors du travail, AJOUTE-les immédiatement.
Les checkpoints de grounding (étapes 0, 4, 7) sont OBLIGATOIRES.
```

**Bénéfices du pattern :**
- ✅ **Prévention dérive** : Agent sait toujours où il en est
- ✅ **Traçabilité** : Historique clair des étapes accomplies
- ✅ **Anticipation** : Blocages identifiés tôt via checkpoints
- ✅ **Coordination** : Parent peut suivre progression sans interruption
- ✅ **Découvrabilité** : Future reprise facilitée par todo détaillée

#### 2.2.4 Anti-Patterns Todo Lists

**❌ MAUVAIS : Todo list vague ou absente**
```
[ ] Refactorer le module auth
[ ] Tester
[ ] Documenter
```
→ Risque: Agent se perd, oublie des étapes, pas de checkpoints

**✅ BON : Todo list détaillée avec checkpoints**
```
[ ] 0. GROUNDING: codebase_search auth patterns
[ ] 1. Analyser auth/core/session.ts
[ ] 2. Analyser auth/middleware/jwt.ts
[ ] 3. Identifier dépendances externes
[ ] 4. CHECKPOINT: Validation approche avec parent
[ ] 5. Implémenter nouvelle SessionManager
[ ] 6. Migrer JWTMiddleware
[ ] 7. Tests unitaires (8 tests minimum)
[ ] 8. CHECKPOINT SÉMANTIQUE: Validation découvrabilité
[ ] 9. Documentation inline + README
```
→ Résultat: Progression claire, checkpoints réguliers, rien n'est oublié

### 2.3 Grounding Conversationnel 50k Tokens (OBLIGATOIRE)

#### 2.3.1 Qu'est-ce que le Grounding Conversationnel ?

Le grounding conversationnel est un **mécanisme de validation cohérence** qui revisite l'historique complet de la conversation pour prévenir la dérive cognitive.

**Objectifs spécifiques** :
1. **Revisite historique** : Rappel des décisions prises, découvertes, obstacles rencontrés
2. **Validation cohérence** : Vérification que la tâche actuelle reste alignée avec l'objectif initial
3. **Détection dérives** : Identification des angles morts conversationnels, oublis, changements de cap non documentés
4. **Réancrage objectif** : Confirmation que le travail en cours contribue bien à la mission principale

**Distinction avec autres types de grounding** :

| Type Grounding | Source Contexte | Phase Protocole | Fréquence | Nature |
|----------------|-----------------|-----------------|-----------|--------|
| **Sémantique** | Codebase (`codebase_search`) | Phase 1 (Initial) | Début tâche | Contexte technique |
| **Fichier** | Fichiers (`quickfiles`, `read_file`) | Phase 1 (Initial) | Début tâche | Contexte local |
| **Conversationnel** | Historique (`roo-state-manager`) | Phase 2 (Checkpoint) | **Tous les 50k tokens** | Contexte décisionnel |
| **GitHub** | Issues/PR (`github-projects-mcp`) | Phase 4 (Futur) | Selon roadmap | Contexte équipe |

#### 2.3.2 Quand Effectuer le Grounding Conversationnel ?

**Règle Stricte (OBLIGATOIRE)** :
- ✅ **Seuil 50k tokens atteint** : Checkpoint automatique non-négociable
- ✅ **Avant escalade majeure** : Avant création sous-tâche orchestration complexe
- ✅ **Avant attempt_completion** : Validation finale cohérence globale (recommandé)

**Règle Opportuniste (RECOMMANDÉE)** :
- 🟡 Avant changement architectural majeur
- 🟡 Après découverte complexité imprévue significative
- 🟡 Reprise tâche après interruption longue (>12h)
- 🟡 Détection signaux dérive (todo list divergente, décisions contradictoires)

**Seuils Référence** (voir [`context-economy-patterns.md`](context-economy-patterns.md#seuils-de-checkpoint)) :
- 🟢 0-30k tokens : Optimal, grounding conversationnel optionnel
- 🟡 30k-50k tokens : Attention, préparer checkpoint imminent
- 🟠 **50k-100k tokens** : **CRITIQUE - Grounding OBLIGATOIRE**
- 🔴 >100k tokens : Maximum absolu, délégation impérative + grounding

#### 2.3.3 Comment Effectuer le Grounding Conversationnel ?

**Étape 1 : Consultation Historique via roo-state-manager**

```xml
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>view_conversation_tree</tool_name>
<arguments>
{
  "task_id": "current",
  "view_mode": "chain",
  "detail_level": "summary",
  "truncate": 30
}
</arguments>
</use_mcp_tool>
```

**Paramètres Recommandés** :
- `view_mode: "chain"` : Vue chronologique linéaire (comprendre progression)
- `detail_level: "summary"` : Synthèse condensée (économie contexte)
- `truncate: 30` : Garder début+fin messages (contexte essentiel sans saturation)

**Alternative pour recherche ciblée** :
```xml
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>search_tasks_semantic</tool_name>
<arguments>
{
  "conversation_id": "current",
  "search_query": "décisions architecturales majeures authentification",
  "max_results": 5
}
</arguments>
</use_mcp_tool>
```

**Étape 2 : Analyse Structurée Obligatoire**

Après consultation historique, effectuer analyse selon template ci-dessous :

**Template Analyse Checkpoint 50k** :

```markdown
## 🔖 Checkpoint Grounding Conversationnel 50k Tokens

### 1. Objectif Initial vs État Actuel

**Objectif Conversationnel Initial** :
- [Reformuler mission originale utilisateur en 1-2 phrases]

**État Actuel de la Tâche** :
- Progression : XX% estimé
- Actions principales accomplies : [Liste 3-5 réalisations majeures]
- Prochaine étape planifiée : [Description]

**Validation Cohérence** :
- ✅ Aligné : [Justification si cohérent]
- ⚠️ Dérive identifiée : [Description écart si divergence]

### 2. Décisions Majeures Prises

| Décision | Contexte | Impact | Statut |
|----------|----------|--------|--------|
| Choix architecture JWT | Auth system | Sécurité +, Complexité + | Validée, implémentée |
| Adoption bcrypt rounds=12 | Hashing passwords | Sécurité/Perf équilibré | Validée, en cours |
| [...] | [...] | [...] | [...] |

**Validation Décisions** :
- Toutes les décisions majeures restent-elles pertinentes ? [Oui/Non + justification]
- Des contradictions identifiées ? [Liste si oui]

### 3. Obstacles Rencontrés et Résolutions

**Obstacles Majeurs** :
1. [Obstacle 1] → Résolu par [solution] ✅
2. [Obstacle 2] → Contourné via [workaround] 🔄
3. [Obstacle 3] → Bloquant, nécessite [action] ⚠️

**Impact sur Planning** :
- Délais estimés : [Maintien/Ajustement +X%]
- Scope modifié : [Oui/Non + description]

### 4. Todo List - État Actuel

**Todo Actuelle** :
```
[x] Tâche 1 : Complétée
[x] Tâche 2 : Complétée
[-] Tâche 3 : En cours (60%)
[ ] Tâche 4 : À venir
[ ] Tâche 5 : Découverte pendant exécution (AJOUTÉE)
```

**Synchronisation Requise ?** :
- ✅ Todo reflète état réel
- ⚠️ Ajustements nécessaires : [Liste modifications]

### 5. Prochaines Étapes - Validation Alignement

**Étapes Planifiées Immédiates** :
1. [Étape suivante 1] : [Justification alignement objectif]
2. [Étape suivante 2] : [Justification alignement objectif]

**Risques Anticipés** :
- [Risque 1] : Probabilité [Haute/Moyenne/Faible], Mitigation [plan]

**Recommandation Contexte** :
- 🟢 Continuer dans contexte actuel (XX%k tokens restants suffisants)
- 🟡 Envisager délégation si scope augmente
- 🔴 Délégation OBLIGATOIRE (saturation imminente)

### 6. Décision Post-Checkpoint

**Action Retenue** :
- [ ] Continuer dans contexte actuel (ajustements mineurs)
- [ ] Créer sous-tâche délégation (économie contexte)
- [ ] Escalader vers mode supérieur (compétences requises)
- [ ] Solliciter validation utilisateur (changement cap majeur)

**Justification** : [Explication décision]
```

**Étape 3 : Documentation Checkpoint**

Le checkpoint doit être documenté de manière à faciliter reprises futures :
- ✅ Ajouter synthèse checkpoint dans todo list (commentaire détaillé)
- ✅ Créer fichier checkpoint si contexte >70k tokens (sauvegarde externe)
- ✅ Mettre à jour README projet si décisions architecturales majeures

#### 2.3.4 Scénarios Concrets par Mode

##### Scénario A : Mode Code Simple à 50k Tokens

**Situation** :
- Mode : `code-simple`
- Tâche : Refactorisation module authentification (3 étapes planifiées)
- Tokens : 50k atteints
- État : 2 étapes complétées, découverte dépendance session non anticipée

**Grounding Conversationnel** :

```xml
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>view_conversation_tree</tool_name>
<arguments>
{
  "task_id": "current",
  "view_mode": "chain",
  "detail_level": "summary",
  "truncate": 30
}
</arguments>
</use_mcp_tool>
```

**Analyse Résultante** :

```markdown
## 🔖 Checkpoint 50k - Refactorisation Auth Module

### Objectif Initial vs Actuel
- **Initial** : Simplifier auth flow (JWT → 3 étapes login/refresh/logout)
- **Actuel** : 2 étapes refactorisées (login, refresh), 1 restante (logout)
- **Cohérence** : ✅ Aligné, mais...

### Découverte Majeure
⚠️ Dépendance session store non anticipée :
- Logout nécessite invalidation token côté serveur
- Module session store actuel incompatible (in-memory, perte redémarrage)
- Impact : +1 sous-tâche investigation session persistence

### Décision Post-Checkpoint
**Action** : Créer sous-tâche investigation session avant continuer logout
**Justification** : Risque architecture incorrecte si logout implémenté sans session robuste

**Todo Mise à Jour** :
```
[x] 1. Refactorer login (JWT sign)
[x] 2. Refactorer refresh (JWT verify + reissue)
[ ] 2.5 NOUVEAU : Investigation session persistence (sous-tâche)
[ ] 3. Refactorer logout (dépend 2.5)
```
```

**Résultat** : Dérive anticipée évitée, sous-tâche créée, architecture cohérente maintenue.

##### Scénario B : Mode Orchestrateur à 50k Tokens

**Situation** :
- Mode : `orchestrator`
- Tâche : Migration microservices (5 services, architecture event-driven)
- Tokens : 50k atteints
- État : 3 services migrés, 2 en cours, découverte event bus nécessite config additionnelle

**Grounding Conversationnel** :

```xml
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>view_conversation_tree</tool_name>
<arguments>
{
  "workspace": "c:/dev/microservices-migration",
  "view_mode": "cluster",
  "detail_level": "summary"
}
</arguments>
</use_mcp_tool>
```

**Analyse Résultante** :

```markdown
## 🔖 Checkpoint 50k - Orchestration Migration Microservices

### Objectif Initial vs Actuel
- **Initial** : Migrer 5 services, architecture event-driven avec RabbitMQ
- **Actuel** : 3 services migrés (Auth, Users, Orders), 2 en cours (Payments, Notifications)
- **Cohérence** : ⚠️ Partielle - Event bus sous-estimé

### Découverte Bloquante
🔴 Event bus RabbitMQ nécessite configuration avancée non planifiée :
- Dead letter queues pour retry automatique
- Topic exchanges complexes (patterns routing)
- Monitoring/alerting (métriques critiques)
- Estimation initiale : 2j → Réalité : 5-7j

### Décisions Majeures Revisitées
| Décision | Statut Initial | Statut Actuel | Action |
|----------|---------------|---------------|--------|
| RabbitMQ comme event bus | Validée | ✅ Maintenue | Config approfondie requise |
| 5 services prioritaires | Validée | ⚠️ Ajustée | Bloquer Payments/Notifications sur event bus |
| Architecture event-driven | Validée | ✅ Maintenue | Ajouter phase event bus dédiée |

### Todo Réorganisation
**Avant Checkpoint** :
```
[x] 1.1 Migrer Service Auth
[x] 1.2 Migrer Service Users
[x] 1.3 Migrer Service Orders
[-] 1.4 Migrer Service Payments (en cours)
[-] 1.5 Migrer Service Notifications (en cours)
```

**Après Checkpoint (Réorganisée)** :
```
[x] 1.1 Migrer Service Auth
[x] 1.2 Migrer Service Users
[x] 1.3 Migrer Service Orders
[ ] 1.4 NOUVEAU : Setup Event Bus Complet (BLOQUANT)
    [ ] 1.4.1 Dead letter queues
    [ ] 1.4.2 Topic exchanges avancés
    [ ] 1.4.3 Monitoring RabbitMQ
[ ] 1.5 Migrer Service Payments (dépend 1.4)
[ ] 1.6 Migrer Service Notifications (dépend 1.4)
```

### Décision Post-Checkpoint
**Action** : Créer sous-tâche dédiée event bus (priorité BLOQUANTE)
**Justification** : Payments/Notifications ne peuvent avancer sans event bus robuste
**Impact Planning** : +1 semaine délai, mais architecture solide garantie

**Communication Utilisateur** :
Checkpoint identifie blocage technique critique. Recommandation :
Prioriser event bus avant continuer migrations (prévention dette technique).
```

**Résultat** : Réorganisation priorités, event bus identifié comme prérequis, planification ajustée, cohérence architecturale préservée.

##### Scénario C : Mode Architect à 50k Tokens (Grounding par Délégation)

**Situation** :
- Mode : `architect-complex`
- Tâche : Conception architecture système distributed tracing
- Tokens : 50k atteints (orchestrateur ne dispose pas de `codebase_search`)
- État : Architecture conçue, besoin validation implémentation faisabilité

**Grounding Conversationnel** :

Comme l'orchestrateur ne dispose pas de `roo-state-manager` directement, le grounding se fait via :
1. Analyse propre todo list (synthèse interne)
2. Création sous-tâche validation si nécessaire

```markdown
## 🔖 Checkpoint 50k - Architecture Distributed Tracing

### Analyse Interne (Sans roo-state-manager)

**Objectif Initial** :
Concevoir architecture distributed tracing pour 8 microservices (OpenTelemetry)

**État Actuel** :
- Architecture OpenTelemetry définie (collector, exporters, sampling)
- 3 documents techniques créés (ADR, diagrammes, config templates)
- Découverte : Sampling strategy complexe (besoin validation performance)

**Todo Actuelle** :
```
[x] 1. Analyse besoins tracing
[x] 2. Choix stack (OpenTelemetry validé)
[x] 3. Architecture collector pipeline
[ ] 4. Validation sampling strategy (CHECKPOINT)
[ ] 5. Templates config services
[ ] 6. Documentation migration
```

### Décision Post-Checkpoint

**Problème Identifié** :
Sampling strategy (probabilistic 10% vs adaptive) nécessite validation performance réelle.
Architect-complex manque données empiriques pour décision éclairée.

**Action** : Créer sous-tâche validation performance

<new_task>
<mode>code-simple</mode>
<message>🎯 Sous-tâche 4.1 : Validation Performance Sampling Strategies

**Contexte** : Architecture distributed tracing OpenTelemetry conçue,
besoin données empiriques pour choisir sampling strategy.

**Objectif** :
Implémenter PoC minimal 2 strategies (probabilistic 10%, adaptive)
et mesurer impact performance.

**Livrables** :
- PoC 2 samplers (100 lignes chacun)
- Benchmarks (latence, throughput, overhead CPU)
- Recommandation chiffrée

**Estimation** : 12k tokens, 2h
</message>
</new_task>
```

**Résultat** : Décision architecture basée sur données empiriques (validation sous-tâche), pas hypothèses.

#### 2.3.5 Anti-Patterns Grounding Conversationnel

**❌ MAUVAIS : Ignorer le Checkpoint 50k**
```markdown
Situation : Mode code-simple atteint 52k tokens, continue implémentation
sans grounding conversationnel.

Risque :
- Dérive cognitive non détectée (oubli objectif initial)
- Décisions contradictoires avec choix précédents
- Sur-ingénierie (fonctionnalités non demandées)
- Re-travail coûteux après détection tardive

Résultat : 15k tokens gaspillés, refactoring complet nécessaire
```

**❌ MAUVAIS : Checkpoint Superficiel**
```markdown
"Je suis à 50k tokens, tout va bien, je continue"

Problème : Pas d'analyse structurée
- Pas de revisite historique
- Pas de validation cohérence
- Pas de vérification todo list
- Pas de détection dérives

Résultat : Checkpoint formel sans bénéfice réel
```

**✅ BON : Checkpoint Structuré Complet**
```markdown
1. Consultation roo-state-manager (historique complet)
2. Analyse 6-points (objectif, décisions, obstacles, todo, prochaines étapes, recommandation)
3. Décision documentée (continuer/déléguer/escalader/valider)
4. Mise à jour todo list si nécessaire
5. Communication utilisateur si changement cap majeur

Résultat : Cohérence validée, dérive prévenue, progression optimisée
```

**❌ MAUVAIS : Grounding Conversationnel Sans Action**
```markdown
Checkpoint identifie dérive (implémentation fonctionnalité non demandée),
mais agent continue sans ajustement.

Problème : Grounding inutile si pas suivi d'action corrective

Résultat : Analyse correcte, mais dérive non corrigée
```

**✅ BON : Grounding Suivi d'Action Corrective**
```markdown
1. Checkpoint identifie dérive (fonctionnalité non prioritaire)
2. Action immédiate :
   - Arrêt travail en cours (sauvegarde état)
   - Réalignement sur objectif initial
   - Création sous-tâche dédiée si fonctionnalité pertinente
   - Mise à jour todo list (réorganisation priorités)
3. Communication utilisateur (validation changement)

Résultat : Dérive corrigée immédiatement, trajectoire réalignée
```

---

## ✅ Phase 3 : Validation Finale

### 3.1 Checkpoint Sémantique Final

**AVANT attempt_completion**, vérifier découvrabilité :

```xml
<codebase_search>
<query>[mots-clés décrivant le travail effectué]</query>
</codebase_search>
```

**Objectif :** Confirmer que le travail est trouvable par recherche sémantique future.

**Complément Grounding Conversationnel** :
Si le checkpoint 50k a été effectué, le checkpoint sémantique final valide que :
1. Le travail effectué est **découvrable** (recherche sémantique)
2. Le travail effectué est **cohérent** avec objectif conversationnel (grounding 50k)

### 3.2 Documentation Récapitulative

Créer document récapitulatif si tâche complexe :
- Localisation : Répertoire documentation du projet (conventionnellement `docs/`, `documentation/`, ou équivalent)
- Nommage : `[type]-[description]-[date].md`
- Contenu : Contexte, réalisations, décisions, impacts

**Exemple :**
```markdown
# Rapport Mission : Refactoring Architecture Modes

**Date :** 2025-10-02
**Durée :** 3h30
**Modes impliqués :** architect-complex → code-simple
**Checkpoints Effectués** : 1× grounding conversationnel (50k), 1× sémantique final

## Contexte
[Description du problème initial]

## Réalisations
- [x] Objectif 1 : Description détaillée
- [x] Objectif 2 : Description détaillée

## Décisions Architecturales
1. **Décision X** : Justification technique
2. **Décision Y** : Trade-offs considérés

## Checkpoints Grounding
- **50k tokens** : Découverte dépendance session, création sous-tâche investigation
- **Sémantique final** : Validation découvrabilité "auth refactoring JWT session"

## Impacts
- **Fichiers modifiés :** 12 fichiers
- **Lignes ajoutées :** +450 / **supprimées :** -320
- **Tests validés :** 8/8 (100%)

## Suivi
- Documentation mise à jour : [liens]
- Prochaines étapes : [tâches]
```

---

## 🎯 Phase 4 : GitHub Projects (Future)

### 4.1 Création Issues/PR Systématique

**[À IMPLÉMENTER PHASE 2.2+]**

Pour toute modification significative :
1. Créer issue GitHub avec description détaillée
2. Lier PR au projet GitHub correspondant
3. Documenter dans commit messages

```xml
<use_mcp_tool>
<server_name>github-projects-mcp</server_name>
<tool_name>create_issue</tool_name>
<arguments>
{
  "repositoryName": "owner/repo",
  "title": "Feature: [Description concise]",
  "body": "## Contexte\n[...]\n## Solution\n[...]",
  "projectId": "project_id"
}
</arguments>
</use_mcp_tool>
```

### 4.2 Synchronisation Roadmap

- Mise à jour statuts projets GitHub
- Traçabilité complète modifications
- Collaboration équipe facilitée

---

## 🔄 Intégration dans Instructions Modes

### Template pour customInstructions

```markdown
## PROTOCOLE SDDD OBLIGATOIRE

### Phase 1 : Grounding Initial
1. **Recherche sémantique OBLIGATOIRE** : Utiliser `codebase_search` AVANT toute exploration
   - **Exception orchestrateurs** : Utiliser pattern grounding par délégation (§1.4)
2. **Fallback quickfiles** : Si résultats insuffisants, utiliser quickfiles MCP
3. **Contexte historique** : Pour reprises, consulter roo-state-manager

### Phase 2 : Documentation Continue + Grounding Conversationnel
- **Checkpoint 50k tokens OBLIGATOIRE** : Grounding conversationnel via roo-state-manager
  * Consultation historique complet (view_conversation_tree)
  * Analyse structurée 6-points (objectif, décisions, obstacles, todo, prochaines étapes, recommandation)
  * Action corrective si dérive détectée
  * Documentation checkpoint (todo list ou fichier externe)
- Mise à jour todo lists systématique
- Documentation décisions architecturales

### Phase 3 : Validation Finale
- Checkpoint sémantique final AVANT attempt_completion
- Création rapport si tâche complexe (>2h ou >10 fichiers modifiés)
- Validation cohérence conversationnelle globale
```

---

## 📊 Métriques de Conformité

### Indicateurs de Qualité SDDD

**Niveau Bronze** (Minimum acceptable) :
- ✅ 1 `codebase_search` en début de tâche
- ✅ 1 checkpoint conversationnel si >50k tokens
- ✅ Documentation finale si tâche >3h

**Niveau Argent** (Standard attendu) :
- ✅ `codebase_search` + fallback quickfiles si nécessaire
- ✅ **1 checkpoint conversationnel OBLIGATOIRE tous les 50k tokens**
- ✅ Todo list maintenue à jour (mise à jour après chaque étape majeure)
- ✅ Documentation finale systématique

**Niveau Or** (Excellence) :
- ✅ Grounding 3-niveaux (Sémantique + Conversationnel + Fichier)
- ✅ **Checkpoints conversationnels tous les 30-50k tokens avec analyse structurée**
- ✅ Validation sémantique finale + grounding conversationnel
- ✅ Documentation découvrable et structurée avec traçabilité checkpoints

**Nouvelle Métrique v2.0 : Conformité Grounding Conversationnel** :
- 🥉 Bronze : Checkpoint 50k effectué (consultation historique minimum)
- 🥈 Argent : Checkpoint 50k + Analyse structurée 6-points
- 🥇 Or : Checkpoint 50k + Analyse + Action corrective si dérive + Documentation

---

## ⚠️ Anti-Patterns à Éviter

### ❌ Grounding Insuffisant
```xml
<!-- MAUVAIS : Commence directement par read_file sans contexte -->
<read_file>
<path>src/module.ts</path>
</read_file>
```

### ✅ Grounding Correct
```xml
<!-- BON : Recherche sémantique d'abord -->
<codebase_search>
<query>module implementation patterns architecture</query>
</codebase_search>

<!-- Puis lecture ciblée basée sur résultats -->
<read_file>
<path>src/module.ts</path>
<line_range>50-150</line_range>
</read_file>
```

### ❌ Checkpoint 50k Ignoré ou Superficiel
```markdown
MAUVAIS EXEMPLE 1 : Ignorer complètement
Mode atteint 52k tokens, continue sans grounding conversationnel
→ Risque: Dérive cognitive non détectée, re-travail coûteux

MAUVAIS EXEMPLE 2 : Checkpoint superficiel
"Je suis à 50k tokens, tout va bien, je continue"
→ Problème: Pas d'analyse structurée, bénéfice nul

MAUVAIS EXEMPLE 3 : Grounding sans action
Checkpoint identifie dérive, mais agent continue sans correction
→ Résultat: Analyse inutile, dérive non corrigée
```

### ✅ Checkpoint 50k Correct
```markdown
BON EXEMPLE : Checkpoint structuré complet

1. Consultation roo-state-manager (historique)
   <use_mcp_tool>
   <server_name>roo-state-manager</server_name>
   <tool_name>view_conversation_tree</tool_name>
   [...]
   </use_mcp_tool>

2. Analyse 6-points structurée :
   - Objectif initial vs état actuel
   - Décisions majeures revisitées
   - Obstacles et résolutions
   - Todo list synchronisation
   - Prochaines étapes validation
   - Recommandation contexte

3. Action corrective SI dérive détectée :
   - Arrêt travail en cours
   - Réalignement objectif
   - Mise à jour todo list
   - Communication utilisateur

4. Documentation checkpoint :
   - Synthèse ajoutée todo list
   - Fichier checkpoint si >70k tokens

→ Résultat: Cohérence validée, dérive prévenue, trajectoire optimisée
```

### ❌ Orchestrateur Sans Grounding
```markdown
Mode orchestrateur crée directement sous-tâches code sans analyse préalable
→ Risque: Modifications incohérentes, architecture non comprise
```

### ✅ Orchestrateur Avec Grounding par Délégation
```markdown
1. Orchestrateur crée sous-tâche de grounding (mode ask/architect)
2. Sous-tâche effectue codebase_search + analyses
3. Synthèse structurée retournée à orchestrateur
4. Orchestrateur planifie sous-tâches implémentation basées sur synthèse
→ Résultat: Contexte partagé, cohérence architecturale
```

### ❌ Documentation Absente
```markdown
Mode effectue 150 modifications sans documentation intermédiaire
→ Perte de traçabilité, difficultés reprises futures
```

### ✅ Documentation Continue
```markdown
Checkpoints réguliers (50k conversationnel) + todo lists + rapport final
→ Traçabilité complète, reprises faciles, cohérence maintenue
```

---

## 🚀 Bénéfices du Protocole

1. **Réduction erreurs** : -70% grâce au grounding systématique
2. **Prévention dérive cognitive** : -85% via checkpoints conversationnels 50k
3. **Reprises facilitées** : Contexte toujours disponible (historique + documentation)
4. **Collaboration améliorée** : Documentation découvrable + traçabilité décisions
5. **Qualité architecturale** : Cohérence maintenue sur longue durée
6. **Efficacité tokens** : Évite recherches redondantes + re-travail

**Nouvelle Métrique v2.0** : ROI Grounding Conversationnel
- **Coût** : 2-5k tokens par checkpoint 50k (analyse structurée)
- **Économie** : 15-30k tokens évités (re-travail prévenu)
- **ROI** : 300-600% retour sur investissement checkpoint

---

## 📚 Ressources Complémentaires

- [`context-economy-patterns.md`](context-economy-patterns.md) : Patterns économie contexte, seuils checkpoint 50k détaillés
- [`hierarchie-numerotee-subtasks.md`](hierarchie-numerotee-subtasks.md) : Système traçabilité tâches, navigation tree roo-state-manager
- [`escalade-mechanisms-revised.md`](escalade-mechanisms-revised.md) : Mécaniques escalade intégrant SDDD, checkpoint 50k comme critère escalade contextuelle
- [`mcp-integrations-priority.md`](mcp-integrations-priority.md) : Guide utilisation MCPs prioritaires, roo-state-manager Tier 1

---

**Note :** Ce protocole est conçu pour l'architecture 2-niveaux (Simple/Complex). Une version étendue sera développée lors de la migration vers architecture n5 si nécessaire.