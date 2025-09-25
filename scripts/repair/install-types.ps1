Write-Host "--- Installation des @types pour jupyter-mcp-server ---"
Push-Location mcps/internal/servers/jupyter-mcp-server
npm install --save-dev @types/node @types/connect @types/mime @types/range-parser @types/minimist
Pop-Location

Write-Host "--- Installation des @types pour github-projects-mcp ---"
Push-Location mcps/internal/servers/github-projects-mcp
npm install --save-dev @types/node
Pop-Location

Write-Host "--- Installation des @types terminée ---"