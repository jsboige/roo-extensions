# call-sk-agent.Tests.ps1 - Offline tests for the vLLM model alias in call-sk-agent.ps1
# Issue #4698 / #3401 étape 4 : le corps de requête construit porte l'alias local-coding.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -Command "Invoke-Pester .\scripts\review\call-sk-agent.Tests.ps1"
#
# Note: compatible Pester 3.4.0 comme le test voisin auto-review.Tests.ps1 —
# assertions par throws inline (portables Pester 3.x ET 5+ : pas de syntaxe
# Should spécifique à une version, pas de fonction file-scope — Pester 5+
# n'expose pas les fonctions du fichier aux blocs It). Hors ligne, aucun appel réseau.

Describe "call-sk-agent.ps1 - vLLM model alias (#4698)" {

    Context "Variable definition" {

        It "Defines VllmModelId exactly once, at script head" {
            $scriptText = Get-Content (Join-Path $PSScriptRoot "call-sk-agent.ps1") -Raw
            $assignMatches = [regex]::Matches($scriptText, '(?m)^\s*\$VllmModelId\s*=\s*"([^"]+)"')
            if ($assignMatches.Count -ne 1) { throw "expected exactly 1 assignment of VllmModelId, got $($assignMatches.Count)" }
        }

        It "Assigns the claudish alias local-coding" {
            $scriptText = Get-Content (Join-Path $PSScriptRoot "call-sk-agent.ps1") -Raw
            $match = [regex]::Match($scriptText, '(?m)^\s*\$VllmModelId\s*=\s*"([^"]+)"')
            if (-not ($match.Success -and $match.Groups[1].Value -eq "local-coding")) { throw "expected local-coding, got '$($match.Groups[1].Value)'" }
        }
    }

    Context "Request body carries the alias (no network)" {

        It "Built body model field equals local-coding" {
            # Extraire la valeur depuis le script lui-même (source de vérité unique)
            $scriptText = Get-Content (Join-Path $PSScriptRoot "call-sk-agent.ps1") -Raw
            $modelId = [regex]::Match($scriptText, '(?m)^\s*\$VllmModelId\s*=\s*"([^"]+)"').Groups[1].Value

            # Construire le corps exactement comme Invoke-VllmDirect
            $bodyObj = @{
                model = $modelId
                messages = @(
                    @{ role = "system"; content = "system-prompt-placeholder" }
                    @{ role = "user"; content = "user-prompt-placeholder" }
                )
                max_tokens = 4000
                temperature = 0.3
            }
            $body = $bodyObj | ConvertTo-Json -Depth 5

            # Vérifier le JSON sérialisé (ce qui part sur le fil)
            $roundTrip = $body | ConvertFrom-Json
            if ($roundTrip.model -ne "local-coding") { throw "body model expected local-coding, got '$($roundTrip.model)'" }
            if ($roundTrip.messages.Count -ne 2) { throw "body messages expected 2, got $($roundTrip.messages.Count)" }
        }

        It "Key lookup filter uses the same variable, not a stale id" {
            $scriptText = Get-Content (Join-Path $PSScriptRoot "call-sk-agent.ps1") -Raw
            if (-not ($scriptText -match '\$_\.id -eq \$VllmModelId')) { throw "key lookup filter does not reference VllmModelId" }
            if ($scriptText -match 'qwen3\.5-35b-a3b') { throw "stale id qwen3.5-35b-a3b still present" }
        }
    }

    Context "Stale identifier removed" {

        It "Contains no occurrence of qwen3.5-35b-a3b" {
            $scriptText = Get-Content (Join-Path $PSScriptRoot "call-sk-agent.ps1") -Raw
            $hits = ([regex]::Matches($scriptText, 'qwen3\.5-35b-a3b')).Count
            if ($hits -ne 0) { throw "expected 0 occurrence of qwen3.5-35b-a3b, got $hits" }
        }

        It "Model field references the variable, not a literal" {
            $scriptText = Get-Content (Join-Path $PSScriptRoot "call-sk-agent.ps1") -Raw
            if (-not ($scriptText -match 'model = \$VllmModelId')) { throw "model field does not reference VllmModelId" }
        }
    }
}
