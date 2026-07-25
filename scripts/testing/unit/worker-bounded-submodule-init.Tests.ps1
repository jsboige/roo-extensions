# Tests unitaires pour le fix #2944 — git submodule update --init --recursive
# non-borné dans Create-Worktree + Reset-WorktreeForMaintenance.
#
# Symptôme : la schtask Claude-Worker sur ai-01 a atteint sa limite d'exécution
# (LastTaskResult=267014 = terminated) sans qu'aucune logique d'escalade ne
# s'active, parce que le process était figé sur un git submodule update qui ne
# rendait jamais la main (hang credentials ou stall réseau). Le worker doit
# borner l'appel par wall-clock et logguer l'abandon.
#
# Trois gardes complémentaires :
#   (a) GIT_TERMINAL_PROMPT=0 + GCM_INTERACTIVE=never → hang credentials = erreur
#   (b) http.lowSpeedLimit=1000 + http.lowSpeedTime=60 → stall réseau = abort
#   (c) Start-Job + Wait-Job -Timeout → plafond wall-clock dur + WARN explicite
#
# Syntaxe Pester v3 (Windows PowerShell 5.1) — cf. nested-worktree-guard.Tests.ps1
#
# Usage :
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Import-Module Pester -RequiredVersion 3.4.0 -Force; Invoke-Pester .\scripts\testing\unit\worker-bounded-submodule-init.Tests.ps1"

