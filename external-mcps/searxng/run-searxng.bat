@echo off
echo Démarrage du serveur MCP SearXNG...

REM Méthode 1 : Utilisation de NPX (ne nécessite pas d'installation préalable)
REM npx -y mcp-searxng

REM Méthode 2 : Utilisation du module installé globalement (nécessite npm install -g mcp-searxng)
REM Remplacez <username> par votre nom d'utilisateur Windows
node "C:\Users\%USERNAME%\AppData\Roaming\npm\node_modules\mcp-searxng\dist\index.js"

REM Si vous rencontrez des problèmes avec la méthode 2, essayez la méthode 1 en décommentant la ligne npx
REM et en commentant la ligne node ci-dessus