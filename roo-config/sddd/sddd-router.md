# SDDD Router - Stratégie de Routage par Niveaux

**Version:** 3.0.0
**Date:** 2026-01-25
**Référence:** Tâche #353

---

## Vue d'ensemble

Le **SDDD Router** détermine **quel niveau de routage utiliser** pour une tâche selon sa complexité. Le mapping effectif vers les modèles LLM est géré par les fichiers de configuration.

### Principe Fondamental

> **"Router vers le niveau le moins sollicitant capable de résoudre la tâche avec succès"**

**Séparation des responsabilités :**
- **Router** → Décide du **niveau** (simple/complex, haiku/sonnet/opus)
- **Configuration** → Définit le **mapping** niveau → modèle effectif

---

## Niveaux de Routage (Abstraction)

### Pour Roo Scheduler

| Niveau | Description | Cas d'usage typiques |
|--------|-------------|---------------------|
| **simple** | Tâches clairement définies, un seul objectif | Documentation, fixes simples, messages |
| **complex** | Tâches multi-objectifs, décisions requises | Features, debugging, refactoring |

**Configuration :** [`model-configs.json`](../model-configs.json) → `modeApiConfigs`

```json
"modeApiConfigs": {
  "sddd-simple": "sddd-simple-glm47flash",
  "sddd-complex": "sddd-complex-glm47"
}
```

### Pour Claude-Code Extension

| Niveau | Description | Cas d'usage typiques |
|--------|-------------|---------------------|
| **haiku** | Tâches simples, peu de contexte | Recherche rapide, validation simple |
| **sonnet** | Tâches standard, design requis | Features standard, debugging |
| **opus** | Tâches critiques, architecture | Sécurité, architecture stratégique |

**Configuration :** [`.claude/configs/provider.zai.template.json`](../.claude/configs/provider.zai.template.json)

```json
"env": {
  "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4.5-air",
  "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-4.7",
  "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-4.7"
}
```

**Note :** Le mapping effectif dépend du provider configuré (Anthropic ou z.ai).

---

## Critères de Décision (Basés sur level-criteria.json)

### Niveau Simple

**Critères (selon level-criteria.json v1.1.0) :**
- ✅ Tâche clairement définie avec un seul objectif
- ✅ Pas de dépendances externes complexes
- ✅ Modification de 1-3 fichiers maximum
- ✅ Pas de décision architecturale requise
- ✅ Pattern existant à suivre dans le codebase

**Exemples concrets :**
- Documentation (README, commentaires, guides)
- Corrections typos et erreurs syntaxiques
- Modifications cosmétiques (formatage, renommage)
- Messages RooSync/INTERCOM
- Tests unitaires basiques

**Routage :**
- **Roo** → Niveau `simple`
- **Claude-Code** → Niveau `haiku`

### Niveau Complex

**Critères :**
- ✅ Tâche avec multiples sous-objectifs
- ✅ Dépendances entre composants
- ✅ Modification de 4+ fichiers
- ✅ Décision architecturale ou design requise
- ✅ Nouveau pattern à établir

**Exemples concrets :**
- Features complètes end-to-end
- Debugging multi-fichiers
- Refactoring architectural
- Tests d'intégration E2E complexes
- Optimisation performance

**Routage :**
- **Roo** → Niveau `complex`
- **Claude-Code** → Niveau `sonnet`

### Niveau Premium (Claude-Code uniquement)

**Critères :**
- ✅ Tâche critique en production
- ✅ Sécurité ou conformité requise
- ✅ Architecture stratégique ou innovation
- ✅ Échec répété sur niveau `sonnet` (2+ tentatives)

**Exemples concrets :**
- Système d'authentification complet
- Race conditions critiques
- Architecture microservices
- Vulnérabilités sécurité (XSS, injection SQL)

**Routage :**
- **Claude-Code** → Niveau `opus`

---

## Flux d'Escalade

### Roo Scheduler (Automatique)

```
┌──────────────┐
│    simple    │ ← Défaut pour tâches simples
└──────┬───────┘
       │ Échec ×2 ou complexité détectée
       ▼
┌──────────────┐
│   complex    │ ← Escalade automatique
└──────┬───────┘
       │ Échec ×2 ou trigger escalade
       ▼
┌──────────────┐
│ claude haiku │ ← Escalade vers Claude (tâches simples)
└──────┬───────┘
       │ Échec ×2
       ▼
┌──────────────┐
│claude sonnet │ ← Escalade standard
└──────┬───────┘
       │ Échec ×2
       ▼
┌──────────────┐
│ claude opus  │ ← Dernier recours
└──────────────┘
```

### Triggers d'Escalade

**Niveau simple → complex :**
- Erreur après 2 tentatives
- Modification dépasse 50 lignes
- Logique métier complexe détectée

**Niveau complex → claude haiku :**
- Échec après 2 tentatives
- Nécessite validation humaine
- Contexte très large (dépend des limites du modèle mappé)

**Niveau haiku → sonnet :**
- Échec après 2 tentatives
- Complexité sous-estimée

**Niveau sonnet → opus :**
- Échec après 2 tentatives
- Tâche identifiée comme critique
- Architecture stratégique

---

## Arbre de Décision

### 1. Identifier l'Agent Demandeur

