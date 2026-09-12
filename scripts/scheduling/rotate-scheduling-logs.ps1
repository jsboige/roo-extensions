<#
.SYNOPSIS
    Rotation des logs scheduling (outputs/scheduling/logs) — item #3323.

.DESCRIPTION
    Applique la politique de retention proposee dans #3323 (commentaire web1
    2026-09-01, corroborre po-2023 2026-09-08 : ~2,8 Go cumules sur 5 machines,
    dont la masse = worker-iter-*).

    REGLES DE SECURITE :
    - Par defaut : REPORT-ONLY (aucune suppression). Le flag -Execute est requis.
    - Les fichiers ne correspondant a AUCUN pattern connu (bucket Unknown) ne sont
      JAMAIS supprimes — comptes a titre informatif seulement.
    - Les .lock / .lastrun frais ne sont jamais touches ; seuls les orphelins
      (> LockOrphanDays) sont eligibles.
    - Aucune recursion : seul le contenu direct du repertoire logs est examine.

    Buckets et retention par defaut :
    | Bucket     | Patterns                                                                                | Retention      |
    |------------|-----------------------------------------------------------------------------------------|----------------|
    | WorkerIter | worker-iter-*                                                                           | 14 jours       |
    | Regular    | worker-*, executor-*, coordinator-*, dashboard-watcher-*, listener-*, copilot-dispatcher*| 30 jours       |
    | Meta       | meta-audit-*, meta-*                                                                    | 7 jours        |
    | Env        | *.env                                                                                   | 30 jours       |
    | Lock       | *.lock, *.lastrun                                                                       | orphan > 7 j   |
    | Unknown    | tout le reste                                                                           | JAMAIS         |

