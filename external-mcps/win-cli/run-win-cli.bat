@echo off
echo Démarrage du serveur MCP Win-CLI...

REM Méthode 1 : Utilisation de NPX (ne nécessite pas d'installation préalable)
npx -y @simonb97/server-win-cli

REM Méthode 2 : Utilisation du module installé globalement (nécessite npm install -g @simonb97/server-win-cli)
REM Remplacez <username> par votre nom d'utilisateur Windows
REM node "C:\Users\%USERNAME%\AppData\Roaming\npm\node_modules\@simonb97\server-win-cli\dist\index.js"

REM Si vous rencontrez des problèmes avec la méthode 1, essayez la méthode 2 en décommentant la ligne node
REM et en commentant la ligne npx ci-dessus