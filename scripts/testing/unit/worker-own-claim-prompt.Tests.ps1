# Tests unitaires : le prompt du worker declare comme SIEN le claim que son lanceur vient de poser.
#
# Defaut mesure (ai-01, 29/10 22:45Z, #2191) : Claim-GitHubIssue poste
# "[CLAIMED] by claude on <lane>", puis l'agent lance lit ce claim frais comme celui
# d'une session jumelle (regle #4221 : « claim de ta lane absent de ton contexte »),
# se met en WAIT derriere son propre verrou (wait-state github-2191.json), et le
# verrou dort 24 h en bloquant les autres lanes.
#
# Ces tests EXECUTENT Build-GitHubPrompt (extrait par AST du script reel) au lieu de
# chercher du texte dans le source. Pester v5, job `unit-pester` (#3216).

BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $script:workerScript = Join-Path $projectRoot "scripts/scheduling/start-claude-worker.ps1"

    $tokens = $null; $errors = $null
    $script:ast = [System.Management.Automation.Language.Parser]::ParseFile($script:workerScript, [ref]$tokens, [ref]$errors)
    $fn = $script:ast.Find({ param($n)
            $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Build-GitHubPrompt'
        }, $true)
    if (-not $fn) { throw "Build-GitHubPrompt introuvable dans $script:workerScript" }
    . ([scriptblock]::Create($fn.Extent.Text))

    # Build-GitHubPrompt lit $env:COMPUTERNAME (absent sous Linux).
    if (-not $env:COMPUTERNAME) { $env:COMPUTERNAME = 'TEST-HOST' }
}

Describe "Worker prompt - own claim notice (#4221 self-block)" {

    It "declares the launcher's claim as the agent's own when a lane is given" {
        $p = Build-GitHubPrompt -IssueNumber 2191 -Title 'T' -Body 'body' -OwnClaimLane 'myia-test:roo-extensions'
        $p | Should -Match '### Your claim on this issue'
        $p | Should -Match ([regex]::Escape('[CLAIMED] by claude on myia-test:roo-extensions'))
        $p | Should -Match 'is YOURS'
        $p | Should -Match '#4221'
        $p | Should -Match 'issue #2191'
    }

    It "keeps other claims binding (the notice does not waive foreign or older claims)" {
        $p = Build-GitHubPrompt -IssueNumber 7 -Title 'T' -Body 'body' -OwnClaimLane 'myia-test:roo-extensions'
        $p | Should -Match 'Any OTHER active claim'
        $p | Should -Match 'predates this run'
    }

    It "places the notice inside the issue section, before the issue description" {
        $p = Build-GitHubPrompt -IssueNumber 7 -Title 'T' -Body 'body' -OwnClaimLane 'myia-test:roo-extensions'
        $issue  = $p.IndexOf('## Issue #7')
        $notice = $p.IndexOf('### Your claim on this issue')
        $desc   = $p.IndexOf('### Issue Description')
        $issue  | Should -BeGreaterThan -1
        $notice | Should -BeGreaterThan $issue
        $desc   | Should -BeGreaterThan $notice
    }

    It "asserts no ownership when no claim was posted (empty lane, e.g. -SkipClaim)" {
        $p = Build-GitHubPrompt -IssueNumber 7 -Title 'T' -Body 'body'
        $p | Should -Not -Match 'Your claim on this issue'
        $p | Should -Not -Match 'is YOURS'
    }

    It "the task builder passes the lane only when it really posted the claim" {
        $call = $script:ast.Find({ param($n)
                $n -is [System.Management.Automation.Language.CommandAst] -and
                $n.GetCommandName() -eq 'Build-GitHubPrompt'
            }, $true)
        $call | Should -Not -BeNullOrEmpty
        $text = $call.Extent.Text
        $text | Should -Match '-OwnClaimLane'
        $text | Should -Match '\$script:ClaimLane'
        $text | Should -Match '-not \$SkipClaim'
    }
}
