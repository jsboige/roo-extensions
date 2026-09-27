# Pester 5 tests for migrate-roosync-storage.ps1 — Plan Marshall (audit 27/09, dispatch ai-01 18:39Z).
#
# Invariants guarded (the pre-fix script violated all of them):
#   1. dry-run by default — no write of any kind;
#   2. a partially-copied tree aborts BEFORE any rename, .bak preserved;
#   3. a same-count-but-altered copy aborts too (SHA256 guard, not just count);
#   4. happy path -Apply: target populated (incl. subdirs), source renamed .bak;
#   5. a pre-existing .bak is preserved (timestamped), never deleted.
#
# INJECTED FAULTS (bench-of-fault discipline): tests 2 and 3 mock Copy-Item to
# simulate a silently-partial / silently-corrupted copy — exactly the audit
# scenario. A mock cannot cross a process boundary, so those two run the script
# IN-PROCESS (host = pwsh 7). Tests 1, 4, 5 run the TARGET as a child
# powershell.exe (5.1), the engine the fleet invokes this script with.
#
# Every test uses -SourcePath/-TargetPath overrides into a temp dir: the real
# store and the real .env are never read or written.
#
# Run:  pwsh -File scripts/testing/run-pester-tests.ps1 -Path scripts/roosync/migrate-roosync-storage.Tests.ps1

BeforeAll {
    $target = Join-Path $PSScriptRoot 'migrate-roosync-storage.ps1'
    $script:tmp = Join-Path ([IO.Path]::GetTempPath()) ("mrs-test-" + [guid]::NewGuid().ToString('N'))

    # Flat source (3 files) for the in-process fault-injection tests.
    $script:srcFlat = Join-Path $script:tmp 'src-flat'
    New-Item -ItemType Directory -Path $script:srcFlat -Force | Out-Null
    'alpha'   | Set-Content (Join-Path $script:srcFlat 'a.txt')
    'beta'    | Set-Content (Join-Path $script:srcFlat 'b.txt')
    'gamma'   | Set-Content (Join-Path $script:srcFlat 'c.txt')

    # Nested source (2 root files + 2 in a subdir = 4 files) for integration tests.
    $script:srcNested = Join-Path $script:tmp 'src-nested'
    New-Item -ItemType Directory -Path (Join-Path $script:srcNested 'sub') -Force | Out-Null
    'root-1' | Set-Content (Join-Path $script:srcNested 'r1.txt')
    'root-2' | Set-Content (Join-Path $script:srcNested 'r2.txt')
    'sub-1'  | Set-Content (Join-Path $script:srcNested 'sub\s1.txt')
    'sub-2'  | Set-Content (Join-Path $script:srcNested 'sub\s2.txt')
}

