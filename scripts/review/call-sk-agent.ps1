# Wrapper pour appeler sk-agent depuis PowerShell
# Usage: .\call-sk-agent.ps1 [-Prompt $prompt] [-Participants @("critic", "optimist", "devils-advocate", "pragmatist")] [-ConversationType "code-review"]

param(
    [string]$Prompt = "",
    [string[]]$Participants = @("critic", "optimist", "devils-advocate", "pragmatist"),
    [string]$ConversationType = "code-review",
    [string]$Context = "{}",
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Stop"

# Chemin du script sk-agent
$SkAgentPath = "D:/Dev/roo-extensions/mcps/internal/servers/sk-agent/run-sk-agent.ps1"

# Vérifier si sk-agent est accessible
if (-not (Test-Path $SkAgentPath)) {
    Write-Error "sk-agent non trouvé à: $SkAgentPath"
    exit 1
}

# Construire la requête MCP
$mcpRequest = @{
    jsonrpc = "2.0"
    id = 1
    method = "tools/call"
    params = @{
        name = "create_conversation"
        arguments = @{
            conversation_type = $ConversationType
            participants = $Participants
            context = $Context | ConvertFrom-Json
        }
    }
} | ConvertTo-Json -Depth 10

if ($Verbose) {
    Write-Host "[DEBUG] Requête MCP:"
    Write-Host $mcpRequest
}

# Appeler sk-agent via MCP
try {
    # Utiliser le MCP sk-agent
    $result = call_agent(
        prompt: $Prompt,
        agent_type: "sk_agent"
    )

    if ($result) {
        Write-Output $result
    } else {
        Write-Warning "sk-agent a retourné un résultat vide"
        exit 1
    }
} catch {
    Write-Error "Erreur lors de l'appel à sk-agent: $_"
    exit 1
}