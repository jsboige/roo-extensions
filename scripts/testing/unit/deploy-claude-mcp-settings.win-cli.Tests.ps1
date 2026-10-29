# Tests unitaires pour scripts/deployment/deploy-claude-mcp-settings.ps1
# Retrait de win-cli du jeu géré (arbitrage ai-01 2026-10-29T01:16Z, file 20261029a item 1).
#
# La preuve demandee est EXECUTOIRE, pas textuelle : le script tourne sur un
# USERPROFILE factice (runtimes playwright/searxng pre-installes en fixtures,
# .claude.json de depart sans win-cli, settings.json minimal), et le JSON ecrit
# est relu — il ne doit contenir AUCUNE cle win-cli, les TROIS gerees, et le
# survivant non gere (sk-agent) preserve.
#
# Syntaxe Pester v5 — portable pwsh Windows et Linux (chemins construits par
# Join-Path, jamais de literal backslash embarque). Aucun reseau : les fixtures
# portent la version matchante pour que Resolve-McpRuntimeEntry court-circuite
# npm install.
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/deploy-claude-mcp-settings.win-cli.Tests.ps1 -Output Detailed"

BeforeAll {
    $script:repoRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $script:deployScript = Join-Path $repoRoot "scripts/deployment/deploy-claude-mcp-settings.ps1"
    $script:source = [System.IO.File]::ReadAllText($deployScript)

    $script:tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) "wincli-retrait-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $tmpRoot -Force | Out-Null

    function New-RuntimeFixture {
        # Meme forme que deploy-mcp-runtime-launchers.Tests.ps1 : manifest a la
        # version attendue => resolution sans npm.
        param([string]$Name, [string]$Package, [string]$Version, [string]$BinFile)
        $dir = Join-Path $tmpRoot $Name
        $pkgDir = Join-Path $dir (Join-Path 'node_modules' $Package)
        New-Item -ItemType Directory -Path $pkgDir -Force | Out-Null
        $manifest = @{ name = $Package; version = $Version; bin = $BinFile } | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText((Join-Path $pkgDir 'package.json'), $manifest)
        New-Item -ItemType File -Path (Join-Path $pkgDir $BinFile) -Force | Out-Null
        return $dir
    }

    function New-SeatFixture {
        # USERPROFILE factice : .claude.json SANS win-cli + un survivant non
        # gere (sk-agent), et .claude/settings.json minimal.
        param([string]$Root, [hashtable]$InitialServers)
        $seatHomePath = Join-Path $Root "seat-$([Guid]::NewGuid().ToString('N').Substring(0,6))"
        New-Item -ItemType Directory -Path (Join-Path $seatHomePath '.claude') -Force | Out-Null
        $claudeJson = @{ mcpServers = $InitialServers } | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText((Join-Path $seatHomePath '.claude.json'), $claudeJson)
        [System.IO.File]::WriteAllText((Join-Path $seatHomePath '.claude/settings.json'), (@{ env = @{} } | ConvertTo-Json -Depth 5))
        return $seatHomePath
    }

    function Invoke-DeployOnSeat {
        param([string]$SeatHome)
        # Le script lit $env:USERPROFILE et $env:COMPUTERNAME : les surcharger
        # le temps de l'appel, puis restaurer (CI compris).
        $oldHome = $env:USERPROFILE
        $oldComputer = $env:COMPUTERNAME
        try {
            $env:USERPROFILE = $SeatHome
            $env:COMPUTERNAME = if ($oldComputer) { $oldComputer } else { 'pester-seat' }
            & $deployScript 2>&1 | Out-Null
        } finally {
            $env:USERPROFILE = $oldHome
            $env:COMPUTERNAME = $oldComputer
        }
    }

    # Les runtimes sont installes sous <USERPROFILE>/.claude/mcp-runtimes par le
    # script ; on pre-remplit CE chemin dans chaque seat (le Root est derive de
    # USERPROFILE, pas parametrable).
    function Install-RuntimesForSeat {
        param([string]$SeatHome)
        $runtimes = Join-Path (Join-Path $SeatHome '.claude') 'mcp-runtimes'
        foreach ($spec in @(
            @{ Name = 'playwright'; Package = '@playwright/mcp'; Version = '0.0.83'; Bin = 'cli.js' },
            @{ Name = 'searxng';    Package = 'mcp-searxng';    Version = '2.9.0';  Bin = 'dist/cli.js' }
        )) {
            $dir = Join-Path $runtimes $spec.Name
            $pkgDir = Join-Path $dir (Join-Path 'node_modules' $spec.Package)
            New-Item -ItemType Directory -Path $pkgDir -Force | Out-Null
            $manifest = @{ name = $spec.Package; version = $spec.Version; bin = $spec.Bin } | ConvertTo-Json -Depth 5
            [System.IO.File]::WriteAllText((Join-Path $pkgDir 'package.json'), $manifest)
            $binPath = Join-Path $pkgDir $spec.Bin
            $binDir = Split-Path $binPath -Parent
            New-Item -ItemType Directory -Path $binDir -Force | Out-Null
            New-Item -ItemType File -Path $binPath -Force | Out-Null
        }
    }
}

