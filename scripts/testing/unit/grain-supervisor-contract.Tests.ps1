# grain-supervisor-contract.Tests.ps1
#
# Offline contract tests for #4833. No Agent invocation, sk-agent workflow,
# network, provider credential or paid proof run. The end-to-end run was
# observed on 2026-11-20 (see the acceptance section of the doc); these
# tests stay offline.
#
# ASCII only: Windows PowerShell 5.1 reads BOM-less .ps1 as ANSI.
# Run:
#   powershell -File scripts/testing/run-pester-tests.ps1 -Path scripts/testing/unit/grain-supervisor-contract.Tests.ps1

BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:agentRel = '.claude/configs/agents/grain-supervisor.md'
    $script:docRel = 'docs/harness/reference/grain-supervisor.md'
    $script:agentPath = Join-Path $script:repoRoot $script:agentRel
    $script:docPath = Join-Path $script:repoRoot $script:docRel
    $script:agentText = [IO.File]::ReadAllText($script:agentPath)
    $script:docText = [IO.File]::ReadAllText($script:docPath)
    $script:combined = $script:agentText + "`n" + $script:docText

    function Get-ContractFindings {
        param([hashtable]$Texts)

        $required = [ordered]@{
            'agent-name' = @{ File = 'agent'; Pattern = '(?m)^name: grain-supervisor$' }
            'host-model' = @{ File = 'agent'; Pattern = '(?m)^model: sonnet$' }
            'agent-list' = @{ File = 'agent'; Pattern = 'mcp__sk-agent__list_agents' }
            'agent-call' = @{ File = 'agent'; Pattern = 'mcp__sk-agent__call_agent' }
            'agent-conversation' = @{ File = 'agent'; Pattern = 'mcp__sk-agent__run_conversation' }
            'difficulty-simple' = @{ File = 'both'; Pattern = '(?m)^\| `?simple`? \|' }
            'difficulty-standard' = @{ File = 'both'; Pattern = '(?m)^\| `?standard`? \|' }
            'difficulty-hard' = @{ File = 'both'; Pattern = '(?m)^\| `?difficile`? \|' }
            'difficulty-very-hard' = @{ File = 'both'; Pattern = '(?m)^\| `?tres difficile`? \|' }
            'luna' = @{ File = 'both'; Pattern = 'notebook-coder-luna' }
            'minimax' = @{ File = 'both'; Pattern = 'notebook-coder-minimax' }
            'glm' = @{ File = 'both'; Pattern = 'glm-5\.3' }
            'terra' = @{ File = 'both'; Pattern = 'Terra' }
            'opus-sol' = @{ File = 'both'; Pattern = 'Opus / Sol' }
            'background' = @{ File = 'doc'; Pattern = 'run_in_background:\s*true' }
            'background-parent' = @{ File = 'doc'; Pattern = 'libere le tour de la lane' }
            'claim-worktree' = @{ File = 'agent'; Pattern = 'worktree.*dedie|worktree existant' }
            'independent-verifier' = @{ File = 'agent'; Pattern = 'producteur et le verificateur sont des appels et conversations distincts' }
            'coordinator-no-merge' = @{ File = 'agent'; Pattern = 'Jamais de merge' }
            'model-witness' = @{ File = 'agent'; Pattern = 'model_used' }
            'spec-witness' = @{ File = 'agent'; Pattern = 'effective_config' }
            'conversation-witness' = @{ File = 'agent'; Pattern = 'effective_conversation' }
            'resumer-bound' = @{ File = 'agent'; Pattern = '4000 caracteres maximum' }
            'cost-wall' = @{ File = 'agent'; Pattern = 'duree murale totale et par etape' }
            'cost-tokens' = @{ File = 'agent'; Pattern = 'tokens input/output/cached' }
            'not-exposed' = @{ File = 'agent'; Pattern = 'NOT_EXPOSED' }
            'acceptance-observed' = @{ File = 'doc'; Pattern = 'Run de preuve' }
            'acceptance-pr-evidence' = @{ File = 'doc'; Pattern = 'jsboige-mcp-servers/pull/1826' }
        }

        $findings = @()
        foreach ($name in $required.Keys) {
            $rule = $required[$name]
            $targets = switch ($rule.File) {
                'agent' { @('agent') }
                'doc' { @('doc') }
                default { @('agent', 'doc') }
            }
            foreach ($target in $targets) {
                if ($Texts[$target] -notmatch $rule.Pattern) {
                    $findings += "$name missing from $target"
                }
            }
        }
        return $findings
    }
}

