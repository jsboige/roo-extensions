# SDDD Router - Stratégie de Routage Multi-Modèles

**Version:** 2.0.0
**Date:** 2026-01-24
**Référence:** Tâche #353

---

## Vue d'ensemble

Le **SDDD Router** détermine quel modèle LLM utiliser pour une tâche selon sa complexité et les quotas disponibles.

### Modèles Disponibles

| Modèle | Provider | Contexte | Output | Quota (5h) | Cas d'usage |
|--------|----------|----------|--------|------------|-------------|
| **GLM 4.7 Flash** | z.ai | 200K | 128K | ~2400* | Tâches très simples |
| **GLM 4.7** | z.ai | 200K | 128K | ~2400* | Tâches complexes Roo |
| **Claude Haiku** | Anthropic | 200K | ? | ~200-800** | Tâches simples Claude |
| **Claude Sonnet 4.5** | Anthropic | 200K | ? | ~200-800** | Tâches standard Claude |
| **Claude Opus 4.5** | Anthropic | 200K | 64K | ~200-800** | Tâches critiques |

\* GLM Max subscription (~$30/mo) - Quota partagé entre tous les modèles GLM
\** Claude Max 20x subscription ($200/mo) - Quota partagé entre tous les modèles Claude

### Principe Fondamental

> **"Utiliser le modèle le moins sollicitant capable de résoudre la tâche avec succès"**

**Rationnement par quotas :**
- GLM Max offre ~12x plus de prompts que Claude Max pour ~6x moins cher
- Opus 4.5 a été maxé en janvier 2026 → rationnement nécessaire
- GLM 4.7 Flash tournera en local à terme → quasi-illimité

---

## Stratégie de Rationnement

### 1. Rationnement Manuel (Extension Claude-Code)

**Géré par l'utilisateur** dans l'interface Claude-Code :
- **Sonnet 4.5** : Par défaut, devrait tenir sans maxer
- **Opus 4.5** : Réservé aux tâches complexes (déjà maxé en janvier)

### 2. Rationnement Automatique Roo (Scheduler)

**Géré par RooScheduler** via modes SDDD :
- **Mode Simple** : GLM 4.7 Flash (ou GLM 4.7 si quota Flash épuisé)
- **Mode Complex** : GLM 4.7

### 3. Escalades vers Claude (`claude -p ...`)

**Géré par scripts Roo** lors d'escalades :
- **Tâches simples** : Claude Haiku
- **Tâches standard** : Claude Sonnet 4.5 (défaut)
- **Tâches complexes** : Claude Opus 4.5

---

## Règles de Routage Basées sur level-criteria.json

### Niveau Simple → GLM 4.7 Flash / Claude Haiku

**Critères (selon level-criteria.json v1.1.0) :**
- Tâche clairement définie avec un seul objectif
- Pas de dépendances externes complexes
- Modification de 1-3 fichiers maximum
- Pas de décision architecturale requise
- Pattern existant à suivre dans le codebase

**Cas d'usage :**
- Documentation (README, commentaires, guides)
- Corrections typos et erreurs syntaxiques simples
- Modifications cosmétiques (formatage, renommage)
- Messages RooSync/INTERCOM
- Tests unitaires basiques

### Niveau Complex → GLM 4.7 / Claude Sonnet 4.5

**Critères :**
- Tâche avec multiples sous-objectifs
- Dépendances entre composants
- Modification de 4+ fichiers
- Décision architecturale ou design requise
- Nouveau pattern à établir

**Cas d'usage :**
- Features complètes end-to-end
- Debugging multi-fichiers
- Refactoring architectural
- Tests d'intégration E2E complexes
- Optimisation performance

### Niveau Premium → Claude Opus 4.5

**Critères :**
- Tâche critique en production
- Sécurité ou conformité requise
- Architecture stratégique ou innovation
- Échec répété sur Sonnet (2+ tentatives)

**Cas d'usage :**
- Système d'authentification complet
- Race conditions critiques
- Architecture microservices
- Vulnérabilités sécurité (XSS, injection SQL)

---

## Flux d'Escalade

### Roo Scheduler (Automatique)

```
┌────────────────┐
│ GLM 4.7 Flash  │ ← Défaut mode simple
└────────┬───────┘
         │ Échec ×2 ou quota épuisé
         ▼
┌────────────────┐
│   GLM 4.7      │ ← Défaut mode complex
└────────┬───────┘
         │ Échec ×2 ou trigger claude
         ▼
┌────────────────┐
│ Claude Haiku   │ ← Escalade simple
└────────┬───────┘
         │ Échec ×2
         ▼
┌────────────────┐
│ Claude Sonnet  │ ← Escalade standard
└────────┬───────┘
         │ Échec ×2
         ▼
┌────────────────┐
│ Claude Opus    │ ← Dernier recours
└────────────────┘
```

### Triggers d'Escalade

**GLM Flash → GLM :**
- Erreur après 2 tentatives
- Modification dépasse 50 lignes
- Logique métier complexe détectée

**GLM → Claude Haiku :**
- Échec après 2 tentatives
- Nécessite validation humaine
- Contexte > 128K tokens (limite output GLM 4.7)

**Haiku → Sonnet :**
- Échec après 2 tentatives
- Complexité sous-estimée

