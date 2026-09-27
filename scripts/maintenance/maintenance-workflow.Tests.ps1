# Pester tests for maintenance-workflow.ps1 — Plan Marshall (audit 27/09, dispatch ai-01 18:39Z).
#
# INJECTED PATH under guard (the pre-fix script violated all of these):
#   1. cleanup choice "all" QUARANTINES the .bak files (moved to backups/_trash-<ts>/),
#      never Remove-Item — deletion becomes an explicit manual gesture;
#   2. cleanup answered N moves nothing (closed control);
#   3. restore archives the CURRENT file as *.pre-restore-<ts>.bak BEFORE overwriting it;
#   4. the menu actually renders (pre-existing bug: Write-Output inside Write-ColorOutput
#      polluted the captured $choice of Show-MainMenu, so the menu never displayed and
#      every keystroke fell into the switch default).
#
# The script is interactive (Read-Host menu); tests drive it via stdin redirection in a
# child powershell.exe 5.1 (the fleet's engine), CWD = an isolated temp dir holding a
# fixtures-only backups/ — the repo's own tree is never touched. Option 7 calls no
# sub-script, so it runs from any CWD that holds backups/.
#
# NOTE: the main loop is duplicated in the source (pre-existing bug, documented in the
# audit verdict, not fixed here) — the menu restarts after "Fin du script", so the exit
# sequence is "8" twice.
#
# Run:  pwsh -File scripts/testing/run-pester-tests.ps1 -Path scripts/maintenance/maintenance-workflow.Tests.ps1

BeforeAll {
    $target = Join-Path $PSScriptRoot 'maintenance-workflow.ps1'
    $script:tmp = Join-Path ([IO.Path]::GetTempPath()) ("mwf-test-" + [guid]::NewGuid().ToString('N'))

    # Creates <tmp>/<CaseDir>/backups and writes each fixture (pscustomobject N=name,
    # C=content) in array order. pscustomobject on purpose: a single-element array of
    # ARRAYS flattens in PowerShell (@(@('a','b')) -eq @('a','b')), an array of
    # pscustomobjects does not — one-fixture cases would silently iterate the strings.
    function New-MenuCase {
        param([string]$CaseDir, [object[]]$Fixtures = @())
        $dir = Join-Path $script:tmp $CaseDir
        $bdir = Join-Path $dir 'backups'
        New-Item -ItemType Directory -Path $bdir -Force | Out-Null
        foreach ($f in $Fixtures) {
            Set-Content -LiteralPath (Join-Path $bdir $f.N) -Value $f.C
        }
        return $dir
    }

    # Drives the menu once with the given stdin lines, CWD = the case dir.
    function Invoke-WorkflowMenu {
        param([string[]]$Lines, [string]$Dir)
        ($Lines -join "`r`n") | Set-Content -LiteralPath (Join-Path $Dir 'in.txt') -NoNewline
        Push-Location $Dir
        try {
            cmd.exe /c ("powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"{0}`" < in.txt > out.txt 2>&1" -f $target)
            $code = $LASTEXITCODE
        } finally {
            Pop-Location
        }
        return @{ Dir = $Dir; Exit = $code; Out = (Get-Content -LiteralPath (Join-Path $Dir 'out.txt') -Raw -ErrorAction SilentlyContinue) }
    }
}

AfterAll {
    Remove-Item -LiteralPath $script:tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'maintenance-workflow.ps1 — option 7 backup management (child powershell.exe 5.1)' {
    It 'cleanup "all" answered O: .bak files are QUARANTINED (moved to _trash-<ts>), not deleted' {
        $dir = New-MenuCase -CaseDir 'quarantine' -Fixtures @(
            [pscustomobject]@{ N = 'x.bak'; C = 'x-content' },
            [pscustomobject]@{ N = 'y.bak'; C = 'y-content' })
        $r = Invoke-WorkflowMenu -Lines @('7', '2', '4', 'O', '', '8', '8') -Dir $dir
        $r.Exit | Should -Be 0
        $trash = @(Get-ChildItem -LiteralPath (Join-Path $r.Dir 'backups') -Directory -Filter '_trash-*')
        $trash.Count | Should -Be 1
        @(Get-ChildItem -LiteralPath $trash[0].FullName -Filter '*.bak').Count | Should -Be 2
        @(Get-ChildItem -LiteralPath (Join-Path $r.Dir 'backups') -Filter '*.bak').Count | Should -Be 0
        $r.Out | Should -Match 'quarantaine'
    }

    It 'cleanup answered N: nothing moves (closed control)' {
        $dir = New-MenuCase -CaseDir 'cancel' -Fixtures @(
            [pscustomobject]@{ N = 'x.bak'; C = 'keep-me' })
        $r = Invoke-WorkflowMenu -Lines @('7', '2', '4', 'N', '', '8', '8') -Dir $dir
        $r.Exit | Should -Be 0
        (Get-Content -LiteralPath (Join-Path $r.Dir 'backups\x.bak') -Raw) | Should -Match 'keep-me'
        @(Get-ChildItem -LiteralPath (Join-Path $r.Dir 'backups') -Directory -Filter '_trash-*').Count | Should -Be 0
    }

    It 'restore answered O: current file archived as .pre-restore-<ts>.bak BEFORE being overwritten' {
        # b.bak written last = most recent -> sorted LastWriteTime DESC -> menu index 0;
        # restoring it overwrites backups\b (its .bak-stripped sibling).
        $dir = New-MenuCase -CaseDir 'restore' -Fixtures @(
            [pscustomobject]@{ N = 'a.bak'; C = 'old-a' },
            [pscustomobject]@{ N = 'b'; C = 'CURRENT-LIVE' },
            [pscustomobject]@{ N = 'b.bak'; C = 'OLD-BACKUP' })
        $r = Invoke-WorkflowMenu -Lines @('7', '1', '1', 'O', '', '8', '8') -Dir $dir
        $r.Exit | Should -Be 0
        (Get-Content -LiteralPath (Join-Path $r.Dir 'backups\b') -Raw) | Should -Match 'OLD-BACKUP'
        $pre = @(Get-ChildItem -LiteralPath (Join-Path $r.Dir 'backups') -Filter 'b.pre-restore-*.bak')
        $pre.Count | Should -Be 1
        (Get-Content -LiteralPath $pre[0].FullName -Raw) | Should -Match 'CURRENT-LIVE'
    }

    It 'menu actually renders (pre-fix: Write-Output polluted the captured $choice, menu never shown)' {
        $dir = New-MenuCase -CaseDir 'menu'
        $r = Invoke-WorkflowMenu -Lines @('8', '8') -Dir $dir
        $r.Exit | Should -Be 0
        $r.Out | Should -Match 'Gestion des sauvegardes'
        $r.Out | Should -Not -Match 'Choix invalide'
    }
}
