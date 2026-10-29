# Tests unitaires pour scripts/deployment/mcp-runtime.lib.ps1 (#4149 F1)
# Launcher flattening : installation per-seat + lancement `node <entry>` direct
# (chaine npx = 4 processus/session -> 1), reprise en charge de searxng avec
# preservation verbatim des champs per-seat (env avec auth, alwaysAllow,
# disabled) — les secrets restent dans ~/.claude.json, jamais dans le depot.
#
# Syntaxe Pester v5 — executé en CI par le job unit-pester (#3216). Portable
# pwsh Windows ET Linux : les chemins node_modules\<pkg> sont construits par les
# MEMES expressions Join-Path que la lib, donc auto-coherents sur chaque OS ;
# aucun test ne reseau (les chemins qui declencheraient npm install ne sont pas
# empruntes — garde structurelle dediee ci-dessous).
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/deploy-mcp-runtime-launchers.Tests.ps1 -Output Detailed"

BeforeAll {
    $script:repoRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    . (Join-Path $repoRoot "scripts/deployment/mcp-runtime.lib.ps1")

    $script:tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) "mcp-runtime-tests-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $tmpRoot -Force | Out-Null

    # Fixture builder — mirrors the exact Join-Path expressions of the lib so
    # the layout is self-consistent on Windows (nested) and Linux (literal).
    function New-RuntimeFixture {
        # $BinJson deliberately UNtyped: a multi-bin manifest arrives as a
        # hashtable, and a [string] cast silently flattens it to
        # "System.Collections.Hashtable" before ConvertTo-Json ever runs.
        param([string]$Name, [string]$Package, [string]$Version, $BinJson, [string]$BinFile)
        $dir = Join-Path $tmpRoot $Name
        $pkgDir = Join-Path $dir ("node_modules\" + $Package)
        New-Item -ItemType Directory -Path $pkgDir -Force | Out-Null
        $manifest = @{ name = $Package; version = $Version; bin = $BinJson } | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText((Join-Path $pkgDir "package.json"), $manifest)
        if ($BinFile) { New-Item -ItemType File -Path (Join-Path $pkgDir $BinFile) -Force | Out-Null }
        return $dir
    }
}

