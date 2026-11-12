# Pester 5 tests: the Copilot dispatcher INSTALLER must express the retarget
# pair (#4669).
#
# Defect these tests pin: setup-copilot-dispatcher.ps1 built the scheduled
# task's command line as a FIXED string -- it could not carry
# -TargetRepoSlug/-TargetRepoPath, so every task it registered ran the worker
# in local mode (queue = the host repo, work root = the host lane's MAIN
# CHECKOUT): Copilot spent premium with zero delivery possible. The po-2025
# Copilot-Dispatcher task (12 h cadence) was registered exactly this way.
#
# What these tests pin (all on the BUILT STRING, no Register ever runs -- the
# assertions ride the -DryRun preview, and a source pin closes the loop
# between the previewed string and the string handed to
# New-ScheduledTaskAction):
#   1. install with the pair: the task args carry -TargetRepoSlug and
#      -TargetRepoPath.
#   2. install without the pair: REFUSED (non-zero exit, explicit message) --
#      a registered task could not deliver, the worker would skip every
#      Copilot call.
#   3. half a pair: refused (the pair is required together, mirroring the
#      worker's own fail-closed guards).
#   4. a -TargetRepoPath that does not exist: refused.
#   5. Positive controls (mutants): stripping the forwarding makes the args
#      lose the pair; stripping the refusal makes a bare install succeed.
#
# Design notes: the installer runs as a CHILD PROCESS of the same engine that
# runs this suite, against a TEMPORARY COPY of the script (the production
# checkout is never executed). All refusals and the preview are read-only
# behaviors, so no scheduled-task cmdlet is ever reached.
#
# Run:  powershell -File scripts/testing/run-pester-tests.ps1 -Path scripts/testing/unit/setup-copilot-dispatcher.Tests.ps1