Describe 'grain-supervisor deployable definition (#4833)' {
    It 'has valid frontmatter and a unique agent name' {
        $script:agentText | Should -Match '^(?s)---\r?\n.*?\r?\n---\r?\n'
        ([regex]::Matches($script:agentText, '(?m)^name: grain-supervisor$')).Count | Should -Be 1
        ([regex]::Matches($script:agentText, '(?m)^model: sonnet$')).Count | Should -Be 1
    }

    It 'grants the sk-agent discovery and workflow tools' {
        foreach ($tool in @('mcp__sk-agent__list_agents', 'mcp__sk-agent__call_agent', 'mcp__sk-agent__run_conversation')) {
            $script:agentText | Should -Match ([regex]::Escape($tool))
        }
    }

    It 'does not grant a scheduler or native-model escalation in frontmatter' {
        $frontmatter = [regex]::Match($script:agentText, '(?s)\A---\r?\n(.*?)\r?\n---').Groups[1].Value
        $frontmatter | Should -Not -Match 'CronCreate|ScheduleWakeup|Register-ScheduledTask'
        $frontmatter | Should -Not -Match '(?m)^model: (opus|fable)$'
    }

    It 'deploys byte-identically to a fresh global agents directory' {
        $sandbox = Join-Path ([IO.Path]::GetTempPath()) ('grain-supervisor-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $sandbox | Out-Null
        $oldProfile = $env:USERPROFILE
        try {
            $env:USERPROFILE = $sandbox
            $deploy = Join-Path $script:repoRoot '.claude/configs/scripts/Deploy-GlobalConfig.ps1'
            & $deploy -Target agents | Out-Null
            $target = Join-Path $sandbox '.claude/agents/grain-supervisor.md'
            Test-Path -LiteralPath $target | Should -Be $true
            (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash | Should -Be (Get-FileHash -LiteralPath $script:agentPath -Algorithm SHA256).Hash
        } finally {
            $env:USERPROFILE = $oldProfile
            Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'is indexed as on-demand documentation' {
        $index = [IO.File]::ReadAllText((Join-Path $script:repoRoot 'docs/harness/reference/INDEX.md'))
        $index | Should -Match 'grain-supervisor\.md'
        $script:docText | Should -Match 'Deploy-GlobalConfig\.ps1 -Target agents -DryRun'
    }
}

Describe 'grain-supervisor routing and delivery contract' {
    BeforeAll {
        $script:cleanFindings = @(Get-ContractFindings -Texts @{ agent = $script:agentText; doc = $script:docText })
    }

    It 'has zero findings on the complete contract' {
        $script:cleanFindings | Should -Be @()
    }

    It 'detects removal of each difficulty row' {
        foreach ($difficultyProfile in @('simple', 'standard', 'difficile', 'tres difficile')) {
            $mutated = $script:agentText -replace "(?m)^\| ``$difficultyProfile`` \|.*$", ''
            $findings = @(Get-ContractFindings -Texts @{ agent = $mutated; doc = $script:docText })
            ($findings -join "`n") | Should -Match 'difficulty-'
        }
    }

    It 'detects removal of the background invocation' {
        $mutated = $script:docText -replace 'run_in_background:\s*true', 'run_in_background: false'
        $findings = @(Get-ContractFindings -Texts @{ agent = $script:agentText; doc = $mutated })
        $findings | Should -Contain 'background missing from doc'
    }

    It 'detects producer self-verification wording loss' {
        $mutated = $script:agentText -replace 'Le producteur et le verificateur sont des appels et conversations distincts\.', ''
        $findings = @(Get-ContractFindings -Texts @{ agent = $mutated; doc = $script:docText })
        $findings | Should -Contain 'independent-verifier missing from agent'
    }

    It 'detects a missing cost report' {
        $mutated = $script:agentText -replace 'duree murale totale et par etape', 'duree'
        $findings = @(Get-ContractFindings -Texts @{ agent = $mutated; doc = $script:docText })
        $findings | Should -Contain 'cost-wall missing from agent'
    }

    It 'keeps merge and native model decisions outside the supervisor' {
        $script:agentText | Should -Match 'Jamais de merge'
        $script:agentText | Should -Match 'coordinateur decide du merge'
        $script:docText | Should -Match 'model: "sonnet"'
        $script:docText | Should -Match 'Opus/Fable natif exige necessite, cout approuve et justification ecrite'
    }

    It 'records an observed end-to-end run with its evidence and cost' {
        $script:docText | Should -Match 'ne lancent ni Agent, ni workflow sk-agent, ni appel payant'
        $script:docText | Should -Match 'Run de preuve'
        $script:docText | Should -Match 'jsboige-mcp-servers/pull/1826'
        $script:docText | Should -Match 'NOT_EXPOSED'
    }
}