Describe "Bounded Submodule Init - #2944 (worker hang prevention)" {

    $projectRoot = (Resolve-Path -Path "$PSScriptRoot\..\..\..").Path
    $workerScript = Join-Path $projectRoot "scripts\scheduling\start-claude-worker.ps1"
    $content = Get-Content $workerScript -Raw

    # ---------------------------------------------------------------------------
    # Guard (a) : env vars process-wide + inside helper scriptblock
    # ---------------------------------------------------------------------------

    Context "Guard (a) - GIT_TERMINAL_PROMPT / GCM_INTERACTIVE (no interactive prompts)" {

        It "Must set GIT_TERMINAL_PROMPT=0 at script level (covers ALL git calls)" {
            ($content -match '\$env:GIT_TERMINAL_PROMPT\s*=\s*"0"') | Should Be $true
        }

        It "Must set GCM_INTERACTIVE=never at script level" {
            ($content -match '\$env:GCM_INTERACTIVE\s*=\s*"never"') | Should Be $true
        }

        It "Env-var block must reference #2944 for traceability" {
            $blockPos = $content.IndexOf('#2944: Bounded git execution')
            $blockPos | Should BeGreaterThan 0
        }

        It "Env-var block must explain why (headless worker, scheduler kill)" {
            $blockPos = $content.IndexOf('#2944: Bounded git execution')
            $window = $content.Substring($blockPos, 600)
            ($window -match 'LastTaskResult=267014') | Should Be $true
        }
    }

    # ---------------------------------------------------------------------------
    # Helper function structure
    # ---------------------------------------------------------------------------

    Context "Helper - Invoke-BoundedSubmoduleInit exists and is well-formed" {

        It "Must define the Invoke-BoundedSubmoduleInit function" {
            ($content -match 'function Invoke-BoundedSubmoduleInit') | Should Be $true
        }

        It "Helper must be defined BEFORE Create-Worktree (so it can be called)" {
            $helperPos = $content.IndexOf('function Invoke-BoundedSubmoduleInit')
            $createPos = $content.IndexOf('function Create-Worktree')
            $helperPos | Should BeGreaterThan 0
            $createPos | Should BeGreaterThan 0
            $createPos | Should BeGreaterThan $helperPos
        }

        It "Helper param block must accept WorktreePath (Mandatory)" {
            ($content -match '\[Parameter\(Mandatory=\$true\)\]\[string\]\$WorktreePath') | Should Be $true
        }

        It "Helper param block must support -Recurse switch" {
            ($content -match '\[switch\]\$Recurse') | Should Be $true
        }

        It "Helper param block must expose -TimeoutSeconds with default 600s" {
            ($content -match '\[int\]\$TimeoutSeconds\s*=\s*600') | Should Be $true
        }

        It "Helper must return \$false when WorktreePath is missing (graceful)" {
            $funcPos = $content.IndexOf('function Invoke-BoundedSubmoduleInit')
            $window = $content.Substring($funcPos, 2000)
            ($window -match 'WorktreePath missing') | Should Be $true
        }
    }

    # ---------------------------------------------------------------------------
    # Guard (b) : http.lowSpeedLimit + http.lowSpeedTime inside scriptblock
    # ---------------------------------------------------------------------------

    Context "Guard (b) - http.lowSpeedLimit / http.lowSpeedTime (network stall abort)" {

        It "Helper scriptblock must set http.lowSpeedLimit=1000" {
            ($content -match 'http\.lowSpeedLimit=1000') | Should Be $true
        }

        It "Helper scriptblock must set http.lowSpeedTime=60" {
            ($content -match 'http\.lowSpeedTime=60') | Should Be $true
        }

        It "Helper scriptblock must re-state GIT_TERMINAL_PROMPT=0 (child process)" {
            $funcPos = $content.IndexOf('function Invoke-BoundedSubmoduleInit')
            $window = $content.Substring($funcPos, 3000)
            ($window -match '\$env:GIT_TERMINAL_PROMPT = "0"') | Should Be $true
        }

        It "Helper scriptblock must re-state GCM_INTERACTIVE=never (child process)" {
            $funcPos = $content.IndexOf('function Invoke-BoundedSubmoduleInit')
            $window = $content.Substring($funcPos, 3000)
            ($window -match '\$env:GCM_INTERACTIVE = "never"') | Should Be $true
        }
    }

    # ---------------------------------------------------------------------------
    # Guard (c) : Start-Job + Wait-Job -Timeout (wall-clock cap)
    # ---------------------------------------------------------------------------

    Context "Guard (c) - Start-Job / Wait-Job -Timeout / Stop-Job (wall-clock cap)" {

        It "Helper must wrap git call in Start-Job -ScriptBlock" {
            $funcPos = $content.IndexOf('function Invoke-BoundedSubmoduleInit')
            $window = $content.Substring($funcPos, 3000)
            ($window -match 'Start-Job -ScriptBlock') | Should Be $true
        }

        It "Helper must Wait-Job -Timeout (bounded)" {
            $funcPos = $content.IndexOf('function Invoke-BoundedSubmoduleInit')
            $window = $content.Substring($funcPos, 3000)
            ($window -match 'Wait-Job -Job \$job -Timeout \$TimeoutSeconds') | Should Be $true
        }

        It "Helper must Stop-Job on timeout (kill the hung process)" {
            $funcPos = $content.IndexOf('function Invoke-BoundedSubmoduleInit')
            $window = $content.Substring($funcPos, 3000)
            ($window -match 'Stop-Job -Job \$job') | Should Be $true
        }

        It "Helper must Remove-Job -Force after stop (cleanup)" {
            $funcPos = $content.IndexOf('function Invoke-BoundedSubmoduleInit')
            $window = $content.Substring($funcPos, 3000)
            ($window -match 'Remove-Job -Job \$job -Force') | Should Be $true
        }

        It "Helper must log WARN with TIMED OUT marker (not silent)" {
            $funcPos = $content.IndexOf('function Invoke-BoundedSubmoduleInit')
            $window = $content.Substring($funcPos, 3000)
            ($window -match 'TIMED OUT') | Should Be $true
            ($window -match '"WARN"') | Should Be $true
        }

        It "Helper must return \$false on timeout (signal failure to caller)" {
            $funcPos = $content.IndexOf('function Invoke-BoundedSubmoduleInit')
            $timeoutPos = $content.IndexOf('TIMED OUT', $funcPos)
            $window = $content.Substring($timeoutPos, 500)
            ($window -match 'return \$false') | Should Be $true
        }
    }

    # ---------------------------------------------------------------------------
    # Wiring : both recursive call sites use the helper
    # ---------------------------------------------------------------------------

    Context "Wiring - both recursive sites delegate to helper" {

        It "Create-Worktree must call helper with -Recurse" {
            $createPos = $content.IndexOf('function Create-Worktree')
            $createEnd = $content.IndexOf('function Stop-WorktreeChildProcesses', $createPos)
            $window = $content.Substring($createPos, $createEnd - $createPos)
            ($window -match 'Invoke-BoundedSubmoduleInit -WorktreePath \$WorktreePath -Recurse') | Should Be $true
        }

        It "Reset-WorktreeForMaintenance must call helper with -Recurse" {
            $resetPos = $content.IndexOf('function Reset-WorktreeForMaintenance')
            $resetEnd = $content.IndexOf('function Invoke-BoundedSubmoduleInit', $resetPos)
            $window = $content.Substring($resetPos, $resetEnd - $resetPos)
            ($window -match 'Invoke-BoundedSubmoduleInit -WorktreePath \$WorktreePath -Recurse') | Should Be $true
        }

        It "Create-Worktree must gate the helper call behind #2944 marker" {
            $createPos = $content.IndexOf('function Create-Worktree')
            $createEnd = $content.IndexOf('function Stop-WorktreeChildProcesses', $createPos)
            $window = $content.Substring($createPos, $createEnd - $createPos)
            ($window -match '#2944') | Should Be $true
        }

        It "Reset-WorktreeForMaintenance must reference #2944 in its helper call comment" {
            $resetPos = $content.IndexOf('function Reset-WorktreeForMaintenance')
            $resetEnd = $content.IndexOf('function Invoke-BoundedSubmoduleInit', $resetPos)
            $window = $content.Substring($resetPos, $resetEnd - $resetPos)
            ($window -match '#2944') | Should Be $true
        }
    }

    # ---------------------------------------------------------------------------
    # Regression : unrelated sibling calls must be untouched (anti-speculative #1936)
    # ---------------------------------------------------------------------------

    Context "Regression - scope discipline (no undemanded refactors)" {

        It "Sync-McpSubmoduleBuild must keep its non-recursive submodule call untouched" {
            # L1690-equivalent: `git submodule update --init mcps/internal` — single submodule,
            # not recursive, different risk profile. Issue scope was the recursive call only.
            $syncPos = $content.IndexOf('function Sync-McpSubmoduleBuild')
            $syncEnd = $content.IndexOf('function Reset-WorktreeForMaintenance', $syncPos)
            $window = $content.Substring($syncPos, $syncEnd - $syncPos)
            ($window -match 'git -C \$Path submodule update --init mcps/internal') | Should Be $true
        }

        It "No unbounded recursive submodule update must remain outside the helper" {
            # Find every occurrence of `submodule update --init --recursive` and verify
            # each one lives INSIDE the helper scriptblock (the bounded path).
            $pattern = 'submodule update --init --recursive'
            $idx = 0
            while (($idx = $content.IndexOf($pattern, $idx)) -ge 0) {
                $inHelper = ($idx -gt $content.IndexOf('function Invoke-BoundedSubmoduleInit')) -and
                            ($idx -lt $content.IndexOf('function Create-Worktree'))
                $inHelper | Should Be $true
                $idx += $pattern.Length
            }
            $true | Should Be $true  # ensure Describe block runs even if 0 matches
        }
    }
}
