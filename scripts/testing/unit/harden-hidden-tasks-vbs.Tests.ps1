# Behaviour tests for Get-VbsRunCommand (harden-hidden-tasks.lib.ps1) and the
# VBS launcher template built by New-HardenLauncherVbs.
#
# Defect C (measured on ai-01, 26-27/10, lanes vllm/Maintenance): a task created
# by `schtasks /tr "<full command>"` unquoted stores the WHOLE command line in the
# Execute field. The old assembly '"{0}" {1}' -f $Execute, $Arguments then built a
# single quoted token end to end, CreateProcess took the whole line for the
# executable path, and the task died with 0x80070002 (the error-propagation guard
# of #4377 makes it VISIBLE now: LastTaskResult is non-zero instead of a lie).
#
# These tests EXECUTE Get-VbsRunCommand with an injected filesystem oracle (Pester
# runs under pwsh 7 on ubuntu CI runners: Windows paths do not exist there -- the
# truth under test is the quoting, not the filesystem), then exercise the real
# launcher builder against a real executable, so a regression that restores the
# naive assembly fails here instead of on a fleet machine.
BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $script:libPath = Join-Path $projectRoot "scripts/scheduling/harden-hidden-tasks.lib.ps1"
    . $script:libPath
    $script:libText = Get-Content $script:libPath -Raw
    # A real, existing executable: the builder does not take an oracle, it resolves
    # against the real filesystem (that is what the production path does).
    $script:realExe = (Get-Process -Id $PID).Path
    # The old single-token shape for defect C, as a LITERAL (no interpolation).
    $script:NaiveAssembly = "-f " + '$exe, ' + '$Arguments'
}

