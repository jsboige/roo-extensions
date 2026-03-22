$config = Get-Content 'mcp_settings_ai01.json' -Raw | ConvertFrom-Json

Write-Host "=== MCP Configuration Analysis (myia-ai-01) ===" -ForegroundColor Cyan
Write-Host ""

$totalTools = 0
$enabledServers = 0

foreach ($serverName in $config.mcpServers.PSObject.Properties.Name) {
    $server = $config.mcpServers.$serverName
    $status = if ($server.disabled) { "DISABLED" } else { "ENABLED" }
    $toolCount = if ($server.alwaysAllow) { $server.alwaysAllow.Count } else { 0 }

    if (-not $server.disabled) {
        $enabledServers++
        $totalTools += $toolCount
    }

    Write-Host "$serverName : $status" -ForegroundColor $(if ($server.disabled) { "Red" } else { "Green" })
    Write-Host "  alwaysAllow: $toolCount tools"

    if ($server.alwaysAllow -and $toolCount -gt 0) {
        Write-Host "  Tools: $($server.alwaysAllow -join ', ')" -ForegroundColor Gray
    }
    Write-Host ""
}

Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Total MCP servers: $($config.mcpServers.PSObject.Properties.Count)"
Write-Host "Enabled servers: $enabledServers"
Write-Host "Disabled servers: $($config.mcpServers.PSObject.Properties.Count - $enabledServers)"
Write-Host "Total alwaysAllow tools (enabled only): $totalTools"
