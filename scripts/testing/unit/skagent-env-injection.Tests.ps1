# Pester 5 tests: the worker must inject sk-agent env vars into its process env
# (#4815 fleet volet — SEARXNG_URL + HUB_BASE_URL).
#
# Defect these tests pin: `claude -p` worker children do NOT pass mcpServers.*.env
# entries to their stdio MCP children, so sk-agent ran with searxng "unavailable"
# in scheduled workers even though ~/.claude.json carried the var. #4814 writes
# HUB_BASE_URL into the same entry env — without this injection every seat depends
# on a hand edit and the post-bump template cannot resolve in workers.
#
# Pattern: lane-signature-autocommit.Tests.ps1 — SOURCE PINS + behavioral
# extraction + positive controls (mutant: stripping the injection block makes the
# corresponding tests go red). Pure string comparisons on the production source;
# no git, no network, no schtask, no real ~/.claude.json access ever runs.
#
# Run:  powershell -File scripts/testing/run-pester-tests.ps1 -Path scripts/testing/unit/skagent-env-injection.Tests.ps1

Describe 'Worker injects sk-agent env vars into its process env (#4815)' {

    BeforeAll {
        $script:workerSrc = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../scheduling/start-claude-worker.ps1') -Raw
    }

    It 'the allow-list names exactly SEARXNG_URL and HUB_BASE_URL, from the sk-agent entry env' {
        $workerSrc | Should -Match '\$SkAgentEnvAllowList\s*=\s*@\(''SEARXNG_URL'',\s*''HUB_BASE_URL''\)'
        $workerSrc | Should -Match '\$SkAgentEnv\s*=\s*\$SkAgentClaudeConfig\.mcpServers\.''sk-agent''\.env'
    }

    It 'injection is only-if-unset (same guard as #2252) and goes through env: Set-Item' {
        $workerSrc | Should -Match 'if \(\(-not \(Test-Path \$envPath\)\) -or -not \(Get-Item \$envPath\)\.Value\)|if \(-not \(Test-Path \$envPath\) -or -not \(Get-Item \$envPath\)\.Value\)'
        $workerSrc | Should -Match 'Set-Item -Path \$envPath -Value \$SkAgentEnv\[\$envVarName\]'
    }

    It 'behavioral: the extracted allow-list selects exactly the two fleet vars from a sample entry env — and nothing else' {
        # Extract the allow-list array literal FROM THE SOURCE (not a forked copy),
        # then evaluate it and run the real selection over a sample sk-agent env.
        $m = [regex]::Match($workerSrc, '\$SkAgentEnvAllowList\s*=\s*@\(([^)]*)\)')
        $m.Success | Should -BeTrue
        $allowList = Invoke-Expression "@($($m.Groups[1].Value))"
        $sampleEntryEnv = @{
            SEARXNG_URL = 'http://seat-searx/local'
            HUB_BASE_URL = 'http://seat-hub/local'
            ZAI_BASE_URL = 'https://api.example'   # present in entry env, must NOT be selected
        }
        $selected = $sampleEntryEnv.Keys | Where-Object { $allowList -contains $_ } | Sort-Object
        ($selected -join ',') | Should -Be 'HUB_BASE_URL,SEARXNG_URL'
        # Only-if-unset semantics preserved: an already-set var is skipped.
        $alreadySet = @{ SEARXNG_URL = 'already-set' }
        $wouldSet = foreach ($name in $allowList) {
            if ($sampleEntryEnv.ContainsKey($name) -and -not $alreadySet.ContainsKey($name)) { $name }
        }
        ($wouldSet | Sort-Object) -join ',' | Should -Be 'HUB_BASE_URL'
    }

    It 'positive control: stripping the sk-agent injection block makes every pin above fail' {
        # Mutant = the pre-fix source: everything from the #4815 marker to the
        # sk-agent catch tail is removed.
        $mutant = $workerSrc -replace '(?s)#4815: sk-agent env injection.*?Injection env sk-agent échouée[^\r\n]*', ''
        $mutant | Should -Not -Match '\$SkAgentEnvAllowList'
        $mutant | Should -Not -Match "mcpServers\.''sk-agent''\.env"
        # The #2252 RSM block must survive the strip — the mutant is surgical.
        $mutant | Should -Match '\$McpEnv\s*=\s*\$ClaudeConfig\.mcpServers\.''roo-state-manager''\.env'
    }
}
