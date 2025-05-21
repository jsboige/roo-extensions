@echo off
REM Script pour rechercher Node.js et l'exécuter avec les arguments fournis

REM Liste des emplacements courants où Node.js pourrait être installé
set PATHS_TO_CHECK=^
C:\Program Files\nodejs\node.exe^
C:\Program Files (x86)\nodejs\node.exe^
%USERPROFILE%\AppData\Roaming\nvm\current\node.exe^
%USERPROFILE%\AppData\Local\Programs\node\node.exe^
%LOCALAPPDATA%\Programs\node\node.exe^
%LOCALAPPDATA%\Microsoft\WindowsApps\node.exe^
%ProgramFiles%\nodejs\node.exe^
%ProgramFiles(x86)%\nodejs\node.exe

REM Vérifier chaque emplacement
for %%p in (%PATHS_TO_CHECK%) do (
    if exist "%%p" (
        echo Node.js trouvé à : %%p
        "%%p" %*
        exit /b %ERRORLEVEL%
    )
)

REM Vérifier si Node.js est installé via Windows Store
where /q node
if %ERRORLEVEL% equ 0 (
    echo Node.js trouvé dans le PATH
    node %*
    exit /b %ERRORLEVEL%
)

REM Si Node.js n'est pas trouvé, afficher un message d'erreur détaillé
echo Node.js n'a pas été trouvé sur le système.
echo Veuillez installer Node.js depuis https://nodejs.org/ ou via Windows Store.
echo.
echo Emplacements vérifiés:
for %%p in (%PATHS_TO_CHECK%) do (
    echo - %%p
)
echo - Commande 'node' dans le PATH
echo.
echo Après l'installation, redémarrez VS Code pour que les changements prennent effet.
exit /b 1