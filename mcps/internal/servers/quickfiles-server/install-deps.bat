@echo off
REM Script pour installer les dépendances avec Node.js portable

REM Obtenir le chemin du répertoire du script
set SCRIPT_DIR=%~dp0

echo Installation des dépendances pour le serveur quickfiles...

REM Exécuter npm install avec Node.js portable
call "%SCRIPT_DIR%run-node-portable.bat" "%SCRIPT_DIR%node-portable\node-v20.12.2-win-x64\node_modules\npm\bin\npm-cli.js" install --prefix "%SCRIPT_DIR%"

if %ERRORLEVEL% neq 0 (
    echo Erreur lors de l'installation des dépendances.
    exit /b %ERRORLEVEL%
)

echo Les dépendances ont été installées avec succès.