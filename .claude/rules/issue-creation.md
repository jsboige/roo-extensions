# Issue Creation — Auto-Project #67 Assignment

**Version:** 1.0.0
**Issue :** #1835
**MAJ :** 2026-05-03

---

## Regle Absolue

**Toute issue creee DOIT etre ajoutee au Project #67 (`PVT_kwHOADA1Xc4BLw3w`).**

## Automatisation

Le workflow `.github/workflows/sync-project.yml` ajoute automatiquement :
- **Nouvelles issues** (`issues.opened`) → ajoutees au Project #67
- **Nouvelles PRs** (`pull_request.opened`) → ajoutees au Project #67
- **Reconciliation quotidienne** (cron 06:17 UTC) → toute issue ouverte sans Project item est ajoutee

## Prerequis

### Secret GitHub Actions : `PROJECT_TOKEN`

Le workflow necessite un Personal Access Token (classic ou fine-grained) avec les scopes :
- **`project`** — lire/ecrire les projets
- **`read:org`** — acceder aux projets organisation (si applicable)
- **`repo`** — lire les issues/PRs (si private)

**Configuration :**
```bash
gh secret set PROJECT_TOKEN -R jsboige/roo-extensions
# Coller le token quand prompt
```

**Verification :**
```bash
gh secret list -R jsboige/roo-extensions
# Doit afficher PROJECT_TOKEN
```

### Token local (agents)

Le token local `gh auth` doit avoir le scope `project` :
```bash
gh auth refresh -s project
```

## Verification manuelle

Si le workflow echoue ou pour verifier manuellement :

```bash
# Lister les issues orphelines (pas dans le Project)
./scripts/github/sync-issues-to-project.ps1 -DryRun

# Ajouter toutes les orphelines
./scripts/github/sync-issues-to-project.ps1 -Execute

# Ajouter une issue specifique
gh project item-add PVT_kwHOADA1Xc4BLw3w --owner jsboige --url https://github.com/jsboige/roo-extensions/issues/N
```

## Champs Project #67

| Champ | Field ID | Options |
|-------|----------|---------|
| Status | `PVTSSF_lAHOADA1Xc4BLw3wzg7PYHY` | Todo, In Progress, Done |
| Machine | `PVTSSF_lAHOADA1Xc4BLw3wzg9nHu8` | ai-01, po-2023..2026, web1, All, Any |
| Agent | `PVTSSF_lAHOADA1Xc4BLw3wzg9icmA` | Roo, Claude, Both |
| Model | `PVTSSF_lAHOADA1Xc4BLw3wzg-jMsU` | haiku, sonnet, opus |
| Execution | `PVTSSF_lAHOADA1Xc4BLw3wzg-jMss` | interactive, scheduled, both |

## Dashboard widget — Orphan Detection

Le meta-analyste doit verifier les issues orphelines (>5 = trigger investigation) :

```powershell
# Compter les orphelines
./scripts/github/sync-issues-to-project.ps1 -DryRun 2>&1 | Select-String "missing"
```

Si > 5 orphelines detectees → poster `[WARN]` sur dashboard workspace avec le count et suggestion de reconciliation manuelle.

---

**Reference :** Issue #1835, scripts `sync-issues-to-project.ps1`, `set-project-fields.ps1`
