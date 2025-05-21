@echo off
echo ===== Déploiement du MCP Quickfiles =====
echo.

cd /d %~dp0

echo 1. Compilation du code...
call compile.bat
if %ERRORLEVEL% NEQ 0 (
    echo Erreur lors de la compilation.
    exit /b %ERRORLEVEL%
)
echo.

echo 2. Redémarrage du serveur MCP Quickfiles...
echo Arrêt des instances en cours...
taskkill /f /im node.exe /fi "WINDOWTITLE eq quickfiles-server" 2>nul
echo Démarrage du serveur MCP...
start "quickfiles-server" cmd /c "node build\index.js"
echo Serveur MCP Quickfiles redémarré.
echo.

echo ===== Déploiement terminé avec succès =====
echo Les nouveaux outils sont maintenant disponibles.
echo.