# sk-agent-daemon.Tests.ps1 - Pester suite for the #4149 F2 seat scripts
#
# Covers: PS 5.1 parseability of the three scripts, the client-config flip
# (backup, idempotence, restore, single-element array survival through the
# JSON round-trip, key never printed), and the dry-run purity of the daemon
# starter (-WhatIf writes nothing, not even the key file) and of the schtask
# installer.
#
# Run: Invoke-Pester scripts/testing/unit/sk-agent-daemon.Tests.ps1

BeforeAll {
    $script:DeployDir = Join-Path $PSScriptRoot '..\..\deployment' | Resolve-Path
    $script:StartScript = Join-Path $DeployDir 'start-sk-agent-daemon.ps1'
    $script:ConfigureScript = Join-Path $DeployDir 'configure-sk-agent-http-client.ps1'
    $script:InstallScript = Join-Path $DeployDir 'install-sk-agent-daemon-schtask.ps1'
    $script:Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("sk-agent-daemon-tests-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force $Tmp | Out-Null

    function Invoke-SeatScript([string]$Path, [string[]]$ArgList) {
        # powershell.exe (5.1) on purpose: the scripts must behave under the
        # oldest engine the fleet runs (shell-fallback.md).
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Path @ArgList 2>&1
        [PSCustomObject]@{ Output = ($out -join "`n"); ExitCode = $LASTEXITCODE }
    }
}

Describe 'sk-agent daemon scripts parse under PS 5.1' {
    It 'all three scripts parse without errors' {
        foreach ($f in @($StartScript, $ConfigureScript, $InstallScript)) {
            $errs = $null
            [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$null, [ref]$errs) | Out-Null
            @($errs).Count | Should -Be 0 -Because "$f must parse under the PS 5.1 parser"
        }
    }
}

Describe 'configure-sk-agent-http-client.ps1' {
    BeforeAll {
        $script:CfgPath = Join-Path $Tmp 'claude.json'
        $script:KeyPath = Join-Path $Tmp 'daemon-api.key'
        # Deliberately single-element arrays: the PS 5.1 round-trip is the
        # regression risk this suite pins (an args array collapsing to a
        # scalar would corrupt every other stdio server in the file).
        @'
{
  "numStartups": 42,
  "mcpServers": {
    "sk-agent": { "type": "", "command": "powershell", "args": ["-File", "run-sk-agent.ps1"] },
    "other-server": { "command": "node", "args": ["server.js", "--http"], "env": { "ONLY_ONE": "x" } }
  }
}
'@ | Set-Content $CfgPath -Encoding ascii
        'pester-fixture-key-not-secret-aaaa' | Set-Content $KeyPath -Encoding ascii
        $script:OriginalHash = (Get-FileHash $CfgPath -Algorithm SHA256).Hash
    }

    It 'flips the stdio entry to http with the daemon bearer' {
        $r = Invoke-SeatScript $ConfigureScript @('-ConfigPath', $CfgPath, '-KeyFile', $KeyPath)
        $r.ExitCode | Should -Be 0
        $r.Output | Should -Match 'sk-agent : .* -> http'
        $cfg = Get-Content $CfgPath -Raw | ConvertFrom-Json
        $cfg.mcpServers.'sk-agent'.type | Should -Be 'http'
        $cfg.mcpServers.'sk-agent'.url | Should -Be 'http://127.0.0.1:8100/mcp'
        $cfg.mcpServers.'sk-agent'.headers.Authorization | Should -Be 'Bearer pester-fixture-key-not-secret-aaaa'
    }

    It 'never prints the key' {
        $r = Invoke-SeatScript $ConfigureScript @('-ConfigPath', $CfgPath, '-KeyFile', $KeyPath)
        $r.Output | Should -Not -Match 'pester-fixture-key-not-secret-aaaa'
    }

    It 'leaves other servers and top-level keys intact (single-element arrays survive)' {
        $cfg = Get-Content $CfgPath -Raw | ConvertFrom-Json
        $cfg.numStartups | Should -Be 42
        $cfg.mcpServers.'other-server'.command | Should -Be 'node'
        @($cfg.mcpServers.'other-server'.args).Count | Should -Be 2
        $cfg.mcpServers.'other-server'.args[0] | Should -Be 'server.js'
    }

    It 'creates a backup before mutating' {
        @((Get-ChildItem $Tmp -Filter 'claude.json.bak-*')).Count | Should -BeGreaterThan 0
    }

    It 'is idempotent: a second run is a no-op (file unchanged)' {
        $h1 = (Get-FileHash $CfgPath -Algorithm SHA256).Hash
        $r = Invoke-SeatScript $ConfigureScript @('-ConfigPath', $CfgPath, '-KeyFile', $KeyPath)
        $r.ExitCode | Should -Be 0
        $r.Output | Should -Match 'already points'
        (Get-FileHash $CfgPath -Algorithm SHA256).Hash | Should -Be $h1
    }

    It 'fails loud when the key file is missing (no mutation)' {
        $h1 = (Get-FileHash $CfgPath -Algorithm SHA256).Hash
        $r = Invoke-SeatScript $ConfigureScript @('-ConfigPath', $CfgPath, '-KeyFile', (Join-Path $Tmp 'nope.key'))
        $r.ExitCode | Should -Be 1
        $r.Output | Should -Match 'key file not found'
        (Get-FileHash $CfgPath -Algorithm SHA256).Hash | Should -Be $h1
    }

    It 'restores the original config with -Restore' {
        $r = Invoke-SeatScript $ConfigureScript @('-ConfigPath', $CfgPath, '-Restore')
        $r.ExitCode | Should -Be 0
        (Get-FileHash $CfgPath -Algorithm SHA256).Hash | Should -Be $OriginalHash
        $cfg = Get-Content $CfgPath -Raw | ConvertFrom-Json
        $cfg.mcpServers.'sk-agent'.command | Should -Be 'powershell'
    }
}

Describe 'start-sk-agent-daemon.ps1 dry-run purity' {
    BeforeAll {
        # Fixture layout: a stub sk_agent.py so the suite never depends on a
        # populated submodule (the CI unit-pester job checks out the parent
        # repo without submodules).
        $script:FxDir = Join-Path $Tmp 'fake-sk-agent'
        New-Item -ItemType Directory -Force $FxDir | Out-Null
        '# stub' | Set-Content (Join-Path $FxDir 'sk_agent.py') -Encoding ascii
    }

    It '-WhatIf writes nothing (no key file, no log dir)' -Skip:($env:OS -ne 'Windows_NT') {
        $freshKey = Join-Path $Tmp 'fresh-daemon.key'
        $freshLog = Join-Path $Tmp 'fresh-logs'
        $r = Invoke-SeatScript $StartScript @('-WhatIf', '-Port', '8399', '-SkAgentDir', $FxDir, '-KeyFile', $freshKey, '-LogDir', $freshLog)
        $r.ExitCode | Should -Be 0 -Because $r.Output
        $r.Output | Should -Match 'WhatIf'
        Test-Path $freshKey | Should -BeFalse
        Test-Path $freshLog | Should -BeFalse
    }

    It 'fails loud when sk_agent.py is absent (submodule hint)' {
        $r = Invoke-SeatScript $StartScript @('-RepoRoot', $Tmp)
        $r.ExitCode | Should -Be 1
        $r.Output | Should -Match 'sk_agent.py not found'
        $r.Output | Should -Match 'submodule'
    }
}

Describe 'install-sk-agent-daemon-schtask.ps1 dry-run purity' {
    It '-WhatIf registers nothing' -Skip:($env:OS -ne 'Windows_NT') {
        $r = Invoke-SeatScript $InstallScript @('-WhatIf', '-TaskName', 'Claude-SkAgent-Daemon-PesterProbe')
        $r.ExitCode | Should -Be 0 -Because $r.Output
        $r.Output | Should -Match 'WhatIf'
        (Get-ScheduledTask -TaskName 'Claude-SkAgent-Daemon-PesterProbe' -ErrorAction SilentlyContinue) | Should -BeNullOrEmpty
    }
}

Describe 'configure-sk-agent-http-client.ps1 content integrity (regression 2026-10-28)' {
    BeforeAll {
        # UTF-8 WITHOUT BOM on purpose: that is the real ~/.claude.json shape,
        # and the shape `Get-Content -Raw` mis-decodes as ANSI under PS 5.1.
        $script:EncDir = Join-Path $Tmp 'enc'
        New-Item -ItemType Directory -Force $EncDir | Out-Null
        $script:EncCfg = Join-Path $EncDir 'claude.json'
        $script:UnicodeProbe = @('Fable 5.1 · capable — ünïcode', 'bar ███░░', 'Usage limit reached · credits')
        $payload = [PSCustomObject]@{
            numStartups = 7
            description = $UnicodeProbe[0]
            banner      = $UnicodeProbe[1]
            menu        = $UnicodeProbe[2]
            mcpServers  = [PSCustomObject]@{
                'sk-agent' = [PSCustomObject]@{ command = 'powershell'; args = @('-File', 'run-sk-agent.ps1') }
            }
        }
        [IO.File]::WriteAllText($EncCfg, ($payload | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
        $script:EncKey = Join-Path $EncDir 'k.key'
        'pester-fixture-key-not-secret-bbbb' | Set-Content $EncKey -Encoding ascii
        $r = Invoke-SeatScript $ConfigureScript @('-ConfigPath', $EncCfg, '-KeyFile', $EncKey)
        if ($r.ExitCode -ne 0) { throw "configure failed: $($r.Output)" }
        $script:EncRaw = [IO.File]::ReadAllText($EncCfg)
    }

    It 'keeps every non-ASCII string byte-faithful through the flip' {
        foreach ($probe in $UnicodeProbe) { $EncRaw | Should -Match ([regex]::Escape($probe)) -Because "the flip must not re-encode '$probe'" }
        $EncRaw | Should -Not -Match 'Â·|â€|Ã¼' -Because 'mojibake means the read path decoded UTF-8 as ANSI'
    }

    It 'still flipped the entry' {
        $cfg = [IO.File]::ReadAllText($EncCfg) | ConvertFrom-Json
        $cfg.mcpServers.'sk-agent'.type | Should -Be 'http'
    }
}

Describe 'configure-sk-agent-http-client.ps1 -Restore picks by TIME, not by name' {
    BeforeAll {
        $script:RDir = Join-Path $Tmp 'rest'
        New-Item -ItemType Directory -Force $RDir | Out-Null
        $script:RCfg = Join-Path $RDir 'claude.json'
        '{"numStartups":1,"mcpServers":{"sk-agent":{"command":"current"}}}' | Set-Content $RCfg -Encoding ascii
        # A foreign backup whose NAME sorts above ours ('s' > '2') but whose
        # mtime is older: the bug picked this one and rolled the seat back weeks.
        $foreign = Join-Path $RDir 'claude.json.bak-skagent-20200101'
        '{"numStartups":1,"mcpServers":{"sk-agent":{"command":"FOREIGN-STALE"}}}' | Set-Content $foreign -Encoding ascii
        (Get-Item $foreign).LastWriteTimeUtc = [datetime]::UtcNow.AddHours(-48)
        $own = Join-Path $RDir 'claude.json.bak-20260101-000000'
        '{"numStartups":1,"mcpServers":{"sk-agent":{"command":"OWN-NEWEST"}}}' | Set-Content $own -Encoding ascii
        (Get-Item $own).LastWriteTimeUtc = [datetime]::UtcNow.AddHours(-1)
    }

    It 'restores the newest own-pattern backup, never the foreign one' {
        $r = Invoke-SeatScript $ConfigureScript @('-ConfigPath', $RCfg, '-Restore')
        $r.ExitCode | Should -Be 0 -Because $r.Output
        $r.Output | Should -Match 'bak-20260101-000000'
        (Get-Content $RCfg -Raw | ConvertFrom-Json).mcpServers.'sk-agent'.command | Should -Be 'OWN-NEWEST'
    }

    It 'honours an explicit -RestorePath' {
        $r = Invoke-SeatScript $ConfigureScript @('-ConfigPath', $RCfg, '-Restore', '-RestorePath', (Join-Path $RDir 'claude.json.bak-skagent-20200101'))
        $r.ExitCode | Should -Be 0 -Because $r.Output
        (Get-Content $RCfg -Raw | ConvertFrom-Json).mcpServers.'sk-agent'.command | Should -Be 'FOREIGN-STALE'
    }

    It 'fails loud when no own-pattern backup exists (no silent foreign rollback)' {
        $lonely = Join-Path $Tmp 'lonely'
        New-Item -ItemType Directory -Force $lonely | Out-Null
        $lonelyCfg = Join-Path $lonely 'claude.json'
        '{"mcpServers":{"sk-agent":{"command":"keep-me"}}}' | Set-Content $lonelyCfg -Encoding ascii
        '{"mcpServers":{"sk-agent":{"command":"FOREIGN"}}}' | Set-Content (Join-Path $lonely 'claude.json.bak-skagent-20200101') -Encoding ascii
        $h = (Get-FileHash $lonelyCfg -Algorithm SHA256).Hash
        $r = Invoke-SeatScript $ConfigureScript @('-ConfigPath', $lonelyCfg, '-Restore')
        $r.ExitCode | Should -Be 1
        $r.Output | Should -Match 'candidate \(NOT used\)'
        (Get-FileHash $lonelyCfg -Algorithm SHA256).Hash | Should -Be $h
    }
}

AfterAll {
    if (Test-Path $Tmp) { Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue }
}
