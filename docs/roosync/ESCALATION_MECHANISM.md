# Mécanisme d'Escalade Roo - Documentation Complète

**Date:** 2026-02-13
**Version:** 1.1 (ajout Couche 3 - Claude CLI Escalade, #464 Phase 2.5)
**Statut:** Documentation de référence pour #462 et #464

---

## Vue d'ensemble

Le système Roo dispose d'un mécanisme d'escalade **automatique** et **intelligent** permettant de déléguer les tâches au niveau de complexité approprié. Ce mécanisme permet d'optimiser les coûts LLM (modes `-simple` = économiques, modes `-complex` = puissants) tout en garantissant la qualité d'exécution.

**Principe :** Commencer simple, escalader si nécessaire.

---

## Trois Types d'Escalade Distincts

**Feedback utilisateur (2026-02-12) :** Il existe trois mécanismes d'escalade distincts, chacun avec ses propres cas d'usage et priorités.

| Type | Nom | Mécanisme | Contexte | Priorité | Cas d'usage |
|------|-----|-----------|----------|----------|-------------|
| **1** | **Descendante (Entrante)** | Délégation à sous-tâches | Contexte **rafraîchi** | **PRIORITAIRE** | Parallélisation, décomposition |
| **2** | **Sur Place** | Switch modèle en cours | Contexte **préservé** | Secondaire | Complexité émergente |
| **3** | **Sortante** | Réassignation complète | Constat **échec** | Dernier recours | Mauvais dimensionnement initial |

### 1. Escalade Descendante (Entrante) - PRIORITAIRE

**Principe :** "Je délègue à une ou plusieurs sous-tâches avec un modèle plus gros que le mien"

**Caractéristiques :**
- Agent Haiku orchestrateur → lance sous-tâche Sonnet
- Chaque sous-tâche démarre avec un **contexte frais** (pas de bagage du parent)
- **Parallélisation possible** → augmente la performance globale
- **À prioriser** car rafraîchit les contextes et évite l'accumulation

**Implémentation Roo :** Via `new_task` avec mode cible (ex: `code-complex`, `debug-complex`)

**Implémentation Claude Code :** Via `claude -p "prompt" --model sonnet` (délégation externe)

**Avantages :**
- ✅ Contexte rafraîchi pour chaque sous-tâche
- ✅ Parallélisation native (plusieurs sous-tâches simultanées)
- ✅ Pas d'accumulation de contexte dans la boucle principale
- ✅ Permet de décomposer une tâche complexe en tâches simples

**Exemple Roo :**
```json
{
  "tool": "new_task",
  "mode": "code-complex",
  "instructions": "Refactorer le module auth.ts : isoler la logique OAuth, ajouter tests unitaires, documenter API"
}
```

### 2. Escalade Sur Place

**Principe :** "Je switch de modèle en cours de conversation pour continuer avec le contexte complet déjà accumulé"

**Caractéristiques :**
- Haiku iteration 1 → analyse et identifie besoin de Sonnet
- **Switch vers Sonnet** sans relancer depuis zéro
- Préserve tout le contexte accumulé (messages, tool calls, résultats)
- Utile quand la complexité émerge **en cours d'exécution**

**Implémentation Roo :** ⚠️ Non explicite dans la configuration actuelle (mécanisme à vérifier)

**Implémentation Claude Code :**
- **🔍 À VÉRIFIER :** Les slash commands pourraient être invocables par l'agent ([Reddit](https://www.reddit.com/r/ClaudeAI/comments/1noyvmq/claude_code_can_invoke_your_custom_slash_commands/))
- Si supporté : L'agent pourrait invoquer `/model sonnet` pour switcher en place
- **Solution workaround actuelle :** Relancer avec nouveau modèle + contexte précédent dans le prompt (simulation)

**Avantages :**
- ✅ Préserve le contexte complet déjà accumulé
- ✅ Évite de recommencer l'investigation depuis zéro

**Inconvénients :**
- ❌ Accumulation de contexte (peut mener à overflow)
- ❌ Pas de parallélisation possible
- ❌ Limitation technique (Claude Code ne supporte pas nativement)

**Exemple Claude Code (simulation) :**
```powershell
# Iteration 1 avec Haiku
$Output1 = & claude -p $Prompt --model haiku

# Agent signale : "ESCALATE_TO_SONNET"
if ($Output1 -match "ESCALATE_TO_SONNET") {
    # Iteration 2 : Relancer avec Sonnet + contexte iteration 1
    $EnrichedPrompt = @"
Contexte précédent (Haiku) :
$Output1

Continue cette tâche avec un modèle plus puissant.
"@
    $Output2 = & claude -p $EnrichedPrompt --model sonnet
}
```

### 3. Escalade Sortante - DERNIER RECOURS

**Principe :** "Je termine ma tâche en signalant besoin de réassignation à un modèle plus gros"

**Caractéristiques :**
- Constat d'un problème : **mauvais dimensionnement initial**, manque de contexte, débordement de scope
- Agent retourne un flag `needsEscalation: true`
- La **boucle principale** relance TOUTE la tâche avec un modèle plus gros
- Nécessite décision avec **plus de recul** que la boucle courante

**Implémentation Roo :** Via `escalationCriteria` dans `modes-config.json`

**Implémentation Claude Code :** Via flag `needsEscalation` dans le retour de `Invoke-Claude`

**Avantages :**
- ✅ Permet de corriger un mauvais dimensionnement initial
- ✅ Agent signale explicitement son besoin

**Inconvénients :**
- ❌ Perte du contexte de la tentative initiale (recommence depuis zéro)
- ❌ Temps perdu sur la première tentative
- ❌ Coût additionnel (première tentative + relance)

**Exemple Roo (escalationCriteria) :**
```json
{
  "escalationCriteria": [
    "La tâche nécessite des décisions architecturales",
    "Le problème est plus complexe que prévu après investigation",
    "Les modifications touchent plus de 3 fichiers interconnectés",
    "Les erreurs persistent après 2 tentatives de correction"
  ]
}
```

**Exemple Claude Code (flag) :**
```powershell
# Agent termine avec flag
return @{
    success = $false
    needsEscalation = $true
    reason = "Modifications touchent 5 fichiers interconnectés, nécessite vision architecturale"
}
```

### Prioritisation Recommandée

**Ordre de priorité (feedback utilisateur 2026-02-12) :**

1. **Escalade descendante (entrante)** - TOUJOURS PRIORISER
   - Rafraîchit contextes
   - Permet parallélisation
   - Plus performant globalement

2. **Escalade sur place** - SI IMPOSSIBLE DE DÉLÉGUER
   - Utile si complexité émerge en cours d'exécution
   - Préserve contexte accumulé
   - Mais risque d'accumulation

3. **Escalade sortante** - DERNIER RECOURS UNIQUEMENT
   - Constat d'un mauvais dimensionnement
   - Nécessite décision avec plus de recul
   - Temps et coût perdus sur la première tentative

**Citation utilisateur :**
> "L'escalade descendante est à prioriser quand elle est possible car elle rafraîchit les contextes, se prête bien à la parallélisation qui est aussi une façon d'augmenter le niveau de performances."

---

## Architecture des Modes Roo

### 5 Familles de Modes × 2 Niveaux = 10 Modes

| Famille | Simple | Complex | Usage |
|---------|--------|---------|-------|
| **💻 Code** | `code-simple` | `code-complex` | Modifications code, features, refactoring |
| **🪲 Debug** | `debug-simple` | `debug-complex` | Diagnostic bugs, corrections |
| **🏗️ Architect** | `architect-simple` | `architect-complex` | Conception, documentation technique |
| **❓ Ask** | `ask-simple` | `ask-complex` | Questions, analyse, lecture code |
| **🎯 Orchestrator** | `orchestrator-simple` | `orchestrator-complex` | Coordination workflows, délégation |

### Caractéristiques par Niveau

| Aspect | Simple | Complex |
|--------|--------|---------|
| **Modèle LLM** | Économique (petit modèle) | Puissant (grand modèle) |
| **Coût** | Faible | Élevé |
| **Capacités** | Tâches bien définies, isolées | Architecture, multi-composants, analyse |
| **Groupes d'outils** | Variable selon famille | Variable selon famille |
| **Délégation** | Escalade vers `-complex` | Désescalade vers `-simple` |

---

## Couches d'Escalade

### Couche 1 : Scheduler Workflow (Orchestrateur)

**Fichier :** `.roo/scheduler-workflow-executor.md`

**Rôle :** Le scheduler Roo (orchestrator-simple) évalue la complexité des tâches dans l'INTERCOM et décide du routing initial.

**Critères d'escalade vers `orchestrator-complex` :**

1. **Plus de 5 sous-tâches** à coordonner
2. **Dépendances entre sous-tâches** (une dépend du résultat d'une autre)
3. **Parallélisation requise** (tâches indépendantes à lancer simultanément)
4. **Message `[URGENT]`** dans l'INTERCOM
5. **2 échecs consécutifs** sur des sous-tâches simples
6. **Modification de plus de 3 fichiers interconnectés**

**Workflow scheduler en 5 étapes :**

```
Étape 1 : Lire INTERCOM local → Identifier tâches [SCHEDULED], [TASK], [URGENT]
Étape 2 : Vérifier workspace (git status, git pull)
Étape 3 : Déléguer tâches (SIMPLE → -simple, MOYEN → -simple séquentiel, COMPLEXE → -complex)
Étape 4 : Rapporter dans INTERCOM LOCAL (via write_to_file, PAS roosync_send)
Étape 5 : Maintenance INTERCOM si >1000 lignes (compaction)
```

### Couche 2 : Modes Individuels (Workers)

**Fichier source :** `roo-config/modes/modes-config.json`

Chaque mode worker (code, debug, architect, ask) dispose de ses propres critères d'escalade.

#### Code Simple → Code Complex

**Escalade si :**
- Décisions architecturales nécessaires
- Problème plus complexe que prévu après investigation
- Modifications touchent **>3 fichiers interconnectés**
- Erreurs persistent après **2 tentatives**

**Désescalade (complex → simple) si :**
- Tâche plus simple que prévu
- Pattern standard applicable
- Modification localisée (1-2 fichiers)
- Code trivial (quelques lignes, pas de logique complexe)

#### Debug Simple → Debug Complex

**Escalade si :**
- Cause racine **non évidente** après première analyse
- Bug implique **interactions multi-composants**
- **Race conditions, memory leaks, performance** issues
- Problème persiste après **2 tentatives**

**Désescalade si :**
- Bug localisé dans **1 seul fichier**
- Cause racine évidente une fois identifiée
- Correction simple et localisée
- Message d'erreur clair pointe le problème

#### Architect Simple → Architect Complex

**Escalade si :**
- **Nouveau pattern architectural** requis
- Impact significatif **scalabilité/performance**
- **Migration ou refonte majeure** nécessaire
- **Plusieurs composants** à restructurer simultanément

**Désescalade si :**
- Pattern standard existant applicable
- Décision simple et **facilement réversible**
- **Peu de composants** concernés
- Documentation existante couvre déjà le sujet

#### Ask Simple → Ask Complex

**Escalade si :**
- Analyse **multi-domaine ou multi-fichiers** requise
- **Recherche externe** requise (web, docs hors codebase)
- **Comparaison détaillée** de solutions nécessaire
- Réponse nécessite **synthèse de sources multiples**

**Désescalade si :**
- Question simple et **localisée** (1 fichier)
- Documentation existante répond **directement**
- **Peu de sources** à consulter
- Réponse factuelle, **pas d'analyse** requise

#### Orchestrator Simple → Orchestrator Complex

**Escalade si :**
- **Dépendances complexes** entre sous-tâches
- **Parallélisation ou ordonnancement non-trivial** requis
- Coordination **multi-systèmes** nécessaire
- **Plus de 5 sous-tâches** à orchestrer

**Désescalade si :**
- Workflow **linéaire** sans dépendances complexes
- **Moins de 5 sous-tâches** séquentielles suffisent
- **Pas de parallélisation** ni coordination externe

### Couche 3 : Claude CLI Escalade (NOUVEAU - #464 Phase 2.5)

**Fichier source :** `roo-config/modes/modes-config.json` (champ `escalationInstruction` de la **dernière** entrée `levels[]` — ex-`complexEscalationInstructions`, relogé par #4115)

**Rôle :** Quand un mode `-complex` est toujours bloqué après 2 tentatives, il peut escalader à Claude CLI (`claude -p "..."`) qui utilise le modèle Anthropic (plus puissant que le modèle Roo).

**Architecture d'escalade complète :**

```
Niveau 1 : Roo mode -simple (modèle économique, ex: Haiku/petit)
   ↓ si échec ou complexe
Niveau 2 : Roo mode -complex (modèle puissant, ex: GLM 5/Sonnet)
   ↓ si 2 échecs ou très complexe (NOUVEAU)
Niveau 3 : Claude CLI (claude -p "..." --model sonnet/opus)
   ↓ si échec aussi
   → Documenter blocage, signaler dans INTERCOM [ESCALADE-CLAUDE]
```

**Critères d'escalade vers Claude CLI :**
- 2 échecs consécutifs en mode `-complex`
- Compréhension architecturale très profonde requise
- Bug impliquant interactions entre 5+ composants
- Analyse/synthèse dépassant la capacité du modèle courant

**Contraintes :**
- Maximum 2 escalades Claude CLI par session scheduler
- Préférer `--model sonnet` (économique) sauf cas critique
- Ne PAS boucler : si Claude CLI échoue aussi, arrêter et documenter
- Modes sans terminal (architect, ask) délèguent à code-simple pour exécuter la commande

**Prérequis :**
- `claude` CLI installé globalement (`npm install -g @anthropic-ai/claude-code`)
- Authentification Anthropic configurée (API key ou session)
- Forfait Anthropic disponible (coûteux - usage parcimonieux)

**Implémenté :** 2026-02-13 (commit TBD)
**Issue liée :** #464 Phase 2.5

### Couche 4 : Orchestrateurs (SDDD Instructions)

**Fichier source :** `roo-config/modes/modes-config.json` (section `additionalInstructions`)

Les orchestrateurs (simple et complex) disposent d'instructions spécifiques sur la **délégation via `new_task`** :

#### Principes SDDD

Quand un orchestrateur instruis une sous-tâche via `new_task`, il fournit un **prompt complet** suivant le pattern SDDD :

1. **Grounding initial** : Recherche sémantique pour contextualiser
   - Exemple : "Avant de commencer, cherche dans la doc les fichiers liés à X"

2. **Tâche spécifique** : Instructions claires et précises
   - Noms de fichiers exacts
   - Paramètres valides
   - Résultats attendus

3. **Validation doc** : Recherche sémantique pour vérifier cohérence
   - Exemple : "Vérifie que la doc reste cohérente avec tes changements"

4. **Résumé complet** : Demande un résumé de terminaison contenant :
   - Infos générales importantes
   - Résumé de la tâche accomplie
   - Anomalies ou observations notables

#### Règles de Délégation

- **Par défaut, déléguer en mode `-simple`**
- Utiliser `-complex` seulement si complexité clairement justifiée
- Vérifier état workspace (git status, fichiers récents) avant de planifier
- Ne jamais dupliquer une opération déjà faite
- Choisir le mode adapté : `code` pour modifier, `debug` pour diagnostiquer, `ask` pour lire/analyser, `architect` pour concevoir

#### Gestion des Échecs

1. **Analyser le résumé d'erreur** de la sous-tâche échouée
2. **Si erreur simple** (fichier introuvable, syntaxe, paramètre invalide) :
   → Relancer en `-simple` avec instructions corrigées
3. **Si erreur complexe** (logique, multi-fichiers, architecture) :
   → Escalader vers le mode `-complex` correspondant
4. **Après 2 échecs** sur la même sous-tâche :
   → Arrêter cette branche et documenter le blocage
5. **NE JAMAIS boucler** indéfiniment sur un échec

#### Routage Inter-Famille

Seuls les orchestrateurs font ce routage :

- **Bug découvert** pendant une tâche code → Déléguer à `debug-simple`
- **Redesign nécessaire** pendant un debug → Déléguer à `architect-simple`
- **Question d'analyse** pendant du code → Déléguer à `ask-simple`

Les workers restent dans leur famille.

---

## Flux d'Escalade Typique

### Scénario 1 : Tâche Simple (Happy Path)

```
Scheduler (orchestrator-simple)
  → Lit INTERCOM : "[TASK] Corriger typo dans README.md"
  → Évalue complexité : SIMPLE (1 action isolée)
  → Délègue à code-simple via new_task
     → code-simple lit README.md
     → code-simple corrige le typo
     → code-simple rapporte succès
  → Scheduler écrit rapport dans INTERCOM : [DONE]
```

**Coût :** Faible (2 modèles économiques)

### Scénario 2 : Escalade Automatique (Mode Worker)

```
Scheduler (orchestrator-simple)
  → Lit INTERCOM : "[TASK] Réparer bug authentification"
  → Évalue complexité : MOYEN (bug non-trivial)
  → Délègue à debug-simple via new_task
     → debug-simple analyse le code
     → debug-simple détecte : bug implique 3 composants (session, middleware, DB)
     → debug-simple évalue : ESCALADE REQUISE (critère #2 : multi-composants)
     → debug-simple délègue à debug-complex via new_task
        → debug-complex analyse les interactions
        → debug-complex identifie cause racine (race condition)
        → debug-complex propose fix
        → debug-complex rapporte succès avec détails
     → debug-simple rapporte : "Escaladé vers debug-complex, problème résolu"
  → Scheduler écrit rapport dans INTERCOM : [DONE]
```

**Coût :** Moyen (1 économique + 1 puissant)

### Scénario 3 : Escalade Scheduler (Orchestrateur)

```
Scheduler (orchestrator-simple)
  → Lit INTERCOM : "[TASK] Refactorer module auth (5 fichiers, dépendances complexes)"
  → Évalue complexité : COMPLEXE (>5 actions, dépendances)
  → Évalue critères escalade scheduler :
     - Plus de 5 sous-tâches ? OUI (analyse + design + refactoring + tests + doc)
     - Dépendances entre sous-tâches ? OUI (design doit précéder refactoring)
     - Modifications >3 fichiers ? OUI (5 fichiers)
  → ESCALADE VERS orchestrator-complex via new_task
     → orchestrator-complex planifie workflow :
        1. architect-complex : analyser architecture actuelle
        2. architect-complex : concevoir nouvelle architecture
        3. code-complex : implémenter refactoring (parallèle sur 5 fichiers)
        4. debug-complex : valider tests + intégration
        5. architect-simple : mettre à jour documentation
     → orchestrator-complex coordonne exécution séquentielle/parallèle
     → orchestrator-complex rapporte succès avec métriques
  → Scheduler écrit rapport dans INTERCOM : [DONE]
```

**Coût :** Élevé (1 économique + 1 puissant orchestrateur + 3-4 puissants workers)

---

## Métriques et Validation

### Métriques de Succès (Niveau 2 - Autonomie Roo Complex)

| Métrique | Cible | Mesure |
|----------|-------|--------|
| **Taux de succès tâches `-simple`** | >90% | Tâches complétées sans escalade / Total tâches -simple |
| **Taux de succès tâches `-complex`** | >80% | Tâches complétées avec succès / Total tâches -complex |
| **Taux d'escalade approprié** | 70-85% | Escalades justifiées / Total escalades |
| **Taux d'échecs répétés** | <5% | Tâches échouées 2+ fois / Total tâches |
| **Temps moyen tâche `-simple`** | <15 min | Durée moyenne exécution tâches simples |
| **Temps moyen tâche `-complex`** | <45 min | Durée moyenne exécution tâches complexes |
| **Rollback automatiques** | <10% | Tâches rollback / Total tâches |

### Garde-fous

1. **Limite de profondeur** : Max 3 niveaux d'escalade (scheduler → orchestrator-complex → worker-complex → sous-worker)
2. **Limite d'échecs** : Max 2 tentatives sur la même sous-tâche avant arrêt
3. **Timeout** : Max 1h par tâche schedulée (protection boucle infinie)
4. **Rollback automatique** : Si tests échouent après modification, rollback git automatique
5. **Human-in-the-loop** : Toute modification >5 fichiers nécessite validation Claude Code

---

## GLM 5 - Implications

**Contexte :** GLM 5 vient d'être déployé et est quasiment du niveau d'Opus (meilleur modèle Claude).

### Impact sur l'Escalade

| Aspect | Avant (modèles plus faibles) | Avec GLM 5 |
|--------|------------------------------|------------|
| **Tâches complex accessibles** | Limitées (modèle moins capable) | Étendues (investigation, fixes, refactoring) |
| **Taux de succès `-complex`** | 50-70% | 80-90% attendu |
| **Délégation par scheduler** | Principalement `-simple` | Peut solliciter `-complex` avec confiance |
| **Autonomie globale** | Niveau 1 (simple seulement) | **Niveau 2 prêt** (complex validé) |

### Nouveaux Cas d'Usage avec GLM 5

1. **Investigation bugs complexes** : Race conditions, memory leaks, performance
2. **Corrections code non-triviales** : Refactoring multi-fichiers, optimisation
3. **Analyse architecturale** : Évaluation trade-offs, migration strategies
4. **Synthèse cross-domaine** : Analyse de sources multiples, documentation

---

## Prochaines Étapes (Roadmap #462)

### Niveau 2 : Roo Complex (EN COURS - prochaine étape)

**Objectif :** Valider le mécanisme d'escalade avec GLM 5 sur des tâches `-complex`.

**Phase A : Tâches d'investigation** (MAINTENANT)
- Roo délégué pour investiguer bugs (mode `debug-complex`)
- Validation : Rapport uniquement, **pas de fix**
- Critère succès : Cause racine identifiée correctement

**Phase B : Corrections supervisées**
- Roo délégué pour corriger bugs identifiés (mode `code-complex`)
- Validation : **Claude review le diff avant commit**
- Worktree : Oui (isolation)

**Phase C : Corrections autonomes**
- Roo délégué pour corriger + commiter (mode `code-complex`)
- Validation : **Post-hoc** (Claude review au prochain sync)
- Worktree : Oui (PR automatique)

### Prérequis pour Passer au Niveau 2

- [x] Scheduler stable 1 semaine (✅ Déployé myia-ai-01, po-2025, web1)
- [ ] Worktrees fonctionnels (#461)
- [ ] Tests de validation Phase A (5+ scénarios)
- [ ] Métriques collectées sur 2+ semaines
- [ ] Documentation complète du mécanisme (ce fichier)

---

## Plan de Test (Phase A - Investigation)

### Scénario 1 : Bug Simple Multi-Fichiers

**Tâche :** "Investiguer pourquoi le module auth échoue lors du login via OAuth"

**Attendu :**
- Escalade automatique : debug-simple → debug-complex (multi-composants)
- Investigation 3 fichiers : auth.ts, oauth.ts, session.ts
- Rapport : Cause racine identifiée (token expiration non gérée)
- Pas de fix appliqué (Phase A)

**Critère succès :** Rapport complet avec cause racine correcte en <30 min

### Scénario 2 : Bug Performance

**Tâche :** "Investiguer pourquoi le dashboard est lent (>3s de chargement)"

**Attendu :**
- Escalade automatique : debug-simple → debug-complex (performance issue)
- Profiling identifié : N+1 queries dans ORM
- Rapport : Cause racine + recommandations d'optimisation
- Pas de fix appliqué (Phase A)

**Critère succès :** Cause racine identifiée + recommandations en <45 min

### Scénario 3 : Bug Race Condition

**Tâche :** "Investiguer les erreurs intermittentes de state dans le module sync"

**Attendu :**
- Escalade automatique : debug-simple → debug-complex (race condition)
- Investigation multi-threads/async
- Rapport : Race condition identifiée (accès concurrent sans lock)
- Pas de fix appliqué (Phase A)

**Critère succès :** Race condition identifiée avec reproduction en <60 min

### Scénario 4 : Refactoring Architecture

**Tâche :** "Investiguer comment refactorer le module storage pour supporter multi-workspaces"

**Attendu :**
- Escalade automatique : architect-simple → architect-complex (migration majeure)
- Analyse architecture actuelle + trade-offs
- Rapport : Stratégie de migration proposée avec étapes
- Pas d'implémentation (Phase A)

**Critère succès :** Stratégie de migration complète avec 3+ options en <60 min

### Scénario 5 : Analyse Cross-Domain

**Tâche :** "Analyser l'impact de passer de SQLite à Qdrant pour le cache conversations"

**Attendu :**
- Escalade automatique : ask-simple → ask-complex (cross-domain, synthèse)
- Recherche externe (docs Qdrant, comparaisons SQLite vs vector DB)
- Rapport : Trade-offs, migration path, risques
- Pas d'implémentation (Phase A)

**Critère succès :** Analyse comparative complète avec recommandation en <45 min

---

## Fichiers de Référence

| Fichier | Rôle | Éditable |
|---------|------|----------|
| `roo-config/modes/modes-config.json` | Source de vérité pour les 10 modes | ✅ Oui (puis régénérer) |
| `roo-config/scripts/generate-modes.js` | Générateur de `.roomodes` | ❌ Non (sauf bug) |
| `roo-config/modes/generated/simple-complex.roomodes` | Modes générés (intermédiaire) | ❌ Non (auto-généré) |
| `.roomodes` | Modes déployés dans workspace | ❌ Non (copié depuis generated/) |
| `.roo/schedules.template.json` | Template config scheduler | ✅ Oui (puis redéployer) |
| `.roo/schedules.json` | Config scheduler déployée | ❌ Non (auto-généré) |
| `.roo/scheduler-workflow-executor.md` | Workflow scheduler executeur | ✅ Oui (commun toutes machines) |

**Règle :** Toujours modifier les sources, jamais les fichiers générés.

---

**Auteur :** Claude Code (myia-po-2025, myia-po-2026)
**Issues liées :** #462, #464
**Dernière mise à jour :** 2026-02-13
