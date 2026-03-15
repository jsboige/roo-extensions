# Workflows Scheduler - Référence Unifiée

**Issue :** #689 - Unifier workflows scheduler
**Dernière mise à jour :** 2026-03-15
**Statut :** Documentation unifiée (scripts en cours de consolidation)

---

## Vue d'Ensemble : Architecture 3 Tiers × 2 Agents

Le système de scheduling est organisé en **3 tiers de fréquence** × **2 agents** (Roo + Claude) = **6 schedulers** au total.

| Tier | Fréquence | Machines | Agent Roo | Agent Claude |
|------|-----------|----------|-----------|--------------|
| **Executor** | 6h | Toutes | Roo Scheduler | Claude Worker |
| **Coordinator** | 6-12h | myia-ai-01 uniquement | (non prévu) | Claude Coordinator |
| **Meta-Analyst** | 72h | Toutes | Roo Meta | Claude Meta-Audit |

---

## Tier 1 : Executor (6h, toutes machines)

### Roo Executor

**Fichier workflow :** [`.roo/scheduler-workflow-executor.md`](../.roo/scheduler-workflow-executor.md)

**Configuration :** `.roo/schedules.json`
```json
{
  "timeInterval": 360,
  "startMinute": 30
}
```

**Pre-flight check :** Tester win-cli (STOP si absent)

```
execute_command(shell="powershell", command="echo OK")
# Si STOP → [CRITICAL] dans INTERCOM
```

**Résumé workflow :**
1. Lire INTERCOM (messages Roo < 24h, tags [SCHEDULED], [TASK], [URGENT])
2. Vérifier workspace (git status)
3. **Pre-flight** : Tester win-cli
4. Sélectionner tâche (RooSync inbox → GitHub Issues → Maintenance)
5. Exécuter via `new_task` (JAMAIS directement)
6. Reporter dans INTERCOM (PAS roosync_send pour communication locale)
7. **Lecture résultats** (obligatoire même si 0 issues trouvées)

**Grille horaire (anti-collision) :**

| Machine | Executor 6h (startMinute) |
|---------|--------------------------|
| myia-ai-01 | :00 |
| myia-po-2023 | :30 |
| myia-po-2024 | :00 |
| myia-po-2025 | :30 |
| myia-po-2026 | :00 |
| myia-web1 | :30 |

---

### Claude Worker

**Script :** [`scripts/scheduling/start-claude-worker.ps1`](../scripts/scheduling/start-claude-worker.ps1)

**Configuration :** Schtask Windows `Claude-Worker` (installé via `setup-scheduler.ps1`)
```powershell
# Installer
.\scripts\scheduling\setup-scheduler.ps1 -Action install -TaskType worker

# Vérifier statut
schtasks /Query /TN "Claude-Worker" /FO LIST
```

**Paramètres par défaut :**
- Intervalle : 6h
- Modèle : haiku (escalade auto : haiku → sonnet → opus)
- Timeout : 30min

**Pre-flight check :** Vérifier roo-state-manager disponible via system-reminders.

**Résumé workflow (/executor command) :**
1. Phase 0 : Vérifier MCPs critiques (roo-state-manager)
2. Phase 1 : Collecte rapide (git, INTERCOM, RooSync, GitHub)
3. Phase 1.5 : Audit traces scheduler Roo
4. Phase 2 : Sélection tâche (RooSync → GitHub → maintenance)
5. Phase 3 : Exécution + validation + commit
6. Phase 3g : Retour en Phase 2 (boucle 2-3 tâches/session)

---

## Tier 2 : Coordinator (6-12h, myia-ai-01 uniquement)

### Claude Coordinator

**Script :** [`scripts/scheduling/start-claude-coordinator.ps1`](../scripts/scheduling/start-claude-coordinator.ps1)

**Configuration :** Schtask Windows `Claude-Coordinator`
```powershell
# Installer
.\scripts\scheduling\setup-scheduler.ps1 -Action install -TaskType coordinator
```