Describe 'Resolve-McpRuntimeEntry (#4149 F1)' {

    It 'resolves the bin entry from the manifest when the installed version matches (string bin)' {
        $dir = New-RuntimeFixture -Name 'playwright' -Package '@playwright/mcp' -Version '0.0.83' -BinJson 'cli.js' -BinFile 'cli.js'
        $spec = @{ Name = 'playwright'; Package = '@playwright/mcp'; Version = '0.0.83' }
        $entry = Resolve-McpRuntimeEntry -Root $tmpRoot -Spec $spec
        $entry | Should -Not -BeNullOrEmpty
        $entry | Should -Be (Join-Path $dir ("node_modules\@playwright\mcp\cli.js"))
    }

    It 'resolves a multi-bin manifest by the bin keyed on the package name' {
        $dir = New-RuntimeFixture -Name 'multi' -Package 'multi-pkg' -Version '1.0.0' -BinJson @{ 'other-bin' = 'other.js'; 'multi-pkg' = 'real.js' } -BinFile 'real.js'
        $spec = @{ Name = 'multi'; Package = 'multi-pkg'; Version = '1.0.0' }
        $entry = Resolve-McpRuntimeEntry -Root $tmpRoot -Spec $spec
        $entry | Should -Be (Join-Path $dir ("node_modules\multi-pkg\real.js"))
    }

    It 'resolves a SCOPED package whose bin key drops the scope (@playwright/mcp shape — caught live on the first real deploy)' {
        $dir = New-RuntimeFixture -Name 'scoped' -Package '@scope/pkg' -Version '1.2.3' -BinJson @{ 'pkg' = 'pkg-cli.js' } -BinFile 'pkg-cli.js'
        $spec = @{ Name = 'scoped'; Package = '@scope/pkg'; Version = '1.2.3' }
        $entry = Resolve-McpRuntimeEntry -Root $tmpRoot -Spec $spec
        $entry | Should -Be (Join-Path $dir ("node_modules\@scope\pkg\pkg-cli.js"))
    }

    It 'falls back to the single bin entry when no key matches the package name' {
        $dir = New-RuntimeFixture -Name 'single' -Package 'some-pkg' -Version '1.0.0' -BinJson @{ 'unrelated-key' = 'solo.js' } -BinFile 'solo.js'
        $spec = @{ Name = 'single'; Package = 'some-pkg'; Version = '1.0.0' }
        $entry = Resolve-McpRuntimeEntry -Root $tmpRoot -Spec $spec
        $entry | Should -Be (Join-Path $dir ("node_modules\some-pkg\solo.js"))
    }

    It 'throws when the bin file is missing from an installed runtime' {
        New-RuntimeFixture -Name 'broken' -Package 'broken-pkg' -Version '1.0.0' -BinJson 'absent.js' -BinFile $null
        $spec = @{ Name = 'broken'; Package = 'broken-pkg'; Version = '1.0.0' }
        { Resolve-McpRuntimeEntry -Root $tmpRoot -Spec $spec } | Should -Throw 'bin entry not found*'
    }

    It 'throws when the manifest has no bin entry' {
        New-RuntimeFixture -Name 'nobin' -Package 'nobin-pkg' -Version '1.0.0' -BinJson $null -BinFile $null
        $spec = @{ Name = 'nobin'; Package = 'nobin-pkg'; Version = '1.0.0' }
        { Resolve-McpRuntimeEntry -Root $tmpRoot -Spec $spec } | Should -Throw 'no bin entry*'
    }

    It 'WhatIf with no install returns the pinned hint path and does not throw' {
        $spec = @{ Name = 'fresh'; Package = 'fresh-pkg'; Version = '9.9.9'; BinHint = 'hint.js' }
        $entry = Resolve-McpRuntimeEntry -Root $tmpRoot -Spec $spec -WhatIf
        $entry | Should -BeLike '*node_modules*fresh-pkg*hint.js*'
    }
}

Describe 'New-SearxngTakeoverConfig (#4149 F1)' {

    It 'preserves env (incl. auth), alwaysAllow and disabled verbatim from the live entry' {
        $existing = @{
            command = 'npx'; args = @('-y', 'mcp-searxng')
        } | ConvertTo-Json | ConvertFrom-Json
        # env with per-seat auth — what must NEVER reach the repo but MUST survive the deploy
        $existing | Add-Member -NotePropertyName 'env' -NotePropertyValue (@{
            SEARXNG_URL = 'https://search.myia.io/'; AUTH_USERNAME = 'seat-user'; AUTH_PASSWORD = 'seat-secret'
        } | ConvertTo-Json | ConvertFrom-Json)
        $existing | Add-Member -NotePropertyName 'alwaysAllow' -NotePropertyValue @('web_url_read', 'searxng_web_search')
        $existing | Add-Member -NotePropertyName 'disabled' -NotePropertyValue $false

        $config = New-SearxngTakeoverConfig -EntryPath 'X:\runtimes\searxng\dist\cli.js' -ExistingEntry $existing

        $config.command | Should -Be 'node'
        $config.args | Should -Be @('X:\runtimes\searxng\dist\cli.js')
        $config.env.SEARXNG_URL | Should -Be 'https://search.myia.io/'
        $config.env.AUTH_USERNAME | Should -Be 'seat-user'
        $config.env.AUTH_PASSWORD | Should -Be 'seat-secret'
        $config.alwaysAllow | Should -Be @('web_url_read', 'searxng_web_search')
        $config.disabled | Should -Be $false
    }

    It 'seeds only the public default URL on a seat with no existing entry' {
        $config = New-SearxngTakeoverConfig -EntryPath 'X:\runtimes\searxng\dist\cli.js' -ExistingEntry $null
        $config.command | Should -Be 'node'
        $config.env.SEARXNG_URL | Should -Be 'https://search.myia.io/'
        $config.Keys | Should -Not -Contain 'alwaysAllow'
        $config.Keys | Should -Not -Contain 'AUTH_PASSWORD'
    }

    It 'adds no env of its own when the live entry carries none (takeover adds nothing)' {
        $existing = @{ command = 'npx' } | ConvertTo-Json | ConvertFrom-Json
        $config = New-SearxngTakeoverConfig -EntryPath 'X:\e.js' -ExistingEntry $existing
        $config.Keys | Should -Not -Contain 'env'
    }

    It 'preserves every NON-launcher field (type, timeout — the RSM-template note, #4411 review)' {
        $existing = @{ command = 'npx'; args = @('-y', 'x'); type = 'stdio'; timeout = 900000 } |
            ConvertTo-Json | ConvertFrom-Json
        $config = New-SearxngTakeoverConfig -EntryPath 'X:\e.js' -ExistingEntry $existing
        $config.command | Should -Be 'node'
        $config.args | Should -Be @('X:\e.js')
        $config.type | Should -Be 'stdio'
        $config.timeout | Should -Be 900000
    }
}

