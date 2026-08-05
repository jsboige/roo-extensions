# Création d'issues — rattachement au Project #67

**Version:** 2.0.0 (slim — outillage déporté 2026-08-05)
**Issue :** #1835

---

## Règle absolue

**Toute issue créée doit se retrouver dans le Project #67** (`PVT_kwHOADA1Xc4BLw3w`).

**C'est automatique** : `.github/workflows/sync-project.yml` rattache les issues et PRs à
l'ouverture, et réconcilie chaque jour les orphelines (cron 06:17 UTC). **Ne pas rattacher à la
main par défaut** — le faire seulement quand on a constaté que l'automatisation a échoué.

## Rappel de gating

Créer une issue GitHub **exige la validation explicite de l'utilisateur**. Le rattachement au
Project est automatique ; la décision d'ouvrir l'issue ne l'est pas.

---

**Workflow, secret `PROJECT_TOKEN`, scopes, réconciliation manuelle, Field IDs, widget orphelines :**
[`docs/harness/reference/project-67-automation.md`](../../docs/harness/reference/project-67-automation.md)
