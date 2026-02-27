# call-sk-agent.ps1 - Call sk-agent for code review from PowerShell
#
# Two modes:
#   1. HTTP MCP (default): POST to sk-agent HTTP endpoint (localhost:8100 or skagents.myia.io)
#   2. Direct vLLM: Call vLLM OpenAI-compatible API with critic system prompt (fallback)
#
# Usage:
#   .\call-sk-agent.ps1 -Prompt "Review this diff: ..." [-Agent critic] [-Mode http]
#   .\call-sk-agent.ps1 -Prompt "Review this diff: ..." -Mode vllm

param(
    [Parameter(Mandatory=$true)]
    [string]$Prompt,

    [string]$Agent = "critic",

    [ValidateSet("http", "vllm")]
    [string]$Mode = "http",

    # sk-agent HTTP endpoint
    [string]$SkAgentUrl = "http://localhost:8100",

    # vLLM endpoint (fallback)
    [string]$VllmUrl = "http://localhost:5002/v1/chat/completions",

    # Max tokens for response
    [int]$MaxTokens = 4000,

    [switch]$ShowDebug
)

$ErrorActionPreference = "Stop"

# System prompt for code review (matches sk-agent critic agent)
$CriticSystemPrompt = @"
You are a rigorous quality reviewer. Stress-test code changes for bugs, logical gaps, edge cases, and security issues. Rate each finding as Critical/Major/Minor. If approved, say APPROVED with a brief note. Otherwise, list improvements by severity.

IMPORTANT: Do NOT include thinking/reasoning steps. Output ONLY the final structured review in markdown:
1. Summary (2-3 sentences)
2. Findings table (severity | category | description)
3. Verdict: APPROVE / APPROVE WITH FIXES / REJECT
"@

function Invoke-SkAgentHttp {
    param([string]$Prompt, [string]$Agent, [string]$Url)

    $ApiKey = $env:SK_AGENT_API_KEY
    if (-not $ApiKey) {
        # Try reading from sk-agent config directory
        $envFile = Join-Path $PSScriptRoot "..\..\mcps\internal\servers\sk-agent\.env"
        if (Test-Path $envFile) {
            $envLine = Select-String -Path $envFile -Pattern '^SK_AGENT_API_KEY=(.+)$' | Select-Object -First 1
            if ($envLine) {
                $ApiKey = $envLine.Matches[0].Groups[1].Value.Trim('"').Trim("'")
            }
        }
    }

    # MCP JSON-RPC request to call_agent tool
    $body = @{
        jsonrpc = "2.0"
        id = 1
        method = "tools/call"
        params = @{
            name = "call_agent"
            arguments = @{
                prompt = $Prompt
                agent = $Agent
            }
        }
    } | ConvertTo-Json -Depth 5 -Compress

    $headers = @{
        "Content-Type" = "application/json"
        "Accept" = "application/json, text/event-stream"
    }
    if ($ApiKey) {
        $headers["Authorization"] = "Bearer $ApiKey"
    }

    if ($ShowDebug) {
        Write-Host "[DEBUG] POST $Url/mcp" -ForegroundColor Gray
        Write-Host "[DEBUG] Agent: $Agent" -ForegroundColor Gray
    }

    $response = Invoke-RestMethod -Uri "$Url/mcp" -Method POST -Headers $headers -Body $body -TimeoutSec 120

    # Parse MCP response
    if ($response.result) {
        $content = $response.result
        if ($content -is [array]) {
            $textContent = ($content | Where-Object { $_.type -eq "text" } | Select-Object -First 1).text
            if ($textContent) { return $textContent }
        }
        if ($content.content -is [array]) {
            $textContent = ($content.content | Where-Object { $_.type -eq "text" } | Select-Object -First 1).text
            if ($textContent) { return $textContent }
        }
        # Try parsing as JSON string
        try {
            $parsed = $content | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($parsed.response) { return $parsed.response }
        } catch {}
        return "$content"
    }

    if ($response.error) {
        throw "sk-agent error: $($response.error.message)"
    }

    throw "Unexpected response format from sk-agent"
}

function Invoke-VllmDirect {
    param([string]$Prompt, [string]$Url, [int]$MaxTokens)

    $bodyObj = @{
        model = "qwen3.5-35b-a3b"
        messages = @(
            @{ role = "system"; content = $CriticSystemPrompt }
            @{ role = "user"; content = $Prompt }
        )
        max_tokens = $MaxTokens
        temperature = 0.3
    }
    $body = $bodyObj | ConvertTo-Json -Depth 5
    # Ensure proper UTF-8 encoding (PS 5.1 Invoke-RestMethod can mangle encoding)
    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)

    # Read API key from sk-agent config (gitignored, has real keys)
    $vllmApiKey = $env:VLLM_API_KEY
    if (-not $vllmApiKey) {
        $configFile = Join-Path $PSScriptRoot "..\..\mcps\internal\servers\sk-agent\sk_agent_config.json"
        if (Test-Path $configFile) {
            try {
                $config = Get-Content $configFile -Raw | ConvertFrom-Json
                $qwenModel = $config.models | Where-Object { $_.id -eq "qwen3.5-35b-a3b" } | Select-Object -First 1
                if ($qwenModel -and $qwenModel.api_key) {
                    $vllmApiKey = $qwenModel.api_key
                }
            } catch {}
        }
    }
    if (-not $vllmApiKey) { $vllmApiKey = "vllm-placeholder-key-2024" }

    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $vllmApiKey"
    }

    if ($ShowDebug) {
        Write-Host "[DEBUG] POST $Url (vLLM direct, key: $($vllmApiKey.Substring(0,6))...)" -ForegroundColor Gray
    }

    $response = Invoke-RestMethod -Uri $Url -Method POST -Headers $headers -Body $bodyBytes -TimeoutSec 120

    if ($response.choices -and $response.choices[0].message.content) {
        $content = $response.choices[0].message.content
        # Strip thinking process if present (Qwen3.5 thinking model)
        if ($content -match '(?s)^.*?(?=^#\s|^##\s)') {
            $thinkEnd = $content.IndexOf("`n# ")
            if ($thinkEnd -lt 0) { $thinkEnd = $content.IndexOf("`n## ") }
            if ($thinkEnd -gt 0 -and $thinkEnd -lt ($content.Length / 2)) {
                $content = $content.Substring($thinkEnd).TrimStart()
            }
        }
        return $content
    }

    throw "Unexpected response format from vLLM"
}

# Main execution
try {
    if ($Mode -eq "http") {
        if ($ShowDebug) { Write-Host "[call-sk-agent] Mode: HTTP MCP ($SkAgentUrl)" -ForegroundColor Cyan }
        $result = Invoke-SkAgentHttp -Prompt $Prompt -Agent $Agent -Url $SkAgentUrl
    } else {
        if ($ShowDebug) { Write-Host "[call-sk-agent] Mode: vLLM direct ($VllmUrl)" -ForegroundColor Cyan }
        $result = Invoke-VllmDirect -Prompt $Prompt -Url $VllmUrl -MaxTokens $MaxTokens
    }

    Write-Output $result

} catch {
    if ($Mode -eq "http") {
        Write-Warning "[call-sk-agent] HTTP mode failed: $_. Falling back to vLLM direct."
        try {
            $result = Invoke-VllmDirect -Prompt $Prompt -Url $VllmUrl -MaxTokens $MaxTokens
            Write-Output $result
        } catch {
            Write-Error "[call-sk-agent] All modes failed. Last error: $_"
            exit 1
        }
    } else {
        Write-Error "[call-sk-agent] vLLM direct failed: $_"
        exit 1
    }
}
