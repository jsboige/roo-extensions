<#
.SYNOPSIS
    Guards the deny-sans-repli probe wired into the executor pre-flight (#4340).

.DESCRIPTION
    Text-guards on scripts/claude/executor-preflight.ps1: the probe must be
    invoked with the workspace path, a finding (probe exit 2) must emit a
    WARN naming the blocked capability and the no-workaround rule, and the
    block must never change the pre-flight's own exit (WARN-never-block,
    same posture as #3169 — provisioning is a per-workspace user decision,
    #4340 point 4). Also guards the last mile: both executor entry points
    (skill + command) must instruct the cycle to relay the WARN, and the
    probe script itself must keep exit code 2 as the finding contract the
    pre-flight branches on.
#>

Describe 'Executor pre-flight deny-fallback probe (#4340)' {
    BeforeAll {
        $preflightPath = Join-Path $PSScriptRoot '..\..\..\scripts\claude\executor-preflight.ps1'
        $preflight = Get-Content $preflightPath -Raw
        $probePath = Join-Path $PSScriptRoot '..\..\..\scripts\diagnostic\check-deny-fallback.py'
        $skillPath = Join-Path $PSScriptRoot '..\..\..\.claude\skills\executor\SKILL.md'
        $commandPath = Join-Path $PSScriptRoot '..\..\..\.claude\commands\executor.md'
        $skill = Get-Content $skillPath -Raw
        $command = Get-Content $commandPath -Raw

        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($preflightPath, [ref]$null, [ref]$errors)
    }

    It 'parses executor-preflight.ps1 under PowerShell' {
        $errors.Count | Should -Be 0
    }

    It 'invokes the probe with the workspace flag' {
        $preflight | Should -Match ([regex]::Escape('scripts/diagnostic/check-deny-fallback.py'))
        $preflight | Should -Match ([regex]::Escape('--workspace'))
        $preflight | Should -Match ([regex]::Escape('"$RepoRoot"'))
    }

    It 'branches on the probe finding contract (exit 2) and instrument error separately' {
        $preflight | Should -Match '\$probeExit -eq 2'
        $preflight | Should -Match '\$probeExit -ne 0'
        $preflight | Should -Match '\[executor-preflight\]\[DENY-FALLBACK\]'
    }

    It 'warns without blocking — the cycle keeps exit 0' {
        $denyBlock = [regex]::Match($preflight, '(?s)\$denyProbe = .*?exit 0')
        $denyBlock.Success | Should -BeTrue
        $denyBlock.Value | Should -Match 'Write-Warning'
        $denyBlock.Value | Should -Not -Match 'exit [1-9]'
    }

    It 'names the no-workaround rule and the per-workscope arbitration in the finding WARN' {
        # The founding incident (po-2027) was a lane normalizing a forbidden
        # fallback (JSON bytesplice of .ipynb) for weeks. The WARN text must
        # carry the interdiction, not just the observation.
        $preflight | Should -Match 'never work around'
        $preflight | Should -Match ([regex]::Escape('per-workspace'))
    }

    It 'keeps the probe finding contract: selftest exit codes documented and FINDINGS = 2' {
        $probe = Get-Content $probePath -Raw
        $probe | Should -Match 'EXIT_FINDINGS = 2'
        $probe | Should -Match ([regex]::Escape('Exit codes: 0 = rien a signaler, 2 = >=1 finding, 1 = erreur'))
    }

    It 'routes the DENY-FALLBACK warning to a dashboard relay in both executor entry points' {
        # Last mile, same as #3169: the WARN becomes a visible fleet signal
        # only once the executor skill/command instruct the cycle to relay it
        # to the workspace dashboard — local pre-flight output dies with the log.
        $skill | Should -Match '\[DENY-FALLBACK\]'
        $command | Should -Match '\[DENY-FALLBACK\]'
        $skill | Should -Match 'tag `WARN`'
        $command | Should -Match '\[WARN\]'
    }
}
