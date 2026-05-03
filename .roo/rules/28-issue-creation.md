# Issue Creation — Auto-Project #67 Assignment (Roo)

**Version:** 1.0.0
**Issue :** #1835
**MAJ :** 2026-05-03

## Regle

**Toute issue creee par un agent Roo DOIT etre ajoutee au Project #67.**

## Automatisation

Le workflow CI `.github/workflows/sync-project.yml` gere l'ajout automatique :
- `issues.opened` → auto-add au Project #67
- `pull_request.opened` → auto-add au Project #67
- Cron quotidien 06:17 UTC → reconciliation des orphelines

## Prerequis : Secret `PROJECT_TOKEN`

Le workflow CI necessite un secret `PROJECT_TOKEN` (PAT avec scopes `project`, `repo`, `read:org`).

**Verification :**
```powershell
gh secret list -R jsboige/roo-extensions
```

Si absent → signaler `[CRITICAL]` sur dashboard. Ne PAS tenter de creer le secret (necessite intervention humaine).

## Actions agents Roo

### Apres creation d'issue

Verifier que l'issue est dans le Project (si le workflow CI est actif, c'est automatique) :

```powershell
gh project item-list 67 --owner jsboige --format json --limit 500 | ConvertFrom-Json | ForEach-Object { $_.items } | Where-Object { $_.content.url -match "/issues/N$" }
```

### Si CI inactive (fallback manuel)

```powershell
gh project item-add PVT_kwHOADA1Xc4BLw3w --owner jsboige --url "https://github.com/jsboige/roo-extensions/issues/N"
```

## Dashboard widget — Orphan Detection

Le meta-analyste (cycle 72h) DOIT verifier les orphelines :

```powershell
./scripts/github/sync-issues-to-project.ps1 -DryRun 2>&1 | Select-String "missing"
```

Si > 5 orphelines → poster `[WARN]` sur dashboard workspace.

## Champs Project #67

| Champ | Options |
|-------|---------|
| Status | Todo, In Progress, Done |
| Machine | ai-01, po-2023..2026, web1, All, Any |
| Agent | Roo, Claude, Both |
| Execution | interactive, scheduled, both |

---

**Reference :** `.claude/rules/issue-creation.md`, Issue #1835
