# Architecture du Scheduler Claude Code

**Document créé:** 2026-02-18
**Auteur:** Claude Code (myia-po-2025)
**Issue:** #487 Phase 3
**Script:** `scripts/scheduling/start-claude-worker.ps1` (1313 lignes)

---

## Vue d'ensemble

Le Scheduler Claude Code est un système autonome qui permet à Claude Code de s'exécuter de manière planifiée sans intervention utilisateur directe. Il s'appuie sur le pattern **Ralph Wiggum Loop** pour l'itération continue et le système **Wait State** pour la reprise après événements externes.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    PHASE 0: Wait State Resume                    │
│         (Priorité maximale - reprend tâches en attente)          │
└───────────────────────────┬─────────────────────────────────────┘
                            │ Pas de wait state
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    PHASE 1: Task Fetching                        │
│        Système hybride à 3 priorités (RooSync → GitHub → Fallback)│
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    PHASE 2: Mode Selection                       │
│              (Restauré si reprise, sinon auto-détecté)           │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                 RALPH WIGGUM LOOP                                │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐                     │
│  │  GATHER  │ → │  ACTION  │ → │  VERIFY  │ → Répéter           │
│  └──────────┘   └──────────┘   └──────────┘                     │
│       │                               │                          │
│       └─────────── Signaling ─────────┘                          │
│           (continue|escalate|wait|success|failure)               │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    REPORTING                                     │
│        (RooSync message + GitHub comment + Cleanup)              │
└─────────────────────────────────────────────────────────────────┘
```

---

## Composants

### 1. Task Fetching Hybride (Phase 1)

**Source:** `Get-NextTask` (lignes 116-149)

Le système récupère les tâches selon 3 priorités :

| Priorité | Source | Condition | Format |
|----------|--------|-----------|--------|
| 1 | RooSync inbox | Messages `to: machineId` ou `to: all` avec `status: unread` | JSON dans GDrive |
| 2 | GitHub issues | Label `roo-schedulable` + champ `Agent: Claude Code|Both|Any` | gh CLI |
| 3 | Fallback | Maintenance quotidienne | Build + tests |

**Code clé :**
```powershell
# Priorité 1: RooSync inbox
$RooSyncTask = Get-RooSyncTask -MachineId $MachineId

# Priorité 2: GitHub issues
$GitHubTask = Get-GitHubTask -AgentType $AgentType -MachineId $MachineId

# Priorité 3: Fallback maintenance
return Get-FallbackTask
```

### 2. Wait State Management (Phase 0 + TODO #5)

**Source:** `Save-WaitState`, `Test-WaitStateReady` (lignes 336-543)

Le système permet à un agent de signaler une attente et de reprendre automatiquement quand la condition est remplie.

**Structure d'un Wait State :**
```json
{
  "taskId": "msg-20260211-abc123",
  "timestamp": "2026-02-11T10:30:00Z",
  "reason": "Attente validation utilisateur",
  "waitFor": "User approval via INTERCOM",
  "resumeWhen": "user_approval",
  "context": {
    "mode": "code-complex",
    "model": "opus",
    "iteration": 3,
    "outputSnippet": "..."
  }
}
```

**4 Conditions de Reprise (resumeWhen) :**

| Condition | Vérification | Implémentation |
|-----------|-------------|----------------|
| `user_approval` | INTERCOM + GitHub comments | `Test-UserApproval` |
| `roosync_response` | Message dans inbox | `Test-RooSyncResponse` |
| `github_decision` | Changement statut issue | `Test-GitHubDecision` |
| `intercom_message` | Message local | `Test-IntercomMessage` |

**Workflow de reprise :**
```
1. Get-PendingWaitStates → Scan .claude/scheduler/wait-states/
2. Test-WaitStateReady → Vérifier condition resumeWhen
3. Build-ResumePrompt → Construire prompt enrichi
4. Invoke-Claude → Reprendre avec contexte restauré
5. Remove-WaitState → Cleanup après succès
```

### 3. Ralph Wiggum Loop (TODO #3)

**Source:** `Invoke-Claude` (lignes 800-1000)

Pattern d'itération continue : **Gather → Action → Verify → Repeat**

```
┌─────────────────────────────────────────────────────┐
│                 Ralph Wiggum Loop                   │
│                                                     │
│  While (iteration < max) {                          │
│      1. GATHER: Lire output précédent               │
│      2. ACTION: claude --dangerously-skip-permissions│
│      3. VERIFY: Parser signaux agent                │
│          - continue → continuer                     │
│          - escalate → escalader vers complex        │
│          - wait → sauvegarder wait state + arrêter  │
│          - success → arrêter (succès)               │
│          - failure → arrêter (échec)                │
│  }                                                  │
└─────────────────────────────────────────────────────┘
```

**Format de signal agent :**
```
=== AGENT STATUS ===
STATUS: <continue|escalate|wait|success|failure>
REASON: <description optionnelle>
ESCALATE_TO: <model> (optionnel, si escalate)
WAIT_FOR: <condition> (optionnel, si wait)
RESUME_WHEN: <condition> (optionnel, si wait)
===================
```

**Parsing du signal :**
```powershell
if ($OutputText -match "STATUS:\s*(\w+)") {
    $Status = $Matches[1].ToLower()
    switch ($Status) {
        "continue" { $Continue = $true }
        "escalate" { $NeedsEscalation = $true }
        "wait" { $WaitStateData = @{...} }
        "success" { $Continue = $false }
        "failure" { $Continue = $false }
    }
}
```

### 4. Escalade Automatique (TODO #4)

**Source:** `Check-Escalation` (lignes 1002-1033)

Le système détecte automatiquement quand une tâche nécessite un mode plus puissant.

**Conditions d'escalade :**
1. Agent signale `STATUS: escalate`
2. Échec détecté (`success = false`)
3. Max iterations atteintes sans signal

**Configuration des modes :**
```json
{
  "modes": [{
    "id": "code-simple",
    "escalation": {
      "triggerMode": "code-complex",
      "maxIterations": 5
    }
  }]
}
```

### 5. Agent Signaling Protocol (TODO #4)

**Source:** Implémenté 2026-02-12 (voir `ESCALATION_MECHANISM.md`)

Le protocole permet à l'agent de signaler explicitement son état sans pattern matching prescriptif.

**Avantages :**
- Détection déterministe (regex simple)
- Pas d'ambiguïté
- Extensible (nouveaux signaux)

---

## Configuration

### Modes disponibles

| Mode | Model | Max Iterations | Escalation |
|------|-------|----------------|------------|
| `sync-simple` | haiku | 3 | sync-complex |
| `sync-complex` | sonnet | 5 | - |
| `code-simple` | haiku | 5 | code-complex |
| `code-complex` | opus | 10 | - |

### Fichiers de configuration

| Fichier | Usage |
|---------|-------|
| `.claude/modes/modes-config.json` | Configuration des modes |
| `.claude/scheduler/wait-states/` | État des tâches en attente |
| `.claude/logs/worker-*.log` | Logs d'exécution |

### Variables d'environnement

| Variable | Description |
|----------|-------------|
| `ROOSYNC_SHARED_PATH` | Chemin vers GDrive partagé |
| `COMPUTERNAME` | ID de la machine |

---

## Utilisation

### Exécution basique
```powershell
# Récupère prochaine tâche + mode auto
.\scripts\scheduling/start-claude-worker.ps1
```

### Exécution avec DryRun
```powershell
# Simule sans exécuter Claude
.\scripts/scheduling/start-claude-worker.ps1 -DryRun
```

### Tâche spécifique
```powershell
# Traite une tâche RooSync spécifique
.\scripts/scheduling/start-claude-worker.ps1 -TaskId "msg-20260211-abc123"
```

### Mode forcé
```powershell
# Force un mode spécifique
.\scripts/scheduling/start-claude-worker.ps1 -Mode "code-complex" -Model "opus"
```

### Avec worktree
```powershell
# Isole dans un worktree Git
.\scripts/scheduling/start-claude-worker.ps1 -UseWorktree
```

---

## Workflow Principal (Phases 0/1/2)

```
1. PHASE 0: Vérifier wait states
   └─ Si wait state prêt → REPRISE (sauter Phase 1)