Describe 'Resolve-McpRuntimeEntry — npm stderr under EAP=Stop (W1, #4411 review)' {

    BeforeAll {
        # Stub npm #1: routine stderr (both the native-style console path and
        # the ErrorRecord path) + stdout, exit 0 — npm's everyday "warn"
        # behaviour. Deliberately NOT self-protecting with -ErrorAction
        # Continue: with the W1 fix absent, the child inherits EAP=Stop and
        # the Write-Error terminates — this test must fall with it.
        $script:stubOk = Join-Path $tmpRoot 'stub-npm-ok.ps1'
        Set-Content -LiteralPath $stubOk -Value @'
[Console]::Error.WriteLine('stub npm warn: native-style stderr line')
Write-Error 'stub npm warn: ErrorRecord stderr line'
Write-Output 'stub npm stdout line'
exit 0
'@
        # Stub npm #2: stderr + non-zero exit — $LASTEXITCODE must be the judge.
        $script:stubFail = Join-Path $tmpRoot 'stub-npm-fail.ps1'
        Set-Content -LiteralPath $stubFail -Value @'
[Console]::Error.WriteLine('stub npm failing stderr line')
exit 3
'@
    }

    AfterEach {
        $script:McpRuntimeNpmCommand = $null
    }

    It 'survives routine npm stderr with exit 0 under EAP=Stop (PS 5.1 RemoteException regression guard)' {
        New-RuntimeFixture -Name 'w1ok' -Package 'w1-pkg' -Version '0.9.0' -BinJson 'old.js' -BinFile 'old.js'
        $spec = @{ Name = 'w1ok'; Package = 'w1-pkg'; Version = '1.0.0' }   # mismatch -> install path
        $script:McpRuntimeNpmCommand = $stubOk
        $prev = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'
        try {
            $entry = Resolve-McpRuntimeEntry -Root $tmpRoot -Spec $spec
            # The stub installs nothing: the OLD manifest+bin stay and resolve.
            $entry | Should -Be (Join-Path $tmpRoot "w1ok\node_modules\w1-pkg\old.js")
        } finally {
            $ErrorActionPreference = $prev
        }
    }

    It 'throws when npm exits non-zero ($LASTEXITCODE is the sole judge)' {
        New-RuntimeFixture -Name 'w1fail' -Package 'w1f-pkg' -Version '0.9.0' -BinJson 'old.js' -BinFile 'old.js'
        $spec = @{ Name = 'w1fail'; Package = 'w1f-pkg'; Version = '1.0.0' }
        $script:McpRuntimeNpmCommand = $stubFail
        { Resolve-McpRuntimeEntry -Root $tmpRoot -Spec $spec } | Should -Throw 'npm install failed*'
    }
}

