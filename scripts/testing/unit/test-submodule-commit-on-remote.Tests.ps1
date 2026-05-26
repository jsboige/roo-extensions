# Tests unitaires pour Test-SubmoduleCommitOnRemote du worker script (Guard #1156 v2)
# Guard: validates that a submodule commit is reachable from origin/main BEFORE
# using it as a pointer in the parent repo (anti phantom submodule pointer).
# Syntaxe Pester v3 (Windows PowerShell 5.1)
#
# Usage (Pester v3 explicit — required because the default Invoke-Pester on modern
# Windows loads Pester 5.x, which rejects v3 syntax like `Should Be` / `BeGreaterThan`):
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Import-Module Pester -RequiredVersion 3.4.0 -Force; Invoke-Pester .\scripts\testing\unit\test-submodule-commit-on-remote.Tests.ps1"
# Or inside an existing PowerShell session:
#   Import-Module Pester -RequiredVersion 3.4.0 -Force
#   Invoke-Pester .\scripts\testing\unit\test-submodule-commit-on-remote.Tests.ps1
#
# Contexte : Test-SubmoduleCommitOnRemote (start-claude-worker.ps1 L1970-2004) est
# le coeur de Reset-PhantomSubmodulePointers (Guard #1156 v2). La version actuelle
# utilise `git merge-base --is-ancestor` pour la verification canonique de containment.
# La version PRECEDENTE utilisait `git log origin/main -1 <commit>` qui ne testait PAS
# que le commit etait sur origin/main — elle se contentait de verifier que git log
# pouvait afficher le commit localement (exit 0 pour tout commit reachable).
#
# Ces tests sont des assertions statiques sur le code (Get-Content -Raw) pour figer
# la signature, la logique canonique, et empecher une regression vers l'ancien pattern.

