# Script pour démarrer tous les serveurs MCP configurés

Write-Output "Démarrage des serveurs MCP..."

# quickfiles
Start-Process powershell -ArgumentList "-NoExit", "-Command", "node c:/dev/roo-extensions/mcps/internal/servers/quickfiles-server/build/index.js"

# jinavigator
Start-Process powershell -ArgumentList "-NoExit", "-Command", "node c:/dev/roo-extensions/mcps/internal/servers/jinavigator-server/dist/index.js"

# jupyter
Start-Process powershell -ArgumentList "-NoExit", "-Command", "node c:/dev/roo-extensions/mcps/internal/servers/jupyter-mcp-server/dist/index.js"

# win-cli
Start-Process powershell -ArgumentList "-NoExit", "-Command", "npx -y @simonb97/server-win-cli"

# filesystem
Start-Process powershell -ArgumentList "-NoExit", "-Command", "npx -y @modelcontextprotocol/server-filesystem c:/dev/roo-extensions"

# git
Start-Process powershell -ArgumentList "-NoExit", "-Command", "npx -y @modelcontextprotocol/server-git"

# github
Start-Process powershell -ArgumentList "-NoExit", "-Command", "npx -y @modelcontextprotocol/server-github"

# searxng
Start-Process powershell -ArgumentList "-NoExit", "-Command", "npx -y mcp-searxng"

# docker
Start-Process powershell -ArgumentList "-NoExit", "-Command", "npx -y @modelcontextprotocol/server-docker"

Write-Output "Tous les serveurs MCP ont été lancés dans des processus séparés."