**Sonnet → Opus :**
- Échec après 2 tentatives
- Tâche identifiée comme critique
- Architecture stratégique

---

## Comparaison des Quotas

### Quotas par Cycle de 5 Heures

| Provider | Plan | Quota Prompts | Coût/Prompt | Coût Mensuel |
|----------|------|---------------|-------------|--------------|
| **z.ai** | GLM Max | ~2400 | ~$0.01 | ~$30 |
| **Anthropic** | Claude Max 20x | ~200-800 | ~$0.25-1.00 | $200 |

**Ratio :** GLM Max offre ~12x plus de prompts pour ~6x moins cher

### Stratégie Optimale (Janvier 2026)

- **80% GLM** (simple + complex) : ~1920 prompts/5h utilisés
- **15% Claude Sonnet** : ~30-120 prompts/5h utilisés
- **5% Claude Opus** : ~10-40 prompts/5h utilisés (CRITIQUE : déjà maxé)

---

## Arbre de Décision

### Questions de Routage

1. **Agent demandeur ?**
   - Roo Scheduler → GLM (simple/complex selon level-criteria.json)
   - Extension Claude-Code (manuel) → Sonnet ou Opus (choix utilisateur)
   - Escalade `claude -p ...` → Question 2

2. **Complexité de la tâche ?**
   - Simple (1-3 fichiers, pattern clair) → Haiku
   - Standard (4+ fichiers, design requis) → Sonnet
   - Critique (sécurité, architecture) → Opus

3. **Quota disponible ?**
   - Opus épuisé → Fallback Sonnet
   - Sonnet épuisé → Fallback Haiku
   - Haiku épuisé → Attendre reset 5h

---

## KPIs et Monitoring

### Indicateurs Clés

| KPI | Cible | Critique |
|-----|--------|----------|
| **GLM Success Rate** | > 85% | Réviser prompts si < 70% |
| **Escalation Rate GLM → Claude** | < 15% | Analyser si > 20% |
| **Opus Weekly Usage** | < quota | ⚠️ Déjà maxé janvier 2026 |
| **Sonnet Weekly Usage** | < quota | Monitoring actif |

### Métriques à Tracker

1. **Par Agent :**
   - Roo Scheduler : % GLM Flash vs GLM 4.7 vs Claude
   - Claude-Code Extension : % Sonnet vs Opus
   - Escalades : Distribution Haiku/Sonnet/Opus

2. **Par Quota :**
   - Utilisation GLM Max (~2400/5h)
   - Utilisation Claude Max (~200-800/5h)
   - Temps avant épuisement

---

## Annexes

### Références Techniques

- [GLM 4.7 Technical Analysis](https://medium.com/@leucopsis/a-technical-analysis-of-glm-4-7-db7fcc54210a)
- [Claude Opus 4.5 Announcement](https://www.anthropic.com/news/claude-opus-4-5)
- [z.ai GLM Coding Plan](https://z.ai/subscribe)
- [Claude Max Subscription](https://support.claude.com/en/articles/11145838-using-claude-code-with-your-pro-or-max-plan)

### Configuration Files

- [`level-criteria.json`](./level-criteria.json) (v1.1.0) - Critères simple/complex
- [`model-configs.json`](../model-configs.json) - Profiles SDDD

**⚠️ ERREUR DE CONFIGURATION :**

Dans [`model-configs.json`](../model-configs.json) ligne 100-110, la config utilise :
```json
"glm-4.7-air": {
  "openRouterModelId": "zhipu/glm-4.7-air"
}
```

**Ce modèle n'existe pas.** Le modèle correct est **GLM 4.7 Flash** (`z-ai/glm-4.7-flash` sur OpenRouter).

**Correction requise :**
```json
"glm-4.7-flash": {
  "openRouterModelId": "z-ai/glm-4.7-flash",
  "id": "sddd-simple-glm47flash",
  "description": "GLM 4.7 Flash pour tâches SDDD simples"
}
```

### Historique des Versions

| Version | Date | Modifications |
|---------|------|---------------|
| 2.0.0 | 2026-01-24 | Réécriture complète basée sur faits vérifiés |
| ~~1.0.0~~ | 2026-01-23 | Version initiale (contenu halluciné) - ANNULÉE |

### Notes d'Implémentation

- Quotas basés sur souscriptions forfaitaires (pas de coût variable)
- Rationnement nécessaire pour Opus 4.5 (déjà maxé janvier 2026)
- GLM Max offre ~12x plus de prompts que Claude Max
- GLM 4.7 Flash tournera en local à terme → quasi-illimité
- **ACTION REQUISE :** Corriger `model-configs.json` pour utiliser `z-ai/glm-4.7-flash` au lieu de `zhipu/glm-4.7-air` qui n'existe pas

---

**Sources :**
- [Claude Max Usage Limits](https://support.claude.com/en/articles/11145838-using-claude-code-with-your-pro-or-max-plan)
- [GLM 4.7 Context Window 200K](https://llm-stats.com/models/glm-4.7)
- [Claude Opus 4.5 Context 200K](https://platform.claude.com/docs/en/build-with-claude/context-windows)
- [z.ai GLM Coding Plan Pricing](https://z.ai/subscribe)
- [Opus 4.5 Usage Limits Issue (Jan 2026)](https://github.com/anthropics/claude-code/issues/17084)
