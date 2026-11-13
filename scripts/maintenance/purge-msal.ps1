# Purge MSAL - issue #1422 (Q15, GO user 04/11/2026) - lane myia-po-2023:roo-extensions
#
# Lanceur. PowerShell 5.1 natif (plancher flotte), AUCUNE elevation requise.
#
#   .\purge-msal.ps1                        -> dry-run (lecture seule, affiche la cible)
#   .\purge-msal.ps1 -Apply                 -> backup horodate + purge chirurgicale
#   .\purge-msal.ps1 -Watch                 -> attend la fermeture de la derniere fenetre
#                                              VS Code puis applique UNE fois (mode tache)
#
# Precondition -Apply : AUCUN processus VS Code vivant. Sinon la base est verrouillee
# et la purge partirait d'un etat fige : le script refuse (c'est la garde, pas un bug).
# -Watch re-teste la garde juste avant d'ecrire, pas seulement a l'entree.
#
# Le script ne manipule ni n'imprime aucune valeur de secret : le Python sous-jacent ne
# lit que des compteurs (nombre de cles cible / autres), et le backup reste local.
param(
    [switch]$Apply,
    [switch]$Watch,
    [string]$StateDb = (Join-Path $env:APPDATA 'Code\User\globalStorage\state.vscdb'),
    [string]$ProcessName = 'Code',
    [string]$LogFile = (Join-Path $env:USERPROFILE '.roo-state-manager\msal-purge\watch.log'),
    [int]$PollSeconds = 20,
    [int]$MaxMinutes = 480,
    [string]$SelfUnregisterTask = ''
)

$ErrorActionPreference = 'Stop'
$py = Join-Path $PSScriptRoot 'purge-msal-cache.py'

function Write-WatchLog([string]$line) {
    $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $entry = "$stamp $line"
    Write-Host $entry
    if ([string]::IsNullOrWhiteSpace($LogFile)) { return }
    $dir = Split-Path -Parent $LogFile
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::AppendAllText($LogFile, $entry + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-CodeProcs {
    @(Get-Process -Name $ProcessName -ErrorAction SilentlyContinue)
}

if (-not (Test-Path $StateDb)) { Write-WatchLog "[ERREUR] base introuvable : $StateDb"; exit 1 }
if (-not (Test-Path $py))      { Write-WatchLog "[ERREUR] script python introuvable : $py"; exit 1 }

# --- Mode veille : la tache planifiee appelle ce chemin jusqu'a la fermeture de VS Code.
if ($Watch) {
    $deadline = (Get-Date).AddMinutes($MaxMinutes)
    Write-WatchLog "[WATCH] attente de la fermeture de '$ProcessName' (poll ${PollSeconds}s, plafond ${MaxMinutes}min)"
    while ((Get-CodeProcs).Count -gt 0) {
        if ((Get-Date) -gt $deadline) {
            Write-WatchLog "[WATCH] plafond atteint, aucune fenetre fermee : abandon sans ecriture"
            exit 0
        }
        Start-Sleep -Seconds $PollSeconds
    }
    # Re-test juste avant d'ecrire : un VS Code peut avoir redemarre pendant le sommeil.
    Start-Sleep -Seconds 3
    $still = Get-CodeProcs
    if ($still.Count -gt 0) {
        Write-WatchLog "[WATCH] '$ProcessName' relance pendant l'attente : on repasse en veille"
        exit 0
    }
    Write-WatchLog "[WATCH] aucune fenetre '$ProcessName' vivante : purge"
    & python $py $StateDb --apply
    $rc = $LASTEXITCODE
    if ($rc -eq 0 -and $SelfUnregisterTask) {
        try {
            Unregister-ScheduledTask -TaskName $SelfUnregisterTask -Confirm:$false -ErrorAction Stop
            Write-WatchLog "[WATCH] tache '$SelfUnregisterTask' retiree (purge faite)"
        } catch {
            Write-WatchLog "[WATCH] tache '$SelfUnregisterTask' non retiree : $($_.Exception.Message)"
        }
    }
    exit $rc
}

# --- Appel direct.
$code = Get-CodeProcs
if ($code.Count -gt 0 -and $Apply) {
    Write-WatchLog "[REFUS] $($code.Count) processus '$ProcessName' vivant(s) : fermer TOUTES les fenetres avant -Apply."
    Write-WatchLog "        (ce message est la garde, pas un bug)"
    exit 1
}

if ($Apply) { & python $py $StateDb --apply } else { & python $py $StateDb }
exit $LASTEXITCODE