Describe 'deploy-claude-mcp-settings.ps1 — structural (#4149 F1)' {

    BeforeAll {
        $script:deploy = Get-Content -Raw (Join-Path $repoRoot "scripts/deployment/deploy-claude-mcp-settings.ps1")
    }

    It 'launches every managed server with node, no npx launcher left' {
        $deploy | Should -Not -Match 'command\s*=\s*"npx"'
    }

    It 'dot-sources the runtime lib (the REAL line, not a header comment — W2)' {
        # W2 (#4411 review): the previous assertion matched the header comment,
        # which names a file that does not exist. Anchor on the dot-source call.
        $deploy | Should -Match '\.\s*\(Join-Path \$PSScriptRoot\s+"mcp-runtime\.lib\.ps1"\)'
        $deploy | Should -Match 'New-SearxngTakeoverConfig'
        $deploy | Should -Match 'ExistingSearxng'
    }

    It 'pins the versions measured in the fleet npx cache (28/10)' {
        $deploy | Should -Match "'@playwright/mcp';\s*Version\s*=\s*'0\.0\.83'"
        $deploy | Should -Match "'mcp-searxng';\s*Version\s*=\s*'2\.9\.0'"
    }

    It 'guards npm behind the version check — an installed runtime is never re-fetched' {
        # The guard structure lives in the LIB: skip-branch message when
        # installed == spec. The behavioural suite never walks the npm branch
        # (no network in CI); this pins the guard to the lib that runs at deploy.
        $lib = Get-Content -Raw (Join-Path $repoRoot "scripts/deployment/mcp-runtime.lib.ps1")
        $lib | Should -Match 'already installed'
        $lib | Should -Match '\$Installed -ne \$Spec\.Version'
    }
}

