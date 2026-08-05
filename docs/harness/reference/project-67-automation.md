# Project #67 — automatisation, champs, réconciliation

**Déporté de** `.claude/rules/issue-creation.md` (v1.0.0) le 2026-08-05.
**Issue :** #1835

La règle auto-chargée garde l'invariant (toute issue va dans le Project #67, et c'est automatique).
Ce qui suit est de l'outillage : on le lit quand l'automatisation tombe en panne ou qu'on doit
renseigner des champs à la main.

---

## Automatisation — `.github/workflows/sync-project.yml`

| Déclencheur | Effet |
|---|---|
| `issues.opened` | l'issue est ajoutée au Project #67 |
| `pull_request.opened` | la PR est ajoutée au Project #67 |
| cron `06:17 UTC` | réconciliation quotidienne : toute issue ouverte sans item Project est ajoutée |

Project #67 = `PVT_kwHOADA1Xc4BLw3w` — https://github.com/users/jsboige/projects/67

## Prérequis

### Secret GitHub Actions `PROJECT_TOKEN`

PAT (classic ou fine-grained) avec les scopes **`project`** (lire/écrire les projets),
**`read:org`** (projets d'organisation, si applicable), **`repo`** (issues/PRs si privé).

```bash
gh secret set PROJECT_TOKEN -R jsboige/roo-extensions   # valeur en --body direct, jamais via pipe
gh secret list -R jsboige/roo-extensions                # doit afficher PROJECT_TOKEN
```

> **Avant de conclure « le PAT est mort »** : un quota GraphQL épuisé produit exactement les mêmes
> symptômes qu'un token invalide. Trancher avec `gh api rate_limit` d'abord.

### Token local des agents

```bash
gh auth refresh -s project    # le scope `project` est requis côté agent aussi
```

## Vérification et réconciliation manuelle

```powershell
./scripts/github/sync-issues-to-project.ps1 -DryRun    # lister les orphelines
./scripts/github/sync-issues-to-project.ps1 -Execute   # toutes les ajouter
```

```bash
# ajouter une issue précise
gh project item-add PVT_kwHOADA1Xc4BLw3w --owner jsboige \
  --url https://github.com/jsboige/roo-extensions/issues/N
```

## Champs du Project #67

| Champ | Field ID | Options |
|-------|----------|---------|
| Status | `PVTSSF_lAHOADA1Xc4BLw3wzg7PYHY` | Todo, In Progress, Done |
| Machine | `PVTSSF_lAHOADA1Xc4BLw3wzg9nHu8` | ai-01, po-2023..2026, web1, All, Any |
| Agent | `PVTSSF_lAHOADA1Xc4BLw3wzg9icmA` | Roo, Claude, Both |
| Model | `PVTSSF_lAHOADA1Xc4BLw3wzg-jMsU` | haiku, sonnet, opus |
| Execution | `PVTSSF_lAHOADA1Xc4BLw3wzg-jMss` | interactive, scheduled, both |

Script d'écriture : `scripts/github/set-project-fields.ps1`.

## Widget dashboard — détection des orphelines

Le méta-analyste compte les issues hors Project ; **> 5 déclenche une investigation** :

```powershell
./scripts/github/sync-issues-to-project.ps1 -DryRun 2>&1 | Select-String "missing"
```

Au-delà du seuil : poster `[WARN]` sur le dashboard workspace avec le compte et la suggestion de
réconciliation manuelle.
