# Script de vérification des fichiers MCP
Write-Host "=== Vérification des fichiers MCP ===" -ForegroundColor Cyan
Write-Host ""

$mcpFiles = @(
    "C:/dev/roo-extensions/mcps/internal/servers/jupyter-mcp-server/dist/index.js",
    "C:/dev/roo-extensions/mcps/internal/servers/github-projects-mcp/dist/index.js",
    "C:/dev/roo-extensions/mcps/internal/servers/roo-state-manager/build/src/index.js",
    "C:/dev/roo-extensions/mcps/internal/servers/jinavigator-server/dist/index.js",
    "C:/dev/roo-extensions/mcps/internal/servers/quickfiles-server/build/index.js"
)

$allExist = $true

foreach ($file in $mcpFiles) {
    if (Test-Path $file) {
        Write-Host "✅ EXISTS: $file" -ForegroundColor Green
    } else {
        Write-Host "❌ MISSING: $file" -ForegroundColor Red
        $allExist = $false
    }
}

Write-Host ""
if ($allExist) {
    Write-Host "✅ Tous les fichiers MCP sont présents" -ForegroundColor Green
} else {
    Write-Host "❌ Certains fichiers MCP sont manquants" -ForegroundColor Red
}