Describe 'setup-copilot-dispatcher.ps1 — retarget pair in the task command line (#4669)' {

    BeforeAll {
        $script:productionScript = Join-Path $PSScriptRoot '../../scheduling/setup-copilot-dispatcher.ps1'
        $script:fixedText = Get-Content -LiteralPath $script:productionScript -Raw
        $script:utf8Bom = [System.Text.UTF8Encoding]::new($true)
        $script:harnessRoots = @()

        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $script:engine = Join-Path $PSHOME 'pwsh'
        } else {
            $script:engine = Join-Path $PSHOME 'powershell.exe'
        }

        function New-InstallerHarness {
            param([string]$ScriptText)

            $root = Join-Path ([System.IO.Path]::GetTempPath()) ("copilot-installer-" + [guid]::NewGuid().ToString('N'))
            $script:harnessRoots += $root
            New-Item -ItemType Directory -Path $root -Force | Out-Null

            # The script derives its own path math from $MyInvocation -- a
            # copy in a flat temp dir keeps that self-contained (the preview
            # prints the worker path from the copy's location; the refusal
            # paths never reach it).
            $scriptCopy = Join-Path $root 'setup-copilot-dispatcher.ps1'
            [System.IO.File]::WriteAllText($scriptCopy, $ScriptText, $script:utf8Bom)

            # A real directory standing in for the target repo's local clone.
            $clone = Join-Path $root 'target-clone'
            New-Item -ItemType Directory -Path $clone -Force | Out-Null

            return @{
                Root = $root
                Script = $scriptCopy
                Clone = $clone
            }
        }

        function Invoke-InstallerChild {
            param(
                [hashtable]$Harness,
                [string[]]$ExtraArgs
            )

            $engineArgs = @('-NoProfile')
            if ($env:OS -eq 'Windows_NT') {
                $engineArgs += @('-ExecutionPolicy', 'Bypass')
            }
            $engineArgs += @('-File', $Harness.Script) + $ExtraArgs

            $prevEap = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            try {
                $output = & $script:engine @engineArgs 2>&1
                $exitCode = $LASTEXITCODE
            } finally {
                $ErrorActionPreference = $prevEap
            }
            # Strip ANSI SGR codes from the merged stream: pwsh 7 ConciseView
            # on Linux colors the child's error records, and the escape codes
            # sit BETWEEN words of the message. Refusal assertions anchor on
            # the installer's plain [REFUSED] Write-Host line (unwrapped on
            # every host); the strip keeps the remaining text comparable.
            $ansiPattern = ([string][char]27) + '\[[0-9;]*m'
            return @{
                ExitCode = $exitCode
                Output = (((@($output) | ForEach-Object { [string]$_ }) -join "`n") -replace $ansiPattern, '')
            }
        }

    }

    AfterAll {
        foreach ($root in $script:harnessRoots) {
            if ($root -and (Test-Path -LiteralPath $root)) {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'install WITH the pair: task args carry -TargetRepoSlug and -TargetRepoPath (preview, no Register)' {
        $harness = New-InstallerHarness -ScriptText $script:fixedText
        $result = Invoke-InstallerChild -Harness $harness -ExtraArgs @(
            '-Action', 'install', '-DryRun',
            '-TargetRepoSlug', 'jsboige/CoursIA',
            '-TargetRepoPath', $harness.Clone
        )

        $result.ExitCode | Should -Be 0
        $out = $result.Output
        $out | Should -Match '\[DRY-RUN\] Would install Copilot-Dispatcher'
        $out | Should -Match ([regex]::Escape('-TargetRepoSlug jsboige/CoursIA'))
        $out | Should -Match ([regex]::Escape("-TargetRepoPath `"$($harness.Clone)`""))
    }

    It 'a trailing path separator on -TargetRepoPath is normalized in the registered args' {
        # A trailing \ would escape the closing quote of the interpolated
        # command line and mangle the task's argument parsing. Assert the
        # backslash form is GONE from the preview (the clean form alone
        # cannot discriminate: it is a substring of the dirty one).
        $harness = New-InstallerHarness -ScriptText $script:fixedText
        $result = Invoke-InstallerChild -Harness $harness -ExtraArgs @(
            '-Action', 'install', '-DryRun',
            '-TargetRepoSlug', 'jsboige/CoursIA',
            '-TargetRepoPath', ($harness.Clone + '\')
        )

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match ([regex]::Escape("-TargetRepoPath `"$($harness.Clone)`""))
        $result.Output | Should -Not -Match ([regex]::Escape($harness.Clone + '\'))
    }

    It 'the previewed string is the string registered: $taskCli carries the pair and flows into -Argument (source pin)' {
        # The behavioral test above rides the -DryRun preview; this pin
        # closes the loop between what is printed and what
        # New-ScheduledTaskAction receives: the SAME $taskCli variable, with
        # the retarget pair inside its construction.
        $script:fixedText | Should -Match '-TargetRepoSlug \$TargetRepoSlug -TargetRepoPath `"\$targetPathNorm`"'
        $script:fixedText | Should -Match '-Argument \$taskCli'
    }

    It 'install WITHOUT the pair: refused with the explicit no-delivery-geometry message' {
        $harness = New-InstallerHarness -ScriptText $script:fixedText
        $result = Invoke-InstallerChild -Harness $harness -ExtraArgs @('-Action', 'install', '-DryRun')

        $result.ExitCode | Should -Not -Be 0
        $out = $result.Output
        # Anchor on the plain [REFUSED] line: the throw's error record is
        # re-wrapped by the engine's renderer (pipe prefixes, line breaks
        # mid-message on Linux pwsh), the Write-Host line is not.
        $out | Should -Match '\[REFUSED\] install refused: no delivery geometry'
        $out | Should -Match '\[REFUSED\].*-TargetRepoSlug'
    }

    It 'install with HALF the pair: refused (the pair is required together)' {
        $harness = New-InstallerHarness -ScriptText $script:fixedText
        $slugOnly = Invoke-InstallerChild -Harness $harness -ExtraArgs @(
            '-Action', 'install', '-DryRun', '-TargetRepoSlug', 'jsboige/CoursIA'
        )
        $slugOnly.ExitCode | Should -Not -Be 0
        ($slugOnly.Output) | Should -Match '\[REFUSED\].*must be given TOGETHER'

        $pathOnly = Invoke-InstallerChild -Harness $harness -ExtraArgs @(
            '-Action', 'install', '-DryRun', '-TargetRepoPath', $harness.Clone
        )
        $pathOnly.ExitCode | Should -Not -Be 0
        ($pathOnly.Output) | Should -Match '\[REFUSED\].*must be given TOGETHER'
    }

    It 'install with a nonexistent -TargetRepoPath: refused' {
        $harness = New-InstallerHarness -ScriptText $script:fixedText
        $result = Invoke-InstallerChild -Harness $harness -ExtraArgs @(
            '-Action', 'install', '-DryRun',
            '-TargetRepoSlug', 'jsboige/CoursIA',
            '-TargetRepoPath', (Join-Path $harness.Root 'no-such-clone')
        )

        $result.ExitCode | Should -Not -Be 0
        ($result.Output) | Should -Match '\[REFUSED\].*does not exist'
    }

    It 'POSITIVE CONTROL 1: with the forwarding stripped, the task args LOSE the pair (the defect)' {
        # Mutate a copy of the FIXED script: drop the retarget tail from the
        # $taskCli build (String.Replace with the exact literal needle --
        # regex escaping of backtick-quoted interpolation is a trap). The
        # preview then registers a local-mode task: the exact #4669
        # installer defect.
        $needle = ' -TargetRepoSlug $TargetRepoSlug -TargetRepoPath `"$targetPathNorm`"'
        $mutated = $script:fixedText.Replace($needle, '')

        # Mutation validity: the anchor drifted -> fail loudly.
        $mutated | Should -Not -Be $script:fixedText
        $mutated | Should -Not -Match '-TargetRepoSlug \$TargetRepoSlug'

        $harness = New-InstallerHarness -ScriptText $mutated
        $result = Invoke-InstallerChild -Harness $harness -ExtraArgs @(
            '-Action', 'install', '-DryRun',
            '-TargetRepoSlug', 'jsboige/CoursIA',
            '-TargetRepoPath', $harness.Clone
        )

        $result.ExitCode | Should -Be 0
        $out = $result.Output
        $out | Should -Match '\[DRY-RUN\] Would install'
        $out | Should -Not -Match '-TargetRepoSlug jsboige/CoursIA'
    }

    It 'POSITIVE CONTROL 2: with the refusal stripped, a bare install previews as installable (the defect)' {
        # Mutate a copy of the FIXED script: remove the whole refusal block
        # (comment through the last throw's closing brace -- anchored by the
        # blank line + the trailing-separator comment that follows, since
        # the intermediate throw blocks close at the same indent). The
        # install then previews happily for a task that could never deliver
        # -- what every registered Copilot-Dispatcher task looked like
        # before #4669.
        $pattern = '(?s)#4669: the task command line must carry the retarget pair.*?\r?\n    \}\r?\n\r?\n(?=    # A trailing)'
        $mutated = $script:fixedText -replace $pattern, ''

        # Mutation validity: the anchor drifted -> fail loudly.
        $mutated | Should -Not -Be $script:fixedText
        $mutated | Should -Not -Match 'install refused: no delivery geometry'

        $harness = New-InstallerHarness -ScriptText $mutated
        $result = Invoke-InstallerChild -Harness $harness -ExtraArgs @('-Action', 'install', '-DryRun')

        $result.ExitCode | Should -Be 0
        $out = $result.Output
        $out | Should -Match '\[DRY-RUN\] Would install Copilot-Dispatcher'
        $out | Should -Not -Match 'install refused'
    }
}
