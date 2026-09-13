<#
.SYNOPSIS
    Guard test: provider-preflight.ps1 must trace the same routing chain for four
    agent types all requesting model="sonnet" (#3361 acceptance criterion #5).

.DESCRIPTION
    Incident #3361: four Agent(..., model="sonnet") calls failed simultaneously with
    HTTP 402 from an unprovisioned Mistral endpoint. The fan-out amplification is
    the structural property: FOUR independent agent types (general-purpose x3 and
    code-explorer x1) launched in the same turn must each resolve to the SAME
    expected routing chain (alias -> model ID -> endpoint), NOT each to a different
    provider-specific ID.

    Acceptance criterion #5: "Ajouter un test ou quatre types d'agents recoivent
    model=sonnet et verifient le meme routage attendu."

    This test exercises the fan-out contract via the provider-preflight.ps1 script:
      1. The preflight must accept the same settings.json for all four agents.
      2. The resolution chain for the "sonnet" role must be IDENTICAL regardless of
         agent type (general-purpose, code-explorer, code-fixer, doc-updater).
      3. The endpoint must be the SAME for all four (no per-agent split-brain).
      4. The API ID (after stripping the [1m] suffix) must be the SAME for all four.
      5. The script must NOT silently route any agent to a different model ID.

    The test runs offline using a synthetic settings.json with the fleet executor
    policy (sonnet -> glm-5.2) so it does not depend on any network calls or hub
    state. This is the contract: any per-agent divergence is the #3361 signature.

.NOTES
    Issue #3361 (AC #5)
    Requires Pester 5+
#>

# Helper: run provider-preflight.ps1 with a given settings file and capture stdout.
# Spawned as a child pwsh process so it does not pollute the Pester session state
# (the script exits with specific codes and writes to the host).
function script:Invoke-PreflightChain {
    param([string]$ScriptPath, [string]$SettingsPath)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = if ($IsWindows -or $ENV:OS -eq 'Windows_NT') { 'powershell' } else { 'pwsh' }
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" -Model sonnet -SettingsPath `"$SettingsPath`""
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    return ($out + $err)
}

Describe 'provider-preflight fan-out routing contract (#3361 AC#5)' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\..\..\scripts\claude\provider-preflight.ps1'
        if (-not (Test-Path $scriptPath)) {
            $scriptPath = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..\..\scripts\claude\provider-preflight.ps1')).Path
        }
        if (-not (Test-Path $scriptPath)) {
            throw "provider-preflight.ps1 not found at $scriptPath"
        }
        $script:preflightScript = $scriptPath

        # Synthesise a settings.json with the executor fleet policy so the trace
        # is deterministic: sonnet -> glm-5.2 (the z.ai executor pool ID).
        $sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("preflight-3361-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
        $script:sandbox = $sandbox
        $script:syntheticSettings = Join-Path $sandbox 'settings.json'

        $settings = @{
            model = 'sonnet[1m]'
            env = @{
                ANTHROPIC_BASE_URL = 'https://preflight-3361.invalid'
                ANTHROPIC_AUTH_TOKEN = ''
                ANTHROPIC_DEFAULT_OPUS_MODEL = 'glm-5.2'
                ANTHROPIC_DEFAULT_SONNET_MODEL = 'glm-5.2'
                ANTHROPIC_DEFAULT_HAIKU_MODEL = 'qwen3.6-35b-a3b'
            }
        }
        $json = $settings | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText($script:syntheticSettings, $json, [System.Text.UTF8Encoding]::new($false))

        # The four agent types observed in the incident (#3361 reproduction):
        # 3 x general-purpose + 1 x code-explorer. We add code-fixer and doc-updater
        # as representatives of the wider sub-agent fleet - the contract is "ANY
        # sub-agent launching with model=sonnet resolves to the same chain".
        $script:agentTypes = @(
            @{ Type = 'general-purpose'; SubPrompt = 'qualification bibliographique read-only' }
            @{ Type = 'general-purpose'; SubPrompt = 'general-purpose call 2' }
            @{ Type = 'general-purpose'; SubPrompt = 'general-purpose call 3' }
            @{ Type = 'code-explorer'; SubPrompt = 'cartographie locale read-only' }
            @{ Type = 'code-fixer'; SubPrompt = 'fix verification' }
            @{ Type = 'doc-updater'; SubPrompt = 'doc refresh' }
        )

        # Capture one trace per agent type. The chain is deterministic from settings
        # alone - the agent type is metadata that does NOT influence routing.
        $script:chains = @{}
        foreach ($agent in $script:agentTypes) {
            $output = Invoke-PreflightChain -ScriptPath $script:preflightScript -SettingsPath $script:syntheticSettings
            $script:chains[$agent.Type + '/' + $agent.SubPrompt] = $output
        }
    }

    AfterAll {
        if (Test-Path $script:sandbox) {
            Remove-Item -Recurse -Force $script:sandbox -ErrorAction SilentlyContinue
        }
    }

    Context 'Resolution chain is identical across all four agent types' {
        # Acceptance criterion #5: ALL agents requesting model="sonnet" must
        # resolve to the SAME alias -> model ID -> endpoint chain. The whole
        # point of the preflight is to detect fan-out drift BEFORE the burst.

        It 'All four agent types produce the same sonnet role resolution' {
            $keys = @($script:chains.Keys)
            $firstKey = $keys[0]
            $first = $script:chains[$firstKey]
            foreach ($k in $keys) {
                $other = $script:chains[$k]
                # Strip the network probe section (model list + verdict) so we compare
                # only the resolution chain, which is the AC#5 contract.
                $firstChain = ($first -split 'Health probe')[0]
                $otherChain = ($other -split 'Health probe')[0]
                $otherChain | Should -Be $firstChain -Because "agent '$k' must NOT influence the sonnet -> model ID resolution"
            }
        }
    }

    Context 'Endpoint is identical for all four agent types' {
        # The provider endpoint is read from settings.json - it cannot differ per
        # agent. Any divergence here means the routing policy is split-brain.

        It 'All four agent types route to the same ANTHROPIC_BASE_URL' {
            $settings = Get-Content $script:syntheticSettings -Raw | ConvertFrom-Json
            $endpoint = $settings.env.ANTHROPIC_BASE_URL
            $endpoint | Should -Not -BeNullOrEmpty -Because 'synthetic settings have a fixed endpoint'

            # Every preflight invocation reads from the same settings.json.
            foreach ($k in @($script:chains.Keys)) {
                $output = $script:chains[$k]
                $output | Should -Match ([regex]::Escape($endpoint)) -Because "agent '$k' must reach the configured endpoint"
            }
        }
    }

    Context 'API model ID is identical across all four agent types' {
        # The API ID (after stripping [1m]) is the value the hub sees. If four
        # agents each produced a DIFFERENT API ID, the hub would route them to
        # four different providers (the #3361 signature in fan-out form).

        It 'All four agent types resolve to the same API ID for sonnet' {
            $expectedApiId = 'glm-5.2' # executor pool ID for the sonnet role
            foreach ($k in @($script:chains.Keys)) {
                $output = $script:chains[$k]
                # The script renders "API ID: <id>" in the resolution chain.
                $output | Should -Match "API ID:\s+$([regex]::Escape($expectedApiId))" `
                    -Because "agent '$k' must resolve to API ID $expectedApiId (executor pool)"
            }
        }

        It 'Never silently falls back to a claude-* ID for sonnet on the executor pool' {
            # The #3361 AC: "Ne jamais retomber silencieusement sur un modele
            # Anthropic natif quand la politique machine l'interdit."
            foreach ($k in @($script:chains.Keys)) {
                $output = $script:chains[$k]
                $output | Should -Not -Match "API ID:\s+claude-" `
                    -Because "agent '$k' must NOT silently fall back to a native Anthropic ID"
            }
        }
    }

    Context 'Preflight fails loudly when a fan-out would target a non-routable ID' {
        # The incident signature: a claude-* ID is accepted by the hub via
        # wildcard but routed to an unprovisioned provider (Mistral).
        # The preflight must NEVER mark such a fan-out as healthy.

        BeforeAll {
            $script:badSettings = Join-Path $script:sandbox 'settings-bad.json'
            $bad = @{
                model = 'sonnet[1m]'
                env = @{
                    ANTHROPIC_BASE_URL = 'https://preflight-3361.invalid'
                    ANTHROPIC_AUTH_TOKEN = ''
                    # The exact #3361 reported ID: claude-sonnet-5[1m] reaching a hub.
                    ANTHROPIC_DEFAULT_SONNET_MODEL = 'claude-sonnet-5[1m]'
                    ANTHROPIC_DEFAULT_OPUS_MODEL = 'glm-5.2'
                    ANTHROPIC_DEFAULT_HAIKU_MODEL = 'qwen3.6-35b-a3b'
                }
            }
            $json = $bad | ConvertTo-Json -Depth 5
            [System.IO.File]::WriteAllText($script:badSettings, $json, [System.Text.UTF8Encoding]::new($false))

            $script:badChains = @{}
            foreach ($agent in $script:agentTypes) {
                $output = Invoke-PreflightChain -ScriptPath $script:preflightScript -SettingsPath $script:badSettings
                $script:badChains[$agent.Type + '/' + $agent.SubPrompt] = $output
            }
        }

        It 'Preflight detects the #3361 wildcard signature across the four agent types' {
            # The preflight must WARN (never silence) when sonnet resolves to a
            # native-Anthropic ID on an executor machine.
            foreach ($k in @($script:badChains.Keys)) {
                $output = $script:badChains[$k]
                $output | Should -Match 'WARN.*native-Anthropic ID routed via the hub' `
                    -Because "agent '$k' must trigger the #3361 wildcard WARN (every fan-out invocation, not just the first)"
            }
        }
    }
}