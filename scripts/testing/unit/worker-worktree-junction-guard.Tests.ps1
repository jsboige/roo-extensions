# Tests unitaires — jonctions retirees AVANT toute suppression recursive d'un worktree
#
# `git worktree remove --force` descend dans une jonction et supprime l'arbre de sa CIBLE ;
# `Remove-Item -Recurse` de PS 5.1 fait de meme. Mesure le 29/09 sur ai-01
# (worker-20260929-124410.log l.30-31) : un agent avait jonctionne
# D:/dev/mcp-wt-2191-view-pg/servers/roo-state-manager/node_modules vers le node_modules du
# checkout principal, qui porte lui-meme un auto-lien npm (node_modules/roo-state-manager ->
# racine du serveur). La garde #2123 a suivi les deux liens : .env, build/ et 147 fichiers
# suivis du serveur principal supprimes.
#
# Syntaxe Pester v5 — execute en CI par le job `unit-pester` via
# scripts/testing/run-pester-tests.ps1. Les assertions statiques tournent partout ; le test
# comportemental (vraies jonctions) ne tourne que sous Windows.
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/worker-worktree-junction-guard.Tests.ps1 -Output Detailed"

BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $script:workerScript = Join-Path $projectRoot "scripts/scheduling/start-claude-worker.ps1"
    $script:content = Get-Content $script:workerScript -Raw

    function Get-FunctionBody([string]$Name) {
        $pos = $script:content.IndexOf("function $Name")
        if ($pos -lt 0) { return '' }
        $body = $script:content.Substring($pos)
        $next = $body.IndexOf("`nfunction ", 1)
        if ($next -gt 0) { $body = $body.Substring(0, $next) }
        return $body
    }

    $script:helperBody = Get-FunctionBody 'Remove-WorktreeReparsePoints'
    $script:removeBody = Get-FunctionBody 'Remove-Worktree {'
    $script:nestedBody = Get-FunctionBody 'Remove-NestedSubmoduleWorktrees'
}

Describe "Worker - jonctions retirees avant suppression recursive" {

    Context "Le helper" {

        It "Doit etre defini" {
            $script:helperBody.Length | Should -BeGreaterThan 0
        }

        It "Ne descend pas dans un point d'analyse : teste ReparsePoint AVANT d'empiler" {
            $test = $script:helperBody.IndexOf('[System.IO.FileAttributes]::ReparsePoint')
            $push = $script:helperBody.IndexOf('$stack.Push($sub)')
            $test | Should -BeGreaterThan 0
            $push | Should -BeGreaterThan $test
        }

        It "Retire le lien par rmdir (jamais recursif) et ne supprime rien d'autre" {
            $script:helperBody | Should -Match 'rmdir ""\$\(\$sub\.FullName\)""'
            $script:helperBody | Should -Not -Match 'rmdir /s'
            $script:helperBody | Should -Not -Match 'Remove-Item'
        }
    }

    Context "Remove-Worktree" {

        It "Appelle le helper avant la premiere suppression recursive" {
            $guard = $script:removeBody.IndexOf('Remove-WorktreeReparsePoints $WorktreePath')
            $gitRm = $script:removeBody.IndexOf('worktree remove ""$WorktreePath"" --force')
            $fsRm  = $script:removeBody.IndexOf('rmdir /s /q')
            $guard | Should -BeGreaterThan 0
            $gitRm | Should -BeGreaterThan $guard
            $fsRm  | Should -BeGreaterThan $guard
        }

        It "Abandonne la suppression si un lien n'a pas pu etre retire" {
            $script:removeBody | Should -Match '(?s)if \(-not \(Remove-WorktreeReparsePoints \$WorktreePath\)\) \{[^}]*return'
        }
    }

    Context "Remove-NestedSubmoduleWorktrees" {

        It "Chaque 'worktree remove --force' est precede d'un appel au helper qui lui est propre" {
            $sites = [regex]::Matches($script:nestedBody, 'worktree remove --force')
            $sites.Count | Should -Be 2
            $floor = 0
            foreach ($site in $sites) {
                $guard = $script:nestedBody.LastIndexOf('Remove-WorktreeReparsePoints', $site.Index)
                $guard | Should -BeGreaterThan $floor
                $floor = $site.Index
            }
        }

        It "Le nettoyage Remove-Item -Recurse de .claude/worktrees est lui aussi garde" {
            $rm = $script:nestedBody.IndexOf('Remove-Item -LiteralPath $smWtDir -Recurse')
            $rm | Should -BeGreaterThan 0
            $lastSite = $script:nestedBody.LastIndexOf('worktree remove --force')
            $script:nestedBody.LastIndexOf('Remove-WorktreeReparsePoints $smWtDir', $rm) | Should -BeGreaterThan $lastSite
        }
    }

    Context "Comportement (Windows seulement : vraies jonctions)" {

        It "Retire les jonctions sans toucher leur cible, meme avec un auto-lien en boucle" -Skip:($env:OS -ne 'Windows_NT') {
            $tokens = $null; $errs = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:workerScript, [ref]$tokens, [ref]$errs)
            $fn = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Remove-WorktreeReparsePoints' }, $true)
            function Write-Log { param($Message, $Level) }
            . ([scriptblock]::Create($fn.Extent.Text))

            $root = Join-Path ([System.IO.Path]::GetTempPath()) ("junction-guard-" + [guid]::NewGuid().ToString('N'))
            $server = Join-Path $root 'main/server'
            New-Item -ItemType Directory -Force (Join-Path $server 'node_modules/pkg') | Out-Null
            Set-Content (Join-Path $server '.env') 'secret'
            Set-Content (Join-Path $server 'node_modules/pkg/index.js') 'x'
            # auto-lien npm : node_modules/server -> racine du serveur (boucle)
            New-Item -ItemType Junction -Path (Join-Path $server 'node_modules/server') -Target $server | Out-Null
            $wt = Join-Path $root 'wt'
            New-Item -ItemType Directory -Force (Join-Path $wt 'servers/server') | Out-Null
            New-Item -ItemType Junction -Path (Join-Path $wt 'servers/server/node_modules') -Target (Join-Path $server 'node_modules') | Out-Null

            try {
                Remove-WorktreeReparsePoints $wt | Should -Be $true
                Test-Path (Join-Path $wt 'servers/server/node_modules') | Should -Be $false
                Remove-Item -LiteralPath $wt -Recurse -Force
                Test-Path (Join-Path $server '.env') | Should -Be $true
                Test-Path (Join-Path $server 'node_modules/pkg/index.js') | Should -Be $true
            } finally {
                & cmd /c "rmdir ""$(Join-Path $server 'node_modules\server')""" 2>&1 | Out-Null
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
