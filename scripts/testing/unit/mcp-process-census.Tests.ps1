# mcp-process-census.Tests.ps1 - pins the TREE attribution of the census v2 (#4149)
#
# Fixture = the web1 measurement of 08/11 (c.771): ONE claude.exe session for
# which census v1 reported "sk-agent: 2 processes / 309 MB" while the real
# trees are 16 processes / 1059 MB. PIDs and parentage are the measured ones;
# working sets are synthetic but keep the measured shape (the two sk_agent
# pythons dwarf their wrappers).
#
# Chain A (root under Code.exe = the Zoo Code declaration, decommissioned by
# the user 02/11 but still mounted at measurement time):
#   cmd 12036 -> pwsh 9500 -> python 9748 (sk_agent.py), which spawned
#   searxng (4 procs), playwright (4 procs) and markitdown (3 procs) children
#   plus a conhost (12204) that must NOT be counted.
# Chain B (root under claude.exe): pwsh 11616 -> python 10148 (sk_agent.py).
# Direct searxng chain under claude.exe: cmd 11600 -> node 3616 -> cmd 6764
# -> node 536.

BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    . (Join-Path $projectRoot 'scripts/diagnostic/mcp-process-census.ps1')

    function New-Proc {
        param([int]$Id, [int]$Parent, [string]$Name, [string]$Cmd)
        [pscustomobject]@{
            ProcessId       = [uint32]$Id
            ParentProcessId = [uint32]$Parent
            Name            = $Name
            CommandLine     = $Cmd
        }
    }

    # The 08/11 web1 snapshot. Switches:
    #   -OrphanPlaywright: adds a standalone playwright node whose parent PID
    #     (424242) is dead - it must become its OWN chain root.
    function New-MeasuredFixture {
        param([switch]$OrphanPlaywright)

        $skWrapper = 'C:\Drive\dev\roo-extensions\mcps\internal\servers\sk-agent\run-sk-agent.ps1'
        $skPython  = 'C:\Python311\python.exe C:\Drive\dev\roo-extensions\mcps\internal\servers\sk-agent\sk_agent.py'
        $procs = @(
            # hosts (never own-match: they are the parents that DECLARE the chains)
            New-Proc 11568 4     'Code.exe'   'C:\Users\Administrator\AppData\Local\Programs\Microsoft VS Code\Code.exe'
            New-Proc 13032 4     'claude.exe' 'C:\Users\Administrator\local\claude.exe'
            # chain A (Zoo Code declaration): root cmd under Code.exe
            New-Proc 12036 11568 'cmd.exe'       ('C:\Windows\system32\cmd.exe /c powershell -NoProfile -ExecutionPolicy Bypass -File "' + $skWrapper + '"')
            New-Proc 9500  12036 'powershell.exe' ('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + $skWrapper + '"')
            New-Proc 9748  9500  'python.exe'    $skPython
            # searxng children of chain A (npx chain: cmd -> npx node -> .bin shim cmd -> server node)
            New-Proc 5824  9748  'cmd.exe'  'C:\Windows\system32\cmd.exe /c npx -y mcp-searxng'
            New-Proc 7788  5824  'node.exe' 'node C:\npm-cache\_npx\abc123\node_modules\npm\bin\npx-cli.js -y mcp-searxng'
            New-Proc 9664  7788  'cmd.exe'  'C:\Windows\system32\cmd.exe /c node_modules\.bin\mcp-searxng'
            New-Proc 3376  9664  'node.exe' 'node C:\npm-cache\_npx\abc123\node_modules\mcp-searxng\dist\index.js'
            # playwright children of chain A
            New-Proc 10168 9748  'cmd.exe'  'C:\Windows\system32\cmd.exe /c npx -y @playwright/mcp@latest'
            New-Proc 8636  10168 'node.exe' 'node C:\npm-cache\_npx\def456\node_modules\npm\bin\npx-cli.js -y @playwright/mcp@latest'
            New-Proc 14832 8636  'cmd.exe'  'C:\Windows\system32\cmd.exe /c node_modules\.bin\playwright-mcp'
            New-Proc 14768 14832 'node.exe' 'node C:\npm-cache\_npx\def456\node_modules\@playwright\mcp\cli.js'
            # markitdown chain under chain A
            New-Proc 12268 9748  'markitdown-mcp.exe' 'C:\venvs\venv-markitdown\Scripts\markitdown-mcp.exe'
            New-Proc 5532  12268 'python.exe' 'C:\venvs\venv-markitdown\Scripts\python.exe C:\venvs\venv-markitdown\markitdown_server.py'
            New-Proc 13860 5532  'python.exe' 'C:\venvs\venv-markitdown\Scripts\python.exe -m markitdown_mcp'
            # conhost child of chain A root: console plumbing, never counted
            New-Proc 12204 12036 'conhost.exe' ''
            # chain B: sk-agent mounted by claude.exe itself
            New-Proc 11616 13032 'pwsh.exe'    ('pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "' + $skWrapper + '"')
            New-Proc 10148 11616 'python.exe'  $skPython
            # direct searxng chain under claude.exe (NOT owned by sk-agent)
            New-Proc 11600 13032 'cmd.exe'  'C:\Windows\system32\cmd.exe /c npx -y mcp-searxng'
            New-Proc 3616  11600 'node.exe' 'node C:\npm-cache\_npx\ghi789\node_modules\npm\bin\npx-cli.js -y mcp-searxng'
            New-Proc 6764  3616  'cmd.exe'  'C:\Windows\system32\cmd.exe /c node_modules\.bin\mcp-searxng'
            New-Proc 536   6764  'node.exe' 'node C:\npm-cache\_npx\ghi789\node_modules\mcp-searxng\dist\index.js'
        )
        if ($OrphanPlaywright) {
            # dead parent PID 424242: standalone playwright chain, its own root
            $procs += New-Proc 22222 424242 'node.exe' 'node C:\npm-cache\_npx\xyz999\node_modules\@playwright\mcp\cli.js'
        }

        # WS shape: hosts 200 MB (irrelevant, never in a tree), chain procs
        # 10 MB, the two sk_agent pythons 100 MB each (the measured shape).
        $ws = @{}
        foreach ($p in $procs) { $ws[[uint32]$p.ProcessId] = 10.0 }
        $ws[[uint32]9748] = 100.0
        $ws[[uint32]10148] = 100.0
        $ws[[uint32]11568] = 200.0
        $ws[[uint32]13032] = 200.0

        return [pscustomobject]@{ Processes = $procs; Ws = $ws }
    }
}

