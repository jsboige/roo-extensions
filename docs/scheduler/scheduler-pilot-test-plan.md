# Plan de Test Pilote - Scheduler Claude Code

**Issue:** #487 Phase 4
**Date:** 2026-02-19
**Durée:** 3 semaines (17/02 - 07/03/2026)
**Machine Pilote:** myia-po-2026

---

## Objectifs

Valider le scheduler Claude Code en conditions réelles avant déploiement multi-machines.

**Critères de succès:**
- [ ] 10+ cycles complets sans intervention manuelle
- [ ] Taux de succès > 80% sur tâches `-simple`
- [ ] Taux de succès > 60% sur tâches `-complex`
- [ ] Zéro perte de données (conflits git résolus)
- [ ] Escalades fonctionnelles (simple → complex → Claude)

---

## Semaine 1 : Infrastructure (17-23/02)

### Jour 1-2 : Setup Initial
| Tâche | Responsable | Validation |
|-------|-------------|------------|
| Installer Ralph Wiggum | Claude (pilote) | `claude plugin list` |
| Créer scheduler-config.json | Claude (pilote) | Fichier présent |
| Créer scheduler-queue.json | Claude (pilote) | Fichier présent |
| Configurer worktree | Claude (pilote) | `git worktree list` |

### Jour 3-5 : Tests Basiques
| Test | Commande | Résultat Attendu |
|------|----------|------------------|
| Git sync | `git pull` dans worktree | Aucun conflit |
| Build | `npm run build` | Exit 0 |
| Tests | `npx vitest run` | >99% pass |
| Locking | `acquire-lock.ps1` | Lock créé/libéré |

**Checkpointer:** Si tous tests basiques passent → Semaine 2

---

## Semaine 2 : Tâches Simples (24/02 - 02/03)

### Configuration
```json
{
  "mode": "simple",
  "interval": 180,
  "maxTasks": 5,
  "taskTypes": ["git-sync", "build", "tests", "cleanup", "docs"]
}
```

### Tests Quotidiens
| Jour | Tâche Assignée | Critère Succès |
|------|----------------|----------------|
| Lundi | `git-sync-simple` | Pull réussi, statut propre |
| Mardi | `validate-build` | Build OK, 0 erreurs |
| Mercredi | `run-tests` | >99% tests pass |
| Jeudi | `cleanup-branches` | Branches mergées supprimées |
| Vendredi | `update-docs` | CLAUDE.md mis à jour |

### Métriques à Collecter
- Temps d'exécution par tâche
- Nombre de tentatives avant succès
- Escalades déclenchées
- Erreurs rencontrées

**Escalade:** Si < 80% succès → analyser logs, ajuster, réessayer

---

## Semaine 3 : Tâches Complexes (03-07/03)

### Configuration
```json
{
  "mode": "complex",
  "interval": 180,
  "maxTasks": 3,
  "taskTypes": ["investigation", "bugfix", "refactor", "feature"]
}
```

### Tests de Monteé en Charge
| Jour | Tâche Assignée | Complexité | Critère Succès |
|------|----------------|------------|----------------|
| Lundi | Investigation bug simple | 1/5 | Cause identifiée |
| Mardi | Fix bug simple | 2/5 | Tests pass, PR créée |
| Mercredi | Refactoring mineur | 2/5 | Code propre, tests pass |
| Jeudi | Feature simple | 3/5 | Implémentée, documentée |
| Vendredi | Test intégration | 4/5 | Scénario complet OK |

### Validation Finale
- [ ] Review des métriques (Semaine 1-3)
- [ ] Analyse des échecs (patterns récurrents?)
- [ ] Ajustements de la configuration
- [ ] Rédaction du rapport de pilotage
- [ ] Décision GO/NO-GO pour déploiement multi-machines

---

## Procédures d'Urgence

### Rollback Immédiat
```powershell
# Désactiver scheduler
.\roo-config\scheduler\scripts\install\deploy-scheduler.ps1 -Action disable

# Supprimer worktree
git worktree remove .worktrees/scheduler

# Nettoyer locks
Remove-Item .claude/scheduler/locks/* -Force
```

### Conflit Git Non Résolu
1. Ne PAS forcer
2. Laisser le worktree en l'état
3. Signaler via INTERCOM: `[ERROR] Conflit git non résolu`
4. Escalader vers Claude Code manuel

### Perte de Connexion API
1. Scheduler attend automatiquement (retry avec backoff)
2. Si > 3 échecs consécutifs → pause 1h
3. Signaler dans INTERCOM: `[WARN] API unreachable`

---

## Rapport de Pilotage

À compléter à la fin de chaque semaine:

```markdown
## Semaine X - Rapport

**Période:** DD/MM - DD/MM
**Tâches tentées:** X
**Tâches réussies:** Y (Z%)
**Escalades:** E
**Erreurs:** L

### Analyse
- [Points positifs]
- [Points à améliorer]

### Actions
- [Actions pour semaine suivante]
```

---

## Références

- Guide déploiement: `docs/architecture/scheduler-pilot-deployment-guide.md`
- Design: `docs/architecture/scheduler-claude-code-design.md`
- Audit: `docs/architecture/scheduler-audit-myia-po-2026.md`

---

**Next Step:** Confirmer machine pilote (myia-po-2026?) et démarrer Semaine 1.
