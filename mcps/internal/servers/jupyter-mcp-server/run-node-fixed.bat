@echo off
REM Script pour rechercher Node.js et l'exécuter avec les arguments fournis

REM Liste des emplacements courants où Node.js pourrait être installé
set "NODEJS_PATH="

REM Vérifier chaque emplacement possible
if exist "C:\Program Files\nodejs\node.exe" (
    set "NODEJS_PATH=C:\Program Files\nodejs\node.exe"
    goto :found
)

if exist "C:\Program Files (x86)\nodejs\node.exe" (
    set "NODEJS_PATH=C:\Program Files (x86)\nodejs\node.exe"
    goto :found
)

if exist "%USERPROFILE%\AppData\Roaming\nvm\current\node.exe" (
    set "NODEJS_PATH=%USERPROFILE%\AppData\Roaming\nvm\current\node.exe"
    goto :found
)

if exist "%LOCALAPPDATA%\Programs\node\node.exe" (
    set "NODEJS_PATH=%LOCALAPPDATA%\Programs\node\node.exe"
    goto :found
)

REM Vérifier si Node.js est dans le PATH
where /q node
if %ERRORLEVEL% equ 0 (
    echo Node.js trouvé dans le PATH
    node %*
    exit /b %ERRORLEVEL%
)

echo Node.js n'a pas été trouvé sur le système.
echo Veuillez installer Node.js depuis https://nodejs.org/ ou via Windows Store.
exit /b 1

:found
echo Node.js trouvé à : %NODEJS_PATH%
"%NODEJS_PATH%" %*
exit /b %ERRORLEVEL%