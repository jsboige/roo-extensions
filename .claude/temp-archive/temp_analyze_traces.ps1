$tasks = @(
    "019d159f-7f4f-709a-a960-0f09a51b213a",
    "019d159c-fccc-77da-9997-4f1e315aa138",
    "019d159d-af11-718a-a2af-2c04a8b0320d",
    "019d132e-1808-707f-bac3-78b29a490da0",
    "019d132c-5b2a-75fb-9d0b-9cb72c9b06da"
)

Write-Output "=== RAPPORT D'ANALYSE DES TRACES ROO ===`n"

foreach ($taskId in $tasks) {
    $taskPath = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks\$taskId"
    $jsonPath = "$taskPath\ui_messages.json"
    
    if (Test-Path $jsonPath) {
        $json = Get-Content $jsonPath -Raw | ConvertFrom-Json
        $date = (Get-Item $taskPath).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
        
        $mode = "unknown"
        foreach ($msg in $json | Select-Object -First 30) {
            if ($msg.text -and $msg.text -match "mode.*?(-simple|-complex)|ask-complex|code-complex|architect-complex|orchestrator-complex") {
                if ($matches[1]) { $mode = $matches[1] } else { $mode = "complex" }
                break
            }
        }
        
        $toolCount = 0
        $toolsUsed = @{}
        foreach ($msg in $json) {
            $content = if ($msg.text) { $msg.text } else { "" }
            if ($msg.say) { $content += " " + $msg.say }
            
            if ($content -match "use_mcp_tool") {
                $toolCount++
                if ($content -match "tool_name.*?`"([^`"]+)`"") {
                    $tool = $matches[1]
                    if ($toolsUsed.ContainsKey($tool)) { $toolsUsed[$tool]++ } else { $toolsUsed[$tool] = 1 }
                }
            }
        }
        
        $errorCount = 0
        foreach ($msg in $json) {
            $content = if ($msg.text) { $msg.text } else { "" }
            if ($msg.say) { $content += " " + $msg.say }
            if ($content -match "error|Error|ERROR|failed|Failed|FAILED") {
                $errorCount++
            }
        }
        
        $escalationCount = 0
        foreach ($msg in $json) {
            $content = if ($msg.text) { $msg.text } else { "" }
            if ($msg.say) { $content += " " + $msg.say }
            if ($content -match "new_task.*complex|escalate") {
                $escalationCount++
            }
        }
        
        $status = if ($errorCount -eq 0) { "SUCCESS" } else { "FAILURE" }
        $toolsList = if ($toolsUsed.Count -gt 0) { ($toolsUsed.Keys | ForEach-Object { "$_($toolsUsed[$_])x $_" }) -join ", " } else { "Aucun" }
        
        Write-Output "Tâche: $($taskId.Substring(0, 12))..."
        Write-Output "  Date: $date"
        Write-Output "  Mode: $mode"
        Write-Output "  Status: $status"
        Write-Output "  Outils MCP: $toolCount appels"
        Write-Output "  Outils utilisés: $toolsList"
        Write-Output "  Erreurs: $errorCount"
        Write-Output "  Escalades: $escalationCount"
        Write-Output ""
    }
}
