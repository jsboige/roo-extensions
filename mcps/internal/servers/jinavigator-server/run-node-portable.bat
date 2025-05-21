@echo off
REM Script pour exécuter Node.js portable via PowerShell

REM Obtenir le chemin du répertoire du script
set SCRIPT_DIR=%~dp0

REM Exécuter le script PowerShell avec les arguments fournis
powershell.exe -ExecutionPolicy Bypass -File "..\quickfiles-server\download-node.ps1" %*

REM Retourner le code de sortie du script PowerShell
exit /b %ERRORLEVEL%