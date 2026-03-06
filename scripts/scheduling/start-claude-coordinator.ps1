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
    Model : opus (coordination strategique)
    Machine : myia-ai-01 UNIQUEMENT

.PARAMETER Model
    Modele Claude a utiliser (defaut: opus)

.PARAMETER LookbackHours
    Fenetre d'analyse en heures (defaut: 48)

.PARAMETER DryRun
    Mode simulation sans execution reelle

.EXAMPLE
    .\start-claude-coordinator.ps1
    # Lance la coordination en mode opus

.EXAMPLE
    .\start-claude-coordinator.ps1 -Model "sonnet" -DryRun
    # Simulation avec modele sonnet

.NOTES
    Auteur: Claude Code (myia-ai-01)
    Date: 2026-03-05
    Version: 1.0.0
    Issue: #540
#>

[CmdletBinding()]
param(
    [string]$Model = "opus",
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

### 0. Lire l'INTERCOM local

Lis le fichier `.claude/local/INTERCOM-$env:COMPUTERNAME.md` (utilise l'outil Read).
Cherche les messages recents de Roo (< 24h) avec ces tags :
- `[DONE]` : Roo a termine une tache → analyser le bilan
- `[WAKE-CLAUDE]` : Roo a detecte des messages RooSync non traites → les traiter en priorite
- `[PATROL]` : Roo a fait une exploration de veille active → noter le domaine couvert
- `[FRICTION-FOUND]` : Roo a detecte un probleme → verifier et escalader si confirme
- `[ERROR]` / `[WARN]` : Problemes operationnels → investiguer
- `[ASK]` : Roo pose une question → repondre via INTERCOM

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

### 4. Decisions et actions

Selon l'analyse :

| Constat | Action |
|---------|--------|
| Machine silencieuse >48h (CONFIRME) | Envoyer message RooSync URGENT |
| Machine surchargee | Rebalancer vers machines inactives |
| Issues non assignees | Dispatcher aux machines disponibles |
| Travail bloque | Escalader ou reassigner |

Pour dispatcher, utilise roosync_send :
- action: "send"
- to: "{machine}:roo-extensions"
- subject: "[TASK] Description"
- tags: ["coordinator", "dispatch"]

### 5. Produire le rapport coordinateur

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

### 6. Ecrire dans l'INTERCOM local

OBLIGATOIRE en fin de cycle. Utilise l'outil Edit pour ajouter un message a la fin de `.claude/local/INTERCOM-$env:COMPUTERNAME.md` :

Format :
``````markdown
## [$Today HH:MM] claude-code -> roo [COORDINATION]
### Bilan coordinateur schedule

- Trafic RooSync : {N} messages analyses, {M} machines actives
- Git : {N} commits depuis ${LookbackHours}h
- Charge : {equilibree|desequilibree} ({details})
- Actions prises : {dispatches, rebalances, ou "aucune"}
- Messages INTERCOM Roo traites : {N} ({tags})
- Prochaine action recommandee pour Roo : {suggestion}

---
``````

Si le fichier INTERCOM n'existe pas ou est inaccessible, note-le dans les logs mais ne bloque pas.

## CONTRAINTES ABSOLUES

- NE MODIFIE AUCUN fichier de harnais (.roo/rules/, .claude/rules/, CLAUDE.md, .roomodes)
- NE FERME AUCUNE issue sans verification checklist 100%
- Toute issue creee DOIT avoir le label needs-approval
- Respecte le protocole de scepticisme : VERIFIE avant de propager
- Maximum 5 dispatches par cycle
- Limite tes outputs (pas de dump complet de fichiers)
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

# Lancer Claude en mode pipe
Write-Log "Lancement Claude coordinateur..."
$StartTime = Get-Date

try {
    Push-Location $RepoRoot

    $ClaudeOutput = Get-Content $PromptFile -Raw | & claude -p --model $Model --dangerously-skip-permissions 2>&1

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
    # Cleanup prompt files (garder les 5 derniers)
    Get-ChildItem (Join-Path $LogDir "coordinator-prompt-*.txt") -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip 5 |
        Remove-Item -Force -ErrorAction SilentlyContinue
}
