# Plan de Test Pilote - Scheduler Claude Code

**Issue:** #487 Phase 4
**Date:** 2026-02-19
**Machine Pilote:** myia-po-2026
**Statut:** EN COURS

---

## Timeline Réelle

| Phase | Statut | Date |
|-------|--------|------|
| Phase 1-3: Audit, Design, Docs | ✅ FAIT | 18/02 |
| Phase 4: Test Pilote | 🔄 EN COURS | 19-21/02 |
| Décision GO/NO-GO | ⏳ À FAIRE | 21/02 |

---

## Ce Qui Reste à Faire (19-21/02)

### Jour 1 (19/02 - Aujourd'hui) : Validation Infrastructure
| Test | Commande | Statut |
|------|----------|--------|
| Git sync | `git pull` | ✅ OK |
| Build | `npm run build` | À tester |
| Tests | `npx vitest run` | ✅ 3305 PASS |
| Scheduler actif | Vérifier `.roo/schedules.json` | À vérifier |

### Jour 2 (20/02) : Tests Tâches Simples
Lancer 3 cycles scheduler et observer:
- `git-sync-simple` → Pull réussi ?
- `validate-build` → Build OK ?
- `run-tests` → Tests pass ?

**Critère:** 2/3 tâches réussies sans intervention

### Jour 3 (21/02) : Test Escalade + Décision
- Lancer 1 tâche qui nécessite escalade (simple → complex)
- Vérifier que l'escalade fonctionne
- Décision GO/NO-GO pour déploiement multi-machines

---

## Critères de Succès (Simplifiés)

| Critère | Seuil | Validation |
|---------|-------|------------|
| Cycles autonomes | ≥3 | Sans intervention |
| Taux succès simple | >66% | 2/3 tâches |
| Pas de perte données | 0 conflit non résolu | Git propre |
| Escalade fonctionne | Au moins 1 testée | Simple→Complex |

---

## Procédures d'Urgence

### Rollback
```powershell
.\roo-config\scheduler\scripts\install\deploy-scheduler.ps1 -Action disable
```

### Conflit Git
1. Ne PAS forcer
2. Signaler INTERCOM: `[ERROR] Conflit git`
3. Escalader vers Claude manuel

---

## Décision GO/NO-GO (21/02)

**GO si:**
- ✅ 3+ cycles sans intervention
- ✅ ≥2/3 tâches simples réussies
- ✅ Zéro conflit non résolu

**NO-GO si:**
- ❌ Moins de 2 cycles complétés
- ❌ Taux succès <50%
- ❌ Perte de données

---

## Références

- Design: `docs/architecture/scheduler-claude-code-design.md`
- Audit: `docs/architecture/scheduler-audit-myia-po-2026.md`
- Déploiement: `docs/architecture/scheduler-pilot-deployment-guide.md`

---

**Next Step:** Vérifier état scheduler sur myia-po-2026 + lancer tests.
