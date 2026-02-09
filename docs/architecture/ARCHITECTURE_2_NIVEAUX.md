# Architecture SDDD 2-Niveaux

**Version:** 1.0.0
**Date:** 2026-01-22
**Auteur:** Claude Code (myia-po-2023)
**Statut:** 🟢 Production Ready

---

## Table des Matières

1. [Vue d'ensemble](#1-vue-densemble)
2. [Principes de l'Architecture 2-Niveaux](#2-principes-de-larchitecture-2-niveaux)
3. [Répartition Roo vs Claude Code](#3-répartition-roo-vs-claude-code)
4. [Architecture Roo : GLM 4.7 vs GLM 4.7 Air](#4-architecture-roo--glm-47-vs-glm-47-air)
5. [Architecture Claude Code : Haiku/Sonnet/Opus](#5-architecture-claude-code--haikusonnetopus)
6. [Critères de Sélection](#6-critères-de-sélection)
7. [Implémentation](#7-implémentation)
8. [Monitoring et Optimisation](#8-monitoring-et-optimisation)
9. [Références](#9-références)

---

## 1. Vue d'ensemble

### 1.1 Objectif

L'architecture SDDD 2-niveaux vise à **optimiser les coûts et les performances** en routant intelligemment les tâches vers le modèle le plus adapté, selon leur complexité et criticité.

### 1.2 Contexte

**Système RooSync Multi-Agent (5 machines)** :
- **5 instances Roo** (agent technique, code)
- **5 instances Claude Code** (coordination, documentation)
- **Total : 10 agents actifs**

**Contraintes** :
- **Roo** : Accès modèles GLM via z.ai (GLM 4.7 + GLM 4.7 Air)
- **Claude Code** : Abonnement Claude Pro Max (quotas limités)
- **Objectif** : Maximiser productivité tout en minimisant coûts

### 1.3 Principe Central

```
┌─────────────────────────────────────────────────────────────┐
│                    ARCHITECTURE 2-NIVEAUX                    │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
       ┌─────────────┐                 ┌─────────────┐
       │   ROO CODE  │                 │ CLAUDE CODE │
       │  (Technique)│                 │(Coordination)│
       └─────────────┘                 └─────────────┘
              │                               │
       ┌──────┴──────┐              ┌────────┴────────┐
       ▼             ▼              ▼        ▼        ▼
   ┌──────┐    ┌────────┐      ┌──────┐ ┌────┐  ┌─────┐
   │ GLM  │    │  GLM   │      │Haiku │ │Sonnet│ │Opus │
   │4.7   │    │4.7 Air │      │(auto)│ │(man) │ │(1/j)│
   │(std) │    │(mini)  │      └──────┘ └────┘  └─────┘
   └──────┘    └────────┘
   Complex      Simple         Auto     Manuel   Escalade
```

---

## 2. Principes de l'Architecture 2-Niveaux

### 2.1 Séparation des Responsabilités

| Agent | Rôle | Modèles | Usage |
|-------|------|---------|-------|
| **Roo Code** | Exécution technique | GLM 4.7 / Air | Code, tests, build, scripts |
| **Claude Code** | Coordination & documentation | Haiku/Sonnet/Opus | Docs, coordination, analyse |

### 2.2 Hiérarchie de Décision

**Révision du protocole (2026-01-22)** :

1. **Claude Code = Cerveau Principal**
   - Décisions d'architecture
   - Validation du code critique
   - Coordination globale

2. **Roo Code = Assistant Polyvalent**
   - Exécution des tâches techniques
   - Code validé par Claude
   - Orchestrations longues

### 2.3 Stratégie de Routage

**Principe : "Le bon modèle pour la bonne tâche"**

| Critère | Modèle Léger | Modèle Puissant |
|---------|--------------|-----------------|
| **Tâches simples** | GLM 4.7 Air, Haiku | - |
| **Tâches complexes** | - | GLM 4.7, Sonnet |
| **Tâches critiques** | - | Opus (1/jour max) |

---

## 3. Répartition Roo vs Claude Code

### 3.1 Quand Utiliser Roo Code

**Tâches techniques** :
- ✅ Écriture de code (features, fixes)
- ✅ Exécution de tests unitaires
- ✅ Build et compilation
- ✅ Scripts PowerShell / Bash
- ✅ Orchestrations longues (séquences de commandes)
- ✅ Bulk operations (tâches répétitives)

**Contrainte** : Code critique doit être validé par Claude avant commit.

### 3.2 Quand Utiliser Claude Code

**Coordination et documentation** :
- ✅ Documentation technique (architecture, guides)
- ✅ Analyse de code et architecture
- ✅ Décisions d'architecture
- ✅ Coordination multi-agent (RooSync)
- ✅ Investigation de bugs complexes
- ✅ Validation du code Roo

**Capacités techniques** : Claude Code peut aussi coder (investigation, fixes simples, prototypes).

### 3.3 Collaboration Roo ↔ Claude

**Workflow type** :

```
1. Claude analyse le problème
2. Claude décide de l'approche
3. Claude délègue implémentation à Roo (via INTERCOM)
4. Roo code et teste
5. Roo informe Claude (INTERCOM)
6. Claude valide le code
7. Claude commit et push
```

---

## 4. Architecture Roo : GLM 4.7 vs GLM 4.7 Air

### 4.1 Modèles Disponibles

| Modèle | Tier z.ai | Capacités | Coût | Usage |
|--------|-----------|-----------|------|-------|
| **GLM 4.7** | Standard | Raisonnement avancé, contexte large | Standard | Tâches complexes |
| **GLM 4.7 Air** | Mini | Rapide, léger, tâches simples | Réduit | Tâches simples |

### 4.2 Critères de Sélection Roo

**Utiliser GLM 4.7 Air (simple) si** :
- ✅ Tâche < 50 lignes de code
- ✅ Documentation simple (README, commentaires)
- ✅ Communication (messages RooSync, INTERCOM)
- ✅ Scripts simples (1-2 fichiers)
- ✅ Corrections typos, imports

**Utiliser GLM 4.7 (complex) si** :
- ✅ Features multi-fichiers
- ✅ Debugging complexe (stack traces, dépendances)
- ✅ Refactoring d'architecture
- ✅ Tests E2E
- ✅ Modifications > 100 lignes

**Triggers d'escalade Air → Standard** :
- ❌ Erreur après 2 tentatives avec Air
- ❌ Modification dépasse 100 lignes
- ❌ Dépendances inter-fichiers non résolues

### 4.3 Modes Roo Proposés

**Configuration recommandée** (voir #352) :

```json
{
  "sddd-simple": {
    "model": "glm-4.7-air",
    "provider": "z.ai",
    "tier": "Mini",
    "use_cases": ["docs", "communication", "scripts-simples"]
  },
  "sddd-complex": {
    "model": "glm-4.7",
    "provider": "z.ai",
    "tier": "Standard",
    "use_cases": ["features", "debugging", "refactoring"]
  }
}
```

**Fichier de référence** : `roo-config/sddd/level-criteria.json` (voir #351)

---

## 5. Architecture Claude Code : Haiku/Sonnet/Opus

### 5.1 Modèles Claude Disponibles

| Modèle | Capacités | Coût | Quota Max | Usage |
|--------|-----------|------|-----------|-------|
| **Claude Haiku** | Rapide, léger | Faible | Illimité* | Scheduling, notifications |
| **Claude Sonnet 4.5** | Équilibré | Moyen | Manuel | Usage quotidien |
| **Claude Opus 4.5** | Raisonnement avancé | Élevé | **1/jour/machine** | Escalade critique |

*Illimité : Dans les limites raisonnables de l'abonnement Pro Max.

### 5.2 Stratégie de Rationnement Claude

**Politique d'usage** (voir #353) :

| Modèle | Fréquence | Cas d'usage |
|--------|-----------|-------------|
| **Haiku** | Automatique | RooScheduler (quotidien), résumés, notifications |
| **Sonnet** | Manuel | Sessions interactives, investigation, documentation |
| **Opus** | 1/jour/machine | Escalade Level 3 (échecs critiques) |

**Pas de router automatique** : Approche manuelle avec escalade contrôlée.

### 5.3 Triggers d'Escalade Claude

**Sonnet → Opus** (max 1/jour) :
- ❌ Échec critique RooScheduler (> 3 tâches échouées)
- ❌ Bug bloquant non résolu après investigation Sonnet
- ❌ Décision d'architecture majeure
- ❌ Conflit git complexe

**Documentation** : `.claude/agents/sddd-router.md` (voir #353)

---

## 6. Critères de Sélection

### 6.1 Arbre de Décision Global

```
┌─────────────────────────────────────┐
│     Nouvelle tâche détectée         │
└──────────────┬──────────────────────┘
               │
               ▼
      ┌────────────────┐
      │ Type de tâche? │
      └────┬───────┬───┘
           │       │
      Code │       │ Coordination/Docs
           ▼       ▼
       ┌─────┐  ┌──────┐
       │ Roo │  │Claude│
       └──┬──┘  └───┬──┘
          │         │
    ┌─────┴────┐    ├──────┬──────┐
    ▼          ▼    ▼      ▼      ▼
 ┌────┐    ┌────┐ Haiku Sonnet Opus
 │Air │    │4.7 │ (auto)(man) (1/j)
 └────┘    └────┘
 Simple   Complex
```

### 6.2 Matrice de Décision Roo

| Tâche | Lignes | Fichiers | Complexité | Modèle | Justification |
|-------|--------|----------|------------|--------|---------------|
| Typo fix | < 10 | 1 | Triviale | **Air** | Modification locale simple |
| Script PS1 | < 50 | 1-2 | Basse | **Air** | Logic simple, 1-2 fichiers |
| Feature simple | < 100 | 2-3 | Moyenne | **4.7** | Multi-fichiers, tests requis |
| Debugging bug | Variable | 3+ | Haute | **4.7** | Stack trace, dépendances |
| Refactoring | > 100 | 5+ | Très haute | **4.7** | Architecture, impacts multiples |

### 6.3 Matrice de Décision Claude

| Tâche | Fréquence | Criticité | Modèle | Justification |
|-------|-----------|-----------|--------|---------------|
| Résumé sync | Quotidien | Basse | **Haiku** | Automatique, non-critique |
| Investigation bug | Ponctuel | Moyenne | **Sonnet** | Manuel, analyse approfondie |
| Décision archi | Rare | Haute | **Opus** | 1/jour, impact global |
| Escalade critique | Exceptionnel | Critique | **Opus** | Échec Level 3 |

---

## 7. Implémentation

### 7.1 Roadmap Phase 2

**Tâches en cours** (voir GitHub Project #67) :

| Issue | Titre | Machine | Statut | Priorité |
|-------|-------|---------|--------|----------|
| #351 | Critères SDDD GLM 4.7 vs Air | myia-po-2026 | Todo | HIGH |
| #352 | Modes sddd-simple/complex | myia-web1 | Todo | HIGH |
| #353 | Stratégie rationnement Claude | myia-po-2026 | Todo | MEDIUM |
| #355 | **Documentation 2-niveaux** | **myia-po-2023** | **In Progress** | **HIGH** |

### 7.2 Fichiers de Configuration

**Roo Code** :
- `roo-config/sddd/level-criteria.json` - Critères GLM (#351)
- `roo-config/model-configs.json` - Profils GLM (#352)
- `roo-config/settings/modes.json` - Modes SDDD (#352)

**Claude Code** :
- `.claude/agents/sddd-router.md` - Stratégie rationnement (#353)
- `docs/sddd/ARCHITECTURE_2_NIVEAUX.md` - Ce document (#355)

### 7.3 Workflow de Déploiement

**Phase 2.1 - Critères** (#351) :
1. Créer `roo-config/sddd/level-criteria.json`
2. Définir critères Air vs Standard
3. Documenter triggers d'escalade
4. Valider avec exemples concrets

**Phase 2.2 - Modes** (#352) :
1. Modifier `roo-config/model-configs.json`
2. Ajouter profils GLM 4.7 / Air
3. Créer modes `sddd-simple` / `sddd-complex`
4. Tester sélection automatique

**Phase 2.3 - Rationnement** (#353) :
1. Créer `.claude/agents/sddd-router.md`
2. Documenter politique Haiku/Sonnet/Opus
3. Définir triggers escalade
4. Intégrer au RooScheduler

**Phase 2.4 - Validation** :
1. Tests E2E workflow complet
2. Monitoring consommation modèles
3. Ajustements basés sur métriques

---

## 8. Monitoring et Optimisation

### 8.1 Métriques à Suivre

**Roo Code** :
- Ratio Air / Standard par type de tâche
- Taux de succès Air (vs escalade)
- Temps moyen par tâche (Air vs Standard)

**Claude Code** :
- Consommation Haiku vs Sonnet vs Opus
- Fréquence escalades Opus (objectif : < 1/jour/machine)
- Délai réponse scheduling Haiku

### 8.2 Optimisations Futures

**Court terme** :
- Affiner critères Air vs Standard basé sur historique
- Automatiser détection candidats Air
- Logs détaillés sélection modèle

**Moyen terme** :
- Router intelligent basé sur ML (prédiction complexité)
- Cache résultats tâches répétitives
- Batch processing tâches Air

**Long terme** :
- Auto-tuning critères basé sur métriques
- Prédiction coûts mensuels
- Dashboard monitoring multi-agent

---

## 9. Références

### 9.1 Documentation Technique

- [PROTOCOLE_SDDD.md](../roosync/PROTOCOLE_SDDD.md) - Méthodologie SDDD v2.6.0
- [GUIDE-TECHNIQUE-v2.3.md](../roosync/GUIDE-TECHNIQUE-v2.3.md) - Guide RooSync
- [CLAUDE.md](../../CLAUDE.md) - Configuration projet

### 9.2 Issues GitHub

- [#351](https://github.com/jsboige/roo-extensions/issues/351) - Critères SDDD GLM 4.7 vs Air
- [#352](https://github.com/jsboige/roo-extensions/issues/352) - Modes sddd-simple/complex
- [#353](https://github.com/jsboige/roo-extensions/issues/353) - Stratégie rationnement Claude
- [#355](https://github.com/jsboige/roo-extensions/issues/355) - Documentation 2-niveaux (ce document)

### 9.3 Fichiers de Configuration

- [`roo-config/model-configs.json`](../../roo-config/model-configs.json) - Configuration modèles
- [`roo-config/settings/modes.json`](../../roo-config/settings/modes.json) - Modes Roo
- [`.claude/commands/executor.md`](../../.claude/commands/executor.md) - Protocole exécutant
- [`.claude/local/INTERCOM-*.md`](../../.claude/local/) - Communication locale

---

**Document créé par :** Claude Code (myia-po-2023)
**Date de création :** 2026-01-22T23:00:00Z
**Version :** 1.0.0
**Statut :** 🟢 Production Ready

**Changelog :**
- **2026-01-22 v1.0.0** - Création initiale (Issue #355)