AfterAll {
    Remove-Item -LiteralPath $script:tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'migrate-roosync-storage.ps1 — integration (child powershell.exe 5.1)' {
    It 'default invocation is a dry-run: plans, writes nothing' {
        $dst = Join-Path $script:tmp 'dst-dry'
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $target -SourcePath $script:srcFlat -TargetPath $dst 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        $out | Should -Match '\[DRY\] 3 fichiers'
        Test-Path -LiteralPath $dst | Should -BeFalse
        (Get-ChildItem -LiteralPath $script:srcFlat -File).Count | Should -Be 3
    }

    It '-Apply happy path: copies 4 files incl. subdir, renames source to .bak' {
        $src = Join-Path $script:tmp 'src-happy'
        New-Item -ItemType Directory -Path (Join-Path $src 'sub') -Force | Out-Null
        'root-1' | Set-Content (Join-Path $src 'r1.txt')
        'root-2' | Set-Content (Join-Path $src 'r2.txt')
        'sub-1'  | Set-Content (Join-Path $src 'sub\s1.txt')
        'sub-2'  | Set-Content (Join-Path $src 'sub\s2.txt')
        $dst = Join-Path $script:tmp 'dst-happy'

        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $target -Apply -SourcePath $src -TargetPath $dst 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        $out | Should -Match 'Integrite verifiee : 4 fichiers'
        (Get-ChildItem -LiteralPath $dst -Recurse -File).Count | Should -Be 4
        (Get-FileHash -LiteralPath (Join-Path "$src.bak" 'sub\s1.txt')).Hash |
            Should -Be (Get-FileHash -LiteralPath (Join-Path $dst 'sub\s1.txt')).Hash
        Test-Path -LiteralPath $src | Should -BeFalse
        Test-Path -LiteralPath "$src.bak" | Should -BeTrue
    }

    It 'pre-existing .bak is preserved (timestamped), never deleted' {
        $src = Join-Path $script:tmp 'src-bak'
        New-Item -ItemType Directory -Path $src -Force | Out-Null
        'only' | Set-Content (Join-Path $src 'one.txt')
        $oldBak = "$src.bak"
        New-Item -ItemType Directory -Path $oldBak -Force | Out-Null
        'marker-previous-backup' | Set-Content (Join-Path $oldBak 'keepme.txt')
        $dst = Join-Path $script:tmp 'dst-bak'

        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $target -Apply -SourcePath $src -TargetPath $dst 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0

        # Exactly two .bak* dirs: the fresh one (renamed source) + the old one (timestamped).
        $baks = @(Get-ChildItem -LiteralPath $script:tmp -Directory -Filter 'src-bak.bak*')
        $baks.Count | Should -Be 2
        # The old backup survives somewhere with its marker intact:
        $marker = $baks | Where-Object {
            (Test-Path -LiteralPath (Join-Path $_.FullName 'keepme.txt')) -and
            (Get-Content (Join-Path $_.FullName 'keepme.txt') -Raw) -match 'marker-previous-backup'
        }
        @($marker).Count | Should -Be 1
    }
}

Describe 'migrate-roosync-storage.ps1 — injected faults (in-process, host = pwsh)' {
    It 'silently-partial copy (shadowed Copy-Item copies 1 of 3): aborts BEFORE rename, source and .bak untouched' {
        $dst = Join-Path $script:tmp 'dst-partial'
        New-Item -ItemType Directory -Path $dst -Force | Out-Null

        # FAULT INJECTED via function shadowing (functions outrank cmdlets in command
        # resolution, so the target script's Copy-Item call lands here; a Pester Mock
        # cannot reach a script invoked with & under Pester 6's new script scope).
        # The fault: copy only the first file, report success — the audit's
        # "partial copy then rename the source" scenario, reproduced deterministically.
        function Copy-Item {
            param([string]$Path, [string]$Destination, [switch]$Recurse, [switch]$Force, [string]$ErrorAction)
            $one = Get-ChildItem -Path $Path -Recurse -File | Select-Object -First 1
            Microsoft.PowerShell.Management\Copy-Item -LiteralPath $one.FullName -Destination (Join-Path $Destination $one.Name)
        }

        $err = $null
        try { & $target -Apply -SourcePath $script:srcFlat -TargetPath $dst *>&1 | Out-Null } catch { $err = $_.Exception.Message }

        $err | Should -Match 'nombre de fichiers : 3 source vs 1 copie'
        Test-Path -LiteralPath $script:srcFlat | Should -BeTrue
        Test-Path -LiteralPath "$($script:srcFlat).bak" | Should -BeFalse
        (Get-ChildItem -LiteralPath $script:srcFlat -File).Count | Should -Be 3
    }

    It 'same-count altered copy (shadowed Copy-Item corrupts the 3rd payload): SHA256 guard aborts' {
        $dst = Join-Path $script:tmp 'dst-corrupt'
        New-Item -ItemType Directory -Path $dst -Force | Out-Null

        # FAULT INJECTED: every file copied, but the 3rd one's payload is replaced —
        # count matches, only the per-file hash can catch it.
        function Copy-Item {
            param([string]$Path, [string]$Destination, [switch]$Recurse, [switch]$Force, [string]$ErrorAction)
            $i = 0
            Get-ChildItem -Path $Path -Recurse -File | ForEach-Object {
                $d = Join-Path $Destination $_.Name
                Microsoft.PowerShell.Management\Copy-Item -LiteralPath $_.FullName -Destination $d
                $i++
                if ($i -eq 3) { 'CORRUPTED' | Set-Content -LiteralPath $d }
            }
        }

        $err = $null
        try { & $target -Apply -SourcePath $script:srcFlat -TargetPath $dst *>&1 | Out-Null } catch { $err = $_.Exception.Message }

        $err | Should -Match 'empreinte différente : c\.txt'
        Test-Path -LiteralPath $script:srcFlat | Should -BeTrue
        Test-Path -LiteralPath "$($script:srcFlat).bak" | Should -BeFalse
    }
}
