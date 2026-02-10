# Scripts de Scheduling Claude Code

**Phase 1** - Implémentation de base (#414)
**Date:** 2026-02-11
**Statut:** ✅ Complété

---

## Vue d'Ensemble

Scripts PowerShell pour l'exécution automatisée de Claude Code avec :
- **Modes simple/complex** (Haiku → Sonnet/Opus)
- **Escalade automatique** (si tâche trop complexe)
- **Worktrees Git** (isolation des changements)
- **Logs détaillés** (.claude/logs/)

---

## Fichiers

| Script | Description | Usage |
|--------|-------------|-------|
| `start-claude-worker.ps1` | Worker générique avec modes + escalade | Manuel ou via scheduler |
| `sync-tour-scheduled.ps1` | Sync-tour automatisé (wrapper) | Task Scheduler / Cron |

---

## Configuration

### Modes Claude (.claude/modes/modes-config.json)

| Mode | Modèle | Coût/1M tokens | Usage |
|------|--------|----------------|-------|
| sync-simple | Haiku 4.5 | $0.25 | Sync basique |
| sync-complex | Sonnet 4.5 | $3.00 | Conflits, build |
| code-simple | Haiku 4.5 | $0.25 | <50 lignes |
| code-complex | Sonnet 4.5 | $3.00 | Refactoring |
| debug-simple | Haiku 4.5 | $0.25 | Bugs évidents |
| debug-complex | Sonnet 4.5 | $3.00 | Bugs complexes |
| coordinate-simple | Haiku 4.5 | $0.25 | Messages RooSync |
| coordinate-complex | Opus 4.6 | $15.00 | Planification |

**Escalade automatique :** Les modes simple escaladent vers complex si conditions remplies.

---

## Utilisation

### 1. Test Local (DryRun)

```powershell
# Test worker générique
.\start-claude-worker.ps1 -DryRun

# Test sync-tour automatisé
.\sync-tour-scheduled.ps1 -DryRun

# Test avec mode spécifique
.\sync-tour-scheduled.ps1 -Mode "sync-complex" -DryRun
```

### 2. Exécution Manuelle

```powershell
# Sync-tour en mode simple (défaut)
.\sync-tour-scheduled.ps1

# Worker avec tâche spécifique
.\start-claude-worker.ps1 -Mode "code-simple" -TaskId "msg-xyz"

# Avec worktree pour isolation
.\start-claude-worker.ps1 -UseWorktree
```

### 3. Planification Windows (Task Scheduler)

**Créer tâche quotidienne à 9h :**

```powershell
schtasks /create /tn "Claude Sync Tour" /tr "powershell.exe -ExecutionPolicy Bypass -File C:\dev\roo-extensions\scripts\scheduling\sync-tour-scheduled.ps1" /sc daily /st 09:00
```

**Créer tâche toutes les 3h :**

```powershell
schtasks /create /tn "Claude Sync Tour 3h" /tr "powershell.exe -ExecutionPolicy Bypass -File C:\dev\roo-extensions\scripts\scheduling\sync-tour-scheduled.ps1" /sc hourly /mo 3
```

**Vérifier tâche :**

```powershell
schtasks /query /tn "Claude Sync Tour" /v
```

### 4. Planification Linux/macOS (Cron)

```bash
# Éditer crontab
crontab -e

# Sync-tour quotidien à 9h
0 9 * * * cd /path/to/roo-extensions && pwsh -File scripts/scheduling/sync-tour-scheduled.ps1

# Sync-tour toutes les 3h
0 */3 * * * cd /path/to/roo-extensions && pwsh -File scripts/scheduling/sync-tour-scheduled.ps1
```

---

## Logs

Tous les logs sont dans `.claude/logs/` :

```
.claude/logs/
├── worker-20260211-003349.log          # Logs worker générique
├── sync-tour-scheduled-20260211-003356.log  # Logs sync-tour
└── escalation-20260211.log              # Logs d'escalade
```

**Consulter logs récents :**

```powershell
# 50 dernières lignes
Get-Content .claude/logs/worker-*.log -Tail 50

# Logs du jour
Get-ChildItem .claude/logs/ | Where-Object { $_.LastWriteTime -gt (Get-Date).Date }
```

---

## Workflow Escalade

### Exemple : Sync-Tour

```
┌─────────────────────┐
│ sync-simple (Haiku) │  git pull, check messages
│ Coût: ~$0.01        │  ✗ FAIL: Conflits git détectés
└──────────┬──────────┘
           │ ESCALADE (condition remplie)
           ▼
┌─────────────────────┐
│ sync-complex (Sonnet)│  Résout conflits, merge
│ Coût: ~$0.15         │  ✓ OK: Conflits résolus
└──────────────────────┘

Total: ~$0.16 (vs $0.15 si direct Sonnet)
Économie: ~$0 (mais si 80% des sync n'ont pas de conflits → économie 80%)
```

---

## Estimation Coûts

### Scénario Conservateur (5 machines)

| Activité | Freq/jour | Tokens/exec | Coût/jour | Coût/mois |
|----------|-----------|-------------|-----------|-----------|
| Sync simple (no escalade) | 8×5 | 10K @ $0.25 | $0.10 | $3.00 |
| Code simple (no escalade) | 10×5 | 10K @ $0.25 | $0.125 | $3.75 |
| Escalades complex | 2×5 | 20K @ $3.00 | $0.60 | $18.00 |
| **TOTAL** | - | 1.1M | **$0.825** | **~$25/mois** |

**vs. Sonnet partout :** ~$150/mois → **Économie : 83%**

---

## Prochaines Étapes

### Phase 2 : Ralph Wiggum (2-3 jours)

- [ ] Installer Ralph Wiggum plugin sur chaque machine
- [ ] Intégrer avec `start-claude-worker.ps1`
- [ ] Tester boucles autonomes sur CONS tasks

### Phase 3 : Coordinateur Central (1 semaine)

- [ ] GitHub Actions pour trigger centralisé
- [ ] Webhook sur push → distribution tâches
- [ ] Dashboard monitoring (optionnel)

---

## Références

- **Issue #414** : Stratégie scheduling Claude Code
- **Issue #387** : Modes SDDD simple/complex (Roo)
- [.claude/modes/README.md](../../.claude/modes/README.md) : Doc modes complète
- [docs/architecture/scheduling-claude-code.md](../../docs/architecture/scheduling-claude-code.md) : Investigation

---

**Auteur:** Claude Code (myia-po-2026)
**Version:** 1.0.0 (Phase 1)
**Licence:** Projet roo-extensions