**Fichier workflow :** [`.roo/scheduler-workflow-coordinator.md`](../.roo/scheduler-workflow-coordinator.md)

**Résumé workflow :**
1. Pre-flight : Tester win-cli
2. Lire INTERCOM (tags [DONE], [WAKE-CLAUDE], [PATROL], [FRICTION-FOUND])
3. Analyser activité cross-machine (RooSync, git log, GitHub Project #67)
4. Dispatcher tâches via RooSync
5. Écrire rapport coordination dans INTERCOM `[COORDINATION]`

---

## Tier 3 : Meta-Analyst (72h, toutes machines)

### Roo Meta-Analyst

**Fichier workflow :** [`.roo/scheduler-workflow-meta-analyst.md`](../.roo/scheduler-workflow-meta-analyst.md)

**Configuration :** `.roo/schedules.json`
```json
{
  "timeInterval": 4320,
  "startMinute": 45
}
```

**Pre-flight check :** Tester win-cli (STOP si absent)

**Grille horaire (anti-collision) :**

| Machine | Meta 72h (startMinute) |
|---------|------------------------|
| myia-ai-01 | :15 |
| myia-po-2023 | :25 |
| myia-po-2024 | :35 |
| myia-po-2025 | :45 |
| myia-po-2026 | :55 |
| myia-web1 | :05 |

---

### Claude Meta-Audit

**Script :** [`scripts/scheduling/start-meta-audit.ps1`](../scripts/scheduling/start-meta-audit.ps1)

**Configuration :** Schtask Windows `Claude-Meta-Audit`
```powershell
# Installer
.\scripts\scheduling\setup-scheduler.ps1 -Action install -TaskType meta
```

---

## Pre-Flight Check Standardisé

### Roo (tous tiers)

Le pre-flight est identique dans les 3 workflows Roo :

```
Tâche déléguée à code-simple :
  execute_command(shell="powershell", command="echo OK")

Si STOP (échec win-cli) :
  → Écrire dans INTERCOM [CRITICAL] : win-cli MCP non disponible
  → Terminer le cycle immédiatement
  → Pas de contournement possible (modes -simple n'ont pas de terminal natif)
```

**Références :**
- Executor : lignes 153-169
- Coordinator : lignes 44-57
- Meta-analyst : lignes 27-35

### Claude (Worker/Coordinator)

```
Phase 0 (avant tout travail) :
1. Vérifier les system-reminders au démarrage
2. roo-state-manager attendu → 37 outils
3. Si absent → STOP & REPAIR immédiat
   a. roosync_mcp_management(subAction: "read")
   b. Corriger config ~/.claude.json si possible
   c. Envoyer message URGENT via RooSync au coordinateur
   d. Documenter dans INTERCOM [CRITICAL]
```

**Référence :** [`.claude/rules/tool-availability.md`](../.claude/rules/tool-availability.md)

---

## Système de Logging

### Roo : Traces dans APPDATA

```
%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks\{TASK_ID}\
  ├── api_conversation_history.json  # Historique complet
  ├── task_metadata.json             # Métadonnées (pas de tokens)
  └── ui_messages.json               # Messages condensés
```

**Consultation via MCP :**
```
conversation_browser(action: "list", limit: 20, sortBy: "lastActivity")
conversation_browser(action: "view", task_id: "...", detail_level: "summary", smart_truncation: true)
```

### Claude : JSONL dans ~/.claude/projects/

```
~/.claude/projects/{workspace-hash}/*.jsonl
```

**Analyse token usage :** `node scripts/monitoring/token-usage-report.js --days 7`

### INTERCOM : Communication locale

```
.claude/local/INTERCOM-{MACHINE_NAME}.md
```

Tags importants : `[DONE]`, `[CRITICAL]`, `[SCHEDULED]`, `[TASK]`, `[COORDINATION]`, `[FEEDBACK]`

---

## Escalade Automatique

### Roo

```
orchestrator-simple
  → code-simple (lecture, git, doc)
  → code-complex (écriture code, tests)
  → debug-complex (investigation bugs)

Seuil d'escalade :
  - Taux succès -simple > 90% → continuer en -simple mais tâches + complexes
  - Taux succès -simple < 80% → corriger workflow
  - Échec 2x en -simple → escalader vers -complex
```

**Référence :** [`docs/roo-code/SCHEDULER_DENSIFICATION.md`](../docs/roo-code/SCHEDULER_DENSIFICATION.md) (non existant - à créer)
**Voir :** [`.claude/rules/scheduler-densification.md`](../.claude/rules/scheduler-densification.md)

### Claude

```
Modèle par défaut : haiku
Escalade automatique : haiku → sonnet → opus
Critères :
  - Tâche complexe identifiée
  - Échec du modèle actuel
  - Tâche > 2h (ask user)
```

---

## Déploiement par Machine

### 1. Roo Scheduler

```powershell
# Déployer schedules.json (depuis template)
.\roo-config\scheduler\scripts\install\deploy-scheduler.ps1 -Action deploy

# Vérifier statut
.\roo-config\scheduler\scripts\install\deploy-scheduler.ps1 -Action status

# Désactiver
.\roo-config\scheduler\scripts\install\deploy-scheduler.ps1 -Action disable
```

**⚠️ Redémarrer VS Code** après déploiement (le scheduler cache la config au démarrage).

### 2. Claude Schtasks

```powershell
# Installer les 3 schtasks
.\scripts\scheduling\setup-scheduler.ps1 -Action install -TaskType worker
.\scripts\scheduling\setup-scheduler.ps1 -Action install -TaskType coordinator  # ai-01 uniquement
.\scripts\scheduling\setup-scheduler.ps1 -Action install -TaskType meta

# Vérifier
schtasks /Query /TN "Claude-Worker" /FO LIST
schtasks /Query /TN "Claude-Coordinator" /FO LIST  # ai-01 uniquement
schtasks /Query /TN "Claude-Meta-Audit" /FO LIST

# Désactiver
schtasks /Change /TN "Claude-Worker" /DISABLE
```

---

## Statut par Machine (#678)

| Machine | Roo Executor 6h | Roo Meta 72h | Claude Worker | Claude Meta |
|---------|-----------------|--------------|---------------|-------------|
| myia-ai-01 | ⬜ | ⬜ | ⬜ | ⬜ |
| myia-po-2023 | ⬜ | ⬜ | ⬜ | ⬜ |
| myia-po-2024 | ⬜ | ⬜ | ⬜ | ⬜ |
| myia-po-2025 | ✅ | ✅ | ✅ | ✅ |
| myia-po-2026 | ⬜ | ⬜ | ⬜ | ⬜ |
| myia-web1 | ⬜ | ⬜ | ⬜ | ⬜ |

*(Mettre à jour au fur et à mesure du déploiement)*

---

## Références

| Fichier | Contenu |
|---------|---------|
| [`.roo/scheduler-workflow-executor.md`](../.roo/scheduler-workflow-executor.md) | Workflow exécutant Roo |
| [`.roo/scheduler-workflow-coordinator.md`](../.roo/scheduler-workflow-coordinator.md) | Workflow coordinateur Roo |
| [`.roo/scheduler-workflow-meta-analyst.md`](../.roo/scheduler-workflow-meta-analyst.md) | Workflow méta-analyste Roo |
| [`.roo/schedules.json`](../.roo/schedules.json) | Config scheduler Roo (machine-specific) |
| [`scripts/scheduling/`](../scripts/scheduling/) | Scripts Claude Worker/Coordinator |
| [`docs/roo-code/SCHEDULER_SYSTEM.md`](roo-code/SCHEDULER_SYSTEM.md) | Référence technique Roo |
| [`.claude/rules/scheduler-densification.md`](../.claude/rules/scheduler-densification.md) | Règles densification |
| [`.claude/rules/scheduler-system.md`](../.claude/rules/scheduler-system.md) | Système scheduler (règles) |
| [`docs/mcp-configuration.md`](mcp-configuration.md) | Configuration MCP win-cli |
