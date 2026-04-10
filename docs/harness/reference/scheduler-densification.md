# Règle de Densification Scheduler Roo

## Objectif

Remplir les itérations planifiées du scheduler Roo avec du travail jusqu'à atteindre l'état IDLE (plus rien à faire), tout en trouvant le **sweet spot** d'escalade.

## Seuil d'Escalade (STANDARDISE #1233)

**Règle :** 1 échec en `-simple` → escalade **IMMEDIATE** vers `-complex`. Pas de retry en -simple.

**Justification :** Le coût d'une boucle en -simple (temps perdu, contexte saturé) est supérieur au coût d'un -complex prématuré.

| Situation | Action |
|-----------|--------|
| Tâche simple réussie | Continuer en `-simple` |
| Tâche simple échoue 1x | **Escalader IMMEDIATEMENT vers `-complex`** |
| Tâche moyenne (3+ fichiers) | Démarrer directement en `-complex` si taux succès > 80% |

**Anti-pattern :** Laisser une tâche échouer 2-4 fois en `-simple` avant d'escalader.

## Rapport de Fin de Cycle (dans INTERCOM)

À la fin de chaque cycle scheduler, Claude Code vérifie et note dans l'INTERCOM :

```markdown
## [{DATE}] claude-code -> roo [FEEDBACK]
### Contrôle Scheduler

**Taux de remplissage :** X% (Y tâches / Z slots disponibles)
**Niveau atteint :** {simple|complex|mixte}
**Problèmes/blocages :** {liste ou "aucun"}
**Escalades effectuées :** X vers complex, Y vers Claude
**Conseil coordinateur :** {pousser complex|maintenir simple|investigation}

---
```

## Métriques à Surveiller

| Métrique | Cible | Action si hors cible |
|----------|-------|---------------------|
| Taux succès `-simple` | > 90% | Si < 80% : corriger workflow |
| Taux succès `-complex` | > 80% | Si < 70% : reprendre tâches échouées |
| Taux remplissage cycle | > 70% | Si < 50% : chercher plus de tâches |
| Escalades appropriées | 70-85% | Si < 50% : trop conservateur, si > 90% : trop agressif |
| Silence scheduler | < 48h | Si > 7 jours : vérifier que VS Code est lancé régulièrement |

## ⚠️ Interprétation Nuancée (CRITIQUE)

**100% succès en -simple NE VEUT PAS DIRE qu'il faut escalader plus tôt !**

| Taux succès -simple | Interprétation correcte | Action |
|---------------------|-------------------------|--------|
| < 80% | Problème workflow/compétences | Corriger workflow, réessayer |
| 80-95% | Sweet spot | Maintenir approche actuelle |
| > 95% | **Tâches trop faciles** | **Confier tâches plus complexes dès le départ** |

**Règle d'or :** Si le taux de succès -simple est très élevé, c'est que la sélection de tâches est trop conservatrice. La solution n'est pas de modifier le seuil d'escalade, mais de **sélectionner des tâches plus ambitieuses** au départ.

### Exemples concrets

❌ **MAUVAIS** : "100% succès -simple → modifier le seuil d'escalade"
✅ **BON** : "100% succès -simple → confier des investigations de bugs, du refactoring, des features"

## Workflow d'Ajustement

1. **Lire les traces Roo** via `conversation_browser(action: "list")` et `conversation_browser(action: "tree")`
2. **Calculer les métriques** sur les 3-5 derniers cycles
3. **Ajuster via INTERCOM** avec message `[FEEDBACK]`
4. **Si structural** : modifier `.roo/scheduler-workflow-executor.md`

## Références

- Commands : `/coordinate` (myia-ai-01), `/executor` (autres machines)
- Workflow Roo : `.roo/scheduler-workflow-executor.md`
- Traces : `conversation_browser(action: "tree")` + `conversation_browser(action: "view")`

---

## Issue #545 - Graduation vers modes Complex

**Contexte (2026-03-03):** Le scheduler Roo n'a jamais dépassé le niveau `-simple` car les tâches assignées étaient trop simples.

**Objectif :** Prouver que Roo peut compléter des tâches `-complex` avec résultats concrets.

### Tâches de Complexité Moyenne

Pour tester l'escalade, utiliser des tâches INTERCOM avec le tag `[COMPLEX]` :

**Type A - Investigation + rapport :**
- Recherche sémantique multi-sources
- Analyse de données multi-fichiers
- Synthèse de conclusions

**Type B - Modification de code guidée :**
- Lecture de plusieurs fichiers
- Modification coordonnée (2-5 fichiers)
- Validation sans commit

**Type C - Diagnostic cross-système :**
- Comparaison de workflows/fichiers
- Identification d'incohérences
- Rapport structuré

### Déclenchement d'Escalade

| Situation | Action |
|-----------|--------|
| `[TASK]` avec tag `[COMPLEX]` | Escalade vers orchestrator-complex (démarrage direct) |
| Échec 1x en -simple | **Escalade IMMEDIATE vers -complex** |
| 3+ actions ou dépendances | Escalade vers orchestrator-complex |

### Métriques de Validation

| Métrique | Méthode | Cible |
|----------|---------|-------|
| Escalades observées | Traces Roo ui_messages.json | ≥ 1 |
| Succès après escalade | INTERCOM + traces | > 80% |
| Résultats exploitables | Analyse humaine | 3/3 tâches |

**Documentation complète :** `.claude/memory/issue-545-escalation-observation-plan.md`