Describe 'mcp-process-census.ps1 — the BEFORE/AFTER instrument (#4149 F1)' {

    BeforeAll {
        $script:census = Get-Content -Raw (Join-Path $repoRoot "scripts/diagnostic/mcp-process-census.ps1")
    }

    It 'classifies the wrapper BEFORE the build child (a wrapper command line contains both patterns)' {
        $wrapperPos = $census.IndexOf("Tag = 'rsm-wrapper'")
        $serverPos = $census.IndexOf("Tag = 'rsm-server'")
        $wrapperPos | Should -BeGreaterThan -1
        $serverPos | Should -BeGreaterThan $wrapperPos
    }

    It 'covers the flattened servers plus the fleet survivors' {
        foreach ($tag in 'playwright', 'searxng', 'rsm-wrapper', 'rsm-server', 'sk-agent', 'papermill') {
            $census | Should -Match ("Tag = '" + $tag + "'")
        }
    }

    It 'runs live and reports per-server counts (Windows seats only — CI runner is ubuntu)' -Skip: ($env:OS -ne 'Windows_NT') {
        # Assert on the JSON payload, not on captured host text: 5.1->pwsh
        # console capture mangles the first banner line (em-dash encoding),
        # while the JSON file is deterministic.
        $json = Join-Path ([System.IO.Path]::GetTempPath()) "census-live-$([Guid]::NewGuid().ToString('N').Substring(0,8)).json"
        try {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot "scripts/diagnostic/mcp-process-census.ps1") -JsonPath $json | Out-Null
            Test-Path -LiteralPath $json | Should -BeTrue
            $c = Get-Content -Raw -LiteralPath $json | ConvertFrom-Json
            $c.machine | Should -Not -BeNullOrEmpty
            $c.sessions | Should -BeGreaterThan 0
            $c.total_procs | Should -BeGreaterThan 0
            $c.servers.Count | Should -BeGreaterThan 0
            foreach ($s in $c.servers) {
                $s.processes | Should -BeGreaterThan 0
                $s.ws_mb_total | Should -BeGreaterThan 0
            }
        } finally {
            Remove-Item -LiteralPath $json -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Resolve-DeployRepoRoot (#4149 — never deploy from a worktree path)' {

    BeforeAll {
        # REAL git, REAL linked worktree. The first version of this suite used
        # a stub .ps1 as the git command: a .ps1 is not an executable on the
        # Linux CI runner, so git never ran there — the redirect test failed
        # on CI while two negative tests passed for the WRONG reason (they
        # "passed" because the function had returned its input unexamined).
        # The instrument now exercises the real command on both platforms.
        $script:repoDir = Join-Path $tmpRoot 'repo'
        $script:linkedDir = Join-Path $tmpRoot 'linked-worktree'
        $script:plainDir = Join-Path $tmpRoot 'not-a-repo'

        New-Item -ItemType Directory -Path $repoDir -Force | Out-Null
        & git -C $repoDir init -q 2>&1 | Out-Null
        & git -C $repoDir -c user.email=test@example.invalid -c user.name=test `
            commit -q --allow-empty -m init 2>&1 | Out-Null
        # `git worktree add` wants a path that does not exist yet.
        & git -C $repoDir worktree add -q $linkedDir -b wt/linked 2>&1 | Out-Null
        New-Item -ItemType Directory -Path $plainDir -Force | Out-Null
    }

    AfterEach {
        $script:McpRuntimeGitCommand = $null
        $script:McpRuntimeGitArgs = $null
    }

    It 'redirects a deploy launched from a linked worktree to the main checkout' {
        (Resolve-DeployRepoRoot -RepoRoot $linkedDir) | Should -Be $repoDir
    }

    It 'leaves the root alone when the deploy already runs in the main checkout' {
        (Resolve-DeployRepoRoot -RepoRoot $repoDir) | Should -Be $repoDir
    }

    It 'returns the input unchanged when git answers with a non-zero exit' {
        # A real 'fatal: not a git repository' on stderr, exit 128 — it must not
        # terminate the deploy (same EAP discipline as the npm call, W1) and it
        # must not produce a root.
        $prev = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'
        try {
            (Resolve-DeployRepoRoot -RepoRoot $plainDir) | Should -Be $plainDir
        } finally {
            $ErrorActionPreference = $prev
        }
    }

    It 'returns the input unchanged on git output it cannot parse' {
        # Real git, real output, wrong shape: `git --version` answers on stdout
        # with exit 0 and no worktree line — the guard must not guess.
        $script:McpRuntimeGitArgs = @('--version')
        (Resolve-DeployRepoRoot -RepoRoot $linkedDir) | Should -Be $linkedDir
    }
}

Describe 'deploy-claude-mcp-settings.ps1 — root resolution is WIRED (#4149)' {

    BeforeAll {
        $script:deploy = Get-Content -Raw (Join-Path $repoRoot "scripts/deployment/deploy-claude-mcp-settings.ps1")
    }

    It 'calls Resolve-DeployRepoRoot on the script-location root' {
        # Anchored on the real assignment, not on a comment about it.
        $deploy | Should -Match '\$RepoRoot\s*=\s*Resolve-DeployRepoRoot\s+-RepoRoot\s+\(Get-Item\s+"\$PSScriptRoot'
    }

    It 'dot-sources the lib BEFORE the root resolution (the function must exist when called)' {
        $sourcePos = $deploy.IndexOf('mcp-runtime.lib.ps1")')
        $callPos = $deploy.IndexOf('Resolve-DeployRepoRoot -RepoRoot')
        $sourcePos | Should -BeGreaterThan -1
        $callPos | Should -BeGreaterThan -1
        $sourcePos | Should -BeLessThan $callPos
    }

    It 'dot-sources the lib exactly once' {
        ([regex]::Matches($deploy, '\.\s*\(Join-Path \$PSScriptRoot\s+"mcp-runtime\.lib\.ps1"\)')).Count | Should -Be 1
    }
}

AfterAll {
    if (Test-Path $tmpRoot) { Remove-Item -Recurse -Force $tmpRoot -ErrorAction SilentlyContinue }
}
