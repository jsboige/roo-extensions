<#
.SYNOPSIS
    Lance le coordinateur schedule via Claude Code (Tier Coordinator de l'architecture 3x2)

.DESCRIPTION
    Issue #540 - Coordinator tier (ai-01 ONLY)

    Ce script :
    1. Analyse le trafic RooSync (messages envoyes/recus par machine)
    2. Analyse l'activite Git recente (commits merges, auteurs)
    3. Evalue l'equilibre de charge entre les 6 machines
    4. Dispatche/rebalance si necessaire
    5. Produit un rapport coordinateur sur GDrive

    Frequence : 6-12h
    Model : Sonnet baseline avec escalation sub-agent Opus pour PR reviews (#1027)
    Machine : myia-ai-01 UNIQUEMENT

    ESCALATION MECHANISM (#1027):
    - Thread principal sur Sonnet (git pull, dashboard read, dispatch decisions)
    - PR review etale : deleguer a sub-agent Opus via Task tool si diff complexe
    - MinimumModel guard non applicable (Sonnet suffisant pour harnais actuel)

.PARAMETER Model
    Modele Claude a utiliser (defaut: sonnet)

.PARAMETER LookbackHours
    Fenetre d'analyse en heures (defaut: 48)

.PARAMETER DryRun
    Mode simulation sans execution reelle

.EXAMPLE
    .\start-claude-coordinator.ps1
    # Lance la coordination en mode Sonnet (baseline)

.EXAMPLE
    .\start-claude-coordinator.ps1 -Model "opus" -DryRun
    # Simulation avec modele Opus (escalade manuelle)

.NOTES
    Auteur: Claude Code (myia-ai-01)
    Date: 2026-03-05
    Version: 1.0.0
    Issue: #540
#>

[CmdletBinding()]
param(
    [string]$Model = "sonnet",
    [int]$LookbackHours = 48,
    [switch]$DryRun = $false
)

# Configuration
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path "$ScriptDir\..\.."
$LogDir = Join-Path $RepoRoot ".claude\logs"
$MachineName = $env:COMPUTERNAME.ToLower()

# Verifier que c'est bien ai-01
if ($MachineName -ne "myia-ai-01") {
    Write-Host "[ERROR] Ce script ne doit tourner que sur myia-ai-01 (machine actuelle: $MachineName)" -ForegroundColor Red
    exit 1
}

# Creer repertoire logs si necessaire
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

$LogFile = Join-Path $LogDir "coordinator-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# === Concurrency Guard: skip if another coordinator is already running ===
$LockFile = Join-Path $LogDir "coordinator.lock"
if (Test-Path $LockFile) {
    try {
        $LockContent = Get-Content $LockFile -Raw | ConvertFrom-Json
        if ($LockContent.pid) {
            $ExistingProcess = Get-Process -Id $LockContent.pid -ErrorAction SilentlyContinue
            if ($ExistingProcess) {
                $StartedAt = $LockContent.startedAt
                Write-Host "[SKIP] Another coordinator is already running (PID $($LockContent.pid), started $StartedAt)" -ForegroundColor Yellow
                exit 0
            }
        }
    } catch {
        # Stale or corrupt lock file - proceed
    }
    Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
}
# Acquire lock
@{ pid = $PID; startedAt = (Get-Date -Format "o"); machine = $MachineName } | ConvertTo-Json | Set-Content $LockFile -Force

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    Write-Host $LogMessage
    Add-Content -Path $LogFile -Value $LogMessage
}

function Test-ClaudeCLI {
    try {
        $Version = & claude --version 2>&1
        Write-Log "Claude CLI: $Version"
        return $true
    } catch {
        Write-Log "Claude CLI non disponible: $_" "ERROR"
        return $false
    }
}

# =============================================================================
# MAIN
# =============================================================================

Write-Log "=== COORDINATOR START ==="
Write-Log "Machine: $MachineName"
Write-Log "Model: $Model"
Write-Log "Lookback: ${LookbackHours}h"
Write-Log "Repo: $RepoRoot"
Write-Log "DryRun: $DryRun"

# Pre-flight
if (-not (Test-ClaudeCLI)) {
    Write-Log "ABORT: Claude CLI introuvable" "ERROR"
    exit 1
}

# Construire le prompt coordinateur
$Today = Get-Date -Format "yyyy-MM-dd"

$Prompt = @"
Tu es le COORDINATEUR SCHEDULE Claude Code sur myia-ai-01.
Date du cycle : $Today
Fenetre d'analyse : ${LookbackHours}h

## TON ROLE

Tu analyses l'activite GLOBALE du collectif de 6 machines : messages RooSync, commits git, charge de travail GitHub.
Tu dispatches et rebalances si necessaire.
Tu NE MODIFIES AUCUN fichier de harnais.

## ETAPES

### 0. Lire le Dashboard Workspace

Lis le dashboard RooSync workspace : roosync_dashboard(action: "read", type: "workspace", section: "intercom", intercomLimit: 10).
Cherche les messages recents (< 24h) avec ces tags :
- `[DONE]` : Un agent a termine une tache → analyser le bilan
- `[WAKE-CLAUDE]` : Roo a detecte des messages RooSync non traites → les traiter en priorite
- `[PATROL]` : Roo a fait une exploration de veille active → noter le domaine couvert
- `[FRICTION-FOUND]` : Roo a detecte un probleme → verifier et escalader si confirme
- `[ERROR]` / `[WARN]` : Problemes operationnels → investiguer
- `[ASK]` : Un agent pose une question → repondre via dashboard

Note les messages pertinents pour les integrer a ton analyse.

### 1. Analyse du trafic RooSync

Lis ta boite de reception RooSync (tous les messages recents) :
- Utilise l'outil roosync_read(mode: "inbox", status: "all", limit: 50)
- Identifie les messages par machine (from field)
- Compte envoyes/recus par machine
- Detecte les machines silencieuses (aucun message depuis ${LookbackHours}h)
- Note les priorites (LOW/MEDIUM/HIGH/URGENT)

ATTENTION au protocole de scepticisme : ne declare JAMAIS une machine "silencieuse" sans avoir verifie les messages read+unread sur ${LookbackHours}h. Verifie aussi les commentaires GitHub recents.

### 2. Analyse de l'activite Git

Utilise Bash pour analyser les commits recents :
``````
git log --oneline --since="${LookbackHours} hours ago" --format="%h %an %s"
``````

Pour chaque commit :
- Identifier l'auteur/machine (Co-Authored-By ou commit author)
- Categoriser : fix, feat, docs, chore, refactor
- Comparer avec le trafic RooSync (travail reel vs communication)

### 3. Equilibre de charge

Consulte le GitHub Project #67 :
``````
gh api graphql -f query='{ user(login: "jsboige") { projectV2(number: 67) { items(first: 100) { nodes { fieldValues(first: 10) { nodes { ... on ProjectV2ItemFieldSingleSelectValue { name field { ... on ProjectV2SingleSelectField { name } } } } } content { ... on Issue { title number state } } } } } } }'
``````

Evaluer :
- Issues par machine (champ Machine)
- Distribution des statuts (Todo / In Progress / Done)
- Machines surchargees ou inactives

### 4. Review et merge des PRs ouvertes

Verifie TOUTES les PRs ouvertes (Worker, Executor, et manuelles) :
``````
gh pr list --repo jsboige/roo-extensions --state open --json number,title,createdAt,additions,deletions,author
``````

Pour chaque PR ouverte, effectue une review structuree :

**4a. Lire le diff :**
``````
gh pr diff {number} --repo jsboige/roo-extensions
``````

**4b. Checklist anti-destruction (OBLIGATOIRE) :**
- Pas de suppression de code sans remplacement PROUVE
- Pas de suppression dans repertoires PROTEGES (src/services/synthesis/, src/services/narrative/)
- Pas de nouveaux stubs (return null, throw new Error, // TODO dans du code expose)
- Pas de console.log dans du code nouveau
- Build + tests CI doivent passer (verifier le statut CI si disponible)

**4c. Decision :**

| Critere | Action |
|---------|--------|
| PR petite (< 100 lignes), diff propre, pas de suppression suspecte | `gh pr merge {number} --merge --repo jsboige/roo-extensions --delete-branch` |
| PR moyenne (100-500 lignes), diff coherent | Ajouter un commentaire `## Coordinator Review` avec analyse + merger si OK |
| PR large (> 500 lignes) ou suppression de code | **ESCALADE** : utiliser Task tool avec sub-agent Opus pour review approfondie |
| Titre indique "Partial" ou "needs review" | Commentaire de review, attendre corrections |
| PR date de plus de 72h sans activite | Commenter pour relancer l'auteur, fermer si >1 semaine |

**ESCALATION PATTERN (#1027) :**
Pour PRs complexes (>500 lignes ou suppressions), deleguer la review a un sub-agent Opus :
```
Task(tool="code-fixer", prompt="Review PR #{number} avec focus anti-destruction. Diff: [gh pr diff {number}]. Checklist: pas de suppression sans preuve, pas de stubs, pas de console.log. Return ton analyse.", model="opus")
```

**4d. Format du commentaire de review :**
``````
## Coordinator Review (scheduled)

**Taille:** +{additions}/-{deletions} ({files} fichiers)
**Analyse:**
- [ ] Pas de suppression sans remplacement
- [ ] Pas de stubs/console.log
- [ ] Diff coherent avec le titre
- [ ] Build/tests OK

**Decision:** APPROVE / REQUEST_CHANGES / COMMENT
**Details:** [analyse concise]
``````

### 5. Decisions et dispatch

**REGLE OBLIGATOIRE : Tu DOIS dispatcher au moins 1 tache par cycle si des issues Todo existent dans le Project #67.**
"Aucun dispatch necessaire" n'est acceptable QUE si le Project #67 a 0 Todo ET 0 issue non-assignee.

Selon l'analyse :

| Constat | Action |
|---------|--------|
| Machine silencieuse >48h (CONFIRME) | Envoyer message RooSync URGENT |
| Machine surchargee | Rebalancer vers machines inactives |
| Issues Todo non assignees | **OBLIGATOIRE** : Dispatcher aux machines disponibles |
| Aucune issue Todo | Dispatcher des taches idle (coverage, patrol, validation) |
| Travail bloque | Escalader ou reassigner |

Pour dispatcher, utilise roosync_send :
- action: "send"
- to: "{machine}:roo-extensions"
- subject: "[TASK] Description"
- tags: ["coordinator", "dispatch"]

Si aucune issue Todo n'existe, cree des taches de veille :
- Coverage : "Lance npx vitest run --coverage et identifie les modules < 60%. Ecris 2-3 tests pour le module le plus faible."
- Patrol : "Explore le codebase, identifie du code mort, des TODO, ou des tests manquants. Rapporte tes trouvailles."

### 5b. Audit config via sk-agent (si disponible)

Si des divergences de configuration ont ete detectees entre machines (via roosync_compare_config ou les rapports) :
``````
call_agent(agent: "critic", prompt: "Audit these configuration differences between machines: [details des diffs]. Identify which are intentional (machine-specific) vs accidental (drift). Rate severity: CRITICAL/WARNING/INFO.")
``````
Inclure le resultat dans le rapport coordinateur sous une section "Config Audit (sk-agent)".
Si sk-agent n'est pas disponible, sauter cette etape sans bloquer.

### 6. Produire le rapport coordinateur

Ecrire le rapport dans le fichier GDrive (si accessible) :
`.shared-state/coordinator/coordinator-report-$Today.md`

Format :
``````markdown
## Coordinator Analysis - $Today

### RooSync Traffic (last ${LookbackHours}h)
| Machine | Sent | Received | Last Active |
|---------|------|----------|-------------|

### Git Activity (last ${LookbackHours}h)
| Author | Commits | Types | Notable |
|--------|---------|-------|---------|

### Workload Balance
| Machine | Open Issues | In Progress | Idle? |
|---------|------------|-------------|-------|

### Actions Taken
- [Dispatches, rebalances, escalations]
``````

### 7. Ecrire dans le Dashboard Workspace

OBLIGATOIRE en fin de cycle. Utilise roosync_dashboard pour ajouter un message :

Format :
``````markdown
roosync_dashboard(
  action: "append",
  type: "workspace",
  tags: ["INFO", "claude-scheduled"],
  content: "## [$Today HH:MM] Coordinateur Schedule - Bilan`n`n- Trafic RooSync : {N} messages analyses, {M} machines actives`n- Git : {N} commits depuis ${LookbackHours}h`n- Charge : {equilibree|desequilibree} ({details})`n- Actions prises : {dispatches, rebalances, ou "aucune"}`n- Messages workspace traites : {N} ({tags})`n- Prochaine action recommandee : {suggestion}`n`n## CONTRAINTES ABSOLUES (rappel)`n- NE MODIFIE AUCUN fichier de harnais (.roo/rules/, .claude/rules/, CLAUDE.md, .roomodes)`n- NE FERME AUCUNE issue sans verification checklist 100%`n- Toute issue creee DOIT avoir le label needs-approval`n- Respecte le protocole de scepticisme : VERIFIE avant de propager`n- Maximum 5 dispatches par cycle`n- Limite tes outputs (pas de dump complet de fichiers)"
)
``````

Si le dashboard est inaccessible, note-le dans les logs mais ne bloque pas.
"@

# Sauvegarder le prompt dans un fichier temporaire
$PromptFile = Join-Path $RepoRoot ".claude\logs\coordinator-prompt-$Today.txt"
[System.IO.File]::WriteAllText($PromptFile, $Prompt, [System.Text.UTF8Encoding]::new($false))

Write-Log "Prompt sauvegarde: $PromptFile"

if ($DryRun) {
    Write-Log "[DRY-RUN] Commande qui serait executee:"
    Write-Log "  cd $RepoRoot && Get-Content '$PromptFile' -Raw | claude -p --model $Model --dangerously-skip-permissions"
    Write-Log "=== COORDINATOR DRY-RUN END ==="
    exit 0
}

# Lancer Claude en mode pipe avec timeout protection
$MaxMinutes = 110  # Generous internal timeout (2h schtask limit, 110min internal for graceful exit)
Write-Log "Lancement Claude coordinateur (timeout: ${MaxMinutes}min)..."
$StartTime = Get-Date

try {
    Push-Location $RepoRoot

    # Launch Claude as a background job with timeout
    $ClaudeJob = Start-Job -ScriptBlock {
        param($promptFile, $model, $repoRoot)
        Set-Location $repoRoot
        Get-Content $promptFile -Raw | & claude -p --model $model --dangerously-skip-permissions 2>&1
    } -ArgumentList $PromptFile, $Model, $RepoRoot

    $Completed = Wait-Job $ClaudeJob -Timeout ($MaxMinutes * 60)

    if ($null -eq $Completed) {
        # Timeout reached - kill the job and all child processes
        Write-Log "TIMEOUT: Claude depasse ${MaxMinutes}min, arret force" "WARN"
        Stop-Job $ClaudeJob -PassThru | Remove-Job -Force
        # Also kill any orphaned claude processes from this session
        Get-Process -Name "claude" -ErrorAction SilentlyContinue | Where-Object {
            $_.StartTime -ge $StartTime
        } | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Log "=== COORDINATOR TIMEOUT ==="
        exit 2
    }

    $ClaudeOutput = Receive-Job $ClaudeJob
    Remove-Job $ClaudeJob -Force -ErrorAction SilentlyContinue

    $Duration = (Get-Date) - $StartTime
    Write-Log "Claude termine en $($Duration.TotalMinutes.ToString('F1')) minutes"
    Write-Log "Output (dernieres 20 lignes):"

    $OutputLines = ($ClaudeOutput -split "`n")
    $LastLines = $OutputLines | Select-Object -Last 20
    foreach ($line in $LastLines) {
        Write-Log "  $line"
    }

    Write-Log "=== COORDINATOR SUCCESS ==="
    exit 0

} catch {
    $Duration = (Get-Date) - $StartTime
    Write-Log "ERREUR: $_" "ERROR"
    Write-Log "Duration: $($Duration.TotalMinutes.ToString('F1')) min" "ERROR"
    Write-Log "=== COORDINATOR FAILED ==="
    exit 1
} finally {
    Pop-Location
    # Release lock file
    Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
    # Cleanup prompt files (garder les 5 derniers)
    Get-ChildItem (Join-Path $LogDir "coordinator-prompt-*.txt") -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip 5 |
        Remove-Item -Force -ErrorAction SilentlyContinue
}
