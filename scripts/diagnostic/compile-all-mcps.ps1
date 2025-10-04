# Script de compilation de tous les MCPs internes
Write-Host "=== Compilation de tous les MCPs internes ===" -ForegroundColor Cyan
Write-Host ""

$mcpServers = @(
    "jupyter-mcp-server",
    "jinavigator-server", 
    "roo-state-manager"
)

$success = $true

foreach ($server in $mcpServers) {
    Write-Host "Compilation de $server..." -ForegroundColor Yellow
    $path = "mcps/internal/servers/$server"
    
    Push-Location $path
    $result = npm run build 2>&1
    $exitCode = $LASTEXITCODE
    Pop-Location
    
    if ($exitCode -eq 0) {
        Write-Host "✅ $server compilé avec succès" -ForegroundColor Green
    } else {
        Write-Host "❌ Erreur lors de la compilation de $server" -ForegroundColor Red
        Write-Host $result
        $success = $false
    }
    Write-Host ""
}

if ($success) {
    Write-Host "✅ Tous les MCPs compilés avec succès" -ForegroundColor Green
} else {
    Write-Host "❌ Certains MCPs n'ont pas pu être compilés" -ForegroundColor Red
}