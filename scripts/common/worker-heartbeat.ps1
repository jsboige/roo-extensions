# ============================================================================
# Worker Heartbeat (fichier de vie — même pattern que listener-heartbeats)
# Module partagé : dot-sourcé par start-claude-worker.ps1 et start-vibe-worker.ps1
# (#3207 : « le correctif gagne à être posé une fois dans une fonction partagée
# plutôt que dupliquée »). Requiert Write-Log dans le scope appelant.
# ============================================================================

function Write-WorkerHeartbeat {
    <#
    .SYNOPSIS
    Écrit un timestamp ISO brut dans worker-heartbeats/<machine>.heartbeat à chaque tick.
    Appelé depuis le bloc finally top-level : couvre TOUS les chemins de sortie
    (pool vide / idle / crash / succès), y compris exit 0 silencieux.
    Permet au coordinateur de distinguer « worker mort » (fichier périmé) de
    « worker vivant, pool vide » (fichier frais, aucun rapport dashboard).

    .PARAMETER LogPrefix
    Préfixe des messages de log (défaut « Worker heartbeat »). start-vibe-worker
    passe « Heartbeat » pour préserver ses logs greppables d'avant l'extraction.
    #>
    param([string]$LogPrefix = 'Worker heartbeat')

    try {
        $SharedPath = $env:ROOSYNC_SHARED_PATH
        if (-not $SharedPath) { return }

        $HeartbeatDir = Join-Path $SharedPath "worker-heartbeats"
        if (-not (Test-Path $HeartbeatDir)) {
            New-Item -ItemType Directory -Path $HeartbeatDir -Force | Out-Null
        }

        $MachineId = if ($env:COMPUTERNAME) { $env:COMPUTERNAME.ToLower() } else { 'unknown' }
        $HeartbeatFile = Join-Path $HeartbeatDir "$MachineId.heartbeat"
        $Timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        # Écriture bornée (#3207) : le WriteAllText GDrive peut staller indéfiniment si DriveFS est
        # en attente I/O ininterruptible (observé ~12 min dans un appel réputé « non-fatal »). On
        # l'exécute dans un process enfant (Start-Job) borné à 3 s, tuable par Stop-Job : le tick ne
        # stalle jamais, et on tue un process (pas un thread .NET bloqué, dont on ne se libère pas).
        $job = Start-Job -ScriptBlock {
            param($file, $content)
            [System.IO.File]::WriteAllText($file, $content, [System.Text.UTF8Encoding]::new($false))
        } -ArgumentList $HeartbeatFile, $Timestamp

        if ($null -ne $job) {
            if (Wait-Job $job -Timeout 3) {
                if ($job.State -eq 'Failed') {
                    Write-Log "$LogPrefix failed (non-fatal): $($job.ChildJobs[0].JobStateInfo.Reason)" "WARN"
                } else {
                    Write-Log "$LogPrefix written ($Timestamp)" "DEBUG"
                }
            } else {
                Stop-Job $job -ErrorAction SilentlyContinue
                Write-Log "$LogPrefix write exceeded 3s — abandoned (DriveFS stall?)" "WARN"
            }
            Remove-Job $job -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        # Non-fatal : GDriveFS indisponible ne doit jamais faire échouer le worker (#2845)
        Write-Log "$LogPrefix failed (non-fatal): $_" "WARN"
    }
}
