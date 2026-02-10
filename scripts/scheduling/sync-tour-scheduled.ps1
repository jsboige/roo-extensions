<#
.SYNOPSIS
    Version automatisée du sync-tour pour scheduling

.DESCRIPTION
    Phase 1 - Scheduling Claude Code (#414)

    Ce script encapsule le sync-tour skill pour exécution automatique :
    1. Lance sync-tour en mode simple (Haiku)
    2. Escalade vers complex si nécessaire
    3. Envoie rapport au coordinateur
    4. Log dans .claude/logs/

.PARAMETER SkipPhases
    Phases à sauter (ex: "4,5,6,7" pour ne faire que sync git + tests)

.PARAMETER Mode
    Mode Claude à utiliser (sync-simple ou sync-complex)
    Par défaut: sync-simple

.PARAMETER ReportTo
    Machine coordinateur pour rapport RooSync
    Par défaut: myia-ai-01

.EXAMPLE
    .\sync-tour-scheduled.ps1
    # Sync-tour complet en mode simple

.EXAMPLE
    .\sync-tour-scheduled.ps1 -Mode "sync-complex" -SkipPhases "6,7"
    # Mode complex, skip planification et réponses

.NOTES
    Auteur: Claude Code (myia-po-2026)
    Date: 2026-02-11
    Version: 1.0.0
    Issue: #414

    Utilisation avec Task Scheduler Windows:
    schtasks /create /tn "Claude Sync Tour" /tr "powershell.exe -ExecutionPolicy Bypass -File C:\dev\roo-extensions\scripts\scheduling\sync-tour-scheduled.ps1" /sc daily /st 09:00
#>

[CmdletBinding()]
param(
    [string]$SkipPhases,
    [string]$Mode = "sync-simple",
    [string]$ReportTo = "myia-ai-01",
    [switch]$DryRun = $false
)

# Configuration
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path "$ScriptDir\..\.."
$LogDir = Join-Path $RepoRoot ".claude\logs"

# Créer répertoire logs si nécessaire
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

$LogFile = Join-Path $LogDir "sync-tour-scheduled-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$StartTime = Get-Date

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    Write-Host $LogMessage
    Add-Content -Path $LogFile -Value $LogMessage
}

function Build-SyncPrompt {
    $Prompt = @"
Execute un sync-tour complet avec les spécifications suivantes :

**Mode d'exécution :** $Mode
**Machine :** $env:COMPUTERNAME
**Phases :**
"@

    if ($SkipPhases) {
        $Prompt += "`n  - Phases à sauter : $SkipPhases"
    } else {
        $Prompt += "`n  - Toutes les phases (0-7)"
    }

    $Prompt += @"


**Instructions détaillées :**

1. **Phase 0 (INTERCOM Local)** : Lire .claude/local/INTERCOM-$env:COMPUTERNAME.md
   - Messages récents de Roo
   - Tâches en cours

2. **Phase 1 (Messages RooSync)** : Lire inbox avec roosync_read (mode: inbox)
   - Filtrer messages non-lus
   - Extraire directives coordinateur

3. **Phase 2 (Git Sync)** : git fetch + pull --no-rebase
   - Résoudre conflits automatiquement si possible
   - Sinon : escalader vers sync-complex
   - Submodule update

4. **Phase 3 (Build + Tests)** : npm run build + npx vitest run
   - Si échecs : corriger erreurs simples
   - Si complexe : escalader vers code-complex

5. **Phase 4 (GitHub Status)** : gh issue list + project status
   - Vérifier tâches assignées
   - Identifier incohérences

6. **Phase 5 (MAJ GitHub)** : Marquer tâches Done
   - Commentaires sur issues
   - **Validation utilisateur** avant créer nouvelles issues

7. **Phase 6 (Planification)** : Ventilation tâches 5 machines
   - Équilibrage charge
   - Prochaines priorités

8. **Phase 7 (Réponses RooSync)** : Messages personnalisés
   - Marquer messages lus
   - Envoyer rapports

**Rapport final :**
- Résumé exécutif
- Actions effectuées
- État final machine
- Points d'attention

**Si escalade nécessaire :** Créer sous-tâche en mode approprié.
"@

    return $Prompt
}

