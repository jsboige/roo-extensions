Write-Host "--- Installation des @types pour github-projects-mcp ---"
Push-Location mcps/internal/servers/github-projects-mcp
npm install --save-dev @types/node @types/connect @types/mime @types/range-parser
Pop-Location
Write-Host "--- Installation des @types terminée ---"