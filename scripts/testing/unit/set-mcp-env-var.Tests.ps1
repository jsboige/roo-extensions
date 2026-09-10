# Tests unitaires pour scripts/mcp/set-mcp-env-var.ps1 (#3555)
#
# Setter additif et preservatif d'UNE SEULE variable .env : upsert d'une cle,
# backup preservatif hors depot Git, -WhatIf sans mutation, idempotence,
# UTF-8 sans BOM, valeur jamais affichee.
#
# Syntaxe Pester v5 -- executee en CI par le job `unit-pester` (#3216) via
# scripts/testing/run-pester-tests.ps1. Portable pwsh Windows ET Linux :
# - le script sous test est invoque en PROCESSUS FILS (codes de sortie et
#   -WhatIf testables pour de vrai) ;
# - sous Windows le fils est powershell.exe (5.1) ; sur les runners Linux,
#   fallback pwsh. Le test dedie "executes under 5.1" est SKIPPE si
#   powershell.exe est absent (CI ubuntu) ;
# - fixtures 100% fictives et jetables dans le temp OS, avec un faux depot
#   (repertoire .git) pour rendre la propriete "backup hors repo" testable ;
# - syntaxe volontairement compatible 5.1 : pas de ternaire, pas de ??,
#   pas de && / || (garde pwsh-engine-portability, #2368).
#
# Usage:
#   powershell -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0; Invoke-Pester -Path ./scripts/testing/unit/set-mcp-env-var.Tests.ps1 -Output Detailed"

BeforeAll {
    $projectRoot     = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $script:SetterPath = Join-Path -Path $projectRoot -ChildPath 'scripts/mcp/set-mcp-env-var.ps1'

    # Fils : powershell.exe (5.1) si dispo (Windows), sinon pwsh (runners Linux).
    $cmd51 = Get-Command -Name powershell.exe -ErrorAction SilentlyContinue
    if ($cmd51) {
        $script:SetterPsExe = $cmd51.Source
        $script:HasPs51    = $true
    } else {
        $script:SetterPsExe = (Get-Command -Name pwsh -ErrorAction Stop).Source
        $script:HasPs51    = $false
    }

    # Fixture jetable : racine dans le temp OS (hors de tout vrai depot Git),
    # faux depot fixture-repo/.git, .env fictif, backup dir voisine hors repo.
    function New-SetterFixtureRoot {
        param([string]$EnvContent)
        $root    = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('set-mcp-env-var-' + [guid]::NewGuid().ToString('N'))
        $repoDir = Join-Path -Path $root -ChildPath 'fixture-repo'
        New-Item -ItemType Directory -Path (Join-Path -Path $repoDir -ChildPath '.git') -Force | Out-Null
        $envPath = Join-Path -Path $repoDir -ChildPath '.env'
        [System.IO.File]::WriteAllText($envPath, $EnvContent, (New-Object System.Text.UTF8Encoding($false)))
        $backupDir = Join-Path -Path $root -ChildPath 'backups-outside-repo'
        return [pscustomobject]@{ Root = $root; Repo = $repoDir; EnvPath = $envPath; BackupDir = $backupDir }
    }

    function Invoke-EnvSetter {
        param([string]$TargetPath, [string]$Name, [string]$Value, [string]$BackupDir, [switch]$WhatIf)
        $argList = @('-File', $script:SetterPath, '-TargetPath', $TargetPath, '-Name', $Name, '-Value', $Value)
        if ($BackupDir) { $argList += @('-BackupDir', $BackupDir) }
        if ($WhatIf.IsPresent) { $argList += '-WhatIf' }
        $preArgs = @('-NoProfile')
        if ($env:OS -eq 'Windows_NT') { $preArgs += @('-ExecutionPolicy', 'Bypass') }
        $output = & $script:SetterPsExe @preArgs @argList *>&1 | Out-String
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
    }
}

