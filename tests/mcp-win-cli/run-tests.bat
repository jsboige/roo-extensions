@echo off
setlocal enabledelayedexpansion

:: Script de lancement des tests du MCP Win-CLI
:: Ce script permet d'exécuter facilement les différents scripts de test

echo ===================================================
echo    TESTS DU MCP WIN-CLI
echo ===================================================
echo.
echo Ce script permet de lancer les différents tests du MCP Win-CLI.
echo.

:menu
echo Choisissez un test à exécuter :
echo.
echo 1. Test simulé (test-win-cli.js)
echo 2. Test semi-réel (test-win-cli-real.js)
echo 3. Test avec API MCP (test-win-cli-mcp.js)
echo 4. Test direct (test-win-cli-direct.js)
echo 5. Exécuter tous les tests
echo 6. Ouvrir le rapport de synthèse
echo 0. Quitter
echo.

set /p choix=Votre choix : 

if "%choix%"=="1" goto test_simule
if "%choix%"=="2" goto test_semi_reel
if "%choix%"=="3" goto test_api_mcp
if "%choix%"=="4" goto test_direct
if "%choix%"=="5" goto tous_les_tests
if "%choix%"=="6" goto ouvrir_rapport
if "%choix%"=="0" goto fin

echo Choix invalide. Veuillez réessayer.
echo.
goto menu

:test_simule
echo.
echo Exécution du test simulé...
echo.
node test-win-cli.js
echo.
echo Test terminé.
echo.
pause
goto menu

:test_semi_reel
echo.
echo Exécution du test semi-réel...
echo.
node test-win-cli-real.js
echo.
echo Test terminé.
echo.
pause
goto menu

:test_api_mcp
echo.
echo Pour exécuter le test avec l'API MCP, vous devez utiliser Roo.
echo Voici la commande à utiliser dans Roo :
echo.
echo ^<use_mcp_tool^>
echo ^<server_name^>win-cli^</server_name^>
echo ^<tool_name^>execute_command^</tool_name^>
echo ^<arguments^>
echo {
echo   "shell": "powershell",
echo   "command": "node test-win-cli-mcp.js",
echo   "workingDir": "%CD%"
echo }
echo ^</arguments^>
echo ^</use_mcp_tool^>
echo.
echo Voulez-vous copier cette commande dans le presse-papiers ? (O/N)
set /p copier=

if /i "%copier%"=="O" (
    echo ^<use_mcp_tool^>^<server_name^>win-cli^</server_name^>^<tool_name^>execute_command^</tool_name^>^<arguments^>{"shell": "powershell","command": "node test-win-cli-mcp.js","workingDir": "%CD%"}^</arguments^>^</use_mcp_tool^> | clip
    echo Commande copiée dans le presse-papiers.
)
echo.
pause
goto menu

:test_direct
echo.
echo Exécution du test direct...
echo.
node test-win-cli-direct.js
echo.
echo Test terminé.
echo.
pause
goto menu

:tous_les_tests
echo.
echo Exécution de tous les tests...
echo.

echo 1. Test simulé
node test-win-cli.js
echo.

echo 2. Test semi-réel
node test-win-cli-real.js
echo.

echo 3. Test direct
node test-win-cli-direct.js
echo.

echo 4. Pour le test avec API MCP, utilisez Roo.
echo.

echo Tous les tests terminés.
echo.
pause
goto menu

:ouvrir_rapport
echo.
echo Ouverture du rapport de synthèse...
start "" rapport-synthese.md
echo.
pause
goto menu

:fin
echo.
echo Merci d'avoir utilisé le script de test du MCP Win-CLI.
echo.
endlocal