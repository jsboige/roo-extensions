# Tests unitaires pour scripts/common/coordinator-claude-session.ps1
# (extrait de scripts/scheduling/start-claude-coordinator.ps1, 2026-09-08)
#
# Bug d'origine : le scriptblock du Start-Job ne retournait que stdout --
# $LASTEXITCODE restait dans le runspace du job et le wrapper logguait
# "=== COORDINATOR SUCCESS ===" sur des runs echoues (log du 08/09 03:37Z :
# "API Error: Rate limit reached" puis SUCCESS, LastTaskResult=0).
#
# Mandat : la decision se prend sur le code de sortie transporte, PAS sur un
# grep de la sortie. "API Error" avec exit 0 doit rester Success ; une sortie
# propre avec exit non nul doit echouer.
#
# Execute en CI par le job unit-pester (#3216) via
# scripts/testing/run-pester-tests.ps1. Faux executables NATIFS obligatoires
# (.cmd sous Windows, script +x avec SHEBANG sous Linux -- sans shebang,
# execve rend ENOEXEC et le fake ne s'execute pas, premiere CI du 08/09) :
# un .ps1 ne peuplerait pas $LASTEXITCODE, grandeur que le module transporte.
#
# Mesures de sonde prealables (ai-01, pwsh 7 + PS 5.1, 08/09) :
# - & <inexistant> ... 2>&1 dans un job NE fait PAS passer le job en
#   State=Failed : l'ErrorRecord est absorbe par 2>&1, le job Complete et
#   $LASTEXITCODE reste $null -> le module doit le classer NoResult. Teste
#   ici via l'API publique (cas reel, sans mock).
# - Set-Location sur un repertoire inexistant n'echoue pas non plus le job
#   (erreur non-terminante). State=Failed est donc une branche DEFENSIVE,
#   atteinte uniquement par exception dans le scriptblock : testee avec un
#   VRAI job en echoue rendu par un Mock Start-Job (objet Job reel, tous les
#   bindings restent valides). Idem pour le resultat absent : vrai job
#   Complete + Receive-Job mocke.
# - Aucun appel Claude reel : uniquement des faux natifs dans un temp dir.
# - Le chemin Timeout ne tue que des processus nommes d'apres le faux :
#   aucun processus claude reel n'est touche par cette suite.

BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    . (Join-Path $projectRoot "scripts/common/coordinator-claude-session.ps1")

    $script:TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "coord-session-tests-$(Get-Random)"
    New-Item -ItemType Directory -Path $script:TempRoot -Force | Out-Null

    # Prompt pipe sur l'entree standard du faux claude
    $script:PromptFile = Join-Path $script:TempRoot "prompt.txt"
    [System.IO.File]::WriteAllText($script:PromptFile, "PROMPT DE TEST", [System.Text.UTF8Encoding]::new($false))

    # PS 5.1 n'a pas $IsWindows -> majeur <= 5 suffit comme discriminant local
    $script:IsWin = ($PSVersionTable.PSVersion.Major -le 5) -or $IsWindows

    function New-FakeClaude {
        param([string]$Name, [string[]]$Lines, [int]$ExitCode)
        if ($script:IsWin) {
            $p = Join-Path $script:TempRoot "$Name.cmd"
            $body = @($Lines | ForEach-Object { "@echo $_" }) + "@exit /b $ExitCode"
            [System.IO.File]::WriteAllText($p, ($body -join "`r`n") + "`r`n", [System.Text.UTF8Encoding]::new($false))
        } else {
            $p = Join-Path $script:TempRoot "$Name.sh"
            $body = @('#!/bin/sh') + @($Lines | ForEach-Object { "echo '$_'" }) + "exit $ExitCode"
            [System.IO.File]::WriteAllText($p, ($body -join "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
            & chmod +x $p
        }
        return $p
    }

    # Fake lent (>> timeout, ~11 s) pour le chemin Timeout. Le kill d'orphelins
    # cible Get-Process -Name <base du faux> : jamais 'claude'.
    function New-SlowFakeClaude {
        if ($script:IsWin) {
            $p = Join-Path $script:TempRoot "slow.cmd"
            [System.IO.File]::WriteAllText($p, "@ping -n 12 127.0.0.1 > nul`r`n@exit /b 0", [System.Text.UTF8Encoding]::new($false))
        } else {
            $p = Join-Path $script:TempRoot "slow.sh"
            [System.IO.File]::WriteAllText($p, "#!/bin/sh`nsleep 11`nexit 0", [System.Text.UTF8Encoding]::new($false))
            & chmod +x $p
        }
        return $p
    }
}

Describe "Invoke-ClaudeCoordinatorSession - transport du code de sortie" {

    It "SUCCESS : exit 0 -> Status Success, sortie transportee, ExitCode 0" {
        $cli = New-FakeClaude -Name 'ok' -Lines @('fake claude output line') -ExitCode 0
        $r = Invoke-ClaudeCoordinatorSession -PromptFile $script:PromptFile -Model 'sonnet' -RepoRoot $script:TempRoot -MaxMinutes 2 -ClaudeCli $cli
        $r.Status | Should -Be 'Success'
        $r.ExitCode | Should -Be 0
        $r.Output | Should -Match 'fake claude output line'
        $r.Reason | Should -Be ''
    }

    It "NONZERO : exit 1 avec 'API Error' dans la sortie -> NonZeroExit (le cas du 08/09 03:37Z)" {
        $cli = New-FakeClaude -Name 'rate' -Lines @('API Error: Rate limit reached') -ExitCode 1
        $r = Invoke-ClaudeCoordinatorSession -PromptFile $script:PromptFile -Model 'sonnet' -RepoRoot $script:TempRoot -MaxMinutes 2 -ClaudeCli $cli
        $r.Status | Should -Be 'NonZeroExit'
        $r.ExitCode | Should -Be 1
        $r.Output | Should -Match 'Rate limit'
        $r.Reason | Should -Match 'exit=1'
    }

    It "ANTI-GREP : 'API Error' dans la sortie MAIS exit 0 -> reste Success" {
        # Garde-fou du mandat : ne pas regresser vers un grep de la sortie.
        $cli = New-FakeClaude -Name 'greptrap' -Lines @('API Error: Rate limit reached') -ExitCode 0
        $r = Invoke-ClaudeCoordinatorSession -PromptFile $script:PromptFile -Model 'sonnet' -RepoRoot $script:TempRoot -MaxMinutes 2 -ClaudeCli $cli
        $r.Status | Should -Be 'Success'
        $r.ExitCode | Should -Be 0
    }

    It "CLI INTROUVABLE : job Complete, ExitCode absent -> NoResult, jamais Success (cas reel, sonde 08/09)" {
        $missing = Join-Path $script:TempRoot 'does-not-exist-xyz'
        $r = Invoke-ClaudeCoordinatorSession -PromptFile $script:PromptFile -Model 'sonnet' -RepoRoot $script:TempRoot -MaxMinutes 2 -ClaudeCli $missing
        $r.Status | Should -Be 'NoResult'
        $r.ExitCode | Should -BeNullOrEmpty
        $r.Reason | Should -Match 'sans ExitCode'
    }

    It "JOB FAILED : job State=Failed -> JobFailed avec raison (branche defensive, vrai job echoue)" {
        # Un VRAI job en echec (throw terminant) rendu par un Mock Start-Job :
        # les erreurs non-terminantes n'echouent jamais un job (sonde 08/09),
        # cette branche ne s'atteint que par une exception dans le scriptblock.
        # Objet Job reel -> tous les bindings positionnels restent valides.
        $script:FailedJob = Start-Job -ScriptBlock { throw 'simulated job failure' }
        Wait-Job $script:FailedJob | Out-Null
        $script:FailedJob.State | Should -Be 'Failed'
        Mock Start-Job { $script:FailedJob }
        $r = Invoke-ClaudeCoordinatorSession -PromptFile $script:PromptFile -Model 'sonnet' -RepoRoot $script:TempRoot -MaxMinutes 2 -ClaudeCli 'unused'
        $r.Status | Should -Be 'JobFailed'
        $r.Reason | Should -Match 'simulated job failure'
    }

    It "NO RESULT : job Complete sans resultat transporte -> NoResult (vrai job, Receive-Job mocke)" {
        $script:EmptyJob = Start-Job -ScriptBlock { 'never-read' }
        Wait-Job $script:EmptyJob | Out-Null
        Mock Start-Job { $script:EmptyJob }
        Mock Receive-Job { $null }
        $r = Invoke-ClaudeCoordinatorSession -PromptFile $script:PromptFile -Model 'sonnet' -RepoRoot $script:TempRoot -MaxMinutes 2 -ClaudeCli 'unused'
        $r.Status | Should -Be 'NoResult'
        $r.Reason | Should -Match 'aucun resultat transporte'
    }

    It "TIMEOUT : fake lent + MaxMinutes 0.05 (3 s) -> Status Timeout, raison d'arret force" {
        $cli = New-SlowFakeClaude
        $r = Invoke-ClaudeCoordinatorSession -PromptFile $script:PromptFile -Model 'sonnet' -RepoRoot $script:TempRoot -MaxMinutes 0.05 -ClaudeCli $cli
        $r.Status | Should -Be 'Timeout'
        $r.Reason | Should -Match 'arret force'
    }
}

AfterAll {
    Remove-Item $script:TempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