Describe 'Get-McpProcessCensus - tree view (#4149 v2: owner = chain root)' {

    BeforeAll {
        $script:fx = New-MeasuredFixture
        $script:result = Get-McpProcessCensus -Processes $fx.Processes -WorkingSetMB $fx.Ws -Sessions 2
    }

    It 'attributes BOTH sk-agent chains to sk-agent: 16 processes, not v1''s 2 (wrappers + children included)' {
        $row = $result.servers | Where-Object { $_.server -eq 'sk-agent' }
        $row | Should -Not -BeNullOrEmpty
        $row.processes | Should -Be 16
    }

    It 'sums the whole tree working set: 340 MB (chain A 230 + chain B 110), not v1''s wrapper-less subset' {
        ($result.servers | Where-Object { $_.server -eq 'sk-agent' }).ws_mb_total | Should -Be 340
    }

    It 'counts the DIRECT searxng chain under claude.exe as searxng (4 procs), separate from sk-agent' {
        ($result.servers | Where-Object { $_.server -eq 'searxng' }).processes | Should -Be 4
        ($result.servers | Where-Object { $_.server -eq 'searxng' }).ws_mb_total | Should -Be 40
    }

    It 'has NO playwright server row: the 4 playwright children live under the sk-agent root (owner view)' {
        ($result.servers | Where-Object { $_.server -eq 'playwright' }) | Should -BeNullOrEmpty
    }

    It 'excludes conhost.exe (sk-agent = 16, not 17)' {
        $result.total_procs | Should -Be 20
        $result.total_ws_mb | Should -Be 380
    }

    It 'divides per session: 16 procs / 2 claude.exe hosts = 8' {
        ($result.servers | Where-Object { $_.server -eq 'sk-agent' }).per_session_procs | Should -Be 8
    }
}

Describe 'Get-McpProcessCensus - identity view (sub_servers)' {

    BeforeAll {
        $script:fx = New-MeasuredFixture
        $script:result = Get-McpProcessCensus -Processes $fx.Processes -WorkingSetMB $fx.Ws -Sessions 2
    }

    It 'shows the markitdown chain that v1 never surfaced (3 procs)' {
        ($result.sub_servers | Where-Object { $_.server -eq 'markitdown' }).processes | Should -Be 3
    }

    It 'splits searxng 8 (4 under sk-agent + 4 direct) and playwright 4 (all under sk-agent)' {
        ($result.sub_servers | Where-Object { $_.server -eq 'searxng' }).processes | Should -Be 8
        ($result.sub_servers | Where-Object { $_.server -eq 'playwright' }).processes | Should -Be 4
    }

    It 'counts sk-agent own-matches at 5 (cmd + pwsh + python chain A; pwsh + python chain B)' {
        ($result.sub_servers | Where-Object { $_.server -eq 'sk-agent' }).processes | Should -Be 5
    }
}

Describe 'Get-McpProcessCensus - chain roots (host attribution)' {

    BeforeAll {
        $script:fx = New-MeasuredFixture
        $script:result = Get-McpProcessCensus -Processes $fx.Processes -WorkingSetMB $fx.Ws -Sessions 2
    }

    It 'finds exactly 3 chain roots, and names the HOST that mounted each' {
        $result.trees.Count | Should -Be 3
        $rootA = $result.trees | Where-Object { $_.root_pid -eq 12036 }
        $rootA.parent_name | Should -Be 'Code.exe'        # the Zoo Code declaration
        $rootA.tag | Should -Be 'sk-agent'
        $rootA.processes | Should -Be 14
        $rootB = $result.trees | Where-Object { $_.root_pid -eq 11616 }
        $rootB.parent_name | Should -Be 'claude.exe'      # the session's own mount
        $rootB.processes | Should -Be 2
        $rootC = $result.trees | Where-Object { $_.root_pid -eq 11600 }
        $rootC.parent_name | Should -Be 'claude.exe'
        $rootC.tag | Should -Be 'searxng'
    }

    It 'makes a dead-parent own-match process its OWN root (playwright orphan)' {
        $fx2 = New-MeasuredFixture -OrphanPlaywright
        $r2 = Get-McpProcessCensus -Processes $fx2.Processes -WorkingSetMB $fx2.Ws -Sessions 2
        # the 4 embedded playwright children stay under sk-agent; only the
        # orphan creates a playwright server row (1 proc, not 5)
        ($r2.servers | Where-Object { $_.server -eq 'playwright' }).processes | Should -Be 1
        ($r2.sub_servers | Where-Object { $_.server -eq 'playwright' }).processes | Should -Be 5
        ($r2.trees | Where-Object { $_.root_pid -eq 22222 }).parent_name | Should -Be '(dead)'
        $r2.total_procs | Should -Be 21
    }
}