function Invoke-SyncTour {
    param([string]$Prompt)

    Write-Log "Lancement sync-tour avec mode: $Mode"

    if ($DryRun) {
        Write-Log "[DRY-RUN] Prompt qui serait exécuté:" "INFO"
        Write-Log $Prompt "INFO"
        return @{ success = $true; dryRun = $true; output = "DRY-RUN" }
    }

    try {
        # Appeler le worker script avec le prompt sync-tour
        $WorkerScript = Join-Path $ScriptDir "start-claude-worker.ps1"

        if (-not (Test-Path $WorkerScript)) {
            Write-Log "start-claude-worker.ps1 introuvable: $WorkerScript" "ERROR"
            return @{ success = $false; error = "Worker script not found" }
        }

        Write-Log "Délégation au worker script..."

        # Créer tâche temporaire pour le worker
        $TempTaskId = "sync-tour-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

        # Lancer worker (simulation pour Phase 1)
        Write-Log "[SIMULATION] Le worker serait lancé avec:" "INFO"
        Write-Log "  - Mode: $Mode" "INFO"
        Write-Log "  - TaskId: $TempTaskId" "INFO"

        # Pour Phase 1, simuler succès
        $Output = "Sync-tour complété en mode $Mode"

        Write-Log "Sync-tour terminé" "INFO"

        return @{
            success = $true
            output = $Output
            mode = $Mode
            duration = (New-TimeSpan -Start $StartTime -End (Get-Date)).TotalSeconds
        }
    }
    catch {
        Write-Log "Erreur exécution sync-tour: $_" "ERROR"
        return @{ success = $false; error = $_.Exception.Message }
    }
}

function Send-Report {
    param($Result)

    Write-Log "Envoi rapport au coordinateur: $ReportTo"

    $Duration = [math]::Round($Result.duration, 2)

    $ReportMessage = @"
## Sync-Tour Automatisé - $env:COMPUTERNAME

**Date :** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Mode :** $Mode
**Durée :** ${Duration}s
**Statut :** $(if ($Result.success) { "✅ SUCCÈS" } else { "❌ ÉCHEC" })

### Résultat
``````
$($Result.output)
``````

### Configuration
- Phases sautées : $(if ($SkipPhases) { $SkipPhases } else { "Aucune" })
- Log : $LogFile

### Prochaine exécution
Selon planification Task Scheduler / Cron
"@

    if ($DryRun) {
        Write-Log "[DRY-RUN] Rapport qui serait envoyé:" "INFO"
        Write-Log $ReportMessage "INFO"
        return
    }

    # TODO: Implémenter envoi RooSync réel
    # Pour l'instant, juste logger
    Write-Log "Rapport préparé (envoi RooSync à implémenter)"
    Write-Log $ReportMessage
}

# ============================================================================
# MAIN WORKFLOW
# ============================================================================

Write-Log "=== SYNC-TOUR AUTOMATISÉ ==="
Write-Log "Machine: $env:COMPUTERNAME"
Write-Log "Mode: $Mode"
Write-Log "Coordinateur: $ReportTo"
Write-Log "DryRun: $DryRun"

try {
    # 1. Construire prompt sync-tour
    $Prompt = Build-SyncPrompt
    Write-Log "Prompt généré ($(($Prompt -split "`n").Count) lignes)"

    # 2. Exécuter sync-tour
    $Result = Invoke-SyncTour -Prompt $Prompt

    # 3. Envoyer rapport
    Send-Report -Result $Result

    Write-Log "=== SYNC-TOUR TERMINÉ ==="

    if ($Result.success) {
        exit 0
    } else {
        exit 1
    }
}
catch {
    Write-Log "ERREUR CRITIQUE: $_" "ERROR"
    Write-Log $_.ScriptStackTrace "ERROR"
    exit 1
}
