<#
.SYNOPSIS
    Lance un worker Claude Code avec une tache specifiee et un timeout.

.DESCRIPTION
    Worker autonome qui :
    1. Lance Claude Code avec un prompt specifique
    2. Capture la sortie dans un fichier log
    3. Gere le timeout et l'arret propre
    4. Detecte la fin de tache (exit code)

    Mode "Ralph Wiggum" : execute une tache, termine, peut etre relance par scheduler.

.PARAMETER Task
    Tache a executer (defaut: sync-tour)

.PARAMETER MaxMinutes
    Duree max en minutes (defaut: 30)

.PARAMETER LogDir
    Dossier de logs (defaut: logs/scheduling/)

.PARAMETER Provider
    Fournisseur LLM (defaut: anthropic). Options: anthropic, z-ai

.PARAMETER SkipPermissions
    Utiliser --dangerously-skip-permissions (defaut: false)

.PARAMETER DryRun
    Afficher la commande sans l'executer

.EXAMPLE
    .\start-claude-worker.ps1
    .\start-claude-worker.ps1 -Task "executor" -MaxMinutes 60
    .\start-claude-worker.ps1 -Task "sync-tour" -DryRun
#>

param(
    [string]$Task = "sync-tour",
    [int]$MaxMinutes = 30,
    [string]$LogDir = "",
    [string]$Provider = "anthropic",
    [switch]$SkipPermissions,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Detecter repo
$RepoRoot = git rev-parse --show-toplevel 2>$null
if (-not $RepoRoot) {
    Write-Error "Pas dans un depot Git."
    exit 1
}

$machineName = ($env:COMPUTERNAME).ToLower()
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

# Dossier logs
if (-not $LogDir) {
    $LogDir = "$RepoRoot/logs/scheduling"
}
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$logFile = "$LogDir/$machineName-$Task-$timestamp.log"

Write-Host "=== Claude Code Worker ===" -ForegroundColor Cyan
Write-Host "Machine:  $machineName"
Write-Host "Task:     $Task"
Write-Host "Timeout:  ${MaxMinutes}min"
Write-Host "Log:      $logFile"
Write-Host "Provider: $Provider"
Write-Host ""

# Construire le prompt selon la tache
$prompts = @{
    "sync-tour" = "Execute un tour de synchronisation complet. Lis les messages RooSync, fait git pull, lance les tests, et envoie un rapport au coordinateur. Sois concis."
    "executor" = "Lance le mode executor. Identifie la machine, lis les messages du coordinateur, execute les taches assignees en autonomie. Commit et push quand c'est pret."
    "tests" = "Lance les tests unitaires et verifie le build. Si des tests echouent, tente de les corriger. Commit les fixes si reussi."
    "cleanup" = "Verifie le git status, nettoie les fichiers temporaires, met a jour la documentation si necessaire."
    "prepare-intercom" = "Lis les issues GitHub assignees a cette machine et les messages RooSync. Ecris un message [SCHEDULED] dans l'INTERCOM (.claude/local/INTERCOM-{MACHINE}.md) avec les taches prioritaires pour Roo. Sois concis et structure."
    "analyze-roo" = "Lis l'INTERCOM (.claude/local/INTERCOM-{MACHINE}.md). Trouve le dernier message [DONE] de Roo. Analyse la qualite du travail (tests passes, git status propre, code acceptable). Ecris un message [FEEDBACK] dans l'INTERCOM avec ton evaluation."
}

$prompt = if ($prompts.ContainsKey($Task)) {
    $prompts[$Task]
} else {
    $Task  # Utiliser le task comme prompt direct
}

# Construire la commande Claude
$claudeCmd = "claude"
$claudeArgs = @(
    "--print"
    "--output-format", "text"
)

# Provider: mapper vers le modele Claude correspondant
$modelMap = @{
    'anthropic' = 'claude-opus-4-6'
    'z-ai'      = 'claude-sonnet-4-5-20250929'
}
if ($modelMap.ContainsKey($Provider)) {
    $claudeArgs += "--model"
    $claudeArgs += $modelMap[$Provider]
}

if ($SkipPermissions) {
    # SECURITE: --dangerously-skip-permissions desactive les confirmations utilisateur.
    # En mode autonome (scheduler), les messages RooSync pourraient contenir du prompt injection.
    # N'utiliser que sur des machines de confiance avec des sources de messages controlees.
    $claudeArgs += "--dangerously-skip-permissions"
}

# Ajouter le prompt (--print est suffisant, pas besoin de -p en doublon)
$claudeArgs += $prompt

$fullCommand = "$claudeCmd $($claudeArgs -join ' ')"

if ($DryRun) {
    Write-Host "[DRY RUN] Commande:" -ForegroundColor Yellow
    Write-Host "  $fullCommand"
    Write-Host ""
    Write-Host "Log serait ecrit dans: $logFile"
    exit 0
}

# Ecrire l'en-tete du log
$logHeader = @"
=== Claude Code Worker Log ===
Machine: $machineName
Task: $Task
Started: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Timeout: ${MaxMinutes}min
Provider: $Provider
Command: $fullCommand
===

"@

Set-Content -Path $logFile -Value $logHeader -Encoding UTF8

# Lancer Claude avec timeout
Write-Host "[START] Lancement Claude Code..." -ForegroundColor Yellow
$startTime = Get-Date

try {
    $process = Start-Process -FilePath $claudeCmd -ArgumentList $claudeArgs `
        -WorkingDirectory $RepoRoot `
        -RedirectStandardOutput "$logFile.stdout" `
        -RedirectStandardError "$logFile.stderr" `
        -PassThru -NoNewWindow

    $timeoutMs = $MaxMinutes * 60 * 1000

    if (-not $process.WaitForExit($timeoutMs)) {
        Write-Host "[TIMEOUT] Arret apres ${MaxMinutes}min" -ForegroundColor Yellow
        $process.Kill()
        Add-Content -Path $logFile -Value "`n=== TIMEOUT after ${MaxMinutes}min ===" -Encoding UTF8
    }

    $exitCode = $process.ExitCode
    $duration = (Get-Date) - $startTime

    # Append stdout/stderr au log principal
    if (Test-Path "$logFile.stdout") {
        Add-Content -Path $logFile -Value "`n=== STDOUT ===" -Encoding UTF8
        Get-Content "$logFile.stdout" | Add-Content -Path $logFile -Encoding UTF8
        Remove-Item "$logFile.stdout" -Force
    }
    if (Test-Path "$logFile.stderr") {
        $stderrContent = Get-Content "$logFile.stderr" -Raw
        if ($stderrContent.Trim()) {
            Add-Content -Path $logFile -Value "`n=== STDERR ===" -Encoding UTF8
            Add-Content -Path $logFile -Value $stderrContent -Encoding UTF8
        }
        Remove-Item "$logFile.stderr" -Force
    }

    # Footer
    $footer = @"

=== COMPLETED ===
Exit Code: $exitCode
Duration: $($duration.TotalMinutes.ToString("F1"))min
Ended: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
    Add-Content -Path $logFile -Value $footer -Encoding UTF8

    Write-Host ""
    Write-Host "=== Worker termine ===" -ForegroundColor $(if ($exitCode -eq 0) { "Green" } else { "Yellow" })
    Write-Host "Exit code: $exitCode"
    Write-Host "Duree:     $($duration.TotalMinutes.ToString('F1'))min"
    Write-Host "Log:       $logFile"

    exit $exitCode
}
catch {
    Write-Error "Erreur: $_"
    Add-Content -Path $logFile -Value "`n=== ERROR: $_ ===" -Encoding UTF8
    exit 1
}
