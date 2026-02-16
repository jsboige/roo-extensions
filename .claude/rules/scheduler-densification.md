# Règle de Densification Scheduler Roo

## Objectif

Remplir les itérations planifiées du scheduler Roo avec du travail jusqu'à atteindre l'état IDLE (plus rien à faire), tout en trouvant le **sweet spot** d'escalade.

## Sweet Spot d'Escalade

**Définition :** Escalader vers `-complex` **AVANT** l'échec, pas après.

| Situation | Action |
|-----------|--------|
| Tâche simple réussie | Continuer en `-simple` |
| Tâche simple échoue 1x | Réessayer avec instructions corrigées |
| Tâche simple échoue 2x | Escalader vers `-complex` |
| Tâche moyenne (3+ fichiers) | Démarrer directement en `-complex` si taux succès > 80% |

**Anti-pattern :** Laisser une tâche échouer 3-4 fois en `-simple` avant d'escalader.

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

## Workflow d'Ajustement

1. **Lire les traces Roo** via `task_browse` et `view_conversation_tree`
2. **Calculer les métriques** sur les 3-5 derniers cycles
3. **Ajuster via INTERCOM** avec message `[FEEDBACK]`
4. **Si structural** : modifier `.roo/scheduler-workflow-executor.md`

## Références

- Commands : `/coordinate` (myia-ai-01), `/executor` (autres machines)
- Workflow Roo : `.roo/scheduler-workflow-executor.md`
- Traces : `task_browse(action: "tree")` + `view_conversation_tree()`
