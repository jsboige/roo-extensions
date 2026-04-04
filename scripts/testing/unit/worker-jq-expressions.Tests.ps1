# Tests unitaires pour les expressions jq du worker script
# Valide que les commandes gh/jq utilisees par start-claude-worker.ps1 fonctionnent correctement.
# Syntaxe Pester v3 (Windows PowerShell 5.1)
#
# Pre-requis: gh CLI authentifie, acces au repo jsboige/roo-extensions
# Usage: Invoke-Pester .\scripts\testing\unit\worker-jq-expressions.Tests.ps1

Describe "Worker Script - jq Expressions" {

    $projectRoot = (Resolve-Path -Path "$PSScriptRoot\..\..\..").Path
    $workerScript = Join-Path $projectRoot "scripts\scheduling\start-claude-worker.ps1"

    Context "Script file validation" {
        It "start-claude-worker.ps1 must exist" {
            Test-Path $workerScript | Should Be $true
        }

        It "Must NOT use inline jq test() with bracket escapes (regression guard)" {
            $content = Get-Content $workerScript -Raw
            # Inline test() with \[ breaks with new jq versions AND PowerShell quoting
            ($content -match "--jq '.*test\(") | Should Be $false
        }

        It "Must use variable-based jq expressions for contains()" {
            $content = Get-Content $workerScript -Raw
            # The fix: store jq expression in $jqExpr variable with escaped quotes
            ($content -match '\$jqExpr\s*=') | Should Be $true
            ($content -match '\$jqClaimExpr\s*=') | Should Be $true
        }
    }

    Context "jq dispatch parsing - PowerShell compatible" {

        It "Dispatch jq expression must execute without error" {
            $jqExpr = '[.comments[-10:][] | .body | select(contains(\"[DISPATCH]\") or contains(\"[CLAIMED]\") or contains(\"[RESULT]\"))]'
            $result = & gh issue view 1065 --repo jsboige/roo-extensions --json comments --jq $jqExpr 2>&1
            $LASTEXITCODE | Should Be 0
        }

        It "Dispatch jq result must be parseable JSON" {
            $jqExpr = '[.comments[-10:][] | .body | select(contains(\"[DISPATCH]\") or contains(\"[CLAIMED]\") or contains(\"[RESULT]\"))]'
            $result = & gh issue view 1065 --repo jsboige/roo-extensions --json comments --jq $jqExpr 2>&1
            if ($LASTEXITCODE -eq 0 -and $result) {
                $parsed = $result | ConvertFrom-Json
                $parsed | Should Not BeNullOrEmpty
            }
        }

        It "Must find DISPATCH comments on dispatched issues" {
            $jqExpr = '[.comments[-10:][] | .body | select(contains(\"[DISPATCH]\"))]'
            $result = & gh issue view 1065 --repo jsboige/roo-extensions --json comments --jq $jqExpr 2>&1
            if ($LASTEXITCODE -eq 0 -and $result) {
                $parsed = $result | ConvertFrom-Json
                $parsed.Count | Should BeGreaterThan 0
            }
        }
    }

    Context "jq claim parsing - PowerShell compatible" {

        It "Claim jq expression must execute without error" {
            $jqClaimExpr = '[.comments[-5:][] | .body | select(contains(\"[CLAIMED]\"))]'
            $result = & gh issue view 1065 --repo jsboige/roo-extensions --json comments --jq $jqClaimExpr 2>&1
            $LASTEXITCODE | Should Be 0
        }

        It "Claim jq result must be parseable JSON" {
            $jqClaimExpr = '[.comments[-5:][] | .body | select(contains(\"[CLAIMED]\"))]'
            $result = & gh issue view 1065 --repo jsboige/roo-extensions --json comments --jq $jqClaimExpr 2>&1
            if ($LASTEXITCODE -eq 0 -and $result) {
                { $result | ConvertFrom-Json } | Should Not Throw
            }
        }
    }

    Context "jq edge cases" {

        It "Must handle special characters in comment bodies" {
            # Issue 1061 has markdown tables, code blocks, etc.
            $jqExpr = '[.comments[-10:][] | .body | select(contains(\"[DISPATCH]\") or contains(\"[CLAIMED]\") or contains(\"[RESULT]\"))]'
            $result = & gh issue view 1061 --repo jsboige/roo-extensions --json comments --jq $jqExpr 2>&1
            $LASTEXITCODE | Should Be 0
        }
    }
}

Describe "Worker Script - Model Guard" {

    $projectRoot = (Resolve-Path -Path "$PSScriptRoot\..\..\..").Path
    $workerScript = Join-Path $projectRoot "scripts\scheduling\start-claude-worker.ps1"
    $content = Get-Content $workerScript -Raw

    Context "Harness size documentation" {
        It "Must NOT reference 114K tokens (obsolete)" {
            ($content -match '114K tokens') | Should Be $false
        }

        It "Must reference updated harness size (~24K tokens)" {
            ($content -match '24K tokens') | Should Be $true
        }
    }

    Context "Minimum model configuration" {
        It "MinimumModel must be defined" {
            ($content -match '\$MinimumModel\s*=\s*"(haiku|sonnet|opus)"') | Should Be $true
        }
    }
}