AfterAll {
    if (Test-Path $tmpRoot) { Remove-Item -Recurse -Force $tmpRoot -ErrorAction SilentlyContinue }
}

Describe 'deploy-claude-mcp-settings: win-cli hors du jeu gere (arbitrage 29/10 01:16Z)' {
    It 'le source ne definit plus $WinCliPath ni sa garde existence' {
        # Pattern sur la DEFINITION ('$WinCliPath ='), pas sur la prose : un
        # commentaire de retrait peut nommer la variable, une definition non.
        $source | Should -Not -Match '\$WinCliPath\s*='
        $source | Should -Not -Match 'win-cli not found'
    }

    It 'la table $McpServers ne declare plus de cle "win-cli"' {
        # Le bloc @{ ... } gere : extraire de "$McpServers = @{" jusqu'a la
        # section merge, et verifier l'absence de la cle.
        $start = $source.IndexOf('$McpServers = @{')
        $start | Should -BeGreaterThan -1
        $end = $source.IndexOf('$MergedServers', $start)
        $end | Should -BeGreaterThan $start
        $table = $source.Substring($start, $end - $start)
        $table | Should -Not -Match '"win-cli"'
    }

    # Les deux tests EXECUTOIRES tournent le VRAI script : cible Windows par
    # conception (chemins "$RepoRoot\mcps\..." en backslashes literals +
    # $env:USERPROFILE) — sur le runner Linux du job unit-pester la garde
    # Test-Path du script ne resout pas et l'execution n'a pas de sens. La
    # preuve executoire vit sur les sieges Windows (locale + marshall-scripts-
    # pester) ; les invariants textuels (tests 1-2) couvrent la jambe Linux.
    $onWindows = ($env:OS -eq 'Windows_NT')   # robuste PS 5.1 ET pwsh 7

    It 'EXECUTION sur seat factice sans win-cli : le JSON ecrit n en gagne aucune (preuve demandee)' -Skip:(-not $onWindows) {
        $seat = New-SeatFixture -Root $tmpRoot -InitialServers @{ 'sk-agent' = @{ command = 'node'; args = @('stub') } }
        Install-RuntimesForSeat -SeatHome $seat
        Invoke-DeployOnSeat -SeatHome $seat

        $written = Get-Content (Join-Path $seat '.claude.json') -Raw | ConvertFrom-Json
        $written.mcpServers.PSObject.Properties['win-cli'] | Should -BeNullOrEmpty
        # Les trois gerees sont la, le survivant non gere aussi.
        $written.mcpServers.PSObject.Properties['roo-state-manager'] | Should -Not -BeNullOrEmpty
        $written.mcpServers.PSObject.Properties['playwright'] | Should -Not -BeNullOrEmpty
        $written.mcpServers.PSObject.Properties['searxng'] | Should -Not -BeNullOrEmpty
        $written.mcpServers.PSObject.Properties['sk-agent'] | Should -Not -BeNullOrEmpty
        ($written.mcpServers.PSObject.Properties | Measure-Object).Count | Should -Be 4
    }

    It 'EXECUTION sur seat factice PORTANT un win-cli legacy : l entree survive (le merge ne purge pas le non-gere)' -Skip:(-not $onWindows) {
        # Comportement attenant documente dans le commentaire du script : le
        # retrait du jeu gere ne retire pas l entree des sieges qui la portent
        # deja — c est le recensement F1 qui les liste. Ce test fixe ce contrat.
        $seat = New-SeatFixture -Root $tmpRoot -InitialServers @{
            'sk-agent' = @{ command = 'node'; args = @('stub') }
            'win-cli'  = @{ command = 'node'; args = @('C:\legacy\win-cli\index.js') }
        }
        Install-RuntimesForSeat -SeatHome $seat
        Invoke-DeployOnSeat -SeatHome $seat

        $written = Get-Content (Join-Path $seat '.claude.json') -Raw | ConvertFrom-Json
        $written.mcpServers.PSObject.Properties['win-cli'] | Should -Not -BeNullOrEmpty
        ($written.mcpServers.PSObject.Properties | Measure-Object).Count | Should -Be 5
    }
}