2. PHASE 1: Récupérer tâche
   ├─ RooSync inbox → Si message présent
   ├─ GitHub issues → Si issue dispo
   └─ Fallback maintenance → Sinon

3. PHASE 2: Déterminer mode
   ├─ Si reprise → Mode restauré
   └─ Sinon → Auto-détection

4. EXÉCUTION: Ralph Wiggum Loop
   ├─ Si wait → Sauvegarder + arrêter
   └─ Si escalate → Relancer avec mode supérieur

5. REPORTING: RooSync + GitHub + Cleanup
```

---

## Tests et Validation

### Test DryRun
```powershell
$env:ROOSYNC_SHARED_PATH = "G:\Mon Drive\Synchronisation\RooSync\.shared-state"
.\scripts\scheduling/start-claude-worker.ps1 -DryRun
```

### Résultat attendu
```
[INFO] === DÉMARRAGE CLAUDE WORKER ===
[INFO] Machine: MYIA-PO-2025
[INFO] Récupération prochaine tâche...
[INFO] Vérification RooSync inbox...
[INFO] Vérification GitHub issues...
[INFO] Aucune tâche RooSync/GitHub → Fallback maintenance
[INFO] [DRY-RUN] Commande qui serait exécutée:
[INFO] claude --dangerously-skip-permissions --model haiku -p "..."
[INFO] === WORKER TERMINÉ ===
```

---

## Dépendances

| Dépendance | Usage | Installation |
|------------|-------|--------------|
| `claude` CLI | Exécution Claude Code | `npm install -g @anthropic-ai/claude-code` |
| `gh` CLI | GitHub issues/projects | `winget install GitHub.cli` |
| PowerShell 5.1+ | Exécution script | Natif Windows |

---

## Historique

| Date | Changement | Auteur |
|------|------------|--------|
| 2026-02-11 | Création script initial (TODO #1-5) | Claude Code (myia-po-2026) |
| 2026-02-12 | Ajout Agent Signaling Protocol | Claude Code |
| 2026-02-16 | Phase 2 Wait State resume | Claude Code |
| 2026-02-18 | Documentation architecture | Claude Code (myia-po-2025) |

---

## Références

- **Script:** `scripts/scheduling/start-claude-worker.ps1`
- **README:** `scripts/scheduling/README.md`
- **Escalade:** `.claude/ESCALATION_MECHANISM.md`
- **Issue:** #487 (Phase 3-4)