Describe 'set-mcp-env-var - single-key upsert (#3555)' {

    It 'adds an absent key while preserving all unrelated content and ordering' {
        $lines = @(
            '# fixture .env - fictitious values only, never real secrets',
            'ROOSYNC_MACHINE_ID=fictitious-machine',
            'ROOSYNC_SHARED_PATH=/tmp/fictitious-shared',
            '',
            '# legacy commented value, must survive untouched',
            '# SKELETON_PREWARM=true',
            'OTHER_SETTING=fictitious-keep'
        )
        $original = ($lines -join "`n") + "`n"
        $expected = $original + 'SKELETON_PREWARM=fictitious-off' + "`n"
        $fx = New-SetterFixtureRoot -EnvContent $original
        try {
            $res = Invoke-EnvSetter -TargetPath $fx.EnvPath -Name 'SKELETON_PREWARM' -Value 'fictitious-off' -BackupDir $fx.BackupDir
            $res.ExitCode | Should -Be 0
            $res.Output | Should -Match 'SKELETON_PREWARM'
            $res.Output | Should -Match 'ADD'
            [System.IO.File]::ReadAllText($fx.EnvPath) | Should -BeExactly $expected
        } finally { Remove-Item -LiteralPath $fx.Root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'replaces exactly the active assignment, nothing else' {
        $lines = @(
            '# fixture .env - fictitious values only, never real secrets',
            'ROOSYNC_MACHINE_ID=fictitious-machine',
            '',
            'SKELETON_PREWARM=fictitious-on',
            '# commented old value kept on its own line: SKELETON_PREWARM=true',
            '',
            'OTHER_SETTING=fictitious-keep'
        )
        $expectedLines = $lines.Clone()
        $expectedLines[3] = 'SKELETON_PREWARM=fictitious-off'
        $original = ($lines -join "`n") + "`n"
        $expected = ($expectedLines -join "`n") + "`n"
        $fx = New-SetterFixtureRoot -EnvContent $original
        try {
            $res = Invoke-EnvSetter -TargetPath $fx.EnvPath -Name 'SKELETON_PREWARM' -Value 'fictitious-off' -BackupDir $fx.BackupDir
            $res.ExitCode | Should -Be 0
            $res.Output | Should -Match 'REPLACE'
            [System.IO.File]::ReadAllText($fx.EnvPath) | Should -BeExactly $expected
        } finally { Remove-Item -LiteralPath $fx.Root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'fails closed on duplicate active assignments before backup or write' {
        $lines = @(
            'ROOSYNC_MACHINE_ID=fictitious-machine',
            'SKELETON_PREWARM=fictitious-first',
            '# SKELETON_PREWARM=fictitious-commented',
            'SKELETON_PREWARM=fictitious-last',
            'OTHER_SETTING=fictitious-keep'
        )
        $original = ($lines -join "`n") + "`n"
        $fx = New-SetterFixtureRoot -EnvContent $original
        try {
            $originalBytes = [System.IO.File]::ReadAllBytes($fx.EnvPath)
            $res = Invoke-EnvSetter -TargetPath $fx.EnvPath -Name 'SKELETON_PREWARM' -Value 'fictitious-off' -BackupDir $fx.BackupDir
            $res.ExitCode | Should -Be 6
            $res.Output | Should -Match 'multiple active assignments'
            $res.Output | Should -Not -Match 'fictitious-first'
            $res.Output | Should -Not -Match 'fictitious-last'
            $res.Output | Should -Not -Match 'fictitious-off'
            [System.BitConverter]::ToString([System.IO.File]::ReadAllBytes($fx.EnvPath)) |
                Should -BeExactly ([System.BitConverter]::ToString($originalBytes))
            Test-Path -LiteralPath $fx.BackupDir | Should -Be $false
        } finally { Remove-Item -LiteralPath $fx.Root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'preserves CRLF line endings of unrelated lines' {
        $lines = @(
            'ROOSYNC_MACHINE_ID=fictitious-machine',
            'SKELETON_PREWARM=fictitious-on',
            'OTHER_SETTING=fictitious-keep'
        )
        $expectedLines = $lines.Clone()
        $expectedLines[1] = 'SKELETON_PREWARM=fictitious-off'
        $original = ($lines -join "`r`n") + "`r`n"
        $expected = ($expectedLines -join "`r`n") + "`r`n"
        $fx = New-SetterFixtureRoot -EnvContent $original
        try {
            $res = Invoke-EnvSetter -TargetPath $fx.EnvPath -Name 'SKELETON_PREWARM' -Value 'fictitious-off' -BackupDir $fx.BackupDir
            $res.ExitCode | Should -Be 0
            [System.IO.File]::ReadAllText($fx.EnvPath) | Should -BeExactly $expected
        } finally { Remove-Item -LiteralPath $fx.Root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'is an idempotent no-op when already configured (no backup, no write)' {
        $lines = @(
            'ROOSYNC_MACHINE_ID=fictitious-machine',
            'SKELETON_PREWARM=fictitious-off',
            'OTHER_SETTING=fictitious-keep'
        )
        $original = ($lines -join "`n") + "`n"
        $fx = New-SetterFixtureRoot -EnvContent $original
        try {
            $res = Invoke-EnvSetter -TargetPath $fx.EnvPath -Name 'SKELETON_PREWARM' -Value 'fictitious-off' -BackupDir $fx.BackupDir
            $res.ExitCode | Should -Be 0
            $res.Output | Should -Match 'NO-CHANGE'
            [System.IO.File]::ReadAllText($fx.EnvPath) | Should -BeExactly $original
            $backupCount = 0
            if (Test-Path -LiteralPath $fx.BackupDir) {
                $backupCount = @(Get-ChildItem -LiteralPath $fx.BackupDir -File).Count
            }
            $backupCount | Should -Be 0
        } finally { Remove-Item -LiteralPath $fx.Root -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Describe 'set-mcp-env-var - WhatIf dry-run (#3555)' {

    It '-WhatIf performs no file or backup mutation' {
        $lines = @(
            'ROOSYNC_MACHINE_ID=fictitious-machine',
            'SKELETON_PREWARM=fictitious-on'
        )
        $original = ($lines -join "`n") + "`n"
        $originalBytes = [System.Text.UTF8Encoding]::UTF8.GetBytes($original)
        $fx = New-SetterFixtureRoot -EnvContent $original
        try {
            $res = Invoke-EnvSetter -TargetPath $fx.EnvPath -Name 'SKELETON_PREWARM' -Value 'fictitious-off' -BackupDir $fx.BackupDir -WhatIf
            $res.ExitCode | Should -Be 0
            $res.Output | Should -Match 'SKELETON_PREWARM'
            $res.Output | Should -Match 'dry-run'
            [System.BitConverter]::ToString([System.IO.File]::ReadAllBytes($fx.EnvPath)) |
                Should -BeExactly ([System.BitConverter]::ToString($originalBytes))
            Test-Path -LiteralPath $fx.BackupDir | Should -Be $false
        } finally { Remove-Item -LiteralPath $fx.Root -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Describe 'set-mcp-env-var - preservative backup (#3555)' {

    It 'writes a byte-identical backup outside the fixture repository before mutating' {
        $lines = @(
            'ROOSYNC_MACHINE_ID=fictitious-machine',
            'SKELETON_PREWARM=fictitious-on'
        )
        $original = ($lines -join "`n") + "`n"
        $fx = New-SetterFixtureRoot -EnvContent $original
        try {
            $originalBytes = [System.IO.File]::ReadAllBytes($fx.EnvPath)
            $res = Invoke-EnvSetter -TargetPath $fx.EnvPath -Name 'SKELETON_PREWARM' -Value 'fictitious-off' -BackupDir $fx.BackupDir
            $res.ExitCode | Should -Be 0
            $backupPath = $null
            if ($res.Output -match 'backup -> (.+)') { $backupPath = $Matches[1].Trim() }
            $backupPath | Should -Not -BeNullOrEmpty
            Test-Path -LiteralPath $backupPath | Should -Be $true
            # hors du depot fixture (propriete "backup outside Git repositories")
            $backupPath -like "$($fx.Repo)*" | Should -Be $false
            $backupPath -like "$($fx.BackupDir)*" | Should -Be $true
            # byte-identique a l'original
            [System.BitConverter]::ToString([System.IO.File]::ReadAllBytes($backupPath)) |
                Should -BeExactly ([System.BitConverter]::ToString($originalBytes))
        } finally { Remove-Item -LiteralPath $fx.Root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'refuses a backup dir inside a Git repository (no mutation)' {
        $lines = @(
            'SKELETON_PREWARM=fictitious-on'
        )
        $original = ($lines -join "`n") + "`n"
        $fx = New-SetterFixtureRoot -EnvContent $original
        $insideDir = Join-Path -Path $fx.Repo -ChildPath 'backups-inside-repo'
        try {
            $res = Invoke-EnvSetter -TargetPath $fx.EnvPath -Name 'SKELETON_PREWARM' -Value 'fictitious-off' -BackupDir $insideDir
            $res.ExitCode | Should -Be 4
            [System.IO.File]::ReadAllText($fx.EnvPath) | Should -BeExactly $original
            Test-Path -LiteralPath $insideDir | Should -Be $false
        } finally { Remove-Item -LiteralPath $fx.Root -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Describe 'set-mcp-env-var - output hygiene and encoding (#3555)' {

    It 'output carries the variable name and status, never the value (old or new)' {
        $lines = @(
            'ROOSYNC_MACHINE_ID=fictitious-machine',
            'SKELETON_PREWARM=fictitious-on'
        )
        $original = ($lines -join "`n") + "`n"
        $fx = New-SetterFixtureRoot -EnvContent $original
        try {
            $res = Invoke-EnvSetter -TargetPath $fx.EnvPath -Name 'SKELETON_PREWARM' -Value 'fictitious-off' -BackupDir $fx.BackupDir
            $res.ExitCode | Should -Be 0
            $res.Output | Should -Match 'SKELETON_PREWARM'
            $res.Output | Should -Match 'REPLACE'
            $res.Output | Should -Not -Match 'fictitious-off'
            $res.Output | Should -Not -Match 'fictitious-on'
        } finally { Remove-Item -LiteralPath $fx.Root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'writes the result as UTF-8 without BOM' {
        $lines = @(
            'SKELETON_PREWARM=fictitious-on'
        )
        $original = ($lines -join "`n") + "`n"
        $fx = New-SetterFixtureRoot -EnvContent $original
        try {
            $res = Invoke-EnvSetter -TargetPath $fx.EnvPath -Name 'SKELETON_PREWARM' -Value 'fictitious-off' -BackupDir $fx.BackupDir
            $res.ExitCode | Should -Be 0
            $bytes = [System.IO.File]::ReadAllBytes($fx.EnvPath)
            $prefix = [System.BitConverter]::ToString($bytes, 0, [Math]::Min(3, $bytes.Length))
            $prefix | Should -Not -Be 'EF-BB-BF'
        } finally { Remove-Item -LiteralPath $fx.Root -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Describe 'set-mcp-env-var - PowerShell 5.1 compatibility (#3555)' {

    It 'parses cleanly under the PowerShell 5.1 language parser' {
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:SetterPath, [ref]$tokens, [ref]$errors) | Out-Null
        $errors.Count | Should -Be 0
    }

    It 'executes a full upsert under Windows PowerShell 5.1' {
        if (-not $script:HasPs51) {
            Set-ItResult -Skipped -Because 'powershell.exe not available (non-Windows runner)'
        }
        $lines = @(
            'ROOSYNC_MACHINE_ID=fictitious-machine',
            'SKELETON_PREWARM=fictitious-on',
            'OTHER_SETTING=fictitious-keep'
        )
        $expectedLines = $lines.Clone()
        $expectedLines[1] = 'SKELETON_PREWARM=fictitious-off'
        $original = ($lines -join "`n") + "`n"
        $expected = ($expectedLines -join "`n") + "`n"
        $fx = New-SetterFixtureRoot -EnvContent $original
        try {
            # Invoke-EnvSetter privilegie powershell.exe (5.1) quand il existe.
            $res = Invoke-EnvSetter -TargetPath $fx.EnvPath -Name 'SKELETON_PREWARM' -Value 'fictitious-off' -BackupDir $fx.BackupDir
            $res.ExitCode | Should -Be 0
            [System.IO.File]::ReadAllText($fx.EnvPath) | Should -BeExactly $expected
        } finally { Remove-Item -LiteralPath $fx.Root -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
