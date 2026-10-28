# backup-lane-essentials.Tests.ps1 - seat-resolved defaults (#lane-backup-defaults)
#
# The first version of the script hardcoded po-2027's paths (D:\dev, G:\Mon
# Drive, d--dev-roo-extensions) in its PARAM DEFAULTS, so every other seat died
# on "memory dir missing" (measured on web2, 28/10). These tests pin the new
# contract: every default derives from the seat at run time, and an
# unresolvable default FAILS LOUD instead of guessing a drive letter.
#
# The script is run as a powershell.exe 5.1 child on purpose (fleet floor,
# shell-fallback.md); env overrides are injected per invocation and restored.

BeforeAll {
    $script:Script = Join-Path $PSScriptRoot 'backup-lane-essentials.ps1'
    $script:Tmp = Join-Path ([IO.Path]::GetTempPath()) ("lane-backup-tests-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force $Tmp | Out-Null

    function Invoke-Backup {
        param([hashtable]$Env = @{}, [string[]]$ArgList = @())
        $saved = @{}
        foreach ($k in @($Env.Keys)) {
            $saved[$k] = [Environment]::GetEnvironmentVariable($k, 'Process')
            [Environment]::SetEnvironmentVariable($k, $Env[$k], 'Process')
        }
        try {
            $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script @ArgList 2>&1
            [PSCustomObject]@{ Output = ($out -join "`n"); ExitCode = $LASTEXITCODE }
        } finally {
            foreach ($k in @($saved.Keys)) { [Environment]::SetEnvironmentVariable($k, $saved[$k], 'Process') }
        }
    }

    # A fake seat: home with the projects convention, plus an RSM .env fixture.
    function New-FakeSeat([string]$Name, [string[]]$ProjectDirs) {
        $home_ = Join-Path $Tmp $Name
        $projects = Join-Path $home_ '.claude\projects'
        New-Item -ItemType Directory -Force $projects | Out-Null
        foreach ($p in $ProjectDirs) {
            $mem = Join-Path $projects "$p\memory"
            New-Item -ItemType Directory -Force $mem | Out-Null
            "lesson" | Set-Content (Join-Path $mem 'MEMORY.md') -Encoding ascii
        }
        $envFixture = Join-Path $home_ 'rsm-server.env'
        'KEY=value' | Set-Content $envFixture -Encoding ascii
        [PSCustomObject]@{ Home = $home_; Projects = $projects; EnvFile = $envFixture }
    }
}

Describe 'backup-lane-essentials.ps1 seat-resolved defaults' {
    BeforeAll {
        $script:Seat = New-FakeSeat 'seatA' @('c--dev-roo-extensions')
        $script:Shared = Join-Path $Tmp 'shared-state'
        New-Item -ItemType Directory -Force $Shared | Out-Null
        # Repo root fixture: its basename becomes the lane label.
        $script:RepoRoot = Join-Path $Tmp 'roo-extensions'
        New-Item -ItemType Directory -Force $RepoRoot | Out-Null
        $script:BaseArgs = @('-WhatIf', '-RepoRoot', $RepoRoot, '-RsmEnvFile', $Seat.EnvFile)
    }

    It 'derives the lane root from ROOSYNC_SHARED_PATH + machine + lane' {
        $r = Invoke-Backup -Env @{ ROOSYNC_SHARED_PATH = $Shared; USERPROFILE = $Seat.Home; ROOSYNC_MACHINE_ID = 'myia-test-seat' } -ArgList $BaseArgs
        $r.ExitCode | Should -Be 0 -Because $r.Output
        $expected = Join-Path $Shared 'lane-backups\myia-test-seat-roo-extensions\daily'
        $r.Output | Should -Match ([regex]::Escape($expected))
    }

    It 'falls back to COMPUTERNAME when ROOSYNC_MACHINE_ID is unset' {
        $r = Invoke-Backup -Env @{ ROOSYNC_SHARED_PATH = $Shared; USERPROFILE = $Seat.Home; ROOSYNC_MACHINE_ID = $null } -ArgList $BaseArgs
        $r.ExitCode | Should -Be 0 -Because $r.Output
        $r.Output | Should -Match ([regex]::Escape("lane-backups\$($env:COMPUTERNAME.ToLower())-roo-extensions"))
    }

    It 'discovers the memory dir from the projects convention (no path re-derivation)' {
        # Renamed project dir: a hardcoded spelling would miss it, discovery does not.
        $seat = New-FakeSeat 'seatB' @('x--elsewhere-roo-extensions')
        $r = Invoke-Backup -Env @{ ROOSYNC_SHARED_PATH = $Shared; USERPROFILE = $seat.Home; ROOSYNC_MACHINE_ID = 'm' } -ArgList $BaseArgs
        $r.ExitCode | Should -Be 0 -Because $r.Output
        $r.Output | Should -Match 'from 2 files'
    }

    It 'fails loud when no memory dir matches, naming the override' {
        $seat = New-FakeSeat 'seatC' @('unrelated-project')
        $r = Invoke-Backup -Env @{ ROOSYNC_SHARED_PATH = $Shared; USERPROFILE = $seat.Home; ROOSYNC_MACHINE_ID = 'm' } -ArgList $BaseArgs
        $r.ExitCode | Should -Be 1
        $r.Output | Should -Match 'no memory dir found'
        $r.Output | Should -Match '-MemoryDir'
    }

    It 'refuses an ambiguous memory dir instead of guessing' {
        $seat = New-FakeSeat 'seatD' @('a-roo-extensions', 'b-roo-extensions')
        $r = Invoke-Backup -Env @{ ROOSYNC_SHARED_PATH = $Shared; USERPROFILE = $seat.Home; ROOSYNC_MACHINE_ID = 'm' } -ArgList $BaseArgs
        $r.ExitCode | Should -Be 1
        $r.Output | Should -Match 'ambiguous memory dir'
        $r.Output | Should -Match 'a-roo-extensions'
        $r.Output | Should -Match 'b-roo-extensions'
    }

    It 'fails loud with no ROOSYNC_SHARED_PATH and no -TargetRoot (no drive letter assumed)' {
        $r = Invoke-Backup -Env @{ ROOSYNC_SHARED_PATH = $null; USERPROFILE = $Seat.Home; ROOSYNC_MACHINE_ID = 'm' } -ArgList $BaseArgs
        $r.ExitCode | Should -Be 1
        $r.Output | Should -Match 'ROOSYNC_SHARED_PATH'
        $r.Output | Should -Not -Match 'G:\\Mon Drive'
    }

    It 'honours an explicit -TargetRoot over the derived one' {
        $explicit = Join-Path $Tmp 'explicit-root'
        $r = Invoke-Backup -Env @{ ROOSYNC_SHARED_PATH = $Shared; USERPROFILE = $Seat.Home; ROOSYNC_MACHINE_ID = 'm' } -ArgList ($BaseArgs + @('-TargetRoot', $explicit))
        $r.ExitCode | Should -Be 0 -Because $r.Output
        $r.Output | Should -Match ([regex]::Escape($explicit))
    }

    It 'resolves a worktree RepoRoot back to its main checkout' {
        # <main>\.claude\worktrees\wt-x -> <main>: otherwise the lane label and
        # the RSM .env path would point inside a throwaway worktree.
        $main = Join-Path $Tmp 'main-repo'
        $wt = Join-Path $main '.claude\worktrees\wt-x'
        New-Item -ItemType Directory -Force $wt | Out-Null
        # The discovered lane must be the MAIN repo's ('main-repo'), so the fake
        # seat carries a project dir for that leaf and none for 'wt-x'.
        $seat = New-FakeSeat 'seatE' @('c--main-repo')
        $r = Invoke-Backup -Env @{ ROOSYNC_SHARED_PATH = $Shared; USERPROFILE = $seat.Home; ROOSYNC_MACHINE_ID = 'm' } -ArgList @('-WhatIf', '-RepoRoot', $wt)
        # No .env under the main fixture -> the guard names the RESOLVED path.
        # Matched on a whitespace-stripped copy: PS folds long paths at 120 cols.
        $r.ExitCode | Should -Be 1
        $flat = ($r.Output -replace '\s+', '')
        $flat | Should -Match 'main-repo.*mcps.*roo-state-manager.*\.env' -Because $r.Output
        $flat | Should -Not -Match 'wt-x.*mcps'
    }
}

AfterAll {
    if (Test-Path $Tmp) { Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue }
}