.PARAMETER RepoRoot
    Chemin du repo (defaut = resolution auto depuis l'emplacement du script).

.PARAMETER LogDir
    Repertoire des logs (defaut = <RepoRoot>\outputs\scheduling\logs).

.PARAMETER Execute
    Effectue les suppressions. Sans ce flag, le script liste seulement les
    fichiers eligibles (dry-run conforme a la regle UAC/dry-run discipline).

.PARAMETER WorkerIterRetentionDays
    Retention des logs worker-iter-* (defaut 14).

.PARAMETER RegularRetentionDays
    Retention des logs de run reguliers (defaut 30).

.PARAMETER MetaRetentionDays
    Retention des logs meta-audit-* / meta-* (defaut 7).

.PARAMETER EnvRetentionDays
    Retention des snapshots *.env (defaut 30).

.PARAMETER LockOrphanDays
    Age au-dela duquel un .lock / .lastrun est considere orphelin (defaut 7).

.NOTES
    Issue : #3323
    Proposition d'origine : commentaire web1 #issuecomment-5489763989 (2026-09-01)
    Deploiement en cron : requiert une elevation (Register-ScheduledTask) =
    INTERACTIVE-ONLY — ce script n'installe rien par lui-meme ; merge sans
    deploiement = aucune modification du comportement runtime d'aucune machine.
#>

param(
    [string]$RepoRoot = '',
    [string]$LogDir = '',
    [switch]$Execute,
    [int]$WorkerIterRetentionDays = 14,
    [int]$RegularRetentionDays = 30,
    [int]$MetaRetentionDays = 7,
    [int]$EnvRetentionDays = 30,
    [int]$LockOrphanDays = 7
)

$ErrorActionPreference = 'Stop'

# --- Resolution des chemins (meme pattern que les wrappers siblings) ---
if ([string]::IsNullOrEmpty($RepoRoot)) {
    $scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
    $RepoRoot = (Split-Path (Split-Path $scriptDir -Parent) -Parent)
}
if ([string]::IsNullOrEmpty($LogDir)) {
    $LogDir = Join-Path $RepoRoot 'outputs\scheduling\logs'
}

if (-not (Test-Path -LiteralPath $LogDir -PathType Container)) {
    Write-Output "[INFO] LogDir absent : $LogDir — rien a faire."
    exit 0
}
$ResolvedLogDir = (Resolve-Path -LiteralPath $LogDir).Path
Write-Output "[INFO] LogDir : $ResolvedLogDir"
if ($Execute) {
    Write-Output "[INFO] Mode   : EXECUTE (suppressions reelles)"
} else {
    Write-Output "[INFO] Mode   : REPORT-ONLY (-Execute requis pour supprimer)"
}

# --- Classification : chaque fichier dans exactement un bucket ---
# Ordre important : worker-iter-* AVANT worker-* (le second matche le premier).
function Get-RetentionBucket {
    param([string]$Name)
    if ($Name -like '*.lock')                { return 'Lock' }
    if ($Name -like '*.lastrun')             { return 'Lock' }
    if ($Name -like 'worker-iter-*')         { return 'WorkerIter' }
    if ($Name -like 'worker-*')              { return 'Regular' }
    if ($Name -like 'executor-*')            { return 'Regular' }
    if ($Name -like 'coordinator-*')         { return 'Regular' }
    if ($Name -like 'dashboard-watcher-*')   { return 'Regular' }
    if ($Name -like 'listener-*')            { return 'Regular' }
    if ($Name -like 'copilot-dispatcher*')   { return 'Regular' }
    if ($Name -like 'meta*')                 { return 'Meta' }
    if ($Name -like '*.env')                 { return 'Env' }
    return 'Unknown'
}

$RetentionByBucket = @{
    WorkerIter = $WorkerIterRetentionDays
    Regular    = $RegularRetentionDays
    Meta       = $MetaRetentionDays
    Env        = $EnvRetentionDays
    Lock       = $LockOrphanDays
}

$Now = Get-Date
$Files = @(Get-ChildItem -LiteralPath $ResolvedLogDir -File)

# --- Passe 1 : inventaire par bucket + selection des eligibles ---
$Stats = @{}
$Eligible = @()
foreach ($f in $Files) {
    $Bucket = Get-RetentionBucket -Name $f.Name
    if (-not $Stats.ContainsKey($Bucket)) {
        $Stats[$Bucket] = @{ Files = 0; Bytes = [long]0; Eligible = 0; EligibleBytes = [long]0 }
    }
    $Stats[$Bucket].Files++
    $Stats[$Bucket].Bytes += $f.Length

    if ($Bucket -eq 'Unknown') { continue }   # jamais supprime, juste compte

    $AgeDays = ($Now - $f.LastWriteTime).TotalDays
    if ($AgeDays -ge $RetentionByBucket[$Bucket]) {
        $Stats[$Bucket].Eligible++
        $Stats[$Bucket].EligibleBytes += $f.Length
        $Eligible += $f
    }
}

Write-Output ""
Write-Output ("{0,-12} {1,8} {2,11} {3,10} {4,13}" -f 'Bucket', 'Fichiers', 'Taille(MB)', 'Eligibles', 'Eligible(MB)')
Write-Output ("{0,-12} {1,8} {2,11} {3,10} {4,13}" -f '------', '--------', '----------', '---------', '------------')
$TotalBytes = [long]0
foreach ($f in $Files) { $TotalBytes += $f.Length }
$TotalEligible = 0
$TotalEligibleBytes = [long]0
foreach ($Key in @($Stats.Keys | Sort-Object)) {
    $S = $Stats[$Key]
    Write-Output ("{0,-12} {1,8} {2,11:N1} {3,10} {4,13:N1}" -f $Key, $S.Files, ($S.Bytes / 1MB), $S.Eligible, ($S.EligibleBytes / 1MB))
    $TotalEligible += $S.Eligible
    $TotalEligibleBytes += $S.EligibleBytes
}
Write-Output ("{0,-12} {1,8} {2,11:N1} {3,10} {4,13:N1}" -f 'TOTAL', $Files.Count, ($TotalBytes / 1MB), $TotalEligible, ($TotalEligibleBytes / 1MB))

if ($Stats.ContainsKey('Unknown') -and $Stats['Unknown'].Files -gt 0) {
    Write-Output ""
    Write-Output ("[INFO] Unknown : {0} fichier(s) sans pattern connu — JAMAIS supprimes par ce script." -f $Stats['Unknown'].Files)
}

# --- Passe 2 : execution ou sortie report-only ---
if (-not $Execute) {
    Write-Output ""
    Write-Output ("[REPORT-ONLY] {0} fichier(s) eligibles ({1:N1} MB). Relancer avec -Execute pour supprimer." -f $TotalEligible, ($TotalEligibleBytes / 1MB))
    exit 0
}

if ($TotalEligible -eq 0) {
    Write-Output ""
    Write-Output "[EXECUTE] Aucun fichier eligible — rien a supprimer."
    exit 0
}

Write-Output ""
Write-Output ("[EXECUTE] Suppression de {0} fichier(s) ({1:N1} MB)..." -f $TotalEligible, ($TotalEligibleBytes / 1MB))
$Deleted = 0
$Failed = 0
foreach ($f in $Eligible) {
    try {
        Remove-Item -LiteralPath $f.FullName -Force
        $Deleted++
    } catch {
        Write-Output ("[WARN] Echec suppression : {0} ({1})" -f $f.Name, $_.Exception.Message)
        $Failed++
    }
}
Write-Output ("[EXECUTE] Resultat : {0} supprime(s), {1} echec(s). Espace libere ~{2:N1} MB." -f $Deleted, $Failed, ($TotalEligibleBytes / 1MB))
if ($Failed -gt 0) { exit 1 }
exit 0