Describe "Test-SubmoduleCommitOnRemote - Guard #1156 v2 submodule pointer safety" {

    $projectRoot = (Resolve-Path -Path "$PSScriptRoot\..\..\..").Path
    $workerScript = Join-Path $projectRoot "scripts\scheduling\start-claude-worker.ps1"
    $content = Get-Content $workerScript -Raw

    # ---------------------------------------------------------------------------
    # Structure : la fonction existe, est documentee, et accepte les bons params
    # ---------------------------------------------------------------------------

    Context "Function presence and signature" {

        It "Must define function Test-SubmoduleCommitOnRemote" {
            ($content -match 'function Test-SubmoduleCommitOnRemote') | Should Be $true
        }

        It "Must accept [string]\$SubmodulePath parameter" {
            # Window 1500 chars to reach past the .SYNOPSIS / .DESCRIPTION doc-comment
            # block (~17 lines) before hitting the param() declaration.
            $funcPos = $content.IndexOf('function Test-SubmoduleCommitOnRemote')
            $window  = $content.Substring($funcPos, 1500)
            ($window -match '\[string\]\$SubmodulePath') | Should Be $true
        }

        It "Must accept [string]\$Commit parameter" {
            $funcPos = $content.IndexOf('function Test-SubmoduleCommitOnRemote')
            $window  = $content.Substring($funcPos, 1500)
            ($window -match '\[string\]\$Commit') | Should Be $true
        }

        It "Must reference Guard #1156 v2 in documentation" {
            $funcPos = $content.IndexOf('function Test-SubmoduleCommitOnRemote')
            $window  = $content.Substring($funcPos, 1500)
            ($window -match 'Guard #1156 v2') | Should Be $true
        }
    }

    # ---------------------------------------------------------------------------
    # Logique canonique : fetch + merge-base --is-ancestor (NOT git log -1)
    # ---------------------------------------------------------------------------

    Context "Canonical containment check (#1156 v2)" {

        It "Must fetch origin main before checking containment" {
            $funcPos = $content.IndexOf('function Test-SubmoduleCommitOnRemote')
            $window  = $content.Substring($funcPos, 1500)
            ($window -match 'git -C \$SubmodulePath fetch origin main') | Should Be $true
        }

        It "Must use --quiet on the fetch to keep logs clean" {
            $funcPos = $content.IndexOf('function Test-SubmoduleCommitOnRemote')
            $window  = $content.Substring($funcPos, 1500)
            ($window -match 'fetch origin main --quiet') | Should Be $true
        }

        It "Must use merge-base --is-ancestor for canonical containment" {
            $funcPos = $content.IndexOf('function Test-SubmoduleCommitOnRemote')
            $window  = $content.Substring($funcPos, 1500)
            ($window -match 'merge-base --is-ancestor \$Commit origin/main') | Should Be $true
        }

        It "Must derive return value from `$LASTEXITCODE -eq 0" {
            $funcPos = $content.IndexOf('function Test-SubmoduleCommitOnRemote')
            $window  = $content.Substring($funcPos, 1500)
            ($window -match '\$LASTEXITCODE -eq 0') | Should Be $true
        }
    }

    # ---------------------------------------------------------------------------
    # Defensive behaviour : try/catch, returns boolean false on failure, WARN log
    # ---------------------------------------------------------------------------

    Context "Defensive error handling" {

        It "Must wrap logic in try/catch" {
            $funcPos = $content.IndexOf('function Test-SubmoduleCommitOnRemote')
            $window  = $content.Substring($funcPos, 1500)
            ($window -match 'try\s*\{') | Should Be $true
            ($window -match 'catch') | Should Be $true
        }

        It "Must log catch errors at WARN level" {
            $funcPos = $content.IndexOf('function Test-SubmoduleCommitOnRemote')
            $window  = $content.Substring($funcPos, 1500)
            ($window -match 'Write-Log .*Test-SubmoduleCommitOnRemote.*"WARN"') | Should Be $true
        }

        It "Must return `$false from catch (fail-closed: phantom suspicion)" {
            $funcPos = $content.IndexOf('function Test-SubmoduleCommitOnRemote')
            $window  = $content.Substring($funcPos, 1500)
            # The function returns $false in the catch block (not $true) — failing closed
            # so a fetch error doesn't accidentally green-light a phantom pointer.
            ($window -match '(?s)catch\s*\{[^}]*return \$false') | Should Be $true
        }
    }

    # ---------------------------------------------------------------------------
    # Regression guard : the OLD broken implementation must NOT come back
    # ---------------------------------------------------------------------------

    Context "Regression guard - no fallback to broken pre-#1156-v2 logic" {

        It "Must NOT use the old broken `git log origin/main -1 \$Commit` pattern" {
            # The previous (broken) implementation tested with `git log origin/main -1 <commit>`
            # which returns 0 for any commit locally reachable, not just commits on origin/main.
            $funcPos = $content.IndexOf('function Test-SubmoduleCommitOnRemote')
            $window  = $content.Substring($funcPos, 1500)
            ($window -match 'git -C \$SubmodulePath log origin/main -1 \$Commit') | Should Be $false
        }

        It "Documentation must call out the old broken pattern (rationale preserved)" {
            # The DESCRIPTION block explains why merge-base --is-ancestor replaced git log -1.
            # Keeping this rationale prevents future regressions ("simplification" undoing the fix).
            $funcPos = $content.IndexOf('function Test-SubmoduleCommitOnRemote')
            $window  = $content.Substring($funcPos, 1500)
            ($window -match 'git log origin/main -1') | Should Be $true
        }
    }

    # ---------------------------------------------------------------------------
    # Integration : the guard is actually called by Reset-PhantomSubmodulePointers
    # ---------------------------------------------------------------------------

    Context "Wiring - guard is wired into Reset-PhantomSubmodulePointers" {

        It "Reset-PhantomSubmodulePointers function must exist" {
            ($content -match 'function Reset-PhantomSubmodulePointers') | Should Be $true
        }

        It "Reset-PhantomSubmodulePointers must call Test-SubmoduleCommitOnRemote" {
            $resetPos = $content.IndexOf('function Reset-PhantomSubmodulePointers')
            $resetPos | Should BeGreaterThan 0
            # Window large enough to cover the full Reset-PhantomSubmodulePointers body
            # (it ends roughly before function Remove-NestedSubmoduleWorktrees ~L2072).
            $window = $content.Substring($resetPos, 5000)
            ($window -match 'Test-SubmoduleCommitOnRemote') | Should Be $true
        }
    }

    # ---------------------------------------------------------------------------
    # Behaviour mimicry : reimplements the function's truth table on a sandbox repo
    # to validate that `merge-base --is-ancestor` actually distinguishes commits
    # on origin/main from local-only commits.
    # ---------------------------------------------------------------------------

    Context "Containment predicate behaviour (sandbox repo)" {

        # Replica of the function's core check, without the worker's logging / fetch noise.
        # We build two repos (origin + local), commit on origin, then create a local-only
        # commit, and assert that the predicate refuses the orphan.
        function Test-Containment {
            param([string]$Repo, [string]$Commit)
            git -C $Repo merge-base --is-ancestor $Commit origin/main 2>&1 | Out-Null
            return ($LASTEXITCODE -eq 0)
        }

        $sandbox = $null

        It "Builds a sandbox origin/local repo pair without error" {
            $sandbox = Join-Path $env:TEMP "submod-commit-remote-test-$([guid]::NewGuid().Guid.Substring(0,8))"
            $origin  = Join-Path $sandbox 'origin'
            $local   = Join-Path $sandbox 'local'

            # Bare-ish origin (use a non-bare init + push from a worktree so commits
            # actually land in refs/heads/main with a working index).
            New-Item -ItemType Directory -Path $origin -Force | Out-Null
            git -C $origin init --quiet --initial-branch=main 2>&1 | Out-Null
            'origin-1' | Out-File -FilePath (Join-Path $origin 'file.txt') -Encoding ascii
            git -C $origin -c user.email=test@example.com -c user.name=test add . 2>&1 | Out-Null
            git -C $origin -c user.email=test@example.com -c user.name=test commit -m "origin commit" --quiet 2>&1 | Out-Null

            # Clone to local
            git clone --quiet $origin $local 2>&1 | Out-Null

            # Create a local-only commit (NOT pushed)
            'local-orphan' | Out-File -FilePath (Join-Path $local 'orphan.txt') -Encoding ascii
            git -C $local -c user.email=test@example.com -c user.name=test add . 2>&1 | Out-Null
            git -C $local -c user.email=test@example.com -c user.name=test commit -m "local orphan" --quiet 2>&1 | Out-Null

            Test-Path $local | Should Be $true

            # Stash sandbox path for following Its (script-scope to dodge It-scope isolation)
            $script:Sandbox = $sandbox
            $script:Local   = $local
        }

        It "ACCEPTS the commit at origin/main (reachable)" {
            $local = $script:Local
            $originHead = (git -C $local rev-parse origin/main).Trim()
            Test-Containment $local $originHead | Should Be $true
        }

        It "REFUSES the local-only commit not pushed to origin (phantom)" {
            $local = $script:Local
            $orphan = (git -C $local rev-parse HEAD).Trim()
            # Sanity check: it must differ from origin/main
            $originHead = (git -C $local rev-parse origin/main).Trim()
            ($orphan -ne $originHead) | Should Be $true
            Test-Containment $local $orphan | Should Be $false
        }

        It "Cleans up the sandbox" {
            if ($script:Sandbox -and (Test-Path $script:Sandbox)) {
                Remove-Item -Recurse -Force $script:Sandbox -ErrorAction SilentlyContinue
            }
            (-not (Test-Path $script:Sandbox)) | Should Be $true
        }
    }
}