Describe "Get-VbsRunCommand" {
    It "Rule 1: a resolvable path with spaces is quoted ALONE, arguments stay outside" {
        $fake = { param($p) $p -eq 'C:\Program Files\PowerShell\7\pwsh.exe' }
        $r = Get-VbsRunCommand -Execute 'C:\Program Files\PowerShell\7\pwsh.exe' `
            -Arguments '-NoProfile -File D:\maint\x.ps1' -TestPath $fake
        $r | Should -Be '"C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile -File D:\maint\x.ps1'
    }
    It "Rule 1: a resolvable path with spaces and NO arguments is quoted alone" {
        $fake = { param($p) $p -eq 'C:\Program Files\PowerShell\7\pwsh.exe' }
        $r = Get-VbsRunCommand -Execute 'C:\Program Files\PowerShell\7\pwsh.exe' -TestPath $fake
        $r | Should -Be '"C:\Program Files\PowerShell\7\pwsh.exe"'
    }
    It "Rule 1: an environment-variable path is expanded and quoted resolved" {
        # The oracle sees the EXPANDED form: proof the expansion happens before
        # quoting. The variable is set by the test itself: ExpandEnvironmentVariables
        # reads the CURRENT process, which is cross-platform (ubuntu CI included).
        $had = [bool]($env:ROO_VBS_TEST_ROOT)
        $old = $env:ROO_VBS_TEST_ROOT
        $env:ROO_VBS_TEST_ROOT = 'C:\WINDOWS'
        try {
            $fake = { param($p) $p -eq 'C:\WINDOWS\system32\cmd.exe' }
            $r = Get-VbsRunCommand -Execute '%ROO_VBS_TEST_ROOT%\system32\cmd.exe' -Arguments '/c echo hi' -TestPath $fake
            $r | Should -Be '"C:\WINDOWS\system32\cmd.exe" /c echo hi'
        } finally {
            if ($had) { $env:ROO_VBS_TEST_ROOT = $old } else { Remove-Item Env:\ROO_VBS_TEST_ROOT -ErrorAction SilentlyContinue }
        }
    }
    It "Rule 1 (defect C regression): full command line in Execute resolves via its head" {
        # The exact shape of the 26/10 casualties: /tr stored everything in Execute.
        $fake = { param($p) $p -eq 'C:\Program Files\PowerShell\7\pwsh.exe' }
        $r = Get-VbsRunCommand -Execute 'C:\Program Files\PowerShell\7\pwsh.exe -NoProfile -File D:\maint\fstier-prune.ps1' `
            -TestPath $fake
        $r | Should -Be '"C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile -File D:\maint\fstier-prune.ps1'
    }
    It "Rule 2: an Execute already starting with a quote is kept verbatim, not double-wrapped" {
        $r = Get-VbsRunCommand -Execute '"C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile -File D:\x.ps1' -TestPath { param($p) $false }
        $r | Should -Be '"C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile -File D:\x.ps1'
    }
    It "Rule 4: nothing resolves -> pre-hardening semantics, NOT a single quoted token" {
        # This is the exact broken form the old code emitted for defect C; assert its absence.
        $r = Get-VbsRunCommand -Execute 'C:\Nowhere\tool.exe -File D:\x.ps1' -TestPath { param($p) $false }
        $r | Should -Be 'C:\Nowhere\tool.exe -File D:\x.ps1'
        $r | Should -Not -Be '"C:\Nowhere\tool.exe -File D:\x.ps1"'
    }
    It "Rule 4: a bare unresolved name keeps its arguments, no quotes added" {
        $r = Get-VbsRunCommand -Execute 'mytool.exe' -Arguments '-v' -TestPath { param($p) $false }
        $r | Should -Be 'mytool.exe -v'
    }
    It "Rule 3 head + separate Arguments: both are kept, head quoted" {
        $fake = { param($p) $p -eq 'D:\tools with space\runner.exe' }
        $r = Get-VbsRunCommand -Execute 'D:\tools with space\runner.exe --mode batch' `
            -Arguments '--dry-run' -TestPath $fake
        $r | Should -Be '"D:\tools with space\runner.exe" --mode batch --dry-run'
    }
    It "An empty Execute yields null (caller reports the task instead of writing a launcher)" {
        Get-VbsRunCommand -Execute ' ' -Arguments 'x' | Should -BeNullOrEmpty
    }
    It "Resolve-ExecutePath treats a drive-letter path as absolute on any host (CI-portable)" {
        # IsPathRooted does not know drive letters under POSIX, but the launchers
        # this tool generates target Windows paths whatever host builds them.
        Resolve-ExecutePath -Execute 'C:\Program Files\PowerShell\7\pwsh.exe' |
            Should -Be 'C:\Program Files\PowerShell\7\pwsh.exe'
    }
}

Describe "New-HardenLauncherVbs (VBS launcher template)" {
    It "Builds the run command through Get-VbsRunCommand, not the naive assembly" {
        $script:libText | Should -Match 'Get-VbsRunCommand -Execute \$Execute -Arguments \$Arguments'
        # The naive form re-wrapped the WHOLE Execute field as one token (defect C).
        $script:libText | Should -Not -Match ([regex]::Escape($script:NaiveAssembly))
    }
    It "A full command line in Execute keeps the exe quoted ALONE in the generated VBS" {
        # Real exe + trailing arguments in the Execute field: defect C shape.
        $vbs = New-HardenLauncherVbs -TaskName 'HHN-DefectC' -Execute ($script:realExe + ' --flag x')
        $vbs | Should -Match ([regex]::Escape('sh.Run("""' + $script:realExe + '"" --flag x"'))
    }
    It "The launcher propagates a CreateProcess failure instead of exiting 0" {
        # LastTaskResult must stop lying: Err.Number is quit out, non-zero.
        $vbs = New-HardenLauncherVbs -TaskName 'HHN-Propagate' -Execute $script:realExe
        $vbs | Should -Match 'On Error Resume Next'
        $vbs | Should -Match 'If Err\.Number <> 0 Then WScript\.Quit Err\.Number'
        $vbs | Should -Match 'WScript\.Quit rc'
    }
}