**Roo Scheduler :**
- Appliquer critères de level-criteria.json
- Router vers niveau `simple` ou `complex`
- Escalader vers Claude si échecs répétés

**Extension Claude-Code (Manuel) :**
- Choix utilisateur entre `haiku`, `sonnet`, `opus`
- Escalade manuelle selon résultats

**Escalade depuis Roo (`claude -p ...`) :**
- Passer à question 2

### 2. Évaluer la Complexité de la Tâche

| Critères | Niveau Recommandé |
|----------|-------------------|
| 1-3 fichiers, pattern clair, un seul objectif | `haiku` |
| 4+ fichiers, design requis, multi-objectifs | `sonnet` |
| Sécurité, architecture, critique | `opus` |

### 3. Appliquer le Mapping Effectif

Le niveau abstrait est mappé vers un modèle effectif selon :

**Roo :**
- Configuration dans [`model-configs.json`](../model-configs.json)
- Section `modeApiConfigs`

**Claude-Code :**
- Configuration dans [`.claude/configs/provider.*.json`](../.claude/configs/)
- Variables `ANTHROPIC_DEFAULT_*_MODEL`

**Note :** Le mapping peut différer selon les machines et les providers configurés.

---

## Configuration du Mapping

### Fichiers de Configuration

| Fichier | Responsabilité |
|---------|----------------|
| [`level-criteria.json`](./level-criteria.json) | Critères simple/complex avec arbre de décision |
| [`model-configs.json`](../model-configs.json) | Mapping Roo : simple/complex → modèles |
| [`.claude/configs/provider.*.json`](../.claude/configs/) | Mapping Claude-Code : haiku/sonnet/opus → modèles |

### Exemple de Mapping Roo

```json
// model-configs.json
"modeApiConfigs": {
  "sddd-simple": "sddd-simple-glm47flash",
  "sddd-complex": "sddd-complex-glm47"
}

"glm-4.7-flash": {
  "openRouterModelId": "z-ai/glm-4.7-flash",
  "id": "sddd-simple-glm47flash"
}
```

### Exemple de Mapping Claude-Code

```json
// .claude/configs/provider.zai.template.json
{
  "provider": "zai",
  "model": "sonnet",
  "env": {
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4.5-air",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-4.7",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-4.7"
  }
}
```

**Note :** Le provider `zai` mappe tous les niveaux Claude vers des modèles GLM.

---

## Implémentation

### Responsabilités du Router

**✅ Le Router DOIT :**
- Analyser la complexité de la tâche
- Décider du niveau abstrait (simple/complex ou haiku/sonnet/opus)
- Gérer les escalades entre niveaux
- Logger les décisions de routage

**❌ Le Router NE DOIT PAS :**
- Connaître les modèles effectifs derrière les niveaux
- Gérer les quotas ou limites de modèles spécifiques
- Dupliquer la configuration de mapping

### Responsabilités de la Configuration

**✅ La Configuration DOIT :**
- Définir le mapping niveau → modèle effectif
- Gérer les credentials et endpoints API
- Spécifier les limites de contexte par modèle

**❌ La Configuration NE DOIT PAS :**
- Définir les critères de routage (c'est le rôle du Router)
- Implémenter la logique d'escalade

---

## KPIs et Monitoring

### Indicateurs Clés (Par Niveau)

| KPI | Cible | Action si Critique |
|-----|-------|-------------------|
| **Success Rate niveau simple** | > 85% | Réviser critères si < 70% |
| **Escalation Rate simple → complex** | < 15% | Analyser causes si > 20% |
| **Escalation Rate Roo → Claude** | < 10% | Revoir mapping si > 15% |
| **Usage niveau opus** | < quota | Rationnement manuel |

### Métriques à Tracker

1. **Par Niveau :**
   - Distribution simple vs complex (Roo)
   - Distribution haiku vs sonnet vs opus (Claude)
   - Taux de succès par niveau

2. **Par Escalade :**
   - Nombre d'escalades par jour
   - Raisons d'escalade (échecs, complexité, validation)
   - Temps avant escalade

3. **Par Agent :**
   - Roo Scheduler : % simple vs complex vs escalades
   - Claude-Code Extension : % haiku vs sonnet vs opus

---

## Annexes

### Références

- [`level-criteria.json`](./level-criteria.json) (v1.1.0) - Critères et arbre de décision
- [`model-configs.json`](../model-configs.json) - Configuration Roo
- [`.claude/configs/`](../.claude/configs/) - Configuration Claude-Code

### Historique des Versions

| Version | Date | Modifications |
|---------|------|---------------|
| 3.0.0 | 2026-01-25 | Focus sur niveaux abstraits, séparation router/config |
| 2.0.0 | 2026-01-24 | Réécriture avec faits vérifiés |
| ~~1.0.0~~ | 2026-01-23 | Version initiale (contenu halluciné) - ANNULÉE |

### Principes de Design

1. **Séparation des préoccupations** : Router décide des niveaux, Config mappe vers les modèles
2. **Abstraction** : Le Router ne connaît pas les modèles effectifs
3. **Flexibilité** : Le mapping peut changer sans modifier le Router
4. **Testabilité** : Les critères de routage sont indépendants des modèles

---

**Built with Claude Code (Sonnet 4.5) 🤖**
