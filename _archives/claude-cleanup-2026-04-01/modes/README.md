# Système de Modes Claude Code

**Version:** 1.0.0
**Date:** 2026-02-11
**Issue:** #414 Phase 1

---

## Vue d'Ensemble

Système de modes avec escalade automatique inspiré du système Roo, optimisé pour la gestion des coûts.

**Principe :** Démarrer avec Haiku (économique), escalader vers Sonnet/Opus uniquement si nécessaire.

---

## Modes Disponibles

### Famille Sync

| Mode | Modèle | Usage | Coût/1M tokens |
|------|--------|-------|----------------|
| **sync-simple** | Haiku 4.5 | Sync basique, checks | $0.25 |
| **sync-complex** | Sonnet 4.5 | Conflits git, build/tests | $3.00 |

**Escalade automatique :** sync-simple → sync-complex si :
- Conflits git détectés
- Erreurs de build complexes
- Décisions de coordination nécessaires

---

### Famille Code

| Mode | Modèle | Usage | Coût/1M tokens |
|------|--------|-------|----------------|
| **code-simple** | Haiku 4.5 | <50 lignes, docs | $0.25 |
| **code-complex** | Sonnet 4.5 | Refactoring, features | $3.00 |
| **code-critical** | Opus 4.6 | Architecture système | $15.00 |

**Escalade automatique :**
- simple → complex si : >50 lignes, refactoring, tests échouent
- complex → critical si : >500 lignes, architecture système

---

### Famille Debug

| Mode | Modèle | Usage | Coût/1M tokens |
|------|--------|-------|----------------|
| **debug-simple** | Haiku 4.5 | Syntaxe, typos | $0.25 |
| **debug-complex** | Sonnet 4.5 | Bugs complexes | $3.00 |

**Escalade automatique :** simple → complex si :
- Bug non reproductible
- Erreur intermittente
- Problème de concurrence

---

### Famille Coordination

| Mode | Modèle | Usage | Coût/1M tokens |
|------|--------|-------|----------------|
| **coordinate-simple** | Haiku 4.5 | Messages RooSync | $0.25 |
| **coordinate-complex** | Opus 4.6 | Planification multi-agent | $15.00 |

**Escalade automatique :** simple → complex si :
- Décisions multi-agent nécessaires
- Planification de tâches requise
- Conflits de priorités

---

## Mécanisme d'Escalade

### Déclenchement Automatique

L'escalade se déclenche dans 3 cas :

1. **Échecs répétés** : 2 tentatives infructueuses en mode simple
2. **Complexité détectée** : Taille du changement, architecture touchée
3. **Conditions spécifiques** : Définies dans `modes-config.json`

### Exemple de Workflow

```
┌─────────────────┐
│ sync-simple     │  Haiku : git pull, check messages
│ (Haiku 4.5)     │  ✓ OK : Pas de conflits
└─────────────────┘  Coût : ~$0.01

┌─────────────────┐
│ code-simple     │  Haiku : Fix typo dans README.md
│ (Haiku 4.5)     │  ✗ FAIL : Changement touche 5 fichiers (>50 lignes)
└────────┬────────┘
         │ ESCALADE
         ▼
┌─────────────────┐
│ code-complex    │  Sonnet : Refactoring complet
│ (Sonnet 4.5)    │  ✓ OK : Changements appliqués + tests PASS
└─────────────────┘  Coût : ~$0.15
```

---

## Optimisation des Coûts

### Règles de Base

1. **Toujours démarrer en mode simple** (Haiku)
2. **Escalader uniquement si nécessaire** (conditions strictes)
3. **Limiter les itérations** (maxIterations par mode)
4. **Monitoring quotidien** (dailyTokenLimit : 1M tokens)

### Fallback Local (Économie Max)

```json
{
  "preferLocalModels": true,
  "localModelFallback": "glm-4.7-flash"
}
```

Pour tâches simples répétitives, utiliser GLM 4.7 Flash local (gratuit).

---

## Estimation Coûts Mensuel

**Scénario conservateur** (5 machines, 8 sync/jour) :

| Activité | Tokens/jour | Coût/jour | Coût/mois |
|----------|-------------|-----------|-----------|
| Sync simple (8×5) | 400K | $0.10 | $3.00 |
| Code simple (10×5) | 500K | $0.125 | $3.75 |
| Escalades complex (2×5) | 200K | $0.60 | $18.00 |
| **TOTAL** | 1.1M | $0.825 | **~$25/mois** |

**Scénario intensif** (escalades fréquentes) : **~$100/mois**

---

## Configuration Scheduler

Les modes sont utilisés automatiquement par les scripts de scheduling :

```powershell
# start-claude-worker.ps1 démarre en sync-simple
.\scripts\scheduling\start-claude-worker.ps1 -Mode "sync-simple"

# Escalade automatique si nécessaire
# sync-simple détecte conflits → lance sync-complex
```

---

## Monitoring

### Logs

Les logs d'escalade sont dans :
```
.claude/logs/escalation-{YYYY-MM-DD}.log
```

### Métriques

```powershell
# Voir consommation tokens aujourd'hui
.\scripts\scheduling\check-token-usage.ps1

# Rapport hebdomadaire
.\scripts\scheduling\weekly-report.ps1
```

---

## Références

- Issue #414 : Stratégie scheduling Claude Code
- Issue #387 : Modes SDDD simple/complex (Roo)
- [modes-config.json](.claude/modes/modes-config.json) : Configuration complète
- [docs/architecture/scheduling-claude-code.md](../../docs/architecture/scheduling-claude-code.md) : Investigation

---

**Prochaine étape :** Implémenter scripts PowerShell Phase 1
