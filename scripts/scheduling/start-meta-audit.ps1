<#
.SYNOPSIS
    Lance un audit meta-analyse via Claude Code (Tier Meta-Analyst de l'architecture 3x2)

.DESCRIPTION
    Issue #551 - Meta-Analyst tier

    Ce script :
    1. Analyse les traces locales Roo et Claude
    2. Effectue une analyse croisee des deux harnais
    3. Poste les findings sur le dashboard workspace (depuis #1818, INTERCOM deprecated)
    4. Propose des issues GitHub avec label needs-approval si applicable

    Frequence : 72h
    Model : Sonnet (zero-scheduled-opus policy 2026-05-25 — credit Anthropic reserve aux agents interactifs)
    Machines : TOUTES

    MODEL POLICY (zero-scheduled-opus 2026-05-25):
    - Thread principal sur Sonnet (analyse traces, detection incoherences)
    - Recommandations architecturales : rester sur Sonnet (suffisant pour harnais actuel)
    - Aucune escalade Opus en schedule : le credit Anthropic est reserve aux agents interactifs (ai-01 + po-2025 a la demande)

.PARAMETER Model
    Modele Claude a utiliser (defaut: sonnet)

.PARAMETER DryRun
    Mode simulation sans execution reelle

.EXAMPLE
    .\start-meta-audit.ps1
    # Lance l'audit meta-analyse en mode Sonnet (baseline)

.EXAMPLE
    .\start-meta-audit.ps1 -Model "sonnet" -DryRun
    # Simulation (zero-scheduled-opus policy 2026-05-25 : pas d'opus en schedule)

.NOTES
    Auteur: Claude Code (myia-ai-01)
    Date: 2026-03-04
    Version: 1.2.0
    Issue: #551
    Fix: INTERCOM→dashboard workspace (#1818)
    Fix: #3142 — rapport non perdu si RSM absent au spawn :
      (1) pre-flight ensure-build-fresh (cause reproductible connue, #2822, datapoint po-2023 2026-08-18)
      (2) branche de degradation prompt -> fallback .claude/local/META-INTERCOM-{MACHINE}.md [FALLBACK]
      (3) post-run grep JSONL session pour mcp__roo-state-manager -> alerte log si 0 hit sans fallback
    Fix: #3142 v2 — durcissements de c.237 (coordinateur):
      (1) ciblage déterministe via --session-id <uuid> + lecture <projectdir>/<uuid>.jsonl
          (finding web1 c.282, prioritaire — heuristique marqueur "META-ANALYSTE Claude Code"
          avait 7x collisions mesurées dans la session executor web1, et toutes les sessions
          qui lisent le prompt l'ont aussi. Selection heuristique par marqueur = non-fiable
          post-merge puisque le marqueur vit sur main.)
      (2) borne temporelle (Get-Item $FallbackFile).LastWriteTime -ge $StartTime
          (finding po-2023 c.236 — Test-Path seul + Contains [FALLBACK] accepte un fallback
          périmé d'un cycle précédent comme valide, ce qui masque silencieusement les
          répétitions de panne.)
#>

[CmdletBinding()]
param(
    [string]$Model = "sonnet",
    [switch]$DryRun = $false
)

# Configuration
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path "$ScriptDir\..\.."
$LogDir = if (-not [string]::IsNullOrWhiteSpace($env:CLAUDE_META_AUDIT_LOG_DIR)) {
    $env:CLAUDE_META_AUDIT_LOG_DIR
} else {
    Join-Path $RepoRoot "outputs\scheduling\logs"
}

# Fix #726: Load ROOSYNC_MACHINE_ID from .env (primary), with COMPUTERNAME fallback
$EnvPath = Join-Path $RepoRoot "mcps\internal\servers\roo-state-manager\.env"
$MachineName = 'unknown'

if (Test-Path $EnvPath) {
    $EnvLine = Get-Content $EnvPath | Where-Object { $_ -match '^ROOSYNC_MACHINE_ID=' }
    if ($EnvLine) {
        $MachineName = ($EnvLine -split '=', 2)[1].Trim().ToLower()
    }
}

if ($MachineName -eq 'unknown' -and $env:COMPUTERNAME) {
    $MachineName = $env:COMPUTERNAME.ToLower()
}

# Creer repertoire logs si necessaire
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

$LogFile = Join-Path $LogDir "meta-audit-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# === Concurrency Guard: skip if another meta-audit is already running ===
$LockFile = Join-Path $LogDir "meta-audit.lock"
if (Test-Path $LockFile) {
    try {
        $LockContent = Get-Content $LockFile -Raw | ConvertFrom-Json
        if ($LockContent.pid) {
            $ExistingProcess = Get-Process -Id $LockContent.pid -ErrorAction SilentlyContinue
            if ($ExistingProcess) {
                $StartedAt = $LockContent.startedAt
                Write-Host "[SKIP] Another meta-audit is already running (PID $($LockContent.pid), started $StartedAt)" -ForegroundColor Yellow
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

Write-Log "=== META-AUDIT START ==="
Write-Log "Machine: $MachineName"
Write-Log "Model: $Model"
Write-Log "Repo: $RepoRoot"
Write-Log "DryRun: $DryRun"

# Pre-flight
if (-not (Test-ClaudeCLI)) {
    Write-Log "ABORT: Claude CLI introuvable" "ERROR"
    exit 1
}

# Pre-flight build freshness (#3142, datapoint po-2023 2026-08-18) :
# la seule cause-class REPRODUCTIBLE de "RSM absent au spawn" a ce jour est un build/ stale
# (submod bump sans rebuild, #2822). On elimine la cause connue AVANT le spawn — ce qui reste
# apres est host-side (incident 08-16 po-2026). Non-fatal : un echec de build ne bloque pas le run.
$EnsureBuildScript = Join-Path $ScriptDir "..\claude\ensure-build-fresh.ps1"
if (Test-Path $EnsureBuildScript) {
    Write-Log "Pre-flight: ensure-build-fresh (stale build = cause connue de RSM absent #2822)..."
    try {
        $BuildVerdict = & pwsh -NoProfile -ExecutionPolicy Bypass -File $EnsureBuildScript 2>&1 | Select-Object -Last 3
        foreach ($line in $BuildVerdict) { Write-Log "  [BUILD] $line" }
    } catch {
        Write-Log "Pre-flight ensure-build-fresh echoue (non fatal): $_" "WARN"
    }
} else {
    Write-Log "Pre-flight: ensure-build-fresh.ps1 introuvable ($EnsureBuildScript) — skip" "WARN"
}

# Construire le prompt meta-analyse
$Today = Get-Date -Format "yyyy-MM-dd"
# Note: META-INTERCOM deprecated since 2026-04-10 (#1818). Reports go to dashboard workspace.

. "$PSScriptRoot\..\common\extension-paths.ps1"
$rooTasksPath = Get-GlobalStoragePath -Extension RooCode | Join-Path -ChildPath "tasks"

$Prompt = @"
Tu es le META-ANALYSTE Claude Code sur la machine $MachineName.
Date du cycle : $Today

## TON ROLE

Tu analyses les DEUX schedulers (Roo et Claude) sur cette machine pour identifier des ameliorations.
Tu ne modifies RIEN, tu ne dispatches RIEN. Tu PROPOSES uniquement.

## ETAPES

### 1. Collecte des traces Roo (5 dernieres taches)

Utilise Bash pour lister les taches Roo recentes :
``````
ls -lt "$rooTasksPath/" 2>/dev/null | head -10
``````

Pour chaque tache recente, lire les ui_messages.json (derniers 50 lignes).

### 2. Collecte des traces Claude

Lister les sessions Claude recentes :
``````
ls -lt ~/.claude/projects/*/  2>/dev/null | head -10
``````

### 3. Analyses productives (ordre de priorite — meta-analyst rule v1.7.0)

**STOP & PIVOT** : Si ton instinct te pousse a "comparer 2 fichiers de regles entre eux" (harness Claude vs Roo), STOP IMMEDIATEMENT. Pivote vers les 7 categories ci-dessous. Reference : docs/harness/coordinator-specific/meta-analyst-rule.md.

Cherche dans cet ordre, dans les TRACES de taches (pas dans les fichiers de regles) :

1. **Interventions utilisateur** (TOP PRIORITY) : BLOCAGE/CORRECTION/STOP/NON/arrete/tu hallucines dans sessions Claude/Roo recentes
2. **Incidents reproduits** (>=2 occurrences) : erreurs MCP recurrentes, crashes, freezes, scheduler 0%
3. **Explosions contexte** : taches >100K chars/tour, vitest sans troncature, boucles outils
4. **Dispatches stale** : items sans [CLAIMED]/[DONE] apres 24h
5. **Escalations -simple -> -complex echouees** : patterns boucle sans escalader
6. **Bugs production** : mpengine crashes, vmmem freezes, Docker cascade, MCP disconnects
7. **Frictions agents** : [FRICTION] dashboard + has_errors:true via roosync_search

**HARD REJECT** (rejet immediat, ne PAS creer issue) :
- Asymetrie version doc Claude/Roo (rythmes differents = normal)
- "Harmoniser/synchroniser/aligner/standardiser/unifier" sans incident concret
- Refactoring sans incident
- Naming drift cosmetique
- Doublons apparents sans incident
- Metrique sans seuil depasse
- Comparaison Roo vs Claude sans bug observe

Si aucune des 7 categories ne donne de matiere : rapporter "rien a signaler" sur dashboard. NE PAS se rabattre sur HARD REJECT.

### 4. Poster le rapport sur le dashboard workspace

**CHECK PREALABLE (#3142)** : verifie d'abord que les outils roo-state-manager (roosync_dashboard, roosync_messages, ...) sont PRESENTS dans ta session.
- **Si presents** : poste via le MCP comme decrit ci-dessous.
- **Si ABSENTS (0 outil roo-state-manager)** : le dashboard est INJOIGNABLE pour toi. Ecris alors le rapport COMPLET dans `.claude/local/META-INTERCOM-$MachineName.md` (fichier local gitignore) avec le tag `[FALLBACK]` et la date du cycle EN TETE du rapport, et precise que le canal dashboard etait indisponible. C'est la seule exception autorisee a la contrainte "aucun fichier rapport dans le depot".

Utilise le MCP roo-state-manager pour poster le rapport :

```
roosync_dashboard(action: "append", type: "workspace", tags: ["META", "claude-interactive"], content: "...rapport...")
```

Format du rapport :

## Meta-Analyse Claude Code — $MachineName — $Today

### Dashboard Compact (max 10 lignes)

**Traces Roo (analyse croisee) :**
- {N} taches analysees, taux succes {X}%
- Modes utilises : {liste}
- Escalades observees : {details}

**Traces Claude (auto-analyse) :**
- {N} sessions recentes
- Worker executions : {details}
- Patterns remarques

**Analyse harnais :**
- Incoherences : {N} (severity)
- Lacunes : {N}
- Ameliorations proposees : {N}

**Recommandations :**
1. {Rec 1} -> [action: INFO|needs-approval|harness-change]

**ANALYSE APPROFONDIE (zero-scheduled-opus 2026-05-25) :**
Pour recommandations architecturales complexes (ex: refactoring majeur, nouveaux patterns), deleguer l'analyse a un sub-agent (herite du modele parent = Sonnet ; AUCUNE escalade Opus en schedule) :
```
Task(tool="code-explorer", prompt="Analyse l'architecture [composant] pour identifier [probleme]. Return un plan d'action detaille.")
```

---

### 5. Creer des issues si recommandations actionnables

UNIQUEMENT si tu identifies des problemes concrets :
- Utilise ``gh issue create`` avec label ``needs-approval``
- Si changement de harnais : ajouter label ``harness-change``
- Maximum 3 issues par cycle
- NE PAS creer d'issue pour des observations purement informationnelles

## CONTRAINTES ABSOLUES

- NE MODIFIE AUCUN fichier de harnais (.roo/rules/, .claude/rules/, CLAUDE.md, .roomodes)
- NE FERME/ARCHIVE AUCUNE issue GitHub
- NE DISPATCHE AUCUNE tache
- TOUTE issue creee DOIT avoir le label needs-approval
- Limite tes outputs (pas de dump complet de fichiers)
- NE CREER AUCUN fichier rapport dans le depot (docs/, .claude/, etc.) — les rapports vont sur le dashboard workspace (roosync_dashboard) ou en issues GitHub (#1179, #1818). Exception UNIQUE (#3142) : si les outils roo-state-manager sont ABSENTS de la session, rapport en fallback dans .claude/local/META-INTERCOM-$MachineName.md avec tag [FALLBACK]
"@

# Sauvegarder le prompt dans un fichier temporaire (evite les problemes de quoting PS)
$PromptFile = Join-Path $LogDir "meta-audit-prompt-$Today.txt"
[System.IO.File]::WriteAllText($PromptFile, $Prompt, [System.Text.UTF8Encoding]::new($false))

Write-Log "Prompt sauvegarde: $PromptFile"

if ($DryRun) {
    Write-Log "[DRY-RUN] Commande qui serait executee:"
    Write-Log "  claude -p --model $Model --dangerously-skip-permissions  (stdin: $PromptFile, cwd: $RepoRoot)"
    Write-Log "=== META-AUDIT DRY-RUN END ==="
    exit 0
}

# Lancer Claude en mode pipe avec timeout protection
$MaxMinutes = 110  # Generous internal timeout (2h schtask limit, 110min internal for graceful exit)
Write-Log "Lancement Claude meta-audit (timeout: ${MaxMinutes}min)..."
$StartTime = Get-Date

# Resolve claude to an image Start-Process can actually launch.
# `Get-Command claude` returns the npm `claude.ps1` FIRST (CommandType=ExternalScript) whenever
# npm's shim directory precedes the others in PATH. Start-Process -FilePath on a .ps1 dies with
# "%1 n'est pas une application Win32 valide" and the audit exits 1 in ~2s. Measured on ai-01
# 2026-08-13 (meta-audit-20260813-193527.log); web1 reported the same symptom.
# "claude is in PATH" was the neighbouring property — true, and it told us nothing. The property
# that counts is "this path is a launchable image", so assert the extension, not the presence.
# Resolution order mirrors spawn-claude.ps1: VS Code native binary, then the .cmd shim.
$ClaudeCmd = $null
$LaunchableExt = @('.exe', '.cmd', '.bat', '.com')
$ClaudeCandidates = @(
    (Get-ChildItem -Path "$env:USERPROFILE/.vscode/extensions/anthropic.claude-code-*-win32-x64/resources/native-binary/claude.exe" -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1).FullName,
    (Get-Command claude.cmd -ErrorAction SilentlyContinue | Select-Object -First 1).Source
)
foreach ($c in $ClaudeCandidates) {
    if ($c -and ([System.IO.Path]::GetExtension($c).ToLowerInvariant() -in $LaunchableExt)) { $ClaudeCmd = $c; break }
}
if (-not $ClaudeCmd) {
    $seen = ($ClaudeCandidates | Where-Object { $_ }) -join ', '
    if (-not $seen) { $seen = '(none)' }
    Write-Log "ABORT: no launchable 'claude' image found. Start-Process needs .exe/.cmd/.bat — a bare claude.ps1 is NOT launchable. Candidates seen: $seen" "ERROR"
    exit 1
}
Write-Log "Claude binary: $ClaudeCmd"

# Raw output files (full output persisted for debugging, streamed to log during run)
$RawOutputFile = Join-Path $LogDir "meta-audit-raw-output-$Today.txt"
$RawErrorFile = Join-Path $LogDir "meta-audit-raw-error-$Today.txt"
Remove-Item $RawOutputFile, $RawErrorFile -Force -ErrorAction SilentlyContinue

try {
    # Launch Claude with stdin from prompt file, stdout/stderr redirected to files.
    # Start-Process resolves .cmd/.bat shims and gives us the real PID for cleanup.
    # This replaces Start-Job which buffered all output until Receive-Job (#3068).
    # Generate deterministic session id (--session-id <uuid>) for the post-run check (#3142 v2,
    # finding web1 c.282): avoids the fragile textual-marker heuristic that collided with any
    # session containing "META-ANALYSTE Claude Code" (7+ hits in web1's own cycle). The UUID
    # path is <projectdir>/<uuid>.jsonl — Claude creates the dir pattern <lower-cwd with \ and :
    # replaced by ->. We re-encode here to match.
    $SessionId = [guid]::NewGuid().ToString()
    Write-Log "SessionId: $SessionId"
    $EncodedCwd = $RepoRoot.Path.ToLowerInvariant() -replace "\\", "-" -replace ":", "-"
    $SessionProjectDir = Join-Path (Join-Path $env:USERPROFILE ".claude\projects") $EncodedCwd
    $ExpectedJsonl = Join-Path $SessionProjectDir "$SessionId.jsonl"

    $ClaudeProcess = Start-Process -FilePath $ClaudeCmd `
        -ArgumentList "-p --model $Model --dangerously-skip-permissions --session-id $SessionId" `
        -WorkingDirectory $RepoRoot `
        -RedirectStandardInput $PromptFile `
        -RedirectStandardOutput $RawOutputFile `
        -RedirectStandardError $RawErrorFile `
        -NoNewWindow `
        -PassThru

    $ClaudePid = $ClaudeProcess.Id
    Write-Log "Claude process started (PID: $ClaudePid)"

    # Polling loop: stream output to log in real-time, emit heartbeat, enforce timeout.
    # This replaces Wait-Job which produced zero output during the entire run (#3068).
    $TimeoutSeconds = $MaxMinutes * 60
    $Elapsed = 0
    $PollInterval = 5  # seconds
    $LastOutLineCount = 0
    $LastErrLineCount = 0

    while (-not $ClaudeProcess.HasExited -and $Elapsed -lt $TimeoutSeconds) {
        Start-Sleep -Seconds $PollInterval
        $Elapsed += $PollInterval

        # Stream new stdout lines to the log file in real-time
        if (Test-Path $RawOutputFile) {
            $CurrentLines = @(Get-Content $RawOutputFile -ErrorAction SilentlyContinue)
            if ($CurrentLines.Count -gt $LastOutLineCount) {
                foreach ($line in $CurrentLines[$LastOutLineCount..($CurrentLines.Count - 1)]) {
                    Write-Log "  [CLAUDE] $line"
                }
                $LastOutLineCount = $CurrentLines.Count
            }
        }

        # Stream new stderr lines to the log file
        if (Test-Path $RawErrorFile) {
            $CurrentErrLines = @(Get-Content $RawErrorFile -ErrorAction SilentlyContinue)
            if ($CurrentErrLines.Count -gt $LastErrLineCount) {
                foreach ($line in $CurrentErrLines[$LastErrLineCount..($CurrentErrLines.Count - 1)]) {
                    Write-Log "  [CLAUDE-ERR] $line" "WARN"
                }
                $LastErrLineCount = $CurrentErrLines.Count
            }
        }

        # Heartbeat every 60 seconds so a frozen run is distinguishable from a working one
        if ($Elapsed % 60 -eq 0) {
            $MinutesElapsed = [math]::Floor($Elapsed / 60)
            Write-Log "Heartbeat: ${MinutesElapsed}min elapsed, PID $ClaudePid running"
        }
    }

    if (-not $ClaudeProcess.HasExited) {
        # Timeout: kill the specific PID and its process tree.
        # NEVER use Get-Process -Name "claude" — it kills unrelated sessions and misses
        # the actual process (node.exe via npm shim). See issue #3068.
        Write-Log "TIMEOUT: Claude (PID $ClaudePid) depasse ${MaxMinutes}min, arret force" "WARN"

        # taskkill /T kills the process tree (parent + all children including node.exe)
        $KillOutput = & taskkill /T /F /PID $ClaudePid 2>&1
        foreach ($line in $KillOutput) {
            Write-Log "  [KILL] $line"
        }

        # Wait briefly for the kill to take effect
        try { $ClaudeProcess.WaitForExit(5000) | Out-Null } catch { }

        # Flush any remaining output that was written before the kill
        if (Test-Path $RawOutputFile) {
            $FinalLines = @(Get-Content $RawOutputFile -ErrorAction SilentlyContinue)
            if ($FinalLines.Count -gt $LastOutLineCount) {
                foreach ($line in $FinalLines[$LastOutLineCount..($FinalLines.Count - 1)]) {
                    Write-Log "  [CLAUDE] $line"
                }
            }
        }

        Write-Log "=== META-AUDIT TIMEOUT ==="
        exit 2
    }

    # Process completed normally — drain any remaining buffered output
    Start-Sleep -Seconds 1
    if (Test-Path $RawOutputFile) {
        $FinalLines = @(Get-Content $RawOutputFile -ErrorAction SilentlyContinue)
        if ($FinalLines.Count -gt $LastOutLineCount) {
            foreach ($line in $FinalLines[$LastOutLineCount..($FinalLines.Count - 1)]) {
                Write-Log "  [CLAUDE] $line"
            }
        }
    }

    $ExitCode = $ClaudeProcess.ExitCode
    $Duration = (Get-Date) - $StartTime
    Write-Log "Claude termine en $($Duration.TotalMinutes.ToString('F1')) minutes (exit code: $ExitCode)"

    # --- Post-run RSM presence check (#3142 + #3142 v2) ---
    # Sans ce check, un run prive de roo-state-manager au spawn est indiscernable d'un succes :
    # exit 0, output streame, et un rapport nulle part. On lit le JSONL ciblé par UUID
    # (--session-id passé au spawn, finding web1 c.282 — la sélection heuristique par marqueur
    # "META-ANALYSTE Claude Code" avait 7+ collisions mesurées dans la session executor web1,
    # et toutes les sessions qui lisent ou citent le prompt acquièrent le marqueur). Si 0 RSM
    # calls sur la BONNE session -> on vérifie le fallback local prescrit, avec une BORNE
    # TEMPORELLE (finding po-2023 c.236 — Test-Path seul + Contains [FALLBACK] acceptait un
    # fallback écrit par un cycle précédent comme valide, masquant les répétitions de panne).
    # Sans fallback frais (écrit par CE run) : alerte ERROR dans le log schtask.
    try {
        $SessionJsonl = $null
        if ($ExpectedJsonl -and (Test-Path $ExpectedJsonl)) {
            $SessionJsonl = Get-Item $ExpectedJsonl
        } else {
            # Defensive fallback: if --session-id was not honored (older Claude binary,
            # launchable wrapping the shim, etc.) fall back to the marker heuristic. This
            # keeps the safety net alive while the targeted path is the primary one.
            Write-Log "Post-run #3142 v2: JSONL cible $ExpectedJsonl absent — fallback heuristique (marqueur). Risque collision reconnu, voir commentaire c.237" "WARN"
            $ProjectsRoot = Join-Path $env:USERPROFILE ".claude\projects"
            $SessionMarker = "META-ANALYSTE Claude Code"
            $SessionJsonl = Get-ChildItem -Path $ProjectsRoot -Recurse -Filter "*.jsonl" -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -ge $StartTime.AddSeconds(-30) } |
                Where-Object {
                    $raw = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
                    $raw -and ($raw.Contains($SessionMarker))
                } |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1
        }
        if (-not $SessionJsonl) {
            Write-Log "Post-run #3142: session JSONL non identifiee (UUID $SessionId introuvable et heuristique marqueur muette) — presence check annule" "WARN"
        } else {
            $RsmLines = @(Select-String -Path $SessionJsonl.FullName -Pattern "mcp__roo-state-manager" -AllMatches -ErrorAction SilentlyContinue)
            if ($RsmLines.Count -gt 0) {
                Write-Log "Post-run #3142: OK — $($RsmLines.Count) ligne(s) mcp__roo-state-manager dans $($SessionJsonl.Name) (selection UUID)"
            } else {
                $FallbackFile = Join-Path $RepoRoot ".claude\local\META-INTERCOM-$MachineName.md"
                $FallbackFresh = (Test-Path $FallbackFile) -and ((Get-Item $FallbackFile).LastWriteTime -ge $StartTime) -and ((Get-Content $FallbackFile -Raw -ErrorAction SilentlyContinue).Contains("[FALLBACK]"))
                if ($FallbackFresh) {
                    Write-Log "Post-run #3142: RSM ABSENT de la session, [FALLBACK] FRAIS ($(((Get-Item $FallbackFile).LastWriteTime).ToString('o'))) dans META-INTERCOM-$MachineName.md — rapport NON perdu (visible machine-local uniquement)" "WARN"
                } else {
                    $FallbackExists = Test-Path $FallbackFile
                    Write-Log "Post-run #3142: ALERTE — 0 outil roo-state-manager dans la session $SessionJsonl.Name ET aucun [FALLBACK] FRAIS dans META-INTERCOM-$MachineName.md (existe=$FallbackExists; périmé si présent). RAPPORT DE CYCLE PERDU. Remediation connue: (1) build stale #2822 -> relancer scripts/claude/ensure-build-fresh.ps1 puis ce script ; (2) si build fresh -> host-side (incident 2026-08-16) -> STOP & REPAIR .claude/rules/tool-availability.md" "ERROR"
                }
            }
        }
    } catch {
        Write-Log "Post-run #3142 check erreur (non fatal): $_" "WARN"
    }

    # Full output is persisted in the raw file; log last 20 lines as summary
    $AllOutputLines = if (Test-Path $RawOutputFile) { @(Get-Content $RawOutputFile -ErrorAction SilentlyContinue) } else { @() }
    Write-Log "Output: $($AllOutputLines.Count) lines total (full output: $RawOutputFile)"
    Write-Log "Output (dernieres 20 lignes):"
    $LastLines = $AllOutputLines | Select-Object -Last 20
    foreach ($line in $LastLines) {
        Write-Log "  $line"
    }

    # Envoyer un rapport RooSync (si ROOSYNC_SHARED_PATH configure)
    $SharedPath = $env:ROOSYNC_SHARED_PATH
    if ($SharedPath) {
        Write-Log "Envoi rapport RooSync..."
        $ReportSubject = "Meta-Audit Report - $MachineName - $Today"
        $ReportBody = "## Meta-Audit Report`n`n**Machine:** $MachineName`n**Date:** $Today`n**Duration:** $($Duration.TotalMinutes.ToString('F1')) min`n**Model:** $Model`n`n### Output (last 10 lines)`n$(($AllOutputLines | Select-Object -Last 10) -join "`n")"

        # Ecrire le rapport en JSON dans l'outbox
        $OutboxPath = Join-Path $SharedPath "messages\outbox"
        if (Test-Path $OutboxPath) {
            $ReportId = "msg-$(Get-Date -Format 'yyyyMMddTHHmmss')-meta-audit"
            $Report = @{
                id = $ReportId
                from = "$MachineName`:roo-extensions"
                to = "myia-ai-01"
                subject = $ReportSubject
                body = $ReportBody
                priority = "LOW"
                timestamp = (Get-Date -Format "o")
                status = "unread"
            } | ConvertTo-Json -Depth 3
            $ReportFile = Join-Path $OutboxPath "$ReportId.json"
            [System.IO.File]::WriteAllText($ReportFile, $Report, [System.Text.UTF8Encoding]::new($false))
            Write-Log "Rapport RooSync envoye: $ReportId"
        }
    }

    Write-Log "=== META-AUDIT SUCCESS ==="
    exit 0

} catch {
    $Duration = (Get-Date) - $StartTime
    Write-Log "ERREUR: $_" "ERROR"
    Write-Log "Duration: $($Duration.TotalMinutes.ToString('F1')) min" "ERROR"
    Write-Log "=== META-AUDIT FAILED ==="
    exit 1
} finally {
    # Release lock file
    Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
    # Cleanup prompt file (garder les 5 derniers)
    Get-ChildItem (Join-Path $LogDir "meta-audit-prompt-*.txt") -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip 5 |
        Remove-Item -Force -ErrorAction SilentlyContinue
}
