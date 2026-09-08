<#
.SYNOPSIS
    Guard (prompt/log hardening): the worker resume path must never present an
    heuristic event as a HUMAN authorization (#3442 investigation thread).

.DESCRIPTION
    start-claude-worker.ps1 decides whether a paused task may resume by matching
    keywords in a GitHub comment / issue state / dashboard / RooSync inbox / timeout.
    A comment that merely contains "continue" (e.g. the French "continueront") makes
    `$Comment.body -match 'continue'` evaluate to $true with no authorization provenance
    (reproduced 2026-09-08 under Windows PowerShell 5.1). Build-ResumePrompt then asserted
    "Condition remplie" and the resume logs asserted "reprise autorisée".

    This is a PROMPT/LOG hardening, NOT a technical lock: the heuristic predicates
    (the `-match` keyword lists, the switch on resumeWhen, the `return $State` control
    flow) are intentionally left untouched. The change only (a) stops asserting
    authorization in the prompt and in the resume logs, and (b) tells the resumed agent
    that a comment / timeout is not an authorization and that approval-gated actions
    remain pending.

    These tests extract the REAL functions from the worker via AST — no dot-sourcing of
    the whole worker (which would run its top-level code and require gh/Claude), no real
    gh/Claude CLI — and assert:
      1. context is preserved (reason, waitFor, resumeWhen, context, OriginalPrompt);
      2. no approval authorization is asserted for resumeWhen github_comment / user_approval
         / timeout, while the disclaimer IS present;
      3. the negative assertions discriminate (counter-proof on the OLD prompt).

    The dynamic cases are bound with `It -ForEach` so each `It` executes its OWN data (a
    plain `foreach` + closure would let every `It` see the last iteration's value — distinct
    test names alone do not prove the right data ran).

.NOTES
    Coordination thread: #3442 (workspace dashboard) — do NOT close. Requires Pester 5+.
    File is UTF-8 WITH BOM: it carries non-ASCII prose that Windows PowerShell 5.1 would
    otherwise mis-decode on machines whose active code page is not 65001 (#2368).
#>

# Bound data for the `-ForEach` It blocks. This MUST be at file scope (not in BeforeAll):
# Pester reads it during DISCOVERY, before BeforeAll runs; an empty/absent value fails the run.
$script:Cases = @(
    @{ label = 'github_comment';  resumeWhen = 'github_comment';    waitFor = 'WAITFOR-SENTINEL-github-approved' }
    @{ label = 'user_approval';   resumeWhen = 'user_approval';     waitFor = 'WAITFOR-SENTINEL-user-approved' }
    @{ label = 'timeout';         resumeWhen = 'timeout_hours: 5';  waitFor = 'WAITFOR-SENTINEL-timeout-5h' }
)

Describe 'Worker resume prompt hardening (#3442)' {

    BeforeAll {
        # Pester v6 does not expose top-level file functions to It blocks, so every
        # helper is defined here, in the BeforeAll scope the It blocks inherit.

        function Get-FunctionCodeFromAst {
            param($Ast, $Tokens, [string]$Name)
            $fn = $Ast.FindAll({
                param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                          $n.Name -eq $Name
            }, $true) | Select-Object -First 1
            if (-not $fn) { return '' }
            $s = $fn.Extent.StartOffset
            $e = $fn.Extent.EndOffset
            $x = ($Tokens | Where-Object { $_.Extent.StartOffset -ge $s -and $_.Extent.EndOffset -le $e -and
                                           $_.Kind -ne [System.Management.Automation.Language.TokenKind]::Comment } |
                  ForEach-Object { $_.Text }) -join ' '
            return $x.Trim()
        }

        # Does the text assert that a resume is authorized / the wait condition is met?
        # Only the ASSERTION forms the old prompt/log used — deliberately NOT "condition est
        # remplie" inside a negation, which the new prompt does contain as a disclaimer.
        function Test-HasApprovalAssertion([string]$Text) {
            $patterns = @(
                'Condition remplie :',
                'est maintenant remplie',
                'reprise autorisée',
                "l'autorisation est accordée",
                'approbation accordée'
            )
            foreach ($p in $patterns) {
                if ($Text -match $p) { return $true }
            }
            return $false
        }

        function New-WaitState([string]$ResumeWhen, [string]$WaitFor) {
            # Unambiguous sentinels: every preserved-context assertion below matches these
            # exact tokens, so a false positive on shared boilerplate cannot satisfy them.
            @{
                reason     = 'RAISON-SENTINEL-waiting'
                waitFor    = $WaitFor
                resumeWhen = $ResumeWhen
                context    = @{
                    iteration     = 42
                    mode          = 'mode-SENTINEL'
                    model         = 'model-SENTINEL'
                    outputSnippet = 'SNIPPET-SENTINEL-ac6132'
                }
            }
        }

        $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
        $script:WorkerScript = Join-Path $projectRoot 'scripts/scheduling/start-claude-worker.ps1'

        $tokens = $null; $errors = $null
        $script:Ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:WorkerScript, [ref]$tokens, [ref]$errors)
        $script:ParseErrors = $errors
        $script:Tokens = $tokens

        # Extract Build-ResumePrompt via AST and make ONLY that function callable
        # (no dot-source of the whole worker). It is a pure string builder: no gh, no
        # Claude, no RepoRoot, no Write-Log — safe to invoke offline.
        $fnPrompt = $script:Ast.FindAll({
            param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                      $n.Name -eq 'Build-ResumePrompt'
        }, $true) | Select-Object -First 1
        if ($fnPrompt) {
            . ([scriptblock]::Create($fnPrompt.Extent.Text))
        }
        $script:HasBuildResumePrompt = [bool]$fnPrompt

        $script:WaitStateReadyCode = Get-FunctionCodeFromAst -Ast $script:Ast -Tokens $script:Tokens -Name 'Test-WaitStateReady'
        $script:GitHubDecisionCode = Get-FunctionCodeFromAst -Ast $script:Ast -Tokens $script:Tokens -Name 'Test-GitHubDecision'
        $script:ResumePromptCode   = Get-FunctionCodeFromAst -Ast $script:Ast -Tokens $script:Tokens -Name 'Build-ResumePrompt'
    }

    It 'Parses the worker script without syntax errors' {
        $script:ParseErrors.Count | Should -Be 0
    }

    Context 'Build-ResumePrompt invocable by AST (no worker dot-source, no gh/Claude)' {

        It 'Extracts and defines the real Build-ResumePrompt function' {
            $script:HasBuildResumePrompt | Should -BeTrue
        }

        It 'Builds a non-empty prompt for <label>' -ForEach $script:Cases {
            $ws = New-WaitState -ResumeWhen $_.resumeWhen -WaitFor $_.waitFor
            $p = Build-ResumePrompt -WaitState $ws -OriginalPrompt 'ORIGINAL-PROMPT-SENTINEL'
            $p | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Prompt preserves the full wait state and the original prompt' {

        It "preserves context for <label>" -ForEach $script:Cases {
            $ws = New-WaitState -ResumeWhen $_.resumeWhen -WaitFor $_.waitFor
            $p = Build-ResumePrompt -WaitState $ws -OriginalPrompt 'ORIGINAL-PROMPT-SENTINEL'

            $p | Should -Match 'RAISON-SENTINEL-waiting'                                     # reason preserved
            $p | Should -Match ([regex]::Escape($_.waitFor))                                 # waitFor preserved
            $p | Should -Match ([regex]::Escape("**Condition d'attente (resumeWhen) :** $($_.resumeWhen)")) # resumeWhen preserved as the wait condition
            $p | Should -Match '42'                                                          # context.iteration preserved
            $p | Should -Match 'mode-SENTINEL'                                               # context.mode preserved
            $p | Should -Match 'model-SENTINEL'                                              # context.model preserved
            $p | Should -Match 'SNIPPET-SENTINEL-ac6132'                                     # context.outputSnippet preserved
            $p | Should -Match 'ORIGINAL-PROMPT-SENTINEL'                                    # OriginalPrompt preserved
        }
    }

    Context 'Prompt never asserts approval — and carries the disclaimer' {

        It "no approval assertion + disclaimer for <label>" -ForEach $script:Cases {
            $ws = New-WaitState -ResumeWhen $_.resumeWhen -WaitFor $_.waitFor
            $p = Build-ResumePrompt -WaitState $ws -OriginalPrompt 'ORIGINAL-PROMPT-SENTINEL'

            # No unauthorized claim of authorization / condition met.
            Test-HasApprovalAssertion $p | Should -BeFalse

            # The disclaimer IS present: comment/timeout are not an authorization,
            # and approval-gated actions remain pending.
            $p | Should -Match 'ne constitue pas une approbation humaine'
            $p | Should -Match 'ne valent pas autorisation'
            $p | Should -Match 'restent EN ATTENTE'
            $p | Should -Match "réexamine l'attente"

            # Exact category: resumeWhen is stated explicitly as the (unconfirmed) wait
            # condition header, not merely present somewhere in the disclaimer.
            $p | Should -Match ([regex]::Escape("**Condition d'attente (resumeWhen) :** $($_.resumeWhen)"))
        }
    }

    Context 'Counter-proof: the negative assertions discriminate (old prompt is caught)' {

        It 'Flags the OLD resume prompt as asserting a fulfilled condition' {
            $oldPrompt = @"
=== REPRISE DE TÂCHE EN ATTENTE ===

Cette tâche a été mise en pause précédemment et reprend maintenant.

**Raison de la pause :** waiting
**En attente de :** approval on issue #123
**Condition remplie :** github_comment
**Iteration précédente :** 3
**Mode précédent :** code
**Modèle précédent :** sonnet

**Contexte de l'exécution précédente (dernières lignes) :**
```
LAST-OUTPUT-SNIPPET
```

=== INSTRUCTIONS ===
La condition d'attente est maintenant remplie. Reprends la tâche là où elle a été interrompue.
"@
            Test-HasApprovalAssertion $oldPrompt | Should -BeTrue
        }

        It 'Does NOT flag the NEW prompt (the hardening holds)' {
            $ws = New-WaitState -ResumeWhen 'github_comment' -WaitFor 'WAITFOR-SENTINEL-github-approved'
            $p = Build-ResumePrompt -WaitState $ws -OriginalPrompt 'ORIGINAL-PROMPT-SENTINEL'
            Test-HasApprovalAssertion $p | Should -BeFalse
        }
    }

    Context 'Structural guards on the worker resume functions (logs)' {

        It 'Test-WaitStateReady code is non-empty and no longer asserts "reprise autorisée"' {
            # The negative assertion is only meaningful on real code — an empty string would
            # vacuously pass every `Should -Not -Match`.
            $script:WaitStateReadyCode | Should -Not -BeNullOrEmpty
            $script:WaitStateReadyCode | Should -Not -Match 'reprise autorisée'
            # positive control: the predicate bites on the pre-fix shape
            'Timeout expiré (2h >= 1h) - reprise autorisée' | Should -Match 'reprise autorisée'
        }

        It 'Test-GitHubDecision code is non-empty and no longer asserts "reprise autorisée" nor "approval détecté"' {
            $script:GitHubDecisionCode | Should -Not -BeNullOrEmpty
            $script:GitHubDecisionCode | Should -Not -Match 'reprise autorisée'
            $script:GitHubDecisionCode | Should -Not -Match 'approval détecté'
            # positive controls
            'Issue #1 est fermée - reprise autorisée' | Should -Match 'reprise autorisée'
            'Commentaire approval détecté: x'           | Should -Match 'approval détecté'
        }

        It 'Build-ResumePrompt code is non-empty and no longer asserts "Condition remplie :" nor "est maintenant remplie"' {
            $script:ResumePromptCode | Should -Not -BeNullOrEmpty
            $script:ResumePromptCode | Should -Not -Match 'Condition remplie :'
            $script:ResumePromptCode | Should -Not -Match 'est maintenant remplie'
            # positive controls
            '**Condition remplie :** yes'                      | Should -Match 'Condition remplie :'
            "La condition d'attente est maintenant remplie"    | Should -Match 'est maintenant remplie'
        }
    }
}
