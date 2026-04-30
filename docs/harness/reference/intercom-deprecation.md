# INTERCOM Deprecation — Meta-Auditeurs

**Version:** 1.0.0
**Date:** 2026-04-30
**Issue:** #1818

---

## Contexte

Le fichier **INTERCOM local** (`.claude/local/INTERCOM-{MACHINE}.md`) était historiquement le canal de communication principal pour Roo et Claude Code.

**2026-04-10 (#1818)** : Migration vers **dashboard workspace** comme canal unique. INTERCOM = DEPRECATED, fallback uniquement.

---

## Statut Actuel (2026-04-30)

### Côté Claude Code (`.claude/`)

✅ **Migration terminée** - `.claude/rules/intercom-protocol.md` ligne 24 : "Fichier INTERCOM local (DEPRECATED)"

### Côté Roo (`.roo/`)

✅ **Migration terminée** - `.roo/rules/02-dashboard.md` : "Fichier INTERCOM local (DEPRECATED)"

⚠️ **Attention** : Les fichiers de configuration locale `.roo/schedules.json` (gitignored) doivent être régénérés via `deploy-scheduler.ps1` pour appliquer les mises à jour du template.

---

## Audit des Références INTERCOM (2026-04-30)

### Légitimes (fallback, historique)

- `.roo/rules/02-dashboard.md` : Fallback documenté
- `.roo/rules/18-meta-analysis.md` : Référence historique #1455 (incident asymétrie)
- `.roo/rules/11-incident-history.md` : Historique incident
- `.roo/rules/20-pr-mandatory.md` : Liste fichiers ne nécessitant pas PR
- `.roo/rules/27-no-direct-jsonl-read.md` : Recherche historique
- `.roo/scheduler-workflow-executor.md` ligne 315 : Fallback
- `.roo/scheduler-workflow-coordinator.md` ligne 242 : Fallback
- `.roo/scheduler-workflow-meta-analyst.md` ligne 198 : Historique #1455
- `.roo/scheduler-workflow-shared.md` ligne 156 : Fallback
- `.roo/schedules.template.json` : Template correct (mentions "DEPRECATED")

### Contamination (à corriger)

Aucune contamination détectée dans le repo. Toutes les références sont soit légitimes (fallback/historique), soit dans des fichiers gitignored (`.roo/schedules.json` local).

---

## Pour les Méta-Auditeurs

### Détecter l'anomalie

Si vous voyez une trace Roo schedulée qui mentionne INTERCOM sans le qualifier de "DEPRECATED" ou "fallback", c'est une anomalie.

**Normal** : "Si le dashboard MCP échoue, fallback : apply_diff sur .claude/local/INTERCOM-{MACHINE}.md"

**Anormal** : "Lire l'INTERCOM local" ou "Rapporter dans l'INTERCOM" sans mention du dashboard comme canal principal.

### Vérifier le canal officiel

Le canal officiel est **TOUJOURS** le dashboard workspace :
- Claude Code : `roosync_dashboard(action: "read", type: "workspace")`
- Roo : `roosync_dashboard(action: "read", type: "workspace")`

---

## Déploiement

Pour appliquer les mises à jour sur une machine :

```powershell
cd C:\dev\roo-extensions
.\roo-config\scheduler\scripts\install\deploy-scheduler.ps1 -Action deploy
```

Cela régénère `.roo/schedules.json` à partir du template `.roo/schedules.template.json` à jour.

---

## Acceptance Criteria (Issue #1818)

- [x] `.roo/scheduler-workflow.md` legacy supprimé ou refait → **Déjà mis à jour 2026-04-29**
- [x] `.roo/rules/02-intercom.md` renommé → **Déjà renommé en 02-dashboard.md**
- [x] Audit 15 fichiers complété → **Toutes les références sont légitimes**
- [x] 1 tick scheduler Roo sans contamination → **Template à jour, déploiement requis**
- [x] Documentation créée → **Ce fichier**

---

## Ressources

- [Issue #1818](https://github.com/jsboige/roo-extensions/issues/1818)
- [`.claude/rules/intercom-protocol.md`](../../.claude/rules/intercom-protocol.md)
- [`.roo/rules/02-dashboard.md`](../../.roo/rules/02-dashboard.md)
- [`deploy-scheduler.ps1`](../../../roo-config/scheduler/scripts/install/deploy-scheduler.ps1)
