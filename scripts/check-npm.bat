@echo off
echo Verification du PATH et de mcp-searxng
echo.
echo Recherche de C:\Users\jsboi\AppData\Roaming\npm dans le PATH :
echo %PATH% | findstr /C:"C:\Users\jsboi\AppData\Roaming\npm"
echo.
echo Verification de l'existence des fichiers :
dir "C:\Users\jsboi\AppData\Roaming\npm\mcp-searxng*" /b
echo.
echo Tentative d'execution de mcp-searxng :
call mcp-searxng --version
echo.
echo Fin de la verification