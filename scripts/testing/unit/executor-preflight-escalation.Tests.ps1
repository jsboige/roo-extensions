<#
.SYNOPSIS
    Guards the #3605 escalation contract: escalate after N=3 repetitions of the
    ABSORBING exit-10 form, never on a plain exit-10 counter, and never by
    killing or auto-retrying.
#>

Describe 'Executor exit-10 absorbing-form escalation (#3605)' {
    BeforeAll {
        $preflightPath = Join-Path $PSScriptRoot '..\..\..\scripts\claude\executor-preflight.ps1'
        $modulePath = Join-Path $PSScriptRoot '..\..\..\scripts\common\executor-blockage-state.ps1'
        $skillPath = Join-Path $PSScriptRoot '..\..\..\.claude\skills\executor\SKILL.md'
        $commandPath = Join-Path $PSScriptRoot '..\..\..\.claude\commands\executor.md'

        $preflight = Get-Content $preflightPath -Raw
        $skill = Get-Content $skillPath -Raw
        $command = Get-Content $commandPath -Raw

        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($preflightPath, [ref]$null, [ref]$errors)
        $preflightParseErrors = @($errors).Count

        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($modulePath, [ref]$null, [ref]$errors)
        $moduleParseErrors = @($errors).Count

        . $modulePath
    }

    It 'parses both touched scripts and carries the mandatory UTF-8 BOM (#3338/#3339)' {
        $preflightParseErrors | Should -Be 0
        $moduleParseErrors | Should -Be 0
        foreach ($p in @($preflightPath, $modulePath)) {
            $b = [System.IO.File]::ReadAllBytes($p)
            ($b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) | Should -BeTrue
        }
    }

    It 'dot-sources the blockage-state module before the pre-flight try block' {
        $dotSource = $preflight.IndexOf('executor-blockage-state.ps1')
        $tryBlock = $preflight.IndexOf('try {')
        $dotSource | Should -BeGreaterThan -1
        $tryBlock | Should -BeGreaterThan $dotSource
    }

    It 'discriminates the absorbing form from a rebuilt run before counting a streak' {
        # Le discriminant doit lire la sortie captee du helper : presence de
        # [REBUILT] ET decompte des hotes predating le build. Un simple compteur
        # d'exit 10 est la chose que la spec interdit.
        $preflight | Should -Match '\$helperOutput'
        $preflight | Should -Match '\[REBUILT\]'
        $preflight | Should -Match 'predating build/index'
        $preflight | Should -Match 'Get-BlockageSignature'
    }

    It 'emits the three banners with their distinct conduct' {
        $preflight | Should -Match '\[ESCALATE\]'
        $preflight | Should -Match '\[SHORT-CYCLE\]'
        $preflight | Should -Match '\[RESTART-REQUIRED\]'
    }

    It 'escalates without killing or auto-retrying' {
        # L'escalade demande un restart interactif ; elle ne lance ni kill ni
        # retry automatique. Rien dans le pre-flight ne doit tuer un processus.
        $preflight | Should -Not -Match 'Stop-Process|taskkill|Kill\('
    }

    It 'resets the streak on every non-10 outcome, failures included' {
        $beforeThrow = $preflight.IndexOf('ensure-build-fresh.ps1 could not guarantee freshness')
        $catchClear = $preflight.IndexOf('Clear-BlockageState', $preflight.IndexOf('} catch {'))
        $beforeThrow | Should -BeGreaterThan -1
        $catchClear | Should -BeGreaterThan -1
    }

    It 'documents the N=3 conduct in both executor entry points' {
        foreach ($entryPoint in @($skill, $command)) {
            $entryPoint | Should -Match '\[ESCALATE\]'
            $entryPoint | Should -Match '\[SHORT-CYCLE\]'
            $entryPoint | Should -Match '3'
        }
        $skill | Should -Match ' formes absorbantes \(#3605'
        $command | Should -Match '#3605'
    }

    It 'Get-BlockageSignature returns null for non-stale forms' {
        Get-BlockageSignature -ProcessPrecedesBuild $false -StaleCount 9 -RebuiltThisRun $false | Should -BeNullOrEmpty
        Get-BlockageSignature -ProcessPrecedesBuild $true -StaleCount 0 -RebuiltThisRun $false | Should -BeNullOrEmpty
    }

    It 'Get-BlockageSignature separates rebuilt runs from the absorbing form' {
        Get-BlockageSignature -ProcessPrecedesBuild $true -StaleCount 2 -RebuiltThisRun $true | Should -Be 'arm-post-rebuild'
        Get-BlockageSignature -ProcessPrecedesBuild $true -StaleCount 2 -RebuiltThisRun $false | Should -Be 'arm-absorbing'
    }

    It 'Get-BlockageStatePath honors an explicit path and stays outside repo and ~/.claude' {
        Get-BlockageStatePath -ExplicitPath 'C:\somewhere\state.json' | Should -Be 'C:\somewhere\state.json'
        $default = Get-BlockageStatePath
        if ($env:LOCALAPPDATA) {
            # Windows fleet: the machine-local location, exactly.
            # Parens are REQUIRED: without them Pester 6 passes the literal string
            # '[regex]::Escape' to Should -Match (argument tokenization, not an
            # expression), so this branch fails on every Windows workstation and
            # the failure is invisible in the ubuntu CI, which never runs it.
            $default | Should -Match ([regex]::Escape($env:LOCALAPPDATA))
        } else {
            # Linux CI runner: LOCALAPPDATA is null; the default must resolve to
            # the temp fallback instead of throwing (review #3653).
            $default | Should -Match 'claude-executor'
        }
        $default | Should -Not -Match '\.claude'
    }

    It 'escalates exactly once, on the third repetition of the same signature' {
        $statePath = Join-Path $TestDrive 'blockage.json'
        $r1 = Update-BlockageState -Signature 'arm-absorbing' -StatePath $statePath
        $r2 = Update-BlockageState -Signature 'arm-absorbing' -StatePath $statePath
        $r3 = Update-BlockageState -Signature 'arm-absorbing' -StatePath $statePath
        $r4 = Update-BlockageState -Signature 'arm-absorbing' -StatePath $statePath

        $r1.Escalate | Should -BeFalse
        $r2.Escalate | Should -BeFalse
        $r3.Escalate | Should -BeTrue
        $r3.Streak | Should -Be 3
        $r4.Escalate | Should -BeFalse
        $r4.ShortCycle | Should -BeTrue
        $r4.Streak | Should -Be 4
    }

    It 'a different signature resets the streak and the escalated flag' {
        $statePath = Join-Path $TestDrive 'reset.json'
        1..3 | ForEach-Object { Update-BlockageState -Signature 'arm-absorbing' -StatePath $statePath } | Out-Null

        $switched = Update-BlockageState -Signature 'arm-post-rebuild' -StatePath $statePath
        $switched.Streak | Should -Be 1
        $switched.Escalate | Should -BeFalse

        # Retour a la forme absorbante : le compteur repart de zero, pas de la
        # memoire de l'ancienne signature.
        $back = Update-BlockageState -Signature 'arm-absorbing' -StatePath $statePath
        $back.Streak | Should -Be 1
        $back.Escalate | Should -BeFalse
    }

    It 'treats a corrupt state file as absent instead of failing the pre-flight' {
        $statePath = Join-Path $TestDrive 'corrupt.json'
        Set-Content -LiteralPath $statePath -Value '{not json at all'

        $r = Update-BlockageState -Signature 'arm-absorbing' -StatePath $statePath
        $r.Streak | Should -Be 1
        $r.Escalate | Should -BeFalse
    }

    It 'Clear-BlockageState removes the file and tolerates absence' {
        $statePath = Join-Path $TestDrive 'clear.json'
        Update-BlockageState -Signature 'arm-absorbing' -StatePath $statePath | Out-Null
        Test-Path -LiteralPath $statePath | Should -BeTrue

        Clear-BlockageState -StatePath $statePath
        Test-Path -LiteralPath $statePath | Should -BeFalse

        { Clear-BlockageState -StatePath $statePath } | Should -Not -Throw
    }
}
