# Session Claude coordinateur avec transport du code de sortie (extraction 2026-09-08)
#
# Origine : scripts/scheduling/start-claude-coordinator.ps1 lancait `claude -p`
# dans un Start-Job dont le scriptblock ne retournait QUE stdout --
# $LASTEXITCODE restait dans le runspace du job, et le parent logguait
# "=== COORDINATOR SUCCESS ===" sans jamais voir le code natif de claude.
# Constat du 08/09/2026 (log coordinator-20260908-053702) : run 03:37Z,
# sortie "API Error: Rate limit reached", code natif NON CAPTE (jamais
# transporte -- c etait le bug), SUCCESS dans le log, LastTaskResult=0.
#
# Ce module transporte un resultat structure { Output, ExitCode } depuis le
# job. La decision SUCCESS/FAILED se prend sur : etat du job, presence du
# resultat transporte, et code de sortie natif -- JAMAIS sur un grep de la
# sortie (une sortie contenant "API Error" avec exit 0 reste un succes ;
# reciproquement une sortie propre avec exit non nul est un echec).
#
# Convention identique a scripts/common/worker-heartbeat.ps1 : module
# dot-source par le wrapper, teste par scripts/testing/unit/ (Pester, job CI
# unit-pester #3216). Compatible Windows PowerShell 5.1 et pwsh 7 (pas
# d'operateur PS7-only).

function Invoke-ClaudeCoordinatorSession {
    <#
    .SYNOPSIS
    Lance `claude -p` dans un job avec timeout et rend un resultat structure.

    .PARAMETER PromptFile
    Fichier dont le contenu est pipe sur l'entree standard de claude.

    .PARAMETER Model
    Modele passe a --model (defaut: sonnet).

    .PARAMETER RepoRoot
    Repertoire de travail du job (Set-Location avant l'invocation).

    .PARAMETER MaxMinutes
    Timeout en minutes. [double] pour permettre des valeurs de test courtes
    (0.05 min = 3 s). Defaut : 110 (limite interne du wrapper, sous les 2 h
    du schtask).

    .PARAMETER ClaudeCli
    Commande claude a invoquer (defaut : 'claude', resolu via PATH par le
    job -- comportement d'origine). Surcharge de test : chemin absolu vers
    un faux executable NATIF (.cmd sous Windows, script +x sous Linux) --
    un .ps1 ne peuplerait pas $LASTEXITCODE.

    .OUTPUTS
    [pscustomobject]@{
        Status          = 'Success' | 'NonZeroExit' | 'JobFailed' | 'NoResult' | 'Timeout'
        ExitCode        = code de sortie natif de claude (int), $null sinon
        Output          = sortie claude concatenee (string)
        Reason          = detail d'echec ou de timeout ('' si Success)
        DurationMinutes = duree du wait, minutes (double)
    }

    .NOTES
    Le chemin Timeout preserve le comportement d'origine : Stop-Job force,
    puis kill des processus du MEME NOM que le lanceur et demarres apres lui
    (balayage nom + StartTime -- ce n'est PAS une ascendance prouvee ;
    comportement preexistant, conserve tel quel dans cette PR).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$PromptFile,
        [string]$Model = "sonnet",
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [double]$MaxMinutes = 110,
        [string]$ClaudeCli = "claude"
    )

    $StartTime = Get-Date

    $Job = Start-Job -ScriptBlock {
        param($promptFile, $model, $repoRoot, $cli)
        Set-Location $repoRoot
        $out = Get-Content $promptFile -Raw | & $cli -p --model $model --dangerously-skip-permissions 2>&1
        # Transport structure : $LASTEXITCODE vit dans le runspace du job.
        # Sans cet objet, le parent ne le verra jamais -- c'etait le bug.
        [pscustomobject]@{ Output = ($out | Out-String); ExitCode = $LASTEXITCODE }
    } -ArgumentList $PromptFile, $Model, $RepoRoot, $ClaudeCli

    $TimeoutSeconds = [int][Math]::Ceiling($MaxMinutes * 60)
    $Completed = Wait-Job $Job -Timeout $TimeoutSeconds

    if ($null -eq $Completed) {
        # Timeout atteint -- arret force du job, puis balayage nom + StartTime (voir NOTES)
        # (comportement d'origine du wrapper, preserve a l'identique).
        Stop-Job $Job -PassThru | Remove-Job -Force
        $ProcName = [System.IO.Path]::GetFileNameWithoutExtension($ClaudeCli)
        Get-Process -Name $ProcName -ErrorAction SilentlyContinue | Where-Object {
            $_.StartTime -ge $StartTime
        } | Stop-Process -Force -ErrorAction SilentlyContinue
        return [pscustomobject]@{
            Status          = 'Timeout'
            ExitCode        = $null
            Output          = ''
            Reason          = "Claude depasse ${MaxMinutes}min, arret force"
            DurationMinutes = ((Get-Date) - $StartTime).TotalMinutes
        }
    }

    $JobState = $Job.State
    $JobReason = ''
    if ($JobState -eq 'Failed') {
        $JobReason = "$($Job.ChildJobs[0].JobStateInfo.Reason)"
    }

    $JobResult = $null
    try {
        $JobResult = Receive-Job $Job -ErrorAction SilentlyContinue
    } catch {
        $JobReason = "Receive-Job: $_"
    }
    Remove-Job $Job -Force -ErrorAction SilentlyContinue

    $Duration = ((Get-Date) - $StartTime).TotalMinutes

    if ($JobState -eq 'Failed') {
        return [pscustomobject]@{
            Status          = 'JobFailed'
            ExitCode        = $null
            Output          = ''
            Reason          = "job State=Failed ($JobReason)"
            DurationMinutes = $Duration
        }
    }

    if ($null -eq $JobResult) {
        return [pscustomobject]@{
            Status          = 'NoResult'
            ExitCode        = $null
            Output          = ''
            Reason          = "job State=$JobState mais aucun resultat transporte"
            DurationMinutes = $Duration
        }
    }

    $Output = ''
    if ($null -ne $JobResult.Output) { $Output = [string]$JobResult.Output }
    $ExitCode = $JobResult.ExitCode

    if ($null -eq $ExitCode) {
        # Le scriptblock transporte toujours ExitCode : son absence signifie
        # que le transport lui-meme est casse -- echec, pas succes silencieux.
        return [pscustomobject]@{
            Status          = 'NoResult'
            ExitCode        = $null
            Output          = $Output
            Reason          = 'resultat transporte sans ExitCode'
            DurationMinutes = $Duration
        }
    }

    if ($ExitCode -ne 0) {
        return [pscustomobject]@{
            Status          = 'NonZeroExit'
            ExitCode        = [int]$ExitCode
            Output          = $Output
            Reason          = "claude exit=$ExitCode"
            DurationMinutes = $Duration
        }
    }

    return [pscustomobject]@{
        Status          = 'Success'
        ExitCode        = 0
        Output          = $Output
        Reason          = ''
        DurationMinutes = $Duration
    }
}
